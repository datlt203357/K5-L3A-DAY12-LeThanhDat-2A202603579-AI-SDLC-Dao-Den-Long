# Retro — AI SDLC Lab: Đảo Đèn Lồng

Ngày tổng hợp: 2026-11-20. Đây là đánh giá trên mã và bằng chứng hiện có trong repo; không đại diện cho một playthrough GUI đủ ba Đêm hay các hidden test của Coach.

## Evaluation theo phase

- **Phase 1 — một đêm và contract:** CP0 đã được người dùng xác nhận chạy scene Godot và `HEADLESS_OK`; hiện có game 3D, fixed-tick simulation và JSONL headless runner. CP0 chưa có ảnh chụp lịch sử được lưu. Chưa có tag `phase-1`.
- **Phase 2 — ba đêm và tính năng mới:** simulation có ba bản đồ, dash, charms, drifters, wind, pause và snapshot mở rộng. Regression kiểm tra scenario dash/charm/drifter/wind. Một số yêu cầu HUD, âm thanh, jump-pad/map geometry và edge case còn thiếu hoặc chưa được kiểm tra qua GUI.
- **Phase 3 — dầu và bình minh:** fuel integer theo tick, drain, relight/refuel, capacity và luật thắng bình minh được đưa vào simulation. ADR và changelog ghi thay đổi phá vỡ tương thích. Regression khóa các lỗi điểm thưởng cũ, drain Đêm 1 và ưu tiên thua khi hết Ngọn Lửa. Colorblind support mới một phần.
- **Phase 4 — phát hành:** đã chạy 25 contract checks, headless full-night, soak 10 Đêm và benchmark GUI; có JSON evidence cùng ảnh gameplay. Benchmark đạt ngưỡng trên máy Windows/GTX 1650 Ti tại workspace. Video demo, kiểm tra đủ ba Đêm, gói xuất bản, phase tags và GitHub Release còn thiếu.

## Làm với AI

Việc hiệu quả là tách `GameSim` khỏi scene 3D để có thể chạy headless, so sánh output, và lưu bằng chứng sinh bởi chính chương trình. `AGENTS.md` nhắc giữ luật ở simulation, không sửa tay output và chạy kiểm tra sau thay đổi. Suite regression giúp bắt lỗi cụ thể thay vì chỉ dựa vào câu trả lời “đã xong” của AI.

Các lỗi AI đã phát hiện trong phiên hoàn thiện:

1. Điểm thắng Đêm 1 còn dùng thưởng thời gian cũ sau Ticket-03.
2. Shade chỉ tìm đèn yếu từ Đêm 2, trong khi Ticket-03 áp dụng cả Đêm 1.
3. Charm trong scenario bị cộng thêm vào charm mặc định thay vì thay thế danh sách.
4. Một thay đổi spawn gây lỗi thụt lề GDScript; `--check-only` bắt được trước khi cập nhật evidence.

Các lỗi này được phát hiện bằng cách so mã với Phase 2/3, chạy scenario CLI thật và thêm regression assertions. Một số lệnh ban đầu dùng path sai do nhầm thư mục hiện hành với `res://`; chạy lại từ đúng project path cho kết quả hợp lệ.

## Harness, token và chi phí

Harness hiện có `AGENTS.md`, contract JSON, headless runner, scenario/input JSON và `tests/contract_checks.gd`. Đây là các phần hỗ trợ nhất vì biến luật thành tình huống có thể chạy lại. Repo chưa có skill/hook riêng.

Tổng token/chi phí AI **không xác định**: lịch sử/tooling hiện có không cung cấp usage theo task để tính lại. Không ước lượng thành con số. Cách hạn chế phạm vi là dùng primitive có sẵn, không tải asset ngoài, giữ tests tập trung ở simulation và tạo evidence tự động.

## Nếu làm lại

1. Tạo test matrix cho từng scenario trước khi viết gameplay; kiểm tra mảng scenario có ngữ nghĩa “replace” ngay từ đầu.
2. Lưu ảnh/log CP0 và tag/commit riêng theo từng phase ngay khi Coach phát hành phase tiếp theo.
3. Chạy từng phase trên GUI song song với headless để kiểm tra map, HUD, âm thanh và trợ năng, thay vì để dồn các phần đó đến cuối.
4. Đặt thời gian cho video, build sạch và Release trước khi hết lab; đây là các deliverable hiện vẫn chưa hoàn tất.
