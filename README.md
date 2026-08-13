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

| Tower | Cost | Targets air | Role | Weapon |
|---|---|---|---|---|
| Auto-Archer | 70 | Yes | Fast single-target physical | Homing crossbow bolt |
| Spell Tower | 60 | Yes | Manually cast AoE nuke | Lightning out of the sky |
| Wizard | 100 | Yes | Magic damage, ignores armor | Charged laser beam |
| Artillery | 125 | No | Slow, heavy splash | Lobbed mortar shell |

### Enemies

| Enemy | Trait |
|---|---|
| Grunt | Fast, no armor |
| Armored Soldier | High physical resist |
| Ranged Attacker | Out-ranges short-range towers |
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
│  ├─ towers/   TowerBase.tscn  BuildPlot.tscn
│  │            Projectile.tscn  MortarShell.tscn
│  ├─ enemies/  EnemyBase.tscn
│  ├─ fx/       DamageNumber.tscn  Shockwave.tscn
│  │            Beam.tscn  Lightning.tscn
│  └─ ui/       MainMenu.tscn  WorldMap.tscn
├─ scripts/
│  ├─ autoload/   events.gd  game_state.gd  fx.gd
│  │              save_game.gd  campaign.gd
│  ├─ core/       level.gd  wave_manager.gd  hud.gd
│  ├─ towers/     tower.gd  build_plot.gd
│  │              projectile.gd  mortar_shell.gd
│  ├─ enemies/    enemy.gd
│  ├─ fx/         damage_number.gd  shockwave.gd
│  │              beam.gd  lightning.gd
│  ├─ ui/         build_menu.gd  upgrade_panel.gd
│  │              ability_button.gd
│  │              pixel_theme.gd  pixel_plate.gd
│  └─ resources/  tower_data.gd  tower_level.gd
│                  enemy_data.gd  level_data.gd
│                  wave_data.gd   wave_entry.gd
├─ data/
│  ├─ towers/    archer  barracks  mage  artillery
│  ├─ enemies/   grunt … boss
│  ├─ levels/    m1_v1 … m3_v10
│  └─ campaign/  campaign.tres
├─ art/
│  ├─ towers/  autoarcher/  spell/  mage/  artillery/
│  └─ fx/      bolt_arrow  javelin  arcane_orb  mortar_shell
└─ audio/
```

> `data/towers/barracks.tres` now holds the Spell Tower. The filename is kept so
> the level resources that reference it still resolve; its `id` is `&"spell"`.
> The retired `art/towers/barracks/` keep and the `javelin` projectile are left
> in the repo but nothing loads them.

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

`muzzle_offset` in each `.tres` is measured off that turret's actual barrel tip in viewBox units, converted to game pixels. It is why shots leave the crossbow rail, the claw socket and the mortar bell rather than all leaving the centre of the tower.

Two exceptions to "the turret is one static file":

- The Auto-Archer's bowstring, nocked bolt and magazine rounds are **not** in its SVG — they have to move, so `Tower._draw_bow_rig()` draws them in the same viewBox coordinates the file uses. `bow_rig` in the `.tres` opts a level into that overlay.
- The Wizard's turret is authored as an **open three-pronged claw** with an empty socket at its tip. The charging core and the three orbiting crystals are drawn in code, so the socket has to actually be empty for them to appear inside it.

The Spell Tower's turret is the only four-fold symmetric one, because it turns under its own power instead of aiming. Its shadow is centred rather than cast to one side — an offset shadow would appear to wobble round with the ring.

---

## Combat model

- Enemies register in the `enemies` group. Towers scan that group and distance-check — no physics queries, no shape resizing when range changes on upgrade.
- Each enemy tracks `progress` (pixels travelled along the route), which is what makes **first / last** targeting possible.
- Damage is `amount * (1.0 - resist)`, where resist is `physical_resist` or `magic_resist` depending on the shot's `damage_type`. This is why Wizard towers counter armour.
- Splash damage falls off with distance from the impact point, down to 55% at the rim, so a direct hit is worth aiming for.
- `Enemy.predict_position(seconds)` samples the baked route curve ahead of time. Mortars lead their target with it, and because it follows the curve rather than extrapolating a straight line, the lead stays correct through corners.

### Weapon models

`attack_kind` on each `TowerData` decides **how** a tower attacks. This is the one deliberate branch in the combat code, and it exists because four towers firing the same homing projectile with different art is not really four towers.

| `attack_kind` | Tower | Behaviour |
|---|---|---|
| `projectile` | Auto-Archer | Homing bolt with real travel time. Steers onto the target, so it cannot miss, but it can arrive late. |
| `beam` | Wizard | Three crystals orbit the tower, then rush inward and converge on the core over `windup_time`. The core snaps, and a beam strikes **instantly** — no travel, no miss. |
| `mortar` | Artillery | The barrel pulls **backward**, thrusts **forward** to launch, then a shell arcs `arc_height` pixels up and falls onto a predicted ground point after `flight_time`. It commits to the ground, so a fast target can walk out of it. |
| `ability` | Spell Tower | Never fires on its own. Charges over `recharge_time`, then a rune appears above it. Clicking the rune drops lightning for AoE damage. |

Aborting is handled: if a Wizard's target dies mid-charge it stops, keeps a short cooldown and re-acquires rather than firing at nothing. If a Spell Tower has no valid target when clicked, the rune flashes red and **keeps its charge** — a mis-click never wastes a 14 second recharge.

### Cadence

A cycle is **reload plus wind-up**, not reload alone. Every tower's damage is solved against the full cycle, so slowing the game down did not weaken anything:

| Tower | Cycle (L1) | Damage (L1) | Sustained |
|---|---|---|---|
| Auto-Archer | 1.18s | 22 | 18.7 dmg/s |
| Wizard | 2.40s (1.85 reload + 0.55 charge) | 58 | 24.1 dmg/s |
| Artillery | 3.55s (3.33 reload + 0.22 telegraph) | 96 | 27.0 dmg/s |
| Spell Tower | 14s, manual | 150 in a 110px blast | on demand |

Multiplying `damage * fire_rate` would overstate a charging weapon by up to 20%, so the upgrade panel divides by the real cycle instead.

### Targeting modes

Set per tower via `targeting_mode` in its `.tres`.

| Mode | Picks |
|---|---|
| `first` | Furthest along the path (genre default) |
| `last` | Least far along — good for cleanup towers |
| `closest` | Nearest to the tower |
| `strongest` | Highest current health |

The Spell Tower ignores this. It picks the point that would **catch the most enemies** in its blast radius, breaking ties toward whichever group is furthest along the path.

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
- The ladder runs **Lv 1 → Lv 2 → Lv 3**. At Lv 3 the tower is done: the panel reads `Fully upgraded.` and only Sell remains.
- **Sell** refunds **70%** of everything invested (build cost + every upgrade actually paid for), computed by `total_invested()` rather than stored, so it stays correct however far the tower was taken.
- Rank is readable on the map: one pip per level above the tower, turning **gold** with a thin gold rim once the tower is topped out.

### The panel

Drawn in the pixel style rather than with Godot's default controls: a hard-edged plate, a two-tone bevel, corner studs, zero corner radius and antialiasing off everywhere. `PixelPlate` paints its own bevel in `_draw()` because `StyleBoxFlat` supports only **one** border colour, and a bevel needs two — light along the top and left, dark along the bottom and right. `PixelTheme` holds the palette and dresses buttons, including deleting the default focus ring and sinking a pressed label down one pixel.

Stats are **segmented bars** rather than raw numbers, measured against that tower's *own* top level, so a bar answers "how far up this ladder am I" instead of inviting a meaningless comparison between an archer and a mortar. The upgrade is previewed as extra green segments **inside the same bar**.

Which rows appear depends on the weapon — a Spell Tower shows `POWER / REACH / BLAST / CYCLE` and no fire rate, because it has none. Wind-up and recharge are inverted, so a shorter charge still fills the bar up. When an upgrade is unaffordable the panel names the shortfall instead of just greying the button out.

---

## Effects

Everything visual routes through the `Fx` autoload, so no system needs to know where effects live in the tree or how they are built. Effects parent to the `fx_root` group node, which draws above enemies and dies with the level.

Particles are `CPUParticles2D`, not GPU — the web export runs on the Compatibility renderer, where CPU particles are the dependable choice.

`Shockwave` is the shared primitive: an expanding ring drawn with `draw_arc()` rather than textured, so it costs nothing, tints to whatever fired it, and needs no art. It eases out cubically and thins as it fades, so it reads as released pressure. Passing `start_radius > end_radius` collapses it inward instead, which is how the "snap into place" accents work.

`Beam` and `Lightning` are rebuilt from scratch every frame rather than animated, which is what makes them crackle. Both stack three passes — a wide soft haze, a solid body, and a thin near-white core — so they read as light rather than as a coloured line.

| Call | Reads as |
|---|---|
| `build_flourish()` | Dust ring punches out, an accent ring in the tower's own colour snaps inward, grit is thrown, camera thumps |
| `upgrade_flourish()` | Stacked gold rings, embers with negative gravity so they rise off the build, and a `LV n` banner |
| `charge_snap()` | Ring collapsing **inward** onto the core, the moment a charge completes |
| `beam()` | Jittering three-pass beam that tapers toward both ends |
| `mortar_launch()` | Directional cone of smoke and sparks out of the bell, plus a camera kick |
| `mortar_impact()` | Ring at the shell's **true** blast radius, dirt thrown outward, lingering smoke |
| `spell_ready()` | Accent ring blooming off the tower when a spell finishes charging |
| `lightning_strike()` | Forked bolt dropped from above the screen, four flashes, ground ring at the blast radius |
| `impact()` | Splash hits get a ring at their true blast radius plus smoke and sparks; magic hits get a violet ring; everything else sparks |
| `damage_number()` | Floating figure, tinted by damage type, larger and gold on a kill |
| `shake()` | Camera kick. Repeated calls take the strongest — they do not stack |

The build and upgrade animations live on the tower itself rather than in `Fx`, because they scale and tint the sprite: a fade-in from 35% with a `TRANS_BACK` overshoot on build, and a `TRANS_ELASTIC` punch plus a decaying gold flare on upgrade.

`AbilityButton` is the floating rune. It is built in code rather than loaded from a scene, and it knows nothing about `Tower` — state is pushed in with `set_state()`, clicks come back as an `activated` signal. That one-way dependency is deliberate: a scene whose script type-hints `Tower` would make `tower.gd` preloading it a cyclic reference.

---

## Milestones

- [x] **M0** — Repo, gitignore, project settings
- [x] **M1** — Route + walking enemy + lives counter
- [x] **M2** — Build plots, radial build menu, gold, tower placement
- [x] **M3** — Targeting, projectiles, damage, death, bounty
- [x] **M4** — WaveManager, automatic wave flow, early-call bonus, win/lose screens
- [x] **M5** — Upgrades L1→L3, sell for refund
- [x] **M6** — Effects pass: particles, damage numbers, shockwaves, build/upgrade juice, screen shake
- [x] **M6.2** — Four distinct weapon models, manual-cast Spell Tower, pixel-art upgrade panel
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
| **Click the rune above a Spell Tower** | Discharge its lightning |
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

- The UI is laid out in the pixel style but still renders in Godot's default font. Dropping a pixel `.ttf` into `art/ui/` and setting it as the project's default font is the last step to make it fully authentic — no code has to change.
- Any new clickable in the world **must** call `set_input_as_handled()`. `Level._unhandled_input()` closes both menus on any unhandled mouse press, so a click that does not mark itself handled will dismiss the very panel it opened.
- A full-screen `ColorRect` or `TextureRect` with the default `mouse_filter = Stop` will swallow every click before it reaches the world. All full-screen UI in this project must use `mouse_filter = Ignore`.
- Anything that must stay interactive while `get_tree().paused` is true needs `process_mode = Always`.
- Turret art authored facing any direction other than right will be rotated wrongly at runtime. Check the pivot is (48, 48) and the barrel points at +X.
- Godot's New Project dialog appends the project name to the path. When cloning this repo first, point *Project Path* at the existing folder and ignore the "selected path is not empty" warning.
