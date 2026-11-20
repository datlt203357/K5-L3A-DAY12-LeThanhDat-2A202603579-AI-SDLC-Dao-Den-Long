# Phase 4 — Ticket-04 acceptance and release checklist

## Verified locally in this workspace

- Contract regression suite: 25 checks, 0 failures; result at `docs/proof/phase-4/contract-checks.json`.
- Full Night 1 headless simulation: 14,400 ticks completed in 0.619 s in this workspace, with output at `docs/proof/phase-2/full-night.jsonl`.
- Headless smoke: seed 42, Night 1, 120 ticks; JSONL at `docs/proof/phase-4/headless-smoke.jsonl`.
- Soak: one process, 10 seeded nights, 0 crashes; RSS start 86.62 MB, end 86.77 MB (below the 1.2× limit); result at `docs/proof/phase-4/soak.json`.
- GUI benchmark: avg 298.35 FPS, P1 low 121.57 FPS, frame-time p95 5.457 ms, 8,951 measured frames, load 161 ms, peak RSS 203.08 MB, vsync disabled; result at `docs/proof/phase-4/bench.json`. Measured on the local Windows / NVIDIA GeForce GTX 1650 Ti setup; instructor hardware may differ.
- README now embeds a gameplay frame captured from the running Godot window at `docs/demo/gameplay.png`.
- `--export-leaderboard` was run headless and produced a valid `{"entries": []}` schema at `docs/proof/phase-4/leaderboard-export.json`; it does not prove saved-score persistence or top-10 ordering.
- All five principal GDScript files pass Godot's `--check-only`, and the project starts headless. Godot logs a Windows root-certificate-store warning in this environment; it did not stop these runs.

## Open before claiming release-ready

- Re-measure the visible benchmark on the instructor's target hardware if it differs from this local Windows / GTX 1650 Ti machine.
- Play all three nights in the GUI and inspect gameplay, map geometry, HUD, pause/settings, rebind conflict feedback, colorblind mode, reduced motion and large text.
- Exercise local leaderboard persistence, top-10 tie ordering, name validation, and `--export-leaderboard` on a writable user-data directory.
- `docs/demo/demo.mp4` has been added; verify it is under five minutes and visibly includes gameplay, passing checks, and benchmark evidence before release upload.
- Build from a clean clone using no more than three README commands; install/use export templates and produce a runnable Windows/macOS/Linux or web artifact.
- AI-assisted evaluation and known errors are recorded in `docs/notes/retro.md` and `docs/notes/ai-log.md`; actual token usage is unavailable in the task history, so the total remains unknown.
- Create the phase tags from real, reviewable phase commits, then create GitHub Release `v1.0.0` with the runnable build and demo. No phase tags or release have been created.
