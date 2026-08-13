# Empire Defense: Glory — Series 1

A Kingdom Rush–style 2D tower defense game.

| | |
|---|---|
| **Engine** | Godot 4 (standard build, GDScript) |
| **Renderer** | Compatibility (required for web export) |
| **Target** | Web browser / itch.io |
| **Base resolution** | 1280×720, stretch mode `canvas_items`, aspect `expand` |
| **Art style** | Hand-authored vector (Kingdom Rush style) |
| **Input** | Mouse / touch |

---

## Scope — Series 1 (full game)

- **3 maps × 10 level variations** = 30 levels
- **4 towers**, each **L1 → L2 → L3**. Level 3 is the ceiling.
- **6 enemies**, including 1 boss
- **Status effects**: slow, burn, poison, stun, armor shred, crit

### Towers

| Tower | Cost | Targets air | Role | Shot |
|---|---|---|---|---|
| Auto-Archer | 70 | Yes | Fast single-target physical | Repeating crossbow bolt |
| Barracks | 60 | No | Short-range garrison, holds a lane | Thrown javelin |
| Mage | 100 | Yes | Magic damage, ignores armor | Arcane orb |
| Artillery | 125 | No | Slow, heavy splash | Fused mortar shell |

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
│  ├─ enemies/  EnemyBase.tscn
│  ├─ fx/       DamageNumber.tscn  Shockwave.tscn
│  └─ ui/       MainMenu.tscn  WorldMap.tscn
├─ scripts/
│  ├─ autoload/   events.gd  game_state.gd  fx.gd
│  │              save_game.gd  campaign.gd
│  ├─ core/       level.gd  wave_manager.gd  hud.gd
│  ├─ towers/     tower.gd  build_plot.gd  projectile.gd
│  ├─ enemies/    enemy.gd
│  ├─ fx/         damage_number.gd  shockwave.gd
│  ├─ ui/         build_menu.gd  upgrade_panel.gd
│  └─ resources/  tower_data.gd  tower_level.gd
│                  enemy_data.gd  level_data.gd
│                  wave_data.gd   wave_entry.gd
├─ data/
│  ├─ towers/    archer  barracks  mage  artillery
│  ├─ enemies/   grunt … boss
│  ├─ levels/    m1_v1 … m3_v10
│  └─ campaign/  campaign.tres
├─ art/
│  ├─ towers/  autoarcher/  barracks/  mage/  artillery/
│  └─ fx/      bolt_arrow  javelin  arcane_orb  mortar_shell
└─ audio/
```

**Map construction:** no TileMap. Each level is one hand-painted background `Sprite2D` + a route sampled from `path_points` + `BuildPlot` markers spawned from `plot_points`. A level variation = same biome art, different points and waves.

**Decoupling:** every system talks through the `Events` signal bus. Towers never reference the HUD, the HUD never references enemies.

---

## Art conventions

All tower and projectile art is hand-authored SVG, checked in as source. Godot rasterises it on import and regenerates the `.svg.import` sidecars, so those are never hand-written.

Every tower is **two files**, because the tower is drawn in two pieces that move independently:

| File | Contents |
|---|---|
| `base_l1.svg` | The static half: foundation, buttresses, deck, mount |
| `turret_l1.svg` | The rotating half: whatever swings to face the target |

The contract those files obey:

- **256×256 canvas over a `0 0 96 96` viewBox.** Art is authored oversized and scaled back down by `Tower.ART_SCALE` (0.25), so it stays crisp when zoomed.
- **Pivot is dead centre, (48, 48).** Both halves share it, so the turret spins without drifting off its mount.
- **Turret halves are authored pointing right (+X)**, because Godot measures rotation clockwise from +X. A turret drawn facing up would be 90° wrong at runtime.
- **Key light from the top-left.** Highlights hug the upper-left rim, contact shadows fall down-right. Every shape is a three-pass stack: dark outline, gradient body, top-left highlight.
- **Projectiles** use a 96×96 canvas over a `0 0 32 32` viewBox, also pointing right, centred on the shot itself so `Projectile.rotation` stays honest.

`muzzle_offset` in each `.tres` is measured off that turret's actual barrel tip in viewBox units, converted to game pixels. It is why shots leave the crossbow rail, the shield notch, the crystal face and the mortar bell rather than all leaving the centre of the tower.

The Auto-Archer's bowstring, nocked bolt and magazine rounds are **not** in its SVG — they have to move, so `Tower._draw_bow_rig()` draws them in the same viewBox coordinates the file uses. `bow_rig` in the `.tres` opts a level into that overlay.

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
- `WaveManager.early_call_bonus_for()` is the single source of truth for that bonus, so the HUD can never advertise an amount the player is not actually paid.
- A wave's `entries` each run as their own coroutine, so one wave can send a slow group and a fast group that overlap. `start_delay` staggers them.
- Victory fires only when every wave has spawned **and** the map is clear. Defeat fires the moment lives hit zero.
- Both outcomes pause the tree. The overlay uses `process_mode = Always` so its Restart button still responds while paused.

---

## Upgrade model

A tower holds a `level_index` into `data.levels`. `current_level()` resolves it to a single `TowerLevel`, and every combat number is read from that. **An upgrade is just pointing at a different resource** — there is no per-level code anywhere.

- Click a **built** tower to open the upgrade panel; click an **empty** plot for the build menu.
- The panel shows current stats and a `Next:` preview line so the purchase can be judged before paying.
- The ladder runs **Lv 1 → Lv 2 → Lv 3**. At Lv 3 the tower is done: the panel reads `Fully upgraded.` and only Sell remains.
- **Sell** refunds **70%** of everything invested (build cost + every upgrade actually paid for), computed by `total_invested()` rather than stored, so it stays correct however far the tower was taken.
- Rank is readable on the map: one pip per level above the tower, turning **gold** with a thin gold rim once the tower is topped out.

---

## Effects

Everything visual routes through the `Fx` autoload, so no system needs to know where effects live in the tree or how they are built. Effects parent to the `fx_root` group node, which draws above enemies and dies with the level.

Particles are `CPUParticles2D`, not GPU — the web export runs on the Compatibility renderer, where CPU particles are the dependable choice.

`Shockwave` is the shared primitive: an expanding ring drawn with `draw_arc()` rather than textured, so it costs nothing, tints to whatever fired it, and needs no art. It eases out cubically and thins as it fades, so it reads as released pressure. Passing `start_radius > end_radius` collapses it inward instead, which is how the "snap into place" accents work.

| Call | Reads as |
|---|---|
| `build_flourish()` | Dust ring punches out, an accent ring in the tower's own colour snaps inward, grit is thrown, camera thumps |
| `upgrade_flourish()` | Stacked gold rings, embers with negative gravity so they rise off the build, and a `LV n` banner |
| `impact()` | Splash hits get a ring at their **true** blast radius plus smoke and sparks; magic hits get a violet ring; everything else sparks |
| `damage_number()` | Floating figure, tinted by damage type, larger and gold on a kill |
| `muzzle_flash()` | Short spit of light at the barrel tip |
| `shake()` | Camera kick. Repeated calls take the strongest — they do not stack |

The build and upgrade animations live on the tower itself rather than in `Fx`, because they scale and tint the sprite: a fade-in from 35% with a `TRANS_BACK` overshoot on build, and a `TRANS_ELASTIC` punch plus a decaying gold flare on upgrade. `Tower._process()` stays disabled until an upgrade actually happens, so idle towers cost nothing.

---

## Milestones

- [x] **M0** — Repo, gitignore, project settings
- [x] **M1** — Route + walking enemy + lives counter
- [x] **M2** — Build plots, radial build menu, gold, tower placement
- [x] **M3** — Targeting, projectiles, damage, death, bounty
- [x] **M4** — WaveManager, automatic wave flow, early-call bonus, win/lose screens
- [x] **M5** — Upgrades L1→L3, sell for refund
- [x] **M6** — Effects pass: particles, damage numbers, shockwaves, build/upgrade juice, screen shake
- [ ] **M6.5** — SFX
- [ ] **M7** — In-editor level editor tool (click to place path + plots, save `.tres`)
- [ ] **M8** — Remaining enemies, then content fill-out to 30 levels

---

## Controls

| Input | Action |
|---|---|
| Click an empty plot | Open the radial build menu |
| Click a tower button | Build it (greyed out if you cannot afford it) |
| Click a built tower | Open the upgrade / sell panel |
| Click anywhere else | Dismiss the menu |
| Hover a built tower | Show its attack range |
| **SPACE** | Call the next wave early for bonus gold |

## Running locally

1. Install [Godot 4](https://godotengine.org/download) — **standard** build, not .NET
2. `git clone https://github.com/SoftwareBro/empire-defense-glory.git`
3. Godot → Import → select `project.godot`
4. Press **F5**

On first open Godot imports the SVGs and writes the `.svg.import` sidecars. That is expected and those files are gitignored.

## Web export (itch.io)

- Export preset: **Web**
- Upload the exported `.zip` to itch.io, mark it **"This file will be played in the browser"**
- Enable **SharedArrayBuffer support** in the itch.io embed settings (required by Godot 4 web builds)
- Keep total build under ~50 MB; use `.ogg` audio and atlas textures ≤ 2048px

## Known gotchas

- A full-screen `ColorRect` or `TextureRect` with the default `mouse_filter = Stop` will swallow every click before it reaches the world. All full-screen UI in this project must use `mouse_filter = Ignore`.
- Anything that must stay interactive while `get_tree().paused` is true needs `process_mode = Always`.
- Turret art authored facing any direction other than right will be rotated wrongly at runtime. Check the pivot is (48, 48) and the barrel points at +X.
- Godot's New Project dialog appends the project name to the path. When cloning this repo first, point *Project Path* at the existing folder and ignore the "selected path is not empty" warning.
