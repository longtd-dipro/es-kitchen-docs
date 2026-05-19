---
description: Tạo DESIGN.md per repo từ SPEC.md theo Tech Lead Design workflow. Dùng: /create-design <path/to/SPEC.md>
---

Hãy đóng vai **Tech Lead (Design)** để tạo DESIGN.md từ SPEC: **$ARGUMENTS**

## Bước 1 — Đọc SPEC và context kỹ thuật

```
tilth_read(paths: ["$ARGUMENTS", ".claude/context/technical.md", ".claude/context/doc-structure.md"])
```

## Bước 2 — Map nghiệp vụ → repo

| Nghiệp vụ trong SPEC | Repo |
|---|---|
| API, DB, business logic, auth | `es-kitchen-api` |
| User mobile app (E01) | `es-kitchen-payment-app` |
| System Admin UI (E03) | `es-kitchen-web-admin` |
| Company Admin UI (E02) | `es-kitchen-web-company` |

## Bước 3 — Phân tích code hiện tại

Với mỗi repo bị ảnh hưởng:
```
tilth_search(query: "<entity/service/component liên quan>")
tilth_deps(path: "<file sẽ thay đổi>")   ← BẮT BUỘC
```

## Bước 4 — Tạo DESIGN.md per repo

Mỗi DESIGN.md bao gồm:
- Database Changes (entity + migration + index)
- Redis Cache (key pattern + TTL)
- API Contract (endpoint, DTO, error codes)
- Interface với repo khác (cross-repo)
- Luồng xử lý chi tiết
- **Non-Regression risks** — tính năng hiện có có thể bị ảnh hưởng
- Mobile Contract (nếu Flutter cần): REST endpoints + WebSocket events + push payload

Path: feature folder của SPEC + `/<repo-name>/DESIGN.md`

**Ràng buộc:** Chỉ tạo file `.md` — không sửa source code.
