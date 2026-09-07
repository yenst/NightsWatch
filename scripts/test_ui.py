#!/usr/bin/env python3
"""Render and exercise the real QML content with isolated fixture data."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1]
work = Path(tempfile.mkdtemp(prefix='nightswatch-ui-'))
runtime = work / 'runtime'
runtime.mkdir(mode=0o700)
for name in ('Commons', 'Ui'):
    (work / name).symlink_to(Path('/usr/share/omarchy/shell') / name)
(work / 'Plugin').symlink_to(source)
shutil.copy2(source / 'tests/Preview.qml', work / 'shell.qml')
env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='offscreen',
           QT_QPA_PLATFORMTHEME='basic', QT_QUICK_CONTROLS_STYLE='Basic', NIGHTSWATCH_CAPTURE_DIR=str(work))
env.pop('WAYLAND_DISPLAY', None)
result = subprocess.run(['qs', '-p', str(work)], env=env, text=True, capture_output=True, timeout=15)
output = result.stdout + result.stderr
if result.returncode or 'UI TEST PASS:' not in output or 'UI TEST FAILED' in output or 'Failed to load configuration' in output:
    raise SystemExit(output)
for name in ('implementation.png', 'detail.png', 'long-command.png'):
    if not (work / name).is_file():
        raise SystemExit('Missing QML capture: ' + name)
print('UI workflows passed. Captures: ' + str(work))
