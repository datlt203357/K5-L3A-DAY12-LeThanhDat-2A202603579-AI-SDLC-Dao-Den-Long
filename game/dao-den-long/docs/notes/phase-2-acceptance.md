# Phase 2 — Ticket-02 acceptance

| Requirement | Evidence / automated check | State |
|---|---|---|
| Three maps, lamp counts, 20/20/30 motes, and 300/330/360 s original durations | `scripts/game_sim.gd`; final v1.2/v1.3 durations checked in `contract_checks.gd` | Implemented; map geometry needs GUI review |
| 6 m/s movement, jump, 14 m/s dash, pickup/interact limits | Simulation code and `tests/scenarios/dash.json` + `tests/inputs/dash.json` | Dash scenario covered; jump-pad/acceleration boundary tests remain |
| Shade chase, pulse, safe radius, hits, recoil, spawning | Simulation, shade/dawn regression checks, ID-ordered collision test | Partly covered; spawn timing and all edge cases need tests |
| Wind, charms, drifters, pause and snapshots | `tests/scenarios/charm.json`, `drifter.json`, `wind.json`; pause/dash/charm/drifter/wind and pulse-drop checks in contract suite | Core paths covered; drifter respawn and full snapshot schema need more checks |
| Menu progression and restart of current night | Runtime menu in `scripts/main.gd` | Implemented in code; GUI playthrough pending |
| Audio cues and complete HUD indicators (cooldowns, interaction prompt, off-screen lamp marker) | No audio assets or AudioStreamPlayer cues; current HUD is text based | Incomplete; add before release |
| One full headless night completes within 30 s | Night 1 ran all 14,400 ticks in 0.619 s; JSONL is in `docs/proof/phase-2/full-night.jsonl` | Meets local runtime limit; this is not a substitute for hidden tests |

Run example scenarios from the project folder with `godot --headless --path . --script res://scripts/headless.gd -- --seed 7 --night 2 --scenario tests/scenarios/charm.json --ticks 60 --out charm.jsonl`. The current output contract is the final v1.3 version.
