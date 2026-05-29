---
description: Cập nhật bộ test cases hiện có khi requirements thay đổi — phân tích delta, xác định TCs cần sửa/thêm/xóa, output bộ TC đã được cập nhật kèm change log.
skills:
  - rbt_manual_testing
---

> **BẮT BUỘC (MANDATORY SKILL):** Bạn PHẢI nạp và đọc kỹ nội dung của skill **`rbt_manual_testing`** (tại `.claude/skills/rbt_manual_testing/SKILL.md`) trước khi bắt đầu.

# Workflow: Cập Nhật Test Cases Khi Requirements Thay Đổi

Workflow này phân tích **delta giữa requirements cũ và mới**, xác định chính xác những TCs nào cần cập nhật — tránh viết lại toàn bộ từ đầu.

## Khi nào dùng

- Requirements vừa được cập nhật (user thay đổi spec, user clarify thêm)
- Q&A với user trả lời xong và cần reflect vào TC đã có
- Tính năng được mở rộng hoặc thu hẹp scope
- **KHÔNG dùng** khi chưa có TC nào → dùng `/generate_manual_testcases_rbt`
- **KHÔNG dùng** khi >50% TC bị ảnh hưởng → nên chạy lại `/generate_manual_testcases_rbt`

## Input cần từ User

| Input | Bắt buộc | Mô tả |
|-------|----------|-------|
| **TC hiện tại** | ✅ | File `.md`, bảng paste vào, hoặc mô tả "TC đang có gồm..." |
| **Requirements thay đổi** | ✅ | Mô tả cụ thể thay đổi, hoặc file spec mới |
| **Requirements cũ** | ⚠️ Nên có | Để so sánh delta chính xác hơn |

## Các bước thực hiện

### Bước 1: Đọc hiểu TC hiện tại

1. Đọc toàn bộ bộ TC hiện tại
2. Tóm tắt: số TC, danh sách modules
3. Xác nhận với user trước khi tiếp tục
4. **Chờ user xác nhận**

### Bước 2: Phân tích Delta Requirements

1. Đọc requirements mới / thay đổi
2. Phân loại từng thay đổi:

   | Loại | Mô tả |
   |------|-------|
   | **Thêm mới** | Rule/field/flow mới chưa có trong TC |
   | **Sửa đổi** | Rule/field/flow cũ thay đổi logic hoặc constraint |
   | **Xóa bỏ** | Rule/field/flow không còn áp dụng |
   | **Làm rõ** | Ambiguity được giải đáp → TC cũ có thể sai assumption |

3. Liệt kê bảng delta + TCs bị ảnh hưởng:

   ```
   | # | Loại     | Mô tả thay đổi                      | TCs bị ảnh hưởng      |
   |---|----------|-------------------------------------|-----------------------|
   | 1 | Sửa đổi  | Giới hạn tên từ 50 → 100 ký tự      | TC_003, TC_004, TC_005 |
   | 2 | Thêm mới | Thêm validation email unique         | Cần TC mới            |
   | 3 | Xóa bỏ   | Bỏ field "Mã nội bộ"                | TC_012 cần xóa        |
   ```

4. **Chờ user xác nhận** delta trước khi sang Bước 3

### Bước 3: Phân loại hành động cho từng TC

Gán trạng thái cho mỗi TC:

| Trạng thái | Ký hiệu | Ý nghĩa |
|-----------|---------|---------|
| Giữ nguyên | ✅ KEEP | Không bị ảnh hưởng |
| Cần cập nhật | ✏️ UPDATE | Sửa steps / expected result / test data |
| Cần xóa | 🗑️ REMOVE | Không còn valid |
| TC mới | ➕ NEW | Tạo mới cho requirement mới |

### Bước 4: Thực hiện cập nhật

1. **UPDATE** — Chỉnh sửa TC bị ảnh hưởng
2. **NEW** — Sinh TC mới theo skill `rbt_manual_testing` (áp dụng Field-Level Validation nếu có field mới)
3. **REMOVE** — Đánh dấu xóa, liệt kê trong Change Log
4. **KEEP** — Copy sang output không thay đổi

### Bước 5: Xuất output

Bảng TC đầy đủ kèm Change Log:

```
## Change Log
- ✏️ Updated [N] TCs: TC_003, TC_004 — Cập nhật max length 50 → 100
- ➕ Added [M] TCs: TC_031, TC_032 — Email unique validation
- 🗑️ Removed [K] TCs: TC_012 — Field "Mã nội bộ" đã xóa khỏi spec
- ✅ Kept [X] TCs không thay đổi
```

## Quy tắc quan trọng

- ❌ KHÔNG xóa TC mà không liệt kê trong Change Log
- ❌ KHÔNG tự đoán requirements thay đổi — chỉ phân tích những gì user cung cấp
- ✅ Test data phải cụ thể theo rule mới, không giữ nguyên data cũ nếu constraint đã thay đổi
- ✅ Nếu thay đổi lớn (>50% TC bị ảnh hưởng) → đề xuất chạy lại `/generate_manual_testcases_rbt`
