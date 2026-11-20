# Đảo Đèn Lồng

Game 3D góc nhìn thứ ba: Mây thu thập đom đóm, thắp đèn và giữ đảo sáng đến bình minh. Dự án dùng Godot 4.7.2 Standard, GDScript và hình khối dựng sẵn trong engine.

## Chạy game

Cài Godot 4.7.2 Standard, mở thư mục `game/dao-den-long` trong Project Manager rồi nhấn **F6/F5**. Có thể chạy từ terminal ở thư mục project:

```sh
godot --path .
```

### macOS và Linux

1. Cài **Godot 4.7.2 Standard** (không cần bản .NET). Tải bản phù hợp với hệ điều hành từ [Godot 4.7.2 archive](https://godotengine.org/download/archive/4.7.2-stable/).
2. Chuyển thư mục `game/dao-den-long` sang máy đó. Trong Godot Project Manager, bấm **Import**, chọn `project.godot` trong thư mục này, rồi **Import & Edit**.
3. Nhấn **F5** trong editor để chạy project. Hoặc mở Terminal tại thư mục `game/dao-den-long` và chạy:

```sh
godot --path .
```

Nếu executable chưa có trong `PATH`, dùng đường dẫn đầy đủ đến Godot thay cho `godot`. Ví dụ Linux:

```sh
chmod +x ~/Downloads/Godot_v4.7.2-stable_linux.x86_64
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --path /path/to/game/dao-den-long
```

Trên macOS, mở ứng dụng Godot, import cùng file `project.godot`, rồi nhấn **F5**; hoặc gọi binary bên trong ứng dụng với `--path /path/to/game/dao-den-long`.

Để chạy các lệnh headless trên macOS/Linux, thêm executable Godot vào `PATH` hoặc dùng đường dẫn đầy đủ:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://scripts/headless.gd -- --seed 42 --night 1 --ticks 600 --out out.jsonl
```

## Điều khiển mặc định

- WASD: di chuyển; chuột: xoay camera.
- Space: nhảy; Shift: lướt; E: nạp/thắp đèn; Q: Tỏa Sáng.
- P hoặc Esc: tạm dừng. Có thể đổi phím trong **Cài đặt**; phím trùng bị từ chối.
- Chọn **Bắt đầu** từ menu chính. Nhặt đom đóm khi đi gần, mang về đèn để thắp/châm dầu.

## Luật và giả định

- Mỗi đèn mới cần 10 đom đóm; đèn đã từng sáng cần 5 để thắp lại. Đèn sáng hao 1 fuel/giây, tối đa 100; Bóng Mực hút thêm fuel khi áp sát đèn yếu.
- Đêm 1/2/3 kéo dài 240/270/300 giây. Thắng khi sống tới bình minh và giữ lần lượt ít nhất 3/5, 4/6, 5/7 đèn sáng. Hết Ngọn Lửa là thua.
- Điểm Phase 3: +5 mỗi đom đóm nạp, +100 thắp lần đầu, +40 thắp lại, +5 mỗi Bóng Mực bị Tỏa Sáng trúng (+15 nếu đang hút dầu); khi thắng nhận điểm theo nhiên liệu đèn và Ngọn Lửa còn lại.
- Vị trí, tick, tốc độ và khoảng cách trong chế độ headless theo mét, trục Y hướng lên, 60 tick/giây. Tham số chuẩn nằm trong `game.contract.json`.
- PRD-0 còn để mở chi tiết mỹ thuật, điều khiển máy ảnh và nội dung lời thoại; lựa chọn cụ thể sẽ được ghi trong `docs/notes/`.

## Kiểm thử và chế độ headless

Kiểm tra simulation:

```sh
godot --headless --path . --script res://tests/contract_checks.gd
godot --headless --path . --script res://tests/phase3_checks.gd
```

Headless contract nhận `--seed`, `--night`, `--ticks`, `--out`, tùy chọn `--scenario`, `--inputs` và `--snapshot-every`. Kết quả JSONL gồm snapshot, event và dòng `end` cuối. Ví dụ kịch bản/đầu vào nằm trong `tests/`.

Benchmark và soak:

```sh
godot --path . -- --bench --seed 42 --duration 30 --out bench.json
godot --headless --path . --script res://scripts/soak.gd -- --seed 7 --nights 10 --out soak.json
```

## Sáng tạo của tôi

- Không thêm asset bên ngoài; nhân vật, đảo, đèn, đom đóm và Bóng Mực hiện được dựng từ primitive mesh và màu trong Godot.
- Bằng chứng hồi quy và giới hạn đã biết được ghi trong `docs/proof/`.

![Ảnh gameplay được chụp trực tiếp từ Godot 4.7.2](docs/demo/gameplay.png)

## Tài liệu

- `AGENTS.md`: hướng dẫn harness cho agent.
- `docs/notes/`: quyết định, giả định, nhật ký AI, acceptance theo phase và [retro](docs/notes/retro.md).
- `docs/proof/`: kết quả chạy test/headless/benchmark/soak.
- `docs/notes/phase-1-acceptance.md` đến `phase-4-acceptance.md`: acceptance, evidence và các mục còn mở theo phase.
- `CREDITS.md`, `CHANGELOG.md`, `LICENSE`: nguồn asset, thay đổi và giấy phép.
