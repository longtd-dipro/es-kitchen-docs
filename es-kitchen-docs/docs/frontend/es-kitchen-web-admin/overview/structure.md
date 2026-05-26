# es-kitchen-web-admin — Cấu trúc Source

> Repo: `es-kitchen-web-admin` · Epic: E03 System Admin · 160 functions
> Stack: React 19 / Vite 7 / RTK v2 / TanStack Query v5 / Ant Design v6

---

## Cấu trúc thư mục

```
es-kitchen-web-admin/
└── src/
    ├── pages/                    ← Feature pages (file-system routing)
    │   ├── auth/                 ← Login, ForgotPassword, Verify, ResetPassword
    │   ├── dashboard/
    │   ├── account-management/   ← Operation + User accounts
    │   │   ├── operation/
    │   │   │   ├── create/
    │   │   │   └── [userId]/
    │   │   └── user/
    │   │       └── [userId]/
    │   ├── company-management/   ← Company CRUD + import CSV
    │   │   ├── import-csv/
    │   │   └── [id]/
    │   ├── contract-management/  ← Contract CRUD
    │   │   └── [id]/
    │   │       └── components/tabs/   ← pricing-payment, equipment-configuration
    │   ├── master-management/    ← Product master
    │   │   └── product/
    │   │       ├── import-product-csv/
    │   │       └── [id]/
    │   ├── menu-management/      ← Monthly menu
    │   │   └── monthly/
    │   │       ├── create-menu/
    │   │       └── [id]/
    │   └── sales-management/     ← Sales analytics + purchase history
    │       ├── favorite/
    │       └── user-purchase-history/[purchaseNumber]/
    │
    ├── components/               ← Shared UI components
    │   ├── Auth/
    │   ├── Common/               ← BaseLoading, shared elements
    │   ├── Counter/
    │   └── EquipmentConfiguration/
    │
    ├── layouts/                  ← 3 layout wrappers
    │   ├── AuthLayout.tsx        ← Sidebar + header (authenticated)
    │   ├── AuthCenteredLayout.tsx ← Centered (reset success)
    │   └── NonAuthLayout.tsx     ← Login pages
    │
    ├── routes/
    │   ├── index.tsx             ← createBrowserRouter — tất cả routes
    │   └── guards/
    │       ├── RequireAuth.tsx   ← Redirect login nếu chưa auth
    │       └── PublicOnly.tsx    ← Redirect dashboard nếu đã auth
    │
    ├── stores/
    │   └── reducers/
    │       ├── auth.ts           ← Auth state (tokens + user)
    │       ├── monthlyMenuImport.ts
    │       └── counter.ts
    │
    ├── services/
    │   ├── client/               ← API service files (1 file per domain)
    │   │   ├── api.ts            ← Axios Requester singleton
    │   │   ├── auth.service.ts
    │   │   ├── account.service.ts
    │   │   ├── company.service.ts
    │   │   ├── contract.service.ts
    │   │   ├── menu.service.ts
    │   │   ├── product.service.ts
    │   │   ├── category.service.ts
    │   │   ├── sales.service.ts
    │   │   ├── dashboard.service.ts
    │   │   ├── favorite.service.ts
    │   │   ├── file-upload.service.ts
    │   │   └── user.service.ts
    │   ├── http/                 ← Axios instance + interceptors + token helpers
    │   │   ├── axios.instance.ts
    │   │   ├── authToken.ts      ← Cookie read/write
    │   │   ├── handleRequest.ts
    │   │   └── handleResponse.ts
    │   └── query/                ← TanStack Query setup
    │       ├── queryClient.ts
    │       ├── baseQuery.ts
    │       └── index.ts
    │
    ├── hooks/                    ← Custom React hooks
    ├── models/                   ← TypeScript interfaces/types
    ├── constants/                ← ROUTE constants, common constants
    ├── enums/
    ├── types/
    ├── utils/
    │   ├── client/
    │   └── menu/
    ├── validation/
    │   └── schemas.ts            ← yup schemas
    ├── statics/
    │   ├── fonts/
    │   ├── icons/
    │   └── images/
    └── styles/
```

---

## Routes (pages hiện có)

| Route path | Page component | Ghi chú |
|---|---|---|
| `/login` | `LoginPage` | Public only |
| `/forgot-password` | `ForgotPasswordPage` | Public only |
| `/verify` | `VerifyCodePage` | OTP verify |
| `/reset-password` | `ResetPasswordPage` | |
| `/dashboard` | `DashboardPage` | Default sau login |
| `/account-management` | `AccountManagementPage` | |
| `/account-management/operation/create` | `OperationAccountCreatePage` | |
| `/account-management/operation/:userId` | `OperationAccountDetailPage` | |
| `/account-management/user/:userId` | `UserAccountDetailPage` | |
| `/company-management` | `CompanyManagementPage` | |
| `/company-management/import-csv` | `CompanyImportCsvPage` | |
| `/company-management/:id` | `CompanyDetailPage` | |
| `/contract-management` | `ContractManagementPage` | |
| `/contract-management/:id` | `ContractDetailPage` | |
| `/master-management/product` | `ProductManagementPage` | |
| `/master-management/product/import-csv` | `ProductImportCsvPage` | |
| `/master-management/product/:id` | `ProductDetailPage` | |
| `/menu-management/monthly` | `MonthlyMenuPage` | |
| `/menu-management/monthly/create-menu` | `MonthlyMenuCreatePage` | |
| `/menu-management/monthly/:id` | `MonthlyMenuDetailPage` | |
| `/sales-management` | `SalesManagementPage` | |
| `/sales-management/favorite` | `SalesFavoritePage` | |
| `/sales-management/user-purchase-history/:purchaseNumber` | `UserPurchaseHistoryPage` | |

---

## Redux Store (RTK v2)

| Slice | File | State |
|---|---|---|
| `auth` | `stores/reducers/auth.ts` | `accessToken`, `refreshToken`, `user`, `status` |
| `monthlyMenuImport` | `stores/reducers/monthlyMenuImport.ts` | Import state |
| `counter` | `stores/reducers/counter.ts` | Demo/dev only |

Auth state flow:
```
App start → read cookies → bootstrapAuthStateFromCookies()
Login → setAuthTokens(tokens) → cookies + Redux
401 response → clearAuthState() → redirect /login
```

---

## API Service Layer

```
services/client/api.ts       ← Axios Requester class (singleton API)
services/client/*.service.ts ← Domain service gọi API.get/post/put/patch/delete
```

Các service file gọi trực tiếp `API.get(url, params)` — không dùng hook trong service.

TanStack Query wrap service calls trong pages/hooks:
```typescript
const { data } = useQuery({
  queryKey: ['companies', params],
  queryFn: () => companyService.getCompanies(params),
});
```
