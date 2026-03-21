# Turkey Wars: Frontend Design & UI/UX Brief

This document outlines the frontend structure, UI elements, player character classes, and overall game scope for **Turkey Wars**. It is intended to be handed off to a frontend/UI LLM to guide visual polish, layout improvements, styling, and general UX refinements.

---

## 1. Game Scope & Core Loop Overview
**Turkey Wars** is a fast-paced, turn-based grand strategy game mixed with a hands-off, auto-battler tactical resolution phase. The visual style features 2.5D sprite-based units roaming a fully 3D battlefield environment, juxtaposed with a flat, polygonal vector map of Turkey for the grand strategy layer. 

**The Core Loop:**
1. **Picking Phase (Turn 1):** 2 to 5 players alternate clicking neutral provinces on the map of Turkey to claim them as their "Capital" and initial territory.
2. **Playing Phase:** Players take turns selecting enemy or neutral neighboring provinces to invade.
3. **Drafting Phase:** Upon attacking, a troop selection screen appears. The attacker uses their accumulated budget (points/gold) to purchase units. The defender (or an auto-generated neutral AI) then does the same.
4. **Resolution Phase (Battlefield):** The scene transitions to a 3D diorama. The accumulated 2D sprite units spawn on opposite sides and automatically pathfind and attack each other until one army is entirely destroyed.
5. **Aftermath:** The winner takes control of the territory, budget pools are updated (with a capture bonus), and gameplay returns to the overarching Map Screen.

---

## 2. Global Styling & Color Palette Directives
The game requires a military, grand-strategy aesthetic (think Hearts of Iron, Risk, or Advance Wars) with clear, distinct colors.
*   **Player Colors:** Dynamically generated hues (currently HSV spacing) applied to map polygons. 
*   **Map Defaults:** 
    *   Neutral/Uninteractable: Very Light Gray (`#E6E6E6`)
    *   Neighbors (Attackable targets): Gray (`#808080`)
    *   Hovered Neighbor: Dark Gray (`#A9A9A9` / `lightened(0.3)`)
    *   Capitals: Darkened versions of the respective player's core color (`darkened(0.5)`).

---

## 3. Screen Breakdown & UI Elements

### 3.1 Main Menu Screen (`main_menu.tscn`)
Driven by nested UI containers, transitioning between several setup pages.
*   **Main Page Buttons:** New Session, Load Session, Settings.
*   **New Session Page:** New Local Session, New Online Session, Back.
*   **New Local Session Configuration:**
    *   **World Name Input:** A `LineEdit` for the save name.
    *   **Players Container:** Dynamically lists players (2-5). Contains `LineEdit` fields to type custom player names (e.g. "Player1") and a "Remove" button next to each.
    *   **Add Player Button:** Adds another player row (caps at 5).
    *   **Create World Button:** Initializes the JSON save and transitions to the Map Scene.
    *   **Back Button.**

### 3.2 Strategy Map Screen (`map_scene.tscn`)
A flat, interactable 2D polygon map of Turkey composed of distinct `Area2D` provinces.

**UI Elements:**
*   **Top Left HUD (`player_army_label`):** 
    *   Displays current active turn state. Format: `[{Phase}] Turn: {Player Name} | Region: {Region} | Army: {Budget}`
    *   Text color matches the active player's color.
*   **Top Right HUD (`all_players_army_label`):**
    *   A `RichTextLabel` box that persistently lists the exact army budgets of *all* active competitors colored in their respective player colors.
*   **Contextual Hover Tooltip (`tooltip_panel`):**
    *   Visible only when hovering over valid, interactable map provinces. Follows the cursor globally.
    *   Contains three nested labels dynamically updated:
        *   **Name:** "{Province Name} ({Owner Name / 'None'})"
        *   **Strength:** Text warning (e.g., "Normal", "Very Strong") with corresponding color coding (Green to Red).
        *   **Army Size:** Expected format, e.g., "10,000".

### 3.3 Troop Formations & Drafting Screen (`troop_selector.tscn`)
Appears immediately before a battle. Allows players to draft units using their available budget.
*   **Title Label:** e.g., "Player1's Attack Force" or "Player2's Capital Defense".
*   **Budget Label:** Real-time countdown of points: "Remaining Army Size: X".
*   **Unit Roster (3 Rows):**
    *   Each row represents a unit type (Soldier, Rifleman, Tank).
    *   Includes: The unit's display name and cost, a **[-] Minus Button**, a count of drafted units (starts at 0), and a **[+] Plus Button**.
*   **Confirm Button:** Submits the army. If it's the attacker's turn, it transitions to the defender's draft phase. If both are complete, it transitions natively to the battlefield.

### 3.4 2.5D Auto-Battlefield Screen (`new_battlefield.tscn`)
A 3D diorama with procedurally generated weather (currently clear spring afternoon lighting, procedural sky). No player inputs are registered here; it is purely cinematic/tracking.
*   **Top Left Label:** "Attackers: [X]". Red text. Real-time count of alive attacking units remaining.
*   **Top Right Label:** "Defenders: [X]". Blue text. Real-time count of alive defending units remaining.
*   *Note: After all units from one side reach 0 HP, a 3-second delay fires before automatically returning to the Map Screen.*

---

## 4. Player Characters / Units
Units act as 2.5D billboarded sprites (Godot's `AnimatedSprite3D`) sliding across the 3D battlefield mesh. They have distinct costs configured in `game_state.gd`.

1. **Soldier (Internal ID: `warrior`)**
    *   **Combat Style:** Melee infantry. Gets up close to attack.
    *   **Cost:** 500 Budget
    *   **Role:** High volume cannon fodder, frontline screeners.

2. **Rifleman (Internal ID: `ranger`)**
    *   **Combat Style:** Ranged infantry. Stays backline and shoots projectiles at an attack range of ~3.0.
    *   **Cost:** 650 Budget
    *   **Role:** Standard ranged DPS.

3. **Tank (Internal ID: `wizard`)**
    *   **Combat Style:** Heavy, explosive payload attacker.
    *   **Cost:** 2500 Budget
    *   **Role:** Armored siege and splash-damage high-value unit. Less numerous but highly durable.

---

## 5. Objectives for the Frontend/UI Designer
*   **Styling:** Redefine the Godot standard button/menu `Theme` to match a cohesive, stylized UI (e.g., flat design, minimal military/tactical aesthetics, custom fonts).
*   **Panel Enhancements:** Upgrade the Tooltips and Budget screens from standard empty labels to styled `<PanelContainer>` backgrounds with borders, inner padding, and drop-shadows.
*   **Transitions & Polish:** Suggest logical layout anchors to ensure UI remains stable on window resizes (especially the Troop selector and Map HUD layout).
*   **Color Space:** Review the automated HSV-derived colors and propose a safe, color-blind friendly palette for up to 5 concurrent players.