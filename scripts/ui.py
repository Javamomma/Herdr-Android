#!/usr/bin/env python3
"""Looks in a `uiautomator dump` for a node whose text or description is the
label (with --has: contains it). Prints the node's centre; exit 1 if none."""
import re
import sys
import xml.etree.ElementTree as ET

args = [a for a in sys.argv[1:] if a != "--has"]
has = "--has" in sys.argv
path, label = args
for node in ET.parse(path).iter("node"):
    for value in (node.get("text") or "", node.get("content-desc") or ""):
        if value == label or (has and label in value):
            x1, y1, x2, y2 = map(int, re.findall(r"\d+", node.get("bounds")))
            print((x1 + x2) // 2, (y1 + y2) // 2)
            sys.exit(0)
sys.exit(1)
