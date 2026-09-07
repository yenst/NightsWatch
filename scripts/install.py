#!/usr/bin/env python3
"""Install this local checkout without touching other shell plugins."""
import json
from pathlib import Path
import shutil
import subprocess

source = Path(__file__).resolve().parents[1]
destination = Path.home() / '.config/omarchy/plugins/jihmy.nightswatch'
subprocess.run(['omarchy', 'plugin', 'validate', str(source)], check=True)
if destination.is_symlink():
    raise SystemExit('Refusing a symlink installation directory')
if destination.exists():
    manifest = destination / 'manifest.json'
    if not manifest.is_file() or json.loads(manifest.read_text()).get('id') != 'jihmy.nightswatch':
        raise SystemExit('Destination belongs to something else; refusing to overwrite it')
files = ['manifest.json', 'Panel.qml', 'Content.qml', 'Icon.qml', 'Service.qml', 'scripts/ports.py', 'README.md', 'CONTRIBUTING.md', 'LICENSE', 'docs/screenshots/overview.png', 'docs/screenshots/detail.png']
for name in files:
    target = destination / name
    if target.is_symlink() or target.parent.is_symlink():
        raise SystemExit('Refusing symlink target: ' + str(target))
for name in files:
    target = destination / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source / name, target)
subprocess.run(['omarchy', 'plugin', 'validate', str(destination)], check=True)
subprocess.run(['omarchy-shell', 'shell', 'rescanPlugins'], check=True)
print('Installed ' + str(destination))
