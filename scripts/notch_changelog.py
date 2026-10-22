"""Rebuild the release list on agent-notch/changelog/ from Agent Notch Pro's CHANGELOG.md.

Usage: python3 scripts/notch_changelog.py ~/agent-notch-pro/CHANGELOG.md
Everything between the CHANGELOG-START and CHANGELOG-END markers is replaced.
"""
import datetime
import html
import re
import sys
from pathlib import Path

PAGE = Path(__file__).resolve().parent.parent / "agent-notch" / "changelog" / "index.html"
FREE_VERSION = "1.4.3"  # free (open-source) build; Pro releases above it are Pro-only


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    return re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)


def releases(md):
    out = []
    for block in re.split(r"^## ", md, flags=re.M)[1:]:
        head, _, body = block.partition("\n")
        m = re.match(r"\[(\d+\.\d+\.\d+)\] - (\d{4}-\d{2}-\d{2})", head)
        if not m:
            continue
        sections, items = [], None
        for line in body.splitlines():
            if line.startswith("### "):
                items = []
                sections.append((line[4:].strip(), items))
            elif line.startswith("- ") and items is not None:
                items.append(line[2:].strip())
            elif line.startswith("  ") and items:
                items[-1] += " " + line.strip()
        out.append((m.group(1), m.group(2), sections))
    return out


def nice(date):
    d = datetime.date.fromisoformat(date)
    return f"{d.day} {d.strftime('%B %Y')}"


def render(rels):
    parts = []
    for ver, date, sections in rels:
        tag = "" if tuple(map(int, ver.split("."))) <= tuple(map(int, FREE_VERSION.split("."))) else " · Pro"
        parts.append(f"      <h2>{ver}</h2>\n      <p class=\"updated\">{nice(date)}{tag}</p>")
        for name, items in sections:
            lis = "\n".join(f"        <li>{inline(i)}</li>" for i in items)
            parts.append(f"      <h3>{html.escape(name)}</h3>\n      <ul>\n{lis}\n      </ul>")
    return "\n".join(parts)


def main():
    rels = releases(Path(sys.argv[1]).expanduser().read_text(encoding="utf-8"))
    page = PAGE.read_text(encoding="utf-8")
    start, end = "<!-- CHANGELOG-START -->", "<!-- CHANGELOG-END -->"
    a, b = page.index(start) + len(start), page.index(end)
    latest = rels[0]
    page = page[:a] + "\n" + render(rels) + "\n      " + page[b:]
    page = re.sub(r'<p class="updated">Latest: [^<]*</p>',
                  f'<p class="updated">Latest: Pro {latest[0]}, {nice(latest[1])} · Free {FREE_VERSION}</p>', page, count=1)
    PAGE.write_text(page, encoding="utf-8")
    print(f"{len(rels)} releases, latest {latest[0]}")


if __name__ == "__main__":
    main()
