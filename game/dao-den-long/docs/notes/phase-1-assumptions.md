# Phase 1 — Giả định và quyết định

> Cập nhật trong Phase 1 khi đọc PRD-0 và Test Contract. Không biến giá trị mẫu thành yêu cầu nếu contract chưa quy định.

## Giả định

| ID | Chỗ chưa rõ | Giả định đã chọn | Lý do | Cách kiểm chứng / trạng thái |
|---|---|---|---|---|
| A-01 | Tên người chơi / nhân vật | Dùng Mây và tên game Đảo Đèn Lồng như PRD-0 | Theo nội dung khách hàng | Đã thể hiện trong README/game; cần GUI review |
| A-02 | Góc camera, nội dung kể chuyện và asset | Dùng camera nhìn theo sau, dựng cảnh bằng primitive, chưa thêm thoại/asset ngoài | PRD-0 để mở mỹ thuật và camera | Có trong scene runtime; xem CREDITS.md |
| A-03 | Phím mặc định | WASD, chuột, Space, Shift, E, Q, P/Esc | Cách bố trí phổ biến; Phase 2 cho phép đổi phím | Đã được nêu trong README; cần kiểm tra GUI |
| A-04 | Điểm và thời gian khi Phase 1 còn mơ hồ | Lưu theo luật chuẩn hóa mới nhất của Ticket-03, không giữ early-win Phase 1 | Yêu cầu thay đổi có hiệu lực ở phase sau | Contract regression và ADR Phase 3 |

## Quyết định kỹ thuật

- Engine: Godot 4.7.2 Standard, GDScript.
- Hệ phát triển hiện tại: Windows.
- Bản hiện tại được làm và kiểm tra trên Windows; cần xác nhận cách chạy trên macOS/Linux hoặc xuất bản web trước khi phát hành.
- Các giá trị gameplay trong `game.contract.json` phải phản ánh đúng cấu hình thực tế của game.

## Cập nhật

| Ngày/giờ | Thay đổi | Lý do |
|---|---|---|
| 2026-11-20 | Ghi lại giả định sau khi đối chiếu Phase 1–4 và mã hiện tại | Để tách rõ yêu cầu mở với quyết định đã chọn |
