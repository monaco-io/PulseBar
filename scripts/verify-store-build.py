#!/usr/bin/env python3
"""Verify bundle separation and signing inputs before Apple validation."""
import pathlib
import plistlib
import subprocess
import sys

app, helper = map(pathlib.Path, sys.argv[1:3])
configuration = sys.argv[3]
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'io.github.monaco-io.PulseBar'
assert not any(key.startswith('SU') for key in info), 'Sparkle metadata in store bundle'
assert not (app / 'Contents/Frameworks/Sparkle.framework').exists()
assert not list(app.rglob('*HelperService*')), 'Companion must not be embedded in store bundle'
binary = app / 'Contents/MacOS/PulseBar'
symbols = subprocess.check_output(['nm', '-u', str(binary)], text=True)
strings = subprocess.check_output(['strings', str(binary)], text=True)
for forbidden in ['PBTemperatureSMC', 'responsibility_get_pid_responsible_for_pid', 'proc_listallpids', 'proc_pid_rusage', 'SPUStandardUpdaterController']:
    assert forbidden not in symbols + strings, f'Unsupported store dependency: {forbidden}'
if configuration == 'release':
    assert 'PULSEBAR_HELPER_TEST_' not in strings, 'Test authentication override in release build'
entitlements = subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(app)], stderr=subprocess.DEVNULL)
entitlements = plistlib.loads(entitlements)
assert entitlements['com.apple.security.app-sandbox'] is True
assert entitlements['com.apple.security.temporary-exception.mach-lookup.global-name'] == ['45Y6A23PTN.io.github.monaco-io.PulseBar.HelperService']
assert not entitlements.get('com.apple.security.get-task-allow')
privacy = plistlib.loads((app / 'Contents/Resources/PrivacyInfo.xcprivacy').read_bytes())
assert privacy['NSPrivacyTracking'] is False
assert privacy['NSPrivacyCollectedDataTypes'] == []
agent = plistlib.loads((helper / 'Contents/Library/LaunchAgents/io.github.monaco-io.PulseBar.HelperService.plist').read_bytes())
assert agent['BundleProgram'] == 'Contents/MacOS/PulseBarHelperService'
assert 'UserName' not in agent and 'RunAtLoad' not in agent and 'KeepAlive' not in agent
assert (helper / agent['BundleProgram']).is_file()
for bundle in [app, helper]:
    assert (bundle / 'Contents/Resources/PulseBar_SpeedCore.bundle').is_dir()
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(bundle)], check=True)
print('Verified store sandbox, read-only service scope, private-code separation, privacy manifest, resources, and signatures.')
