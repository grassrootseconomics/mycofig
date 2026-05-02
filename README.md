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
- `Tab`: cycle active agent.
- `A`: toggle baby/spawn behavior.
- `B`: toggle resource bars.
- `+` / `-`: change movement speed.
- `Esc` or `Q`: end run / go to game-over screen.
- `2/3/4/5` (social mode): set connector count tuning.

## Project Structure
- `global/global.gd`: global state, rank thresholds, spawn scaling, platform tuning.
- `scenes/level.gd`: plants gameplay scene controller.
- `scenes/sociallevel.gd`: social gameplay scene controller.
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
