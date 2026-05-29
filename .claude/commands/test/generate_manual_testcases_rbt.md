---
description: Sinh manual test cases chất lượng cao theo quy trình AI-RBT 6 bước (Risk-Based Testing) từ requirements.
skills:
  - rbt_manual_testing
  - requirements_analyzer
---

> **BẮT BUỘC (MANDATORY SKILL):** Bạn PHẢI nạp và đọc kỹ nội dung của skill **`rbt_manual_testing`** (tại `.claude/skills/rbt_manual_testing/SKILL.md`) trước khi bắt đầu thực hiện tác vụ này. Sử dụng **Mode FULL RBT** của skill. Ngoài ra, tham khảo thêm skill **`requirements_analyzer`** để hiểu cách phân tích giao diện nếu cần.

# Workflow: Sinh Manual Test Cases theo AI-RBT Framework (FULL RBT Mode)

Workflow này sử dụng **Mode FULL RBT** của skill `rbt_manual_testing` — quy trình **AI-RBT (AI-Driven Risk-Based Testing)** gồm 6 bước tuần tự để sinh manual test cases từ tài liệu yêu cầu.

> [!NOTE]
> **Luồng Claude Code:** Agent thực hiện theo hướng dẫn trong skill, KHÔNG cần đọc file prompt.txt.

## ⚠️ Nguyên tắc thực thi

- **Mode:** FULL RBT (6 bước tuần tự)
- **BẮT BUỘC chạy tuần tự** từng bước, KHÔNG gộp nhiều bước
- **PHẢI dừng lại** chờ user phản hồi tại Bước 2 (Q&A) và Bước 4 (Review Scenarios)
- Nếu user chưa cung cấp requirements, hỏi user cung cấp trước khi bắt đầu
- Tất cả output bằng **Tiếng Việt**

## Các bước thực hiện

Thực hiện theo hướng dẫn chi tiết trong skill `rbt_manual_testing` → phần **Mode 2: FULL RBT**.

### Bước 1: Khởi tạo ngữ cảnh (Context & Role-play)
1. Yêu cầu user cung cấp: tên dự án, mô tả hệ thống, mục tiêu MVP, tài liệu yêu cầu
2. Đọc kỹ tài liệu, xác nhận hiểu bối cảnh
3. **Chờ user xác nhận** → sang Bước 2

### Bước 2: Phân tích yêu cầu (Analysis & QnA)

> Nếu user cung cấp AC + Q&A đã chốt (output từ `/analyze_requirement_document`):
> → Bỏ qua step 2 (Phát hiện Ambiguities), chỉ thực hiện step 1 (xác định luồng) + hỏi thêm nếu còn thiếu.

1. Xác định Happy Path, Alternate Paths, Exception Paths
2. Phát hiện Ambiguities (thiếu sót, mâu thuẫn, chưa rõ ràng)
3. Đặt câu hỏi Q&A có đánh số (Q1, Q2...) cho user, kèm ngữ cảnh + assumption
4. **DỪNG LẠI — Chờ user trả lời câu hỏi** → sang Bước 3

### Bước 3: Phân rã hệ thống (Decomposition)
1. Chia tính năng thành Modules / Sub-modules
2. Mô tả chức năng từng Module + Dependencies giữa chúng

### Bước 4: Đảm bảo độ bao phủ (Traceability)
1. Map Module → mã Yêu cầu (REQ-01, REQ-02...)
2. Cross-check thiếu sót (Gap Analysis)
3. Nếu AC được cung cấp trong input: map từng AC item vào Module → đảm bảo mỗi AC có ít nhất 1 Scenario cover; nếu không có AC → bỏ qua
4. Liệt kê High-Level Scenarios cho từng Module
5. **Chờ user review** scenarios → sang Bước 5

### Bước 5: Sinh Test Case chi tiết (RBT & TC Generation)
1. Đánh giá Risk Level (High/Medium/Low) cho mỗi Module
2. Sinh test cases đầy đủ: Title, Pre-condition, Steps, Expected, Test Data, Priority
3. Áp dụng kỹ thuật: EP, BVA, Decision Table, State Transition
4. **Validation chuyên biệt từng trường (Field-Level Validation):**
   - Liệt kê tất cả input fields trên form/UI đang test
   - Sinh validation TCs **riêng cho TỪNG trường** theo đặc tính riêng
   - Tham chiếu **Bảng Field-Level Validation** trong skill `rbt_manual_testing`
   - **KHÔNG** gộp validation nhiều trường vào 1 TC
5. Bao phủ đầy đủ: Happy Path, Negative, Boundary, Edge Cases
6. Test Data phải cụ thể (không placeholder chung)
7. Nếu quá nhiều → sinh từng Module, hỏi user để tiếp tục
8. **Sinh UI Visual TCs** theo Bảng Field-Level Visual States Validation trong skill — đặt TRƯỚC logic TCs của cùng field, trong cùng bảng TC

### Bước 6: Chuẩn hóa Format (Template Mapping)
1. Đóng gói toàn bộ test cases vào bảng Markdown chuẩn:
   `| ID | Function Name | Category | Risk Level | Test Scenario | Precondition | Steps | Expected Results | Test Data | Priority |`
2. Không được bỏ sót test case nào
3. Xuất dưới dạng Artifact nếu dài

## Output

- Bảng Test Cases Markdown hoàn chỉnh, sẵn sàng copy sang Backlog/Excel
- UI Visual TCs (screen level + component level + field level) — trong cùng bảng với logic TCs
- Traceability Matrix
- Danh sách Ambiguities đã giải quyết
