import argparse
import math
import re
import xml.etree.ElementTree as ET
from pathlib import Path
import numpy as np

import svgpathtools
from shapely.geometry import Polygon
from shapely.validation import make_valid

COMMAND_RE = re.compile(r"(?=[Mm])")

PROVINCES = [
    "Konya", "Sivas", "Ankara", "Erzurum", "Van", "Antalya", "Şanlıurfa", "Kayseri", 
    "Mersin", "Diyarbakır", "Afyonkarahisar", "Balıkesir", "Adana", "Kahramanmaraş", 
    "Yozgat", "Eskişehir", "Kastamonu", "Manisa", "Çorum", "Muğla", "Malatya", 
    "Kütahya", "Erzincan", "İzmir", "Denizli", "Ağrı", "Bursa", "Bolu", "Tokat", 
    "Çanakkale", "Kars", "Samsun", "Elazığ", "Mardin", "Karaman", "Isparta", "Bitlis", 
    "Çankırı", "Bingöl", "Aksaray", "Muş", "Aydın", "Hakkâri", "Adıyaman", "Artvin", 
    "Tunceli", "Niğde", "Şırnak", "Burdur", "Gaziantep", "Giresun", "Kırşehir", 
    "Tekirdağ", "Edirne", "Gümüşhane", "Kırklareli", "Ordu", "Sinop", "Amasya", 
    "Hatay", "Ardahan", "Siirt", "Nevşehir", "Uşak", "İstanbul", "Sakarya", "Batman", 
    "Kırıkkale", "Trabzon", "Bilecik", "Bayburt", "Rize", "Kocaeli", "Iğdır", 
    "Zonguldak", "Osmaniye", "Karabük", "Bartın", "Kilis", "Düzce", "Yalova"
]

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

def effective_fill(element: ET.Element, inherited_fill: str | None) -> str | None:
    style_map = parse_style(element.attrib.get("style", ""))
    if "fill" in style_map: return normalize_color(style_map["fill"])
    if "fill" in element.attrib: return normalize_color(element.attrib["fill"])
    return inherited_fill

def to_float(value: str | None) -> float | None:
    if not value: return None
    v = value.strip().lower()
    if v.endswith("px"): v = v[:-2]
    try: return float(v)
    except ValueError: return None

def get_path_polygon(path_data: str):
    try:
        path = svgpathtools.parse_path(path_data)
        points = []
        for segment in path:
            for t in np.linspace(0, 1, 10):
                pt = segment.point(t)
                points.append((pt.real, pt.imag))
        if len(points) >= 3:
            poly = Polygon(points)
            return make_valid(poly)
    except:
        pass
    return None

def split_path_subpaths(path_data: str) -> list[str]:
    parts = COMMAND_RE.split(path_data)
    return [p.strip() for p in parts if p.strip()]

def collect_areas(element: ET.Element, inherited_fill: str | None, target_fill: str, areas: list):
    current_fill = effective_fill(element, inherited_fill)
    tag = local_name(element.tag)
    display = parse_style(element.attrib.get("style", "")).get("display", element.attrib.get("display", "")).strip().lower()
    
    if current_fill == target_fill and display != "none":
        if tag == "path":
            path_data = element.attrib.get("d", "").strip()
            for subpath in split_path_subpaths(path_data):
                poly = get_path_polygon(subpath)
                if poly and poly.area > 0:
                    areas.append({
                        "tag": tag,
                        "attributes": dict(element.attrib),
                        "d": subpath,
                        "area": poly.area,
                        "poly": poly
                    })
    
    for child in element:
        collect_areas(child, current_fill, target_fill, areas)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("svg_path", type=Path, nargs="?", default=Path("../assets/map.svg"))
    parser.add_argument("--target-color", default="#6f9c76")
    parser.add_argument("--output-svg", type=Path, default=Path("../assets/map_named_areas.svg"))
    args = parser.parse_args()

    target_fill = normalize_color(args.target_color)
    tree = ET.parse(args.svg_path)
    root = tree.getroot()

    areas = []
    collect_areas(root, normalize_color(root.attrib.get("fill")), target_fill, areas)
    
    # Sort by area descending
    areas.sort(key=lambda x: x["area"], reverse=True)
    
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

    for i, item in enumerate(areas):
        name = PROVINCES[i] if i < len(PROVINCES) else f"unk#{i - len(PROVINCES) + 1}"
        
        # draw path
        attrs = {k:v for k,v in item["attributes"].items() if k not in ("style", "fill", "stroke", "stroke-width", "d")}
        attrs["d"] = item["d"]
        attrs["fill"] = "#6f9c76"
        attrs["stroke"] = "#333333"
        attrs["stroke-width"] = "0.5"
        ET.SubElement(out_root, "path", attrs)
        
        # draw label
        poly = item["poly"]
        rep_pt = poly.representative_point()
        
        minx, miny, maxx, maxy = poly.bounds
        poly_w = maxx - minx
        poly_h = maxy - miny
        
        # Ensure text is small and fits inside the bounding box
        # Character aspect ratio approx 1:0.6
        max_f_w = (poly_w * 0.9) / (0.6 * max(1, len(name)))
        max_f_h = poly_h * 0.8
        font_size = min(max_f_w, max_f_h, 6.0)
        font_size = max(font_size, 0.5)

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
        text_node.text = name

    args.output_svg.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(out_root).write(args.output_svg, encoding="utf-8", xml_declaration=True)
    print(f"Processed {len(areas)} areas, output saved to {args.output_svg}")

if __name__ == "__main__":
    main()
