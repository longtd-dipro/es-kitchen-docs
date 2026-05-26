# DESIGN: Maintain Management — es-kitchen-web-admin (E03)

> **Feature:** Maintain Management (Cross-repo Common)
> **Repo:** `es-kitchen-web-admin`
> **SPEC:** `es-kitchen-docs/docs/features/maintain-management/SPEC.md`
> **Date:** 19/05/2026
> **Author:** Tech Lead
> **Status:** Draft

---

## 1. Tổng quan thiết kế

### Quyết định thiết kế chính

| Hạng mục | Quyết định | Lý do |
|---|---|---|
| Route | `/settings/maintenance` | Đây là feature cấu hình hệ thống — nhóm vào `/settings/` nhất quán hơn `/maintain-management` |
| State management | TanStack Query v5 (server state) — không dùng Redux | Dữ liệu từ API, không phải client state |
| 2-step confirm | Local state trong Modal component | Không cần persist — modal state sống trong component |
| Real-time update | Refetch sau mutation — không WebSocket | Requirement không yêu cầu real-time push; đơn giản hơn và đủ dùng |
| Table layout | Ant Design `Table` v6 — 6 rows cố định, không phân trang | Matrix 6 rows — không cần pagination |
| Loading/Error | Skeleton + `message.error()` qua App.useApp() | Nhất quán với pattern web-admin hiện có |

---

## 2. Route & Navigation

**Route path:** `/settings/maintenance`

**ROUTE constant:**
```typescript
// constants/route.ts — thêm vào
MAINTENANCE: '/settings/maintenance',
```

**Router registration** (`routes/index.tsx`):
```typescript
// Trong children của RequireAuth + AuthLayout
{
  path: ROUTE.MAINTENANCE,
  element: withSuspense(<MaintenanceManagementPage />),
},
```

**Sidebar entry:** Thêm menu item "Maintain Management" dưới nhóm "Settings" trong sidebar navigation.

---

## 3. Component Tree

```
MaintenanceManagementPage         ← pages/settings/maintenance/page.tsx
└── MaintenanceMatrix             ← components/MaintenanceMatrix.tsx
    ├── [Ant Design Table]        ← 6 rows, không phân trang
    │   └── Toggle button (Enable/Disable) mỗi row
    └── ToggleConfirmModal        ← components/ToggleConfirmModal.tsx
        ├── Step 1: Warning popup
        └── Step 2: Confirm popup
```

---

## 4. File Structure

```
pages/settings/maintenance/
├── page.tsx                            ← Entry point (lazy-loaded)
└── components/
    ├── MaintenanceMatrix.tsx           ← Table + toggle logic
    └── ToggleConfirmModal.tsx          ← 2-step confirm modal
```

```
services/client/
└── maintenance.service.ts              ← API calls

types/
└── maintenance.ts                      ← TypeScript types/interfaces
```

---

## 5. TypeScript Types

**File:** `types/maintenance.ts`

```typescript
export type MaintenancePlatform = 'ios' | 'android';
export type MaintenanceEnvironment = 'development' | 'staging' | 'production';

export interface MaintenanceAdminItem {
  id: string;
  platform: MaintenancePlatform;
  environment: MaintenanceEnvironment;
  isEnabled: boolean;
  updatedAt: string;           // ISO string
  updatedByAdmin: {
    id: string;
    userName: string;
  } | null;
}

export interface MaintenanceListResponse {
  data: MaintenanceAdminItem[];
}

export interface ToggleMaintenancePayload {
  id: string;
  isEnabled: boolean;
}
```

---

## 6. Service Layer

**File:** `services/client/maintenance.service.ts`

```typescript
import API from './api';
import type { MaintenanceListResponse, ToggleMaintenancePayload } from '@/types/maintenance';

export const maintenanceService = {
  getList: (): Promise<MaintenanceListResponse> =>
    API.get('/admin/maintenance'),

  toggle: ({ id, isEnabled }: ToggleMaintenancePayload) =>
    API.patch(`/admin/maintenance/${id}`, { isEnabled }),
};
```

---

## 7. TanStack Query v5

### Query — fetch list

```typescript
// Trong MaintenanceMatrix.tsx
const { data, isLoading, isError } = useQuery({
  queryKey: ['maintenance', 'list'],
  queryFn: () => maintenanceService.getList(),
  staleTime: 0,    // Luôn fetch mới khi navigate tới trang
});
```

### Mutation — toggle

```typescript
const queryClient = useQueryClient();
const { message } = App.useApp();

const { mutate: toggleMutation, isPending } = useMutation({
  mutationFn: ({ id, isEnabled }: ToggleMaintenancePayload) =>
    maintenanceService.toggle({ id, isEnabled }),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['maintenance', 'list'] });
    message.success(isEnabled ? 'Maintain đã được bật' : 'Maintain đã được tắt');
    setModalState({ open: false, step: 1, target: null });
  },
  onError: () => {
    message.error('Có lỗi xảy ra. Vui lòng thử lại.');
  },
});
```

---

## 8. Component Specifications

### 8.1 MaintenanceManagementPage

**File:** `pages/settings/maintenance/page.tsx`

- Container page, không có logic riêng
- Render `<MaintenanceMatrix />`
- Page title: "Maintain Management"

### 8.2 MaintenanceMatrix

**File:** `pages/settings/maintenance/components/MaintenanceMatrix.tsx`

**Props:** None (fetch data internally)

**State:**
```typescript
type ModalState = {
  open: boolean;
  step: 1 | 2;          // Step 1 = Warning, Step 2 = Confirm
  target: MaintenanceAdminItem | null;
};
const [modalState, setModalState] = useState<ModalState>({
  open: false,
  step: 1,
  target: null,
});
```

**Ant Design Table columns:**

| Column | Key | Render |
|---|---|---|
| Platform | `platform` | Text: `iOS` / `Android` |
| Environment | `environment` | Text: `Development` / `Staging` / `Production` |
| Status | `isEnabled` | `<Tag color="green">ON</Tag>` hoặc `<Tag color="default">OFF</Tag>` |
| Last Updated | `updatedAt` | `dayjs(updatedAt).format('YYYY/MM/DD HH:mm')` — hiển thị `—` nếu `updatedByAdmin` null |
| Updated By | `updatedByAdmin.userName` | `—` nếu null |
| Action | — | `<Button>` "Enable Maintain" (khi OFF) hoặc "Disable Maintain" (khi ON) |

**Table config:**
```typescript
<Table
  dataSource={data?.data ?? []}
  rowKey="id"
  loading={isLoading}
  pagination={false}
  columns={columns}
/>
```

**Hành động khi nhấn toggle button:**
```typescript
const handleToggleClick = (record: MaintenanceAdminItem) => {
  setModalState({ open: true, step: 1, target: record });
};
```

### 8.3 ToggleConfirmModal

**File:** `pages/settings/maintenance/components/ToggleConfirmModal.tsx`

**Props:**
```typescript
interface ToggleConfirmModalProps {
  open: boolean;
  step: 1 | 2;
  target: MaintenanceAdminItem | null;
  isPending: boolean;
  onContinue: () => void;    // Step 1 → Step 2
  onConfirm: () => void;     // Step 2 → call mutation
  onCancel: () => void;      // Hủy, đóng modal
}
```

**Nội dung theo step:**

**Step 1 — Warning:**
- Title: "Cảnh báo"
- Content (enable): "Bạn sắp bật maintain cho **{Platform} — {Environment}**. Toàn bộ user trên nền tảng này sẽ bị block khỏi app ngay lập tức."
- Content (disable): "Bạn sắp tắt maintain cho **{Platform} — {Environment}**. User sẽ có thể sử dụng app trở lại."
- Buttons: "Hủy" (cancel) | "Tiếp tục" (continue → step 2)

**Step 2 — Confirm:**
- Title: "Xác nhận"
- Content (enable): "Xác nhận bật maintain cho **{Platform} — {Environment}**?"
- Content (disable): "Xác nhận tắt maintain cho **{Platform} — {Environment}**?"
- Buttons: "Hủy" (cancel) | "Xác nhận" (confirm, loading khi isPending)

**Implementation:**
```typescript
// Dùng Ant Design Modal v6
<Modal
  open={open}
  title={step === 1 ? 'Cảnh báo' : 'Xác nhận'}
  onCancel={onCancel}
  footer={[
    <Button key="cancel" onClick={onCancel}>Hủy</Button>,
    step === 1
      ? <Button key="continue" type="primary" onClick={onContinue}>Tiếp tục</Button>
      : <Button key="confirm" type="primary" danger loading={isPending} onClick={onConfirm}>Xác nhận</Button>,
  ]}
>
  {/* content */}
</Modal>
```

**Logic onConfirm:**
```typescript
const handleConfirm = () => {
  if (!modalState.target) return;
  toggleMutation({
    id: modalState.target.id,
    isEnabled: !modalState.target.isEnabled,
  });
};
```

---

## 9. Display Labels

```typescript
// utils/maintenance.ts
export const PLATFORM_LABELS: Record<MaintenancePlatform, string> = {
  ios: 'iOS',
  android: 'Android',
};

export const ENVIRONMENT_LABELS: Record<MaintenanceEnvironment, string> = {
  development: 'Development',
  staging: 'Staging',
  production: 'Production',
};
```

---

## 10. Loading & Error States

| State | UI |
|---|---|
| `isLoading` | Table `loading={true}` (built-in Ant Design skeleton) |
| `isError` | `message.error('データの取得に失敗しました')` + empty table |
| `isPending` (mutation) | Confirm button `loading={true}`, disabled |
| API error (mutation) | `message.error(...)` trong `onError` |

---

## 11. Non-Regression Risks

| Risk | Biện pháp |
|---|---|
| Route conflict với existing `/settings/...` route | Kiểm tra `routes/index.tsx` trước khi thêm |
| Ant Design Modal v6 API khác v5 | Dùng `footer` array prop — đã confirm v6 compatible |
| `App.useApp()` phải nằm trong `<App>` context | Đảm bảo `MaintenanceMatrix` render bên trong `<App>` wrapper (đã có ở layout level) |
| `invalidateQueries` không trigger refetch nếu query đang inactive | `staleTime: 0` đảm bảo refetch ngay khi page active |
| Platform/environment label khác nhau giữa API response và display | Dùng `PLATFORM_LABELS` / `ENVIRONMENT_LABELS` map — không hardcode string trực tiếp |

---

## 12. Task Breakdown (gợi ý)

| Task | Nội dung |
|---|---|
| task-2-1 | Type definitions + service layer (`maintenance.service.ts`) |
| task-2-2 | `MaintenanceMatrix` component (table, toggle button) |
| task-2-3 | `ToggleConfirmModal` component (2-step) |
| task-2-4 | `MaintenanceManagementPage` + routing + sidebar entry |
| task-2-5 | Integration test: toggle flow E2E (manual) |
