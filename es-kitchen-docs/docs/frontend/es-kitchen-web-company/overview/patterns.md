# es-kitchen-web-company — Patterns & Conventions

> Đọc file này trước khi viết code React mới cho E02. Cùng stack với web-admin nhưng scope nghiệp vụ khác.
> Tham chiếu thêm: `es-kitchen-web-admin/overview/patterns.md` — các pattern cốt lõi giống nhau.

---

## Điểm khác biệt so với web-admin

| | `es-kitchen-web-admin` (E03) | `es-kitchen-web-company` (E02) |
|---|---|---|
| API prefix | `/admin/...` | `/admin-company/...` |
| Default route | `/dashboard` | `/sales-management` |
| RTK slices | `auth`, `monthlyMenuImport`, `counter` | `auth` only |
| Service files | 13 files | 5 files |
| Pages hiện có | 8 groups | 3 groups |

> ⚠️ Không copy endpoint từ web-admin sang — prefix khác nhau hoàn toàn.

---

## HTTP Client Pattern

**Giống hệt web-admin** — cùng `Requester` class, cùng interceptor pattern.

```typescript
// services/client/api.ts — identical to web-admin
const API = new Requester();  // singleton
export default API;
```

Điểm khác biệt duy nhất: `baseURL` trỏ cùng server nhưng endpoint prefix là `/admin-company/...`

---

## Service Layer

Chỉ có 5 service files — scope nhỏ hơn web-admin:

```typescript
// services/client/auth.service.ts
export const authService = {
  login: (data: LoginDto) =>
    API.post('/admin-company/auth/login', data, { disabledToken: true }),

  logout: () => API.post('/admin-company/auth/logout'),

  getMe: () => API.get('/admin-company/auth/me'),
};

// services/client/account.service.ts
export const accountService = {
  getUsers: (params: GetUsersParams) =>
    API.get('/admin-company/users', params),

  getUserDetail: (userId: string) =>
    API.get(`/admin-company/users/${userId}`),
};

// services/client/sales.service.ts
export const salesService = {
  getSales: (params: GetSalesParams) =>
    API.get('/admin-company/orders', params),

  getUserPurchaseHistory: (purchaseNumber: string) =>
    API.get(`/admin-company/orders/${purchaseNumber}`),

  refundOrder: (orderId: string) =>
    API.post(`/admin-company/orders/${orderId}/refund`),
};
```

---

## TanStack Query Pattern (v5)

Cùng pattern với web-admin:

```typescript
// ✅ v5 syntax
const { data } = useQuery({
  queryKey: ['users', filters],
  queryFn: () => accountService.getUsers(filters),
});

const { mutate: refund } = useMutation({
  mutationFn: (orderId: string) => salesService.refundOrder(orderId),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['sales'] });
  },
});
```

---

## Redux Store

Chỉ có 1 slice: `auth`. Không có `monthlyMenuImport` hay `counter` như web-admin.

```typescript
// stores/reducers/auth.ts — same pattern as web-admin
// setAuthTokens / setCurrentUser / clearAuthState

// Selectors
export const selectCurrentUser = (state: { auth: AuthState }) => state.auth.user;
export const selectIsAuthenticated = (state: { auth: AuthState }) =>
  state.auth.status === SESSION_STATUS.AUTHENTICATED;
```

Khi thêm state mới: tạo slice mới trong `stores/reducers/` — không nhét vào `auth` slice.

---

## Auth Flow

Giống web-admin, nhưng gọi endpoint `/admin-company/auth/`:

```
App khởi động → bootstrapAuthStateFromCookies()
Login → POST /admin-company/auth/login
  → setAuthTokens() → cookies + Redux
401 → clearAuthState() → redirect /login
```

---

## Routing Pattern

```typescript
// routes/index.tsx
export const router = createBrowserRouter([
  {
    element: <PublicOnly />,
    children: [
      { path: ROUTE.LOGIN, element: withSuspense(<LoginPage />) },
      // ... other auth pages
    ],
  },
  {
    element: <RequireAuth />,
    children: [
      {
        element: <AuthLayout />,
        children: [
          // ← Default redirect: / → /sales-management (khác web-admin → /dashboard)
          { index: true, element: <Navigate to={ROUTE.SALES_MANAGEMENT} replace /> },
          { path: ROUTE.ACCOUNT_MANAGEMENT, element: withSuspense(<AccountManagementPage />) },
          { path: ROUTE.SALES_MANAGEMENT, element: withSuspense(<SalesManagementPage />) },
        ],
      },
    ],
  },
]);
```

---

## Page Structure Pattern

Cùng pattern với web-admin:

```
pages/<domain>/
├── page.tsx                    ← Entry point
├── components/
│   ├── <Feature>/
│   │   ├── <Feature>Tab.tsx
│   │   ├── FormSearch.tsx
│   │   └── renderers.tsx       ← Table cell renderers
└── [id] hoặc [purchaseNumber]/
    └── page.tsx
```

Ví dụ thực tế:
```
pages/sales-management/
├── page.tsx
├── components/
│   └── UserSales/
│       ├── UserSalesTab.tsx
│       ├── FormSearch.tsx
│       ├── UserSaleSummary.tsx
│       ├── RefundConfirmModal.tsx
│       └── renderers.tsx
└── user-purchase-history/[purchaseNumber]/
    └── page.tsx
```

---

## Form Pattern

```typescript
// validation/schemas.ts — yup schemas
export const loginSchema = yup.object({
  email: yup.string().email().required(),
  password: yup.string().min(8).required(),
});

// Trong component
const { register, handleSubmit, formState: { errors } } = useForm({
  resolver: yupResolver(loginSchema),
});
```

---

## Thêm page mới — Checklist

Khi thêm feature page mới vào web-company:

- [ ] Tạo folder trong `src/pages/<domain>/`
- [ ] Thêm lazy import trong `routes/index.tsx`
- [ ] Thêm route path vào `createBrowserRouter`
- [ ] Thêm constant vào `constants/route.ts`
- [ ] Thêm service file trong `services/client/<domain>.service.ts` nếu cần
- [ ] API endpoint prefix phải là `/admin-company/...` — không dùng `/admin/...`
- [ ] Nếu cần state phức tạp: tạo RTK slice mới trong `stores/reducers/`
