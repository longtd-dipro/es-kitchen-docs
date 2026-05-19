# [BE] [Supplier_Web] - Implement SupplierOrderController + DTO/Response + cập nhật supplier.module.ts

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
- Phase: 2 | Repo: `es-kitchen-api` | Depends on: task-2-1 (SupplierOrderService phải tồn tại)

## Mục tiêu
Tạo HTTP layer cho Supplier Order API: request DTO, response class, controller với 2 endpoints, và cập nhật `supplier.module.ts` để wire toàn bộ.

## Context (đọc trước khi code)
- DESIGN.md: `es-kitchen-docs/docs/epics/E04/details/order-list/es-kitchen-api/DESIGN.md` — Section 4, 5
- Pattern tham khảo: `es-kitchen-repository/es-kitchen-api/src/modules/admin-company/http/controllers/order.controller.ts`
- `SupplierGuard` + `GetUser` decorator: xem `supplier-authentication` DESIGN Section 5.1

## Yêu cầu implement

### 1. Request DTO
File: `src/modules/supplier/http/requests/list-purchase-orders.request.ts`

```typescript
export class ListPurchaseOrdersRequest {
  @IsOptional()
  @IsEnum(PurchaseOrderStatus)
  status?: PurchaseOrderStatus;

  @IsOptional()
  @IsDateString()
  shipmentDateFrom?: string;

  @IsOptional()
  @IsDateString()
  shipmentDateTo?: string;

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

### 2. Response classes
File: `src/modules/supplier/http/responses/purchase-order-list.response.ts`

```typescript
export class PurchaseOrderItemResponse {
  id: string;
  orderNumber: string;
  orderDate: Date;
  productName: string;
  productCount: number;
  status: PurchaseOrderStatus;
  desiredDeliveryDate: string | null;
  scheduledShipmentDate: string | null;
  shipmentDate: string | null;
  quantity: number;
  trackingNumber: string | null;
}

export class PurchaseOrderListResponse {
  items: PurchaseOrderItemResponse[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}
```

File: `src/modules/supplier/http/responses/purchase-order-badge.response.ts`

```typescript
export class PurchaseOrderBadgeResponse {
  waitingDeliveryDate: number;
  waitingShipment: number;
  shipped: number;
}
```

### 3. Controller
File: `src/modules/supplier/http/controllers/order.controller.ts`

```typescript
@Controller('supplier/orders')
@ApiTags('Supplier — Orders')
@ApiBearerAuth()
@UseGuards(SupplierGuard)
export class SupplierOrderController {
  constructor(private readonly orderService: SupplierOrderService) {}

  @Get()
  @ApiUnifiedResponse(PurchaseOrderListResponse)
  async listOrders(
    @GetUser() supplier: JwtPayload,
    @Query() query: ListPurchaseOrdersRequest,
  ) {
    const data = await this.orderService.listOrders(supplier.sub, query);
    return { code: 200, data };
  }

  @Get('badge-count')
  @ApiUnifiedResponse(PurchaseOrderBadgeResponse)
  async getBadgeCount(@GetUser() supplier: JwtPayload) {
    const data = await this.orderService.getBadgeCount(supplier.sub);
    return { code: 200, data };
  }
}
```

> `@GetUser()` trả về `JwtPayload` với `sub` = `supplierId` (UUID) — xem supplier-auth DESIGN để confirm field name.

### 4. Cập nhật `supplier.module.ts`

Thêm vào `imports`, `controllers`, `providers`:

```typescript
imports: [
  TypeOrmModule.forFeature([
    Supplier,
    SupplierPasswordResetToken,
    PurchaseOrder,       // THÊM
    PurchaseOrderItem,   // THÊM
  ]),
  ...
],
controllers: [
  SupplierAuthController,
  SupplierOrderController, // THÊM
],
providers: [
  SupplierAuthService,
  SupplierOrderService,    // THÊM
  ...
],
```

## Unit Tests (BẮT BUỘC)
- File: `src/modules/supplier/http/controllers/order.controller.spec.ts`
- Coverage target: 80%
- Verify: `npm run test -- order.controller.spec`

**Test cases:**

```
describe('GET /supplier/orders')
  ✓ trả về 200 + data khi query hợp lệ (không có filter)
  ✓ trả về 200 + data khi filter theo status
  ✓ trả về 200 + data khi filter theo shipmentDateFrom/To
  ✓ trả về 401 khi không có token (SupplierGuard mock)
  ✓ truyền supplierId đúng từ JwtPayload.sub xuống service

describe('GET /supplier/orders/badge-count')
  ✓ trả về 200 + data badge count
  ✓ trả về 401 khi không có token
```

## Non-Regression Table
| Tính năng | File liên quan | Cách verify |
|---|---|---|
| Supplier Auth endpoints | `modules/supplier/http/controllers/auth.controller.ts` | Không chạm file này |
| `supplier.module.ts` sau khi update | — | `npm run build` không lỗi circular dependency |
| AdminGuard không bị apply nhầm | `modules/admin/guards/admin.guard.ts` | Controller dùng `SupplierGuard` — kiểm tra import |

## Không được làm
- Không dùng `AdminGuard` trên controller này — phải dùng `SupplierGuard`
- Không thêm business logic vào controller — chỉ delegate xuống service
- Không thêm `@Public()` decorator — tất cả endpoints cần auth

## Definition of Done
- [ ] Build pass
- [ ] Lint pass
- [ ] Unit tests pass, coverage ≥ 80%
- [ ] `GET /supplier/orders` trả về đúng structure theo DESIGN
- [ ] `GET /supplier/orders/badge-count` trả về đúng structure
- [ ] `supplier.module.ts` build không lỗi
- [ ] Swagger docs hiển thị 2 endpoints mới dưới tag "Supplier — Orders"
- [ ] Actual Hour cập nhật
- [ ] Status chuyển → Request Review
