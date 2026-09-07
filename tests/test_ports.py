import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import unittest
from unittest.mock import patch

HELPER = Path(__file__).resolve().parents[1] / 'scripts' / 'ports.py'
spec = importlib.util.spec_from_file_location('ports', HELPER)
ports = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ports)


class ParsingTests(unittest.TestCase):
    def info(self, pid):
        return {'uid': 1000 if pid in (10, 20) else 0, 'startTime': str(pid * 100), 'cwd': '/home/me/project', 'command': 'python app.py'}

    def test_ipv6_multiple_owners_bindings_and_categories(self):
        output = '''tcp LISTEN 0 128 [::1]:8080 [::]:* users:(("python",pid=10,fd=5),("worker",pid=20,fd=7)) uid:1000 ino:1
 tcp LISTEN 0 128 [::1]:8080 [::]:* users:(("python",pid=10,fd=8)) uid:1000 ino:2
 tcp LISTEN 0 128 127.0.0.1:8080 0.0.0.0:* users:(("python",pid=10,fd=9))
 udp UNCONN 0 0 0.0.0.0:53 0.0.0.0:* users:(("daemon",pid=30,fd=1)) uid:0
 tcp LISTEN 0 128 192.168.1.2:3000 0.0.0.0:* ino:5'''
        rows, truncated = ports.parse_listeners(output, {10}, self.info, 1000)
        self.assertEqual(len(rows), 5)
        self.assertFalse(truncated)
        self.assertEqual([r['category'] for r in rows], ['system', 'system', 'apps', 'apps', 'own'])
        self.assertEqual([r['scope'] for r in rows], ['All interfaces', 'Specific address', 'Local only', 'Local only', 'Local only'])
        self.assertEqual(rows[2]['startTime'], '1000')
        self.assertFalse(rows[0]['canStop'])
        self.assertFalse(rows[1]['canStop'])
        self.assertEqual(len({r['key'] for r in rows}), 5)

    def test_stat_embedded_parentheses(self):
        stat = '50 (a weird (process) name)) S ' + ' '.join(['0'] * 18 + ['1234567890123456789', '0'])
        self.assertEqual(ports.stat_start_time(stat), '1234567890123456789')

    def test_row_limit(self):
        lines = '\n'.join(f'tcp LISTEN 0 1 *:{port} *:*' for port in range(1, 502))
        rows, truncated = ports.parse_listeners(lines, own_uid=1000)
        self.assertEqual(len(rows), 500)
        self.assertTrue(truncated)

    def test_scope_and_plain_strings(self):
        self.assertEqual(ports.scope_for('127.55.2.3'), 'Local only')
        self.assertEqual(ports.scope_for('::'), 'All interfaces')
        self.assertEqual(ports.scope_for('fe80::1%wlan0'), 'Specific address')
        self.assertEqual(ports.plain('a\n\x1bb'), 'a  b')

    def test_ipv6_zone_after_bracket(self):
        rows, _ = ports.parse_listeners('udp UNCONN 0 0 [fe80::1234]%wlan0:546 [::]:*', own_uid=1000)
        self.assertEqual(rows[0]['address'], 'fe80::1234%wlan0')
        self.assertEqual(rows[0]['scope'], 'Specific address')

    def test_foreign_uid_refused(self):
        start = ports.process_info(os.getpid())['startTime']
        with patch.object(ports.os, 'getuid', return_value=os.getuid() + 1), patch.object(ports.signal, 'pidfd_send_signal') as send:
            result = ports.stop(str(os.getpid()), start)
        self.assertFalse(result['ok'])
        send.assert_not_called()

    def test_mismatch_never_signals(self):
        with patch.object(ports.signal, 'pidfd_send_signal') as send:
            result = ports.stop(str(os.getpid()), '0')
        self.assertFalse(result['ok'])
        self.assertIn('identity changed', result['error'])
        send.assert_not_called()

    def test_netlink_failure_is_error_even_with_zero_status(self):
        completed = subprocess.CompletedProcess([], 0, '', 'Cannot open netlink socket: Operation not permitted')
        with patch.object(ports.subprocess, 'run', return_value=completed):
            with self.assertRaisesRegex(RuntimeError, 'Listener scan failed'):
                ports.scan()

    def test_hyprctl_failure_preserves_listeners(self):
        completed = subprocess.CompletedProcess([], 0, 'tcp LISTEN 0 1 *:8080 *:*', '')
        with patch.object(ports.subprocess, 'run', side_effect=[completed, FileNotFoundError('hyprctl missing')]):
            data = ports.scan()
        self.assertEqual(len(data['ports']), 1)
        self.assertIn('classification unavailable', data['warning'])


@unittest.skipUnless(hasattr(os, 'pidfd_open') and hasattr(signal, 'pidfd_send_signal'), 'pidfd unavailable')
class IntegrationTests(unittest.TestCase):
    def setUp(self):
        code = '''import socket,time
try:
    s=socket.socket(); s.bind(("127.0.0.1",0)); s.listen()
    print(s.getsockname()[1],flush=True)
except PermissionError:
    print(0,flush=True)
time.sleep(30)'''
        self.child = subprocess.Popen([sys.executable, '-u', '-c', code], stdout=subprocess.PIPE, text=True)
        self.port = int(self.child.stdout.readline())
        self.start = ports.process_info(self.child.pid)['startTime']

    def tearDown(self):
        if self.child.poll() is None:
            self.child.terminate()
        self.child.wait(timeout=3)
        self.child.stdout.close()

    def call_helper(self, *args):
        result = subprocess.run([sys.executable, str(HELPER), *args], capture_output=True, text=True, timeout=10)
        return result, json.loads(result.stdout)

    def test_wrong_start_then_stop_owned_disposable_listener(self):
        result, data = self.call_helper('stop', str(self.child.pid), '0')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(data['ok'])
        self.assertIsNone(self.child.poll())
        result, data = self.call_helper('stop', str(self.child.pid), self.start)
        self.assertEqual(result.returncode, 0, data)
        self.assertTrue(data['ok'])
        self.assertEqual(self.child.wait(timeout=3), -signal.SIGTERM)

    def test_discover_then_stop_listener(self):
        if not self.port:
            self.skipTest('Sandbox denies localhost listener sockets')
        result, data = self.call_helper('scan')
        if result.returncode and 'Operation not permitted' in data.get('error', ''):
            self.skipTest('Sandbox denies ss netlink access')
        self.assertEqual(result.returncode, 0, data)
        matches = [r for r in data['ports'] if r['pid'] == self.child.pid and r['port'] == self.port]
        self.assertEqual(len(matches), 1)
        row = matches[0]
        self.assertTrue(row['canStop'])
        self.assertEqual(row['scope'], 'Local only')
        self.assertEqual(row['startTime'], self.start)
        result, data = self.call_helper('stop', str(row['pid']), row['startTime'])
        self.assertTrue(data['ok'], data)
        self.assertEqual(self.child.wait(timeout=3), -signal.SIGTERM)


if __name__ == '__main__':
    unittest.main()
