---
description: Sinh structured exploratory testing charter — xác định mission, scope, time-box và ghi chép kết quả. Biến exploratory testing từ ad-hoc thành có hệ thống.
skills:
  - rbt_manual_testing
  - requirements_analyzer
---

> **BẮT BUỘC (MANDATORY SKILL):** Bạn PHẢI nạp và đọc kỹ nội dung của skill **`rbt_manual_testing`** (tại `.claude/skills/rbt_manual_testing/SKILL.md`) để hiểu cách đánh giá risk.

# Workflow: Sinh Exploratory Testing Charter

Workflow này chuyển exploratory testing từ **"tự do click lung tung"** thành **có mission rõ ràng, time-box, và ghi chép được** — đảm bảo coverage mà không cần viết TC từ trước.

## Khi nào dùng

- Tính năng mới chưa có TC, cần khám phá nhanh trước khi viết TC đầy đủ
- Sau khi chạy hết TC chính thức, muốn tìm thêm bug ngoài script
- Release gấp, không đủ thời gian viết TC chi tiết
- Khi muốn test theo góc nhìn user thực tế, không bị giới hạn bởi script
- **Không thay thế** systematic test cases cho module quan trọng

## Input cần từ User

| Input | Bắt buộc | Mô tả |
|-------|----------|-------|
| **Module/Tính năng cần explore** | ✅ | Tên module hoặc URL |
| **Requirements/Spec** | ⚠️ Nên có | Để agent hiểu expected behavior |
| **Thời gian có sẵn** | ⚠️ Nên có | VD: "45 phút", "2 tiếng" |
| **Mục tiêu cụ thể** | ❌ Optional | "Tập trung vào security", "Tìm bug edge cases" |

## Các bước thực hiện

### Bước 1: Xác định Charter Mission

1. Đọc requirements/thông tin module được cung cấp
2. Đề xuất **1-3 charters** (mỗi charter = 1 session explore có trọng tâm):

   | Charter | Mission | Time-box | Focus Area |
   |---------|---------|----------|-----------|
   | #1 | Explore luồng Happy Path từ góc độ user mới | 30 phút | Onboarding flow |
   | #2 | Tìm boundary và edge cases của form validation | 45 phút | Input validation |
   | #3 | Kiểm tra behavior khi mất kết nối / lỗi server | 30 phút | Error handling |

3. **Chờ user chọn** charter nào muốn thực hiện (hoặc xác nhận tất cả)

### Bước 2: Sinh Charter chi tiết

Với mỗi charter được chọn, sinh template đầy đủ:

```markdown
## Charter #[N]: [Mission Statement]

**Tester:** _______________
**Ngày/Giờ bắt đầu:** _______________
**Time-box:** [X phút]

### Mission
[Mô tả rõ mục tiêu của session explore này]

### Scope — Nên explore
- [Vùng 1 cần khám phá]
- [Vùng 2 cần khám phá]
- [Vùng 3 cần khám phá]

### Out of Scope — Không cần explore trong session này
- [Vùng 1 bỏ qua]
- [Vùng 2 bỏ qua]

### Heuristics gợi ý (góc nhìn test)
- **CRUD:** Tạo → Đọc → Sửa → Xóa, kiểm tra tất cả trạng thái
- **Boundaries:** Giá trị min, max, vượt giới hạn, rỗng
- **Interruptions:** Reload, back browser, logout giữa chừng
- **Concurrency:** Mở 2 tab cùng lúc, thao tác đồng thời
- **Permissions:** Thử với nhiều role khác nhau (nếu có)

### Ghi chép trong session
| Thời điểm | Hành động | Quan sát | Bug? |
|-----------|-----------|---------|------|
| | | | |

### Kết quả session
- **Bugs tìm được:** [N]
- **Areas covered:** [liệt kê]
- **Areas NOT covered:** [liệt kê — để biết cần explore thêm]
- **Ghi chú cho session tiếp theo:**
```

## Quy tắc quan trọng

- ❌ KHÔNG để exploratory session vượt time-box — mất focus
- ❌ KHÔNG skip phần ghi chép — đây là điểm khác biệt với ad-hoc testing
- ✅ Mỗi bug tìm được → dùng `/generate_bug_report` để report ngay
- ✅ Sau session → review "Areas NOT covered" để lên kế hoạch session tiếp
- ✅ 1 charter = 1 tester = 1 session — không gộp nhiều mission vào 1 charter
