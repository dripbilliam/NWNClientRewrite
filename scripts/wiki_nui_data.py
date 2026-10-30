"""MediaWiki export -> bounded, asset-free stock NUI panels and native messages.

No HTTP, game process access, or client resource installation occurs here.
"""
from __future__ import annotations

import html
import json
import re
import struct
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

TOKEN = 0x6E770001
WINDOW_ID = "localwikireader"
MAX_SECTION_CHARS = 6000  # Presentation budget, not a claimed engine limit.


def split_fields(text: str) -> list[str]:
    """Split template/table fields without breaking nested links/templates."""
    result, start, braces, links, i = [], 0, 0, 0, 0
    while i < len(text):
        pair = text[i:i + 2]
        if pair == "{{":
            braces += 1
            i += 2
        elif pair == "}}" and braces:
            braces -= 1
            i += 2
        elif pair == "[[":
            links += 1
            i += 2
        elif pair == "]]" and links:
            links -= 1
            i += 2
        elif text[i] == "|" and not braces and not links:
            result.append(text[start:i])
            start = i + 1
            i += 1
        else:
            i += 1
    return result + [text[start:]]


def expand_templates(text: str, sources: dict[str, str], depth: int = 0) -> str:
    if depth > 8:
        return "[Nested template omitted]"
    result, i = [], 0
    while i < len(text):
        if text[i:i + 2] != "{{":
            result.append(text[i])
            i += 1
            continue
        start, nesting = i + 2, 1
        i += 2
        while i < len(text) and nesting:
            if text[i:i + 2] == "{{":
                nesting += 1
                i += 2
            elif text[i:i + 2] == "}}":
                nesting -= 1
                i += 2
            else:
                i += 1
        if nesting:
            result.append(text[start - 2:])
            break
        fields = split_fields(text[start:i - 2])
        name = fields[0].strip()
        normalized = re.sub(r"^template:", "", name, flags=re.I).casefold()
        if normalized == "race":
            labels = {"NAME": "Race", "BASE": "Base race", "AWARD": "Award",
                      "ALIGNMENT": "Alignment", "ECL": "ECL", "STR": "Strength",
                      "DEX": "Dexterity", "CON": "Constitution", "INT": "Intelligence",
                      "WIS": "Wisdom", "CHA": "Charisma", "FEATS": "Feats",
                      "BONUS": "Bonuses", "LANGUAGE": "Languages",
                      "START": "Starting locations", "OTHER": "Other"}
            rows = []
            for field in fields[1:]:
                if "=" in field:
                    key, value = field.split("=", 1)
                    key = key.strip()
                    rows.append(labels.get(key, key) + ": " + expand_templates(value.strip(), sources, depth + 1))
            result.append("\n" + "\n".join(rows) + "\n")
        elif name.startswith(":"):
            target = name[1:].strip().replace("_", " ").casefold()
            source = sources.get(target)
            if source is None:
                result.append("[Referenced article: " + name[1:] + "]")
            else:
                includes = re.findall(r"<onlyinclude>(.*?)</onlyinclude>", source, re.I | re.S)
                result.append(expand_templates("\n".join(includes) if includes else source, sources, depth + 1))
        elif normalized in {"raceheader", "race navbox", "hidden monstrous races"}:
            pass
        elif normalized == "stub":
            result.append("[This wiki article is incomplete.]\n")
        else:
            # Preserve unknown content rather than silently losing template data.
            result.append("[Template " + name + ": " + " | ".join(fields[1:]) + "]")
    return "".join(result)


def plain_text(source: str, sources: dict[str, str]) -> str:
    text = re.sub(r"<!--.*?-->", "", source, flags=re.S)
    text = expand_templates(text, sources)
    swatches = re.findall(r"\[\[(?:File|Image):Skin color (\d+)\.png[^\]]*\]\]", text, re.I)
    text = re.sub(r"\[\[(?:File|Image):Skin color \d+\.png[^\]]*\]\]", "", text, flags=re.I)

    def image(match):
        fields = split_fields(match.group(1))
        return "\n[Illustration: " + fields[0] + (" - " + fields[-1] if len(fields) > 2 else "") + "]\n"

    text = re.sub(r"\[\[(?:File|Image):([^\]]+)\]\]", image, text, flags=re.I)
    text = re.sub(r"\[\[(?:Category):[^\]]+\]\]", "", text, flags=re.I)
    text = re.sub(r"\[\[([^\]]+)\]\]", lambda m: m.group(1).split("|")[-1].replace("_", " "), text)
    text = re.sub(r"\[(https?://\S+)(?:\s+([^\]]+))?\]", lambda m: m.group(2) or m.group(1), text)
    text = re.sub(r"</?br\s*/?>", "\n", text, flags=re.I)
    text = re.sub(r"<li\b[^>]*>", "\n- ", text, flags=re.I)
    text = re.sub(r"</(?:li|ul|div)>", "\n", text, flags=re.I)
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"'{2,5}", "", text)
    output = []
    for line in html.unescape(text).splitlines():
        line = line.strip()
        if line.startswith(("{|", "|}", "|-")):
            continue
        if line.startswith("|+"):
            line = line[2:].strip()
        elif line.startswith(("|", "!")):
            line = re.sub(r"[|!]{2}", " | ", line[1:]).strip()
            line = re.sub(r"^(?:style|class|rowspan|colspan|align|width)\s*=.*?\|\s*", "", line)
        line = re.sub(r"^[*#]+\s*", "- ", line)
        line = re.sub(r"^:+\s*", "  ", line)
        line = re.sub(r"^={2,6}\s*(.*?)\s*={2,6}$", r"\1", line)
        output.append(line)
    text = re.sub(r"\n{3,}", "\n\n", "\n".join(output)).strip()
    if swatches:
        text += "\n\nSkin palette indices: " + ", ".join(swatches) + ".\n(Color swatch images are not included in this export.)"
    # The stock target's English font coverage is more reliable for these punctuation forms.
    return text.translate(str.maketrans({"\u2018": "'", "\u2019": "'", "\u201c": '"', "\u201d": '"', "\u2013": "-", "\u2014": " - ", "\u00a0": " "}))


def chunks(text: str, limit: int = MAX_SECTION_CHARS) -> list[str]:
    result = []
    while len(text) > limit:
        end = text.rfind("\n", limit // 2, limit)
        if end < 0:
            end = text.rfind(" ", limit // 2, limit)
        if end < 0:
            end = limit
        result.append(text[:end].strip())
        text = text[end:].strip()
    return result + ([text] if text else [])


@dataclass
class Article:
    title: str
    sections: list[tuple[str, str]]
    links: list[str]


def load_export(filename: str | Path) -> list[Article]:
    raw = Path(filename).read_bytes()
    if len(raw) > 32 * 1024 * 1024 or b"<!DOCTYPE" in raw.upper() or b"<!ENTITY" in raw.upper():
        raise ValueError("Unsupported export size or XML entity declarations")
    root = ET.fromstring(raw)
    ns = {"m": "http://www.mediawiki.org/xml/export-0.11/"}
    source_rows = []
    for page in root.findall("m:page", ns):
        if page.findtext("m:ns", "0", ns) != "0":
            continue
        revisions = page.findall("m:revision", ns)
        if revisions:
            source_rows.append((page.findtext("m:title", "", ns), revisions[-1].findtext("m:text", "", ns)))
    sources = {title.replace("_", " ").casefold(): text for title, text in source_rows}
    articles = []
    for title, source in source_rows:
        parts = re.split(r"(?m)^={2,6}\s*([^=\n].*?)\s*={2,6}\s*$", source)
        blocks = [("Overview", parts[0])] + list(zip(parts[1::2], parts[2::2]))
        sections = []
        for heading, body in blocks:
            pieces = chunks(plain_text(body, sources))
            for index, piece in enumerate(pieces):
                label = heading.strip() + (f" ({index + 1}/{len(pieces)})" if len(pieces) > 1 else "")
                sections.append((label, piece))
        targets = dict.fromkeys(m.strip().replace("_", " ") for m in re.findall(r"\[\[([^\]|#]+)", source))
        links = [target for target in targets if target.casefold() in sources and target.casefold() != title.casefold()]
        articles.append(Article(title, sections or [("Overview", "No article text.")], links))
    if not articles:
        raise ValueError("Export has no article pages")
    return articles


def ubjson(value) -> bytes:
    def integer(number):
        if -128 <= number <= 127:
            return b"i" + struct.pack(">b", number)
        if 0 <= number <= 255:
            return b"U" + bytes([number])
        if -32768 <= number <= 32767:
            return b"I" + struct.pack(">h", number)
        if -2147483648 <= number <= 2147483647:
            return b"l" + struct.pack(">i", number)
        return b"L" + struct.pack(">q", number)

    def string(text):
        raw = text.encode("utf-8")
        return integer(len(raw)) + raw

    if value is None:
        return b"Z"
    if isinstance(value, bool):
        return b"T" if value else b"F"
    if isinstance(value, int):
        return integer(value)
    if isinstance(value, float):
        return b"D" + struct.pack(">d", value)
    if isinstance(value, str):
        return b"S" + string(value)
    if isinstance(value, list):
        return b"[" + b"".join(ubjson(v) for v in value) + b"]"
    if isinstance(value, dict):
        return b"{" + b"".join(string(k) + ubjson(value[k]) for k in sorted(value)) + b"}"
    raise TypeError(type(value))


def native_packet(minor: int, fields: list[tuple[str, object]], mode: int = 1) -> bytes:
    """Full P/55 envelope, CNWMessage byte stream and three-bit residual header."""
    body = bytearray(b"\x03\x01" if mode == 0 else b"")

    def tag(n):
        if mode == 0:
            body.append(n)

    for kind, value in fields:
        if kind == "int":
            tag(8)
            body.extend(struct.pack("<i", value))
        elif kind == "string":
            raw = value.encode("ascii")  # IDs/bind names only; content is UTF-8 UBJSON.
            tag(14)
            tag(8)
            body.extend(struct.pack("<i", len(raw)))
            body.extend(raw)
        elif kind == "json":
            raw = ubjson(value)
            tag(16)
            tag(7)
            body.extend(struct.pack("<I", len(raw)))
            tag(15)
            body.extend(raw)
        else:
            raise ValueError(kind)
    return bytes([80, 55, minor]) + struct.pack("<I", 7 + len(body)) + body + b"\x60"


def button(identifier, label, width=None):
    result = {"type": "button", "id": identifier, "label": label, "height": 28.0}
    if width is not None:
        result["width"] = float(width)
    return result


class WikiReader:
    def __init__(self, articles: list[Article], initial="Forest Gnome"):
        self.articles = articles
        self.by_title = {a.title.casefold(): i for i, a in enumerate(articles)}
        self.article = self.by_title.get(initial.casefold(), 0)
        self.section = 0
        self.history = []
        self.contents = False

    def content(self):
        article = self.articles[self.article]
        heading, text = article.sections[self.section]
        navigation = {"type": "row", "height": 32.0, "children": [
            button("back", "Back", 70), button("previous", "Previous", 90),
            button("contents", "Sections", 90), button("next", "Next", 70)]}
        children = [{"type": "label", "value": article.title, "height": 28.0}, navigation]
        if self.contents:
            children += [button("section_" + str(i), label) for i, (label, _) in enumerate(article.sections)]
            children += [{"type": "label", "value": "Related exported articles", "height": 28.0}]
            children += [button("article_" + str(self.by_title[t.casefold()]), t) for t in article.links]
        else:
            children += [{"type": "label", "value": f"{self.section + 1}/{len(article.sections)} - {heading}", "height": 28.0},
                         {"type": "text", "value": text, "border": True, "scrollbars": 2, "height": 460.0}]
        return {"type": "col", "children": children}

    def layout(self):
        index = {"type": "col", "children": [button("article_" + str(i), a.title) for i, a in enumerate(self.articles)]}
        return {"version": 1, "title": "Arelith Wiki - local stock NUI experiment",
                "geometry": {"x": 40.0, "y": 60.0, "w": 1000.0, "h": 660.0},
                "resizable": True, "collapsed": False, "closable": True,
                "transparent": False, "border": True, "acceptsInput": True,
                "root": {"type": "col", "children": [
                    {"type": "label", "height": 26.0, "value": f"{len(self.articles)} exported articles | Local preview; Arelith server is not involved"},
                    {"type": "row", "children": [
                        {"type": "group", "width": 240.0, "height": 565.0, "border": True, "scrollbars": 2, "children": [index]},
                        {"type": "group", "id": "wiki_content", "width": 700.0, "height": 565.0, "border": True, "scrollbars": 2, "children": [self.content()]}]}]}}

    def click(self, element):
        if element.startswith("article_"):
            index = int(element.removeprefix("article_"))
            if not 0 <= index < len(self.articles):
                raise ValueError("Article index out of range")
            self.history.append((self.article, self.section))
            self.article, self.section, self.contents = index, 0, False
        elif element.startswith("section_"):
            index = int(element.removeprefix("section_"))
            if not 0 <= index < len(self.articles[self.article].sections):
                raise ValueError("Section index out of range")
            self.section, self.contents = index, False
        elif element == "next":
            self.section = min(self.section + 1, len(self.articles[self.article].sections) - 1)
            self.contents = False
        elif element == "previous":
            self.section = max(0, self.section - 1)
            self.contents = False
        elif element == "contents":
            self.contents = not self.contents
        elif element == "back":
            if self.history:
                self.article, self.section = self.history.pop()
            self.contents = False
        else:
            return False
        return True

    def create(self, mode=1):
        return native_packet(1, [("int", TOKEN), ("string", WINDOW_ID), ("int", 1), ("json", self.layout())], mode)

    def update(self, mode=1):
        return native_packet(5, [("int", TOKEN), ("string", "wiki_content"), ("json", self.content())], mode)

    def destroy(self, mode=1):
        return native_packet(2, [("int", TOKEN)], mode)
