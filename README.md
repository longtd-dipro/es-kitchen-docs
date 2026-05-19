**Last updated:** 19/05/2026
**Maintained by:** TRAN DUC LONG

---

## 1. Tổng quan

Hệ thống AI Agent của ESKITCHEN được tổ chức trong thư mục `.claude/` tại root project. Thiết kế theo nguyên tắc **load đúng thứ gì, đúng lúc** — tránh tốn token không cần thiết.

```
.claude/
├── agents/        ← Sub-agents chuyên biệt (load khi spawn)
├── commands/      ← Slash commands / workflow shortcuts (load khi gọi)
├── skills/        ← Knowledge packs chuyên sâu (load khi invoke)
├── rules/         ← Constraints & conventions (AUTO-LOAD mọi session)
├── context/       ← Project background knowledge (load on-demand)
└── workflows/     ← Operational runbooks (load on-demand)
```

---

## 2. Load Policy

| Thành phần               | Khi nào load          | Ai load                               |
| ------------------------ | --------------------- | ------------------------------------- |
| `AGENTS.md` (root)       | Mọi session           | Claude Code tự động                   |
| `.claude/rules/*.md`     | Mọi session           | Claude Code tự động                   |
| `.claude/agents/*.md`    | Khi agent được spawn  | Claude Code khi dùng Agent tool       |
| `.claude/commands/*.md`  | Khi gọi `/command`    | Claude Code khi user gõ slash command |
| `.claude/skills/`        | Khi invoke skill      | Agent chủ động invoke                 |
| `.claude/context/*.md`   | On-demand             | Agent chủ động `tilth_read`           |
| `.claude/workflows/*.md` | On-demand             | Agent chủ động `tilth_read`           |

**Token tối ưu:** Chỉ `AGENTS.md` + `rules/` là always-loaded (~200 dòng). Toàn bộ chi tiết còn lại chỉ load khi cần.

---

## 3. Sub-agents — `.claude/agents/`

Mỗi agent có tool set giới hạn đúng với vai trò. Không dùng agent sai role.

| Agent                         | Vai trò             | Tool chính                           | Trigger khi                                              |
| ----------------------------- | ------------------- | ------------------------------------ | -------------------------------------------------------- |
| `ba-agent.md`                 | Business Analyst    | Read, Write, tilth_read, tilth_files | Phân tích yêu cầu, tạo SPEC.md                           |
| `techlead-design-agent.md`    | Tech Lead Design    | Read, Write, Edit, tilth_*           | Đọc SPEC → tạo DESIGN.md per repo                        |
| `techlead-tasks-agent.md`     | Tech Lead Tasks     | Read, Write, Edit, tilth_*           | Đọc DESIGN → phân rã task-x-y.md                         |
| `backend-agent.md`            | NestJS Developer    | Read, Edit, Write, Bash, tilth_*     | Implement/review API, service, entity, migration, Redis  |
| `frontend-agent.md`           | React Developer     | Read, Edit, Write, tilth_*           | Implement/review component, hook, store (E02 + E03 + E04)|
| `mobile-agent.md`             | Flutter Developer   | Read, Edit, Write, tilth_*           | Implement/review screen, Socket.IO, payment (E01)        |
| `pm-agent.md`                 | Project Manager     | Read, Write, Edit, tilth_read        | Tạo PLAN.md, phase-gate, timeline                        |
| `qa-agent.md`                 | QA Engineer         | Read, Bash, tilth_*                  | Verify test, validate AC, non-regression                 |

> Tech Lead trigger qua agent (`subagent_type: techlead-design-agent / techlead-tasks-agent`) **hoặc** slash command (`/create-design`, `/create-tasks`).

---

## 4. Slash Commands — `.claude/commands/`

Workflow shortcuts theo BMAD pipeline. Mỗi command định nghĩa rõ Bước 1 (đọc file gì) trước khi thực hiện.

| Command                    | File                  | Bước 1 đọc                                      | Output               |
| -------------------------- | --------------------- | ----------------------------------------------- | -------------------- |
| `/create-spec <feature>`   | `create-spec.md`      | `specification.md`, `doc-structure.md`          | `SPEC.md`            |
| `/create-design <SPEC.md>` | `create-design.md`    | SPEC + `technical.md` + `doc-structure.md`      | `DESIGN.md` per repo |
| `/create-tasks <feature/>` | `create-tasks.md`     | DESIGN files + `doc-structure.md`               | `task-*.md`          |
| `/create-plan <feature/>`  | `create-plan.md`      | SPEC + `specification.md` + `doc-structure.md`  | `PLAN.md`            |
| `/review-code [path]`      | `review-code.md`      | File được chỉ định                              | Review report        |
| `/generate-api <module>`   | `generate-api.md`     | `patterns.md` của api                           | NestJS scaffold      |
| `/create-component <Name>` | `create-component.md` | `patterns.md` của web repo                      | React scaffold       |

---

## 5. Skills — `.claude/skills/`

Knowledge packs chuyên sâu. Agents invoke khi cần expertise cụ thể.

| Skill                    | Áp dụng                | Dùng khi                                       |
| ------------------------ | ---------------------- | ---------------------------------------------- |
| `nestjs-best-practices/` | `es-kitchen-api`       | Viết/review NestJS, DI, module structure       |
| `postgresql/`            | `es-kitchen-api`       | Schema, migration, query optimization, index   |
| `redis-development/`     | `es-kitchen-api`       | Redis cache pattern, TTL, key naming           |
| `react-expert/`          | web-admin, web-company | React hooks, component design                  |
| `frontend-review/`       | web-admin, web-company | Code review E02 + E03 + E04                    |
| `flutter-review/`        | payment-app            | Code review Flutter E01                        |
| `business-analyst/`      | —                      | Discovery, SPEC template, interview framework  |
| `technical-writing/`     | Tất cả                 | Viết/cập nhật SPEC/DESIGN/PLAN                 |
| `solution-architect/`    | —                      | Kiến trúc cross-cutting, integration           |

---

## 6. Rules — `.claude/rules/`

Auto-load mọi session. Không cần invoke thủ công. Đây là những ràng buộc cứng không được vi phạm.

| File                   | Nội dung                                                             |
| ---------------------- | -------------------------------------------------------------------- |
| `stack-constraints.md` | Tech stack cố định, version lock, mobile convention                  |
| `security-rules.md`    | Secret management, JWT, payment, mobile security                     |
| `git-workflow.md`      | Branch naming (`feat/<STORY-ID>_desc`), commit format, PR checklist  |
| `coding-style.md`      | NestJS / React / Flutter style rules                                 |
| `project-structure.md` | Module structure, doc structure, tilth usage, **AI Policy**          |

---

## 7. Context — `.claude/context/`

Background knowledge. Agents đọc on-demand theo role — không phải file nào agent nào cũng đọc.

| File                  | Nội dung                                                     | Ai đọc                                                                                        |
| --------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| `specification.md`    | Business context, 6 epics, phase-gate G1–G6, actors, budget  | `ba-agent`, `pm-agent`, `/create-spec`, `/create-plan`                                        |
| `technical.md`        | Tech stack detail, git convention, CI/CD, known bugs         | `techlead-design-agent`, `/create-design`, `backend-agent`                                    |
| `backlog-workflow.md` | Issue types, status workflow, title format, phân quyền       | `techlead-tasks-agent`, `/create-tasks`, tất cả agents khi tạo task                          |
| `doc-structure.md`    | Cấu trúc SPEC/DESIGN/task — single-epic vs cross-repo path   | `ba-agent`, `techlead-design-agent`, `techlead-tasks-agent`, `/create-spec`, `/create-design`, `/create-tasks` |
| `ai-workflow.md`      | Reference architecture AI Agent system                       | Khi mở rộng/debug agent system                                                                |

---

## 8. Workflows — `.claude/workflows/`

Operational runbooks — quy trình từng bước. Đọc khi được yêu cầu cụ thể.

| File                    | Nội dung                                            | Ai dùng                                            |
| ----------------------- | --------------------------------------------------- | -------------------------------------------------- |
| `new-feature.md`        | BMAD pipeline end-to-end từ requirement đến deploy  | Reference cho tất cả roles                         |
| `bug-fix.md`            | Quy trình điều tra root cause → fix → QA verify     | `backend-agent`, `frontend-agent`, `mobile-agent`  |
| `db-connect-dev.md`     | Kết nối PostgreSQL DEV qua DBeaver                  | `backend-agent`                                    |
| `db-connect-staging.md` | Kết nối PostgreSQL Staging qua AWS SSM tunnel       | `backend-agent`                                    |

---

## 9. BMAD Pipeline

Luồng chuẩn từ yêu cầu đến production:

```
User requirement
      │
      ▼ [ba-agent] /create-spec
   SPEC.md
      │
      ▼ [techlead-design-agent] /create-design
DESIGN.md (per repo)
      │
      ▼ [techlead-tasks-agent] /create-tasks
tasks/task-*.md
      │
      ▼ [pm-agent] /create-plan
   PLAN.md
      │
      ▼ ⚠️ CONTRACT LOCK
      │   REST API + WebSocket + Push notification
      │   confirm: BE + FE + Mobile + PM
      │
      ┌──────────────┬──────────────────┐
      │              │                  │
[backend-agent] [frontend-agent]  [mobile-agent]
 Phase 1-2        Phase 3 (FE)     Phase 3 (Mobile)
      │              │                  │
      └──────────────┴──────────────────┘
      │
      ▼ [qa-agent]
  QA Report (PASS / FAIL)
      │
      ▼
  Deploy STG → PROD
```

**Phase order (global, cross-repo):**

| Phase | Nội dung                                   | Repo              |
| ----- | ------------------------------------------ | ----------------- |
| 1     | DB migration / schema                      | `es-kitchen-api`  |
| 2     | Service + API endpoint                     | `es-kitchen-api`  |
| 3     | Frontend E02/E03/E04 + Mobile E01 (song song) | web + payment-app |
| 4     | Integration test                           | tất cả repo       |

---

## 10. AI Policy

Quy tắc bắt buộc cho mọi agent — định nghĩa trong `.claude/rules/project-structure.md`:

1. **Đọc đúng file được chỉ định** — mỗi agent/command có danh sách file phải đọc ở Bước 1. Không bỏ qua, không đọc thêm ngoài danh sách trừ khi có lý do rõ ràng từ task.
2. **Không tự suy nghĩ khi thiếu thông tin** — nếu context chưa đủ, hỏi user. Không tự điền giả định vào SPEC/DESIGN/task.
3. **Không search toàn bộ codebase** — chỉ `tilth_search` khi cần xác nhận symbol/file cụ thể liên quan đến task.
4. **Context files chỉ đọc đúng theo role** — xem cột "Ai đọc" trong bảng Context (mục 7).
5. **Không generate code khi chưa đọc đủ context** — thứ tự: đọc docs → xác nhận source → mới generate.
