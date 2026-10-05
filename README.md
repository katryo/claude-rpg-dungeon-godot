# Shards of Dawn: The Dark Castle

An HD-2D style JRPG for **Godot 4.7**: pixel-art billboard characters in a lit,
fogged and depth-of-field-blurred 3D castle. Three heroes storm Castle Nocturne
to defeat the Dark Lord Malzeth.

![Title](docs/screenshots/title.jpg)

| Exploration | Battle |
|---|---|
| ![Field](docs/screenshots/field.jpg) | ![Battle](docs/screenshots/battle.jpg) |
| ![Menu](docs/screenshots/menu.jpg) | ![Boss](docs/screenshots/boss.jpg) |
| ![Status](docs/screenshots/status.jpg) | ![Equip](docs/screenshots/equip.jpg) |

## The party

| | Hero | Class | Role |
|---|---|---|---|
| ⚔️ | **Arlen** | Magic Warrior (protagonist) | Elemental sword skills (Flame Blade, Thunder Slash, Lumina Blade) plus Cure |
| 🛡️ | **Garrick** | Armored Warrior (sidekick) | Tank: Provoke, Shield Bash, Iron Wall, War Cry, Earthsplitter |
| 🔮 | **Theia** | Arch Mage (wand, Greek chiton & laurel wreath) | Fira / Blizzara / Thundara, Asclepius' Grace, Anastasis, Meteor, Holy |

## Running

1. Open the folder in Godot 4.7 (Forward+ renderer) and press **F5**, or run
   `godot --path .` from this directory.
2. No imported assets are required: every sprite, texture, sound effect and
   music track is generated at runtime from code.

### Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move / cursor | Arrows or WASD | D-pad / left stick |
| Confirm / check / talk | Z, Enter, Space, E | A |
| Cancel / back | X, Esc, Backspace | B |
| Open menu | X, Tab, M, C | Y |
| Dash | Shift | — |

The mouse also works in menus (click to choose, right-click to go back).

## Gameplay

- **Explore** Castle Nocturne: the entrance hall, the west and east wings, the
  great hall and the throne room.
- **Six treasure chests** hold better weapons, armor, accessories and items.
- **Enemies roam visibly** on the map (no random encounters); touch one to fight.
  They chase you when you get close.
- The **save crystal** in the great hall fully restores the party and records a
  checkpoint. If the party falls you can retry from the last crystal.
- **Turn-based battles**: Attack, Skills, Items, Defend, Flee. Turn order is by
  Speed (shown top-right). Elemental weaknesses deal 1.5x damage; buffs,
  debuffs, taunts, criticals and revives are all supported.
- **Party menu**: Items, Skills (field healing), Equipment (with stat
  comparison) and a detailed Status page per hero.
- **The Dark Lord** has two phases: at half HP he transforms, acts twice per
  round and charges the devastating *Abyssal Ruin* (watch for the warning and
  Defend!).

## How the HD-2D look is built

- 2D pixel sprites on `Sprite3D` billboards (Y-axis locked, nearest filtering,
  alpha-scissor) with soft blob shadows, standing in a real 3D level.
- Tilt-shift depth of field (`CameraAttributesPractical` near + far blur)
  focused on the party.
- Warm flickering point lights from braziers and wall torches, cool moonlight,
  volumetric fog, SSAO, filmic tonemapping, bloom on fire/magic, colour grading
  and a screen vignette.
- Drifting embers and dust particles; particle-based spell effects (flame
  columns, ice shards, lightning, holy pillars, dark implosions, meteors).

> Note: MSAA is intentionally left **off**. With MSAA enabled the depth-of-field
> pass blurs the in-focus subject as well.

## Project layout

```
scenes/main.tscn            Entry scene (flow controller)
scripts/main.gd             Title -> field <-> battle -> ending / game over
scripts/autoload/game.gd    Party, stats, leveling, inventory, equipment, checkpoints
scripts/autoload/ui.gd      Theme, dialogue window, transitions, vignette, toasts
scripts/autoload/sfx.gd     Procedural sound effects and music
scripts/data/db.gd          Heroes, skills, items, equipment, enemies, encounters, map
scripts/data/sprite_data.gd ASCII pixel art for every character
scripts/gfx/pixel_art.gd    Builds sprite / tile / effect textures at runtime
scripts/world/props.gd      Environment, lights, fire, pillars, braziers, particles
scripts/world/castle.gd     Field exploration
scripts/battle/battle.gd    Battle scene, UI, AI and effects
scripts/battle/battler.gd   Combatant model
scripts/ui/                 Party menu, title/ending, cursor list, gauges
tests/                      Headless checks (see below)
```

The castle layout is the ASCII `MAP` in `scripts/data/db.gd`; edit it to reshape
the dungeon (`#` wall, `.` floor, `r` carpet, `i` pillar, `b` brazier, `E` enemy
group, `C` chest, `S` save crystal, `B` throne, `P` start).

## Tests

```sh
godot --headless --path . res://tests/check_scripts.tscn   # every script compiles
godot --headless --path . res://tests/flow_test.tscn       # input-driven playthrough: title -> menu -> battle -> chest -> boss -> ending
godot --headless --path . res://tests/sim_battles.tscn     # balance simulation of every fight with an auto-battle AI
godot --path . res://tests/shots.tscn                      # renders screenshots (needs a GPU); SHOTS_DIR=/path to choose output
```
