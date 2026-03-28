import json
import csv
import re
from pathlib import Path

def get_node_name(province_name):
    # Same logic used in generate_godot_scene.py
    return (province_name
        .replace("ı", "i").replace("ş", "s").replace("ğ", "g")
        .replace("ü", "u").replace("ö", "o").replace("ç", "c")
        .replace("İ", "I").replace("Ş", "S").replace("Ğ", "G")
        .replace("Ü", "U").replace("Ö", "O").replace("Ç", "C")
        .replace(" ", "_"))

def main():
    # 1. Parse raw stats
    stats = {}
    with open('raw_stats.csv', 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row['Province'].strip()
            # Normalize some known mismatches (Istanbul vs İstanbul)
            if name == "Istanbul": name = "İstanbul"
            if name == "Izmir": name = "İzmir"
            stats[name] = row

    # 2. Parse adjacencies and regions from for_llm.txt
    adjacencies = {}
    regions_2 = {}
    regions_3 = {}
    regions_4 = {}
    regions_5 = {}

    with open('for_llm.txt', 'r', encoding='utf-8') as f:
        content = f.read()

    # Split into lines
    lines = content.splitlines()

    # Iterate until we hit the empty line before "1. Two Areas:"
    idx = 1 # skip header "Province,Neighboring Provinces"
    while idx < len(lines):
        line = lines[idx].strip()
        if not line:
            idx += 1
            if idx < len(lines) and "1. Two Areas" in lines[idx]:
                break
            continue
        
        # Parse CSV-ish adjacency line (e.g. Adana,"Hatay, Osmaniye, Kahramanmaraş, Kayseri, Niğde, Mersin")
        if ',"' in line:
            prov, neighbors_str = line.split(',"', 1)
            neighbors_str = neighbors_str.rstrip('"')
            neighbors = [n.strip() for n in neighbors_str.split(',') if n.strip()]
        else:
            parts = line.split(',')
            prov = parts[0]
            neighbors = parts[1:]
        
        adjacencies[prov] = neighbors
        idx += 1

    # Extract Blocks
    # Helper to extract groups of provinces
    def parse_region_block(block_text):
        mapping = {}
        for line in block_text.splitlines():
            line = line.strip()
            if ":" in line and ("Provinces" in line or line.split(":")[0].strip() != ""):
                # e.g. "West (40 Provinces): Afyonkarahisar, Aksaray..."
                # or "Far West: ..."
                prefix, provs_str = line.split(":", 1)
                region_name = prefix.split("(")[0].strip()
                provs = [p.strip() for p in provs_str.split(",") if p.strip()]
                if not provs[-1]: # handle trailing comma
                    provs = provs[:-1]
                # remove any trailing periods from the last province
                if provs and provs[-1].endswith("."):
                    provs[-1] = provs[-1][:-1]
                mapping[region_name] = provs
        return mapping

    # Extremely hacky but robust regex extraction of the blocks based on provided text format
    blocks = re.split(r'\n\d\.\s+', "\n" + content)
    
    for block in blocks:
        if "Two Areas:" in block:
            regions_2 = parse_region_block(block)
        elif "Three Areas:" in block:
            regions_3 = parse_region_block(block)
        elif "Four Areas:" in block:
            regions_4 = parse_region_block(block)
        elif "Five Areas:" in block:
            regions_5 = parse_region_block(block)

    # 3. Build the final game_data.json
    game_data = {}
    
    # We want to iterate by the canonical names from adjacencies
    for prov, neighbors in adjacencies.items():
        node_id = get_node_name(prov)
        
        # Find stats
        lookup_name = prov
        if lookup_name not in stats:
            for s_name in stats.keys():
                if get_node_name(s_name) == node_id:
                    lookup_name = s_name
                    break
        
        if lookup_name not in stats:
            print(f"Warning: No stats found for {prov}")
            s = {"Difficulty_Score": "1", "Army_Size": "10000"}
        else:
            s = stats[lookup_name]

        # Which regions does it belong to?
        r2 = next((r for r, ps in regions_2.items() if prov in ps), "Unknown")
        r3 = next((r for r, ps in regions_3.items() if prov in ps), "Unknown")
        r4 = next((r for r, ps in regions_4.items() if prov in ps), "Unknown")
        r5 = next((r for r, ps in regions_5.items() if prov in ps), "Unknown")
        
        # We store neighbor node_ids so Godot can directly reference them
        neighbor_ids = [get_node_name(n) for n in neighbors]
        
        game_data[node_id] = {
            "id": node_id,
            "display_name": prov,
            "adjacencies": neighbor_ids,
            "strength": int(s["Difficulty_Score"]),
            "initial_army": int(s["Army_Size"]),
            "regions": {
                "2": r2,
                "3": r3,
                "4": r4,
                "5": r5
            }
        }

    # Verify counts
    print(f"Total Provinces processed: {len(game_data)}")
    
    out_path = Path('../assets/game_data.json')
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(game_data, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f"Successfully generated {out_path} with manual constraints.")

if __name__ == "__main__":
    main()
