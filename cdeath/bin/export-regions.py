#!/usr/bin/env python3
"""Export the country grouping used only by the mortyear menu."""

import csv
import gzip
import json
import sys

NORTHERN_AMERICA = {"BMU", "CAN", "GRL", "SPM", "USA"}

if len(sys.argv) != 3:
    raise SystemExit("Usage: export-regions.py WPP-demographic.csv.gz OUTPUT.json")

with gzip.open(sys.argv[1], "rt", encoding="utf-8-sig", newline="") as handle:
    rows = list(csv.DictReader(handle))

hierarchy = {
    row["LocID"]: {
        "parent": row["ParentID"], "name": row["Location"], "type": row["LocTypeName"]
    }
    for row in rows
}


def region(row):
    """Return the broad menu group without adding it to statistical records."""
    if row["ISO3_code"] in NORTHERN_AMERICA:
        return "Northern America"
    node = hierarchy.get(row["ParentID"])
    while node:
        if node["type"] == "Geographic region":
            return node["name"]
        node = hierarchy.get(node["parent"])
    return "Other"


result = {}
for row in rows:
    iso = row["ISO3_code"]
    if iso:
        result[iso.lower()] = region(row)

result.update({"eng": "Europe", "sco": "Europe", "nir": "Europe"})

with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(dict(sorted(result.items())), handle, ensure_ascii=False, indent=2)
    handle.write("\n")
