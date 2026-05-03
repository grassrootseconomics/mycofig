# Plants and People Gardening

Godot 4 game prototype with two related simulations:
- **Plants mode**: mycorrhizal nutrient exchange in a garden ecosystem.
- **People mode**: social/economic exchange using basket-like connectors.

## Requirements
- `godot4` on your PATH (tested with Godot `4.5.1`).

## Run
From project root:

```bash
cd /home/wor/src/mycofig
godot4 --path .
```

Run a specific scene:

```bash
godot4 --path . --scene res://scenes/level.tscn
godot4 --path . --scene res://scenes/sociallevel.tscn
godot4 --path . --scene res://scenes/world_foundation_test.tscn
```

Headless smoke test:

```bash
godot4 --path . --headless --quit-after 1200 --log-file /tmp/mycofig.log
```

## Game Modes
Choose mode from title screen:
- `Tutorial`
- `Free Garden`
- `Challenge`
- `COFI` (social economy-focused challenge)

Also toggle between plant/social views with the title screen checkboxes.

## Controls
- `Left Click`: drag entities and place inventory items.
- `Left Click + Drag` (empty world) or `Right Click + Drag`: pan camera across the larger tiled map.
- `WASD`: pan camera.
- `Two-finger trackpad drag`: pan camera.
- `Arrow Keys`: move the selected active agent.
- `Shift + Arrow Keys`: also pan camera.
- `Tab`: cycle active agent.
- `M`: toggle baby/spawn behavior.
- `B`: toggle resource bars (bars start ON by default).
- `+` / `-`: change movement speed.
- `Esc` or `Q`: end run / go to game-over screen.
- `2/3/4/5` (social mode): set connector count tuning.
- Inventory panel visibility: no hotkey yet (always shown).

Keybinding implementation:
- All shared gameplay hotkeys are centralized in `scenes/level_helpers.gd` via `handle_gameplay_hotkeys(...)`.
- `scenes/level.gd` and `scenes/sociallevel.gd` call that shared handler.

Placement rules:
- Plants/fungi move freely while dragging/keyboard movement, then snap smoothly to the nearest unoccupied tile center.
- Only one plant/fungi can occupy a tile at a time.
- While dragging or arrow-key moving plants/fungi: tile outline is `green` for available and `red` for occupied.
- If the active moving sprite dies, no other sprite is auto-selected; camera focus stays where it is until manual selection.

World foundation debug (test scene):
- `F1`: toggle soil debug overlay.
- `F2`: reset static baseline map.
- `F3`: toggle tile stage edit mode.
- `Left Click` (with edit on): cycle tile stage `0 -> 1 -> 2 -> 3 -> 0`.

## Project Structure
- `global/global.gd`: global state, rank thresholds, spawn scaling, platform tuning.
- `scenes/level.gd`: plants gameplay scene controller.
- `scenes/sociallevel.gd`: social gameplay scene controller.
- `scenes/world_foundation.gd`: shared tiled world, soil tile model, stage rendering, camera clamp/pan.
- `scenes/world_foundation_test.tscn`: static validation map for M1 grid foundation.
- `scenes/agent.gd`, `scenes/socialagent.gd`, `scenes/basket.gd`: core actor logic.
- `scenes/bird.gd`, `scenes/tuktuk.gd`: predator/raider logic.
- `scenes/ui.gd`: in-game HUD, inventory placement, drag preview.
- `scenes/level_helpers.gd`: shared scene helpers (signal wiring, myco line invalidation, audio stop).

## Recent Cleanup Notes
- Deferred spawning for predators/trades to avoid physics-flush state errors.
- Fixed predator movement logic so spawned birds/tuktuks appear and pursue targets reliably.
- Added mobile-aware runtime limits:
  - lower social buddy radius
  - capped predator wave size
- Replaced duplicated scene utility code with reusable helpers in `scenes/level_helpers.gd`.

## Troubleshooting
- If Godot crashes on startup due `user://logs/...` in restricted environments, run with:
  - `--log-file /tmp/mycofig.log`
- Forced headless quits (`--quit-after`) may still print resource-leak warnings during shutdown, even when gameplay is healthy.
