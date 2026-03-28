import json
from shapely.wkt import loads
import xml.etree.ElementTree as ET
from shapely.geometry import Polygon, MultiPolygon
import re

with open('../assets/turkey_final_provinces.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

def parse_d(d_str):
    parts = d_str.split("Z")
    pgs = []
    
    for part in parts:
        if not part.strip(): continue
        coords = []
        tokens = part.replace("M", "").replace("L", "").split()
        for t in tokens:
            if "," in t:
                x, y = t.split(",")
                coords.append((float(x), float(y)))
        if len(coords) >= 3:
            pgs.append(coords)
    return pgs

total_pts = 0
for k, v in data.items():
    rings = parse_d(v["d"])
    for ring in rings:
        total_pts += len(ring)

print(f"Total points originally: {total_pts}")

def simplify_d(d_str, tolerance=1.0):
    rings = parse_d(d_str)
    simplified_rings = []
    for ring in rings:
        poly = Polygon(ring)
        s_poly = poly.simplify(tolerance, preserve_topology=True)
        if s_poly.is_empty: continue
        if s_poly.geom_type == 'Polygon':
            simplified_rings.append(list(s_poly.exterior.coords))
    return simplified_rings

total_simp = 0
for k, v in data.items():
    s_rings = simplify_d(v["d"], 0.5)
    for r in s_rings:
        total_simp += len(r)

print(f"Total points after simplification (0.5): {total_simp}")
