# Phase 4 evidence index

- `contract-checks.json`: 25 automated simulation checks from Godot 4.7.2, 0 failures.
- `headless-smoke.jsonl`: 120-tick deterministic CLI smoke output.
- `../phase-2/full-night.jsonl`: full Night 1, 14,400 ticks, completed in 0.619 s on this machine.
- `soak.json`: 10-night single-process soak, 0 crashes; RSS 86.62 MB at start and 86.77 MB at end.
- `bench.json`: 30-second GUI benchmark after 3-second warmup; 298.35 average FPS, 121.57 P1 low FPS, 5.457 ms p95 frame time, 161 ms load, 203.08 MB peak RSS, vsync disabled. Local Windows / GTX 1650 Ti measurement.
- `leaderboard-export.json`: command-line export schema verification, empty leaderboard; persistent user scores and top-10 ordering are not verified.
- `../../demo/gameplay.png`: screenshot captured from a running game window.
- `../../demo/demo.mp4`: user-provided demo video; verify duration and required contents before release upload.
