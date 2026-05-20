# es-kitchen-webapp-driver — Patterns & Conventions

> Đọc file này trước khi viết code React cho E06 Driver Web App.
> Stack khác với các web repo khác: **Zustand** thay RTK, **shadcn/ui** thay Ant Design.

---

## State Management — Zustand (không phải Redux)

```typescript
// stores/useAuthStore.ts
export const useAuthStore = create<AuthState & AuthActions>(set => ({
  accessToken: null,
  refreshToken: null,
  status: SESSION_STATUS.UNAUTHENTICATED,
  user: null,

  setAuthTokens({ accessToken, refreshToken }) {
    setAuthCookies({ accessToken, refreshToken });
    set({ accessToken, refreshToken, user: null, status: SESSION_STATUS.LOADING });
  },

  setCurrentUser(user) {
    set({ user, status: SESSION_STATUS.AUTHENTICATED });
  },

  clearAuthState() {
    clearAuthCookies();
    set({ accessToken: null, refreshToken: null, user: null, status: SESSION_STATUS.UNAUTHENTICATED });
  },
}));

// Dùng trong component
const { user, setCurrentUser, clearAuthState } = useAuthStore();
```

> ⚠️ Không import `useSelector`, `useDispatch`, hay bất kỳ RTK API nào ở repo này.

Khi thêm state mới: tạo Zustand store mới, không nhét vào `useAuthStore`.

---

## UI Components — shadcn/ui

Repo này dùng **shadcn/ui** thay Ant Design. Components nằm trong `src/components/ui/`.

```typescript
// ✅ Dùng shadcn components
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PasswordInput } from "@/components/ui/password-input";

// ❌ Không import từ antd
import { Button } from "antd"; // SAI — antd không có trong repo này
```

Thêm component shadcn mới: `npx shadcn@latest add <component-name>`

---

## HTTP Client Pattern

Cùng `Requester` pattern với các web repo khác:

```typescript
// services/client/api.ts
const API = new Requester();
export default API;
```

API prefix của driver **không có prefix** như `/admin/` hay `/admin-company/`:

```typescript
// services/client/auth.service.ts
const APIs = {
  SIGNIN: "/auth/login",           // không có /admin/ prefix
  ME: "/company/me",
  LOGOUT: "/auth/logout",
  FORGOT_PASSWORD: "/auth/forgot-password/request",
  VERIFY_FORGOT_PASSWORD_OTP: "/auth/forgot-password/verify-otp",
  RESET_PASSWORD: "/auth/forgot-password/confirm",
};
```

Login dùng `companyCode` + `password` (không phải `email`):

```typescript
export const signIn = async (values: {
  companyCode: string;
  password: string;
}): Promise<IBaseApiResponse<AdminLoginResponse>> => {
  return API.post(APIs.SIGNIN, values);
};
```

---

## TanStack Query Pattern (v5)

Cùng object syntax với các repo khác:

```typescript
// ✅ v5 syntax
const { data } = useQuery({
  queryKey: ['driver-orders', filters],
  queryFn: () => driverService.getOrders(filters),
});

const { mutate } = useMutation({
  mutationFn: (orderId: string) => driverService.updateOrderStatus(orderId),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['driver-orders'] });
  },
});
```

---

## Toast — sonner (không phải AntD message)

```typescript
import { toast } from "sonner";

// ✅ Dùng sonner
toast.success("Cập nhật thành công");
toast.error("Đã có lỗi xảy ra");

// ❌ Không dùng
import { message } from "antd"; // SAI
```

`<Toaster />` đã được mount tại root qua `components/ui/sonner.tsx`.

---

## shadcn cn() Utility

```typescript
import { cn } from "@/lib/utils";

// Kết hợp class có điều kiện
<div className={cn("base-class", isActive && "active-class", className)} />
```

---

## Auth Flow

```
App khởi động → AuthBootstrap.tsx → syncAuthStateFromCookies()
Login → POST /auth/login (companyCode + password)
  → setAuthTokens() → cookies + Zustand store
  → fetchCurrentAdmin() → setCurrentUser()
  → redirect /dashboard
401 → clearAuthState() → redirect /login
```

---

## Routing Pattern

```typescript
// routes/index.tsx
export const router = createBrowserRouter([
  {
    element: <PublicOnly />,        // redirect → /dashboard nếu đã auth
    children: [
      { path: ROUTE.LOGIN, element: <LoginPage /> },
      { path: ROUTE.FORGOT_PASSWORD, element: <ForgotPasswordPage /> },
      // ...
    ],
  },
  {
    element: <RequireAuth />,       // redirect → /login nếu chưa auth
    children: [
      {
        element: <AuthLayout />,
        children: [
          { index: true, element: <Navigate to={ROUTE.DASHBOARD} replace /> },
          { path: ROUTE.DASHBOARD, element: withSuspense(<DashboardPage />) },
        ],
      },
    ],
  },
  { path: "*", element: <Navigate to={ROUTE.LOGIN} replace /> },
]);
```

---

## Thêm page mới — Checklist

- [ ] Tạo folder trong `src/pages/<domain>/`
- [ ] Thêm lazy import + route vào `routes/index.tsx`
- [ ] Thêm route path vào `constants/route.ts`
- [ ] Thêm service file `services/client/<domain>.service.ts` nếu cần API mới
- [ ] API endpoint **không có prefix** `/admin/` — xác nhận với BE trước khi code
- [ ] Dùng shadcn/ui components — không import từ `antd`
- [ ] State mới → Zustand store mới trong `stores/` — không nhét vào `useAuthStore`
- [ ] Toast → `sonner`, không dùng `antd message`
