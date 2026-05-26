# DESIGN: Admin Account Management — es-kitchen-web-admin

> SPEC: `es-kitchen-docs/docs/epics/E03/details/admin-account-management/SPEC.md`
> API DESIGN: `../es-kitchen-api/DESIGN.md`
> Date: 19/05/2026

---

## 0. Phân tích trạng thái hiện tại

Hiện tại module "Admin Account" chưa tồn tại trong `es-kitchen-web-admin`. Feature này là mới hoàn toàn phía FE. Cần tạo mới routes, pages và components.

**Stack áp dụng:**
- TanStack Query v5 — object syntax bắt buộc
- Redux Toolkit v2 — chỉ dùng cho client state (confirmation dialog state, v.v.)
- react-hook-form + yup — validation form
- Ant Design v6
- react-router-dom v7

---

## 1. Routes / Pages

| Route | Component | Mô tả |
|---|---|---|
| `/admin/admin-management` | `AdminManagementPage` | Danh sách tài khoản admin (Story 4.1) |
| `/admin/role-system` | `RoleSystemPage` | Danh sách role + permission (Story 4.5) |
| `/admin/ip-whitelist` | `IpWhitelistPage` | Quản lý IP Whitelist (Story 4.9) |

Tất cả routes trên nằm trong layout chính của web-admin (sidebar + header đã có).

> Routes này được thêm vào file router chính của app (thường là `src/router.tsx` hoặc tương đương).

---

## 2. Components

### 2.1 AdminManagementPage — `/admin/admin-management`

```
src/pages/admin-management/
├── AdminManagementPage.tsx           ← Page container
└── components/
    ├── AdminTable.tsx                ← Bảng danh sách, columns: ACTION, #, USERNAME, EMAIL, ROLE
    ├── AdminTableActions.tsx         ← Nút Edit + Disable/Enable (ẩn với SUPPER_ADMIN)
    ├── CreateAdminModal.tsx          ← Modal tạo admin mới
    ├── EditAdminModal.tsx            ← Modal chỉnh sửa admin
    └── ConfirmActionModal.tsx        ← Modal 2 bước: warning → confirm (dùng chung disable/enable)
```

**AdminTable columns:**

| Column | Type | Ghi chú |
|---|---|---|
| ACTION | ReactNode | Nút Edit (bút chì, blue) + Disable/Enable (khóa, green). Ẩn hoàn toàn nếu `isSupperAdmin = true` |
| # | number | Index thứ tự (1-based, theo page) |
| USERNAME | string | |
| EMAIL | string | |
| ROLE | string | Hiển thị `role.roleName` |

**CreateAdminModal fields:**

| Field | Type | Validation |
|---|---|---|
| Username | text | required, max 255 |
| Email | email | required, valid email |
| Password | password | required, min 8 chars, complexity (uppercase + number + special char) |
| Role | select | required, options từ `GET /admin/roles` |

**EditAdminModal fields:**

| Field | Type | Validation | Điều kiện hiển thị |
|---|---|---|---|
| Username | text | required, max 255 | Luôn hiển thị |
| Email | email | required, valid email | Luôn hiển thị |
| Role | select | required | Chỉ hiển thị nếu current user là SUPPER_ADMIN |

**ConfirmActionModal — Disable flow:**
1. Bước 1 (Warning): Hiển thị message `"Bạn sắp vô hiệu hóa tài khoản [USERNAME]. Tài khoản này sẽ không thể đăng nhập."` — nút `Tiếp tục` và `Hủy`.
2. Bước 2 (Confirm): Hiển thị `"Xác nhận vô hiệu hóa?"` — nút `Xác nhận` và `Hủy`.

---

### 2.2 RoleSystemPage — `/admin/role-system`

```
src/pages/role-system/
├── RoleSystemPage.tsx               ← Page container
└── components/
    ├── RoleTable.tsx                ← Bảng danh sách role, columns: ACTION, #, ROLE
    ├── RoleTableActions.tsx         ← Nút Edit (ẩn với SUPPER_ADMIN role)
    ├── CreateRoleModal.tsx          ← Modal tạo role mới
    ├── EditRoleModal.tsx            ← Modal chỉnh sửa role
    ├── PermissionMatrix.tsx         ← Grid 2 cột, mỗi module có EDIT + VIEW checkbox
    └── DeleteRoleConfirmModal.tsx   ← Modal 2 bước confirm xóa role
```

**RoleTable columns:**

| Column | Type | Ghi chú |
|---|---|---|
| ACTION | ReactNode | Nút Edit (bút chì, blue). Ẩn nếu `isSystem = true` |
| # | number | Index thứ tự |
| ROLE | string | `role.roleName` |

**PermissionMatrix — layout:**

- 2 cột grid, mỗi cell hiển thị tên module + 2 checkbox con: `EDIT` và `VIEW`
- `EDIT` checkbox checked → tự động check `VIEW` (BR-03) — implement bằng `watch` của react-hook-form
- `VIEW` không thể uncheck khi `EDIT` đang checked

**CreateRoleModal / EditRoleModal fields:**

| Field | Type | Validation |
|---|---|---|
| Role Name | text | required, max 100 |
| Permissions | PermissionMatrix | optional (có thể không chọn gì) |

**DeleteRoleConfirmModal:**
1. Bước 1 (Warning): `"Bạn sắp xóa role [ROLE_NAME]. Hành động này không thể hoàn tác."` — nút `Tiếp tục` và `Hủy`.
2. Bước 2 (Confirm): `"Xác nhận xóa role?"` — nút `Xác nhận (đỏ)` và `Hủy`.
- Nếu API trả lỗi `400` (role đang được gán) → hiển thị inline error: `"Không thể xóa. Role này đang được gán cho {adminCount} tài khoản."`.

---

### 2.3 IpWhitelistPage — `/admin/ip-whitelist`

```
src/pages/ip-whitelist/
├── IpWhitelistPage.tsx               ← Page container
└── components/
    ├── IpWhitelistTable.tsx          ← Bảng danh sách IP, columns: ACTION, #, IP ADDRESS, NOTE, CREATED AT
    ├── AddIpModal.tsx                ← Modal thêm IP mới
    └── DeleteIpConfirmModal.tsx      ← Modal 2 bước confirm xóa IP
```

**IpWhitelistTable columns:**

| Column | Type |
|---|---|
| ACTION | Nút Delete (icon trash, đỏ) |
| # | number |
| IP ADDRESS | string (IPv4/IPv6/CIDR) |
| NOTE | string \| null |
| CREATED AT | date formatted |

**AddIpModal fields:**

| Field | Type | Validation |
|---|---|---|
| IP Address | text | required, valid IPv4 / IPv6 / CIDR format (custom yup validator) |
| Note | text | optional, max 255 |

**DeleteIpConfirmModal:** Tương tự pattern 2 bước.

---

### 2.4 Shared Components

```
src/components/
└── TwoStepConfirmModal.tsx
    // Props:
    // warningTitle: string
    // warningMessage: string
    // confirmTitle: string
    // confirmMessage: string
    // onConfirm: () => void
    // onCancel: () => void
    // isLoading: boolean
    // isDanger?: boolean (nút confirm màu đỏ)
```

`TwoStepConfirmModal` là component tái sử dụng cho tất cả destructive action (disable admin, xóa role, xóa IP). Quản lý step state nội bộ bằng `useState`.

---

## 3. API Calls (TanStack Query v5)

### 3.1 Admin Account Queries & Mutations

```typescript
// src/services/admin-management.service.ts

// --- Queries ---

// Danh sách admin
export const useAdminList = (params: GetAdminListParams) =>
  useQuery({
    queryKey: ['admin-management', 'list', params],
    queryFn: () => adminManagementApi.getList(params),
  });

// Chi tiết admin
export const useAdminDetail = (id: string) =>
  useQuery({
    queryKey: ['admin-management', 'detail', id],
    queryFn: () => adminManagementApi.getDetail(id),
    enabled: !!id,
  });

// --- Mutations ---

// Tạo admin
export const useCreateAdmin = () =>
  useMutation({
    mutationFn: (data: CreateAdminRequest) => adminManagementApi.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-management', 'list'] });
    },
  });

// Sửa admin
export const useUpdateAdmin = (id: string) =>
  useMutation({
    mutationFn: (data: UpdateAdminRequest) => adminManagementApi.update(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-management', 'list'] });
      queryClient.invalidateQueries({ queryKey: ['admin-management', 'detail', id] });
    },
  });

// Disable/Enable admin
export const useUpdateAdminStatus = (id: string) =>
  useMutation({
    mutationFn: (data: { status: 1 | 2 }) => adminManagementApi.updateStatus(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-management', 'list'] });
    },
  });

// Cấu hình email notification
export const useAdminEmailNotifications = (adminId: string) =>
  useQuery({
    queryKey: ['admin-management', 'email-notifications', adminId],
    queryFn: () => adminManagementApi.getEmailNotifications(adminId),
    enabled: !!adminId,
  });

export const useUpdateEmailNotifications = (adminId: string) =>
  useMutation({
    mutationFn: (data: UpdateEmailNotificationsRequest) =>
      adminManagementApi.updateEmailNotifications(adminId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: ['admin-management', 'email-notifications', adminId],
      });
    },
  });
```

### 3.2 Role Queries & Mutations

```typescript
// src/services/admin-role.service.ts

// Danh sách role (dùng cho cả RoleSystemPage và select option trong CreateAdminModal)
export const useRoleList = () =>
  useQuery({
    queryKey: ['admin-roles', 'list'],
    queryFn: () => adminRoleApi.getList(),
    staleTime: 5 * 60 * 1000, // 5 phút — roles thay đổi ít
  });

// Chi tiết role
export const useRoleDetail = (id: string) =>
  useQuery({
    queryKey: ['admin-roles', 'detail', id],
    queryFn: () => adminRoleApi.getDetail(id),
    enabled: !!id,
  });

// Tạo role
export const useCreateRole = () =>
  useMutation({
    mutationFn: (data: CreateRoleRequest) => adminRoleApi.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-roles', 'list'] });
    },
  });

// Sửa role
export const useUpdateRole = (id: string) =>
  useMutation({
    mutationFn: (data: UpdateRoleRequest) => adminRoleApi.update(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-roles', 'list'] });
      queryClient.invalidateQueries({ queryKey: ['admin-roles', 'detail', id] });
    },
  });

// Xóa role
export const useDeleteRole = () =>
  useMutation({
    mutationFn: (id: string) => adminRoleApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-roles', 'list'] });
    },
  });
```

### 3.3 IP Whitelist Queries & Mutations

```typescript
// src/services/admin-ip-whitelist.service.ts

export const useIpWhitelistList = () =>
  useQuery({
    queryKey: ['admin-ip-whitelist', 'list'],
    queryFn: () => ipWhitelistApi.getList(),
  });

export const useAddIp = () =>
  useMutation({
    mutationFn: (data: AddIpRequest) => ipWhitelistApi.add(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-ip-whitelist', 'list'] });
    },
  });

export const useDeleteIp = () =>
  useMutation({
    mutationFn: (id: string) => ipWhitelistApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-ip-whitelist', 'list'] });
    },
  });
```

---

## 4. State Management (Redux Toolkit)

Feature này **không cần Redux slice** cho server state — TanStack Query đủ xử lý.

Chỉ cần client state tối thiểu cho dialog flow và hiện tại nên dùng `useState` local trong component — không cần global store:

- Trạng thái open/close của modal → `useState` trong Page component
- Trạng thái step (warning/confirm) của `TwoStepConfirmModal` → `useState` nội bộ component

**Nếu cần global state trong tương lai** (ví dụ: current admin permissions sau login được dùng để ẩn/hiện nút action trên toàn app), thêm slice `adminPermissionsSlice` vào store.

---

## 5. UI/UX Notes

### 5.1 SUPPER_ADMIN protection (BR-01)

- Hàng SUPPER_ADMIN trong `AdminTable`: cột ACTION render `null` — không hiển thị icon Edit hay Disable.
- Hàng SUPPER_ADMIN trong `RoleTable`: cột ACTION render `null`.
- Logic kiểm tra: `item.isSupperAdmin === true` (từ response API) — không tự check tên role ở FE.

### 5.2 Role column trong EditAdminModal (BR-07)

- Field `Role` chỉ render nếu `currentUser.role === 'SUPPER_ADMIN'` (lấy từ `/admin/auth/me` hoặc Redux auth state).
- Non-SUPPER_ADMIN mở EditAdminModal → field Role không hiển thị, payload `PATCH` không gửi `roleId`.

### 5.3 BR-03 — EDIT bao hàm VIEW trong PermissionMatrix

```typescript
// Trong EditRoleModal / CreateRoleModal, dùng react-hook-form watch:
const { watch, setValue } = useForm();

// Watch tất cả EDIT fields
useEffect(() => {
  const subscription = watch((value, { name }) => {
    if (name?.endsWith('.canEdit') && value[module]?.canEdit) {
      setValue(`${module}.canView`, true);
    }
  });
  return () => subscription.unsubscribe();
}, [watch, setValue]);
```

### 5.4 Destructive action — 2 bước (BR-02)

Tất cả action phá hủy dùng `TwoStepConfirmModal`:
- Disable admin: warning → confirm
- Enable admin: warning → confirm
- Xóa role: warning → confirm
- Xóa IP: warning → confirm

Modal không tự đóng khi click bên ngoài (prevent accidental close).

### 5.5 Error handling

| Scenario | Xử lý |
|---|---|
| API 400 — username/email duplicate | Hiển thị inline error dưới field tương ứng |
| API 400 — role đang được gán (xóa role) | Toast error kèm message từ API |
| API 403 — không có quyền | Toast error: `"Bạn không có quyền thực hiện thao tác này"` |
| API 500 | Toast error generic: `"Đã có lỗi xảy ra. Vui lòng thử lại."` |
| Force logout (401 do session_version thay đổi) | Interceptor HTTP → redirect về `/admin/login` + clear auth state |

### 5.6 Password complexity hint trong CreateAdminModal

Hiển thị helper text ngay dưới password field:
```
Mật khẩu tối thiểu 8 ký tự, bao gồm chữ hoa, số và ký tự đặc biệt.
```

### 5.7 IP format validation (client-side)

Custom yup validator kiểm tra:
- IPv4: regex `^(\d{1,3}\.){3}\d{1,3}$` + từng octet 0–255
- IPv6: dùng thư viện `is-ip` hoặc regex chuẩn
- CIDR: IPv4/32 hoặc IPv6/128 với prefix hợp lệ

> Nếu OQ-06 resolved là "chỉ single IP" → bỏ CIDR validation, chỉ IPv4 + IPv6.

### 5.8 Loading states

- Bảng data: Ant Design `Table` prop `loading={isLoading}`
- Submit button trong modal: `loading={mutation.isPending}` — disable khi đang gọi API
- Delete/Disable button trong modal bước 2: `loading={mutation.isPending}`

---

## 6. Non-Regression Risks

| Risk | Mức độ | Biện pháp |
|---|---|---|
| Routes mới `/admin/admin-management` và `/admin/role-system` có thể conflict với route pattern hiện có | LOW | Kiểm tra router config trước khi thêm — ưu tiên route cụ thể trước route dynamic |
| `useRoleList` query được dùng trong `CreateAdminModal` (select Role option) và `RoleSystemPage` — nếu staleTime quá dài, sau khi tạo role mới, CreateAdminModal sẽ không thấy role mới | LOW | Invalidate `['admin-roles', 'list']` sau mỗi `useCreateRole` onSuccess |
| HTTP interceptor xử lý 401 force logout — nếu interceptor hiện có chỉ xử lý token expired thông thường, cần đảm bảo session_version mismatch cũng trigger logout | MEDIUM | Kiểm tra HTTP interceptor hiện có; đảm bảo mọi 401 response đều trigger clear auth + redirect |
| Ant Design v6 `Table` có thay đổi API so với v5 — cần xác nhận trước khi dùng `columns` config | LOW | Đọc Ant Design v6 migration guide, xác nhận `Table` API không thay đổi breaking |
| Sidebar menu cần thêm items mới ("Admin Management", "Role System", "IP Whitelist") — không được sửa nhầm menu của các feature khác | LOW | Thêm vào đúng section "Admin Account" trong sidebar config |
