---
description: Sinh checklist thực thi test có thứ tự ưu tiên trước release — nhóm TCs theo risk, ước lượng thời gian, đánh dấu regression candidates.
skills:
  - rbt_manual_testing
---

> **BẮT BUỘC (MANDATORY SKILL):** Bạn PHẢI nạp và đọc kỹ nội dung của skill **`rbt_manual_testing`** (tại `.claude/skills/rbt_manual_testing/SKILL.md`) để hiểu cách đánh giá risk level.

# Workflow: Sinh Test Execution Checklist Trước Release

Workflow này giúp QC biết **chạy TC nào trước, bao lâu xong, và cái nào không thể bỏ qua** — thay vì chạy theo thứ tự trong bảng TC.

## Khi nào dùng

- Chuẩn bị cho sprint release / hotfix / UAT
- Cần phân bổ thời gian test hợp lý trong deadline ngắn
- Muốn xác định những TCs bắt buộc phải pass trước khi ship
- **Không dùng** khi chưa có bộ TC → dùng `/generate_manual_testcases_rbt` trước

## Input cần từ User

| Input | Bắt buộc | Mô tả |
|-------|----------|-------|
| **Bộ TC hiện tại** | ✅ | File `.md`, bảng paste vào |
| **Loại release** | ✅ | Hotfix / Sprint Release / Major Release / UAT |
| **Thời gian có sẵn** | ⚠️ Nên có | VD: "2 ngày", "4 tiếng" — để tính toán coverage khả thi |
| **Tính năng thay đổi trong release này** | ⚠️ Nên có | Để ưu tiên test đúng vùng bị ảnh hưởng |
| **Số lượng QC thực hiện** | ❌ Optional | Để phân chia nếu có nhiều người |

## Các bước thực hiện

### Bước 1: Phân tích TCs và ngữ cảnh release

1. Đọc toàn bộ bộ TC
2. Xác định loại release → áp dụng chiến lược phù hợp:

   | Loại release | Chiến lược |
   |-------------|-----------|
   | **Hotfix** | Chỉ test TCs liên quan trực tiếp đến fix + smoke test core flows |
   | **Sprint Release** | Full test TCs của tính năng mới + regression các module phụ thuộc |
   | **Major Release** | Full regression toàn bộ bộ TC |
   | **UAT** | Tập trung Happy Path + business-critical scenarios |

3. Xác nhận context với user trước khi tiếp tục

### Bước 2: Phân loại TCs theo 3 nhóm

| Nhóm | Ký hiệu | Tiêu chí |
|------|---------|---------|
| **Must-run** | 🔴 | Critical/High priority, core flows, tính năng thay đổi trong release |
| **Should-run** | 🟡 | Medium priority, regression các module liên quan |
| **Nice-to-run** | 🟢 | Low priority, edge cases ít gặp, UI cosmetic |

### Bước 3: Ước lượng thời gian

Ước lượng thời gian thực thi mỗi TC (không tính setup):

| Độ phức tạp | Thời gian ước lượng |
|------------|-------------------|
| TC đơn giản (≤3 steps) | 2-3 phút |
| TC trung bình (4-7 steps) | 5-10 phút |
| TC phức tạp (>7 steps, nhiều data) | 10-20 phút |

Tổng hợp thời gian theo nhóm và so sánh với thời gian user có sẵn.

### Bước 4: Xuất Execution Checklist

```markdown
## Test Execution Checklist — [Tên Release] — [Ngày]

### Tổng quan
- Tổng TCs: [N] | Must-run: [X] | Should-run: [Y] | Nice-to-run: [Z]
- Thời gian ước tính: Must-run [Xh] | Full [Yh]
- Thời gian có sẵn: [Z tiếng/ngày]

### 🔴 Must-Run (không được bỏ qua)
| STT | TC ID | Module | Test Title | Priority | Thời gian | Kết quả |
|-----|-------|--------|-----------|----------|-----------|---------|
| 1   | TC_001 | Login | Đăng nhập thành công | Critical | 5 phút | ⬜ |
| ... |

### 🟡 Should-Run (nếu còn thời gian)
| STT | TC ID | Module | Test Title | Priority | Thời gian | Kết quả |
|-----|-------|--------|-----------|----------|-----------|---------|

### 🟢 Nice-to-Run (nếu dư thời gian)
| STT | TC ID | Module | Test Title | Priority | Thời gian | Kết quả |
|-----|-------|--------|-----------|----------|-----------|---------|

### Ghi chú
- Nếu thiếu thời gian: bỏ qua nhóm 🟢, cắt bớt nhóm 🟡
- Release blocker: tất cả TCs nhóm 🔴 phải PASS
```

## Quy tắc quan trọng

- ❌ KHÔNG bỏ TC nhóm 🔴 dù thiếu thời gian — đây là release blocker
- ✅ Nếu thời gian ước tính Must-run > thời gian có sẵn → cảnh báo user ngay
- ✅ TCs có data phức tạp hoặc cần setup môi trường → note rõ để QC chuẩn bị trước
