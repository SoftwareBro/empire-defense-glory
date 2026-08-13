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

| Tower | Cost | Role | Branch A | Branch B |
|---|---|---|---|---|
| Archer | 70 | Fast single-target physical | Sharpshooter (crit, pierce) | Ranger Camp (multishot, poison) |
| Barracks | 60 | Blocks the path, melee soldiers | Knights (tanky, taunt) | Assassins (evasion, execute) |
| Mage | 100 | Magic damage, ignores armor | Arcane Wizard (chain bolt) | Sorcerer (polymorph, curse) |
| Artillery | 125 | Slow AoE | Cannon (splash, stun) | Tesla (chain lightning, burn) |

### Enemies

| Enemy | Trait |
|---|---|
| Grunt | Fast, no armor |
| Armored Soldier | High physical resist |
| Ranged Attacker | Shoots barracks soldiers |
| Flyer | Ignores path blockers |
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
│  ├─ towers/   TowerBase.tscn  BuildPlot.tscn
│  └─ enemies/  EnemyBase.tscn
├─ scripts/
│  ├─ autoload/   Events.gd  GameState.gd
│  ├─ core/       level.gd  hud.gd
│  ├─ towers/     tower.gd  build_plot.gd
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

## Milestones

- [x] **M0** — Repo, gitignore, project settings
- [x] **M1** — Route + walking enemy + lives counter
- [x] **M2** — Build plots, radial build menu, gold, tower placement
- [ ] **M3** — Targeting, projectiles, damage, death, bounty
- [ ] **M4** — WaveManager, wave counter, win/lose
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
| **SPACE** | Start the next wave |

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
