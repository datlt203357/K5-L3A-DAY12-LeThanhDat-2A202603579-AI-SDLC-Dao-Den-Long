# Nhật ký sử dụng AI

Ghi lại theo từng phiên. Ước tính token/chi phí chỉ điền khi có số liệu từ công cụ; không tự ước đoán thành số thực tế.

| Ngày/giờ   | Công cụ/model | Việc giao cho AI | Kết quả và phần tôi đã kiểm tra | Token/chi phí |
|------------|---|---|---|---|
| 20/11/2026   | ChatGPT/Codex | Hướng dẫn CP0, tạo scene 3D tối giản và kiểm tra lệnh headless | Người dùng xác nhận đã chạy thành công scene và smoke test có `HEADLESS_OK`; cần lưu ảnh/log gốc để làm bằng chứng độc lập | Chưa có số liệu |
| 20/11/2026 | OpenAI Codex | Hoàn thiện mô phỏng 3 đêm, runner contract, soak, menu/settings/leaderboard, benchmark, bằng chứng và tài liệu | Đã chạy 25 checks (0 lỗi), headless full-night/smoke, soak 10 Đêm và benchmark GUI. Review phát hiện công thức điểm Đêm 1 cũ, thiếu drain Night 1, spawn bùa scenario không thay thế mặc định; đã sửa và thêm regression checks. | Công cụ không cung cấp số token/chi phí theo task; chưa có số liệu để điền |

## Lỗi AI hoặc điểm cần xem lại

- Lệnh headless ban đầu dùng đường dẫn resource sai (`res\\://...`); đã hướng dẫn dùng `res://smoke_test.gd`.
- Trong phiên này, bản code ban đầu còn dùng điểm thưởng thời gian cũ cho Đêm 1 và chỉ chuyển Bóng Mực sang đèn yếu từ Đêm 2. Phát hiện bằng cách so sánh trực tiếp implementation với Ticket-03 và thêm regression checks.
- Chạy `--check-only` một lần bắt được lỗi thụt lề trong script sau chỉnh sửa spawn; đã sửa và chạy lại suite thành công.
