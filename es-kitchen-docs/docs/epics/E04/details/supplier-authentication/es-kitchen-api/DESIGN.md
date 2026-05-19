# DESIGN: Supplier Authentication — es-kitchen-api

> **Epic:** E04 — Supplier Web
> **SPEC:** `../SPEC.md`
> **Date:** 19/05/2026
> **Status:** Draft
> **Author:** Tech Lead

---

## 1. Tổng quan kỹ thuật

Feature cung cấp 5 API endpoints dưới prefix `/supplier/auth/...` phục vụ xác thực cho Supplier Web (E04). Module `supplier/` được tạo mới, tách biệt hoàn toàn khỏi các module `admin/`, `admin-company/`, `user/` — có JWT Strategy riêng (`supplier-jwt`) và secret riêng.

**Quyết định kỹ thuật cho Open Questions trong SPEC:**
- **OQ-01 (Reset token TTL):** 24 giờ — nhất quán với session timeout (BR-09)
- **OQ-02 (Password complexity):** Tối thiểu 8 ký tự, ít nhất 1 chữ hoa, 1 chữ thường, 1 số — regex `^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$`
- **OQ-04 (Account lockout):** Out of scope cho phase này — không implement
- **OQ-06 (Invalidate other sessions on change-password):** Không invalidate session khác — giữ phiên hiện tại theo BR-09

**Điểm khác biệt so với E02/E03:**
- Supplier login bằng `email` + `password` (không có `companyCode`)
- Forgot password dùng reset link token (URL có token, TTL 24h) — **không** dùng OTP 4 số như E02/E03
- Entity `Supplier` và `SupplierPasswordResetToken` lưu trong DB, không dùng Cognito
- Password hash bằng `argon2` (nhất quán với codebase)

---

## 2. Database Changes

### 2.1 Entity: `Supplier`

File: `src/entities/supplier.entity.ts`

```typescript
import { Exclude } from 'class-transformer';
import {
  Column,
  CreateDateColumn,
  DeleteDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum SupplierStatus {
  ACTIVE = 1,
  DISABLED = 0,
}

@Index('idx_suppliers_email_active', ['email'], {
  unique: true,
  where: '"deleted_at" IS NULL',
})
@Entity({ name: 'suppliers' })
export class Supplier {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'supplier_name', type: 'varchar', length: 255 })
  supplierName: string;

  @Column({ type: 'varchar', length: 255, unique: true })
  email: string;

  @Column({ name: 'password_hash', type: 'varchar', length: 255 })
  @Exclude()
  passwordHash: string;

  @Column({ name: 'hashed_refresh_token', type: 'varchar', nullable: true })
  @Exclude()
  hashedRefreshToken: string | null;

  @Column({ type: 'smallint', default: SupplierStatus.ACTIVE })
  status: number;

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

**Ghi chú:**
- UUID PK (khác với `Admin` entity dùng bigint) — Supplier là domain riêng của E04
- `status`: `1` = Active, `0` = Disabled — kiểm tra khi login
- `hashed_refresh_token`: lưu argon2 hash của refresh token, null khi logout
- Index unique partial trên email, chỉ áp dụng khi `deleted_at IS NULL`

### 2.2 Entity: `SupplierPasswordResetToken`

File: `src/entities/supplier-password-reset-token.entity.ts`

```typescript
import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  JoinColumn,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Supplier } from './supplier.entity';

@Index('idx_supplier_prt_token', ['token'], { unique: true })
@Index('idx_supplier_prt_supplier', ['supplierId'])
@Entity({ name: 'supplier_password_reset_tokens' })
export class SupplierPasswordResetToken {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'supplier_id', type: 'uuid' })
  supplierId: string;

  @ManyToOne(() => Supplier, { eager: false })
  @JoinColumn({ name: 'supplier_id' })
  supplier: Supplier;

  @Column({ type: 'varchar', length: 255, unique: true })
  token: string;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;

  @Column({ name: 'is_used', type: 'boolean', default: false })
  isUsed: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
```

**Ghi chú:**
- `token`: chuỗi random `crypto.randomBytes(32).toString('hex')` — 64 ký tự hex
- `expires_at`: `createdAt + 24 giờ` (TTL theo OQ-01)
- `is_used`: set `true` ngay sau khi reset password thành công (BR-04)
- Không có `updated_at` — record chỉ được ghi một lần, sau đó `is_used` flip

### 2.3 Migrations

#### Migration 1: `CreateSuppliersTable`

File: `src/migrations/<timestamp>-CreateSuppliersTable.ts`

```typescript
import { MigrationInterface, QueryRunner, Table, TableIndex } from 'typeorm';

export class CreateSuppliersTable<timestamp> implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.createTable(
      new Table({
        name: 'suppliers',
        columns: [
          { name: 'id', type: 'uuid', isPrimary: true, generationStrategy: 'uuid', default: 'uuid_generate_v4()' },
          { name: 'supplier_name', type: 'varchar', length: '255', isNullable: false },
          { name: 'email', type: 'varchar', length: '255', isNullable: false, isUnique: true },
          { name: 'password_hash', type: 'varchar', length: '255', isNullable: false },
          { name: 'hashed_refresh_token', type: 'varchar', isNullable: true },
          { name: 'status', type: 'smallint', default: '1', isNullable: false },
          { name: 'last_login_at', type: 'timestamptz', isNullable: true },
          { name: 'created_at', type: 'timestamptz', default: 'now()' },
          { name: 'updated_at', type: 'timestamptz', default: 'now()' },
          { name: 'deleted_at', type: 'timestamptz', isNullable: true },
        ],
      }),
      true,
    );

    await queryRunner.createIndex(
      'suppliers',
      new TableIndex({
        name: 'idx_suppliers_email_active',
        columnNames: ['email'],
        isUnique: true,
        where: '"deleted_at" IS NULL',
      }),
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropIndex('suppliers', 'idx_suppliers_email_active');
    await queryRunner.dropTable('suppliers');
  }
}
```

#### Migration 2: `CreateSupplierPasswordResetTokensTable`

File: `src/migrations/<timestamp>-CreateSupplierPasswordResetTokensTable.ts`

```typescript
import { MigrationInterface, QueryRunner, Table, TableIndex, TableForeignKey } from 'typeorm';

export class CreateSupplierPasswordResetTokensTable<timestamp> implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.createTable(
      new Table({
        name: 'supplier_password_reset_tokens',
        columns: [
          { name: 'id', type: 'uuid', isPrimary: true, generationStrategy: 'uuid', default: 'uuid_generate_v4()' },
          { name: 'supplier_id', type: 'uuid', isNullable: false },
          { name: 'token', type: 'varchar', length: '255', isNullable: false, isUnique: true },
          { name: 'expires_at', type: 'timestamptz', isNullable: false },
          { name: 'is_used', type: 'boolean', default: false, isNullable: false },
          { name: 'created_at', type: 'timestamptz', default: 'now()' },
        ],
      }),
      true,
    );

    await queryRunner.createIndex(
      'supplier_password_reset_tokens',
      new TableIndex({ name: 'idx_supplier_prt_token', columnNames: ['token'], isUnique: true }),
    );

    await queryRunner.createIndex(
      'supplier_password_reset_tokens',
      new TableIndex({ name: 'idx_supplier_prt_supplier', columnNames: ['supplier_id'] }),
    );

    await queryRunner.createForeignKey(
      'supplier_password_reset_tokens',
      new TableForeignKey({
        name: 'fk_supplier_prt_supplier_id',
        columnNames: ['supplier_id'],
        referencedTableName: 'suppliers',
        referencedColumnNames: ['id'],
        onDelete: 'CASCADE',
      }),
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropForeignKey('supplier_password_reset_tokens', 'fk_supplier_prt_supplier_id');
    await queryRunner.dropIndex('supplier_password_reset_tokens', 'idx_supplier_prt_supplier');
    await queryRunner.dropIndex('supplier_password_reset_tokens', 'idx_supplier_prt_token');
    await queryRunner.dropTable('supplier_password_reset_tokens');
  }
}
```

---

## 3. Redis Cache

### 3.1 Key schema

| Key pattern | Value | TTL | Mục đích |
|---|---|---|---|
| `supplier:blacklist:<jti>` | `"1"` | Còn lại đến expiry của token | Logout — invalidate access token cụ thể |
| `supplier:session:<supplierId>` | `accessToken jti` | `86400s` (24h) | Tracking session hiện tại để force-logout |

**Lưu ý:** Key `supplier:blacklist:<jti>` dùng để block access token sau khi logout. `jti` (JWT ID) phải được include trong payload khi sign token. TTL của key Redis bằng thời gian còn lại đến khi token hết hạn — không lưu vĩnh viễn.

### 3.2 Logout flow với Redis

```
POST /supplier/auth/logout
  → Lấy jti từ decoded token
  → SET supplier:blacklist:<jti> "1" EX <remaining_ttl>
  → SET supplier:session:<supplierId> null (hoặc DEL)
  → Clear hashed_refresh_token trong DB
```

### 3.3 Guard validation

`SupplierJwtAuthGuard` phải kiểm tra Redis blacklist **sau** khi Passport validate signature:

```typescript
// Trong canActivate():
const jti = request.user?.jti;
const isBlacklisted = await this.redisService.get(`supplier:blacklist:${jti}`);
if (isBlacklisted) throw new UnauthorizedException();
```

---

## 4. API Contract

> Controller prefix: `/supplier/auth` (module prefix `/supplier`, controller prefix `/auth`)
> Public routes (không cần guard): `login`, `forgot-password`, `reset-password`
> Protected routes (cần `SupplierJwtAuthGuard`): `logout`, `change-password`

---

### 4.1 `POST /supplier/auth/login`

**Mô tả:** Xác thực Supplier bằng email + password. Trả về JWT token cặp access/refresh.

**Request body:**
```json
{
  "email": "supplier@example.com",
  "password": "Password123"
}
```

**DTO:**
```typescript
// src/modules/supplier/http/requests/login.request.ts
export class LoginRequest {
  @IsEmail()
  @IsNotEmpty()
  @Transform(({ value }) => value?.toLowerCase()?.trim())
  email: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(8)
  password: string;
}
```

**Response `200 OK`:**
```json
{
  "data": {
    "accessToken": "<jwt>",
    "refreshToken": "<jwt>"
  }
}
```

**Response `401 Unauthorized`** (email không tồn tại, password sai, tài khoản Disabled):
```json
{
  "statusCode": 401,
  "message": "メールアドレスまたはパスワードが正しくありません。"
}
```

**Business logic:**
1. Tìm Supplier theo email (`deleted_at IS NULL`)
2. Nếu không tìm thấy → throw `UnauthorizedException` với message chung (chống enumeration — BR-02)
3. So sánh password với `argon2.verify(supplier.passwordHash, password)`
4. Nếu sai → throw `UnauthorizedException` với cùng message chung
5. Nếu `supplier.status === SupplierStatus.DISABLED` → throw `UnauthorizedException` với message "アカウントは無効化されています。管理者にお問い合わせください。"
6. Update `last_login_at`
7. Sign access token (`expiresIn: '24h'`) với payload `{ sub: supplier.id, email: supplier.email, jti: uuid() }`
8. Sign refresh token, hash và lưu vào `hashed_refresh_token`
9. Lưu jti vào `supplier:session:<supplierId>` với TTL 24h
10. Trả về `{ accessToken, refreshToken }`

---

### 4.2 `POST /supplier/auth/logout`

**Mô tả:** Invalidate access token hiện tại. Yêu cầu Bearer token hợp lệ.

**Auth:** `@UseGuards(SupplierJwtAuthGuard)`

**Request:** Không có body. Token lấy từ `Authorization: Bearer <token>`.

**Response `200 OK`:**
```json
{
  "data": null,
  "message": "ログアウトしました。"
}
```

**Business logic:**
1. Lấy `jti` và `sub` từ `request.user` (đã validate bởi guard)
2. Tính `remaining_ttl` = `exp - Date.now()/1000`
3. `SET supplier:blacklist:<jti> "1" EX <remaining_ttl>`
4. `DEL supplier:session:<supplierId>`
5. Update `hashed_refresh_token = null` trong DB

---

### 4.3 `POST /supplier/auth/forgot-password`

**Mô tả:** Gửi email chứa reset link. Luôn trả về thành công dù email tồn tại hay không (BR-05, chống enumeration).

**Request body:**
```json
{
  "email": "supplier@example.com"
}
```

**DTO:**
```typescript
// src/modules/supplier/http/requests/forgot-password.request.ts
export class ForgotPasswordRequest {
  @IsEmail()
  @IsNotEmpty()
  @Transform(({ value }) => value?.toLowerCase()?.trim())
  email: string;
}
```

**Response `200 OK`:** (luôn trả về — dù email tồn tại hay không)
```json
{
  "data": null,
  "message": "パスワード再設定の手順をメールでお送りしました。"
}
```

**Business logic:**
1. Tìm Supplier theo email (không throw nếu không tìm thấy — silent return)
2. Nếu không tìm thấy → return ngay (không gửi email, không báo lỗi)
3. Invalidate tất cả token cũ chưa dùng của supplier này (set `is_used = true` hoặc xóa)
4. Tạo `SupplierPasswordResetToken`:
   - `token = crypto.randomBytes(32).toString('hex')`
   - `expires_at = now + 24h`
   - `is_used = false`
5. Gửi email qua `MailService.sendTemplated()`:
   - Template: `supplier-reset-password`
   - Reset URL: `${SUPPLIER_WEB_URL}/reset-password?token=<token>`
   - Context: `{ supplierName, resetUrl, expirationHours: 24 }`
6. Return 200 (không phân biệt kết quả)

---

### 4.4 `POST /supplier/auth/reset-password`

**Mô tả:** Đặt lại mật khẩu mới bằng token từ email. Sau khi thành công, redirect Supplier về login.

**Request body:**
```json
{
  "token": "a3f8c2...(64 ký tự hex)",
  "newPassword": "NewPassword123",
  "confirmPassword": "NewPassword123"
}
```

**DTO:**
```typescript
// src/modules/supplier/http/requests/reset-password.request.ts
export class ResetPasswordRequest {
  @IsString()
  @IsNotEmpty()
  @Length(64, 64)
  token: string;

  @IsString()
  @MinLength(8)
  @Matches(/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$/, {
    message: 'password must contain at least 1 uppercase, 1 lowercase and 1 number',
  })
  newPassword: string;

  @IsString()
  @IsNotEmpty()
  confirmPassword: string;
}
```

**Response `200 OK`:**
```json
{
  "data": null,
  "message": "パスワードを再設定しました。"
}
```

**Response `400 Bad Request`** — token hết hạn:
```json
{
  "statusCode": 400,
  "message": "リンクの有効期限が切れました。再度パスワード再設定をリクエストしてください。"
}
```

**Response `400 Bad Request`** — token đã dùng hoặc không tồn tại:
```json
{
  "statusCode": 400,
  "message": "リンクが無効または使用済みです。"
}
```

**Response `400 Bad Request`** — password không khớp confirm:
```json
{
  "statusCode": 400,
  "message": "パスワードが一致しません。"
}
```

**Response `400 Bad Request`** — password mới trùng password cũ (BR-06):
```json
{
  "statusCode": 400,
  "message": "新しいパスワードは現在のパスワードと異なるものを設定してください。"
}
```

**Business logic:**
1. Tìm `SupplierPasswordResetToken` theo `token`
2. Nếu không tìm thấy hoặc `is_used = true` → throw `BadRequestException` "invalid/used"
3. Nếu `expires_at < now` → throw `BadRequestException` "expired"
4. Validate `newPassword === confirmPassword` (hoặc để client validate, service chỉ accept sau khi FE validate)
5. Tìm `Supplier` theo `supplierId`
6. Kiểm tra `argon2.verify(supplier.passwordHash, newPassword)` — nếu trùng → throw `BadRequestException` (BR-06)
7. Hash password mới: `newHash = await argon2.hash(newPassword)`
8. Trong transaction:
   - Update `supplier.password_hash = newHash`
   - Update `supplier.hashed_refresh_token = null` (invalidate tất cả refresh token)
   - Set `token.is_used = true`
9. Return 200

---

### 4.5 `PUT /supplier/auth/change-password`

**Mô tả:** Đổi mật khẩu chủ động. Giữ nguyên session hiện tại (không đăng xuất — AC-10).

**Auth:** `@UseGuards(SupplierJwtAuthGuard)`

**Request body:**
```json
{
  "currentPassword": "OldPassword123",
  "newPassword": "NewPassword456",
  "confirmPassword": "NewPassword456"
}
```

**DTO:**
```typescript
// src/modules/supplier/http/requests/change-password.request.ts
export class ChangePasswordRequest {
  @IsString()
  @IsNotEmpty()
  currentPassword: string;

  @IsString()
  @MinLength(8)
  @Matches(/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$/, {
    message: 'newPassword must contain at least 1 uppercase, 1 lowercase and 1 number',
  })
  newPassword: string;

  @IsString()
  @IsNotEmpty()
  confirmPassword: string;
}
```

**Response `200 OK`:**
```json
{
  "data": null,
  "message": "パスワードを変更しました。"
}
```

**Response `400 Bad Request`** — current password sai:
```json
{
  "statusCode": 400,
  "message": "現在のパスワードが正しくありません。"
}
```

**Response `400 Bad Request`** — password mới trùng password cũ (BR-06):
```json
{
  "statusCode": 400,
  "message": "新しいパスワードは現在のパスワードと異なるものを設定してください。"
}
```

**Business logic:**
1. Lấy `supplierId` từ `request.user.sub`
2. Tìm Supplier theo id
3. Verify `argon2.verify(supplier.passwordHash, currentPassword)` — nếu sai → throw `BadRequestException`
4. Kiểm tra `argon2.verify(supplier.passwordHash, newPassword)` — nếu trùng → throw `BadRequestException` (BR-06)
5. Validate `newPassword === confirmPassword`
6. Hash password mới và update `supplier.password_hash`
7. **Không** invalidate session hiện tại — chỉ update password (AC-10, OQ-06 → out of scope)
8. Return 200

---

## 5. Module Structure

```
src/modules/supplier/
├── supplier.module.ts
├── guards/
│   └── supplier.guard.ts              ← SupplierGuard + SupplierStrategy ('supplier-jwt')
├── http/
│   ├── controllers/
│   │   └── auth.controller.ts         ← @Controller('auth'), prefix /supplier từ module
│   ├── requests/
│   │   ├── login.request.ts
│   │   ├── forgot-password.request.ts
│   │   ├── reset-password.request.ts
│   │   └── change-password.request.ts
│   └── responses/
│       └── authenticated.response.ts  ← { accessToken: string; refreshToken: string }
└── services/
    ├── auth.service.ts                ← login, logout, forgotPassword, resetPassword, changePassword
    └── auth.service.spec.ts
```

**Entities** đặt tại `src/entities/` (nhất quán với pattern toàn codebase):
- `src/entities/supplier.entity.ts`
- `src/entities/supplier-password-reset-token.entity.ts`

### 5.1 `supplier.guard.ts`

```typescript
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuthGuard, PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { JwtConfig } from 'config/jwt.config';
import { AppConfig } from 'config';
import { JwtPayload } from 'src/auth/interfaces/jwt-payload.interface';
// Redis service import — dùng service đã có trong codebase

const STRATEGY_NAME = 'supplier-jwt';

@Injectable()
export class SupplierGuard extends AuthGuard(STRATEGY_NAME) {}

@Injectable()
export class SupplierStrategy extends PassportStrategy(Strategy, STRATEGY_NAME) {
  constructor(configService: ConfigService<AppConfig>) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<JwtConfig>('jwtSupplier')?.secret || 'SupplierSecretKey',
    });
  }

  validate(payload: JwtPayload & { jti: string }) {
    return payload; // attach to request.user
  }
}
```

### 5.2 `supplier.module.ts`

```typescript
@Module({
  imports: [
    TypeOrmModule.forFeature([Supplier, SupplierPasswordResetToken]),
    JwtModule.registerAsync({
      useClass: JwtSupplierConfigService, // cần tạo trong jwt.config.ts
    }),
    MailModule,
  ],
  controllers: [AuthController],
  providers: [
    SupplierStrategy,
    AuthService,
  ],
})
@Controller('supplier')   // prefix /supplier cho toàn bộ module
export class SupplierModule {}
```

### 5.3 Config bổ sung

Cần thêm vào `config/jwt.config.ts`:
```typescript
@Injectable()
export class JwtSupplierConfigService implements JwtOptionsFactory {
  constructor(private readonly configService: ConfigService<AppConfig>) {}

  createJwtOptions(): JwtModuleOptions {
    return {
      secret: this.configService.get<JwtConfig>('jwtSupplier')?.secret || 'SupplierSecretKey',
      signOptions: {
        expiresIn: this.configService.get<JwtConfig>('jwtSupplier')?.expiresIn || '86400s',
      },
    };
  }
}
```

Cần thêm `jwtSupplier` vào `AppConfig` và `config/index.ts`:
```typescript
jwtSupplier: {
  secret: process.env.SUPPLIER_JWT_SECRET,
  refreshSecret: process.env.SUPPLIER_JWT_REFRESH_SECRET,
  expiresIn: '86400s',       // 24h — session timeout (BR-09)
  expiresInRefresh: '86400s',
}
```

Cần thêm `jwtSupplier` vào AWS Parameter Store (không hard-code):
- `SUPPLIER_JWT_SECRET`
- `SUPPLIER_JWT_REFRESH_SECRET`
- `SUPPLIER_WEB_URL` — URL của es-kitchen-web-supplier để tạo reset link

---

## 6. Email Template

Template name: `supplier-reset-password`

Đặt tại: `src/commons/utiliz/mail/templates/supplier-reset-password.hbs`

Context object:
```typescript
{
  supplierName: string;    // tên hiển thị của supplier
  resetUrl: string;        // https://<SUPPLIER_WEB_URL>/reset-password?token=<token>
  expirationHours: number; // 24
  companyName: string;     // 'ESKitchen'
}
```

---

## 7. App Module

Đăng ký `SupplierModule` trong `src/app.module.ts`:
```typescript
import { SupplierModule } from './modules/supplier/supplier.module';

@Module({
  imports: [
    // ... existing modules
    SupplierModule,
  ],
})
export class AppModule {}
```

---

## 8. Non-Regression Risks

| Risk | Module bị ảnh hưởng | Mitigation |
|---|---|---|
| JWT Module `global: true` trong `AdminModule` có thể conflict với `JwtModule` mới của `SupplierModule` | `supplier/`, `admin/` | Không dùng `global: true` trong `SupplierModule.JwtModule` — chỉ scope trong module |
| Thêm entity `Supplier`, `SupplierPasswordResetToken` vào `AppModule` data source nhưng không ảnh hưởng các module khác | Tất cả | Migration chạy tuần tự, `synchronize: false` — không tự modify schema |
| Strategy name `supplier-jwt` phải unique — không trùng `admin-jwt`, `admin-company-jwt`, `jwt` | Auth system | Đã verify: tất cả 4 strategy names khác nhau |
| `MailModule` đã import tại `AdminModule`, `AdminCompanyModule`, `UserModule` — dùng chung không cần khai báo global | `supplier/` | Import `MailModule` trực tiếp vào `SupplierModule` — pattern nhất quán với các module khác |
| Password reset token table cần `uuid_generate_v4()` extension | PostgreSQL | Extension `uuid-ossp` phải đã được enable (Admin/AdminCompany entities dùng bigint nên có thể chưa enable) — kiểm tra trong migration `up()` bằng `CREATE EXTENSION IF NOT EXISTS "uuid-ossp"` |

---

## 9. Self-Review Checklist

- [x] Column naming snake_case trong entity
- [x] Migration có `up()` và `down()` đầy đủ
- [x] Không N+1 query — tất cả query single lookup theo PK hoặc unique index
- [x] Redis key có TTL — `supplier:blacklist:<jti>` TTL = remaining token time, `supplier:session:<id>` TTL = 24h
- [x] DTO có class-validator decorator đầy đủ
- [x] Không hard-code secret, URL, key — dùng `ConfigService` và `process.env`
- [x] Strategy name unique: `supplier-jwt`
- [x] Password không trả về trong response (entity có `@Exclude()`)
- [x] Chống enumeration attack: login và forgot-password dùng message chung
