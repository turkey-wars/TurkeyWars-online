import argparse
import random
import re
import xml.etree.ElementTree as ET
from pathlib import Path
import numpy as np

import svgpathtools
from shapely.geometry import LineString, Polygon
from shapely.ops import polygonize, unary_union
from shapely.validation import make_valid

# Set a seed to make it reproducible if we wanted, but "randomly" implies random every time.
# random.seed(42)  # Optional, left out so it's truly random

def local_name(tag: str) -> str:
    return tag.split("}", 1)[-1] if "}" in tag else tag

def parse_style(style: str) -> dict[str, str]:
    result = {}
    for part in style.split(";"):
        if ":" not in part: continue
        key, value = part.split(":", 1)
        result[key.strip().lower()] = value.strip()
    return result

def normalize_color(value: str | None) -> str | None:
    if not value: return None
    value = value.strip().lower()
    if value == "none": return "none"
    if value.startswith("#"):
        if len(value) == 4: return "#" + "".join(c * 2 for c in value[1:])
        return value
    if value.startswith("rgb(") and value.endswith(")"):
        parts = [p.strip() for p in value[4:-1].split(",")]
        if len(parts) == 3:
            try:
                r, g, b = (max(0, min(255, int(float(x)))) for x in parts)
                return f"#{r:02x}{g:02x}{b:02x}"
            except ValueError: pass
    return value

def is_white(color: str | None) -> bool:
    if not color: return False
    return normalize_color(color) == "#ffffff"

def get_effective_stroke(element: ET.Element, inherited_stroke: str | None) -> str | None:
    style_map = parse_style(element.attrib.get("style", ""))
    if "stroke" in style_map: return normalize_color(style_map["stroke"])
    if "stroke" in element.attrib: return normalize_color(element.attrib["stroke"])
    return inherited_stroke

def get_lines_from_path(d: str, num_samples: int = 15):
    lines = []
    try:
        path = svgpathtools.parse_path(d)
        for segment in path:
            points = []
            for t in np.linspace(0, 1, num_samples):
                pt = segment.point(t)
                points.append((pt.real, pt.imag))
            if len(points) >= 2:
                lines.append(LineString(points))
    except Exception as e:
        pass
    return lines

def extract_white_lines(element: ET.Element, inherited_stroke: str | None, all_lines: list):
    current_stroke = get_effective_stroke(element, inherited_stroke)
    tag = local_name(element.tag)
    
    if is_white(current_stroke) and tag == "path" and "d" in element.attrib:
        d = element.attrib["d"].strip()
        if d:
            lines = get_lines_from_path(d)
            all_lines.extend(lines)
            
    for child in element:
        extract_white_lines(child, current_stroke, all_lines)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("svg_path", type=Path, nargs="?", default=Path("../assets/map.svg"))
    parser.add_argument("--output-svg", type=Path, default=Path("../assets/map_random_numbered.svg"))
    args = parser.parse_args()

    tree = ET.parse(args.svg_path)
    root = tree.getroot()

    root_stroke = get_effective_stroke(root, None)
    
    print("Extracting white lines...")
    all_lines = []
    extract_white_lines(root, root_stroke, all_lines)
    
    print(f"Extracted {len(all_lines)} line segments.")
    
    print("Noding geometries (this might take a few seconds)...")
    # Buffer slightly to be "very liberal" about intersection? 
    # Or just use unary_union. unary_union nodes intersections nicely.
    noded_lines = unary_union(all_lines)
    
    print("Polygonizing spaces...")
    polygons = list(polygonize(noded_lines))
    
    # Filter out empty or broken polys
    valid_polygons = [p for p in polygons if p.is_valid and p.area > 0.1]
    
    print(f"Found {len(valid_polygons)} enclosed spaces.")
    
    # Randomly shuffle them
    random.shuffle(valid_polygons)
    
    # Create Output SVG
    width = float(root.attrib.get("width", "1000"))
    height = float(root.attrib.get("height", "422"))
    view_box = root.attrib.get("viewBox", root.attrib.get("viewbox", f"0 0 {width} {height}"))
    out_root = ET.Element("svg", {
        "xmlns": "http://www.w3.org/2000/svg",
        "width": str(width),
        "height": str(height),
        "viewBox": view_box,
    })
    
    ET.SubElement(out_root, "rect", {"x": "0", "y": "0", "width": "100%", "height": "100%", "fill": "#111111"})

    for i, poly in enumerate(valid_polygons, start=1):
        # We need SVG d path for this polygon to draw it
        
        def ring_to_d(ring):
            coords = list(ring.coords)
            if not coords: return ""
            pts = [f"{x},{y}" for x, y in coords]
            return "M " + " L ".join(pts) + " Z"

        d = ring_to_d(poly.exterior)
        for interior in poly.interiors:
            d += " " + ring_to_d(interior)
            
        color = "#6f9c76"
        
        ET.SubElement(out_root, "path", {
            "d": d,
            "fill": color,
            "stroke": "#ffffff",
            "stroke-width": "0.5"
        })
        
        # Add a random number
        rep_pt = poly.representative_point()
        
        # Calculate bounding box to guess font size
        minx, miny, maxx, maxy = poly.bounds
        poly_w = maxx - minx
        poly_h = maxy - miny
        
        # Fit logic
        text_str = str(i)
        max_f_w = (poly_w * 0.9) / (0.6 * max(1, len(text_str)))
        max_f_h = poly_h * 0.8
        font_size = min(max_f_w, max_f_h, 12.0)
        font_size = max(font_size, 1.0)
        
        text_node = ET.SubElement(out_root, "text", {
            "x": f"{rep_pt.x:.2f}",
            "y": f"{rep_pt.y:.2f}",
            "fill": "white",
            "font-family": "sans-serif",
            "font-size": f"{font_size:.2f}px",
            "text-anchor": "middle",
            "dominant-baseline": "central",
            "stroke": "black",
            "stroke-width": f"{font_size*0.1:.2f}px",
            "paint-order": "stroke"
        })
        text_node.text = text_str

    args.output_svg.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(out_root).write(args.output_svg, encoding="utf-8", xml_declaration=True)
    print(f"Saved random numbered spaces map to {args.output_svg}")

if __name__ == "__main__":
    main()
