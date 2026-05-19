# [FE] [Supplier_Web] - Implement OrderStatusTabs + OrderSearchForm components

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
- Phase: 3 | Repo: `es-kitchen-web-supplier` | Depends on: task-3-1 (types phải tồn tại)

## Mục tiêu
Implement 2 presentational components: `OrderStatusTabs` (3 tab + badge counter) và `OrderSearchForm` (date range picker), đủ để render độc lập và test.

## Context (đọc trước khi code)
- DESIGN.md: `es-kitchen-docs/docs/epics/E04/details/order-list/es-kitchen-web-supplier/DESIGN.md` — Section 6.2, 6.3
- Types: `src/types/purchase-order.ts` (từ task-3-1)
- AntD version: v6 — xem `antd-theme.ts` để biết token hiện tại

## Yêu cầu implement

### 1. `OrderStatusTabs`
File: `src/components/orders/OrderStatusTabs.tsx` *(file mới)*

```typescript
interface OrderStatusTabsProps {
  activeTab: PurchaseOrderStatus;
  badgeCount?: PurchaseOrderBadgeCount;
  onChange: (tab: PurchaseOrderStatus) => void;
}
```

Logic:
- Dùng `Tabs` từ AntD với `items` array
- Mỗi tab label wrap trong `<Badge count={...} offset={[8, -2]}>` — Badge hiện số ngay cạnh text tab
- Badge count = 0 → `showZero={false}` để ẩn badge (không hiển thị số 0)
- Tab config cố định (không từ API):

| key | labelJa | badgeKey |
|---|---|---|
| `WAITING_DELIVERY_DATE` | `配送日回答待ち` | `waitingDeliveryDate` |
| `WAITING_SHIPMENT` | `出荷待ち` | `waitingShipment` |
| `SHIPPED` | `出荷済み` | `shipped` |

- `onChange` callback: cast `key as PurchaseOrderStatus` trước khi gọi prop

### 2. `OrderSearchForm`
File: `src/components/orders/OrderSearchForm.tsx` *(file mới)*

```typescript
interface SearchFormValues {
  shipmentDateRange?: [Dayjs | null, Dayjs | null];
}

export interface SearchState {
  shipmentDateFrom?: string;  // YYYY-MM-DD
  shipmentDateTo?: string;
}

interface OrderSearchFormProps {
  onSearch: (params: SearchState) => void;
}
```

Logic:
- Dùng `Form`, `Form.Item`, `DatePicker.RangePicker` từ AntD
- Format hiển thị: `YYYY/MM/DD` (Japanese convention)
- Khi submit: convert Dayjs → string `YYYY-MM-DD` cho API
- Khi reset: `form.resetFields()` + gọi `onSearch({})` để clear filter
- Layout: `inline` với 2 button `検索` (primary) và `リセット`

```typescript
const handleFinish = (values: SearchFormValues) => {
  const [from, to] = values.shipmentDateRange ?? [null, null];
  onSearch({
    shipmentDateFrom: from?.format('YYYY-MM-DD') ?? undefined,
    shipmentDateTo:   to?.format('YYYY-MM-DD')   ?? undefined,
  });
};
```

## Unit Tests (BẮT BUỘC)
- Files: `src/components/orders/OrderStatusTabs.test.tsx`, `src/components/orders/OrderSearchForm.test.tsx`
- Coverage target: 80%
- Verify: `npm run test -- OrderStatusTabs` và `npm run test -- OrderSearchForm`

**OrderStatusTabs test cases:**
```
✓ render 3 tabs: 配送日回答待ち / 出荷待ち / 出荷済み
✓ active tab highlight đúng theo prop activeTab
✓ hiển thị badge number khi badgeCount > 0
✓ không hiển thị badge khi count = 0 (showZero false)
✓ gọi onChange với đúng PurchaseOrderStatus khi click tab
✓ render không lỗi khi badgeCount = undefined
```

**OrderSearchForm test cases:**
```
✓ render DatePicker.RangePicker với label "出荷日"
✓ render button 検索 và リセット
✓ submit: gọi onSearch với shipmentDateFrom/To đúng format YYYY-MM-DD
✓ submit với range trống: gọi onSearch({})
✓ reset: clear form và gọi onSearch({})
```

## Non-Regression Table
| Tính năng | File liên quan | Cách verify |
|---|---|---|
| AntD theme tokens | `shared/theme/antd-theme.ts` | Component không override global token |
| Dashboard page | `pages/dashboard/DashboardPage.tsx` | Không chạm file này |
| Sidebar nav layout | Layout component chứa nav | Thêm OrderIcon không làm layout bị vỡ — kiểm tra visual |

## Không được làm
- Không fetch data trong component này — chỉ nhận props, gọi callbacks
- Không dùng `defaultValue` cứng cho DatePicker — để mặc định empty
- Không thêm Status dropdown vào form (đã handle qua tab) trừ khi có yêu cầu rõ ràng

## Definition of Done
- [ ] Build pass
- [ ] Lint pass (không có `any` không cần thiết)
- [ ] `OrderStatusTabs` render đúng 3 tab với badge
- [ ] `OrderSearchForm` convert date sang YYYY-MM-DD đúng
- [ ] Unit tests pass, coverage ≥ 80%
- [ ] Actual Hour cập nhật
- [ ] Status chuyển → Request Review
