# [BE] [Supplier_Web] - Implement SupplierOrderService (list orders + badge count + Redis)

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
- Phase: 2 | Repo: `es-kitchen-api` | Depends on: task-1-1 (entities phải tồn tại)

## Mục tiêu
Implement `SupplierOrderService` với 2 methods: `listOrders` (query builder với filter/pagination) và `getBadgeCount` (Redis cache + DB fallback).

## Context (đọc trước khi code)
- DESIGN.md: `es-kitchen-docs/docs/epics/E04/details/order-list/es-kitchen-api/DESIGN.md` — Section 3, 4.1, 4.2
- Pattern tham khảo (query builder + pagination): `es-kitchen-repository/es-kitchen-api/src/modules/admin-company/services/order.service.ts`
- Redis pattern: tham khảo các service đã dùng Redis trong codebase (`tilth_search("redis.set")`)

## Yêu cầu implement

### File: `src/modules/supplier/services/order.service.ts`

```typescript
@Injectable()
export class SupplierOrderService {
  constructor(
    @InjectRepository(PurchaseOrder)
    private readonly purchaseOrderRepository: Repository<PurchaseOrder>,
    @Inject(CACHE_MANAGER) private readonly cache: Cache,  // hoặc Redis client theo pattern codebase
  ) {}

  async listOrders(supplierId: string, query: ListPurchaseOrdersRequest) { ... }
  async getBadgeCount(supplierId: string) { ... }
}
```

### Method `listOrders`:

```typescript
async listOrders(supplierId: string, query: ListPurchaseOrdersRequest) {
  const qb = this.purchaseOrderRepository
    .createQueryBuilder('po')
    .where('po.supplierId = :supplierId', { supplierId })
    .andWhere('po.deletedAt IS NULL');

  // Filter by status (tab)
  if (query.status) {
    qb.andWhere('po.status = :status', { status: query.status });
  }

  // Search by shipment date — OR logic: check cả 2 date fields
  if (query.shipmentDateFrom) {
    qb.andWhere(
      '(po.scheduledShipmentDate >= :from OR po.shipmentDate >= :from)',
      { from: query.shipmentDateFrom },
    );
  }
  if (query.shipmentDateTo) {
    qb.andWhere(
      '(po.scheduledShipmentDate <= :to OR po.shipmentDate <= :to)',
      { to: query.shipmentDateTo },
    );
  }

  qb.select([
    'po.id', 'po.orderNumber', 'po.status',
    'po.desiredDeliveryDate', 'po.scheduledShipmentDate',
    'po.shipmentDate', 'po.trackingNumber', 'po.createdAt',
  ]);

  // Subquery: tổng quantity (alias: totalQuantity)
  qb.addSelect((sub) =>
    sub.select('COALESCE(SUM(i.quantity), 0)')
       .from('purchase_order_items', 'i')
       .where('i.purchase_order_id = po.id'),
    'totalQuantity',
  );

  // Subquery: tên sản phẩm đầu tiên (alias: firstProductName)
  qb.addSelect((sub) =>
    sub.select('i2.product_name')
       .from('purchase_order_items', 'i2')
       .where('i2.purchase_order_id = po.id')
       .orderBy('i2.id', 'ASC')
       .limit(1),
    'firstProductName',
  );

  // Subquery: số lượng loại sản phẩm (alias: productCount)
  qb.addSelect((sub) =>
    sub.select('COUNT(*)')
       .from('purchase_order_items', 'i3')
       .where('i3.purchase_order_id = po.id'),
    'productCount',
  );

  qb.orderBy('po.createdAt', 'DESC')
    .limit(query.limit ?? 20)
    .offset(query.skip);

  const [{ entities, raw }, total] = await Promise.all([
    qb.getRawAndEntities(),
    qb.clone().getCount(),
  ]);

  // Map raw fields (subquery results) vào entities
  const items = entities.map((po) => {
    const rawRow = raw.find((r) => r.po_id === po.id);
    return {
      id: po.id,
      orderNumber: po.orderNumber,
      orderDate: po.createdAt,
      productName: rawRow?.firstProductName ?? '',
      productCount: Number(rawRow?.productCount ?? 0),
      status: po.status,
      desiredDeliveryDate: po.desiredDeliveryDate,
      scheduledShipmentDate: po.scheduledShipmentDate,
      shipmentDate: po.shipmentDate,
      quantity: Number(rawRow?.totalQuantity ?? 0),
      trackingNumber: po.trackingNumber,
    };
  });

  return {
    items,
    total,
    page: query.page ?? 1,
    limit: query.limit ?? 20,
    totalPages: Math.ceil(total / (query.limit ?? 20)),
  };
}
```

### Method `getBadgeCount`:

```typescript
async getBadgeCount(supplierId: string) {
  const cacheKey = `supplier:orders:badge:${supplierId}`;

  const cached = await this.cache.get<string>(cacheKey);
  if (cached) {
    return JSON.parse(cached);
  }

  const rows = await this.purchaseOrderRepository
    .createQueryBuilder('po')
    .select('po.status', 'status')
    .addSelect('COUNT(*)', 'cnt')
    .where('po.supplierId = :supplierId', { supplierId })
    .andWhere('po.deletedAt IS NULL')
    .groupBy('po.status')
    .getRawMany<{ status: string; cnt: string }>();

  const badge = {
    waitingDeliveryDate: 0,
    waitingShipment: 0,
    shipped: 0,
  };
  for (const row of rows) {
    if (row.status === PurchaseOrderStatus.WAITING_DELIVERY_DATE) badge.waitingDeliveryDate = Number(row.cnt);
    if (row.status === PurchaseOrderStatus.WAITING_SHIPMENT)      badge.waitingShipment      = Number(row.cnt);
    if (row.status === PurchaseOrderStatus.SHIPPED)               badge.shipped              = Number(row.cnt);
  }

  await this.cache.set(cacheKey, JSON.stringify(badge), 60_000); // TTL 60s

  return badge;
}
```

## Unit Tests (BẮT BUỘC)
- File: `src/modules/supplier/services/order.service.spec.ts`
- Coverage target: 85%
- Verify: `npm run test -- order.service.spec`

**Test cases bắt buộc:**

```
describe('listOrders')
  ✓ trả về danh sách đúng khi không có filter
  ✓ filter đúng theo status
  ✓ filter đúng theo shipmentDateFrom và shipmentDateTo
  ✓ pagination: skip = (page - 1) * limit
  ✓ trả về productName = tên item đầu tiên
  ✓ trả về productCount đúng khi 1 item
  ✓ trả về productCount đúng khi nhiều items
  ✓ trả về totalQuantity = tổng quantity tất cả items
  ✓ không trả về đơn của supplier khác (isolation)
  ✓ không trả về đơn đã soft-delete

describe('getBadgeCount')
  ✓ trả về từ Redis cache khi HIT
  ✓ query DB khi cache MISS và lưu vào Redis
  ✓ count đúng 0 khi không có đơn ở trạng thái đó
  ✓ count đúng khi có đơn ở nhiều trạng thái
```

## Non-Regression Table
| Tính năng | File liên quan | Cách verify |
|---|---|---|
| admin-company OrderService | `modules/admin-company/services/order.service.ts` | Không chạm → không cần verify |
| Redis cache key namespace | Existing cache keys | Pattern `supplier:orders:badge:*` — không trùng với key hiện tại |
| PurchaseOrder entity relation | `purchase-order.entity.ts` | Subquery dùng raw SQL alias, không trigger eager load |

## Không được làm
- Không dùng `find()` hoặc `findOne()` cho list query — dùng `createQueryBuilder`
- Không sort theo user-controlled field — chỉ `po.createdAt DESC` cố định
- Không để `eager: true` trên relation trong entity
- Không cache list result — chỉ cache badge count

## Definition of Done
- [ ] Build pass
- [ ] Lint pass
- [ ] Unit tests pass, coverage ≥ 85%
- [ ] Cache key format đúng: `supplier:orders:badge:{supplierId}`
- [ ] Subquery aliases không trùng nhau (`totalQuantity`, `firstProductName`, `productCount`)
- [ ] Actual Hour cập nhật
- [ ] Status chuyển → Request Review
