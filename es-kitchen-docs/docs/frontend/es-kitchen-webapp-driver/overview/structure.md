# es-kitchen-webapp-driver — Cấu trúc Source

> Repo: `es-kitchen-webapp-driver` · Epic: E06 Driver Web App
> Stack: React 19 / Vite 7 / **Zustand 5** / TanStack Query v5 / **shadcn/ui** / TailwindCSS v4

---

## Điểm khác biệt so với các web repo khác

| | `web-admin` / `web-company` / `web-supplier` | `webapp-driver` |
|---|---|---|
| State management | Redux Toolkit v2 | **Zustand 5** |
| UI Component library | Ant Design v6 | **shadcn/ui + Radix UI** |
| Login credential | email + password | **companyCode + password** |
| API prefix | `/admin/...` hoặc `/admin-company/...` | `/auth/...`, `/company/...` |
| Toast | AntD message | **sonner** |

> ⚠️ Không dùng `useSelector`/`useDispatch` ở repo này — dùng `useAuthStore` (Zustand) thay thế.

---

## Cấu trúc thư mục

```
es-kitchen-webapp-driver/
└── src/
    ├── pages/
    │   ├── auth/
    │   │   ├── LoginPage.tsx
    │   │   ├── ForgotPasswordPage.tsx
    │   │   ├── VerifyPage.tsx
    │   │   ├── ResetPasswordPage.tsx
    │   │   └── ResetSuccessPage.tsx
    │   └── dashboard/
    │       └── DashboardPage.tsx
    │
    ├── components/
    │   ├── Auth/
    │   │   ├── AuthBootstrap.tsx     ← Sync auth state on app start
    │   │   └── AuthCard.tsx
    │   ├── Common/
    │   │   ├── BaseAuthButton/
    │   │   ├── BaseAuthInput/
    │   │   ├── BaseAuthPasswordInput/
    │   │   ├── BaseLoading/
    │   │   └── BaseLoadingFullScreen/
    │   └── ui/                       ← shadcn/ui components
    │       ├── button.tsx
    │       ├── input.tsx
    │       ├── password-input.tsx
    │       ├── field.tsx
    │       ├── label.tsx
    │       ├── sonner.tsx            ← Toast provider
    │       └── spinner.tsx
    │
    ├── layouts/
    │   ├── AuthLayout.tsx            ← Sidebar + main area (sau login)
    │   ├── AuthCenteredLayout.tsx    ← Centered layout (reset success)
    │   └── NonAuthLayout.tsx         ← Public pages
    │
    ├── routes/
    │   ├── index.tsx                 ← createBrowserRouter
    │   └── guards/
    │       ├── RequireAuth.tsx
    │       └── PublicOnly.tsx
    │
    ├── stores/
    │   └── useAuthStore.ts           ← Zustand store (auth state)
    │
    ├── services/
    │   ├── client/
    │   │   ├── api.ts                ← Axios Requester singleton
    │   │   ├── auth.service.ts
    │   │   ├── file-upload.service.ts
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
    │   ├── useAuth.ts
    │   ├── useCan.ts
    │   ├── useDebouncedValue.ts
    │   ├── useInView.ts
    │   ├── useMutationCustom.ts
    │   ├── useTableParams.ts
    │   └── router.ts
    │
    ├── lib/
    │   └── utils.ts                  ← shadcn cn() utility
    │
    ├── constants/
    │   ├── route.ts
    │   ├── common.ts                 ← SESSION_STATUS enum
    │   ├── nav.ts
    │   ├── date.ts
    │   ├── errors.ts
    │   └── messages.ts
    │
    ├── models/
    │   ├── auth.ts
    │   ├── common.ts
    │   ├── file-upload.ts
    │   └── Response.ts
    │
    ├── enums/
    │   └── common.ts
    ├── types/
    ├── utils/
    ├── validation/
    │   └── schemas.ts
    ├── shared/
    ├── styles/
    │   └── global.css
    └── statics/
        ├── icons/
        └── images/
```

---

## Routes (pages hiện có)

| Route path | Page component | Ghi chú |
|---|---|---|
| `/login` | `LoginPage` | Public only — dùng `companyCode` + `password` |
| `/forgot-password` | `ForgotPasswordPage` | |
| `/verify` | `VerifyPage` | OTP verify |
| `/reset-password` | `ResetPasswordPage` | |
| `/reset-success` | `ResetSuccessPage` | AuthCenteredLayout |
| `/dashboard` | `DashboardPage` | **Default sau login** |

Default redirect: `/` → `/dashboard`
Fallback: `*` → `/login`

---

## Zustand Store

| Store | State | Actions |
|---|---|---|
| `useAuthStore` | `accessToken`, `refreshToken`, `status`, `user` | `setAuthTokens`, `setCurrentUser`, `clearAuthState`, `syncAuthStateFromCookies` |

Token lưu cookie thông qua `authToken.ts`. Khi 401: `clearAuthState()` → redirect `/login`.

---

## Scope hiện tại (May 2026)

- ✅ Auth flow (login, forgot password, OTP verify, reset password)
- ✅ Dashboard (scaffold)
- Các tính năng giao vận (nhận đơn, cập nhật trạng thái) chưa implement
