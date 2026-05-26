# DESIGN: Version Management — es-kitchen-web-admin (E03)

> **Feature:** Version Management (Cross-repo Common)
> **Repo:** `es-kitchen-web-admin`
> **Spec:** `es-kitchen-docs/docs/features/version-management/SPEC.md`
> **API Design:** `es-kitchen-docs/docs/features/version-management/es-kitchen-api/DESIGN.md`
> **Date:** 19/05/2026
> **Status:** Draft
> **Author:** Tech Lead

---

## 1. Route

```
/version-management
```

Route đặt ở top-level (không nest dưới `/settings`) vì đây là màn hình độc lập trong sidebar.

---

## 2. Component Tree

```
VersionManagementPage                          ← pages/version-management/index.tsx
├── PageHeader
│   ├── <h1>Version Management</h1>
│   └── <Button>New</Button>                   ← mở NewVersionModal
├── FilterToolbar
│   └── PlatformFilterDropdown                 ← All / iOS / Android
├── VersionTable                               ← components/version-management/VersionTable.tsx
│   └── VersionTableRow (per row)
│       ├── EditButton                         ← mở EditVersionModal
│       └── DeleteButton                       ← mở DeleteConfirmFlow
├── NewVersionModal                            ← components/version-management/VersionModal.tsx (mode=create)
├── EditVersionModal                           ← VersionModal.tsx (mode=edit, pre-filled)
└── DeleteConfirmFlow                          ← components/version-management/DeleteConfirmFlow.tsx
    ├── WarningPopup (bước 1)
    └── ConfirmPopup (bước 2)
```

---

## 3. File Structure

```
src/
├── pages/
│   └── version-management/
│       └── index.tsx                          ← Route component
├── components/
│   └── version-management/
│       ├── VersionTable.tsx
│       ├── VersionModal.tsx                   ← dùng chung create + edit, prop: mode + initialData
│       ├── DeleteConfirmFlow.tsx
│       └── PlatformFilterDropdown.tsx
├── hooks/
│   └── version-management/
│       └── useVersionManagement.ts            ← TanStack Query v5: list + mutations
└── services/
    └── appVersionApi.ts                       ← API call functions
```

---

## 4. API Integration

### 4.1 Endpoints dùng

| Method | Path | Dùng ở đâu |
|---|---|---|
| GET | `/admin/app-versions?platform=` | useVersionManagement — list query |
| POST | `/admin/app-versions` | useVersionManagement — createMutation |
| PUT | `/admin/app-versions/:id` | useVersionManagement — updateMutation |
| DELETE | `/admin/app-versions/:id` | useVersionManagement — deleteMutation |

### 4.2 Service layer (`appVersionApi.ts`)

```typescript
// services/appVersionApi.ts
export const appVersionApi = {
  list: (platform?: 'ios' | 'android') =>
    apiClient.get<AppVersionListResponse>('/admin/app-versions', { params: { platform } }),

  create: (body: CreateAppVersionBody) =>
    apiClient.post<AppVersionItemResponse>('/admin/app-versions', body),

  update: (id: string, body: UpdateAppVersionBody) =>
    apiClient.put<AppVersionItemResponse>(`/admin/app-versions/${id}`, body),

  delete: (id: string) =>
    apiClient.delete(`/admin/app-versions/${id}`),
};
```

---

## 5. TanStack Query v5

File: `hooks/version-management/useVersionManagement.ts`

```typescript
// Object syntax BẮT BUỘC — TanStack Query v5
export function useVersionManagement(platform?: AppPlatform) {
  const queryClient = useQueryClient();

  const listQuery = useQuery({
    queryKey: ['app-versions', platform],
    queryFn: () => appVersionApi.list(platform),
  });

  const createMutation = useMutation({
    mutationFn: (body: CreateAppVersionBody) => appVersionApi.create(body),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['app-versions'] });
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, body }: { id: string; body: UpdateAppVersionBody }) =>
      appVersionApi.update(id, body),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['app-versions'] });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => appVersionApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['app-versions'] });
    },
  });

  return { listQuery, createMutation, updateMutation, deleteMutation };
}
```

**Query key strategy:** `['app-versions', platform]` — khi platform thay đổi, query tự động re-fetch. `invalidateQueries({ queryKey: ['app-versions'] })` invalidate tất cả platform variants.

---

## 6. Types

```typescript
// types/appVersion.ts

export type AppPlatform = 'ios' | 'android';
export type AppEnvironment = 'development' | 'staging' | 'production';

export interface AppVersionItem {
  id: string;
  platform: AppPlatform;
  versionName: string;
  versionCode: number;
  environment: AppEnvironment;
  downloadUrl: string;
  description: string | null;
  forceUpdate: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AppVersionListResponse {
  data: AppVersionItem[];
}

export interface AppVersionItemResponse {
  data: AppVersionItem;
}

export interface CreateAppVersionBody {
  platform: AppPlatform;
  versionName: string;
  versionCode: number;
  environment: AppEnvironment;
  downloadUrl: string;
  description?: string;
  forceUpdate?: boolean;
}

export type UpdateAppVersionBody = CreateAppVersionBody;
```

---

## 7. Component Design

### 7.1 VersionTable

```typescript
interface VersionTableProps {
  data: AppVersionItem[];
  isLoading: boolean;
  onEdit: (item: AppVersionItem) => void;
  onDelete: (item: AppVersionItem) => void;
}
```

**Columns (theo SPEC AC-01):**

| Column | Data field | Notes |
|---|---|---|
| ACTION | — | Edit icon (xanh) + Delete icon (đỏ) |
| VERSION NAME | `versionName` | — |
| VERSION CODE | `versionCode` | — |
| ENVIRONMENT | `environment` | Badge hoặc text |
| PLATFORM | `platform` | 'iOS' / 'Android' (capitalize) |
| DESCRIPTION | `description` | Truncate nếu dài |
| FORCE UPDATE | `forceUpdate` | Hiển thị 'True' / 'False' |

Không dùng pagination — load toàn bộ (per SPEC; OQ-04 chưa resolve, default là load all).

### 7.2 PlatformFilterDropdown

```typescript
interface PlatformFilterDropdownProps {
  value?: AppPlatform;
  onChange: (value?: AppPlatform) => void;
}
```

Options: `All` (value = undefined) | `iOS` (value = 'ios') | `Android` (value = 'android')

State quản lý ở `VersionManagementPage` — truyền xuống cả `VersionTable` và `useVersionManagement`.

### 7.3 VersionModal (create + edit)

```typescript
interface VersionModalProps {
  open: boolean;
  mode: 'create' | 'edit';
  initialData?: AppVersionItem;    // chỉ dùng khi mode='edit'
  onClose: () => void;
  onSubmit: (body: CreateAppVersionBody) => void;
  isSubmitting: boolean;
}
```

**Form fields (react-hook-form + yup):**

| Field | Type | Validation |
|---|---|---|
| Platform | Select | Required; default: 'ios' |
| Version Name | Input | Required; pattern `^\d+(\.\d+)+$` |
| Version Code | Input[number] | Required; integer >= 1 |
| Environment | Select | Required; default: 'development' |
| Download URL | Input | Required; valid URL (http/https) |
| Description | Textarea | Optional |
| Force Update | Checkbox | Default: unchecked |

**Submit flow (2-step confirmation per BR-05):**
1. User fills form → nhấn Save → form validation chạy.
2. Nếu valid → hiển thị Warning Popup (`WarningPopup`).
3. User confirm → submit API.
4. Nếu API 409 (duplicate) → hiển thị error inline dưới Version Name hoặc toast.

**Warning popup content khi Force Update = true:**
> "Force Update đang được bật. Người dùng đang chạy version này sẽ bị buộc cập nhật app."

### 7.4 DeleteConfirmFlow

```typescript
interface DeleteConfirmFlowProps {
  open: boolean;
  target: AppVersionItem | null;
  onClose: () => void;
  onConfirm: () => void;
  isDeleting: boolean;
}
```

**2-step flow:**
- Bước 1 — Warning popup: hiển thị thông tin version sẽ bị xóa. Nếu `target.forceUpdate === true`, thêm text: "Version này đang có Force Update = True."
- Bước 2 — Confirm popup: "Bạn có chắc muốn xóa? Hành động này không thể hoàn tác."
- Nhấn Cancel ở bất kỳ bước nào → đóng flow, không thay đổi gì.

---

## 8. Form Validation Schema (yup)

```typescript
const versionSchema = yup.object({
  platform: yup.string().oneOf(['ios', 'android']).required(),
  versionName: yup
    .string()
    .matches(/^\d+(\.\d+)+$/, 'Version name phải theo định dạng số, ví dụ: 1.0.12')
    .max(20)
    .required(),
  versionCode: yup
    .number()
    .integer('Version Code phải là số nguyên')
    .positive('Version Code phải > 0')
    .required(),
  environment: yup.string().oneOf(['development', 'staging', 'production']).required(),
  downloadUrl: yup
    .string()
    .matches(/^https?:\/\//, 'Download URL phải bắt đầu bằng http:// hoặc https://')
    .max(500)
    .required(),
  description: yup.string().optional(),
  forceUpdate: yup.boolean().default(false),
});
```

---

## 9. State Management

Client state cho UI (modal open/close, filter selection) quản lý bằng `useState` cục bộ trong `VersionManagementPage` — không dùng Redux (đây là UI state thuần, không shared).

Server state (data list, mutations) qua TanStack Query v5 — không dùng Redux cho server data.

---

## 10. Error Handling

| Error | Xử lý |
|---|---|
| API 409 (duplicate) | Hiển thị message lỗi inline trong modal form: "Version (platform + name + code) đã tồn tại." |
| API 404 (not found on edit/delete) | Toast error: "Version không tìm thấy." + close modal + invalidate list |
| Network error | Toast error generic: "Có lỗi xảy ra. Vui lòng thử lại." |
| Validation lỗi (client-side) | Inline error dưới từng field trong form |

---

## 11. Tasks phân rã

| Task | Mô tả | Phase |
|---|---|---|
| task-3-1 | `appVersionApi.ts` service functions | Phase 3 |
| task-3-2 | `useVersionManagement.ts` hook (TanStack Query v5) | Phase 3 |
| task-3-3 | `VersionTable` + `PlatformFilterDropdown` components | Phase 3 |
| task-3-4 | `VersionModal` component (create + edit) với react-hook-form + yup | Phase 3 |
| task-3-5 | `DeleteConfirmFlow` component (2-step) | Phase 3 |
| task-3-6 | `VersionManagementPage` — compose các component, wire state | Phase 3 |
| task-3-7 | Route registration + sidebar menu link | Phase 3 |
