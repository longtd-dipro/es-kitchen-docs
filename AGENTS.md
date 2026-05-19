# ESKITCHEN — Project Rules for AI Agents

<ecosystem>

## Repos

| Repo | Vai trò | Stack |
|---|---|---|
| `es-kitchen-api` | Core API, Business Logic, Domain Gatekeeper | NestJS / TypeScript / PostgreSQL |
| `es-kitchen-payment-app` | User Mobile App (E01) — iOS + Android | Flutter 3.x / Dart / Riverpod |
| `es-kitchen-web-admin` | System Admin Web (E03) — 160 functions | React 19 / Vite 7 / Redux Toolkit |
| `es-kitchen-web-company` | Company Admin Web (E02) — 58 functions | React 19 / Vite 7 / Redux Toolkit |

Docs: `es-kitchen-docs/` — SPEC, DESIGN, PLAN, tasks.

</ecosystem>

---

<core_rules>

## Nguyên tắc bắt buộc

1. **Không dùng MySQL** — chỉ **PostgreSQL** + TypeORM.
2. **Không dùng GraphQL** — chỉ **REST API**.
3. **Không nhầm E02 và E03** — `web-company` = Company Admin (E02), `web-admin` = System Admin (E03).
4. **Không dùng Stripe** — Payment dùng **elepay**, Alipay, WeChat Pay.
5. **Không tự ý thay đổi** linter config, test config, `.gitignore`, migration files.
6. **Không đoán mò** tech stack — dùng `tilth_search` để xác nhận.
7. **Không commit** khi không được yêu cầu rõ ràng.
8. **Không sửa source code** khi task là review/fix docs.
9. **Mobile version:** DEV `0.0.x` / STG `0.1.x` / PROD `1.0.x`.
10. **Secrets:** AWS Parameter Store — không hard-code, không `.env` production.

**AI Policy (không được vi phạm):**
- Đọc đúng file được chỉ định trong agent/command — không tự search rộng
- Không tự suy nghĩ / đoán khi thiếu context — hỏi user
- Không generate code khi chưa đọc đủ docs + xác nhận source
- Context files chỉ đọc đúng theo role (xem cột "Ai đọc" trong bảng Context bên dưới)

Chi tiết → `.claude/rules/`: `stack-constraints.md` · `security-rules.md` · `git-workflow.md` · `coding-style.md` · `project-structure.md`

</core_rules>

---

<tilth_rules>

## Source code analysis — dùng tilth

```bash
tilth_search(query: "OrderService")          # tìm symbol/usage
tilth_read(paths: ["<file>"])                # đọc file
tilth_files(pattern: "**/*.service.ts")      # list file
tilth_deps(path: "<file>")                   # blast radius — BẮT BUỘC trước khi đổi public interface
```

**Thứ tự:** đọc docs liên quan → `tilth_search` xác nhận thực tế → mới generate code.

</tilth_rules>

---

<red_line_rules>

## Phân công theo repo

| Tính năng | Repo |
|---|---|
| API, business logic, database, auth, tích hợp ngoài | `es-kitchen-api` |
| User mobile app — order, menu, delivery, payment (E01) | `es-kitchen-payment-app` |
| System Admin (E03) | `es-kitchen-web-admin` |
| Company Admin (E02) | `es-kitchen-web-company` |
| elepay / Alipay / WeChat Pay | `es-kitchen-api` + `es-kitchen-payment-app` |
| Push notification Firebase | `es-kitchen-api` (send) + `es-kitchen-payment-app` (receive) |

</red_line_rules>

---

<agent_architecture>

## Kiến trúc Agent — `.claude/`

### Sub-agents — `.claude/agents/`

| Agent | Vai trò | Trigger khi |
|---|---|---|
| `ba-agent.md` | Business Analyst | Phân tích yêu cầu, tạo SPEC.md |
| `backend-agent.md` | NestJS Developer | Implement/review API, service, entity, migration, Redis |
| `frontend-agent.md` | React Developer | Implement/review component, hook, store (E02 + E03) |
| `mobile-agent.md` | Flutter Developer | Implement/review screen, Socket.IO, payment (E01) |
| `pm-agent.md` | Project Manager | Tạo PLAN.md, phase-gate, timeline |
| `qa-agent.md` | QA Engineer | Verify test coverage, validate AC, non-regression |

> Tech Lead (Design + Tasks): thực hiện qua `/create-design` và `/create-tasks`.

### Slash Commands — `.claude/commands/`

| Command | Chức năng |
|---|---|
| `/create-spec <feature>` | Tạo SPEC.md |
| `/create-design <SPEC.md>` | Tạo DESIGN.md per repo |
| `/create-tasks <feature/>` | Phân rã DESIGN → task files |
| `/create-plan <feature/>` | Tạo PLAN.md |
| `/review-code [path]` | Review code |
| `/generate-api <module>` | Scaffold NestJS module |
| `/create-component <Name> [admin\|company]` | Scaffold React component |

### Skills — `.claude/skills/`

| Skill | Repo | Dùng khi |
|---|---|---|
| `nestjs-best-practices/` | `es-kitchen-api` | Viết/review NestJS |
| `postgresql/` | `es-kitchen-api` | Schema, migration, query |
| `redis-development/` | `es-kitchen-api` | Redis cache pattern |
| `react-expert/` | web-admin, web-company | React hooks/component |
| `frontend-review/` | web-admin, web-company | Code review E02 + E03 |
| `flutter-review/` | payment-app | Code review Flutter E01 |
| `business-analyst/` | — | Discovery, SPEC template |
| `technical-writing/` | Tất cả | Viết/cập nhật docs |
| `solution-architect/` | — | Kiến trúc cross-cutting |

### Context — `.claude/context/` (đọc on-demand)

| File | Nội dung | Ai đọc |
|---|---|---|
| `specification.md` | Business context, epics, phase-gate G1-G6 | `ba-agent`, `pm-agent`, `/create-spec`, `/create-plan` |
| `technical.md` | Tech stack, CI/CD, known bugs | `/create-design`, `backend-agent` |
| `backlog-workflow.md` | Quy tắc tạo issue/task, status workflow | Tất cả agents khi tạo task |
| `doc-structure.md` | Cấu trúc SPEC/DESIGN/PLAN theo feature type | `ba-agent`, `/create-spec`, `/create-design` |
| `ai-workflow.md` | Kiến trúc AI Agent system | Khi mở rộng agent system |

### Workflows — `.claude/workflows/` (đọc on-demand)

| File | Nội dung | Ai dùng |
|---|---|---|
| `db-connect-dev.md` | Kết nối PostgreSQL DEV | `backend-agent` |
| `db-connect-staging.md` | Kết nối PostgreSQL Staging qua SSM | `backend-agent` |
| `new-feature.md` | BMAD pipeline end-to-end | Reference workflow |
| `bug-fix.md` | Quy trình điều tra và fix bug | `backend-agent` / `frontend-agent` / `mobile-agent` |

</agent_architecture>

---

<bmad_workflow>

## BMAD Workflow

| Bước | Command | Output | Agent |
|---|---|---|---|
| 1 | `/create-spec <feature>` | `SPEC.md` | `ba-agent` |
| 2 | `/create-design <SPEC.md>` | `DESIGN.md` per repo | Claude Code (Tech Lead) |
| 3 | `/create-tasks <feature/>` | `tasks/task-*.md` | Claude Code (Tech Lead) |
| 4 | `/create-plan <feature/>` | `PLAN.md` | `pm-agent` |
| 5 | Implement task | Working code | `backend-agent` / `frontend-agent` / `mobile-agent` |
| 6 | QA Verify | QA Report | `qa-agent` |

**Phase order:** Phase 1 (DB migration) → Phase 2 (API) → Phase 3 (FE + Mobile song song) → Phase 4 (Integration)

**Contract Lock** trước Phase 3: REST API + WebSocket events + Push notification payload — confirm bởi BE + FE + Mobile + PM.

Chi tiết → `.claude/workflows/new-feature.md`

</bmad_workflow>

---

<memory_update_gate>

## Memory Update Gate — sau mỗi Dev task

| Thay đổi | Action |
|---|---|
| Endpoint mới / đổi method/path/response | cập nhật `api-catalog.md` |
| Entity mới / đổi column/relation | cập nhật `erd.md` |
| Pattern mới trong codebase | cập nhật `patterns.md` của repo |
| Thay đổi kiến trúc lớn | cập nhật `architecture.md` / `tech_stack.md` |
| Không có gì thay đổi | Bỏ qua |

```
✅ task-x-y hoàn thành
Files đã thay đổi:  <path> → <mô tả>
Non-Regression:     ✅ <tính năng X> vẫn hoạt động
Memory Update Gate: ✅/skipped api-catalog / erd / patterns
Bước tiếp:          → task-x-(y+1)
```

</memory_update_gate>
