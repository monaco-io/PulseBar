#!/usr/bin/env python3
"""Fail before release work if a tag is inconsistent, already published, or a downgrade."""
import json
import plistlib
import re
import subprocess
import sys
import urllib.request
import xml.etree.ElementTree as ET

tag = sys.argv[1]
if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", tag):
    sys.exit("Stable release tags must use vMAJOR.MINOR.PATCH")
with open("Resources/Info.plist", "rb") as file:
    info = plistlib.load(file)
if tag != "v" + info["CFBundleShortVersionString"]:
    sys.exit("Tag does not match CFBundleShortVersionString")
build = int(info["CFBundleVersion"])
releases = json.loads(subprocess.check_output([
    "gh", "api", "--paginate", "--slurp", "repos/monaco-io/PulseBar/releases?per_page=100"
]))
stable = []
for page in releases:
    for release in page:
        if release["tag_name"] == tag:
            sys.exit("Release already exists; inspect it before retrying. Published assets must not be overwritten.")
        if not release["draft"] and not release["prerelease"]:
            stable.append(release)
version = tuple(map(int, tag[1:].split(".")))
for release in stable:
    old_tag = release["tag_name"]
    if re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", old_tag):
        if version <= tuple(map(int, old_tag[1:].split("."))):
            sys.exit("Stable release version must increase")
if stable:
    with urllib.request.urlopen(info["SUFeedURL"], timeout=30) as response:
        root = ET.fromstring(response.read())
    builds = [int(node.text) for node in root.findall(".//{http://www.andymatuschak.org/xml-namespaces/sparkle}version")]
    if not builds or build <= max(builds):
        sys.exit("CFBundleVersion must exceed the published feed's build number")
print(f"Version preflight passed: {tag} ({build})")
