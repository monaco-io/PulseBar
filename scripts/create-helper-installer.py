#!/usr/bin/env python3
"""Describe a per-user, script-free Helper installer for macOS Installer."""
import pathlib
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

stage, helper = map(pathlib.Path, sys.argv[1:])
info = plistlib.loads((helper / 'Contents/Info.plist').read_bytes())
version = info['CFBundleShortVersionString']
identity_source = pathlib.Path('Sources/HelperIPC/HelperProtocol.swift').read_text()
assert re.search(r'public static let version = "' + re.escape(version) + '"', identity_source), 'Helper version and download URL disagree'
components = [{
    'BundleHasStrictIdentifier': True,
    'BundleIsRelocatable': False,
    'BundleIsVersionChecked': True,
    'BundleOverwriteAction': 'upgrade',
    'RootRelativeBundlePath': 'Applications/PulseBar Helper.app',
}]
(stage / 'components.plist').write_bytes(plistlib.dumps(components))
distribution = ET.Element('installer-gui-script', minSpecVersion='2')
ET.SubElement(distribution, 'title').text = 'PulseBar Helper'
ET.SubElement(distribution, 'options', customize='never', hostArchitectures='arm64,x86_64', **{'require-scripts': 'false'})
ET.SubElement(distribution, 'domains', enable_anywhere='false', enable_currentUserHome='true', enable_localSystem='false')
allowed = ET.SubElement(ET.SubElement(distribution, 'volume-check'), 'allowed-os-versions')
ET.SubElement(allowed, 'os-version', min='13.0')
ET.SubElement(distribution, 'welcome', file='Welcome.html', **{'mime-type': 'text/html'})
ET.SubElement(distribution, 'conclusion', file='Conclusion.html', **{'mime-type': 'text/html'})
outline = ET.SubElement(distribution, 'choices-outline')
ET.SubElement(outline, 'line', choice='helper')
choice = ET.SubElement(distribution, 'choice', id='helper', title='PulseBar Helper', visible='false')
identifier = info['CFBundleIdentifier'] + '.pkg'
ET.SubElement(choice, 'pkg-ref', id=identifier)
ET.SubElement(distribution, 'pkg-ref', id=identifier, version=version, auth='none', onConclusion='none').text = 'HelperComponent.pkg'
ET.indent(distribution)
ET.ElementTree(distribution).write(stage / 'Distribution.xml', encoding='utf-8', xml_declaration=True)
