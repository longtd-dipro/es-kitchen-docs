# Project Structure — ESKITCHEN

## 4 Repos (Red Line Rules)

| Repo | Epic | Trách nhiệm | Không được làm |
|---|---|---|---|
| `es-kitchen-api` | — | API, business logic, database, auth, integrations | Implement UI logic |
| `es-kitchen-payment-app` | E01 | User mobile app — order, menu, delivery, payment | Gọi BE logic trực tiếp không qua API |
| `es-kitchen-web-admin` | E03 | System Admin — quản trị toàn hệ thống (160 functions) | Implement business logic của E02 |
| `es-kitchen-web-company` | E02 | Company Admin — quản lý company/contract/order (58 functions) | Implement business logic của E03 |

> **E02 ≠ E03** — lỗi phổ biến nhất. Luôn xác nhận repo trước khi code.

## NestJS Module Structure

```
src/modules/<feature>/
├── <feature>.module.ts
├── <feature>.controller.ts     ← HTTP layer only
├── <feature>.service.ts        ← Business logic
├── entities/<feature>.entity.ts
├── dto/
│   ├── create-<feature>.dto.ts
│   └── list-<feature>.dto.ts
└── <feature>.service.spec.ts
```

## React Project Structure

```
src/
├── pages/          ← Route-level components (1 file = 1 route)
├── components/     ← Shared, reusable UI components
├── hooks/          ← Custom hooks (use<Feature>.ts)
├── store/          ← Redux slices (client state only)
├── services/       ← API call functions
└── utils/          ← Pure utility functions
```

## Doc Structure (BMAD)

```
es-kitchen-docs/docs/
├── features/<feature>/          ← Cross-repo feature
│   ├── SPEC.md                  ← BA
│   ├── PLAN.md                  ← PM
│   ├── es-kitchen-api/
│   │   ├── DESIGN.md            ← Tech Lead
│   │   └── tasks/task-X-Y.md
│   └── es-kitchen-web-admin/
│       ├── DESIGN.md
│       └── tasks/task-X-Y.md
└── epics/<E0X>/details/<feature>/  ← Single-repo epic
    ├── SPEC.md
    └── ...
```

## Tilth — Code Analysis Tool

Luôn dùng tilth MCP thay vì bash grep/find/cat:
- `tilth_search` → tìm symbol, definition, usage
- `tilth_read` → đọc file với smart outline
- `tilth_files` → list file theo pattern
- `tilth_deps` → blast radius trước khi đổi interface public

## AI Agent Policy — BẮT BUỘC

**Không tự suy nghĩ, không tự đoán, không search bừa:**

1. **Đọc đúng file được chỉ định** — mỗi agent/command có danh sách file phải đọc ở Bước 1. Không bỏ qua, không đọc thêm file ngoài danh sách đó trừ khi có lý do rõ ràng từ task.

2. **Không tự suy nghĩ khi thiếu thông tin** — nếu context chưa đủ để ra quyết định, hỏi user. Không tự điền giả định vào SPEC/DESIGN/task.

3. **Không search toàn bộ codebase** — chỉ `tilth_search` khi cần xác nhận symbol/file cụ thể liên quan đến task. Không scan rộng để "khám phá" codebase.

4. **Context files chỉ đọc khi đúng role** — xem cột "Ai đọc" trong bảng Context của AGENTS.md. Agent không liên quan không cần đọc.

5. **Không generate code khi chưa đọc đủ context** — thứ tự bắt buộc: đọc docs → xác nhận source → mới generate.
