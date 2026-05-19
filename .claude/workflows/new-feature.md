# Workflow: New Feature — BMAD Pipeline

Quy trình chuẩn để đưa một feature mới từ yêu cầu đến production trong ESKITCHEN.

---

## Tổng quan pipeline

```
User requirement
      │
      ▼ [ba-agent]
   SPEC.md  ←── /create-spec <feature>
      │
      ▼ [techlead-design-agent]
DESIGN.md per repo  ←── /create-design <SPEC.md>
      │
      ▼ [techlead-tasks-agent]
tasks/task-*.md  ←── /create-tasks <feature-folder/>
      │
      ▼ [pm-agent]
   PLAN.md  ←── /create-plan <feature-folder/>
      │
      ▼ CONTRACT LOCK ← phải confirm trước bước này
      │
      ┌──────────┬──────────────┐
      │          │              │
[backend-agent] [frontend-agent] [mobile-agent]
  task-1,2-x    task-3-x (FE)   task-3-x (Mobile)
      │          │              │
      └──────────┴──────────────┘
      │
      ▼ [qa-agent]
  QA Report  ←── verify AC + non-regression
      │
      ▼
  Deploy STG → PROD
```

---

## Bước 1 — Phân tích yêu cầu (BA)

**Agent:** `ba-agent`
**Command:** `/create-spec <tên feature>`
**Context cần đọc:**
- `.claude/context/specification.md` — business overview, epics, actors
- Các SPEC hiện có trong `es-kitchen-docs/docs/features/` và `docs/epics/`

**Output:** `SPEC.md` tại:
- Single-epic: `es-kitchen-docs/docs/epics/<E0X>/details/<feature>/SPEC.md`
- Cross-repo: `es-kitchen-docs/docs/features/<feature>/SPEC.md`

**Gate:** Không tiếp tục nếu SPEC chưa được PM/BrSE review.

---

## Bước 2 — Thiết kế kỹ thuật (Tech Lead Design)

**Agent:** `techlead-design-agent`
**Command:** `/create-design <path/to/SPEC.md>`
**Context cần đọc:**
- `.claude/context/technical.md` — tech stack, known bugs
- `es-kitchen-docs/docs/backend/es-kitchen-api/overview/patterns.md`
- `es-kitchen-docs/docs/backend/es-kitchen-api/overview/erd.md`

**BẮT BUỘC trước khi viết DESIGN:**
```
tilth_deps(path: "<file sẽ thay đổi>")
```

**Output:** `DESIGN.md` per repo (cùng folder với SPEC.md)

---

## Bước 3 — Phân rã tasks (Tech Lead Tasks)

**Agent:** `techlead-tasks-agent`
**Command:** `/create-tasks <path/to/feature-folder/>`
**Phase numbering global:**

| Phase | Nội dung | Repo |
|---|---|---|
| 1 | DB migration / schema | `es-kitchen-api` |
| 2 | Service + API endpoint | `es-kitchen-api` |
| 3 | Frontend E02/E03 + Mobile (song song) | `web-*` + `payment-app` |
| 4 | Integration test | Tất cả |

**Output:** `tasks/task-X-Y.md` per repo

---

## Bước 4 — Lập kế hoạch (PM)

**Agent:** `pm-agent`
**Command:** `/create-plan <path/to/feature-folder/>`
**Context cần đọc:**
- `.claude/context/specification.md` — phase-gate, budget context

**Output:** `PLAN.md` — timeline, assignee, gate alignment, risks

---

## CONTRACT LOCK ⚠️ (trước Phase 3)

Phải confirm đầy đủ trước khi FE/Mobile bắt đầu implement:

- [ ] REST API endpoints: method, path, request/response DTO, error codes
- [ ] WebSocket events: tên event, payload schema (nếu có)
- [ ] Push notification: payload format, trigger condition (nếu có)

**Ai confirm:** Backend dev + Frontend dev + Mobile dev (nếu có) + PM

---

## Bước 5 — Implement (Dev)

**Agent theo repo:**
- `es-kitchen-api` → `backend-agent`
- `es-kitchen-web-admin` / `es-kitchen-web-company` → `frontend-agent`
- `es-kitchen-payment-app` → `mobile-agent`

**Thứ tự thực hiện:**
```
task-1-x (DB)  →  task-2-x (API)  →  task-3-x (FE + Mobile, song song)  →  task-4-x (Integration)
```

**Sau mỗi task:** Chạy Memory Update Gate (xem `AGENTS.md`).

---

## Bước 6 — QA Verification

**Agent:** `qa-agent`

Với mỗi task đã implement:
1. Chạy test suite (`npm run test`, `flutter test`)
2. Validate từng AC trong SPEC.md
3. Verify Non-Regression table trong task file

**Status workflow:**
```
Dev: Open → In Progress → Request Review
Leader: In Review → Testing Request
QA: Testing Request → Resolved (hoặc Reopen nếu fail)
PM/Leader: Resolved → Closed
```

---

## Bước 7 — Deploy

1. Deploy STG → smoke test
2. Confirm với PM/client
3. Deploy PROD

**Không deploy thẳng PROD** khi chưa qua STG.

---

## Checklist trước khi đóng feature

- [ ] Tất cả tasks status = Resolved/Closed
- [ ] QA sign-off
- [ ] Memory Update Gate đã chạy (api-catalog, erd cập nhật nếu cần)
- [ ] PR approved và merged
- [ ] STG deploy pass
- [ ] PROD deploy pass
