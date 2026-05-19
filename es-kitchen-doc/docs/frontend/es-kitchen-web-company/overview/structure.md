# es-kitchen-web-company — Cấu trúc Source

> Repo: `es-kitchen-web-company` · Epic: E02 Company Admin · 58 functions
> Stack: React 19 / Vite 7 / RTK v2 / TanStack Query v5 / Ant Design v6

---

## Phân biệt với `es-kitchen-web-admin`

| | `es-kitchen-web-admin` | `es-kitchen-web-company` |
|---|---|---|
| Epic | E03 System Admin | E02 Company Admin |
| Người dùng | Internal system admin | Company staff |
| Functions | 160 | 58 |
| Default route | `/dashboard` | `/sales-management` |
| Pages hiện có | 8 page groups | 3 page groups |

> ⚠️ Hai repo dùng chung stack nhưng **nghiệp vụ hoàn toàn khác nhau**. Không nhầm lẫn.

---

## Cấu trúc thư mục

```
es-kitchen-web-company/
└── src/
    ├── pages/                    ← Feature pages (ít hơn web-admin)
    │   ├── auth/                 ← Login, ForgotPassword, Verify, ResetPassword
    │   ├── account-management/   ← Quản lý user trong company
    │   │   └── user/
    │   │       └── [userId]/
    │   └── sales-management/     ← Xem doanh thu, lịch sử mua hàng
    │       └── user-purchase-history/[purchaseNumber]/
    │
    ├── components/
    │   ├── Auth/
    │   └── Common/
    │
    ├── layouts/
    │   ├── AuthLayout.tsx
    │   ├── AuthCenteredLayout.tsx
    │   └── NonAuthLayout.tsx
    │
    ├── routes/
    │   ├── index.tsx             ← createBrowserRouter
    │   └── guards/
    │       ├── RequireAuth.tsx
    │       └── PublicOnly.tsx
    │
    ├── stores/
    │   └── reducers/
    │       └── auth.ts           ← Auth state (same pattern as web-admin)
    │
    ├── services/
    │   ├── client/
    │   │   ├── api.ts            ← Axios Requester (identical to web-admin)
    │   │   ├── auth.service.ts
    │   │   ├── account.service.ts
    │   │   ├── sales.service.ts
    │   │   ├── user.service.ts
    │   │   └── error-report.service.ts
    │   ├── http/
    │   │   ├── axios.instance.ts
    │   │   ├── authToken.ts
    │   │   ├── handleRequest.ts
    │   │   ├── handleResponse.ts
    │   │   └── index.ts
    │   └── query/
    │       ├── queryClient.ts
    │       ├── baseQuery.ts
    │       └── index.ts
    │
    ├── hooks/
    ├── models/
    ├── constants/
    ├── enums/
    ├── types/
    ├── utils/
    │   ├── client/
    │   └── menu/
    ├── validation/
    │   └── schemas.ts
    ├── shared/
    │   ├── providers/
    │   │   └── AntdProvider.tsx
    │   └── theme/
    └── statics/
        ├── icons/
        └── images/
```

---

## Routes (pages hiện có)

| Route path | Page component | Ghi chú |
|---|---|---|
| `/login` | `LoginPage` | Public only |
| `/forgot-password` | `ForgotPasswordPage` | |
| `/verify` | `VerifyCodePage` | OTP verify |
| `/reset-password` | `ResetPasswordPage` | |
| `/account-management` | `AccountManagementPage` | Quản lý users của company |
| `/account-management/user/:userId` | `UserAccountDetailPage` | |
| `/sales-management` | `SalesManagementPage` | **Default sau login** |
| `/sales-management/user-purchase-history/:purchaseNumber` | `UserPurchaseHistoryPage` | |

Default redirect: `/` → `/sales-management` (khác với web-admin → `/dashboard`)

---

## Redux Store

| Slice | State |
|---|---|
| `auth` | `accessToken`, `refreshToken`, `user`, `status` |

Cùng pattern với web-admin — token lưu cookie, 401 → `clearAuthState()` → logout.

---

## API Service Layer

Cùng pattern với `es-kitchen-web-admin`:
- `services/client/api.ts` — Axios `Requester` singleton
- Service files gọi `API.get/post/put/patch/delete`
- Pages dùng TanStack Query wrap service calls

```typescript
// Ví dụ
const { data } = useQuery({
  queryKey: ['sales', filters],
  queryFn: () => salesService.getSales(filters),
});
```

---

## Scope hiện tại (May 2026)

Các pages đang có trong repo:
- ✅ Auth (login, forgot password, OTP)
- ✅ Account Management (user listing + detail)
- ✅ Sales Management (user sales, purchase history, refund)

Các pages **chưa có** (sẽ thêm trong Phase 2):
- Menu management (Company Admin tạo menu)
- Contract management (xem hợp đồng)
- Marketing / Referral bonus
- Company profile settings
