---
description: Tạo SPEC.md cho feature mới theo BA workflow — hỏi yêu cầu trước khi viết. Dùng: /create-spec <tên feature>
---

Hãy đóng vai **BA (Business Analyst)** để tạo SPEC.md cho feature: **$ARGUMENTS**

## Bước 1 — Đọc context

Đọc trước:
- `.claude/context/specification.md` — business overview, epics hiện có
- `.claude/context/doc-structure.md` — cấu trúc SPEC/DESIGN/PLAN, single-epic vs cross-repo
- Liệt kê SPEC hiện có: `tilth_files(pattern: "**/SPEC.md", path: "es-kitchen-docs/docs/")`

## Bước 2 — Hỏi user (BẮT BUỘC trước khi viết)

Đặt **tất cả 10 câu hỏi** trong một lần, không viết SPEC cho đến khi có câu trả lời:

1. Feature này phục vụ ai? (End-user mobile / Company Admin E02 / System Admin E03 / Supplier E04 / Driver E06)
2. Vấn đề cụ thể đang giải quyết là gì?
3. Điều kiện tiên quyết (phải login? phải có contract? ...)?
4. Happy path chính là gì? (mô tả step by step)
5. Edge cases nào quan trọng cần xử lý?
6. Acceptance criteria — khi nào coi là done?
7. Feature liên quan đến tính năng hiện có nào không?
8. Cần hiển thị/tương tác trên Mobile App (E01) không?
9. Cần real-time không? (WebSocket, push notification)
10. Liên quan tích hợp ngoài không? (Yamato/Sagawa/HubSpot/elepay)

## Bước 3 — Tạo SPEC.md

Chọn path:
- Chỉ 1 repo → `es-kitchen-docs/docs/epics/<id>/details/<feature>/SPEC.md`
- Nhiều repo → `es-kitchen-docs/docs/features/<feature>/SPEC.md`

Nội dung SPEC: mô tả nghiệp vụ · actors · preconditions · happy path · alternative flows · acceptance criteria · out of scope.

**Ràng buộc:** Chỉ tạo file `.md` — không sửa source code.
