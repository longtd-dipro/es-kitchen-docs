# DESIGN: Driver Authentication — es-kitchen-api

> **Epic:** E06 — Driver App
> **Feature:** Driver Authentication
> **Repo:** `es-kitchen-api`
> **Date:** 19/05/2026
> **Status:** Draft
> **Author:** Tech Lead
> **SPEC:** `../SPEC.md`

---

## 1. Tổng quan kỹ thuật

Implement module `driver` mới trong `es-kitchen-api`, tách biệt hoàn toàn khỏi các module `admin`, `admin-company`, và `user`. Module này cung cấp ba endpoint xác thực: **Login** (Driver ID + Password), **Logout**, và **Forgot Password** (Driver ID → email → reset link).

### Điểm khác biệt so với các module hiện tại

| Điểm | admin / admin-company | driver (E06) |
|---|---|---|
| Login field | Email | Driver ID (`DRV-xxx`) |
| Password backend | AWS Cognito | argon2 hash trong DB (không dùng Cognito) |
| Forgot password flow | OTP 4 chữ số qua email | Reset link token qua email (1 lần dùng, có expiry) |
| JWT strategy name | `admin-jwt` / `admin-company-jwt` | `driver-jwt` |
| Config key | `jwtAdmin` / `jwtAdminCompany` | `jwtDriver` |
| Session TTL | Config riêng | 24 giờ (1 ngày) |

> **Lý do không dùng Cognito cho Driver:** Driver ID là mã nội bộ (không phải email), không phù hợp với Cognito User Pool hiện tại. Password hash trực tiếp bằng argon2 giữ nhất quán với pattern của `User` entity (`es-kitchen-api/src/entities/user.entity.ts`).

> **Lý do dùng reset link thay vì OTP:** SPEC yêu cầu luồng "Driver ID → gửi link reset về email" — không có bước verify OTP trung gian, khác với admin/admin-company flow.

---

## 2. Database

### 2.1 Entity `Driver`

**File:** `src/entities/driver.entity.ts`  
**Table:** `drivers`

| Column | Type | Constraint | Ghi chú |
|---|---|---|---|
| `id` | `bigint` | PK, auto-increment | Consistent với entities hiện tại |
| `driver_code` | `varchar(20)` | UNIQUE, NOT NULL | Driver ID sinh ra bởi hệ thống. Format: `DRV-{6 digits zero-padded}` — ví dụ `DRV-000001` |
| `name` | `varchar(255)` | NOT NULL | Tên tài xế |
| `email` | `varchar(255)` | NOT NULL | Email đã xác nhận — bắt buộc (BR-06) |
| `password` | `varchar(255)` | NOT NULL | argon2 hash |
| `hashed_refresh_token` | `varchar(512)` | NULL | argon2 hash của refresh token |
| `status` | `driver_status_enum` | NOT NULL, DEFAULT `ACTIVE` | `ACTIVE` / `INACTIVE` |
| `last_login_at` | `timestamptz` | NULL | |
| `created_at` | `timestamptz` | NOT NULL, DEFAULT NOW() | |
| `updated_at` | `timestamptz` | NOT NULL, DEFAULT NOW() | |
| `deleted_at` | `timestamptz` | NULL | Soft delete |

**Enum `driver_status_enum`:** `ACTIVE`, `INACTIVE`

**Index:**
- `idx_drivers_driver_code` — UNIQUE trên `driver_code` WHERE `deleted_at IS NULL`
- `idx_drivers_email` — trên `email` WHERE `deleted_at IS NULL`

**TypeScript Enum:**
```typescript
// src/commons/enums/driver.enum.ts
export enum DriverStatus {
  ACTIVE = 'ACTIVE',
  INACTIVE = 'INACTIVE',
}
```

**Entity skeleton:**
```typescript
// src/entities/driver.entity.ts
@Entity({ name: 'drivers' })
export class Driver {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id: string;

  @Column({ name: 'driver_code', type: 'varchar', length: 20, unique: true })
  driverCode: string;  // DRV-000001

  @Column({ type: 'varchar', length: 255 })
  name: string;

  @Column({ type: 'varchar', length: 255 })
  email: string;

  @Column({ type: 'varchar', length: 255 })
  @Exclude()
  password: string;

  @Column({ name: 'hashed_refresh_token', type: 'varchar', length: 512, nullable: true })
  @Exclude()
  hashedRefreshToken: string | null;

  @Column({ type: 'enum', enum: DriverStatus, default: DriverStatus.ACTIVE })
  status: DriverStatus;

  @Column({ name: 'last_login_at', type: 'timestamptz', nullable: true })
  lastLoginAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;
}
```

---

### 2.2 Entity `DriverPasswordResetToken`

**File:** `src/entities/driver-password-reset-token.entity.ts`  
**Table:** `driver_password_reset_tokens`

Lý do dùng entity riêng thay vì bảng `otps` chung: reset token của Driver là **link-based** (1 lần, thời hạn dài hơn), khác với OTP 4 chữ số 5 phút của admin. Tách bảng tránh ô nhiễm và dễ query.

| Column | Type | Constraint | Ghi chú |
|---|---|---|---|
| `id` | `bigint` | PK, auto-increment | |
| `driver_id` | `bigint` | NOT NULL, FK → `drivers.id` | |
| `token_hash` | `varchar(255)` | NOT NULL | SHA-256 hash của raw token |
| `expires_at` | `timestamptz` | NOT NULL | Default: NOW() + 1 giờ (pending OQ-06 — hiện để 1h, cần confirm client) |
| `used_at` | `timestamptz` | NULL | Set khi token đã được dùng |
| `created_at` | `timestamptz` | NOT NULL, DEFAULT NOW() | |

**Index:** `idx_driver_pwd_reset_driver_id` trên `driver_id`

**Entity skeleton:**
```typescript
// src/entities/driver-password-reset-token.entity.ts
@Entity({ name: 'driver_password_reset_tokens' })
export class DriverPasswordResetToken {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id: string;

  @Column({ name: 'driver_id', type: 'bigint' })
  driverId: string;

  @Column({ name: 'token_hash', type: 'varchar', length: 255 })
  @Exclude()
  tokenHash: string;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;

  @Column({ name: 'used_at', type: 'timestamptz', nullable: true })
  usedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @ManyToOne(() => Driver, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'driver_id' })
  driver: Driver;
}
```

---

### 2.3 Migrations

**Quy tắc:** mỗi schema change = 1 file migration. Cần 2 migration file:

#### Migration 1: `<timestamp>-CreateDriversTable.ts`

```
database/migrations/<timestamp>-CreateDriversTable.ts
```

`up()`:
1. `CREATE TYPE driver_status_enum AS ENUM ('ACTIVE', 'INACTIVE')`
2. `CREATE TABLE drivers` với tất cả columns theo mục 2.1
3. `CREATE UNIQUE INDEX idx_drivers_driver_code ON drivers(driver_code) WHERE deleted_at IS NULL`
4. `CREATE INDEX idx_drivers_email ON drivers(email) WHERE deleted_at IS NULL`

`down()`:
1. `DROP TABLE drivers`
2. `DROP TYPE driver_status_enum`

#### Migration 2: `<timestamp>-CreateDriverPasswordResetTokensTable.ts`

```
database/migrations/<timestamp>-CreateDriverPasswordResetTokensTable.ts
```

`up()`:
1. `CREATE TABLE driver_password_reset_tokens` với tất cả columns theo mục 2.2
2. `ALTER TABLE driver_password_reset_tokens ADD CONSTRAINT fk_driver_pwd_reset_driver_id FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE CASCADE`
3. `CREATE INDEX idx_driver_pwd_reset_driver_id ON driver_password_reset_tokens(driver_id)`

`down()`:
1. `DROP TABLE driver_password_reset_tokens`

---

## 3. Driver ID Generation

**Pattern:** `DRV-{6 digits zero-padded}` — ví dụ `DRV-000001`, `DRV-000042`, `DRV-001337`

**Lý do chọn sequential thay vì UUID-based:**
- Dễ đọc, dễ tra cứu trực tiếp bởi driver (họ nhìn vào thẻ nhân viên)
- Zero-padded 6 chữ số đủ cho 999,999 drivers — dư so với scale hiện tại
- UUID-based (`DRV-a3f9...`) dài, khó nhập trên mobile keyboard

**Implementation trong service khi E03 tạo Driver:**
```typescript
// Trong DriverService.generateDriverCode()
// Gọi khi E03 tạo tài khoản Driver mới
async generateDriverCode(): Promise<string> {
  // Lấy MAX id hiện tại + 1 (atomic trong transaction)
  // Không dùng sequence PostgreSQL riêng để giữ đơn giản
  const result = await this.dataSource.query(
    `SELECT COALESCE(MAX(CAST(REGEXP_REPLACE(driver_code, 'DRV-', '') AS INTEGER)), 0) + 1 AS next_seq FROM drivers`
  );
  const seq = result[0].next_seq;
  return `DRV-${String(seq).padStart(6, '0')}`;
}
```

> Lưu ý: `generateDriverCode()` phải chạy bên trong `dataSource.transaction()` khi tạo Driver để tránh race condition.

---

## 4. JWT / Redis

### 4.1 JWT Config

**Config key mới:** `jwtDriver`

```typescript
// config/jwt.config.ts — thêm JwtDriverConfigService
@Injectable()
export class JwtDriverConfigService implements JwtOptionsFactory {
  constructor(private readonly configService: ConfigService<AppConfig>) {}

  createJwtOptions(): JwtModuleOptions {
    return {
      secret: this.configService.get<JwtConfig>('jwtDriver')?.secret || 'DriverSecretKey',
      signOptions: {
        expiresIn: this.configService.get<JwtConfig>('jwtDriver')?.expiresIn || '86400s', // 24h
      },
    };
  }
}
```

**Environment variables (AWS Parameter Store):**
- `DRIVER_JWT_SECRET` — access token secret
- `DRIVER_JWT_REFRESH_SECRET` — refresh token secret
- `DRIVER_JWT_EXPIRES_IN` = `86400s` (24 giờ)
- `DRIVER_JWT_REFRESH_EXPIRES_IN` = `86400s` (session = 1 ngày, không auto-refresh)

### 4.2 Redis — JWT Blacklist (Logout)

Logout phải invalidate access token ngay lập tức — không chờ expiry. Dùng Redis blacklist pattern.

**Key format:** `eskitchen:driver:blacklist:<jti>`  
**TTL:** Thời gian còn lại của token (tính từ `exp` claim đến thời điểm logout)

**Flow logout:**
1. Service nhận `jti` và `exp` từ JWT payload
2. `redis.set('eskitchen:driver:blacklist:<jti>', '1', 'EXAT', exp)` — TTL = Unix timestamp của expiry
3. `DriverStrategy.validate()` kiểm tra key này trước khi return payload

> `jti` (JWT ID) phải được inject vào payload khi sign token: `jwtService.signAsync({ sub, driverCode, jti: uuid() })`

**Redis không dùng cho data khác** trong module này — chỉ blacklist logout. Không cache driver entity (driver data thay đổi ít, không cần thiết tại scope này).

---

## 5. Module Structure

```
src/modules/driver/
├── driver.module.ts
├── guards/
│   └── driver.guard.ts              # DriverGuard + DriverStrategy ('driver-jwt')
├── http/
│   ├── controllers/
│   │   └── auth.controller.ts       # @Controller('driver/auth')
│   ├── requests/
│   │   ├── login.request.ts
│   │   ├── forgot-password.request.ts
│   │   └── reset-password.request.ts
│   └── responses/
│       └── auth.response.ts
└── services/
    ├── auth.service.ts
    └── auth.service.spec.ts
```

Entities đặt tại:
- `src/entities/driver.entity.ts`
- `src/entities/driver-password-reset-token.entity.ts`

Enum: `src/commons/enums/driver.enum.ts`

---

## 6. API Contract

### URL Prefix

Tất cả endpoint Driver Auth có prefix: `/driver/auth/...`

---

### 6.1 `POST /driver/auth/login`

**Guard:** Không (public endpoint)  
**Description:** Xác thực Driver ID + Password, trả về access + refresh token.

**Request Body:**
```typescript
// http/requests/login.request.ts
export class DriverLoginRequest {
  @IsString()
  @IsNotEmpty()
  @ApiProperty({ example: 'DRV-000001', description: 'Driver ID do hệ thống cấp' })
  driverId: string;  // maps to driver_code trong DB

  @IsString()
  @IsNotEmpty()
  @ApiProperty({ example: 'P@ssw0rd!' })
  password: string;
}
```

**Response 200:**
```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ..."
}
```

**Response 401 — credentials sai hoặc driver_code không tồn tại:**
```json
{ "message": "Driver ID またはパスワードが正しくありません。" }
```
Thông báo lỗi **luôn chung** — không phân biệt ID sai hay password sai (BR-03).

**Response 403 — tài khoản INACTIVE:**
```json
{ "message": "アカウントが無効化されています。管理者にお問い合わせください。" }
```

**Service logic:**
```
1. Tìm Driver theo driver_code (WHERE driver_code = :driverId AND deleted_at IS NULL)
2. Nếu không tìm thấy → throw UnauthorizedException (thông báo chung)
3. Nếu status = INACTIVE → throw ForbiddenException (thông báo riêng BR-04)
4. argon2.verify(driver.password, body.password) → nếu false → throw UnauthorizedException (thông báo chung)
5. Tạo jti = randomUUID()
6. sign accessToken: { sub: driver.id, driverCode: driver.driverCode, jti }
7. sign refreshToken: { sub: driver.id, driverCode: driver.driverCode, jti: randomUUID() }
8. UPDATE drivers SET hashed_refresh_token = argon2(refreshToken), last_login_at = NOW() WHERE id = driver.id
9. Return { accessToken, refreshToken }
```

---

### 6.2 `POST /driver/auth/logout`

**Guard:** `DriverGuard` (requires valid Bearer token)  
**Description:** Invalidate access token ngay lập tức qua Redis blacklist.

**Request Header:** `Authorization: Bearer <accessToken>`  
**Request Body:** (empty)

**Response 200:**
```json
{ "message": "ログアウトしました。" }
```

**Service logic:**
```
1. Lấy payload từ JWT: { sub, driverCode, jti, exp }
2. redis.set('eskitchen:driver:blacklist:<jti>', '1', 'EXAT', exp)
3. UPDATE drivers SET hashed_refresh_token = NULL WHERE id = sub
4. Return success
```

---

### 6.3 `POST /driver/auth/forgot-password`

**Guard:** Không (public endpoint)  
**Description:** Nhận Driver ID, tra email tương ứng, gửi reset link qua AWS SES.

**Request Body:**
```typescript
// http/requests/forgot-password.request.ts
export class DriverForgotPasswordRequest {
  @IsString()
  @IsNotEmpty()
  @ApiProperty({ example: 'DRV-000001' })
  driverId: string;
}
```

**Response 200 (luôn trả về thành công — tránh enumeration BR-03):**
```json
{ "message": "パスワードリセットリンクをメールに送信しました（登録済みの場合）。" }
```

**Service logic:**
```
1. Tìm Driver theo driver_code (WHERE driver_code = :driverId AND deleted_at IS NULL)
2. Nếu không tìm thấy → return (không throw, không leak thông tin)
3. Nếu status = INACTIVE → return (tương tự)
4. Invalidate tất cả token cũ chưa dùng: UPDATE driver_password_reset_tokens SET used_at = NOW() WHERE driver_id = driver.id AND used_at IS NULL
5. Sinh raw token: crypto.randomBytes(32).toString('hex') (64 ký tự hex)
6. token_hash = crypto.createHash('sha256').update(rawToken).digest('hex')
7. expires_at = NOW() + 1 giờ (pending OQ-06)
8. INSERT INTO driver_password_reset_tokens(driver_id, token_hash, expires_at)
9. Gửi email qua MailService.sendTemplated():
   - to: driver.email
   - templateName: 'driver-reset-password'
   - context: { driverName: driver.name, resetUrl: '<DRIVER_APP_URL>/reset-password/<rawToken>', expirationTime: '1 hour' }
10. Return (không throw dù email fail — log error internally)
```

> `DRIVER_APP_URL` đọc từ ConfigService — không hard-code.

---

### 6.4 `POST /driver/auth/reset-password`

**Guard:** Không (public endpoint — token trong body đóng vai trò auth)  
**Description:** Xác thực reset token, cập nhật password mới.

**Request Body:**
```typescript
// http/requests/reset-password.request.ts
export class DriverResetPasswordRequest {
  @IsString()
  @IsNotEmpty()
  @ApiProperty({ description: 'Raw token từ URL email' })
  token: string;

  @IsString()
  @MinLength(8)
  @Matches(/^(?=.*[A-Z])(?=.*[0-9])/, {
    message: 'Password phải có ít nhất 1 chữ hoa và 1 chữ số',
  })
  @ApiProperty({ example: 'NewP@ss1' })
  newPassword: string;
}
```

**Response 200:**
```json
{ "message": "パスワードを更新しました。ログイン画面からログインしてください。" }
```

**Response 400 — token hết hạn hoặc đã dùng:**
```json
{ "message": "リンクの有効期限が切れています。再度パスワード再設定をお試しください。" }
```

**Service logic:**
```
1. token_hash = crypto.createHash('sha256').update(body.token).digest('hex')
2. Tìm record: WHERE token_hash = :hash AND used_at IS NULL
3. Nếu không tìm thấy → throw BadRequestException (thông báo link không hợp lệ/đã dùng)
4. Nếu expires_at < NOW() → throw BadRequestException (thông báo link hết hạn)
5. dataSource.transaction():
   a. UPDATE drivers SET password = argon2(newPassword), hashed_refresh_token = NULL WHERE id = record.driver_id
   b. UPDATE driver_password_reset_tokens SET used_at = NOW() WHERE id = record.id
6. Return success
```

---

## 7. Guard Pattern

**File:** `src/modules/driver/guards/driver.guard.ts`

```typescript
// Follows pattern của admin.guard.ts
const STRATEGY_NAME = 'driver-jwt';

@Injectable()
export class DriverGuard extends AuthGuard(STRATEGY_NAME) {}

@Injectable()
export class DriverStrategy extends PassportStrategy(Strategy, STRATEGY_NAME) {
  constructor(
    configService: ConfigService<AppConfig>,
    @InjectRepository(Driver) private driverRepo: Repository<Driver>,
    private redis: Redis,  // @InjectRedis() — ioredis
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<JwtConfig>('jwtDriver')?.secret || 'DriverSecretKey',
    });
  }

  async validate(payload: DriverJwtPayload) {
    // 1. Check Redis blacklist (logout)
    const isBlacklisted = await this.redis.get(`eskitchen:driver:blacklist:${payload.jti}`);
    if (isBlacklisted) throw new UnauthorizedException();

    // 2. Check driver còn tồn tại và active
    const driver = await this.driverRepo.findOne({
      where: { id: payload.sub, status: DriverStatus.ACTIVE },
    });
    if (!driver) throw new UnauthorizedException();

    return payload;  // attach to request.user
  }
}
```

**JWT Payload interface:**
```typescript
// src/modules/driver/interfaces/driver-jwt-payload.interface.ts
export interface DriverJwtPayload {
  sub: string;        // driver.id
  driverCode: string; // driver.driver_code
  jti: string;        // uuid — dùng cho blacklist
  iat: number;
  exp: number;
}
```

---

## 8. Module Registration

**File:** `src/modules/driver/driver.module.ts`

```typescript
@Module({
  imports: [
    TypeOrmModule.forFeature([Driver, DriverPasswordResetToken]),
    JwtModule.registerAsync({
      global: true,
      useClass: JwtDriverConfigService,
    }),
    MailModule,
    // RedisModule — inject ioredis client đã setup ở AppModule
  ],
  controllers: [DriverAuthController],
  providers: [
    DriverStrategy,
    DriverAuthService,
  ],
  exports: [],
})
export class DriverModule {}
```

**AppModule:** Import `DriverModule` cùng cấp với `AdminModule`, `AdminCompanyModule`, `UserModule`.

---

## 9. File Tree Đầy Đủ

```
src/
├── entities/
│   ├── driver.entity.ts                          (new)
│   └── driver-password-reset-token.entity.ts     (new)
├── commons/enums/
│   └── driver.enum.ts                            (new)
├── modules/driver/
│   ├── driver.module.ts                          (new)
│   ├── interfaces/
│   │   └── driver-jwt-payload.interface.ts       (new)
│   ├── guards/
│   │   └── driver.guard.ts                       (new)
│   ├── http/
│   │   ├── controllers/
│   │   │   └── auth.controller.ts                (new)
│   │   ├── requests/
│   │   │   ├── login.request.ts                  (new)
│   │   │   ├── forgot-password.request.ts        (new)
│   │   │   └── reset-password.request.ts         (new)
│   │   └── responses/
│   │       └── auth.response.ts                  (new)
│   └── services/
│       ├── auth.service.ts                       (new)
│       └── auth.service.spec.ts                  (new)
└── config/
    └── jwt.config.ts                             (modify: add JwtDriverConfigService)

database/migrations/
├── <ts1>-CreateDriversTable.ts                   (new)
└── <ts2>-CreateDriverPasswordResetTokensTable.ts (new)
```

---

## 10. Non-Regression Risks

| Risk | Impact | Mitigation |
|---|---|---|
| `JwtDriverConfigService` dùng sai key config (`jwtAdmin` thay vì `jwtDriver`) | Driver token được validate bởi AdminGuard — security leak | Unit test `DriverStrategy.validate()` riêng. ConfigService key phải là `'jwtDriver'` |
| `DriverModule` import `JwtModule.registerAsync({ global: true })` — conflict với `AdminModule` cùng `global: true` | Có thể override token secret toàn app | Xác nhận: NestJS scope `global: true` trên JwtModule không override nhau nếu strategy name khác. Cần test end-to-end sau deploy |
| Migration `CreateDriversTable` chạy trước khi `driver_status_enum` tồn tại (nếu DB state lạ) | Migration fail | Migration `up()` tạo ENUM trước khi tạo table — giữ đúng thứ tự |
| `generateDriverCode()` race condition khi E03 tạo 2 Driver cùng lúc | Duplicate driver_code | Hàm phải chạy trong `dataSource.transaction()` + UNIQUE index trên `driver_code` làm safety net (DB reject nếu trùng) |
| Redis blacklist không available khi logout | Token không bị invalidate đúng | `DriverStrategy.validate()` phải xử lý Redis timeout gracefully — log error nhưng không crash. Nếu Redis down, token hết hạn tự nhiên sau 24h |
| Email template `driver-reset-password` chưa tồn tại | `MailService.sendTemplated()` fail | Tạo template trước khi deploy. Service log error nhưng không throw (tránh leak thông tin) |

---

## 11. Open Items ảnh hưởng Implementation

| # | Open Question | Tác động | Default tạm |
|---|---|---|---|
| OQ-06 | Reset link có thời hạn bao lâu? | `expires_at` trong `DriverPasswordResetToken` | **Tạm đặt 1 giờ** — cần confirm client trước task Phase 1 |
| OQ-03 | Driver đang có delivery in-progress logout → cho phép hay chặn? | Logic trong `DriverAuthService.logout()` | **Tạm cho phép logout** — không block, feature delivery tracking sẽ handle |
| OQ-05 | Change Password có trong scope E06? | Endpoint mới nếu có | **Không implement** theo SPEC hiện tại |
