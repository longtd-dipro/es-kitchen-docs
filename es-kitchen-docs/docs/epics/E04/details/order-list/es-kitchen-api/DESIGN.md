# DESIGN: Order List — es-kitchen-api

> **Epic:** E04 — Supplier Web
> **SPEC:** `../SPEC.md`
> **Date:** 19/05/2026
> **Status:** Draft
> **Author:** Tech Lead

---

## 1. Tổng quan kỹ thuật

Feature cung cấp 2 API endpoint dưới prefix `/supplier/orders` phục vụ màn hình Order List của Supplier Web (E04).

**Domain mới: Purchase Order (B2B)**
Đây là domain hoàn toàn tách biệt với bảng `orders` hiện tại (dành cho E01 — consumer mobile orders). `purchase_orders` là đơn hàng nhập hàng từ Company gửi đến Supplier, không có quan hệ gì với payment flow của E01.

**Quyết định kỹ thuật cho Open Questions trong SPEC:**
- **OQ-01 (Status trung gian):** Không có trạng thái trung gian — flow là 3 bước: `WAITING_DELIVERY_DATE` → `WAITING_SHIPMENT` → `SHIPPED`. "Delivery Date Response Provided" trong spec gốc là tên hiển thị tiếng Anh cho status `WAITING_SHIPMENT`.
- **OQ-06 (Product Name nhiều sản phẩm):** Nếu 1 đơn có nhiều items → hiển thị tên item đầu tiên + suffix `(他N点)` *(TBD — confirm client)*. API trả về `productName` (string) + `productCount` (int) để FE tự render.
- **OQ-11 (Pagination):** Có pagination. Default `limit=20`, dùng offset-based giống pattern hiện tại của codebase.
- **Badge (OQ-04, OQ-05):** Badge = tổng đơn **chưa xử lý tích lũy** (không reset khi xem tab). Invalidate cache khi status thay đổi (action thuộc feature Order Detail).

---

## 2. Database Changes

### 2.1 Enum: `PurchaseOrderStatus`

File: `src/commons/enums/purchase-order.enum.ts`

```typescript
export enum PurchaseOrderStatus {
  WAITING_DELIVERY_DATE = 'WAITING_DELIVERY_DATE',
  WAITING_SHIPMENT      = 'WAITING_SHIPMENT',
  SHIPPED               = 'SHIPPED',
}
```

---

### 2.2 Entity: `PurchaseOrder`

File: `src/entities/purchase-order.entity.ts`

```typescript
import {
  Column,
  CreateDateColumn,
  DeleteDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { PurchaseOrderStatus } from '../commons/enums/purchase-order.enum';
import { PurchaseOrderItem } from './purchase-order-item.entity';

@Index('idx_po_supplier_status', ['supplierId', 'status'])
@Index('idx_po_supplier_shipment_date', ['supplierId', 'shipmentDate'])
@Index('idx_po_supplier_scheduled_date', ['supplierId', 'scheduledShipmentDate'])
@Entity({ name: 'purchase_orders' })
export class PurchaseOrder {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id: string;

  @Column({ name: 'order_number', type: 'varchar', length: 20, unique: true })
  orderNumber: string;

  @Column({ name: 'supplier_id', type: 'uuid' })
  supplierId: string;

  @Column({ name: 'company_id', type: 'bigint' })
  companyId: string;

  @Column({
    type: 'enum',
    enum: PurchaseOrderStatus,
    default: PurchaseOrderStatus.WAITING_DELIVERY_DATE,
  })
  status: PurchaseOrderStatus;

  @Column({ name: 'desired_delivery_date', type: 'date', nullable: true })
  desiredDeliveryDate: string | null;

  @Column({ name: 'scheduled_shipment_date', type: 'date', nullable: true })
  scheduledShipmentDate: string | null;

  @Column({ name: 'shipment_date', type: 'date', nullable: true })
  shipmentDate: string | null;

  @Column({ name: 'tracking_number', type: 'varchar', length: 100, nullable: true })
  trackingNumber: string | null;

  @OneToMany(() => PurchaseOrderItem, (item) => item.purchaseOrder, {
    cascade: true,
    eager: false,
  })
  items: PurchaseOrderItem[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;
}
```

**Ghi chú:**
- `supplier_id`: UUID FK trỏ đến `suppliers.id` (entity `Supplier` từ auth DESIGN)
- `company_id`: bigint FK trỏ đến `companies.id`
- `desired_delivery_date`: ngày mong muốn từ phía Company, nullable (TBD business rule)
- `scheduled_shipment_date`: Supplier điền khi phản hồi ngày giao — trigger chuyển sang `WAITING_SHIPMENT`
- `shipment_date`: ngày thực tế xuất hàng — Supplier điền khi confirm ship
- `tracking_number`: nhập tay (scope carrier API integration = Out of Scope)

---

### 2.3 Entity: `PurchaseOrderItem`

File: `src/entities/purchase-order-item.entity.ts`

```typescript
import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { PurchaseOrder } from './purchase-order.entity';

@Index('idx_poi_purchase_order', ['purchaseOrderId'])
@Entity({ name: 'purchase_order_items' })
export class PurchaseOrderItem {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id: string;

  @Column({ name: 'purchase_order_id', type: 'bigint' })
  purchaseOrderId: string;

  @Column({ name: 'product_id', type: 'bigint', nullable: true })
  productId: string | null;

  @Column({ name: 'product_name', type: 'varchar', length: 500 })
  productName: string;

  @Column({ type: 'int' })
  quantity: number;

  @ManyToOne(() => PurchaseOrder, (po) => po.items, {
    onDelete: 'CASCADE',
    eager: false,
  })
  @JoinColumn({ name: 'purchase_order_id' })
  purchaseOrder: PurchaseOrder;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
```

**Ghi chú:**
- `product_name`: snapshot tại thời điểm tạo đơn — không phụ thuộc sự tồn tại của product
- `product_id`: nullable + `ON DELETE SET NULL` — products có thể bị soft-delete sau khi đơn tạo

---

### 2.4 Migrations

#### Migration 1: `CreatePurchaseOrdersTable`

File: `src/migrations/<timestamp>-CreatePurchaseOrdersTable.ts`

```typescript
import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePurchaseOrdersTable<timestamp> implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE purchase_order_status AS ENUM (
        'WAITING_DELIVERY_DATE',
        'WAITING_SHIPMENT',
        'SHIPPED'
      )
    `);

    await queryRunner.query(`
      CREATE TABLE purchase_orders (
        id                      BIGSERIAL PRIMARY KEY,
        order_number            VARCHAR(20)             NOT NULL UNIQUE,
        supplier_id             UUID                    NOT NULL,
        company_id              BIGINT                  NOT NULL,
        status                  purchase_order_status   NOT NULL DEFAULT 'WAITING_DELIVERY_DATE',
        desired_delivery_date   DATE,
        scheduled_shipment_date DATE,
        shipment_date           DATE,
        tracking_number         VARCHAR(100),
        created_at              TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
        updated_at              TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
        deleted_at              TIMESTAMPTZ,
        CONSTRAINT fk_po_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT,
        CONSTRAINT fk_po_company  FOREIGN KEY (company_id)  REFERENCES companies(id) ON DELETE RESTRICT
      )
    `);

    await queryRunner.query(`
      CREATE INDEX idx_po_supplier_status         ON purchase_orders (supplier_id, status);
      CREATE INDEX idx_po_supplier_shipment_date  ON purchase_orders (supplier_id, shipment_date);
      CREATE INDEX idx_po_supplier_scheduled_date ON purchase_orders (supplier_id, scheduled_shipment_date);
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS purchase_orders`);
    await queryRunner.query(`DROP TYPE IF EXISTS purchase_order_status`);
  }
}
```

#### Migration 2: `CreatePurchaseOrderItemsTable`

File: `src/migrations/<timestamp>-CreatePurchaseOrderItemsTable.ts`

```typescript
import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePurchaseOrderItemsTable<timestamp> implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE purchase_order_items (
        id                  BIGSERIAL PRIMARY KEY,
        purchase_order_id   BIGINT          NOT NULL,
        product_id          BIGINT,
        product_name        VARCHAR(500)    NOT NULL,
        quantity            INT             NOT NULL,
        created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
        updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_poi_purchase_order FOREIGN KEY (purchase_order_id)
          REFERENCES purchase_orders(id) ON DELETE CASCADE,
        CONSTRAINT fk_poi_product FOREIGN KEY (product_id)
          REFERENCES products(id) ON DELETE SET NULL
      )
    `);

    await queryRunner.query(`
      CREATE INDEX idx_poi_purchase_order ON purchase_order_items (purchase_order_id);
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS purchase_order_items`);
  }
}
```

---

## 3. Redis Cache

### 3.1 Key schema

| Key | Value | TTL | Invalidate khi |
|---|---|---|---|
| `supplier:orders:badge:{supplierId}` | `{waitingDeliveryDate: N, waitingShipment: N, shipped: N}` (JSON string) | 60s | Status của bất kỳ purchase_order thuộc supplier thay đổi |

### 3.2 Badge cache flow

```
GET /supplier/orders/badge-count
  ├── Redis HIT  → return cached JSON
  └── Redis MISS → SELECT COUNT(*) GROUP BY status FROM purchase_orders WHERE supplier_id = ?
                   → SET key (TTL 60s) → return
```

Invalidation: khi Order Detail feature implement PATCH endpoints → gọi `redis.del('supplier:orders:badge:{supplierId}')` sau khi update status.

---

## 4. API Contract

**Prefix:** `/supplier/orders`
**Guard:** `SupplierGuard` (JWT — supplier-jwt strategy, từ auth DESIGN)
**Auth:** Bearer token (access token)

---

### 4.1 `GET /supplier/orders`

**Mục đích:** Lấy danh sách purchase orders của supplier đang đăng nhập, filter theo tab (status) và search criteria.

**Request — Query params:**

```typescript
// src/modules/supplier/http/requests/list-purchase-orders.request.ts
export class ListPurchaseOrdersRequest {
  @IsOptional()
  @IsEnum(PurchaseOrderStatus)
  status?: PurchaseOrderStatus;

  @IsOptional()
  @IsDateString()
  shipmentDateFrom?: string; // YYYY-MM-DD

  @IsOptional()
  @IsDateString()
  shipmentDateTo?: string;   // YYYY-MM-DD

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  get skip(): number {
    return ((this.page ?? 1) - 1) * (this.limit ?? 20);
  }
}
```

**Response — 200 OK:**

```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": "1",
        "orderNumber": "PO-20260519-001",
        "orderDate": "2026-05-19T09:00:00.000Z",
        "productName": "商品名A",
        "productCount": 1,
        "status": "WAITING_DELIVERY_DATE",
        "desiredDeliveryDate": "2026-05-25",
        "scheduledShipmentDate": null,
        "shipmentDate": null,
        "quantity": 10,
        "trackingNumber": null
      }
    ],
    "total": 50,
    "page": 1,
    "limit": 20,
    "totalPages": 3
  }
}
```

**Response fields:**

| Field | Type | Mô tả |
|---|---|---|
| `id` | string | PK của purchase_order |
| `orderNumber` | string | Mã đơn hàng |
| `orderDate` | ISO string | `created_at` của đơn |
| `productName` | string | Tên sản phẩm (item đầu tiên) |
| `productCount` | number | Số lượng loại sản phẩm trong đơn |
| `status` | enum | Trạng thái hiện tại |
| `desiredDeliveryDate` | string \| null | Ngày giao mong muốn (YYYY-MM-DD) |
| `scheduledShipmentDate` | string \| null | Ngày giao dự kiến Supplier phản hồi |
| `shipmentDate` | string \| null | Ngày xuất hàng thực tế |
| `quantity` | number | Tổng quantity của tất cả items |
| `trackingNumber` | string \| null | Mã vận đơn |

**Error codes:**

| HTTP | Code | Message |
|---|---|---|
| 401 | 401 | Unauthorized |

**Query logic (service):**

```typescript
const qb = this.purchaseOrderRepository
  .createQueryBuilder('po')
  .leftJoin('po.items', 'item')
  .where('po.supplierId = :supplierId', { supplierId })
  .andWhere('po.deletedAt IS NULL');

if (query.status) {
  qb.andWhere('po.status = :status', { status: query.status });
}

// Search by shipment date — dùng scheduled_shipment_date khi status = WAITING_SHIPMENT
// hoặc shipment_date khi status = SHIPPED. Không có status filter → áp dụng cả 2.
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

// Subquery: total quantity
qb.addSelect((sub) =>
  sub.select('COALESCE(SUM(i.quantity), 0)')
     .from('purchase_order_items', 'i')
     .where('i.purchaseOrderId = po.id'),
  'totalQuantity',
);

// Subquery: first product name
qb.addSelect((sub) =>
  sub.select('i2.productName')
     .from('purchase_order_items', 'i2')
     .where('i2.purchaseOrderId = po.id')
     .orderBy('i2.id', 'ASC')
     .limit(1),
  'firstProductName',
);

// Subquery: product count
qb.addSelect((sub) =>
  sub.select('COUNT(*)')
     .from('purchase_order_items', 'i3')
     .where('i3.purchaseOrderId = po.id'),
  'productCount',
);

qb.orderBy('po.createdAt', 'DESC');
```

> **ORDER_BY_MAP pattern không cần** vì không có user-controlled orderBy trong feature này — chỉ sort theo `createdAt DESC` cố định.

---

### 4.2 `GET /supplier/orders/badge-count`

**Mục đích:** Trả về số đơn chưa xử lý theo từng trạng thái để hiển thị badge trên tab.

**Request:** Không có query params.

**Response — 200 OK:**

```json
{
  "code": 200,
  "data": {
    "waitingDeliveryDate": 5,
    "waitingShipment": 3,
    "shipped": 0
  }
}
```

**Logic:**
1. Check Redis key `supplier:orders:badge:{supplierId}`
2. HIT → parse JSON → return
3. MISS → query DB:

```sql
SELECT status, COUNT(*) as cnt
FROM purchase_orders
WHERE supplier_id = $1
  AND deleted_at IS NULL
GROUP BY status;
```

4. Map kết quả → SET Redis (TTL 60s) → return

**Error codes:**

| HTTP | Code | Message |
|---|---|---|
| 401 | 401 | Unauthorized |

---

## 5. Module Structure

```
src/modules/supplier/
├── supplier.module.ts                          ← CẬP NHẬT: thêm PurchaseOrder + PurchaseOrderItem repositories
├── supplier.guard.ts                           ← không đổi
├── http/
│   └── controllers/
│       ├── auth.controller.ts                  ← không đổi
│       └── order.controller.ts                 ← MỚI
├── services/
│   ├── auth.service.ts                         ← không đổi
│   └── order.service.ts                        ← MỚI
└── http/
    ├── requests/
    │   └── list-purchase-orders.request.ts     ← MỚI
    └── responses/
        ├── purchase-order-list.response.ts     ← MỚI
        └── purchase-order-badge.response.ts    ← MỚI
```

```
src/entities/
├── purchase-order.entity.ts                    ← MỚI
└── purchase-order-item.entity.ts              ← MỚI
```

```
src/commons/enums/
└── purchase-order.enum.ts                      ← MỚI
```

### 5.1 `order.controller.ts` (skeleton)

```typescript
@Controller('supplier/orders')
@ApiTags('Supplier — Orders')
@ApiBearerAuth()
@UseGuards(SupplierGuard)
export class SupplierOrderController {
  constructor(private readonly orderService: SupplierOrderService) {}

  @Get()
  async listOrders(
    @GetUser() supplier: JwtPayload,
    @Query() query: ListPurchaseOrdersRequest,
  ) { ... }

  @Get('badge-count')
  async getBadgeCount(@GetUser() supplier: JwtPayload) { ... }
}
```

### 5.2 Update `supplier.module.ts`

```typescript
@Module({
  imports: [
    TypeOrmModule.forFeature([
      Supplier,
      SupplierPasswordResetToken,
      PurchaseOrder,       // MỚI
      PurchaseOrderItem,   // MỚI
    ]),
    // ... existing
  ],
  controllers: [
    SupplierAuthController,
    SupplierOrderController, // MỚI
  ],
  providers: [
    SupplierAuthService,
    SupplierOrderService,    // MỚI
    // ... existing
  ],
})
export class SupplierModule {}
```

---

## 6. Non-Regression Risks

| Risk | Mức độ | Mitigation |
|---|---|---|
| `orders` table (E01/E02) bị ảnh hưởng | **Không có** — đây là bảng mới `purchase_orders`, hoàn toàn tách biệt | — |
| `supplier.module.ts` có circular dependency khi thêm OrderService | Thấp | Kiểm tra imports trước khi merge |
| `products.id` FK trong `purchase_order_items` — product bị hard-delete | Thấp | FK dùng `ON DELETE SET NULL`, entity `product_id` nullable |
| `suppliers.id` FK trong `purchase_orders` — supplier bị xóa | Thấp | FK dùng `ON DELETE RESTRICT` — phải xử lý đơn hàng trước khi xóa supplier |
| `SupplierGuard` không được apply đúng trên `/supplier/orders` | Trung bình | Unit test guard trên controller |
| Migration chạy sai thứ tự (cần `suppliers` + `companies` tồn tại trước) | Trung bình | Đặt timestamp migration sau migration của supplier-authentication |

---

## 7. Self-Review Checklist

- [ ] Entity dùng `name` explicit cho tất cả `@Column`
- [ ] Relation dùng `eager: false`
- [ ] `SupplierGuard` apply đúng trên cả 2 endpoint
- [ ] `ListPurchaseOrdersRequest` có `@IsOptional()` trên tất cả fields
- [ ] Subquery trong service dùng alias unique, không trùng alias hiện tại
- [ ] Redis TTL 60s — không cache quá lâu khi badge thay đổi thường xuyên
- [ ] Migration timestamp đúng thứ tự sau supplier-auth migrations
- [ ] `purchase_order_items.product_id` FK là `ON DELETE SET NULL`
