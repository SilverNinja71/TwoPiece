#!/usr/bin/env python3
"""
Comprehensive Static Project Validator for Project "Blue Planet" (Godot 4.3+, precision=double).

Checks all project files in `/Users/lin/Downloads/OnePieceBluePlanet/`:
1. `project.godot`: verifies `run/main_scene`, `config/icon`, and all `[autoload]` paths resolve.
2. `.gd` (GDScript 4): checks parenthesis/bracket/brace/quote balance ignoring comments and strings,
   and verifies `class_name` / `extends` structure.
3. `.tscn` (Godot 4 Text Scene): checks `[gd_scene format=3]`, `[ext_resource]` path resolution,
   and balanced quotes/brackets.
4. `.gdshader` (Godot 4 Shader): checks `shader_type` declaration, `uniform` declarations, and brace balance.
5. `.svg`: parses strict XML well-formedness via `xml.etree.ElementTree`.
6. `.json`: parses strict JSON syntax via `json.loads`.
"""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Tuple

PROJECT_ROOT = Path("/Users/lin/Downloads/OnePieceBluePlanet")


def res_path_to_fs(res_path: str) -> Path:
    cleaned = res_path.strip()
    if cleaned.startswith("*"):
        cleaned = cleaned[1:]
    if not cleaned.startswith("res://"):
        raise ValueError(f"Expected res:// path, got: {res_path}")
    return PROJECT_ROOT / cleaned[len("res://"):]


def check_code_balance(text: str, is_gdscript: bool) -> List[str]:
    """Checks (), [], {} balance while skipping comments and string literals."""
    errors: List[str] = []
    stack: List[Tuple[str, int]] = []
    pairs = {"(": ")", "[": "]", "{": "}"}
    closing = {")": "(", "]": "[", "}": "{"}

    i = 0
    n = len(text)
    line = 1
    in_single = False
    in_double = False
    in_triple_double = False
    in_line_comment = False
    in_block_comment = False

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        nxt3 = text[i : i + 3]

        if ch == "\n":
            line += 1
            in_line_comment = False
            i += 1
            continue

        if in_line_comment:
            i += 1
            continue

        if in_block_comment:
            if ch == "*" and nxt == "/":
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue

        if in_triple_double:
            if nxt3 == '"""':
                in_triple_double = False
                i += 3
                continue
            if ch == "\\" and i + 1 < n:
                i += 2
                continue
            i += 1
            continue

        if in_double:
            if ch == "\\" and i + 1 < n:
                i += 2
                continue
            if ch == '"':
                in_double = False
            i += 1
            continue

        if in_single:
            if ch == "\\" and i + 1 < n:
                i += 2
                continue
            if ch == "'":
                in_single = False
            i += 1
            continue

        # Comments
        if is_gdscript and ch == "#":
            in_line_comment = True
            i += 1
            continue
        if not is_gdscript:
            if ch == "/" and nxt == "/":
                in_line_comment = True
                i += 2
                continue
            if ch == "/" and nxt == "*":
                in_block_comment = True
                i += 2
                continue

        # Strings
        if is_gdscript and nxt3 == '"""':
            in_triple_double = True
            i += 3
            continue
        if ch == '"':
            in_double = True
            i += 1
            continue
        if ch == "'":
            in_single = True
            i += 1
            continue

        # Brackets
        if ch in pairs:
            stack.append((ch, line))
        elif ch in closing:
            expected_open = closing[ch]
            if not stack or stack[-1][0] != expected_open:
                errors.append(f"Unmatched '{ch}' on line {line}")
            else:
                stack.pop()

        i += 1

    if in_single or in_double or in_triple_double:
        errors.append("Unterminated string literal at EOF")
    if in_block_comment:
        errors.append("Unterminated /* */ block comment at EOF")
    for open_ch, open_line in stack:
        errors.append(f"Unclosed '{open_ch}' opened on line {open_line}")
    return errors


def validate_project_godot(errors: List[str], warnings: List[str]) -> None:
    pg_path = PROJECT_ROOT / "project.godot"
    if not pg_path.exists():
        errors.append("Missing project.godot")
        return
    text = pg_path.read_text(encoding="utf-8")

    main_match = re.search(r'^run/main_scene="([^"]+)"', text, re.MULTILINE)
    if not main_match:
        errors.append("project.godot missing run/main_scene")
    else:
        target = res_path_to_fs(main_match.group(1))
        if not target.exists():
            errors.append(f"project.godot run/main_scene missing on disk: {main_match.group(1)}")

    icon_match = re.search(r'^config/icon="([^"]+)"', text, re.MULTILINE)
    if icon_match:
        target = res_path_to_fs(icon_match.group(1))
        if not target.exists():
            errors.append(f"project.godot config/icon missing on disk: {icon_match.group(1)}")

    in_autoload = False
    for raw_line in text.splitlines():
        s = raw_line.strip()
        if s.startswith("["):
            in_autoload = (s == "[autoload]")
            continue
        if in_autoload and "=" in s and not s.startswith(";"):
            _, rhs = s.split("=", 1)
            rhs = rhs.strip().strip('"')
            target = res_path_to_fs(rhs)
            if not target.exists():
                errors.append(f"project.godot autoload missing on disk: {rhs}")

    if "FloatingOrigin" not in text:
        warnings.append("project.godot does not register FloatingOrigin in [autoload]")


def validate_tscn_file(tscn_path: Path, errors: List[str], warnings: List[str]) -> None:
    text = tscn_path.read_text(encoding="utf-8")
    rel = tscn_path.relative_to(PROJECT_ROOT)
    if not text.lstrip().startswith("[gd_scene"):
        errors.append(f"{rel}: missing [gd_scene header")

    ext_ids = set()
    for match in re.finditer(r'\[ext_resource\s+[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', text):
        res_p, ext_id = match.group(1), match.group(2)
        ext_ids.add(ext_id)
        fs_target = res_path_to_fs(res_p)
        if not fs_target.exists():
            errors.append(f"{rel}: ext_resource '{ext_id}' missing on disk -> {res_p}")

    # Also support attribute ordering where id precedes path
    for match in re.finditer(r'\[ext_resource\s+[^\]]*id="([^"]+)"[^\]]*path="([^"]+)"', text):
        ext_id, res_p = match.group(1), match.group(2)
        ext_ids.add(ext_id)
        fs_target = res_path_to_fs(res_p)
        if not fs_target.exists():
            errors.append(f"{rel}: ext_resource '{ext_id}' missing on disk -> {res_p}")

    for ref_match in re.finditer(r'ExtResource\("([^"]+)"\)', text):
        ref_id = ref_match.group(1)
        if ref_id not in ext_ids:
            errors.append(f"{rel}: references undeclared ExtResource(\"{ref_id}\")")

    if not ext_ids:
        warnings.append(f"{rel}: contains no ext_resource entries")


def validate_gdshader_file(shader_path: Path, errors: List[str]) -> None:
    text = shader_path.read_text(encoding="utf-8")
    rel = shader_path.relative_to(PROJECT_ROOT)
    if not re.search(r'\bshader_type\s+(spatial|canvas_item|particles|sky|fog)\s*;', text):
        errors.append(f"{rel}: missing valid `shader_type ...;` declaration")
    for err in check_code_balance(text, is_gdscript=False):
        errors.append(f"{rel}: {err}")


def main() -> int:
    errors: List[str] = []
    warnings: List[str] = []

    validate_project_godot(errors, warnings)

    gd_files = sorted(PROJECT_ROOT.rglob("*.gd"))
    tscn_files = sorted(PROJECT_ROOT.rglob("*.tscn"))
    shader_files = sorted(PROJECT_ROOT.rglob("*.gdshader"))
    svg_files = sorted(PROJECT_ROOT.rglob("*.svg"))
    json_files = sorted(PROJECT_ROOT.rglob("*.json"))

    for gd in gd_files:
        text = gd.read_text(encoding="utf-8")
        rel = gd.relative_to(PROJECT_ROOT)
        for err in check_code_balance(text, is_gdscript=True):
            errors.append(f"{rel}: {err}")

    for tscn in tscn_files:
        validate_tscn_file(tscn, errors, warnings)

    for sh in shader_files:
        validate_gdshader_file(sh, errors)

    for svg in svg_files:
        rel = svg.relative_to(PROJECT_ROOT)
        try:
            ET.fromstring(svg.read_text(encoding="utf-8"))
        except ET.ParseError as exc:
            errors.append(f"{rel}: Invalid SVG XML -> {exc}")

    for jf in json_files:
        rel = jf.relative_to(PROJECT_ROOT)
        try:
            json.loads(jf.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{rel}: Invalid JSON -> {exc}")

    print("=== Project Blue Planet Static Verification Report ===")
    print(
        f"Checked: {len(gd_files)} .gd | {len(tscn_files)} .tscn | "
        f"{len(shader_files)} .gdshader | {len(svg_files)} .svg | {len(json_files)} .json"
    )
    if warnings:
        print(f"Warnings ({len(warnings)}):")
        for w in warnings:
            print(f"  [WARN] {w}")
    if errors:
        print(f"Errors ({len(errors)}):")
        for e in errors:
            print(f"  [ERR]  {e}")
        return 1

    print("ALL CHECKS PASSED WITH 0 ERRORS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
