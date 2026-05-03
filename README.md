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
- `G`: toggle repositioning of already-placed plants/fungi (default `OFF`).
- `B`: toggle resource bars (bars start ON by default).
- `+` / `-`: change movement speed.
- `Esc` or `Q`: end run / go to game-over screen.
- `2/3/4/5` (social mode): set connector count tuning.
- Inventory panel visibility: no hotkey yet (always shown).

Keybinding implementation:
- All shared gameplay hotkeys are centralized in `scenes/level_helpers.gd` via `handle_gameplay_hotkeys(...)`.
- `scenes/level.gd` and `scenes/sociallevel.gd` call that shared handler.

Placement rules:
- With reposition toggle `G` enabled, plants/fungi move via drag/arrow keys and then snap smoothly to the nearest unoccupied tile center.
- With reposition toggle `G` disabled (default), already-placed plants/fungi cannot be repositioned; only harvest-ready fruit/seed/mushroom drag-to-inventory is allowed.
- Only one plant/fungi can occupy a tile at a time.
- While dragging or arrow-key moving plants/fungi: tile outline is `green` for available and `red` for occupied.
- If the active selected sprite dies (any death path), it is unselected and no replacement is auto-selected.

Bean lifecycle (plants mode):
- Bean now progresses through staged sprites: `sprout -> vine -> pod-ready -> brown/dead`.
- Progress to maturity remains nutrient-driven (not scale-driven).
- Stage advance requires consuming `1` of each nutrient in `3` full consumption cycles, with an extra wait tick between stage promotions.
- Only pod-ready beans can be harvested into inventory; earlier stages snap back to the map if dragged over inventory.
- Pod-stage reproduction only: each pod event rolls random babies `0..3` (max), then dead-stage has no reproduction.
- Harvesting adds bean seeds back into inventory.
- Dead-stage bean vine fades out, then is removed and frees its tile for new placement/spawn.

Squash lifecycle (plants mode):
- Squash now follows the same lifecycle rules as bean: `sprout -> vine -> pod-ready -> brown/dead`.
- Same maturity gate: consume `1` of each nutrient across `3` full cycles, with a wait tick between stage promotions.
- Same harvest/baby/death rules: pod-ready only harvest, random `0..3` babies during pod stage, and dead-stage fade/removal.

Maize lifecycle (plants mode):
- Maize now follows the same lifecycle rules as bean/squash: `sprout -> stalk -> pod-ready -> brown/dead`.
- Same maturity gate: consume `1` of each nutrient across `3` full cycles, with a wait tick between stage promotions.
- Same harvest/baby/death rules: pod-ready only harvest, random `0..3` babies during pod stage, and dead-stage fade/removal.

Fungi lifecycle (plants mode):
- Fungi now follows staged lifecycle parity with crops: `spore -> rhizo-grow -> mushroom harvest-ready -> brown/dead -> spore reset`.
- Stage promotion uses the same cadence as crops: `3` full consume cycles plus a `1`-tick wait between promotions.
- Pod/harvest-ready fungi can spawn random babies `0..3` on pod interval ticks; no births outside pod stage.
- Harvest behavior is stage-gated: dragging mature fungi into inventory adds `+3` to `myco` inventory and reverts that fungi to spore stage.
- Dragging immature fungi into inventory does not harvest; it snaps back to map placement.
- If mature mushroom is not harvested, it browns/withers and then reverts to spore stage (rhizomorphic layer persists).
- Sustained nutrient starvation also rolls fungi back down to spore stage.
- Rhizomorphic radius growth/shrink is visual reach only; fungi occupancy remains single-tile.

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
