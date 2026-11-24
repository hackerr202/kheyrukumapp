#!/usr/bin/env python3
"""Audit lib/screens and lib/widgets for remaining user-facing hardcoded English strings."""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCAN_DIRS = [ROOT / "lib" / "screens", ROOT / "lib" / "widgets"]

# Internal enum / DB / route / mime / dropdown value tokens that are not UI copy
IGNORED_VALUE_TOKENS = {
    "en",
    "ar",
    "am",
    "male",
    "female",
    "paid",
    "pending",
    "submitted",
    "approved",
    "rejected",
    "overdue",
    "present",
    "late",
    "absent",
    "excused",
    "admin",
    "director",
    "superadmin",
    "teacher",
    "parent",
    "student",
    "group",
    "direct",
    "all",
    "light",
    "dark",
    "system",
    "unknown",
    "active",
    "completed",
    "reviewed",
    "image",
    "audio",
    "voice",
    "video",
    "document",
    "file",
    "text",
    "announcement",
    "homework",
    "payment",
    "absence",
    "illness",
    "family_emergency",
    "school_exam",
    "travel",
    "other",
    "promote",
    "avatar",
    "suspend",
    "remove",
    "delete",
    "user",
    "jpg",
    "jpeg",
    "png",
    "webp",
    "m4a",
    "pdf",
    "mp4",
    "id",
    "created_at",
    "updated_at",
    "full_name",
    "halaqah_id",
    "student_id",
    "parent_id",
    "teacher_id",
    "sender_id",
    "receiver_id",
    "kheyrukum",
    "Kheyrukum",
    "KHEYRUKUM",
    "prayer-${DateTime.now().millisecondsSinceEpoch}",
}

UI_PARAM_NAMES = (
    "title",
    "subtitle",
    "label",
    "labelText",
    "hintText",
    "helperText",
    "tooltip",
    "message",
    "emptyTitle",
    "emptySubtitle",
    "actionLabel",
    "confirmText",
    "cancelText",
    "description",
    "text",
    "errorText",
    "semanticLabel",
    "badgeText",
)

TEXT_WIDGET_RE = re.compile(
    r"""(?:const\s+)?Text\s*\(\s*(['"])((?:\\.|(?!\1).)*)\1"""
)
TEXT_SPAN_RE = re.compile(
    r"""(?:const\s+)?TextSpan\s*\(\s*text\s*:\s*(['"])((?:\\.|(?!\1).)*)\1"""
)
PARAM_RE = re.compile(
    r"""\b(?:""" + "|".join(UI_PARAM_NAMES) + r""")\s*:\s*(?:const\s+)?(['"])((?:\\.|(?!\1).)*)\1"""
)
CHIP_OR_DIALOG_RE = re.compile(
    r"""\b(?:SnackBar|AlertDialog|Chip|Badge)\s*\([^)]*?\bcontent\s*:\s*(?:const\s+)?Text\s*\(\s*(['"])((?:\\.|(?!\1).)*)\1"""
)
RETURN_LITERAL_RE = re.compile(
    r"""^\s*return\s+\(?(['"])([A-Za-z][^'"]*)\1(?:\s*,|\s*\)\s*;|\s*;)"""
)
TERNARY_UI_RE = re.compile(
    r"""(?:\?|:)\s*(?:const\s+)?(['"])([A-Za-z][^'"\n]{1,120})\1"""
)

NON_ENGLISH_RE = re.compile(r"[^\x00-\x7F]")
PURE_INTERP_RE = re.compile(r"^(?:\$\{?[\w.]+\}?|\s|[0-9:/\-.,%+|()•·—–!?#])*$")


def strip_comments(line: str) -> str:
    in_sq = False
    in_dq = False
    escaped = False
    for idx, ch in enumerate(line):
        if escaped:
            escaped = False
            continue
        if ch == "\\":
            escaped = True
            continue
        if ch == "'" and not in_dq:
            in_sq = not in_sq
        elif ch == '"' and not in_sq:
            in_dq = not in_dq
        elif ch == "/" and not in_sq and not in_dq and idx + 1 < len(line) and line[idx + 1] == "/":
            return line[:idx]
    return line


def is_user_facing_english(raw: str, line: str) -> bool:
    s = raw.strip()
    if not s or len(s) < 2:
        return False
    if s in IGNORED_VALUE_TOKENS:
        return False
    if s.startswith(("http://", "https://", "package:", "assets/", "lib/", "voice/", "chat/", "audio/", "image/")):
        return False
    if "debugPrint(" in line or "print(" in line or "RegExp(" in line:
        return False
    if "DateFormat(" in line and not re.search(r"[A-Za-z]{4,}", s):
        return False
    if "fontFamily" in line:
        return False
    if "DropdownMenuItem(" in line and s.islower():
        return False
    if "value:" in line and s.islower():
        return False
    if "extension:" in line or "storagePath:" in line or "mediaMimeType:" in line:
        return False
    if "['" in s or '["' in s:
        return False
    if NON_ENGLISH_RE.search(s):
        return False
    if PURE_INTERP_RE.match(s):
        return False
    if re.fullmatch(r"[a-z][a-z0-9_]*", s) and ("_" in s or "Case" in line or "case " in line):
        return False
    if s in {"yyyy-MM-dd", "HH:mm", "MMM d", "MMM d, y", "dd/MM/yyyy", "EEE", "MMM"}:
        return False
    # Exempt formal Quranic/Islamic brand name only in splash/auth hero header? No, audit shows true literals!
    without_interp = re.sub(r"\$\{[^}]+\}|\$[A-Za-z_]\w*", " ", s)
    return bool(re.search(r"[A-Za-z]{2,}", without_interp))


def scan_file(path: pathlib.Path) -> list[tuple[int, str, str]]:
    hits: list[tuple[int, str, str]] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    for lineno, raw_line in enumerate(lines, start=1):
        line = strip_comments(raw_line)
        if not line.strip() or line.lstrip().startswith(("import ", "export ", "part ")):
            continue
        if "debugPrint(" in line or "assert(" in line or "throw Exception(" in line:
            continue
        window = line
        if lineno < len(lines) and re.search(r"(?:Text|TextSpan|\b(?:" + "|".join(UI_PARAM_NAMES) + r")\s*:)\s*\(?\s*$", line):
            window = line + " " + strip_comments(lines[lineno]).strip()

        seen_on_line: set[str] = set()
        for regex in (TEXT_WIDGET_RE, TEXT_SPAN_RE, PARAM_RE, CHIP_OR_DIALOG_RE, RETURN_LITERAL_RE, TERNARY_UI_RE):
            for match in regex.finditer(window):
                literal = match.group(2)
                if literal in seen_on_line:
                    continue
                if is_user_facing_english(literal, window):
                    if re.search(r"\bcase\s+['\"]", line):
                        continue
                    seen_on_line.add(literal)
                    hits.append((lineno, literal, raw_line.strip()))
    return hits


def main() -> int:
    total = 0
    for scan_dir in SCAN_DIRS:
        if not scan_dir.exists():
            continue
        for dart_file in sorted(scan_dir.rglob("*.dart")):
            hits = scan_file(dart_file)
            if hits:
                rel = dart_file.relative_to(ROOT).as_posix()
                print(f"{rel}: {len(hits)}")
                for lineno, literal, ctx in hits:
                    print(f"  L{lineno}: {literal!r}  | {ctx[:110]}")
                total += len(hits)
    print(f"\nTOTAL_UI_LITERALS={total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
