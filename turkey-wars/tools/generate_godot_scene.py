import json
from shapely.wkt import loads
import xml.etree.ElementTree as ET
from shapely.geometry import Polygon, MultiPolygon
from pathlib import Path

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

def simplify_d(d_str, tolerance=0.5):
    rings = parse_d(d_str)
    simplified_rings = []
    for ring in rings:
        poly = Polygon(ring)
        s_poly = poly.simplify(tolerance, preserve_topology=True)
        if s_poly.is_empty: continue
        if s_poly.geom_type == 'Polygon':
            simplified_rings.append(list(s_poly.exterior.coords))
    return simplified_rings

def format_packed_vector2(coords):
    # Remove last point if it's the exact same as first point
    if coords and len(coords) > 1 and coords[0] == coords[-1]:
        coords = coords[:-1]
    pts = []
    for x, y in coords:
        pts.append(f"{x:^.2f}")
        pts.append(f"{y:^.2f}")
    return "PackedVector2Array(" + ", ".join(pts) + ")"

def main():
    with open('../assets/turkey_final_provinces.json', 'r', encoding='utf-8') as f:
        data = json.load(f)

    out_lines = [
        '[gd_scene load_steps=2 format=3]',
        '',
        '[ext_resource type="Script" path="res://map_scene.gd" id="1"]',
        '',
        '[node name="MapScene" type="Node2D"]',
        'script = ExtResource("1")',
        ''
    ]
    
    out_lines.append('[node name="Background" type="ColorRect" parent="."]')
    out_lines.append('offset_left = -200.0')
    out_lines.append('offset_top = -200.0')
    out_lines.append('offset_right = 1500.0')
    out_lines.append('offset_bottom = 1000.0')
    out_lines.append('color = Color(1, 1, 1, 1)')
    out_lines.append('mouse_filter = 2') # ignore mouse clicks for background
    out_lines.append('')
    
    for province, info in data.items():
        node_name = province.replace("ı", "i").replace("ş", "s").replace("ğ", "g").replace("ü", "u").replace("ö", "o").replace("ç", "c").replace("İ", "I").replace("Ş", "S").replace("Ğ", "G").replace("Ü", "U").replace("Ö", "O").replace("Ç", "C").replace(" ", "_")
        
        rings = simplify_d(info["d"], 0.5)
        if not rings:
            continue
            
        out_lines.append(f'[node name="{node_name}" type="Area2D" parent="."]')
        out_lines.append('')
        
        for i, ring in enumerate(rings):
            packed = format_packed_vector2(ring)
            
            out_lines.append(f'[node name="Poly{i}" type="Polygon2D" parent="{node_name}"]')
            out_lines.append(f'polygon = {packed}')
            out_lines.append(f'color = Color(0.7, 0.7, 0.7, 1)')
            out_lines.append('antialiased = true')
            out_lines.append('')

            out_lines.append(f'[node name="Line{i}" type="Line2D" parent="{node_name}"]')
            out_lines.append(f'points = {packed}')
            out_lines.append(f'closed = true')
            out_lines.append(f'width = 1.0')
            out_lines.append(f'default_color = Color(1, 1, 1, 1)')
            out_lines.append('joint_mode = 2')
            out_lines.append('begin_cap_mode = 2')
            out_lines.append('end_cap_mode = 2')
            out_lines.append('antialiased = true')
            out_lines.append('')
            
            out_lines.append(f'[node name="Col{i}" type="CollisionPolygon2D" parent="{node_name}"]')
            out_lines.append(f'polygon = {packed}')
            out_lines.append('')

    out_lines.append('[node name="UILayer" type="CanvasLayer" parent="."]')
    out_lines.append('layer = 100')
    out_lines.append('')
    
    out_lines.append('[node name="TooltipPanel" type="PanelContainer" parent="UILayer"]')
    out_lines.append('visible = false')
    out_lines.append('offset_right = 160.0')
    out_lines.append('offset_bottom = 80.0')
    out_lines.append('mouse_filter = 2')
    out_lines.append('')
    
    out_lines.append('[node name="VBox" type="VBoxContainer" parent="UILayer/TooltipPanel"]')
    out_lines.append('layout_mode = 2')
    out_lines.append('mouse_filter = 2')
    out_lines.append('')
    
    out_lines.append('[node name="NameLabel" type="Label" parent="UILayer/TooltipPanel/VBox"]')
    out_lines.append('layout_mode = 2')
    out_lines.append('text = "Province Name"')
    out_lines.append('')

    out_lines.append('[node name="StrengthLabel" type="Label" parent="UILayer/TooltipPanel/VBox"]')
    out_lines.append('layout_mode = 2')
    out_lines.append('text = "Strength: 0"')
    out_lines.append('')

    out_lines.append('[node name="ArmyLabel" type="Label" parent="UILayer/TooltipPanel/VBox"]')
    out_lines.append('layout_mode = 2')
    out_lines.append('text = "Army Size: 0"')
    out_lines.append('')
    
    # Global player army size
    out_lines.append('[node name="TopLeftUI" type="MarginContainer" parent="UILayer"]')
    out_lines.append('offset_right = 200.0')
    out_lines.append('offset_bottom = 60.0')
    out_lines.append('theme_override_constants/margin_left = 20')
    out_lines.append('theme_override_constants/margin_top = 20')
    out_lines.append('')
    
    out_lines.append('[node name="PlayerArmyLabel" type="Label" parent="UILayer/TopLeftUI"]')
    out_lines.append('layout_mode = 2')
    out_lines.append('theme_override_colors/font_color = Color(0, 0, 0, 1)')
    out_lines.append('theme_override_font_sizes/font_size = 24')
    out_lines.append('text = "Player Army: 35000"')
    out_lines.append('')

    tscn_path = Path('../map_scene.tscn')
    tscn_path.write_text("\n".join(out_lines), encoding='utf-8')
    print("Godot scene written to map_scene.tscn")

if __name__ == "__main__":
    main()
