# Doc Structure — ESKITCHEN (BMAD)

## Single-epic feature
Khi feature chỉ ảnh hưởng **1 repo duy nhất** — DESIGN.md nằm thẳng trong thư mục feature (không có subfolder repo):

```
es-kitchen-docs/docs/epics/<epic-id>/details/<feature-name>/
├── SPEC.md       ← BA tạo (nghiệp vụ)
├── DESIGN.md     ← Tech Lead tạo (kỹ thuật, 1 repo nên không cần subfolder)
├── PLAN.md       ← PM tạo (kế hoạch)
└── tasks/
    ├── task-1-1.md
    └── task-2-1.md
```

Ví dụ: `docs/epics/E02/details/company-account-management/`

---

## Cross-repo feature
Khi feature ảnh hưởng **nhiều repo** (phổ biến trong ESKITCHEN — thường BE + FE hoặc BE + Mobile):

```
es-kitchen-docs/docs/features/<feature-name>/
├── SPEC.md                          ← BA tạo (1 file, góc nhìn nghiệp vụ)
├── PLAN.md                          ← PM tạo (tổng hợp tất cả repo)
├── es-kitchen-api/
│   ├── DESIGN.md                    ← Tech Lead (kỹ thuật BE)
│   └── tasks/
│       ├── task-1-1.md              ← Phase 1: DB migration
│       ├── task-2-1.md              ← Phase 2: Service
│       └── task-2-2.md              ← Phase 2: API endpoint
├── es-kitchen-web-admin/            ← có nếu E03 liên quan
│   ├── DESIGN.md
│   └── tasks/
│       └── task-3-1.md
├── es-kitchen-web-company/          ← có nếu E02 liên quan
│   ├── DESIGN.md
│   └── tasks/
│       └── task-3-2.md
└── es-kitchen-payment-app/          ← có nếu E01 Mobile liên quan
    ├── DESIGN.md
    └── tasks/
        └── task-3-3.md
```

---

## Phân công

| Role | Trách nhiệm |
|---|---|
| BA | Tạo **1 SPEC** — nghiệp vụ, actors, flow, AC. Không cần biết ranh giới repo. |
| Tech Lead | Đọc SPEC → xác định repo → tạo **DESIGN per repo** + tasks |
| PM | Tổng hợp → tạo **1 PLAN** với timeline cross-repo |
| Dev | Implement task của repo mình |

---

## Khi nào Mobile cần DESIGN riêng?

Flutter (`es-kitchen-payment-app`) cần subfolder + DESIGN.md khi SPEC có:
- Người dùng thao tác trên mobile app (E01)
- WebSocket event mới (socket_io)
- Push notification (Firebase)
- API endpoint mới mà Mobile gọi
