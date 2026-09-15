#!/usr/bin/env python3
"""Reject inconsistent or incomplete artifacts before publishing a stable release."""
import base64
import hashlib
import pathlib
import plistlib
import re
import sys
import xml.etree.ElementTree as ET
import zipfile


def verify(directory, tag):
    directory = pathlib.Path(directory)
    required = {"PulseBar.dmg", "PulseBar.zip", "appcast.xml", "INSTALL.txt", "RELEASE_NOTES.md"}
    checksums = {}
    for line in (directory / "SHA256SUMS.txt").read_text().splitlines():
        digest, name = line.split("  ", 1)
        assert name in required and name not in checksums, "Unexpected/duplicate checksum entry"
        checksums[name] = digest
    assert checksums.keys() == required, "Incomplete checksums"
    for name, digest in checksums.items():
        assert re.fullmatch(r"[a-f0-9]{64}", digest)
        assert hashlib.sha256((directory / name).read_bytes()).hexdigest() == digest, f"Checksum mismatch: {name}"

    with zipfile.ZipFile(directory / "PulseBar.zip") as archive:
        assert archive.testzip() is None, "Corrupt archive"
        info = plistlib.loads(archive.read("PulseBar.app/Contents/Info.plist"))
        assert all(name.startswith("PulseBar.app/") for name in archive.namelist()), "Unexpected archive contents"
        assert any("Contents/Frameworks/Sparkle.framework/" in name for name in archive.namelist()), "Missing updater"
        assert any("Contents/Resources/PulseBar_SpeedCore.bundle/" in name for name in archive.namelist()), "Missing translations"

    base_url = "https://github.com/monaco-io/PulseBar/releases"
    assert tag == f'v{info["CFBundleShortVersionString"]}', "Tag/version mismatch"
    assert info["CFBundleVersion"].isdigit() and int(info["CFBundleVersion"]) > 0
    assert info["CFBundleIdentifier"] == "local.apple-widget.NetSpeed", "Existing installs must retain their identity"
    assert info["SUFeedURL"] == f"{base_url}/latest/download/appcast.xml"
    assert info["SURequireSignedFeed"] and info["SUVerifyUpdateBeforeExtraction"]
    assert len(base64.b64decode(info["SUPublicEDKey"], validate=True)) == 32
    feed = (directory / "appcast.xml").read_text()
    assert re.search(r"<!-- sparkle-signatures:\s+edSignature: [A-Za-z0-9+/=]+\s+length: [0-9]+\s+-->\s*$", feed), "Missing feed signature"
    root = ET.fromstring(feed)
    items = root.findall("channel/item")
    assert len(items) == 1, "Publish exactly one current, universal version"
    item = items[0]
    sparkle = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
    assert item.findtext(f"{sparkle}version") == info["CFBundleVersion"]
    assert item.findtext(f"{sparkle}shortVersionString") == info["CFBundleShortVersionString"]
    assert item.findtext(f"{sparkle}minimumSystemVersion") == info["LSMinimumSystemVersion"]
    enclosure = item.find("enclosure")
    assert enclosure is not None
    assert enclosure.attrib["url"] == f"{base_url}/download/{tag}/PulseBar.zip"
    assert int(enclosure.attrib["length"]) == (directory / "PulseBar.zip").stat().st_size
    assert len(base64.b64decode(enclosure.attrib[f"{sparkle}edSignature"], validate=True)) == 64
    print(f"Verified {tag}, build {info['CFBundleVersion']}: complete assets, checksums, feed and bundle agree")


if __name__ == "__main__":
    verify(*sys.argv[1:])
