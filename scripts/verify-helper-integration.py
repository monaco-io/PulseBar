#!/usr/bin/env python3
"""Exercise the sandboxed client and launchd service with per-build signature pins.

Uses DEBUG-only overrides, a unique Mach service, and a temporary launch agent.
Never registers the production helper or changes the installed app.
"""
import json
import argparse
import os
import pathlib
import plistlib
import re
import shutil
import subprocess
import tempfile
import uuid
from concurrent.futures import ThreadPoolExecutor

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILD = ROOT / 'dist/app-store-debug'
SERVICE = BUILD / 'PulseBar Helper.app/Contents/MacOS/PulseBarHelperService'
BASE_APP = BUILD / 'PulseBar.app'


def run(*args, **kwargs):
    return subprocess.run(args, text=True, capture_output=True, check=True, **kwargs)


def signature(path):
    output = run('codesign', '-dv', '--verbose=4', str(path)).stderr
    return re.search(r'^CDHash=(\w+)$', output, re.MULTILINE)[1]


def requirement(value):
    return f'cdhash H"{value}"'


def sample(app, service_name, service_hash, count=3):
    env = dict(os.environ, PULSEBAR_HELPER_TEST_SERVICE=service_name)
    env.pop('PULSEBAR_HELPER_TEST_SERVICE_REQUIREMENT', None)
    if service_hash is not None:
        env['PULSEBAR_HELPER_TEST_SERVICE_REQUIREMENT'] = requirement(service_hash)
    result = subprocess.run([str(app / 'Contents/MacOS/PulseBar'), '--sample', str(count)],
                            env=env, capture_output=True, text=True, timeout=30)
    rows = [json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')]
    assert len(rows) == count, f'Incomplete samples: {result.stderr[-2000:]}'
    for row in rows:
        assert not (set(row.get('errors', {})) - {'apps'}), row.get('errors')
        assert row['memory']['totalBytes'] > 0 and 'interfaces' in row and 'disk' in row
    assert rows[-1]['cpu'] is not None, 'Basic CPU monitoring stopped'
    return rows


def disconnected(rows):
    assert all(not row['helperConnected'] for row in rows), 'Untrusted helper connection accepted'
    assert all('apps' in row.get('errors', {}) and not row['temperatures'] for row in rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--identity', help='Existing Developer ID identity to exercise production certificate requirements')
    options = parser.parse_args()
    service_name = '45Y6A23PTN.io.github.monaco-io.PulseBar.HelperService.Test' + uuid.uuid4().hex
    domain = f'gui/{os.getuid()}'
    report = {}
    agent_plist = BUILD / 'PulseBar Helper.app/Contents/Library/LaunchAgents/io.github.monaco-io.PulseBar.HelperService.v2.plist'
    production_agent = plistlib.loads(agent_plist.read_bytes())
    with tempfile.TemporaryDirectory(prefix='pulsebar-helper-integration-') as tmp:
        tmp = pathlib.Path(tmp)
        app = tmp / 'PulseBar.app'
        shutil.copytree(BASE_APP, app)
        # Keep test preferences/containers apart from the installed store app.
        # Changing between ad-hoc and Developer ID ownership of one container
        # otherwise correctly asks the user for consent on recent macOS.
        info_path = app / 'Contents/Info.plist'
        info = plistlib.loads(info_path.read_bytes())
        client_id = info['CFBundleIdentifier'] + '.Integration' + ('Signed' if options.identity else 'AdHoc')
        info['CFBundleIdentifier'] = client_id
        info_path.write_bytes(plistlib.dumps(info))
        entitlements = plistlib.loads((ROOT / 'Resources/AppStore/PulseBar.entitlements').read_bytes())
        entitlements['com.apple.security.temporary-exception.mach-lookup.global-name'] = [service_name]
        ent = tmp / 'entitlements.plist'
        ent.write_bytes(plistlib.dumps(entitlements))
        identity = options.identity or '-'
        run('codesign', '--force', '--sign', identity, '--identifier', client_id,
            '--entitlements', str(ent), str(app))
        service = SERVICE
        if options.identity:
            helper = tmp / 'PulseBar Helper.app'
            shutil.copytree(BUILD / 'PulseBar Helper.app', helper)
            service = helper / 'Contents/MacOS/PulseBarHelperService'
            run('codesign', '--force', '--sign', identity, '--identifier', 'io.github.monaco-io.PulseBar.HelperService', str(service))
            run('codesign', '--force', '--sign', identity, str(helper))
        client_hash = signature(app)
        service_hash = None if options.identity else signature(service)
        service_env = {'PULSEBAR_HELPER_TEST_SERVICE': service_name}
        if not options.identity:
            service_env['PULSEBAR_HELPER_TEST_CLIENT_REQUIREMENT'] = requirement(client_hash)
        else:
            service_env['PULSEBAR_HELPER_TEST_CLIENT_ID'] = client_id
        agent = tmp / 'agent.plist'
        agent.write_bytes(plistlib.dumps({
            'Label': service_name,
            'ProgramArguments': [str(service)],
            'MachServices': {service_name: True},
            'ProcessType': production_agent['ProcessType'],
            'EnvironmentVariables': service_env,
        }))
        bootstrapped = False
        try:
            run('launchctl', 'bootstrap', domain, str(agent))
            bootstrapped = True
            rows = sample(app, service_name, service_hash)
            assert all(row['helperConnected'] and not row.get('errors') for row in rows), rows[-1].get('errors')
            assert all(row['apps']['sampledProcesses'] > 0 for row in rows)
            assert rows[-1]['apps']['topCPU'] and rows[-1]['apps']['topMemory']
            report['trusted_connection'] = {
                'signing': 'Developer ID production requirements' if options.identity else 'Exact debug code hashes',
                'samples': len(rows), 'processes': rows[-1]['apps']['sampledProcesses'],
                'temperature_components': [r['component'] for r in rows[-1]['temperatures']],
                'process_type': production_agent['ProcessType'],
            }

            # Short-lived clients reproduce reconnects after a timeout. All
            # must receive fresh readings without spawning competing scans.
            with ThreadPoolExecutor(max_workers=3) as clients:
                futures = [clients.submit(sample, app, service_name, service_hash, 2) for _ in range(3)]
                for future in futures:
                    reconnect = future.result()
                    assert all(row['helperConnected'] and not row.get('errors') for row in reconnect)
                    assert reconnect[-1]['apps']['topCPU'] and reconnect[-1]['apps']['topMemory']
            report['concurrent_reconnections'] = 3

            untrusted = tmp / 'Untrusted.app'
            shutil.copytree(app, untrusted)
            untrusted_info = dict(info, CFBundleIdentifier='io.github.monaco-io.PulseBar.IntegrationUntrusted')
            (untrusted / 'Contents/Info.plist').write_bytes(plistlib.dumps(untrusted_info))
            run('codesign', '--force', '--sign', '-', '--identifier', 'test.untrusted.PulseBar',
                '--entitlements', str(ent), str(untrusted))
            assert signature(untrusted) != client_hash
            disconnected(sample(untrusted, service_name, service_hash, 2))
            report['untrusted_client_rejected'] = True

            disconnected(sample(app, service_name, '0' * 40, 2))
            report['untrusted_service_rejected'] = True
        finally:
            if bootstrapped:
                run('launchctl', 'bootout', f'{domain}/{service_name}')
        disconnected(sample(app, service_name, service_hash, 2))
        report['missing_helper_keeps_basic_monitoring'] = True
    output = ROOT / ('.build/helper-signed-integration-report.json' if options.identity else '.build/helper-integration-report.json')
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(output.read_text())


if __name__ == '__main__':
    main()
