# es-kitchen-api — Patterns & Conventions

> Đọc file này trước khi viết code NestJS mới. Follow pattern đang có — không tự refactor.

---

## Module Pattern

```typescript
// Mỗi module import entity riêng qua TypeOrmModule.forFeature()
@Module({
  imports: [
    TypeOrmModule.forFeature([Order, OrderDetail, Company]),
    JwtModule.registerAsync({ global: true, useClass: JwtAdminConfigService }),
    MailModule,
  ],
  controllers: [OrderController, CompanyController],
  providers: [OrderService, CompanyService, AdminStrategy],
})
export class AdminModule {}
```

**Quy tắc:**
- Mỗi module khai báo entity dùng trong module đó — không dùng chung repository giữa modules
- JwtModule.registerAsync với `global: true` — token valid trong toàn module
- MailModule import khi cần gửi email (AWS SES)

---

## Controller Pattern

```typescript
@Controller('admin/orders')
@UseGuards(JwtAuthGuard)                    // Guard ở controller level
export class OrderController {
  constructor(private readonly orderService: OrderService) {}

  @Get()
  async getOrders(@Query() query: GetOrdersRequest) {
    return this.orderService.getOrders(query);
  }

  @Get(':id')
  async getOrderDetail(@Param('id') id: string) {
    return this.orderService.getOrderDetail(id);
  }

  @Post()
  async createOrder(@Body() body: CreateOrderRequest) {
    return this.orderService.createOrder(body);
  }
}
```

**URL prefix theo module:**
- E03 System Admin: `/admin/...`
- E02 Company Admin: `/admin-company/...`
- E01 User: `/user/...`

---

## Service Pattern

```typescript
@Injectable()
export class OrderService {
  constructor(
    @InjectRepository(Order) private orderRepository: Repository<Order>,
    @InjectRepository(OrderDetail) private orderDetailRepository: Repository<OrderDetail>,
  ) {}

  async getOrders(query: GetOrdersRequest) {
    const qb = this.orderRepository
      .createQueryBuilder('order')
      .leftJoinAndSelect('order.company', 'company')
      .where('order.deleted_at IS NULL');

    // orderBy whitelist — BẮT BUỘC để tránh TypeError
    const ORDER_BY_MAP: Record<string, string> = {
      createdAt: 'order.createdAt',
      companyCode: 'company.companyCode',
    };
    const orderByField = ORDER_BY_MAP[query.orderBy] ?? 'order.createdAt';
    qb.orderBy(orderByField, query.order ?? 'DESC');

    return qb.getManyAndCount();
  }
}
```

**Lưu ý quan trọng — Known Bug:**
```typescript
// ❌ KHÔNG làm — TypeORM orderBy với string từ query param
qb.orderBy(query.orderBy, 'DESC');
// → TypeError: Cannot read properties of undefined (reading 'databaseName')

// ✅ LUÔN dùng whitelist map
const ORDER_BY_MAP = { createdAt: 'order.createdAt', ... };
const field = ORDER_BY_MAP[query.orderBy] ?? 'order.createdAt';
qb.orderBy(field, 'DESC');
```

---

## Entity Pattern

```typescript
@Entity('orders')
export class Order {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'company_id' })   // ← snake_case trong DB
  companyId: string;                  // ← camelCase trong TypeScript

  @Column({ name: 'total_amount', type: 'decimal', precision: 10, scale: 2 })
  totalAmount: number;

  @Column({ name: 'status', type: 'enum', enum: OrderStatus })
  status: OrderStatus;

  @ManyToOne(() => Company)
  @JoinColumn({ name: 'company_id' })
  company: Company;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt?: Date;
}
```

**Conventions:**
- PK: UUID (`@PrimaryGeneratedColumn('uuid')`)
- Column name: phải explicit `{ name: 'snake_case' }` — TypeORM không tự convert
- Timestamps: `timestamptz` — không dùng `timestamp`
- Soft delete: `@DeleteDateColumn` với `deletedAt` — không `DELETE` cứng
- Enum: dùng TypeScript enum + `type: 'enum'`

---

## DTO / Request Pattern

```typescript
// requests/get-orders.request.ts
import { IsOptional, IsString, IsEnum } from 'class-validator';

export class GetOrdersRequest {
  @IsOptional()
  @IsString()
  orderBy?: string;

  @IsOptional()
  @IsEnum(['ASC', 'DESC'])
  order?: 'ASC' | 'DESC';

  @IsOptional()
  @IsString()
  companyCode?: string;
}
```

**Quy tắc:**
- Tất cả request DTO dùng `class-validator` decorators
- Đặt trong `http/requests/` — không đặt inline trong controller
- Response DTO đặt trong `http/responses/`

---

## Guard Pattern

```typescript
// modules/admin/guards/admin.guard.ts
@Injectable()
export class AdminStrategy extends PassportStrategy(Strategy, 'admin-jwt') {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: process.env.ADMIN_JWT_SECRET,
    });
  }

  async validate(payload: JwtPayload) {
    return payload;  // attach to request.user
  }
}
```

Mỗi module có strategy riêng với tên unique (`'admin-jwt'`, `'admin-company-jwt'`, `'user-jwt'`) để không conflict.

---

## Migration Pattern

```typescript
// migrations/1234567890-add-payment-method.ts
export class AddPaymentMethod1234567890 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE payment_methods (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        name VARCHAR(255) NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        deleted_at TIMESTAMPTZ
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE payment_methods`);
  }
}
```

**Quy tắc migration:**
- Mỗi schema change = 1 file migration riêng
- Phải có cả `up()` và `down()`
- Không sửa migration đã chạy trên STG/PROD
- Tên file: `<timestamp>-<description>.ts`

---

## Event / Listener Pattern

```typescript
// commons/events/order-created.event.ts
export class OrderCreatedEvent {
  constructor(public readonly orderId: string) {}
}

// modules/admin-company/listeners/admin-company.listener.ts
@Injectable()
export class AdminCompanyListener {
  @OnEvent('order.created')
  handleOrderCreated(event: OrderCreatedEvent) {
    // side effects: notification, email, etc.
  }
}
```

---

## Redis Cache Pattern

```typescript
@Injectable()
export class ProductService {
  constructor(
    @InjectRepository(Product) private repo: Repository<Product>,
    private redis: RedisService,
  ) {}

  async getProduct(id: string) {
    const cacheKey = `eskitchen:product:${id}`;
    const cached = await this.redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    const product = await this.repo.findOne({ where: { id } });
    await this.redis.set(cacheKey, JSON.stringify(product), 'EX', 300); // 5 min TTL
    return product;
  }
}
```

**Key naming:** `eskitchen:<domain>:<id>` hoặc `eskitchen:<domain>:list:<hash>`  
**TTL:** Bắt buộc — không set key không có expiry.

---

## Test Pattern

```typescript
// <service>.spec.ts — Jest + @nestjs/testing
describe('OrderService', () => {
  let service: OrderService;
  let orderRepository: jest.Mocked<Repository<Order>>;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        OrderService,
        {
          provide: getRepositoryToken(Order),
          useValue: { findOne: jest.fn(), save: jest.fn() },
        },
      ],
    }).compile();

    service = module.get(OrderService);
    orderRepository = module.get(getRepositoryToken(Order));
  });

  it('should return order', async () => {
    orderRepository.findOne.mockResolvedValue({ id: '1' } as Order);
    const result = await service.getOrderDetail('1');
    expect(result.id).toBe('1');
  });
});
```

**Scope test bắt buộc:** `*.service.ts`, `*.guard.ts`, `*.interceptor.ts`  
**Bỏ qua:** DTO, Entity files.
