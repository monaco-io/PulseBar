#!/usr/bin/env python3
"""Validate the sole DMG asset and its separately published signed update feed."""
import base64
import hashlib
import pathlib
import plistlib
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


def verify(directory, tag, feed_path=None):
    directory = pathlib.Path(directory)
    assert {entry.name for entry in directory.iterdir()} == {"PulseBar.dmg"}, "Release must contain only PulseBar.dmg"
    dmg = directory / "PulseBar.dmg"
    feed_path = pathlib.Path(feed_path) if feed_path else directory.parent / "updates/appcast.xml"
    feed = feed_path.read_text()
    assert re.search(r"<!-- sparkle-signatures:\s+edSignature: [A-Za-z0-9+/=]+\s+length: [0-9]+\s+-->\s*$", feed), "Missing feed signature"
    root = ET.fromstring(feed)
    items = root.findall("channel/item")
    assert len(items) == 1, "Expected one universal stable update"
    item = items[0]
    sparkle = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
    enclosure = item.find("enclosure")
    assert enclosure is not None
    assert enclosure.attrib["url"] == f"https://github.com/monaco-io/PulseBar/releases/download/{tag}/PulseBar.dmg"
    assert int(enclosure.attrib["length"]) == dmg.stat().st_size
    assert len(base64.b64decode(enclosure.attrib[f"{sparkle}edSignature"], validate=True)) == 64
    with tempfile.TemporaryDirectory(prefix="pulsebar-verify-") as temporary:
        mount = pathlib.Path(temporary) / "mount"
        mount.mkdir()
        subprocess.run(["hdiutil", "attach", "-quiet", "-readonly", "-nobrowse", "-mountpoint", str(mount), str(dmg.resolve())], check=True)
        try:
            app = mount / "PulseBar.app"
            info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
            assert (mount / "Applications").is_symlink()
            assert (mount / "Applications").readlink() == pathlib.Path("/Applications")
            assert (app / "Contents/Frameworks/Sparkle.framework").is_dir()
            assert (app / "Contents/Resources/PulseBar_SpeedCore.bundle").is_dir()
            subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
            subprocess.run(["lipo", str(app / "Contents/MacOS/PulseBar"), "-verify_arch", "arm64", "x86_64"], check=True)
        finally:
            subprocess.run(["hdiutil", "detach", "-quiet", str(mount)], check=True)
    assert tag == f'v{info["CFBundleShortVersionString"]}'
    assert info["CFBundleIdentifier"] == "local.apple-widget.NetSpeed"
    assert info["SUFeedURL"] == "https://raw.githubusercontent.com/monaco-io/PulseBar/codex/updates/appcast.xml"
    assert info["SURequireSignedFeed"] and info["SUVerifyUpdateBeforeExtraction"]
    assert len(base64.b64decode(info["SUPublicEDKey"], validate=True)) == 32
    assert item.findtext(f"{sparkle}version") == info["CFBundleVersion"]
    assert item.findtext(f"{sparkle}shortVersionString") == info["CFBundleShortVersionString"]
    assert item.findtext(f"{sparkle}minimumSystemVersion") == info["LSMinimumSystemVersion"]
    print(f"Verified {tag} ({info['CFBundleVersion']}): sole DMG asset, mounted app and signed feed agree")
    print(f"DMG SHA-256: {hashlib.sha256(dmg.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    verify(*sys.argv[1:])
