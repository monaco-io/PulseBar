#!/usr/bin/env python3
"""Regenerate the checked-in Finder layout; requires ds-store==1.3.3.

Packaging copies the template, so release builds need no Python dependency.
The template contains only relative item names and view settings.
Format reference: https://ds-store.readthedocs.io/en/latest/
"""
import pathlib

from ds_store import DSStore


destination = pathlib.Path(__file__).resolve().parent.parent / "Resources/DMG/FinderLayout.dsstore"
destination.parent.mkdir(parents=True, exist_ok=True)
with DSStore.open(str(destination), "w+") as store:
    store["."]["vSrn"] = ("long", 1)
    store["."]["icvl"] = ("type", b"icnv")
    store["."]["bwsp"] = {
        "WindowBounds": "{{160, 120}, {800, 440}}",
        "ShowToolbar": False,
        "ShowSidebar": False,
        "ContainerShowSidebar": False,
        "ShowStatusBar": False,
        "ShowPathbar": False,
        "ShowTabView": False,
        "PreviewPaneVisibility": False,
        "SidebarWidth": 0,
    }
    store["."]["icvp"] = {
        "viewOptionsVersion": 1,
        "backgroundType": 0,
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "gridSpacing": 100.0,
        "arrangeBy": "none",
        "showIconPreview": True,
        "showItemInfo": False,
        "labelOnBottom": True,
        "textSize": 16.0,
        "iconSize": 256.0,
        "scrollPositionX": 0.0,
        "scrollPositionY": 0.0,
    }
    store["PulseBar.app"]["Iloc"] = (200, 200)
    store["Applications"]["Iloc"] = (600, 200)
