import json
import xml.etree.ElementTree as ET
from pathlib import Path
import numpy as np

import svgpathtools
from shapely.geometry import LineString, Polygon
from shapely.ops import polygonize, unary_union

PROVINCE_MAPPING = {
    "Istanbul": [16, 52],
    "Çanakkale": [25, 40, 57, 73],
    "Balıkesir": [14, 39, 50],
    "Erzurum": [26],
    "Çorum": [47],
    "Kırıkkale": [38],
    "Yozgat": [9],
    "Ağrı": [1],
    "Şırnak": [2],
    "Bursa": [3],
    "Mardin": [4],
    "Kahramanmaraş": [5],
    "Karaman": [6],
    "Denizli": [7],
    "Tunceli": [8],
    "Ankara": [58],
    "Çankırı": [10],
    "Kırşehir": [11],
    "Eskişehir": [12],
    "Antalya": [13],
    "Gümüşhane": [15],
    "Sakarya": [17],
    "Nevşehir": [18],
    "Bilecik": [19],
    "Samsun": [20],
    "Burdur": [21],
    "Ardahan": [22],
    "Kastamonu": [23],
    "Niğde": [24],
    "Isparta": [27],
    "Afyonkarahisar": [28],
    "Kütahya": [29],
    "Düzce": [30],
    "Aksaray": [31],
    "Kocaeli": [32],
    "İzmir": [33],
    "Kars": [34],
    "Uşak": [35],
    "Adıyaman": [36],
    "Osmaniye": [37],
    "Batman": [41],
    "Diyarbakır": [42],
    "Sinop": [43],
    "Adana": [44],
    "Konya": [45],
    "Artvin": [46],
    "Hakkari": [49],
    "Trabzon": [51],
    "Manisa": [53],
    "Bartın": [54],
    "Van": [55],
    "Aydın": [56],
    "Muğla": [59],
    "Kırklareli": [60],
    "Bitlis": [61],
    "Bayburt": [62],
    "Bingöl": [63],
    "Giresun": [64],
    "Gaziantep": [65],
    "Mersin": [66],
    "Elazığ": [67],
    "Bolu": [68],
    "Tekirdağ": [69],
    "Karabük": [70],
    "Kilis": [71],
    "Iğdır": [72],
    "Erzincan": [74],
    "Sivas": [75],
    "Şanlıurfa": [76],
    "Edirne": [77],
    "Malatya": [78],
    "Zonguldak": [79],
    "Tokat": [80],
    "Siirt": [81],
    "Hatay": [82],
    "Ordu": [83],
    "Amasya": [84],
    "Kayseri": [85],
    "Yalova": [86],
    "Muş": [87],
    "Rize": [48]
}

def ring_to_d(ring):
    coords = list(ring.coords)
    if not coords: return ""
    pts = [f"{x},{y}" for x, y in coords]
    return "M " + " L ".join(pts) + " Z"

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

def path_to_polygon(d):
    lines = get_lines_from_path(d)
    noded = unary_union(lines)
    polys = list(polygonize(noded))
    return unary_union(polys)

def local_name(tag: str) -> str:
    return tag.split("}", 1)[-1] if "}" in tag else tag

def main():
    svg_path = Path("../assets/map_random_numbered.svg")
    out_svg_path = Path("../assets/map_final_provinces.svg")
    out_json_path = Path("../assets/turkey_final_provinces.json")

    tree = ET.parse(svg_path)
    root = tree.getroot()

    path_map = {}
    current_path = None
    
    # We rely on the strict order written by the previous script: path then text.
    for el in root:
        tag = local_name(el.tag)
        if tag == "path":
            # ignore background rect if it was a path, but background is "rect"
            current_path = el.attrib.get("d")
        elif tag == "text" and current_path:
            text_val = el.text.strip()
            if text_val.isdigit():
                path_map[int(text_val)] = current_path
            current_path = None

    print(f"Parsed {len(path_map)} numbered regions from the random map.")

    final_provinces = {}
    
    for province, indices in PROVINCE_MAPPING.items():
        polys = []
        for idx in indices:
            if idx in path_map:
                p = path_to_polygon(path_map[idx])
                if p and not p.is_empty:
                    polys.append(p)
            else:
                print(f"Warning: Region {idx} not found for {province}!")
        
        merged_poly = unary_union(polys)
        final_provinces[province] = merged_poly

    print(f"Successfully constructed {len(final_provinces)} final provinces.")

    # Generate JSON
    json_data = {}
    for name, poly in final_provinces.items():
        if poly.geom_type == 'Polygon':
            geom_list = [poly]
        elif poly.geom_type == 'MultiPolygon':
            geom_list = list(poly.geoms)
        else:
            geom_list = []
            
        full_d = ""
        for pg in geom_list:
            d = ring_to_d(pg.exterior)
            for interior in pg.interiors:
                d += " " + ring_to_d(interior)
            full_d += " " + d
            
        json_data[name] = {"d": full_d.strip(), "area": poly.area}
        
    out_json_path.parent.mkdir(parents=True, exist_ok=True)
    out_json_path.write_text(json.dumps(json_data, indent=2, ensure_ascii=False), encoding="utf-8")

    # Generate SVG
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

    for province, poly in final_provinces.items():
        d = json_data[province]["d"]
        ET.SubElement(out_root, "path", {
            "d": d,
            "fill": "#6f9c76",
            "stroke": "#ffffff",
            "stroke-width": "0.5",
            "data-province": province
        })
        
        rep_pt = poly.representative_point()
        minx, miny, maxx, maxy = poly.bounds
        poly_w = maxx - minx
        poly_h = maxy - miny
        
        max_f_w = (poly_w * 0.9) / (0.6 * max(1, len(province)))
        max_f_h = poly_h * 0.8
        font_size = min(max_f_w, max_f_h, 8.0)
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
        text_node.text = province

    ET.ElementTree(out_root).write(out_svg_path, encoding="utf-8", xml_declaration=True)
    print(f"Saved final finalized map to {out_svg_path}")

if __name__ == "__main__":
    main()
