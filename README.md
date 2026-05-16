# Plants Gardening

Godot 4 game prototype focused on a soil-restoration story loop:
- Farm ecosystem growth using crops + myco networks.
- Story-driven village phase where people/baskets trade and farmer crop stock sustains the market.

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
godot4 --path . --scene res://scenes/world_foundation_test.tscn
```

Headless smoke test:

```bash
godot4 --path . --headless --quit-after 1200 --log-file /tmp/mycofig.log
```

Headless benchmark runner (deterministic seed + scenario):

```bash
godot4 --path . --headless --scene res://scenes/benchmark_runner.tscn -- --scenario=s2 --seed=1337 --duration=120 --target=700
```

Add `--bars` to profile worst-case resource bars, or `--no-lines` to isolate simulation without myco-line visuals.

## Android (APK-First)
- Android presets are defined in `export_presets.cfg`:
  - `Android-TestAPK` (phone install testing)
  - `Android-PlayAAB` (Google Play upload)
- Stable Android package/application ID:
  - `org.grassecon.socialsoil`
- Version contract:
  - `versionName`: `1.2.4` (from `project.godot` + preset override)
  - `versionCode`: `16` (must be incremented before each Play upload)

Local test export:

```bash
mkdir -p build/android
godot4 --headless --path . --export-debug "Android-TestAPK" build/android/social-soil-gardening-test.apk
```

Install on a connected phone:

```bash
adb install -r build/android/social-soil-gardening-test.apk
```

Play upload export (signed AAB via release keystore):

```bash
godot4 --headless --path . --export-release "Android-PlayAAB" build/android/social-soil-gardening-play.aab
```

CI workflow:
- `.github/workflows/android-build.yml` builds reproducible Android artifacts from `v*` tags.
- Artifact names include app version + git SHA.
- Signed AAB export in CI requires these repository secrets:
  - `ANDROID_RELEASE_KEYSTORE_BASE64`
  - `GODOT_ANDROID_KEYSTORE_RELEASE_USER`
  - `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`

## Game Modes
Choose mode from title screen:
- `Story`
- `Challenge`

`Story` uses one continuous map flow (farm to village) with fog-of-war.  
`Challenge` includes the plant survival loop plus a revealed village economy without story fog gating. In the village economy, `R` is money: farmers sell harvested `N`, vendors sell produced `P`, cooks sell produced `K`, and the bank targets a fixed `6` each of `N/P/K` as bridge stock.

## Controls
- `Left Click`: drag entities and place inventory items.
- `Mouse Hover Cell`: hovering any occupied tile cell shows outline + resource bars for that tile's plant/fungi/person/basket (when global bars are off).
- `Left Click + Drag` (empty world) or `Right Click + Drag`: pan camera across the larger tiled map.
- `WASD`: pan camera.
- `Two-finger trackpad drag`: pan camera.
- `Arrow Keys`: move the selected active agent.
- `Shift + Arrow Keys`: also pan camera.
- `Tab`: cycle active agent.
- `M`: toggle baby/spawn behavior.
- `G`: toggle repositioning of already-placed plants/fungi (default `OFF`).
- `B`: toggle resource bars (bars start OFF by default).
- `F`: challenge-mode farmer `N` autofill test toggle.
- `+` / `-`: change movement speed.
- `Esc` or `Q`: end run / go to game-over screen.
- `Android Back`: first press pauses, next press opens exit-to-menu confirmation.
- Inventory panel visibility: no hotkey yet (always shown).
- `N`: toggle runtime performance overlay.
- `V`: toggle Story fog-of-war on/off (debug runtime toggle).
- Minimap (HUD): click or drag to move camera.

Story-specific controls/behavior:
- Farm and Village inventory tabs (Village unlocks on story reveal).
- In village phase, ripe crop harvest can only be dropped on `Farmer` (not inventory/other villagers/baskets).
- Story farmers do not passively regenerate resources.
- Any successful drop onto a farmer refills the farmer's `N` resource bar to full (`needs["N"] * 2`).
- Story village trading uses native social-agent resources/bars only (no separate hidden farmer stock meter).
- Story tuktuk predators are temporarily disabled by default via `Global.enable_tuktuk_predators = false` (story-only; birds still spawn).

Keybinding implementation:
- All shared gameplay hotkeys are centralized in `scenes/level_helpers.gd` via `handle_gameplay_hotkeys(...)`.
- `scenes/level.gd` and `scenes/sociallevel.gd` call that shared handler.

## Performance + Benchmarking
- Runtime instrumentation samples every `0.5s` and tracks:
  - frame avg/p95
  - active/moving agents
  - trade packet count
  - line count
  - visible resource bars
  - soil tiles touched per tick
  - soil tick time (ms)
  - tile occupancy query count
- Adaptive quality tiers:
  - `Tier 0`: full visuals
  - `Tier 1`: reduced bar/line update rates
  - `Tier 2`: reduced line quality (trade packets remain visible)
- Android-tuned adaptive policy:
  - Uses weighted pressure scores from `frame p95/avg`, `active agents`, `trade packets`, `line count`, `visible bars`, and `tile occupancy queries`.
  - Promotion/degradation uses hysteresis windows:
    - promote after `2` consecutive over-threshold samples
    - degrade after `5` consecutive below-threshold samples
  - Tuned from dense-map benchmark traces (`target=120/240/420/700`) so Tier 1 engages around sustained high density and Tier 2 engages only under severe pressure.
- Global perf toggles live in `global/global.gd`:
  - `perf_adaptive_enabled`
  - `perf_quality_override` (`-1` auto, `0..2` forced)
  - `perf_metrics_enabled` (enables benchmark sample file output)
- Benchmark logs are written to `user://perf_metrics.json` and `user://perf_metrics.csv` when metrics logging is enabled.
- Benchmark scenario profiles:
  - `s2`: density ramp baseline.
  - `s3`: interaction stress (spawn/kill churn bursts).
  - `s4`: endurance soak (sustained high density + periodic churn).
  - Sample traces now include scenario metadata (`scenario_id`, `run_profile`, `seed`, `target`) for easier comparison.
- Soil optimization decision gate (M2.1 deferred):
  - Keep current full-map `1s` soil tick for `48x27`.
  - Enable dirty-tile soil updates when either:
    - map exceeds ~`2000` tiles, or
    - observed `soil_tick_ms` p95 exceeds ~`2.0ms`.

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
- `Z`: toggle soil debug overlay.
- `X`: reset static baseline map.
- `C`: toggle tile stage edit mode.
- `V`: toggle Story fog-of-war on/off.
- `Left Click` (with edit on): cycle tile stage `0 -> 1 -> 2 -> 3 -> 0`.

## Project Structure
- `global/global.gd`: global state, rank thresholds, spawn scaling, platform tuning.
- `scenes/level.gd`: primary Story/Challenge gameplay controller.
- `scenes/world_foundation.gd`: shared tiled world, soil tile model, stage rendering, camera clamp/pan, story fog-of-war.
- `scenes/perf_monitor.gd`: runtime perf sampler + adaptive quality controller + optional metric logging.
- `scenes/benchmark_runner.gd`: deterministic headless benchmark harness.
- `scenes/world_foundation_test.tscn`: static validation map for M1 grid foundation.
- `scenes/agent.gd`, `scenes/socialagent.gd`, `scenes/basket.gd`: core actor logic.
- `scenes/bird.gd`, `scenes/tuktuk.gd`: predator/raider logic.
- `scenes/ui.gd`, `scenes/minimap_panel.gd`: HUD, inventory tabs, minimap navigation, drag preview.
- `scenes/level_helpers.gd`: shared scene helpers (signal wiring, myco line invalidation, audio stop).

## Runtime Ownership Map
- Canonical runtime paths:
  - entity behavior: `scenes/agent.gd`, `scenes/myco.gd`, `scenes/socialagent.gd`, `scenes/basket.gd`
  - world/tile/soil/camera: `scenes/world_foundation.gd`
  - scene orchestration: `scenes/level.gd`
  - shared placement/lines/occupancy helpers: `scenes/level_helpers.gd`
  - packet transport: `scenes/trade.gd`
- Legacy assets/scripts such as `scenes/bean.gd`, `scenes/squash.gd`, `scenes/maize.gd`, `scenes/city.gd`, `scenes/meteor.gd` are retained for rollback safety but are not the primary runtime path.

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
