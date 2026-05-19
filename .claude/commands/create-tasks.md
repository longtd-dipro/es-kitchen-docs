---
description: Phân rã DESIGN.md thành task files theo Tech Lead Tasks workflow. Dùng: /create-tasks <path/to/feature-folder>
---

Hãy đóng vai **Tech Lead (Tasks)** để tạo task files từ: **$ARGUMENTS**

## Bước 1 — Đọc DESIGN.md và context

```
tilth_files(pattern: "*/DESIGN.md", path: "$ARGUMENTS")
tilth_read(paths: [".claude/context/doc-structure.md"])
```
Đọc từng DESIGN.md, hiểu rõ scope. Đọc doc-structure.md để đặt task file đúng path (single-epic vs cross-repo).

## Bước 2 — Mapping Repo → Backlog Category & ROLE

| Repo | Category (Backlog) | ROLE Tag |
|---|---|---|
| `es-kitchen-api` | _(theo epic: Admin_Web / Company_Web / Payment_App_Mobile / ...)_ | `[BE]` |
| `es-kitchen-web-admin` | `Admin_Web` | `[FE]` |
| `es-kitchen-web-company` | `Company_Web` | `[FE]` |
| `es-kitchen-payment-app` | `Payment_App_Mobile` | `[FE]` |

> BE task phục vụ epic nào thì gán Category của epic đó (Admin_Web nếu là E03, Company_Web nếu E02, v.v.)

## Bước 3 — Phase numbering (global, cross-repo)

| Phase | Nội dung | Repo |
|---|---|---|
| Phase 1 | DB migration / schema setup | `es-kitchen-api` |
| Phase 2 | NestJS service + API endpoint | `es-kitchen-api` |
| Phase 3 | Frontend E02/E03 + Flutter Mobile (song song) | web + mobile |
| Phase 4 | Integration test | tất cả repo |

## Bước 4 — Mỗi task file phải có

```markdown
# [ROLE] [Category] - [Mô tả ngắn gọn hành động]

## Backlog Info
- **Issue Type:** Task
- **Category:** <Admin_Web | Company_Web | Payment_App_Mobile | Supplier_Web | Driver_App_Web | Delivery_Web>
- **Parent Issue:** <User Story title hoặc Epic ID — ví dụ: US-xxx hoặc E02-feature-name>
- **Version:** Phase 2
- **Milestone:** <Released xxx | Go-live yyy>
- **Estimate Hour:** Xh
- **Actual Hour:** — _(điền khi Resolved)_
- **Status:** Open

## Metadata
- Phase: X | Repo: <repo> | Depends on: task-Y-Z

## Mục tiêu
[1 câu]

## Context (đọc trước khi code)
- DESIGN.md: <path>
- File liên quan: <tilth_search result>

## Yêu cầu implement
[code snippet / pseudocode cụ thể]

## Unit Tests (BẮT BUỘC)
- File: <path>.spec.ts
- Test cases: [danh sách]
- Coverage target: X%
- Verify: `npm run test -- <file>`

## Non-Regression Table
| Tính năng | File liên quan | Cách verify |

## Không được làm
[scope boundary]

## Definition of Done
- [ ] Build pass
- [ ] Lint pass
- [ ] Unit Tests pass (coverage đạt target)
- [ ] Non-Regression verify đủ
- [ ] Actual Hour cập nhật
- [ ] Status chuyển → Request Review (sau khi dev xong)
```

## Bước 5 — Status Workflow nhắc nhở

Khi implement task, developer cần tuân thủ workflow:

```
Open → In Progress → Request Review → In Review → Testing Request → Resolved → Closed
```

- Developer tự chuyển: `Open → In Progress → Request Review`
- Leader/PM chuyển: `In Review → Testing Request → Closed`
- QC chuyển: `Testing Request → Resolved` (hoặc `Reopen` nếu fail)

**Ràng buộc:** Mỗi task estimatable trong 4–8h. Chỉ tạo file `.md`. Không commit khi chưa được yêu cầu.
