# [FE] [Supplier_Web] - Setup foundation: types, service, hooks, route và nav item

## Backlog Info
- **Issue Type:** Task
- **Category:** Supplier_Web
- **Parent Issue:** E04 — Order List (Supplier Web)
- **Version:** Phase 2
- **Milestone:** Released W8 / Go-live W31
- **Estimate Hour:** 4h
- **Actual Hour:** —
- **Status:** Open

## Metadata
- Phase: 3 | Repo: `es-kitchen-web-supplier` | Depends on: task-2-2 (API contract phải finalized)

## Mục tiêu
Tạo toàn bộ foundation layer cho màn hình Order List: TypeScript types, API service, TanStack Query hooks, route config và nav item — không implement UI component.

## Context (đọc trước khi code)
- DESIGN.md: `es-kitchen-docs/docs/epics/E04/details/order-list/es-kitchen-web-supplier/DESIGN.md` — Section 2, 3, 4
- File hiện tại cần sửa: `src/constants/route.ts`, `src/constants/nav.ts`, router config
- Pattern tham khảo: `src/services/client/auth.service.ts`, `src/services/query/`

## Yêu cầu implement

### 1. Types
File: `src/types/purchase-order.ts` *(file mới)*

```typescript
export enum PurchaseOrderStatus {
  WAITING_DELIVERY_DATE = 'WAITING_DELIVERY_DATE',
  WAITING_SHIPMENT      = 'WAITING_SHIPMENT',
  SHIPPED               = 'SHIPPED',
}

export interface PurchaseOrderListItem {
  id: string;
  orderNumber: string;
  orderDate: string;
  productName: string;
  productCount: number;
  status: PurchaseOrderStatus;
  desiredDeliveryDate: string | null;
  scheduledShipmentDate: string | null;
  shipmentDate: string | null;
  quantity: number;
  trackingNumber: string | null;
}

export interface PurchaseOrderListResponse {
  items: PurchaseOrderListItem[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface PurchaseOrderBadgeCount {
  waitingDeliveryDate: number;
  waitingShipment: number;
  shipped: number;
}

export interface ListOrdersParams {
  status?: PurchaseOrderStatus;
  shipmentDateFrom?: string;
  shipmentDateTo?: string;
  page?: number;
  limit?: number;
}
```

### 2. API Service
File: `src/services/client/order.service.ts` *(file mới)*

```typescript
import API from './api';
import type { PurchaseOrderListResponse, PurchaseOrderBadgeCount, ListOrdersParams } from '../../types/purchase-order';

export const orderService = {
  getOrders: (params: ListOrdersParams): Promise<{ data: PurchaseOrderListResponse }> =>
    API.get('/supplier/orders', params),

  getBadgeCount: (): Promise<{ data: PurchaseOrderBadgeCount }> =>
    API.get('/supplier/orders/badge-count'),
};
```

### 3. TanStack Query hooks
File: `src/hooks/useOrderList.ts` *(file mới)*

```typescript
import { useQuery } from '@tanstack/react-query';
import { orderService } from '../services/client/order.service';
import type { ListOrdersParams } from '../types/purchase-order';

export const ORDER_QUERY_KEYS = {
  list: (params: ListOrdersParams) => ['supplier', 'orders', params] as const,
  badge: () => ['supplier', 'orders', 'badge'] as const,
};

export function useOrderList(params: ListOrdersParams) {
  return useQuery({
    queryKey: ORDER_QUERY_KEYS.list(params),
    queryFn: () => orderService.getOrders(params),
    select: (res) => res.data,
    staleTime: 30_000,
  });
}

export function useOrderBadgeCount() {
  return useQuery({
    queryKey: ORDER_QUERY_KEYS.badge(),
    queryFn: () => orderService.getBadgeCount(),
    select: (res) => res.data,
    refetchInterval: 60_000,
    staleTime: 30_000,
  });
}
```

### 4. Cập nhật `src/constants/route.ts`
Thêm `ORDERS: "/orders"` vào object ROUTE.

### 5. Cập nhật `src/constants/nav.ts`
Thêm nav item cho Orders sau Dashboard:

```typescript
{
  key: "orders",
  labelJa: "注文一覧",
  icon: OrderIcon,
  href: ROUTE.ORDERS,
}
```

> `OrderIcon`: nếu chưa có trong `src/statics/icons/nav-icons`, tạo component SVG placeholder hoặc dùng icon tương tự từ bộ có sẵn.

### 6. Cập nhật router
Thêm route `/orders` trỏ đến `OrderListPage` (component sẽ tạo ở task-3-3). Tạm thời có thể dùng lazy import với placeholder component.

## Unit Tests (BẮT BUỘC)
- File: `src/hooks/useOrderList.test.ts`
- Coverage target: 80%
- Verify: `npm run test -- useOrderList`

**Test cases:**

```
describe('useOrderList')
  ✓ gọi orderService.getOrders với đúng params
  ✓ select đúng res.data từ response
  ✓ staleTime = 30000

describe('useOrderBadgeCount')
  ✓ gọi orderService.getBadgeCount
  ✓ refetchInterval = 60000
  ✓ select đúng res.data

describe('ORDER_QUERY_KEYS')
  ✓ list key có namespace ['supplier', 'orders', params]
  ✓ badge key = ['supplier', 'orders', 'badge']
```

## Non-Regression Table
| Tính năng | File liên quan | Cách verify |
|---|---|---|
| Route hiện tại (dashboard, auth) | `constants/route.ts` | Không xóa/đổi key cũ — chỉ thêm `ORDERS` |
| Nav item Dashboard | `constants/nav.ts` | Dashboard item vẫn còn và đứng trước Orders |
| Auth service | `services/client/auth.service.ts` | Không chạm file này |
| TanStack Query keys hiện tại | Các hooks khác | Namespace `['supplier', 'orders', ...]` unique |

## Không được làm
- Không dùng Redux cho server state (list, badge) — chỉ TanStack Query
- Không tạo Redux slice cho order data
- Không implement UI component trong task này

## Definition of Done
- [ ] Build pass: `npm run build`
- [ ] Lint pass
- [ ] `src/types/purchase-order.ts` export đầy đủ types
- [ ] `src/services/client/order.service.ts` hoạt động
- [ ] `src/hooks/useOrderList.ts` export 2 hooks + `ORDER_QUERY_KEYS`
- [ ] Route `/orders` đã có trong router
- [ ] Nav item `注文一覧` hiển thị trong sidebar
- [ ] Unit tests pass, coverage ≥ 80%
- [ ] Actual Hour cập nhật
- [ ] Status chuyển → Request Review
