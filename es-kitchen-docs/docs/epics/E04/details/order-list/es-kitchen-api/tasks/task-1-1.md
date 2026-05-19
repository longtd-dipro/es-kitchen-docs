# [BE] [Supplier_Web] - Tạo entities, enum và migrations cho purchase_orders domain

## Backlog Info
- **Issue Type:** Task
- **Category:** Supplier_Web
- **Parent Issue:** E04 — Order List (Supplier Web)
- **Version:** Phase 2
- **Milestone:** Released W8 (Design Sign-off) / Go-live W31
- **Estimate Hour:** 4h
- **Actual Hour:** —
- **Status:** Open

## Metadata
- Phase: 1 | Repo: `es-kitchen-api` | Depends on: supplier-authentication migration (phải chạy trước)

## Mục tiêu
Tạo đầy đủ enum, entities TypeORM và 2 migration files cho domain `purchase_orders` — nền tảng cho toàn bộ feature Order List E04.

## Context (đọc trước khi code)
- DESIGN.md: `es-kitchen-docs/docs/epics/E04/details/order-list/es-kitchen-api/DESIGN.md` — Section 2
- Tham khảo entity hiện tại: `es-kitchen-repository/es-kitchen-api/src/entities/order.entity.ts`
- Migration pattern: xem các file trong `es-kitchen-repository/es-kitchen-api/src/migrations/`
- **Bắt buộc chạy sau** migration của supplier-authentication (bảng `suppliers` phải tồn tại trước)

## Yêu cầu implement

### 1. Enum
File: `src/commons/enums/purchase-order.enum.ts`

```typescript
export enum PurchaseOrderStatus {
  WAITING_DELIVERY_DATE = 'WAITING_DELIVERY_DATE',
  WAITING_SHIPMENT      = 'WAITING_SHIPMENT',
  SHIPPED               = 'SHIPPED',
}
```

### 2. Entity: PurchaseOrder
File: `src/entities/purchase-order.entity.ts`
- PK: bigint
- Các column: `order_number`, `supplier_id` (uuid), `company_id` (bigint), `status` (enum), `desired_delivery_date` (date nullable), `scheduled_shipment_date` (date nullable), `shipment_date` (date nullable), `tracking_number` (varchar 100 nullable)
- Relation: `@OneToMany` đến `PurchaseOrderItem` với `eager: false`
- 3 composite index: `(supplier_id, status)`, `(supplier_id, shipment_date)`, `(supplier_id, scheduled_shipment_date)`
- Có `deleted_at` (soft delete)
- Xem code đầy đủ trong DESIGN.md Section 2.2

### 3. Entity: PurchaseOrderItem
File: `src/entities/purchase-order-item.entity.ts`
- PK: bigint
- Các column: `purchase_order_id` (bigint FK), `product_id` (bigint nullable), `product_name` (varchar 500 snapshot), `quantity` (int)
- `@ManyToOne` → `PurchaseOrder` với `onDelete: 'CASCADE'`, `eager: false`
- Index: `(purchase_order_id)`
- **Không có** `deleted_at` — record bị xóa cascade khi order xóa
- Xem code đầy đủ trong DESIGN.md Section 2.3

### 4. Migration 1: CreatePurchaseOrdersTable
File: `src/migrations/<timestamp>-CreatePurchaseOrdersTable.ts`
- CREATE TYPE `purchase_order_status`
- CREATE TABLE `purchase_orders` với đầy đủ FK constraints
- FK `supplier_id → suppliers(id) ON DELETE RESTRICT`
- FK `company_id → companies(id) ON DELETE RESTRICT`
- Tạo 3 indexes
- `down()`: DROP TABLE → DROP TYPE (thứ tự ngược)

### 5. Migration 2: CreatePurchaseOrderItemsTable
File: `src/migrations/<timestamp>-CreatePurchaseOrderItemsTable.ts`
- CREATE TABLE `purchase_order_items`
- FK `purchase_order_id → purchase_orders(id) ON DELETE CASCADE`
- FK `product_id → products(id) ON DELETE SET NULL`
- `down()`: DROP TABLE

## Unit Tests (BẮT BUỘC)
- File: không cần spec riêng cho entity/enum — coverage được kiểm tra qua service tests (task-2-1)
- **Verify migration**: sau khi chạy `npm run migration:run`, kiểm tra trong DB:
  ```sql
  SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
  WHERE table_name IN ('purchase_orders', 'purchase_order_items')
  ORDER BY table_name, ordinal_position;
  ```
- Verify rollback: `npm run migration:revert` không có lỗi

## Non-Regression Table
| Tính năng | File liên quan | Cách verify |
|---|---|---|
| Bảng `orders` (E01/E02) | `src/entities/order.entity.ts` | Không chạm → không cần verify |
| Supplier entity | `src/entities/supplier.entity.ts` (sau auth task) | FK `supplier_id` trỏ đúng → verify bằng migration |
| TypeORM DataSource | `src/database/data-source.ts` | Thêm 2 entity mới vào `entities[]` array |

## Không được làm
- Không sửa bảng `orders` hoặc `order_details` hiện tại
- Không đặt `eager: true` trên bất kỳ relation nào
- Không hard-code timestamp trong tên migration file (dùng `Date.now()` hoặc format `YYYYMMDDHHmmss`)

## Definition of Done
- [ ] Build pass: `npm run build`
- [ ] Lint pass: `npm run lint`
- [ ] Migration up/down không lỗi trên DEV DB
- [ ] 3 entities + 1 enum tồn tại đúng path
- [ ] TypeORM DataSource đã include 2 entity mới
- [ ] Actual Hour cập nhật
- [ ] Status chuyển → Request Review
