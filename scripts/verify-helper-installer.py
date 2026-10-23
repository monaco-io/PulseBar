#!/usr/bin/env python3
"""Inspect the actual installer payload; never install or register the helper."""
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

package = pathlib.Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='pulsebar-installer-verify-') as directory:
    expanded = pathlib.Path(directory) / 'expanded'
    subprocess.run(['pkgutil', '--expand-full', str(package), str(expanded)], check=True)
    distribution = ET.parse(expanded / 'Distribution').getroot()
    domains = distribution.find('domains')
    assert domains is not None and domains.attrib == {
        'enable_anywhere': 'false', 'enable_currentUserHome': 'true', 'enable_localSystem': 'false'
    }, 'Installer must stay inside the current user home directory'
    assert distribution.find('options').get('require-scripts') == 'false'
    # Only the helper can be delivered: no main app, shell scripts or launch daemon.
    bundles = list(expanded.glob('*.pkg/Payload/Applications/*.app'))
    assert len(bundles) == 1 and bundles[0].name == 'PulseBar Helper.app'
    helper = bundles[0]
    info = plistlib.loads((helper / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == 'io.github.monaco-io.PulseBar.Helper'
    if len(sys.argv) > 2:
        source = pathlib.Path(sys.argv[2])
        expected = {p.relative_to(source) for p in source.rglob('*') if p.is_file() or p.is_symlink()}
        actual = {p.relative_to(helper) for p in helper.rglob('*') if p.is_file() or p.is_symlink()}
        assert actual == expected, 'Installer payload added or omitted helper files'
        for relative in expected:
            assert (helper / relative).read_bytes() == (source / relative).read_bytes(), f'Installer changed {relative}'
    component = helper.parent.parent.parent
    package_info = ET.parse(component / 'PackageInfo').getroot()
    assert package_info.find('scripts') is None, 'Installer scripts are not allowed'
    assert not (component / 'Scripts').exists()
    payload = component / 'Payload'
    assert [p.name for p in payload.iterdir()] == ['Applications']
    assert [p.name for p in (payload / 'Applications').iterdir()] == ['PulseBar Helper.app']
    for executable in ['PulseBarHelper', 'PulseBarHelperService']:
        architectures = subprocess.check_output(['xcrun', 'lipo', '-archs', str(helper / 'Contents/MacOS' / executable)], text=True).split()
        assert {'arm64', 'x86_64'} <= set(architectures), 'Missing helper architecture'
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(helper)], check=True)
    # productbuild normalizes zh_CN resource folders to zh-Hans in the product.
    for language in ['en.lproj', 'zh-Hans.lproj']:
        assert (expanded / 'Resources' / language / 'Welcome.html').is_file(), 'Missing localized installer page; resources: ' + str([str(p.relative_to(expanded)) for p in expanded.rglob('*.html')])
        assert (expanded / 'Resources' / language / 'Conclusion.html').is_file()
print('Verified universal Helper-only installer, per-user destination, no scripts, bilingual instructions and payload signatures.')
