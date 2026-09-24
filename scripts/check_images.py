#!/usr/bin/env python3
"""Check that every image in the Obsidian vault renders on GitHub and in Obsidian.

Run from the repo root: python3 scripts/check_images.py
Exits 1 and lists each problem if any image breaks the rules in CLAUDE.md.
"""
import pathlib
import re
import sys
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent / "Obsidian Vault"
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".webp"}

problems = []
referenced = set()
wikilinked_names = set()

for md in ROOT.rglob("*.md"):
    if ".obsidian" in md.parts:
        continue
    for n, line in enumerate(md.read_text().splitlines(), 1):
        where = f"{md.relative_to(ROOT)}:{n}"
        for m in re.finditer(r"!\[\[([^\]|]+)", line):
            wikilinked_names.add(pathlib.Path(m.group(1)).name)
            problems.append(f"{where}: Obsidian wikilink embed, use ![alt](path)")
        for m in re.finditer(r"!\[([^\]]*)\]\(([^)]+)\)", line):
            alt, path = m.groups()
            target = (md.parent / urllib.parse.unquote(path.strip("<>"))).resolve()
            if not target.exists():
                problems.append(f"{where}: image not found: {path}")
            referenced.add(target)
            if not alt.strip() or alt.strip().isdigit() or "|" in alt:
                problems.append(f"{where}: alt text missing, numeric or contains '|'")
        if re.match(r"[ \t]+!\[", line) or re.search(r"\S.*!\[", line):
            problems.append(f"{where}: image must be alone on its line with no indentation")

for img in ROOT.rglob("*"):
    if img.suffix.lower() not in IMAGE_EXTS or ".obsidian" in img.parts:
        continue
    rel = img.relative_to(ROOT)
    if not re.fullmatch(r"[a-z0-9-]+\.[a-z]+", img.name):
        problems.append(f"{rel}: filename must be lowercase ASCII letters, digits and hyphens")
    if img.parent.name != "Screenshots":
        problems.append(f"{rel}: image must live in an Offense/Screenshots or Defense/Screenshots folder")
    if img.resolve() not in referenced and img.name not in wikilinked_names:
        problems.append(f"{rel}: not referenced by any note")

print("\n".join(problems) or "OK: all images follow the format")
sys.exit(1 if problems else 0)
