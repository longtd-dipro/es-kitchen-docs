# DESIGN: Supplier Authentication — es-kitchen-web-supplier

> **Epic:** E04 — Supplier Web
> **SPEC:** `../SPEC.md`
> **API DESIGN:** `../es-kitchen-api/DESIGN.md`
> **Date:** 19/05/2026
> **Status:** Draft
> **Author:** Tech Lead

---

## 1. Tổng quan kỹ thuật

`es-kitchen-web-supplier` đã có scaffold với React 19 / Vite / Redux Toolkit / TanStack Query v5 / react-hook-form + yup — nhất quán với `es-kitchen-web-admin` và `es-kitchen-web-company`.

Supplier login bằng **email + password** (không có `companyCode` như E02/E03). Forgot password dùng **reset link token qua URL** (không phải OTP 4 số). Đây là điểm khác biệt chính so với flow hiện tại trong `es-kitchen-web-supplier` (hiện tại đang scaffold theo flow E02).

**Thay đổi cần thực hiện:**
- Sửa `LoginPage` — bỏ field `companyCode`, chỉ còn `email` + `password`
- Xóa `VerifyPage` (OTP flow) — thay bằng `ResetPasswordPage` truy cập qua token trong URL
- Sửa `ForgotPasswordPage` — bỏ field `companyCode`, chỉ còn `email`
- Thêm `ChangePasswordPage` — trang mới cho Supplier đã đăng nhập
- Cập nhật `auth.service.ts`, `validation/schemas.ts`, `routes/index.tsx`

**Lưu ý quan trọng:** Codebase hiện tại của `es-kitchen-web-supplier` được scaffold từ template E02 (có `companyCode`, OTP flow). Task này cần điều chỉnh lại để match đúng SPEC E04.

---

## 2. Routes

```
/login                         (public) — LoginPage
/forgot-password               (public) — ForgotPasswordPage
/reset-password                (public) — ResetPasswordPage (?token=<hex_token> trong query)
/change-password               (protected) — ChangePasswordPage
/dashboard                     (protected) — DashboardPage (existing)
```

### Route config (`src/routes/index.tsx`)

```typescript
// Public routes (PublicOnly guard)
{ path: ROUTE.LOGIN,            element: <LoginPage /> }
{ path: ROUTE.FORGOT_PASSWORD,  element: <ForgotPasswordPage /> }
{ path: ROUTE.RESET_PASSWORD,   element: <ResetPasswordPage /> }  // ?token=<token>

// Protected routes (RequireAuth guard)
{ path: ROUTE.CHANGE_PASSWORD,  element: <ChangePasswordPage /> }
{ path: ROUTE.DASHBOARD,        element: <DashboardPage /> }
```

### `src/constants/route.ts` — thêm constant

```typescript
export const ROUTE = {
  LOGIN: '/login',
  FORGOT_PASSWORD: '/forgot-password',
  RESET_PASSWORD: '/reset-password',
  CHANGE_PASSWORD: '/change-password',
  DASHBOARD: '/dashboard',
  INDEX: '/',
};
```

---

## 3. API Calls (TanStack Query v5)

File: `src/services/client/auth.service.ts`

```typescript
const APIs = {
  SIGNIN:           '/supplier/auth/login',
  LOGOUT:           '/supplier/auth/logout',
  FORGOT_PASSWORD:  '/supplier/auth/forgot-password',
  RESET_PASSWORD:   '/supplier/auth/reset-password',
  CHANGE_PASSWORD:  '/supplier/auth/change-password',
};
```

**Lưu ý:** Tất cả request đến `es-kitchen-api` đều đi qua `/supplier/auth/...` prefix (thay đổi từ `/auth/...` hiện tại).

### Models (`src/models/auth.ts`)

```typescript
// Request models
export interface ILoginRequestData {
  email: string;
  password: string;
}

export interface IForgotPasswordRequestData {
  email: string;
}

export interface IResetPasswordRequestData {
  token: string;
  newPassword: string;
  confirmPassword: string;
}

export interface IChangePasswordRequestData {
  currentPassword: string;
  newPassword: string;
  confirmPassword: string;
}

// Response models
export interface IAuthTokens {
  accessToken: string;
  refreshToken: string;
}
```

### Mutation hooks (dùng `useMutationCustom` đã có)

```typescript
// Login
const loginMutation = useMutationCustom({ mutationFn: signIn, ... });

// Forgot password
const forgotPasswordMutation = useMutationCustom({ mutationFn: forgotPassword, ... });

// Reset password
const resetPasswordMutation = useMutationCustom({ mutationFn: resetPassword, ... });

// Change password (protected — cần token trong header, axios interceptor tự thêm)
const changePasswordMutation = useMutationCustom({ mutationFn: changePassword, ... });
```

---

## 4. Validation Schemas (`src/validation/schemas.ts`)

```typescript
export const signInSchema = yup.object().shape({
  email: yup
    .string()
    .email('有効なメールアドレスを入力してください。')
    .required('メールアドレスは必須項目です。'),
  password: yup.string().required('パスワードは必須項目です。'),
});

export const forgotPasswordSchema = yup.object().shape({
  email: yup
    .string()
    .email('有効なメールアドレスを入力してください。')
    .required('メールアドレスは必須項目です。'),
});

export const resetPasswordSchema = yup.object().shape({
  newPassword: yup
    .string()
    .required('パスワードは必須項目です。')
    .min(8, '8文字以上で入力してください。')
    .matches(
      /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$/,
      '大文字・小文字・数字をそれぞれ1文字以上含めてください。',
    ),
  confirmPassword: yup
    .string()
    .required('確認用パスワードは必須項目です。')
    .oneOf([yup.ref('newPassword')], 'パスワードが一致しません。'),
});

export const changePasswordSchema = yup.object().shape({
  currentPassword: yup.string().required('現在のパスワードは必須項目です。'),
  newPassword: yup
    .string()
    .required('新しいパスワードは必須項目です。')
    .min(8, '8文字以上で入力してください。')
    .matches(
      /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$/,
      '大文字・小文字・数字をそれぞれ1文字以上含めてください。',
    ),
  confirmPassword: yup
    .string()
    .required('確認用パスワードは必須項目です。')
    .oneOf([yup.ref('newPassword')], 'パスワードが一致しません。'),
});
```

---

## 5. Pages

### 5.1 `LoginPage` (`src/pages/auth/LoginPage.tsx`)

**Mô tả:** Form đăng nhập với 2 field — `email` và `password`.

**Thay đổi so với scaffold hiện tại:** Bỏ field `companyCode`, đổi field `companyCode` thành `email`.

**Components:**
- `AuthCard` (title: "ログイン")
- `Controller` + `BaseInput` — field `email` (type email, label "メールアドレス")
- `Controller` + `BaseInputPassword` — field `password` (label "パスワード")
- `BaseButtonAuth` (label "ログイン", loading state)
- Link đến `/forgot-password` ("パスワードを忘れた方はこちら")

**Form schema:** `signInSchema` (email + password)

**Submit flow:**
1. `signInService({ email, password })`
2. Thành công: `dispatch(setAuthTokens({ accessToken, refreshToken }))` → redirect đến `ROUTE.DASHBOARD`
3. Thất bại: `toast.error(error.response?.data?.message || MESSAGES.LOGIN_FAILED)`

**UI Notes:**
- Hiển thị error message từ API response — message chung "メールアドレスまたはパスワードが正しくありません。" cho cả email sai và password sai (chống enumeration — BR-02)
- Không phân biệt "tài khoản không tồn tại" vs "password sai" trong UI
- Nếu tài khoản Disabled: server trả message riêng → hiển thị đúng message đó

---

### 5.2 `ForgotPasswordPage` (`src/pages/auth/ForgotPasswordPage.tsx`)

**Mô tả:** Form nhập email để nhận reset link.

**Thay đổi so với scaffold hiện tại:** Bỏ field `companyCode`. Sau khi submit thành công, không redirect sang VerifyPage — chuyển sang trang thông báo thành công.

**Components:**
- `AuthCard` (title: "パスワード再設定", subtitle: "登録済みのメールアドレスを入力してください。")
- `Controller` + `BaseInput` — field `email` (type email, label "メールアドレス")
- `BaseButtonAuth` (label "再設定リンクを送信", loading state)
- Link quay lại `/login` ("ログインに戻る")

**Form schema:** `forgotPasswordSchema` (email only)

**Submit flow:**
1. `forgotPasswordMutation.mutateAsync({ email })`
2. Thành công (API luôn trả 200 — BR-05): chuyển sang trạng thái "success" trong cùng trang hoặc redirect sang trang confirmation riêng
3. Thất bại (network error): `toast.error(...)`

**UI Notes:**
- Sau khi submit, hiển thị thông báo "パスワード再設定の手順をメールでお送りしました。" bất kể email có tồn tại hay không (BR-05, chống enumeration)
- Không tiết lộ email có trong hệ thống hay không

**Success state (inline trong cùng trang):**
```
[Icon mail]
パスワード再設定のメールを送信しました。
メールに記載のリンクからパスワードを再設定してください。
リンクの有効期限は24時間です。

[ログインに戻る] ← Link to /login
```

---

### 5.3 `ResetPasswordPage` (`src/pages/auth/ResetPasswordPage.tsx`)

**Mô tả:** Form đặt mật khẩu mới. Token lấy từ query param `?token=<hex>` trong URL.

**Thay đổi so với scaffold hiện tại:** Bỏ flow OTP. Lấy token từ `useSearchParams()` thay vì Redux state.

**Components:**
- `AuthCard` (title: "新しいパスワードを設定")
- `Controller` + `BaseInputPassword` — field `newPassword` (label "新しいパスワード")
- `Controller` + `BaseInputPassword` — field `confirmPassword` (label "新しいパスワード（確認）")
- `BaseButtonAuth` (label "パスワードを設定する", loading state)
- Password requirements hint: "8文字以上、大文字・小文字・数字を含む"

**Form schema:** `resetPasswordSchema`

**Mount flow:**
1. Lấy `token` từ `useSearchParams().get('token')`
2. Nếu `token` không tồn tại hoặc rỗng → redirect về `/forgot-password`

**Submit flow:**
1. `resetPasswordMutation.mutateAsync({ token, newPassword, confirmPassword })`
2. Thành công: redirect đến `/login` với query `?reset=success` (LoginPage hiển thị toast success)
3. Thất bại 400 "expired": hiển thị error state với link quay lại `/forgot-password`
4. Thất bại 400 "invalid/used": hiển thị error state với link quay lại `/forgot-password`
5. Thất bại khác: `toast.error(...)`

**Error states (inline):**

Token hết hạn:
```
リンクの有効期限が切れました。
再度パスワード再設定をリクエストしてください。
[パスワード再設定ページへ] ← Link to /forgot-password
```

Token không hợp lệ / đã dùng:
```
リンクが無効または使用済みです。
新たにパスワード再設定をリクエストしてください。
[パスワード再設定ページへ] ← Link to /forgot-password
```

**UI Notes:**
- Validate token lỗi phải show state rõ ràng, không chỉ toast
- Form field validation xảy ra client-side trước khi gửi API

---

### 5.4 `ChangePasswordPage` (`src/pages/change-password/ChangePasswordPage.tsx`)

**Mô tả:** Trang đổi mật khẩu cho Supplier đã đăng nhập. Route protected.

**Location:** `src/pages/change-password/ChangePasswordPage.tsx` (trang riêng, không phải modal)

**Components:**
- Page heading / breadcrumb (nếu layout có)
- Form card:
  - `Controller` + `BaseInputPassword` — field `currentPassword` (label "現在のパスワード")
  - `Controller` + `BaseInputPassword` — field `newPassword` (label "新しいパスワード")
  - `Controller` + `BaseInputPassword` — field `confirmPassword` (label "新しいパスワード（確認）")
  - Password requirements hint dưới `newPassword`: "8文字以上、大文字・小文字・数字を含む"
  - Button "変更する" (loading state)
  - Button "キャンセル" → navigate(-1)

**Form schema:** `changePasswordSchema`

**Submit flow:**
1. `changePasswordMutation.mutateAsync({ currentPassword, newPassword, confirmPassword })`
2. Thành công: `toast.success('パスワードを変更しました。')` → reset form
3. Thất bại 400 "current password wrong": set field error trên `currentPassword` hoặc toast.error
4. Thất bại 400 "same password": set field error trên `newPassword`
5. Thất bại khác: `toast.error(...)`

**UI Notes:**
- Sau khi thành công, **không** redirect về login — phiên vẫn tiếp tục (AC-10)
- Form reset về trạng thái empty sau khi thành công
- Nếu `currentPassword` sai, chỉ hiển thị lỗi ở field đó — không lộ thông tin khác

---

### 5.5 `LoginPage` — Session expired banner

Khi Supplier bị redirect về `/login` do session hết hạn (AC-05):
- Axios interceptor detect `401` response → dispatch `clearAuthState()` → redirect `?expired=true`
- `LoginPage` kiểm tra `useSearchParams().get('expired')` → hiển thị banner:
  ```
  セッションの有効期限が切れました。再度ログインしてください。
  ```

---

## 6. Auth State (Redux)

File: `src/stores/reducers/auth.ts` — đã có, không cần thay đổi logic chính.

```typescript
// Actions đã có trong scaffold:
setAuthTokens({ accessToken, refreshToken })
clearAuthState()

// Selectors đã có:
selectIsAuthenticated
selectCurrentUser
selectAuthStatus
```

---

## 7. Axios Interceptor

File: `src/services/http/handleResponse.ts` — đã có.

**Cần verify:** Response 401 phải trigger `clearAuthState()` và redirect về `/login?expired=true`.

Pattern này đã tồn tại trong `es-kitchen-web-admin` và `es-kitchen-web-company` — không implement lại từ đầu, verify và adjust nếu cần.

---

## 8. Files cần tạo mới

| File | Mô tả |
|---|---|
| `src/pages/change-password/ChangePasswordPage.tsx` | Trang đổi mật khẩu (route protected) |

## 9. Files cần sửa

| File | Thay đổi |
|---|---|
| `src/pages/auth/LoginPage.tsx` | Bỏ `companyCode` field, đổi thành `email` field |
| `src/pages/auth/ForgotPasswordPage.tsx` | Bỏ `companyCode` field, sửa submit → hiển thị success state inline, không redirect OTP |
| `src/pages/auth/ResetPasswordPage.tsx` | Bỏ OTP flow, lấy token từ `useSearchParams()`, thêm error states |
| `src/pages/auth/VerifyPage.tsx` | Xóa hoặc để lại nếu vẫn dùng (xác nhận với FE dev) |
| `src/services/client/auth.service.ts` | Đổi API endpoints sang `/supplier/auth/...`, bỏ `companyCode` params |
| `src/validation/schemas.ts` | Sửa `signInSchema` (bỏ `companyCode`), sửa `forgotPasswordSchema` (bỏ `companyCode`), sửa `resetPasswordSchema` (đổi field names), thêm `changePasswordSchema` |
| `src/routes/index.tsx` | Bỏ route `/verify`, thêm route `/change-password` |
| `src/constants/route.ts` | Bỏ `VERIFY`, thêm `CHANGE_PASSWORD` |
| `src/models/auth.ts` | Cập nhật interfaces theo API contract mới |

---

## 10. Non-Regression Risks

| Risk | Mitigation |
|---|---|
| Xóa `VerifyPage` và route `/verify` | Nếu có deep link cũ trỏ vào `/verify` sẽ redirect về `/login` (wildcard route đã có) |
| Sửa `signInSchema` bỏ `companyCode` | Chỉ ảnh hưởng `LoginPage` — không có component nào khác dùng `signInSchema` hiện tại |
| Đổi API endpoint prefix từ `/auth/...` sang `/supplier/auth/...` | Cần update `APIs` object trong `auth.service.ts` và confirm với BE về route chính xác |
| `ChangePasswordPage` là trang mới — không có regression | New feature |
