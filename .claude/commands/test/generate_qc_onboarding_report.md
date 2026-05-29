---
description: Tổng hợp hiện trạng dự án cho QC mới join giữa chừng — coverage map, open bugs, và danh sách tác vụ cụ thể cần làm ngay. Giảm ramp-up time từ ngày xuống giờ.
skills:
  - rbt_manual_testing
  - requirements_analyzer
---

> **BẮT BUỘC (MANDATORY SKILL):** Bạn PHẢI nạp và đọc kỹ nội dung của skill **`requirements_analyzer`** (tại `.claude/skills/requirements_analyzer/SKILL.md`) và **`rbt_manual_testing`** (tại `.claude/skills/rbt_manual_testing/SKILL.md`) trước khi bắt đầu.

# Workflow: Onboarding Report cho QC Mới

Workflow này giúp QC mới join giữa dự án **nắm được toàn bộ hiện trạng trong 1 session** — không cần hỏi team liên tục, không bị overload vì đọc quá nhiều tài liệu rời rạc.

## Khi nào dùng

- QC mới được assign vào dự án đang chạy
- QC cũ quay lại sau thời gian nghỉ dài
- Lead QC muốn audit coverage hiện tại trước khi lên kế hoạch sprint mới
- **Không dùng** cho dự án mới hoàn toàn chưa có artifact nào → dùng `/generate_manual_testcases_rbt`

## Input cần từ User

Cung cấp bất cứ thứ gì có sẵn — workflow hoạt động được với input không đầy đủ:

| Input | Bắt buộc | Mô tả |
|-------|----------|-------|
| **Tên dự án + mô tả ngắn** | ✅ | Hệ thống đang làm gì, đối tượng người dùng |
| **Bộ TC hiện có** | ⚠️ Nên có | File `.md`, bảng Excel paste vào, hoặc mô tả "có khoảng X TCs cho module Y" |
| **Requirements / Spec** | ⚠️ Nên có | Để so sánh với TC hiện có và phát hiện coverage gap |
| **Danh sách bug đang mở** | ⚠️ Nên có | Từ Backlog hoặc paste trực tiếp |
| **Sprint hiện tại / Roadmap** | ❌ Optional | Để xác định tác vụ ưu tiên ngay |
| **Role của QC mới** | ❌ Optional | Junior/Senior, chuyên manual hay cả automation — để điều chỉnh task list |

> Nếu thiếu input nào → agent sẽ ghi rõ "Không có thông tin — cần hỏi team" thay vì tự đoán.

## Các bước thực hiện

### Bước 1: Thu thập và đọc hiểu artifacts

1. Đọc toàn bộ input được cung cấp
2. Xác định những gì **có** và những gì **thiếu**:

   ```
   ✅ Có: Requirements module Login, Bộ TC 45 TCs, Bug list 12 bugs
   ❌ Thiếu: TC cho module Payment, Roadmap sprint tiếp theo
   ```

3. Xác nhận với user trước khi phân tích sâu

### Bước 2: Tổng hợp Project Snapshot

Mô tả ngắn gọn (không quá 1 trang) về:
- **Hệ thống đang làm gì** — mục đích, đối tượng dùng, tech stack (nếu biết)
- **Giai đoạn hiện tại** — đang phát triển tính năng mới / đang stabilize / gần release
- **Modules đã hoàn thiện** vs **đang phát triển** vs **chưa bắt đầu**

### Bước 3: Sinh Coverage Map

Với mỗi module/tính năng đã xác định, đánh giá mức độ coverage:

```markdown
| Module | Requirements | TC hiện có | Coverage | Chất lượng TC | Trạng thái |
|--------|-------------|-----------|----------|--------------|-----------|
| Login | ✅ Có | 12 TCs | 🟢 Đủ | Tốt | Stable |
| Payment | ✅ Có | 3 TCs | 🔴 Thiếu | Chỉ có Happy Path | Đang dev |
| Profile | ❌ Không có | 0 TCs | ⚫ Chưa có | — | Chưa bắt đầu |
| Dashboard | ✅ Có | 8 TCs | 🟡 Một phần | Thiếu edge cases | Stable |
```

**Mức coverage:**
- 🟢 Đủ — Happy Path + Negative + Boundary đều có
- 🟡 Một phần — có TC nhưng thiếu một số loại (thường là edge cases / negative)
- 🔴 Thiếu — chỉ có Happy Path hoặc rất ít TC
- ⚫ Chưa có — không có TC nào

### Bước 4: Phân tích Open Bugs

Nếu có danh sách bug, tổng hợp theo:

```markdown
## Open Bugs Summary

| Severity | Số lượng | Modules nhiều nhất |
|----------|---------|-------------------|
| Critical | 1 | Payment |
| Major | 4 | Login (2), Cart (2) |
| Minor | 7 | Nhiều modules |
| Trivial | 3 | UI |

### Bugs cần chú ý đặc biệt
- [BUG-PAY-003] Critical — Payment double charge: Đang investigate, chưa có fix
- [BUG-LOGIN-007] Major — Session timeout không hoạt động: Assigned cho DEV, ETA sprint này
```

### Bước 5: Sinh Immediate Task List

Dựa trên toàn bộ phân tích trên, sinh danh sách tác vụ **cụ thể, có thứ tự ưu tiên** cho QC mới:

```markdown
## Tác vụ ưu tiên cho [Tên QC] — Tuần đầu

### 🔴 Làm ngay (Ngày 1-2)
1. **Đọc requirements module Payment** — module coverage thấp nhất, đang active dev
2. **Verify bug BUG-PAY-003** (Critical) — reproduce lại để confirm vẫn còn tồn tại
3. **Hỏi team lead** về các điểm chưa rõ (xem danh sách câu hỏi bên dưới)

### 🟡 Làm trong tuần (Ngày 3-5)
4. **Bổ sung TC cho module Payment** — dùng `/generate_manual_testcases_rbt`
5. **Bổ sung Negative/Edge cases cho Dashboard** — coverage đang ở mức 🟡
6. **Regression smoke test** các module Stable (Login, Profile) trước sprint release

### 🟢 Để sau khi ổn định
7. Xây TC cho module Profile (chưa có TC nào)
8. Review và update TC cũ nếu requirements đã thay đổi
```

### Bước 6: Liệt kê câu hỏi cần hỏi team

Những thứ **không có trong tài liệu** nhưng QC cần biết để làm việc hiệu quả:

```markdown
## Câu hỏi cần hỏi team

### Hỏi Lead QC / QC cũ
- Q1: TC của module Payment bị bỏ dở vì lý do gì?
- Q2: Có test environment riêng không, hay test chung với dev?
- Q3: Bug nào đang được ưu tiên fix trong sprint này?

### Hỏi user
- Q4: Sprint tiếp theo có release tính năng nào mới không?
- Q5: Module Profile có được test trong sprint này không?

### Hỏi DEV
- Q6: BUG-PAY-003 đang ở trạng thái nào — đã có fix chưa hay vẫn đang investigate?
```

## Output

```markdown
# QC Onboarding Report — [Tên Dự Án]
Ngày tạo: [date] | Tạo cho: [Tên QC]

## 1. Project Snapshot
## 2. Coverage Map
## 3. Open Bugs Summary
## 4. Immediate Task List (tuần đầu)
## 5. Câu hỏi cần hỏi team
## 6. Những gì chưa có thông tin (cần bổ sung)
```

## Quy tắc quan trọng

- ❌ KHÔNG tự đoán coverage nếu không có TC hoặc requirements để so sánh — ghi rõ "Không đủ thông tin"
- ❌ KHÔNG sinh task list chung chung ("đọc tài liệu", "làm quen hệ thống") — phải cụ thể và có thứ tự
- ✅ Task list phải khả thi trong tuần đầu — không assign quá nhiều
- ✅ Luôn có phần "Câu hỏi cần hỏi team" — artifact không bao giờ đủ 100% thông tin
- ✅ Nếu input rất ít → vẫn sinh được report, chỉ cần ghi rõ phần nào cần bổ sung thêm
