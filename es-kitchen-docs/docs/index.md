# ESKITCHEN Documentation

Tài liệu kỹ thuật và nghiệp vụ cho dự án **ESKITCHEN Phase 2** — hệ thống quản lý bếp doanh nghiệp cho client Nhật Bản.

## Hệ sinh thái

| Repo | Epic | Vai trò | Stack |
|---|---|---|---|
| `es-kitchen-api` | — | Core API, Business Logic, PostgreSQL | NestJS / TypeScript |
| `es-kitchen-payment-app` | E01 | User Mobile App (iOS + Android) | Flutter / Riverpod |
| `es-kitchen-web-admin` | E03 | System Admin Web (160 functions) | React 19 / Vite 7 |
| `es-kitchen-web-company` | E02 | Company Admin Web (58 functions) | React 19 / Vite 7 |
| `es-kitchen-web-supplier` | E04 | Supplier Web | React 19 / Vite 7 |

## BMAD Workflow

| Bước | Command | Output | Role |
|---|---|---|---|
| 1 | `/create-spec <feature>` | `SPEC.md` | BA |
| 2 | `/create-design <SPEC.md>` | `DESIGN.md` per repo | Tech Lead |
| 3 | `/create-tasks <feature/>` | `tasks/task-*.md` | Tech Lead |
| 4 | `/create-plan <feature/>` | `PLAN.md` | PM |
| 5 | Implement task | Working code | Dev |
| 6 | QA Verify | QA Report | QA |

## Cấu trúc tài liệu

```
docs/
├── backend/
│   └── es-kitchen-api/overview/    ← ERD, API catalog, patterns
├── frontend/
│   ├── es-kitchen-web-admin/       ← E03 patterns & structure
│   └── es-kitchen-web-company/     ← E02 patterns & structure
├── mobile/
│   └── es-kitchen-payment-app/     ← E01 structure
├── epics/
│   ├── E03/details/<feature>/      ← System Admin features
│   ├── E04/details/<feature>/      ← Supplier features
│   ├── E05/details/<feature>/      ← Contract/Delivery features
│   └── E06/details/<feature>/      ← Driver features
└── features/
    └── <feature>/                  ← Cross-repo features
        └── <repo>/DESIGN.md
```
