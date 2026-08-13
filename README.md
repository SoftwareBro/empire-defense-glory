# Empire Defense: Glory — Series 1

A Kingdom Rush–style 2D tower defense game.

| | |
|---|---|
| **Engine** | Godot 4 (standard build, GDScript) |
| **Renderer** | Compatibility (required for web export) |
| **Target** | Web browser / itch.io |
| **Base resolution** | 1280×720, stretch mode `canvas_items`, aspect `expand` |
| **Art style** | Hand-painted (Kingdom Rush style) |
| **Input** | Mouse / touch |

---

## Scope — Series 1 (full game)

- **3 maps × 10 level variations** = 30 levels
- **4 towers**, each: L1 → L2 → L3, then a choice of **2 specialization branches** at max level
- **6 enemies**, including 1 boss
- **Status effects**: slow, burn, poison, stun, armor shred, crit

### Towers

| Tower | Cost | Targets air | Role | Branch A | Branch B |
|---|---|---|---|---|---|
| Archer | 70 | Yes | Fast single-target physical | Sharpshooter (crit, pierce) | Ranger Camp (multishot, poison) |
| Barracks | 60 | No | Blocks the path, melee soldiers | Knights (tanky, taunt) | Assassins (evasion, execute) |
| Mage | 100 | Yes | Magic damage, ignores armor | Arcane Wizard (chain bolt) | Sorcerer (splash curse) |
| Artillery | 125 | No | Slow, heavy splash | Cannon (bigger splash, stun) | Tesla (fast magic, chain) |

### Enemies

| Enemy | Trait |
|---|---|
| Grunt | Fast, no armor |
| Armored Soldier | High physical resist |
| Ranged Attacker | Shoots barracks soldiers |
| Flyer | Ignores path blockers, only air-capable towers can hit it |
| Swarm / Spawner | Splits into smaller units on death |
| **Boss** | Huge HP, AoE stun, immune to slow |

---

## Architecture principle

**Systems are code. Content is data.**

Towers, enemies, waves, and levels are all `.tres` Resource files. Adding level 27 must never require writing code.

```
res://
├─ scenes/
│  ├─ core/     Level.tscn  HUD.tscn
│  ├─ towers/   TowerBase.tscn  BuildPlot.tscn  Projectile.tscn
│  └─ enemies/  EnemyBase.tscn
├─ scripts/
│  ├─ autoload/   events.gd  game_state.gd
│  ├─ core/       level.gd  wave_manager.gd  hud.gd
│  ├─ towers/     tower.gd  build_plot.gd  projectile.gd
│  ├─ enemies/    enemy.gd
│  ├─ ui/         build_menu.gd
│  └─ resources/  tower_data.gd  tower_level.gd
│                  enemy_data.gd  level_data.gd
│                  wave_data.gd   wave_entry.gd
├─ data/
│  ├─ towers/   archer  barracks  mage  artillery
│  ├─ enemies/  grunt … boss
│  └─ levels/   m1_v1 … m3_v10
├─ art/
└─ audio/
```

**Map construction:** no TileMap. Each level is one hand-painted background `Sprite2D` + a route sampled from `path_points` + `BuildPlot` markers spawned from `plot_points`. A level variation = same biome art, different points and waves.

**Decoupling:** every system talks through the `Events` signal bus. Towers never reference the HUD, the HUD never references enemies.

---

## Combat model

- Enemies register in the `enemies` group. Towers scan that group and distance-check — no physics queries, no shape resizing when range changes on upgrade.
- Each enemy tracks `progress` (pixels travelled along the route), which is what makes **first / last** targeting possible.
- Damage is `amount * (1.0 - resist)`, where resist is `physical_resist` or `magic_resist` depending on the shot's `damage_type`. This is why Mage towers counter armour.
- Projectiles home on the live target but remember its last position, so a shot whose target dies mid-flight still lands instead of vanishing.
- Splash shots damage every enemy within `splash_radius` of the impact point.

### Targeting modes

Set per tower via `targeting_mode` in its `.tres`.

| Mode | Picks |
|---|---|
| `first` | Furthest along the path (genre default) |
| `last` | Least far along — good for cleanup towers |
| `closest` | Nearest to the tower |
| `strongest` | Highest current health |

---

## Wave lifecycle

`WaveManager` is a state machine: `COUNTDOWN → SPAWNING → CLEARING →` (next wave, or `FINISHED`).

- `delay_before` on each `WaveData` sets that wave's countdown. Pressing **SPACE** during a countdown skips it and pays **2 gold per whole second saved** — the risk/reward lever the genre runs on.
- A wave's `entries` each run as their own coroutine, so one wave can send a slow group and a fast group that overlap. `start_delay` staggers them.
- Victory fires only when every wave has spawned **and** the map is clear. Defeat fires the moment lives hit zero.
- Both outcomes pause the tree. The overlay uses `process_mode = Always` so its Restart button still responds while paused.

---

## Milestones

- [x] **M0** — Repo, gitignore, project settings
- [x] **M1** — Route + walking enemy + lives counter
- [x] **M2** — Build plots, radial build menu, gold, tower placement
- [x] **M3** — Targeting, projectiles, damage, death, bounty
- [x] **M4** — WaveManager, automatic wave flow, early-call bonus, win/lose screens
- [ ] **M5** — Upgrades L1→L3 + 2 branches + sell
- [ ] **M6** — Effects pass: particles, damage numbers, screen shake, SFX
- [ ] **M7** — In-editor level editor tool (click to place path + plots, save `.tres`)
- [ ] **M8** — Real art pass, then content fill-out

---

## Controls

| Input | Action |
|---|---|
| Click an empty plot | Open the radial build menu |
| Click a tower button | Build it (greyed out if you cannot afford it) |
| Click anywhere else | Dismiss the menu |
| Hover a built tower | Show its attack range |
| **SPACE** | Call the next wave early for bonus gold |

## Running locally

1. Install [Godot 4](https://godotengine.org/download) — **standard** build, not .NET
2. `git clone https://github.com/SoftwareBro/empire-defense-glory.git`
3. Godot → Import → select `project.godot`
4. Press **F5**

## Web export (itch.io)

- Export preset: **Web**
- Upload the exported `.zip` to itch.io, mark it **"This file will be played in the browser"**
- Enable **SharedArrayBuffer support** in the itch.io embed settings (required by Godot 4 web builds)
- Keep total build under ~50 MB; use `.ogg` audio and atlas textures ≤ 2048px

## Known gotchas

- A full-screen `ColorRect` or `TextureRect` with the default `mouse_filter = Stop` will swallow every click before it reaches the world. All full-screen UI in this project must use `mouse_filter = Ignore`.
- Anything that must stay interactive while `get_tree().paused` is true needs `process_mode = Always`.
- Godot's New Project dialog appends the project name to the path. When cloning this repo first, point *Project Path* at the existing folder and ignore the "selected path is not empty" warning.
