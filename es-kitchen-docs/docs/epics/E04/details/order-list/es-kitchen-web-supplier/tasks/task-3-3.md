# [FE] [Supplier_Web] - Implement OrderListTable + OrderListPage (compose)

## Backlog Info
- **Issue Type:** Task
- **Category:** Supplier_Web
- **Parent Issue:** E04 — Order List (Supplier Web)
- **Version:** Phase 2
- **Milestone:** Released W8 / Go-live W31
- **Estimate Hour:** 6h
- **Actual Hour:** —
- **Status:** Open

## Metadata
- Phase: 3 | Repo: `es-kitchen-web-supplier` | Depends on: task-3-1, task-3-2 (tất cả components + hooks phải sẵn)

## Mục tiêu
Implement `OrderListTable` (9 cột, pagination, empty state) và `OrderListPage` (orchestrator compose toàn bộ màn hình Order List), kết nối với API thực qua TanStack Query hooks.

## Context (đọc trước khi code)
- DESIGN.md: `es-kitchen-docs/docs/epics/E04/details/order-list/es-kitchen-web-supplier/DESIGN.md` — Section 6.1, 6.4
- Types: `src/types/purchase-order.ts` (task-3-1)
- Hooks: `src/hooks/useOrderList.ts` (task-3-1)
- Components: `OrderStatusTabs`, `OrderSearchForm` (task-3-2)
- `SearchState` interface: export từ `OrderSearchForm.tsx`

## Yêu cầu implement

### 1. `OrderListTable`
File: `src/components/orders/OrderListTable.tsx` *(file mới)*

```typescript
interface OrderListTableProps {
  items: PurchaseOrderListItem[];
  total: number;
  page: number;
  limit: number;
  loading: boolean;
  onPageChange: (page: number) => void;
}
```

**9 cột cấu hình:**

| # | title (tiếng Nhật) | dataIndex | render |
|---|---|---|---|
| 1 | `注文番号` | `orderNumber` | plain text |
| 2 | `注文日` | `orderDate` | `dayjs(v).format('YYYY/MM/DD')` |
| 3 | `商品名` | `productName` | nếu `productCount > 1` → `${name}（他${productCount - 1}点）` |
| 4 | `ステータス` | `status` | map qua `STATUS_LABEL` constant |
| 5 | `希望納品日` | `desiredDeliveryDate` | `v ?? '—'` |
| 6 | `出荷予定日` | `scheduledShipmentDate` | `v ?? '—'` |
| 7 | `出荷日` | `shipmentDate` | `v ?? '—'` |
| 8 | `数量` | `quantity` | `align: 'right'` |
| 9 | `トラッキング番号` | `trackingNumber` | `v ?? '—'` |

```typescript
const STATUS_LABEL: Record<PurchaseOrderStatus, string> = {
  [PurchaseOrderStatus.WAITING_DELIVERY_DATE]: '配送日回答待ち',
  [PurchaseOrderStatus.WAITING_SHIPMENT]:      '出荷待ち',
  [PurchaseOrderStatus.SHIPPED]:               '出荷済み',
};
```

**Table props quan trọng:**
- `rowKey="id"`
- `scroll={{ x: 'max-content' }}` — tránh layout vỡ trên màn nhỏ
- `locale={{ emptyText: '注文がありません' }}`
- Pagination: `showSizeChanger: false`, `showTotal: (t) => \`全${t}件\``

### 2. `OrderListPage`
File: `src/pages/orders/OrderListPage.tsx` *(file mới)*

State management:
```typescript
const [activeTab, setActiveTab] = useState<PurchaseOrderStatus>(
  PurchaseOrderStatus.WAITING_DELIVERY_DATE,  // default Tab 1
);
const [search, setSearch] = useState<SearchState>({});
const [page, setPage] = useState(1);
```

Tổng hợp params và truyền xuống hooks:
```typescript
const params: ListOrdersParams = {
  status: activeTab,
  ...search,
  page,
  limit: 20,
};

const { data, isLoading } = useOrderList(params);
const { data: badgeCount } = useOrderBadgeCount();
```

Handler quan trọng:
- `handleTabChange`: setActiveTab + **reset page về 1**
- `handleSearch`: setSearch + **reset page về 1**
- `handlePageChange`: setPage trực tiếp

Layout (xem DESIGN Section 6.1 để reference):
```tsx
<div className="py-6">
  <h1 className="mb-4 text-2xl font-bold text-neutral-800">注文一覧</h1>
  <OrderStatusTabs activeTab={activeTab} badgeCount={badgeCount} onChange={handleTabChange} />
  <OrderSearchForm onSearch={handleSearch} />
  <OrderListTable
    items={data?.items ?? []}
    total={data?.total ?? 0}
    page={page}
    limit={20}
    loading={isLoading}
    onPageChange={handlePageChange}
  />
</div>
```

### 3. Verify route kết nối
Trong router config: xác nhận `<Route path="/orders" element={<OrderListPage />} />` đã wrap trong `PrivateRoute` (auth guard).

## Unit Tests (BẮT BUỘC)
- Files: `src/components/orders/OrderListTable.test.tsx`, `src/pages/orders/OrderListPage.test.tsx`
- Coverage target: 75%
- Verify: `npm run test -- OrderListTable` và `npm run test -- OrderListPage`

**OrderListTable test cases:**
```
✓ render đúng 9 header columns
✓ render đúng dữ liệu từng row
✓ format orderDate đúng YYYY/MM/DD
✓ productCount = 1 → hiển thị productName thuần
✓ productCount > 1 → hiển thị "名前（他N点）"
✓ null fields (desiredDeliveryDate, trackingNumber...) hiển thị "—"
✓ hiển thị empty state '注文がありません' khi items = []
✓ loading = true → AntD Table loading spinner
✓ pagination gọi onPageChange khi click
```

**OrderListPage test cases:**
```
✓ render h1 '注文一覧'
✓ default active tab = WAITING_DELIVERY_DATE
✓ đổi tab → reset page về 1
✓ submit search form → reset page về 1
✓ truyền đúng params xuống useOrderList (status = activeTab)
✓ hiển thị loading state khi isLoading = true
✓ render table với data từ hook
```

## Non-Regression Table
| Tính năng | File liên quan | Cách verify |
|---|---|---|
| Dashboard page | `pages/dashboard/DashboardPage.tsx` | Route `/dashboard` vẫn hoạt động sau khi thêm `/orders` |
| Auth pages (Login, etc.) | `pages/auth/` | Không chạm các file này |
| PrivateRoute logic | Layout/Router | Route `/orders` redirect về login khi chưa đăng nhập |
| Sidebar layout | Layout component | Nav item Orders hiển thị, không làm vỡ layout |

## Không được làm
- Không fetch data trong `OrderListTable` — chỉ nhận `items[]` qua props
- Không dùng Redux để lưu `activeTab`, `search`, `page` — dùng local `useState`
- Không thêm columns ngoài 9 cột đã định nghĩa trong SPEC

## Definition of Done
- [ ] Build pass
- [ ] Lint pass
- [ ] `OrderListTable` render đúng 9 cột với đúng format
- [ ] `OrderListPage` compose đủ 3 sub-components
- [ ] Đổi tab → reset page về 1
- [ ] Search → reset page về 1
- [ ] Empty state tiếng Nhật hiển thị khi không có data
- [ ] Route `/orders` đã wrap PrivateRoute
- [ ] Unit tests pass, coverage ≥ 75%
- [ ] Actual Hour cập nhật
- [ ] Status chuyển → Request Review
