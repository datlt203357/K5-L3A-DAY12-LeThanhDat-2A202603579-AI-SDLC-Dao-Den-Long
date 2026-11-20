# Bằng chứng CP0 — Chuẩn bị môi trường

## Môi trường

- OS phát triển: Windows.
- Engine: Godot 4.7.2 Standard.
- Project: `game/dao-den-long`.

## Kiểm tra headless

- Lệnh chạy:

```powershell
& "D:\Workspace\AI20K\Lab_Day_12\Tools\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path "D:\Workspace\AI20K\Lab_Day_12\game\dao-den-long" --script "res://smoke_test.gd"
```

- Kết quả được người dùng xác nhận: Godot khởi chạy và in `HEADLESS_OK`, không báo lỗi tải script.
- Trạng thái bằng chứng: hiện là ghi nhận theo xác nhận của người dùng trong phiên; cần lưu ảnh chụp terminal hoặc output nguyên bản trước khi coi đây là bằng chứng lưu trữ có thể đối chiếu.

## Kiểm tra giao diện 3D

- Kết quả: người dùng xác nhận đã hoàn tất thành công mục 2 và 3 (project Godot và scene 3D chạy được).
- Bằng chứng cần bổ sung: ảnh cửa sổ game đang chạy, có sàn và vật thể, lưu cùng thư mục này.
- Ảnh gameplay ở `docs/demo/gameplay.png` là từ bản game hiện tại sau khi hoàn thiện; ảnh đó không chứng minh scene CP0 cũ có sàn và vật thể như yêu cầu ban đầu.

## Phạm vi

Đây là kiểm tra CP0, chưa phải kiểm thử Test Contract Phase 1. Chưa xác minh `game.contract.json`, tham số `--seed/--night/--ticks/--out`, JSONL hay tính tất định.
