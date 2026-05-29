---
description: Xác định bộ TCs cần chạy lại khi có code change — map thay đổi vào modules bị ảnh hưởng, phân loại direct/indirect impact, output regression suite có thứ tự ưu tiên.
skills:
  - rbt_manual_testing
---

> **BẮT BUỘC (MANDATORY SKILL):** Bạn PHẢI nạp và đọc kỹ nội dung của skill **`rbt_manual_testing`** (tại `.claude/skills/rbt_manual_testing/SKILL.md`) để hiểu cách đánh giá risk level.

# Workflow: Sinh Regression Suite

Workflow này giúp QC **không phải chạy toàn bộ TC mỗi sprint** — chỉ chạy đúng những TC có khả năng bị ảnh hưởng bởi code change, theo thứ tự risk.

## Khi nào dùng

- Sau mỗi sprint có code changes cần xác định scope regression
- Hotfix cần verify không break tính năng khác
- Refactor code và cần chọn safety net TCs
- **Không dùng** khi cần full regression → dùng `/generate_test_execution_checklist`

## Input cần từ User

| Input | Bắt buộc | Mô tả |
|-------|----------|-------|
| **Bộ TC hiện tại** | ✅ | File `.md` hoặc bảng TC paste vào |
| **Danh sách thay đổi** | ✅ | Tính năng/module/fix được thay đổi trong release này |
| **Module map** | ⚠️ Nên có | Sơ đồ dependencies giữa các modules (nếu có) |

## Các bước thực hiện

### Bước 1: Phân tích scope thay đổi

1. Đọc danh sách thay đổi từ user
2. Phân loại từng thay đổi:

   | Loại thay đổi | Ví dụ | Mức ảnh hưởng |
   |--------------|-------|--------------|
   | **New feature** | Thêm tính năng export PDF | Trực tiếp + modules dùng chung data |
   | **Bug fix** | Fix lỗi validation email | Trực tiếp tính năng đó |
   | **Refactor** | Tách service layer | Tất cả modules dùng service đó |
   | **Config change** | Thay đổi timeout, limit | Tất cả flows có timeout/limit |
   | **Database change** | Thêm/sửa cột | Tất cả TCs liên quan đến entity đó |

3. Tóm tắt scope và hỏi user bổ sung nếu cần

### Bước 2: Map thay đổi → Modules bị ảnh hưởng

Xác định 2 mức ảnh hưởng:

- **Direct impact** — Module được thay đổi trực tiếp
- **Indirect impact** — Module phụ thuộc vào module thay đổi (shared components, API, data)

```markdown
| Thay đổi | Direct Impact | Indirect Impact |
|---------|--------------|----------------|
| Fix login validation | Module: Login | Module: Dashboard (dùng login state), Profile |
| Thêm field "Địa chỉ" | Module: User Create/Edit | Module: Report (có thể hiển thị địa chỉ) |
```

### Bước 3: Chọn TCs cho regression suite

Với mỗi module bị ảnh hưởng, chọn TCs theo tiêu chí:

| Ưu tiên | Loại TC cần chọn |
|---------|----------------|
| **1 — Bắt buộc** | TCs liên quan trực tiếp đến thay đổi |
| **2 — Bắt buộc** | Happy Path của module bị ảnh hưởng |
| **3 — Nên có** | TCs của module indirect impact (smoke test) |
| **4 — Optional** | Edge cases của module thay đổi |

### Bước 4: Xuất Regression Suite

```markdown
## Regression Suite — [Sprint/Release Name]

### Scope thay đổi
[Tóm tắt 2-3 dòng những gì thay đổi]

### Modules bị ảnh hưởng
- 🔴 Direct: [Module A, Module B]
- 🟡 Indirect: [Module C, Module D]

### Regression TCs ([N] TCs — est. [X] giờ)

| STT | TC ID | Module | Test Title | Impact | Priority | Kết quả |
|-----|-------|--------|-----------|--------|----------|---------|
| 1 | TC_001 | Login | Đăng nhập thành công | Direct | Critical | ⬜ |
| 2 | TC_015 | Dashboard | Load dashboard sau login | Indirect | High | ⬜ |
| ... |

### TCs không cần chạy lại
Các module sau không bị ảnh hưởng, bỏ qua để tiết kiệm thời gian:
- [Module X] — không có dependency với thay đổi
- [Module Y] — isolated, không dùng shared components
```

## Quy tắc quan trọng

- ❌ KHÔNG bỏ qua indirect impact — bug regression thường xuất hiện ở đây
- ❌ KHÔNG chọn TC chỉ dựa trên tên module — phải verify dependency thực tế
- ✅ Nếu không có module map → hỏi user về dependencies trước khi chọn TCs
- ✅ Regression suite nên chiếm 20-40% tổng bộ TC — nếu >60% thì nên dùng full regression
