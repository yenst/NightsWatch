#!/usr/bin/env python3
"""Short-lived listener inventory and race-resistant, owner-only termination."""
import ipaddress
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys

MAX_ROWS = 500
OWNER_RE = re.compile(r'\("((?:[^"\\]|\\.)*)",pid=(\d+),fd=\d+\)')


def plain(value, limit=512):
    return ''.join(c if c.isprintable() else ' ' for c in str(value))[:limit]


def stat_start_time(text):
    # comm may itself contain spaces and closing parentheses. Field 22 is
    # offset 19 after the final comm delimiter (field 3, state).
    tail = text[text.rindex(')') + 1:].split()
    value = tail[19]
    if not value.isdecimal():
        raise ValueError('Invalid process start time')
    return value


def process_info(pid):
    root = Path('/proc') / str(pid)
    try:
        uid = root.stat().st_uid
        start = stat_start_time((root / 'stat').read_text())
    except (OSError, ValueError, IndexError):
        return None
    try:
        command = plain((root / 'cmdline').read_bytes()[:16384].decode('utf-8', 'replace').replace('\0', ' ').strip(), 2048)
    except OSError:
        command = ''
    try:
        cwd = plain(os.readlink(root / 'cwd'), 1024)
    except OSError:
        cwd = ''
    return {'uid': uid, 'startTime': start, 'cwd': cwd, 'command': command}


def scope_for(address):
    if address in ('*', '0.0.0.0', '::'):
        return 'All interfaces'
    try:
        if ipaddress.ip_address(address.split('%', 1)[0]).is_loopback:
            return 'Local only'
    except ValueError:
        pass
    return 'Specific address'


def parse_listeners(output, app_pids=(), info_reader=process_info, own_uid=None):
    own_uid = os.getuid() if own_uid is None else own_uid
    rows, seen, cache = [], set(), {}
    for line in output.splitlines():
        fields = line.split(None, 6)
        if len(fields) < 6:
            continue
        proto, state, _, _, endpoint, _ = fields[:6]
        if proto not in ('tcp', 'udp') or state not in ('LISTEN', 'UNCONN'):
            continue
        if proto == 'tcp' and state != 'LISTEN':
            continue
        address, separator, port_text = endpoint.rpartition(':')
        if not separator or not port_text.isdecimal():
            continue
        port = int(port_text)
        if not 0 <= port <= 65535:
            continue
        address = address.replace('[', '').replace(']', '')
        rest = fields[6] if len(fields) > 6 else ''
        socket_uid = re.search(r'\buid:(\d+)\b', rest)
        owners = OWNER_RE.findall(rest) or [('', '0')]
        for name, pid_text in owners:
            pid = int(pid_text)
            identity = (proto, address, port, pid)
            if identity in seen:
                continue
            if len(rows) == MAX_ROWS:
                return rows, True
            seen.add(identity)
            if pid not in cache:
                cache[pid] = info_reader(pid) if pid else None
            info = cache[pid]
            uid = info['uid'] if info else int(socket_uid[1]) if socket_uid else None
            category = 'apps' if info and uid == own_uid and pid in app_pids else 'own' if uid == own_uid else 'system'
            process = plain(name or 'Unknown process', 128)
            cwd = info['cwd'] if info else ''
            rows.append({
                'key': f"{proto}|{address}|{port}|{pid}|{info['startTime'] if info else ''}", 'proto': proto,
                'port': port, 'address': plain(address, 256), 'endpoint': plain(endpoint, 280),
                'process': process, 'pid': pid, 'startTime': info['startTime'] if info else '',
                'uid': uid, 'category': category, 'project': plain(os.path.basename(cwd.rstrip('/')) or process, 128),
                'cwd': cwd, 'command': info['command'] if info else '', 'scope': scope_for(address),
                'canStop': bool(info and uid == own_uid and pid > 1 and hasattr(os, 'pidfd_open') and hasattr(signal, 'pidfd_send_signal')),
            })
    rows.sort(key=lambda p: (p['port'], p['proto'], p['address'], p['pid']))
    return rows, False


def scan():
    try:
        result = subprocess.run(['/usr/bin/ss', '-H', '-tulpne'], capture_output=True, text=True, timeout=5, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError('Listener scan failed: ' + plain(exc)) from exc
    if result.returncode or ('Cannot open netlink socket' in result.stderr):
        raise RuntimeError('Listener scan failed: ' + plain(result.stderr or f'ss exited {result.returncode}'))
    app_pids, warning = set(), plain(result.stderr.strip())
    try:
        clients = subprocess.run(['/usr/bin/hyprctl', 'clients', '-j'], capture_output=True, text=True, timeout=3, check=True)
        data = json.loads(clients.stdout)
        if not isinstance(data, list):
            raise ValueError('Unexpected window response')
        app_pids = {item['pid'] for item in data if isinstance(item, dict) and isinstance(item.get('pid'), int)}
    except (OSError, subprocess.SubprocessError, ValueError) as exc:
        warning = plain((warning + ' Window classification unavailable: ' + str(exc)).strip())
    rows, truncated = parse_listeners(result.stdout, app_pids)
    return {'ports': rows, 'warning': warning, 'truncated': truncated}


def stop(pid_text, expected_start):
    if not pid_text.isascii() or not pid_text.isdecimal() or int(pid_text) <= 1:
        return {'ok': False, 'error': 'Invalid process ID'}
    if not expected_start.isascii() or not expected_start.isdecimal():
        return {'ok': False, 'error': 'Invalid process start time'}
    if not hasattr(os, 'pidfd_open') or not hasattr(signal, 'pidfd_send_signal'):
        return {'ok': False, 'error': 'Safe process termination is unavailable on this system'}
    pid = int(pid_text)
    fd = None
    try:
        fd = os.pidfd_open(pid, 0)
        root = Path('/proc') / str(pid)
        start = stat_start_time((root / 'stat').read_text())
        uid = root.stat().st_uid
        if start != expected_start:
            return {'ok': False, 'error': 'Process identity changed; refresh the list'}
        if uid != os.getuid():
            return {'ok': False, 'error': 'Only your own processes can be stopped'}
        signal.pidfd_send_signal(fd, signal.SIGTERM, None, 0)
        return {'ok': True, 'error': ''}
    except (OSError, ValueError, IndexError, OverflowError) as exc:
        return {'ok': False, 'error': 'Could not safely stop process: ' + plain(exc)}
    finally:
        if fd is not None:
            os.close(fd)


def main(args):
    try:
        if args == ['scan']:
            output = scan()
        elif len(args) == 3 and args[0] == 'stop':
            output = stop(args[1], args[2])
        else:
            output = {'error': 'Usage: ports.py scan | stop PID STARTTIME'}
    except RuntimeError as exc:
        output = {'error': str(exc)}
    print(json.dumps(output, ensure_ascii=True))
    return 1 if output.get('error') else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
