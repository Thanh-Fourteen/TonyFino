# Nguồn gốc & giấy phép

Mọi file PNG trong thư mục này — 3 file gốc ở thư mục này (`party_popper_3d.png`, `trophy_3d.png`,
`fire_3d.png`) và 14 file icon danh mục trong `categories/` — đều lấy từ bộ
[Microsoft Fluent Emoji](https://github.com/microsoft/fluentui-emoji), style 3D, không chỉnh sửa.

**Giấy phép: MIT** (Copyright (c) Microsoft Corporation) — xem
https://github.com/microsoft/fluentui-emoji/blob/main/LICENSE. Giữ file này lại cùng thư mục để
đáp ứng điều khoản MIT (giữ nguyên thông báo bản quyền), không cần ghi công hiển thị trong UI.

## Phạm vi sử dụng

**3 file ở thư mục gốc** (`party_popper_3d.png`, `trophy_3d.png`, `fire_3d.png`): khoảnh khắc ăn
mừng đạt mục tiêu tiết kiệm (🎉🏆) và điểm nhấn streak nhập liệu (🔥) — xem `docs/decisions.md`
§ Phase 22.

**`categories/`** (tên file = `iconCode`, khớp `lib/theme/tokens/icons.dart`): icon danh mục, hiện
ở MỌI nơi có `CategoryAvatar` — danh sách giao dịch, biểu đồ, form.

> ⚠️ Đoạn trên **đảo ngược** giới hạn cũ của file này ("KHÔNG dùng trong danh sách giao
> dịch/form/biểu đồ", đặt ra ở Phase 22). Lý do đảo: bản ghi màn hình Rolly (`rolly.mp4`, Tony
> quay từ chính app anh đang dùng) cho thấy Rolly **hoàn toàn phẳng** — nền trắng, viền 1px, gần
> như không đổ bóng — và toàn bộ cảm giác "3D/sang" của nó đến từ **bộ icon danh mục 3D** trên mọi
> dòng, chứ không từ shadow/glass/chrome. Nói cách khác đây KHÔNG phải nới lỏng luật "màn dày data
> giữ phẳng" của Phase 22: bề mặt vẫn phẳng y nguyên, chỉ phần ruột icon đổi. Tony duyệt trực tiếp
> ngày 2026-08-22 sau khi được trình bày đúng căng thẳng này. Xem `docs/decisions.md`.
