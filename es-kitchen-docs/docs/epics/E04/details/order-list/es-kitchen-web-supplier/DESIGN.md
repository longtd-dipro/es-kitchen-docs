# DESIGN: Order List — es-kitchen-web-supplier

> **Epic:** E04 — Supplier Web
> **SPEC:** `../SPEC.md`
> **API DESIGN:** `../es-kitchen-api/DESIGN.md`
> **Date:** 19/05/2026
> **Status:** Draft
> **Author:** Tech Lead

---

## 1. Tổng quan kỹ thuật

Thêm màn hình **Order List** (`/orders`) vào Supplier Web. Đây là màn hình đầu tiên có business logic sau màn hình Dashboard (hiện đang là placeholder).

**Stack áp dụng:** React 19 · Vite 7 · TanStack Query v5 · Redux Toolkit v2 · Ant Design v6 · TailwindCSS v4 · react-router-dom v7

**Quyết định kỹ thuật:**
- Server state (danh sách đơn, badge) → **TanStack Query** (không dùng Redux)
- Client state (active tab, search form) → **local state** (useState) — không cần Redux slice vì không chia sẻ global
- Date picker → **Ant Design DatePicker** (đã có trong theme hiện tại)
- Tab component → **Ant Design Tabs** với badge từ `Ant Design Badge`

---

## 2. Routes & Navigation

### 2.1 Cập nhật `constants/route.ts`

```typescript
export const ROUTE = {
  INDEX: "/",
  DASHBOARD: "/dashboard",
  ORDERS: "/orders",          // MỚI
  LOGIN: "/login",
  LOGOUT: "/api/auth/signout",
  FORGOT_PASSWORD: "/forgot-password",
  VERIFY: "/verify",
  RESET_PASSWORD: "/reset-password",
  RESET_SUCCESS: "/reset-success",
};
```

### 2.2 Cập nhật `constants/nav.ts`

```typescript
import { DashboardIcon, OrderIcon } from "../statics/icons/nav-icons";

export const NAV_ITEMS: NavItem[] = [
  {
    key: "dashboard",
    labelJa: "ダッシュボード",
    icon: DashboardIcon,
    href: ROUTE.DASHBOARD,
  },
  {
    key: "orders",
    labelJa: "注文一覧",   // "Order List"
    icon: OrderIcon,
    href: ROUTE.ORDERS,
  },
];
```

### 2.3 Cập nhật router

```typescript
// Thêm route vào App.tsx hoặc router config
<Route path={ROUTE.ORDERS} element={<OrderListPage />} />
```

---

## 3. API Service Layer

### 3.1 Types

File: `src/types/purchase-order.ts` *(MỚI)*

```typescript
export enum PurchaseOrderStatus {
  WAITING_DELIVERY_DATE = 'WAITING_DELIVERY_DATE',
  WAITING_SHIPMENT      = 'WAITING_SHIPMENT',
  SHIPPED               = 'SHIPPED',
}

export interface PurchaseOrderItem {
  id: string;
  orderNumber: string;
  orderDate: string;           // ISO string
  productName: string;
  productCount: number;
  status: PurchaseOrderStatus;
  desiredDeliveryDate: string | null;    // YYYY-MM-DD
  scheduledShipmentDate: string | null;  // YYYY-MM-DD
  shipmentDate: string | null;           // YYYY-MM-DD
  quantity: number;
  trackingNumber: string | null;
}

export interface PurchaseOrderListResponse {
  items: PurchaseOrderItem[];
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
  shipmentDateFrom?: string;  // YYYY-MM-DD
  shipmentDateTo?: string;    // YYYY-MM-DD
  page?: number;
  limit?: number;
}
```

### 3.2 Service

File: `src/services/client/order.service.ts` *(MỚI)*

```typescript
import API from './api';
import type {
  PurchaseOrderListResponse,
  PurchaseOrderBadgeCount,
  ListOrdersParams,
} from '../../types/purchase-order';

export const orderService = {
  getOrders: (params: ListOrdersParams): Promise<{ data: PurchaseOrderListResponse }> =>
    API.get('/supplier/orders', params),

  getBadgeCount: (): Promise<{ data: PurchaseOrderBadgeCount }> =>
    API.get('/supplier/orders/badge-count'),
};
```

---

## 4. TanStack Query Hooks

File: `src/hooks/useOrderList.ts` *(MỚI)*

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
    staleTime: 30_000,  // 30s — danh sách không cần real-time
  });
}

export function useOrderBadgeCount() {
  return useQuery({
    queryKey: ORDER_QUERY_KEYS.badge(),
    queryFn: () => orderService.getBadgeCount(),
    select: (res) => res.data,
    refetchInterval: 60_000,  // poll 60s — sync với Redis TTL
    staleTime: 30_000,
  });
}
```

---

## 5. Component Structure

```
src/
├── pages/
│   └── orders/
│       └── OrderListPage.tsx           ← MỚI: route component, compose các sub-components
├── components/
│   └── orders/
│       ├── OrderStatusTabs.tsx         ← MỚI: AntD Tabs + Badge per tab
│       ├── OrderSearchForm.tsx         ← MỚI: DatePicker range + Status dropdown
│       └── OrderListTable.tsx          ← MỚI: AntD Table với 9 cột
├── hooks/
│   └── useOrderList.ts                 ← MỚI (xem section 4)
├── services/
│   └── client/
│       └── order.service.ts            ← MỚI (xem section 3.2)
└── types/
    └── purchase-order.ts               ← MỚI (xem section 3.1)
```

---

## 6. Component Design

### 6.1 `OrderListPage.tsx`

Trách nhiệm: orchestrator — quản lý active tab state, search params, truyền xuống các sub-component.

```typescript
interface SearchState {
  shipmentDateFrom?: string;
  shipmentDateTo?: string;
}

export default function OrderListPage() {
  const [activeTab, setActiveTab] = useState<PurchaseOrderStatus>(
    PurchaseOrderStatus.WAITING_DELIVERY_DATE,
  );
  const [search, setSearch] = useState<SearchState>({});
  const [page, setPage] = useState(1);

  const params: ListOrdersParams = {
    status: activeTab,
    ...search,
    page,
    limit: 20,
  };

  const { data, isLoading } = useOrderList(params);
  const { data: badgeCount } = useOrderBadgeCount();

  const handleTabChange = (tab: PurchaseOrderStatus) => {
    setActiveTab(tab);
    setPage(1);  // reset pagination khi đổi tab
  };

  const handleSearch = (values: SearchState) => {
    setSearch(values);
    setPage(1);
  };

  return (
    <div className="py-6">
      <h1 className="mb-4 text-2xl font-bold text-neutral-800">注文一覧</h1>

      <OrderStatusTabs
        activeTab={activeTab}
        badgeCount={badgeCount}
        onChange={handleTabChange}
      />

      <OrderSearchForm onSearch={handleSearch} />

      <OrderListTable
        items={data?.items ?? []}
        total={data?.total ?? 0}
        page={page}
        limit={20}
        loading={isLoading}
        onPageChange={setPage}
      />
    </div>
  );
}
```

---

### 6.2 `OrderStatusTabs.tsx`

```typescript
interface OrderStatusTabsProps {
  activeTab: PurchaseOrderStatus;
  badgeCount?: PurchaseOrderBadgeCount;
  onChange: (tab: PurchaseOrderStatus) => void;
}

const TAB_CONFIG = [
  {
    key: PurchaseOrderStatus.WAITING_DELIVERY_DATE,
    label: '配送日回答待ち',    // Waiting for Delivery Date Response
    badgeKey: 'waitingDeliveryDate' as const,
  },
  {
    key: PurchaseOrderStatus.WAITING_SHIPMENT,
    label: '出荷待ち',           // Waiting for Shipment
    badgeKey: 'waitingShipment' as const,
  },
  {
    key: PurchaseOrderStatus.SHIPPED,
    label: '出荷済み',           // Shipped
    badgeKey: 'shipped' as const,
  },
];

export const OrderStatusTabs: React.FC<OrderStatusTabsProps> = ({
  activeTab,
  badgeCount,
  onChange,
}) => {
  const items = TAB_CONFIG.map(({ key, label, badgeKey }) => ({
    key,
    label: (
      <Badge count={badgeCount?.[badgeKey] ?? 0} offset={[8, -2]}>
        {label}
      </Badge>
    ),
  }));

  return (
    <Tabs
      activeKey={activeTab}
      items={items}
      onChange={(key) => onChange(key as PurchaseOrderStatus)}
      className="mb-4"
    />
  );
};
```

---

### 6.3 `OrderSearchForm.tsx`

```typescript
interface SearchFormValues {
  shipmentDateRange?: [Dayjs | null, Dayjs | null];
}

interface OrderSearchFormProps {
  onSearch: (params: SearchState) => void;
}

export const OrderSearchForm: React.FC<OrderSearchFormProps> = ({ onSearch }) => {
  const [form] = Form.useForm<SearchFormValues>();

  const handleFinish = (values: SearchFormValues) => {
    const [from, to] = values.shipmentDateRange ?? [null, null];
    onSearch({
      shipmentDateFrom: from?.format('YYYY-MM-DD'),
      shipmentDateTo: to?.format('YYYY-MM-DD'),
    });
  };

  const handleReset = () => {
    form.resetFields();
    onSearch({});
  };

  return (
    <Form form={form} layout="inline" onFinish={handleFinish} className="mb-4">
      <Form.Item name="shipmentDateRange" label="出荷日">
        <DatePicker.RangePicker format="YYYY/MM/DD" />
      </Form.Item>
      <Form.Item>
        <Button type="primary" htmlType="submit">検索</Button>
        <Button onClick={handleReset} className="ml-2">リセット</Button>
      </Form.Item>
    </Form>
  );
};
```

> **Lưu ý:** Search theo Status đã được xử lý qua Tab — không cần dropdown Status riêng khi tab đang active. Nếu khách hàng confirm cần search cross-tab theo Status, thêm `<Select>` cho `status` vào form này.

---

### 6.4 `OrderListTable.tsx`

```typescript
interface OrderListTableProps {
  items: PurchaseOrderItem[];
  total: number;
  page: number;
  limit: number;
  loading: boolean;
  onPageChange: (page: number) => void;
}

const STATUS_LABEL: Record<PurchaseOrderStatus, string> = {
  [PurchaseOrderStatus.WAITING_DELIVERY_DATE]: '配送日回答待ち',
  [PurchaseOrderStatus.WAITING_SHIPMENT]:      '出荷待ち',
  [PurchaseOrderStatus.SHIPPED]:               '出荷済み',
};

const columns: TableColumnsType<PurchaseOrderItem> = [
  {
    title: '注文番号',
    dataIndex: 'orderNumber',
    key: 'orderNumber',
  },
  {
    title: '注文日',
    dataIndex: 'orderDate',
    key: 'orderDate',
    render: (v: string) => dayjs(v).format('YYYY/MM/DD'),
  },
  {
    title: '商品名',
    dataIndex: 'productName',
    key: 'productName',
    render: (name: string, record) =>
      record.productCount > 1
        ? `${name}（他${record.productCount - 1}点）`  // TBD OQ-06
        : name,
  },
  {
    title: 'ステータス',
    dataIndex: 'status',
    key: 'status',
    render: (s: PurchaseOrderStatus) => STATUS_LABEL[s] ?? s,
  },
  {
    title: '希望納品日',
    dataIndex: 'desiredDeliveryDate',
    key: 'desiredDeliveryDate',
    render: (v: string | null) => v ?? '—',
  },
  {
    title: '出荷予定日',
    dataIndex: 'scheduledShipmentDate',
    key: 'scheduledShipmentDate',
    render: (v: string | null) => v ?? '—',
  },
  {
    title: '出荷日',
    dataIndex: 'shipmentDate',
    key: 'shipmentDate',
    render: (v: string | null) => v ?? '—',
  },
  {
    title: '数量',
    dataIndex: 'quantity',
    key: 'quantity',
    align: 'right',
  },
  {
    title: 'トラッキング番号',
    dataIndex: 'trackingNumber',
    key: 'trackingNumber',
    render: (v: string | null) => v ?? '—',
  },
];

export const OrderListTable: React.FC<OrderListTableProps> = ({
  items, total, page, limit, loading, onPageChange,
}) => (
  <Table
    rowKey="id"
    dataSource={items}
    columns={columns}
    loading={loading}
    pagination={{
      current: page,
      pageSize: limit,
      total,
      onChange: onPageChange,
      showSizeChanger: false,
      showTotal: (t) => `全${t}件`,
    }}
    locale={{ emptyText: '注文がありません' }}
    scroll={{ x: 'max-content' }}
  />
);
```

---

## 7. Non-Regression Risks

| Risk | Mức độ | Mitigation |
|---|---|---|
| Nav item mới làm layout bị lệch | Thấp | Test responsive layout sau khi thêm nav item |
| TanStack Query key trùng với query key của feature khác | Thấp | Dùng namespace `['supplier', 'orders', ...]` — đủ unique |
| AntD `Tabs` onChange gọi với string nhưng type là enum | Thấp | Cast `key as PurchaseOrderStatus` ở `onChange` handler |
| `refetchInterval: 60_000` trên badge-count gây quá nhiều request | Thấp | Chỉ active khi component mount — unmount tự cleanup |
| Route `/orders` bị redirect về login nếu auth guard thiếu | Trung bình | Kiểm tra `PrivateRoute` wrapper đã bao `OrderListPage` |

---

## 8. Self-Review Checklist

- [ ] TanStack Query v5 — object syntax, không positional
- [ ] `useQuery` không dùng `Redux` cho server state
- [ ] `staleTime` set hợp lý — không để default 0 tránh refetch liên tục
- [ ] `dayjs` format date output `YYYY/MM/DD` (Japanese convention)
- [ ] Table có `scroll={{ x: 'max-content' }}` tránh layout vỡ trên mobile
- [ ] Empty state tiếng Nhật: `'注文がありません'`
- [ ] Route `/orders` wrap trong PrivateRoute (auth guard)
- [ ] Nav item mới thêm vào `NAV_ITEMS` đúng order
- [ ] `OrderIcon` cần tạo hoặc tái sử dụng từ icon set hiện tại
