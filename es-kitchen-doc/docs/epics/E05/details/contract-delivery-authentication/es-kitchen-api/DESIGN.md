# DESIGN — Contract Delivery Authentication (es-kitchen-api)

> **Feature:** Contract Delivery Authentication
> **Epic:** E05 — Contract Delivery Web
> **Repo:** es-kitchen-api
> **SPEC:** `../SPEC.md`
> **Date:** 19/05/2026
> **Status:** Draft
> **Author:** Tech Lead

---

## 1. Tổng quan kỹ thuật

E05 là website outsource dành cho nhân viên vận chuyển hợp đồng. Authentication sử dụng username/email + password với JWT riêng — không dùng Cognito như E03/E02, vì tài khoản delivery staff quản lý trực tiếp bởi hệ thống (bcrypt/argon2 hash trong DB).

**Lý do không dùng Cognito cho E05:** Delivery staff account được E03 tạo nội bộ, số lượng ít, không cần enterprise identity federation. Pattern tương tự `Admin` entity của E03.

**Pattern tham chiếu:** `src/modules/admin/` (E03) — dùng argon2 hash password, hashed_refresh_token, MailService OTP flow. E05 sẽ follow cùng pattern nhưng dùng reset link token thay OTP (vì SPEC yêu cầu link qua email, không OTP).

---

## 2. Database Design

### 2.1 Entity `DeliveryStaff`

**Table name:** `delivery_staff`

| Column | Type | Constraint | Ghi chú |
|---|---|---|---|
| `id` | UUID | PK DEFAULT uuid_generate_v4() | Dùng UUID để đồng nhất với quy định mới (E05 là module mới) |
| `username` | varchar(100) | UNIQUE NOT NULL | Login identifier chính |
| `email` | varchar(255) | UNIQUE NOT NULL | Dùng cho forgot password |
| `password` | varchar(255) | NOT NULL | Argon2 hash |
| `hashed_refresh_token` | varchar(500) | NULL | Argon2 hash của refresh token |
| `status` | varchar(20) | NOT NULL DEFAULT 'active' | Enum: `active`, `disabled` |
| `last_login_at` | timestamptz | NULL | Cập nhật khi login thành công |
| `created_by` | varchar(255) | NULL | Email của admin E03 đã tạo |
| `created_at` | timestamptz | NOT NULL DEFAULT NOW() | |
| `updated_at` | timestamptz | NOT NULL DEFAULT NOW() | |
| `deleted_at` | timestamptz | NULL | Soft delete |

**Ghi chú thiết kế:**
- `id` dùng UUID (khác với các entity cũ dùng bigint) — E05 là module mới, tuân theo quy chuẩn mới ghi trong `patterns.md`.
- `username` và `email` đều unique — login chấp nhận cả hai (SPEC 4.1: "Username/Email").
- `status` dùng varchar enum thay vì int2 để readable hơn (tham chiếu: SPEC BR-07).
- Không có Cognito pool — password quản lý trực tiếp bằng argon2.

**TypeScript Entity path:** `src/entities/delivery-staff.entity.ts`

```typescript
// src/entities/delivery-staff.entity.ts — Skeleton tham khảo
@Entity({ name: 'delivery_staff' })
export class DeliveryStaff {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'username', type: 'varchar', length: 100, unique: true })
  username: string;

  @Column({ type: 'varchar', length: 255, unique: true })
  email: string;

  @Column({ type: 'varchar', length: 255 })
  @Exclude()
  password: string;

  @Column({ name: 'hashed_refresh_token', type: 'varchar', length: 500, nullable: true })
  @Exclude()
  hashedRefreshToken: string | null;

  @Column({ type: 'varchar', length: 20, default: DeliveryStaffStatus.ACTIVE })
  status: DeliveryStaffStatus;

  @Column({ name: 'last_login_at', type: 'timestamptz', nullable: true })
  lastLoginAt: Date | null;

  @Column({ name: 'created_by', type: 'varchar', length: 255, nullable: true })
  createdBy: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;
}
```

---

### 2.2 Entity `DeliveryPasswordResetToken`

**Table name:** `delivery_password_reset_tokens`

| Column | Type | Constraint | Ghi chú |
|---|---|---|---|
| `id` | UUID | PK DEFAULT uuid_generate_v4() | |
| `delivery_staff_id` | UUID | FK → delivery_staff.id NOT NULL | |
| `token_hash` | varchar(255) | NOT NULL | SHA-256 hash của raw token |
| `is_used` | boolean | NOT NULL DEFAULT false | BR-04: dùng một lần |
| `expires_at` | timestamptz | NOT NULL | Thời hạn token (xem OQ-02) |
| `created_at` | timestamptz | NOT NULL DEFAULT NOW() | |

**Ghi chú thiết kế:**
- Lưu `token_hash` (SHA-256), không lưu raw token — bảo mật khi DB bị lộ.
- Raw token là UUID ngẫu nhiên gửi trong email link, hash so sánh khi reset.
- Mỗi lần forgot-password tạo 1 record mới; record cũ (chưa used, chưa expired) bị invalidate bằng cách set `is_used = true`.
- Thời hạn mặc định thiết kế là **1 giờ** — pending OQ-02 confirm từ client.

**So sánh với pattern E02 (`Otp` entity):** E02 dùng OTP 4 số, E05 dùng token link dài hơn — pattern khác nhau nên tạo entity mới, không tái sử dụng `Otp`. Không có E04 SupplierPasswordResetToken nào đã tồn tại trong codebase (xác nhận qua tilth_search).

**TypeScript Entity path:** `src/entities/delivery-password-reset-token.entity.ts`

---

### 2.3 Enum `DeliveryStaffStatus`

**Path:** `src/commons/enums/delivery-staff.enum.ts`

```typescript
export enum DeliveryStaffStatus {
  ACTIVE = 'active',
  DISABLED = 'disabled',
}
```

---

## 3. Migrations

### Migration 1: Create `delivery_staff` table

**File:** `database/migrations/<timestamp>-create-delivery-staff.ts`

```sql
-- up()
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE delivery_staff (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username              VARCHAR(100) NOT NULL,
  email                 VARCHAR(255) NOT NULL,
  password              VARCHAR(255) NOT NULL,
  hashed_refresh_token  VARCHAR(500) NULL,
  status                VARCHAR(20)  NOT NULL DEFAULT 'active',
  last_login_at         TIMESTAMPTZ  NULL,
  created_by            VARCHAR(255) NULL,
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ  NULL
);

CREATE UNIQUE INDEX idx_delivery_staff_username_active
  ON delivery_staff (username) WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX idx_delivery_staff_email_active
  ON delivery_staff (email) WHERE deleted_at IS NULL;

-- down()
DROP TABLE IF EXISTS delivery_staff;
```

### Migration 2: Create `delivery_password_reset_tokens` table

**File:** `database/migrations/<timestamp>-create-delivery-password-reset-tokens.ts`

```sql
-- up()
CREATE TABLE delivery_password_reset_tokens (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  delivery_staff_id   UUID         NOT NULL REFERENCES delivery_staff(id) ON DELETE CASCADE,
  token_hash          VARCHAR(255) NOT NULL,
  is_used             BOOLEAN      NOT NULL DEFAULT false,
  expires_at          TIMESTAMPTZ  NOT NULL,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_delivery_password_reset_tokens_staff_id
  ON delivery_password_reset_tokens (delivery_staff_id);

-- down()
DROP TABLE IF EXISTS delivery_password_reset_tokens;
```

---

## 4. Redis Design

### 4.1 JWT Blacklist (Logout)

Khi logout, access token còn trong TTL cần được blacklist để ngăn tái sử dụng.

| Key | Format | Value | TTL |
|---|---|---|---|
| JWT blacklist | `delivery:jwt:blacklist:<jti>` | `"1"` | Bằng TTL còn lại của access token (tối đa 24h) |

**Cách hoạt động:**
1. `POST /delivery/auth/logout` — decode access token lấy `jti` và `exp`.
2. Tính TTL còn lại: `exp - now()`.
3. Set Redis key với TTL tương ứng.
4. `DeliveryGuard.validate()` kiểm tra Redis trước khi return payload.

**Ghi chú:** `jti` (JWT ID) phải được thêm vào payload khi sign token — dùng `uuid()` để unique.

### 4.2 Access Token TTL

Session timeout 1 ngày (SPEC BR-08):

| Token | TTL | Config key |
|---|---|---|
| Access token | 24h (`86400s`) | `JWT_DELIVERY_ACCESS_EXPIRY` |
| Refresh token | 7 ngày (`604800s`) | `JWT_DELIVERY_REFRESH_EXPIRY` |

Không cache profile delivery staff — entity nhỏ, không có requirement listing phức tạp trong scope auth.

---

## 5. API Contract

### Base URL prefix: `/delivery/auth`

Tất cả endpoint không cần guard (public) ngoại trừ `logout` và `change-password`.

---

### 5.1 `POST /delivery/auth/login`

**Guard:** none (public)

**Request Body:**
```json
{
  "identifier": "staff01",       // username hoặc email
  "password": "MyP@ss1234"
}
```

**Response 200:**
```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ..."
}
```

**Response 401:**
```json
{
  "statusCode": 401,
  "message": "ログイン情報が正しくありません"
}
```

**Logic:**
1. Tìm `DeliveryStaff` theo `username = identifier OR email = identifier` với `deleted_at IS NULL`.
2. Nếu không tìm thấy → throw `UnauthorizedException` (thông báo chung — SPEC BR-02).
3. Nếu `status = 'disabled'` → throw `UnauthorizedException` với message riêng (SPEC BR-07, AC-04).
4. So sánh password bằng `argon2.verify(staff.password, dto.password)`.
5. Nếu sai → throw `UnauthorizedException` (thông báo chung).
6. Tạo JWT payload: `{ sub: staff.id, id: staff.id, email: staff.email, jti: uuid() }`.
7. Sign access token (TTL 24h) và refresh token (TTL 7d) với secret riêng (`jwtDelivery`).
8. Hash refresh token bằng argon2, lưu vào `hashed_refresh_token`.
9. Update `last_login_at`.
10. Return `{ accessToken, refreshToken }`.

---

### 5.2 `POST /delivery/auth/logout`

**Guard:** `DeliveryGuard` (JWT required)

**Request:** Header `Authorization: Bearer <accessToken>`

**Response 200:**
```json
{ "message": "ログアウトしました" }
```

**Logic:**
1. Lấy `jti` và `exp` từ decoded JWT (đã validate bởi guard).
2. Tính TTL còn lại: `Math.max(0, exp - Math.floor(Date.now() / 1000))`.
3. Set `delivery:jwt:blacklist:<jti>` = `"1"` với TTL còn lại.
4. Set `hashed_refresh_token = null` trong `delivery_staff`.
5. Return success.

---

### 5.3 `POST /delivery/auth/forgot-password`

**Guard:** none (public)

**Request Body:**
```json
{
  "email": "staff01@example.com"
}
```

**Response 200** (luôn trả về thông báo chung — SPEC BR-03):
```json
{
  "message": "パスワード再設定のメールをご確認ください"
}
```

**Logic:**
1. Tìm `DeliveryStaff` theo `email` với `deleted_at IS NULL`.
2. Nếu không tìm thấy hoặc `status = 'disabled'` → **không gửi email**, vẫn return 200 với thông báo chung.
3. Tạo raw token = `crypto.randomUUID()`.
4. Hash token = `crypto.createHash('sha256').update(rawToken).digest('hex')`.
5. Invalidate token cũ: update `delivery_password_reset_tokens` set `is_used = true` where `delivery_staff_id = staff.id AND is_used = false`.
6. Insert record mới `DeliveryPasswordResetToken` với `expires_at = now() + 1 hour`.
7. Gửi email qua `MailService.sendTemplated()` với template `delivery-reset-password`, context: `{ staffName, resetLink, expirationTime }`.
   - `resetLink` = `${DELIVERY_FRONTEND_URL}/reset-password?token=${rawToken}`
8. Return 200.

---

### 5.4 `POST /delivery/auth/reset-password`

**Guard:** none (public)

**Request Body:**
```json
{
  "token": "3f7a2b1c-...",   // raw token từ email link
  "newPassword": "NewP@ss5678"
}
```

**Response 200:**
```json
{
  "message": "パスワードを再設定しました"
}
```

**Response 400 — token hết hạn hoặc đã dùng:**
```json
{
  "statusCode": 400,
  "message": "リセットリンクが無効または期限切れです"
}
```

**Logic:**
1. Hash `token` bằng SHA-256.
2. Tìm `DeliveryPasswordResetToken` theo `token_hash` với `is_used = false`.
3. Nếu không tìm thấy → throw `BadRequestException`.
4. Nếu `expires_at < now()` → throw `BadRequestException` (token expired).
5. Lấy `DeliveryStaff` tương ứng, kiểm tra `status = 'active'` và `deleted_at IS NULL`.
6. Hash `newPassword` bằng argon2.
7. Dùng `dataSource.transaction()`:
   - Update `delivery_staff.password = hashedNewPassword`.
   - Update `delivery_password_reset_tokens.is_used = true`.
8. Return success.

---

### 5.5 `PUT /delivery/auth/change-password`

**Guard:** `DeliveryGuard` (JWT required)

**Request Body:**
```json
{
  "currentPassword": "OldP@ss1234",
  "newPassword": "NewP@ss5678",
  "confirmNewPassword": "NewP@ss5678"
}
```

**Response 200:**
```json
{
  "message": "パスワードを変更しました"
}
```

**Response 400 — current password sai:**
```json
{
  "statusCode": 400,
  "message": "現在のパスワードが正しくありません"
}
```

**Logic:**
1. Lấy `staffId` từ `request.user.sub` (đã qua `DeliveryGuard`).
2. Tìm `DeliveryStaff` theo `id = staffId`.
3. Verify `currentPassword` bằng `argon2.verify(staff.password, dto.currentPassword)`.
4. Nếu sai → throw `BadRequestException` (SPEC AC-13).
5. Verify `newPassword !== currentPassword` bằng cách verify hash (SPEC BR-06, AC-14).
6. Hash `newPassword` bằng argon2.
7. Update `delivery_staff.password = hashedNewPassword`.
8. Phiên hiện tại KHÔNG bị logout (SPEC 4.4 bước 8) — chỉ update password, không clear refresh token.
9. Return success.

---

## 6. Module Structure

```
src/modules/delivery/
├── delivery.module.ts
├── guards/
│   └── delivery.guard.ts                      ← DeliveryGuard + DeliveryStrategy ('delivery-jwt')
├── services/
│   ├── auth.service.ts                        ← Login, logout, change-password
│   └── password-reset.service.ts             ← Forgot/reset password + token management
├── http/
│   ├── controllers/
│   │   └── auth.controller.ts                ← 5 endpoints
│   ├── requests/
│   │   ├── login.request.ts
│   │   ├── forgot-password.request.ts
│   │   ├── reset-password.request.ts
│   │   └── change-password.request.ts
│   └── responses/
│       └── authenticated.response.ts
```

**Files mới cần tạo ngoài module:**

| File | Mô tả |
|---|---|
| `src/entities/delivery-staff.entity.ts` | Entity |
| `src/entities/delivery-password-reset-token.entity.ts` | Entity |
| `src/commons/enums/delivery-staff.enum.ts` | Enum status |
| `config/index.ts` | Thêm `jwtDelivery: JwtConfig` vào `AppConfig` |
| `config/jwt.config.ts` | Thêm `JwtDeliveryConfigService` |
| `database/migrations/<ts>-create-delivery-staff.ts` | Migration 1 |
| `database/migrations/<ts>-create-delivery-password-reset-tokens.ts` | Migration 2 |

---

## 7. Guard & Strategy

```typescript
// src/modules/delivery/guards/delivery.guard.ts

const STRATEGY_NAME = 'delivery-jwt';

@Injectable()
export class DeliveryGuard extends AuthGuard(STRATEGY_NAME) {}

@Injectable()
export class DeliveryStrategy extends PassportStrategy(Strategy, STRATEGY_NAME) {
  constructor(
    configService: ConfigService<AppConfig>,
    private readonly redisService: RedisService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<JwtConfig>('jwtDelivery')?.secret || 'DeliverySecretKey',
    });
  }

  async validate(payload: JwtPayload) {
    // Kiểm tra blacklist
    const blacklisted = await this.redisService.get(
      `delivery:jwt:blacklist:${payload.jti}`
    );
    if (blacklisted) {
      throw new UnauthorizedException('Token has been revoked');
    }
    return payload;
  }
}
```

**Strategy name:** `'delivery-jwt'` — unique, không conflict với `'admin-jwt'`, `'admin-company-jwt'`, `'jwt'`.

---

## 8. Config Update

### `config/index.ts` — thêm vào `AppConfig`:

```typescript
export interface AppConfig {
  // ... existing fields
  jwtDelivery: JwtConfig;
  links: {
    adminFrontendUrl: string;
    companyFrontendUrl: string;
    deliveryFrontendUrl: string;   // mới — dùng để build reset link
  };
}
```

### Environment variables mới:

| Variable | Mô tả | Giá trị mặc định |
|---|---|---|
| `JWT_DELIVERY_ACCESS_SECRET` | Secret cho access token delivery | `DeliverySecretKey` |
| `JWT_DELIVERY_ACCESS_EXPIRY` | TTL access token | `86400s` (24h) |
| `JWT_DELIVERY_REFRESH_SECRET` | Secret cho refresh token delivery | `DeliveryRefreshSecretKey` |
| `JWT_DELIVERY_REFRESH_EXPIRY` | TTL refresh token | `604800s` (7d) |
| `DELIVERY_FRONTEND_URL` | Base URL của web-delivery app | `http://localhost:3001` |

---

## 9. Module Registration

```typescript
// src/modules/delivery/delivery.module.ts
@Module({
  imports: [
    TypeOrmModule.forFeature([DeliveryStaff, DeliveryPasswordResetToken]),
    JwtModule.registerAsync({
      global: true,
      useClass: JwtDeliveryConfigService,
    }),
    MailModule,
  ],
  controllers: [AuthController],
  providers: [
    DeliveryStrategy,
    AuthService,
    PasswordResetService,
  ],
})
export class DeliveryModule {}
```

Đăng ký `DeliveryModule` vào `AppModule` sau khi tạo.

---

## 10. Reuse Opportunities

| Pattern hiện có | E05 có thể reuse |
|---|---|
| `JwtConfig` interface (`config/jwt.config.ts`) | Thêm `JwtDeliveryConfigService` cùng pattern với `JwtAdminConfigService` |
| `MailService.sendTemplated()` | Dùng trực tiếp, thêm template `delivery-reset-password` |
| Guard pattern (Strategy + AuthGuard) | Copy pattern từ `admin.guard.ts`, đổi strategy name và secret key |
| `argon2` hash + verify | Dùng trực tiếp, cùng package |
| `JwtPayload` interface (`src/auth/interfaces/jwt-payload.interface.ts`) | Extend thêm field `jti?: string` cho blacklist support |

**Lưu ý JwtPayload:** Cần thêm `jti` vào interface để support blacklist. Dùng `tilth_deps` trước khi sửa để check blast radius — interface này được dùng bởi `admin.guard.ts`, `admin-company.guard.ts`, và `jwt.strategy.ts`.

---

## 11. Non-Regression Risks

| Risk | Mô tả | Mitigation |
|---|---|---|
| `JwtPayload` interface thay đổi | Thêm `jti?: string` (optional) ảnh hưởng E03, E02, E01 guard | Thêm optional `jti?` — không breaking. Chạy `npm run test` sau khi sửa. |
| `AppConfig` interface thay đổi | Thêm `jwtDelivery` và `deliveryFrontendUrl` | Thêm field mới — không breaking với code cũ. |
| `config/jwt.config.ts` thay đổi | Thêm class mới — không sửa class cũ | Chỉ thêm `JwtDeliveryConfigService`, không touch `JwtAdminConfigService` hay `JwtAdminCompanyConfigService`. |
| Redis key collision | `delivery:jwt:blacklist:*` | Prefix riêng `delivery:` — không overlap với keys hiện tại. |
| Strategy name collision | `'delivery-jwt'` | Unique — xác nhận qua tilth_search trước khi tạo. |

---

## 12. Open Questions cần clarify trước implement

| OQ | SPEC | Quyết định tạm thời | Cần confirm |
|---|---|---|---|
| OQ-02 | Thời hạn reset token | 1 giờ | Client confirm |
| OQ-04 | Password complexity | MinLength 8, ít nhất 1 chữ hoa, 1 số | Client confirm |
| OQ-01 | Multi-session | Cho phép đa phiên — không force logout phiên cũ | Client confirm |
| OQ-03 | Force logout phiên khác khi đổi password | Không force logout (SPEC 4.4 bước 8 đã rõ) | Client confirm nếu muốn thay đổi |
| OQ-05 | Email template content | BA/Designer cung cấp | Designer |

---

## 13. Self-review Checklist

- [ ] Column naming snake_case trong entity — explicit `{ name: 'snake_case' }`
- [ ] Migration có `up()` và `down()`
- [ ] Không N+1 query — auth query đơn giản, findOne theo PK/unique index
- [ ] Redis key `delivery:jwt:blacklist:<jti>` có TTL = remaining token lifetime
- [ ] DTO có class-validator decorator (`@IsString`, `@IsEmail`, `@MinLength`, v.v.)
- [ ] `@Exclude()` trên `password` và `hashedRefreshToken` trong entity
- [ ] Strategy name `'delivery-jwt'` unique — không conflict
- [ ] Không hard-code secret — dùng `configService.get('jwtDelivery')`
- [ ] `JwtPayload.jti` thêm optional — kiểm tra blast radius trước
- [ ] Thông báo lỗi login chung — không tiết lộ username hay email tồn tại
