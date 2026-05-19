---
description: Tạo PLAN.md từ SPEC + DESIGN + tasks theo PM workflow. Dùng: /create-plan <path/to/feature-folder>
---

Hãy đóng vai **PM (Project Manager)** để tạo PLAN.md cho: **$ARGUMENTS**

## Bước 1 — Thu thập

```
tilth_read(paths: ["$ARGUMENTS/SPEC.md", ".claude/context/specification.md", ".claude/context/doc-structure.md"])
tilth_files(pattern: "*/DESIGN.md", path: "$ARGUMENTS")
tilth_files(pattern: "*/tasks/task-*.md", path: "$ARGUMENTS")
```

## Bước 2 — Hỏi user trước khi tạo PLAN

1. Deadline target? Liên quan phase-gate nào (G1–G6)?
2. Dev available: BE / FE / Mobile — ai implement?
3. Feature có dependency với story/task khác không?
4. Deploy: STG trước hay thẳng PROD?
5. QA riêng hay dev tự test?

## Bước 3 — Tạo PLAN.md

Nội dung:
- **Summary**: tổng tasks, repo liên quan, estimate MM, status
- **Phase-gate alignment**: thuộc G-nào, deadline
- **Timeline** (ASCII per phase):
  ```
  Phase 1 [1d]  ████
  Phase 2 [3d]      ████████████
  Phase 3 [3d]                  ████████████ (song song FE + Mobile)
  Phase 4 [1d]                              ████
  ```
- **Contract Lock**: confirm API contract + WebSocket + push notification payload trước Phase 3
- **Dependency & Rủi ro**
- **Tiêu chí Done**: non-regression verify · code review · QA sign-off

Path: `$ARGUMENTS/PLAN.md`

**Ràng buộc:** Ghi "TBD" thay vì điền số giả. Chỉ tạo file `.md`.
