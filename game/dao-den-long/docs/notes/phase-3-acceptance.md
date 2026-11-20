# Phase 3 — Ticket-03 acceptance

| Requirement | Implementation / automated check | State |
|---|---|---|
| Integer 1/60 fuel, decay, refuel, relight and lantern-out event | `scripts/game_sim.gd`; contract checks cover decay and relight | Implemented; event edge cases need more tests |
| Low-fuel shades drain lamps and safe zones return at fuel 30 | Simulation; regression checks cover draining on Night 1 and Night 2 | Implemented; threshold/ejection tests remain |
| Dawn win at 60%, no early win; no-flames takes precedence | Simulation; dawn and no-early-win checks | Implemented; add explicit simultaneous no-flames/dawn test |
| Capacity grows by two per successful light, max 20 | Simulation and HUD | Implemented; needs dedicated boundary checks |
| Phase 3 score formula | Regression checks verify first-light, relight, and Night 1 dawn score | Implemented; add fuel-drain bonus and multi-night total checks |
| Colorblind palette, warning symbol, non-color lamp differences | Settings and alternate shade color; unlit flame flattened; low fuel blinks and has a bar | Partly implemented: torn-paper edge and full GUI accessibility review remain |
| ADR and breaking-change changelog | `docs/notes/phase-3-adr.md`, `CHANGELOG.md` | Present; ADR must reflect any remaining deviations |

Focused Phase 3 regression evidence: `docs/proof/phase-3/phase3-checks.json` (10 checks, 0 failures). Regenerate it from the project directory with `godot --headless --path . --script res://tests/phase3_checks.gd`.

The previous early-win rule is intentionally removed. A pre-lit lantern created by a scenario does not add score or successful-light capacity. Do not claim Phase 3 complete until the open visual checks and regression cases are recorded.
