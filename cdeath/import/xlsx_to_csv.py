#!/usr/bin/env python3

import csv
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree


MAIN_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
NS = {"x": MAIN_NS}


def column_index(reference):
    letters = re.match(r"[A-Z]+", reference).group(0)
    index = 0
    for letter in letters:
        index = index * 26 + ord(letter) - ord("A") + 1
    return index - 1


def text_content(element):
    parts = []
    for child in element:
        if child.tag == f"{{{MAIN_NS}}}t":
            parts.append(child.text or "")
        elif child.tag == f"{{{MAIN_NS}}}r":
            text = child.find("x:t", NS)
            parts.append(text.text or "" if text is not None else "")
    return "".join(parts)


def shared_strings(archive):
    try:
        root = ElementTree.fromstring(archive.read("xl/sharedStrings.xml"))
    except KeyError:
        return []
    return [text_content(item) for item in root.findall("x:si", NS)]


def cell_value(cell, strings):
    cell_type = cell.get("t")
    if cell_type == "inlineStr":
        inline = cell.find("x:is", NS)
        return text_content(inline) if inline is not None else ""

    value = cell.find("x:v", NS)
    if value is None or value.text is None:
        return ""
    if cell_type == "s":
        return strings[int(value.text)]
    if cell_type == "b":
        return "TRUE" if value.text == "1" else "FALSE"
    return value.text


def convert(source, destination):
    with zipfile.ZipFile(source) as archive:
        strings = shared_strings(archive)
        sheet = ElementTree.fromstring(archive.read("xl/worksheets/sheet1.xml"))

    rows = []
    width = 0
    for row_element in sheet.findall(".//x:sheetData/x:row", NS):
        values = {}
        for cell in row_element.findall("x:c", NS):
            index = column_index(cell.get("r"))
            values[index] = cell_value(cell, strings)
            width = max(width, index + 1)
        rows.append(values)

    with open(destination, "w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output, lineterminator="\n")
        for values in rows:
            writer.writerow([values.get(index, "") for index in range(width)])


def main():
    if len(sys.argv) != 3:
        raise SystemExit(f"Usage: {Path(sys.argv[0]).name} INPUT.xlsx OUTPUT.csv")
    convert(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    main()
