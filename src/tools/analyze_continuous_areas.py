from __future__ import annotations

import argparse
import colorsys
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path


COMMAND_RE = re.compile(r"[Mm]")

# Merge groups (1-based area indices) to combine after detection
MERGE_GROUPS: list[list[int]] = [
    [16, 17],
    [19, 20, 21, 22],
    [37, 38, 39],
]


def local_name(tag: str) -> str:
    return tag.split("}", 1)[-1] if "}" in tag else tag


def parse_style(style: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for part in style.split(";"):
        if ":" not in part:
            continue
        key, value = part.split(":", 1)
        key = key.strip().lower()
        value = value.strip()
        if key:
            result[key] = value
    return result


def normalize_color(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip().lower()
    if not value:
        return None
    if value == "none":
        return "none"
    if value.startswith("#"):
        if len(value) == 4:
            return "#" + "".join(ch * 2 for ch in value[1:])
        if len(value) == 7:
            return value
        return value
    if value.startswith("rgb(") and value.endswith(")"):
        inside = value[4:-1]
        parts = [p.strip() for p in inside.split(",")]
        if len(parts) != 3:
            return value
        try:
            r, g, b = (max(0, min(255, int(float(x)))) for x in parts)
            return f"#{r:02x}{g:02x}{b:02x}"
        except ValueError:
            return value
    return value


def effective_fill(element: ET.Element, inherited_fill: str | None) -> str | None:
    style_map = parse_style(element.attrib.get("style", ""))
    if "fill" in style_map:
        return normalize_color(style_map["fill"])
    if "fill" in element.attrib:
        return normalize_color(element.attrib["fill"])
    return inherited_fill


def effective_display(element: ET.Element, inherited_display: str) -> str:
    style_map = parse_style(element.attrib.get("style", ""))
    if "display" in style_map:
        return style_map["display"].strip().lower()
    if "display" in element.attrib:
        return element.attrib["display"].strip().lower()
    return inherited_display


def to_float(value: str | None) -> float | None:
    if value is None:
        return None
    stripped = value.strip().lower()
    if not stripped:
        return None
    if stripped.endswith("px"):
        stripped = stripped[:-2]
    try:
        return float(stripped)
    except ValueError:
        return None


def is_renderable_shape(tag: str, element: ET.Element) -> bool:
    if tag == "circle":
        radius = to_float(element.attrib.get("r"))
        return radius is not None and radius > 0
    if tag == "ellipse":
        radius_x = to_float(element.attrib.get("rx"))
        radius_y = to_float(element.attrib.get("ry"))
        return (radius_x is not None and radius_x > 0) and (radius_y is not None and radius_y > 0)
    if tag == "rect":
        width = to_float(element.attrib.get("width"))
        height = to_float(element.attrib.get("height"))
        return (width is not None and width > 0) and (height is not None and height > 0)
    if tag in {"polygon", "polyline"}:
        return bool(element.attrib.get("points", "").strip())
    if tag == "path":
        return bool(element.attrib.get("d", "").strip())
    return False


def split_path_subpaths(path_data: str) -> list[str]:
    starts = [match.start() for match in COMMAND_RE.finditer(path_data)]
    if not starts:
        cleaned = path_data.strip()
        return [cleaned] if cleaned else []
    subpaths: list[str] = []
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else len(path_data)
        segment = path_data[start:end].strip()
        if segment:
            subpaths.append(segment)
    return subpaths


def color_for_index(index: int) -> str:
    hue = (index * 0.618033988749895) % 1.0
    saturation = 0.68
    value = 0.95
    red, green, blue = colorsys.hsv_to_rgb(hue, saturation, value)
    return f"#{int(red * 255):02x}{int(green * 255):02x}{int(blue * 255):02x}"


def copy_shape_attributes(element: ET.Element, extra: dict[str, str]) -> dict[str, str]:
    attrs = {k: v for k, v in element.attrib.items() if k not in {"style", "fill", "stroke", "stroke-width"}}
    attrs.update(extra)
    return attrs


def extract_label_points(source_root: ET.Element) -> dict[str, tuple[float, float]]:
    label_points: dict[str, tuple[float, float]] = {}
    label_group: ET.Element | None = None

    for node in source_root.iter():
        if local_name(node.tag) == "g" and node.attrib.get("id") == "label_points":
            label_group = node
            break

    if label_group is None:
        return label_points

    for child in label_group:
        if local_name(child.tag) != "circle":
            continue

        region_id = child.attrib.get("id", "").strip()
        center_x = to_float(child.attrib.get("cx"))
        center_y = to_float(child.attrib.get("cy"))

        if region_id and center_x is not None and center_y is not None:
            label_points[region_id] = (center_x, center_y)

    return label_points


def merge_areas(areas: list[dict], merge_groups: list[list[int]]) -> list[dict]:
    # Build mapping by first index (to preserve ordering)
    n = len(areas)
    group_map: dict[int, list[int]] = {}
    for grp in merge_groups:
        valid = [i for i in grp if 1 <= i <= n]
        if not valid:
            continue
        first = min(valid)
        group_map[first] = valid

    merged: list[dict] = []
    processed: set[int] = set()

    for i in range(1, n + 1):
        if i in processed:
            continue
        if i in group_map:
            idxs = group_map[i]
            components = [areas[j - 1] for j in idxs]
            merged.append(
                {
                    "kind": "merged",
                    "shape_tag": "g",
                    "merged_from": idxs,
                    "components": components,
                }
            )
            processed.update(idxs)
        else:
            merged.append(areas[i - 1])
            processed.add(i)

    return merged


def collect_areas(
    element: ET.Element,
    inherited_fill: str | None,
    inherited_display: str,
    target_fill: str,
    areas: list[dict],
) -> None:
    current_fill = effective_fill(element, inherited_fill)
    current_display = effective_display(element, inherited_display)
    tag = local_name(element.tag)
    element_id = element.attrib.get("id", "")
    element_name = element.attrib.get("name", "")

    if current_fill == target_fill and current_display != "none":
        if tag == "path":
            path_data = element.attrib.get("d", "").strip()
            for subpath_index, subpath in enumerate(split_path_subpaths(path_data), start=1):
                areas.append(
                    {
                        "kind": "path",
                        "shape_tag": tag,
                        "source_id": element_id,
                        "source_name": element_name,
                        "subpath_index": subpath_index,
                        "attributes": copy_shape_attributes(
                            element,
                            {
                                "d": subpath,
                            },
                        ),
                    }
                )
        elif tag in {"circle", "ellipse", "rect", "polygon", "polyline"} and is_renderable_shape(tag, element):
            areas.append(
                {
                    "kind": tag,
                    "shape_tag": tag,
                    "source_id": element_id,
                    "source_name": element_name,
                    "subpath_index": None,
                    "attributes": copy_shape_attributes(element, {}),
                }
            )

    for child in element:
        collect_areas(child, current_fill, current_display, target_fill, areas)


def build_output_svg(
    source_root: ET.Element,
    areas: list[dict],
    label_points: dict[str, tuple[float, float]],
    output_path: Path,
) -> None:
    width = source_root.attrib.get("width", "1000")
    height = source_root.attrib.get("height", "422")
    view_box = source_root.attrib.get("viewBox") or source_root.attrib.get("viewbox") or f"0 0 {width} {height}"

    output_root = ET.Element(
        "svg",
        {
            "xmlns": "http://www.w3.org/2000/svg",
            "width": width,
            "height": height,
            "viewBox": view_box,
        },
    )

    ET.SubElement(output_root, "rect", {"x": "0", "y": "0", "width": "100%", "height": "100%", "fill": "#111111"})

    label_positions: list[tuple[int, float, float]] = []
    source_label_offset_count: dict[str, int] = {}

    def area_label_point(area: dict) -> tuple[float, float] | None:
        # For merged areas, prefer any component's source label, else average available points
        if area.get("kind") == "merged":
            pts: list[tuple[float, float]] = []
            for comp in area.get("components", []):
                sid = comp.get("source_id", "")
                if sid in label_points:
                    pts.append(label_points[sid])
            if not pts:
                return None
            if len(pts) == 1:
                return pts[0]
            avgx = sum(p[0] for p in pts) / len(pts)
            avgy = sum(p[1] for p in pts) / len(pts)
            return (avgx, avgy)
        else:
            sid = area.get("source_id", "")
            return label_points.get(sid)

    for index, area in enumerate(areas, start=1):
        if area.get("kind") == "merged":
            grp = ET.SubElement(output_root, "g", {"data-area-id": str(index)})
            for comp in area.get("components", []):
                child_tag = comp.get("shape_tag")
                child_attrs = dict(comp.get("attributes", {}))
                child_attrs["fill"] = color_for_index(index)
                child_attrs["stroke"] = "#111111"
                child_attrs["stroke-width"] = "0.35"
                grp.append(ET.Element(child_tag, child_attrs))
        else:
            attrs = dict(area["attributes"])
            attrs["fill"] = color_for_index(index)
            attrs["stroke"] = "#111111"
            attrs["stroke-width"] = "0.35"
            attrs["data-area-id"] = str(index)
            ET.SubElement(output_root, area["shape_tag"], attrs)

        pt = area_label_point(area)
        if pt is not None:
            # find a source id for offset grouping
            sid = None
            if area.get("kind") == "merged":
                for comp in area.get("components", []):
                    if comp.get("source_id", "") in label_points:
                        sid = comp.get("source_id")
                        break
            else:
                sid = area.get("source_id", "")

            offset_index = source_label_offset_count.get(sid, 0)
            source_label_offset_count[sid] = offset_index + 1
            label_x, label_y = pt
            label_positions.append((index, label_x, label_y + (offset_index * 9.0)))

    for area_index, label_x, label_y in label_positions:
        text_node = ET.SubElement(
            output_root,
            "text",
            {
                "x": f"{label_x:.2f}",
                "y": f"{label_y:.2f}",
                "fill": "#ffffff",
                "stroke": "#000000",
                "stroke-width": "1.2",
                "paint-order": "stroke",
                "font-size": "8",
                "font-family": "Arial, sans-serif",
                "text-anchor": "middle",
                "dominant-baseline": "middle",
            },
        )
        text_node.text = str(area_index)

    tree = ET.ElementTree(output_root)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output_path, encoding="utf-8", xml_declaration=True)


def write_report(areas: list[dict], source_svg: Path, target_fill: str, json_output_path: Path) -> None:
    report_areas = []
    for index, area in enumerate(areas, start=1):
        if area.get("kind") == "merged":
            comps = []
            for comp in area.get("components", []):
                comps.append(
                    {
                        "source_id": comp.get("source_id"),
                        "source_name": comp.get("source_name"),
                        "shape": comp.get("shape_tag"),
                        "subpath_index": comp.get("subpath_index"),
                    }
                )
            report_areas.append(
                {
                    "area_id": index,
                    "kind": "merged",
                    "merged_from": area.get("merged_from", []),
                    "components": comps,
                }
            )
        else:
            report_areas.append(
                {
                    "area_id": index,
                    "kind": area.get("kind"),
                    "source_id": area.get("source_id"),
                    "source_name": area.get("source_name"),
                    "shape": area.get("shape_tag"),
                    "subpath_index": area.get("subpath_index"),
                }
            )

    report = {
        "source_svg": str(source_svg),
        "target_fill": target_fill,
        "area_count": len(areas),
        "areas": report_areas,
    }

    json_output_path.parent.mkdir(parents=True, exist_ok=True)
    json_output_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")


def build_borders_svg(source_root: ET.Element, areas: list[dict], output_path: Path) -> None:
    width = source_root.attrib.get("width", "1000")
    height = source_root.attrib.get("height", "422")
    view_box = source_root.attrib.get("viewBox") or source_root.attrib.get("viewbox") or f"0 0 {width} {height}"

    output_root = ET.Element(
        "svg",
        {
            "xmlns": "http://www.w3.org/2000/svg",
            "width": width,
            "height": height,
            "viewBox": view_box,
        },
    )

    # Transparent background
    ET.SubElement(output_root, "rect", {"x": "0", "y": "0", "width": "100%", "height": "100%", "fill": "none"})

    for index, area in enumerate(areas, start=1):
        if area.get("kind") == "merged":
            grp = ET.SubElement(output_root, "g", {"data-area-id": str(index)})
            for comp in area.get("components", []):
                child_tag = comp.get("shape_tag")
                child_attrs = dict(comp.get("attributes", {}))
                child_attrs["fill"] = "none"
                child_attrs["stroke"] = "#000000"
                child_attrs["stroke-width"] = "0.6"
                grp.append(ET.Element(child_tag, child_attrs))
        else:
            attrs = dict(area["attributes"])
            attrs["fill"] = "none"
            attrs["stroke"] = "#000000"
            attrs["stroke-width"] = "0.6"
            attrs["data-area-id"] = str(index)
            ET.SubElement(output_root, area["shape_tag"], attrs)

    tree = ET.ElementTree(output_root)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output_path, encoding="utf-8", xml_declaration=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Identify continuous SVG areas by fill color and generate a numbered visualization SVG + JSON report."
    )
    parser.add_argument("svg_path", type=Path, help="Path to the input SVG file.")
    parser.add_argument("--target-color", default="#6f9c76", help="Target fill color to analyze (default: #6f9c76).")
    parser.add_argument(
        "--output-svg",
        type=Path,
        default=Path("assets/map_identified_areas.svg"),
        help="Path for the output visualization SVG.",
    )
    parser.add_argument(
        "--output-json",
        type=Path,
        default=Path("assets/map_identified_areas.json"),
        help="Path for the output JSON report.",
    )
    parser.add_argument(
        "--borders-svg",
        type=Path,
        default=Path("assets/map_borders.svg"),
        help="Path for the output vector borders SVG.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source_path = args.svg_path
    target_fill = normalize_color(args.target_color)
    if target_fill is None:
        raise ValueError("Invalid target color.")

    tree = ET.parse(source_path)
    root = tree.getroot()

    areas: list[dict] = []
    label_points = extract_label_points(root)
    collect_areas(root, normalize_color(root.attrib.get("fill")), root.attrib.get("display", "inline").strip().lower(), target_fill, areas)

    # Apply user-specified merges (indices are 1-based in MERGE_GROUPS)
    final_areas = merge_areas(areas, MERGE_GROUPS)

    build_output_svg(root, final_areas, label_points, args.output_svg)
    build_borders_svg(root, final_areas, args.borders_svg)
    write_report(final_areas, source_path, target_fill, args.output_json)

    print(f"Found {len(final_areas)} continuous area(s) (after merges) with fill {target_fill}.")
    print(f"Visualization SVG: {args.output_svg}")
    print(f"Borders SVG: {args.borders_svg}")
    print(f"JSON report: {args.output_json}")


if __name__ == "__main__":
    main()