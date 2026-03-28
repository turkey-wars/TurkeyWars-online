import xml.etree.ElementTree as ET
import svgpathtools
import numpy as np
from shapely.geometry import LineString, MultiLineString
from shapely.ops import polygonize, unary_union

tree = ET.parse('../assets/map.svg')
root = tree.getroot()

def get_lines(d):
    try:
        path = svgpathtools.parse_path(d)
        lines = []
        for segment in path:
            points = []
            # We can use more points for better precision but this is a test
            for t in np.linspace(0, 1, 10):
                pt = segment.point(t)
                points.append((pt.real, pt.imag))
            lines.append(LineString(points))
        return lines
    except:
        return []

all_lines = []
for el in root.iter():
    tag = el.tag.split("}")[-1]
    _d = el.attrib.get("d", "").strip()
    if tag == "path" and _d:
        all_lines.extend(get_lines(_d))

print("Noding lines...")
noded = unary_union(all_lines)
polys = list(polygonize(noded))
print(f"Found {len(polys)} enclosed spaces!")
