import json
import csv
from pathlib import Path
from shapely.geometry import Polygon
import numpy as np

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

def get_polygon(d_str):
    rings = parse_d(d_str)
    from shapely.geometry import MultiPolygon
    from shapely.validation import make_valid
    polys = [make_valid(Polygon(r)) for r in rings]
    from shapely.ops import unary_union
    return unary_union(polys)

def kmeans(points, k, ids):
    # points is dict of id -> (x, y)
    import random
    random.seed(42)
    centroids = random.sample(list(points.values()), k)
    
    clusters = {}
    for _ in range(50):
        # assign
        new_clusters = {i: [] for i in range(k)}
        for pid, pt in points.items():
            best_i = min(range(k), key=lambda i: (pt[0]-centroids[i])[0]**2 + (pt[1]-centroids[i])[1]**2)
            new_clusters[best_i].append(pid)
        
        # recompute centroids
        new_centroids = []
        for i in range(k):
            if new_clusters[i]:
                cx = sum(points[pid][0] for pid in new_clusters[i]) / len(new_clusters[i])
                cy = sum(points[pid][1] for pid in new_clusters[i]) / len(new_clusters[i])
                new_centroids.append((cx, cy))
            else:
                new_centroids.append(centroids[i])
                
        clusters = new_clusters
        centroids = new_centroids
        
    return clusters, centroids

def main():
    with open('raw_stats.csv', 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        stats = {row['Province'].replace("Izmir", "İzmir"): row for row in reader}

    with open('../assets/turkey_final_provinces.json', 'r', encoding='utf-8') as f:
        geom_data = json.load(f)

    # find centroids and neighbors
    provinces = {}
    points = {}
    polygons = {}
    for prov_name, d_info in geom_data.items():
        poly = get_polygon(d_info["d"])
        polygons[prov_name] = poly
        pt = poly.representative_point()
        points[prov_name] = (pt.x, pt.y)

    # Calculate Adjacency
    # Two provinces are adjacent if the distance between their boundaries is very small
    adjacencies = {p: [] for p in polygons.keys()}
    prov_names = list(polygons.keys())
    for i in range(len(prov_names)):
        for j in range(i+1, len(prov_names)):
            p1 = prov_names[i]
            p2 = prov_names[j]
            # using distance < 1 to account for float inaccuracies 
            if polygons[p1].distance(polygons[p2]) < 2.0:
                adjacencies[p1].append(p2)
                adjacencies[p2].append(p1)

    print("Calculated adjacencies.")

    def sort_clusters(clusters, centroids, layout_hints):
        # maps cluster id to a nice name based on centroid positions
        c_list = list(clusters.items())
        if layout_hints == 2:
            # West / East
            # sort by X
            c_list.sort(key=lambda item: centroids[item[0]][0])
            return {"West": c_list[0][1], "East": c_list[1][1]}
        elif layout_hints == 3:
            # West / Mid / East
            c_list.sort(key=lambda item: centroids[item[0]][0])
            return {"Far West": c_list[0][1], "Middle": c_list[1][1], "Far East": c_list[2][1]}
        elif layout_hints == 4:
            # NW, NE, SW, SE
            cx = np.mean([centroids[i][0] for i in range(4)])
            cy = np.mean([centroids[i][1] for i in range(4)])
            res = {}
            for cid, p_list in c_list:
                cent = centroids[cid]
                if cent[0] < cx and cent[1] < cy: res["NW"] = p_list
                elif cent[0] < cx and cent[1] >= cy: res["SW"] = p_list
                elif cent[0] >= cx and cent[1] < cy: res["NE"] = p_list
                else: res["SE"] = p_list
            # Handle potential edge cases where multiple fall in same bucket by using absolute sorting
            # But kmeans usually spreads them out well. Let's just do a robust sort.
            sorted_x = sorted(c_list, key=lambda x: centroids[x[0]][0])
            west = sorted_x[:2]
            east = sorted_x[2:]
            west.sort(key=lambda x: centroids[x[0]][1])
            east.sort(key=lambda x: centroids[x[0]][1])
            return {"NW": west[0][1], "SW": west[1][1], "NE": east[0][1], "SE": east[1][1]}
        elif layout_hints == 5:
            # NW, NE, Central, SW, SE
            # The one closest to the overall mean is Central.
            mean_cx = np.mean([centroids[i][0] for i in range(5)])
            mean_cy = np.mean([centroids[i][1] for i in range(5)])
            dists = [(cid, (centroids[cid][0]-mean_cx)**2 + (centroids[cid][1]-mean_cy)**2) for cid in range(5)]
            dists.sort(key=lambda x: x[1])
            central_cid = dists[0][0]
            
            rem = [c for c in c_list if c[0] != central_cid]
            sorted_x = sorted(rem, key=lambda x: centroids[x[0]][0])
            west = sorted_x[:2]
            east = sorted_x[2:]
            west.sort(key=lambda x: centroids[x[0]][1])
            east.sort(key=lambda x: centroids[x[0]][1])
            
            return {
                "Central": clusters[central_cid],
                "NW": west[0][1],
                "SW": west[1][1],
                "NE": east[0][1],
                "SE": east[1][1]
            }

    # Generate regions for 2,3,4,5
    regions = {}
    for k in [2,3,4,5]:
        clusters, centroids = kmeans(points, k, prov_names)
        mapped = sort_clusters(clusters, centroids, k)
        regions[str(k)] = mapped

    print("Calculated regions.")

    game_data = {}
    for prov in prov_names:
        # Some name fixing if needed
        lookup_name = prov
        if lookup_name not in stats:
            print(f"MISSING STATS FOR {lookup_name}!")
            # try finding it without case sensitivity
            for sprov in stats.keys():
                if sprov.lower() == lookup_name.lower():
                    lookup_name = sprov
                    break
        
        stat = stats.get(lookup_name, {"Difficulty_Score": "1", "Army_Size": "10000"})
        game_data[prov] = {
            "name": prov,
            "center": {"x": points[prov][0], "y": points[prov][1]},
            "adjacencies": adjacencies[prov],
            "strength": int(stat["Difficulty_Score"]),
            "initial_army": int(stat["Army_Size"]),
            "regions": {}
        }
        
    for k_str, r_map in regions.items():
        for r_name, p_list in r_map.items():
            for p in p_list:
                game_data[p]["regions"][k_str] = r_name

    out_path = Path('../assets/game_data.json')
    out_path.write_text(json.dumps(game_data, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f"Saved game data to {out_path}")

if __name__ == "__main__":
    main()