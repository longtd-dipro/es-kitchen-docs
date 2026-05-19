# DESIGN: Admin Account Management — es-kitchen-api

> SPEC: `es-kitchen-docs/docs/epics/E03/details/admin-account-management/SPEC.md`
> Phase: 1 (DB Migration) → 2 (API) → 3 (Integration)
> Date: 19/05/2026

---

## 0. Phân tích trạng thái hiện tại

### Đã tồn tại (Phase 1 — kế thừa)

| Artifact | File | Ghi chú |
|---|---|---|
| Entity `Admin` | `src/entities/admin.entity.ts` | Table `admins`, PK `bigint`, `role` là `varchar` raw string |
| Service `AccountService` | `src/modules/admin/services/account.service.ts` | CRUD admin/user/company-admin đã có |
| Controller `AccountController` | `src/modules/admin/http/controllers/account.controller.ts` | Prefix `/accounts`, guard `AdminGuard` |
| Guard `AdminGuard` | `src/modules/admin/guards/admin.guard.ts` | Strategy `admin-jwt` |
| Service `AuthService` | `src/modules/admin/services/auth.service.ts` | Login/logout/refresh, gọi AWS Cognito |

### Vấn đề cần giải quyết trong Phase 2

1. `admins.role` hiện là `varchar` (raw string như `"ADMIN"`, `"SUPPER_ADMIN"`) — cần tách thành bảng `admin_roles` riêng với permission chi tiết per module.
2. Chưa có bảng `admin_roles` và `admin_role_permissions`.
3. Chưa có bảng `admin_ip_whitelist`.
4. Chưa có bảng `admin_email_notification_settings`.
5. Chưa có cơ chế force logout khi Role bị thay đổi (invalidate JWT session).
6. IP check chưa được thực hiện ở login flow.

---

## 1. Database Changes

### 1.1 New Entities

#### `admin_roles` — Bảng Role tùy chỉnh

```typescript
// src/entities/admin-role.entity.ts
@Entity({ name: 'admin_roles' })
@Index('idx_admin_roles_name_active', ['name'], {
  unique: true,
  where: '"deleted_at" IS NULL',
})
export class AdminRole {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id: string;

  @Column({ name: 'role_name', type: 'varchar', length: 100 })
  roleName: string;

  @Column({ name: 'is_system', type: 'boolean', default: false })
  isSystem: boolean;
  // isSystem = true: SUPPER_ADMIN, ADMIN, OPERATOR — không cho edit/delete

  @OneToMany(() => AdminRolePermission, (p) => p.role, { cascade: ['insert', 'update'] })
  permissions: AdminRolePermission[];

  @OneToMany(() => Admin, (a) => a.adminRole)
  admins: Admin[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;
}
```

#### `admin_role_permissions` — Permission per module per role

```typescript
// src/entities/admin-role-permission.entity.ts
// Enum dùng chung — kế thừa từ Phase 1, bổ sung Phase 2
export enum AdminPermissionModule {
  // Phase 1 modules (giữ nguyên)
  COMPANY_MANAGEMENT        = 'COMPANY_MANAGEMENT',
  CONTRACT_MANAGEMENT       = 'CONTRACT_MANAGEMENT',
  PRODUCT_MANAGEMENT        = 'PRODUCT_MANAGEMENT',
  MENU_MANAGEMENT           = 'MENU_MANAGEMENT',
  ORDER_MANAGEMENT          = 'ORDER_MANAGEMENT',
  USER_MANAGEMENT           = 'USER_MANAGEMENT',
  PAYMENT_MANAGEMENT        = 'PAYMENT_MANAGEMENT',
  NOTIFICATION_MANAGEMENT   = 'NOTIFICATION_MANAGEMENT',
  DASHBOARD                 = 'DASHBOARD',
  // Phase 2 modules (mới)
  ADMIN_ACCOUNT_MANAGEMENT  = 'ADMIN_ACCOUNT_MANAGEMENT',
  SALES_ANALYTICS           = 'SALES_ANALYTICS',
}

@Entity({ name: 'admin_role_permissions' })
@Index('idx_admin_role_perm_unique', ['roleId', 'module'], { unique: true })
export class AdminRolePermission {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id: string;

  @Column({ name: 'role_id', type: 'bigint' })
  roleId: string;

  @ManyToOne(() => AdminRole, (r) => r.permissions, { eager: false })
  @JoinColumn({ name: 'role_id' })
  role: AdminRole;

  @Column({ name: 'module', type: 'varchar', length: 100 })
  module: string;
  // Giá trị = AdminPermissionModule enum

  @Column({ name: 'can_view', type: 'boolean', default: false })
  canView: boolean;

  @Column({ name: 'can_edit', type: 'boolean', default: false })
  canEdit: boolean;
  // BR-03: can_edit = true → can_view = true (enforce ở service layer)

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
```

#### Thay đổi `admins` entity

Thêm FK `role_id` → `admin_roles.id`. Giữ nguyên cột `role` (varchar) để backward compatible trong Phase 2 — sẽ deprecate sau khi migration data xong.

```typescript
// Thêm vào src/entities/admin.entity.ts
@Column({ name: 'role_id', type: 'bigint', nullable: true })
roleId: string | null;

@ManyToOne(() => AdminRole, (r) => r.admins, { eager: false, nullable: true })
@JoinColumn({ name: 'role_id' })
adminRole: AdminRole | null;

@Column({ name: 'session_version', type: 'int', default: 0 })
sessionVersion: number;
// Tăng lên 1 khi Role bị đổi → JWT cũ với session_version thấp hơn bị reject (BR-07b)
```

#### `admin_ip_whitelist` — IP Whitelist

```typescript
// src/entities/admin-ip-whitelist.entity.ts
@Entity({ name: 'admin_ip_whitelist' })
@Index('idx_admin_ip_whitelist_ip', ['ipAddress'], { unique: true })
export class AdminIpWhitelist {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id: string;

  @Column({ name: 'ip_address', type: 'varchar', length: 50 })
  ipAddress: string;
  // Hỗ trợ IPv4, IPv6, CIDR (validate ở DTO layer)

  @Column({ name: 'note', type: 'varchar', length: 255, nullable: true })
  note: string | null;

  @Column({ name: 'created_by', type: 'bigint', nullable: true })
  createdBy: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;
}
```

#### `admin_email_notification_settings` — Cấu hình email notification

```typescript
// src/entities/admin-email-notification-setting.entity.ts
export enum AdminEmailNotificationEvent {
  // Placeholder — chi tiết event từng epic sẽ bổ sung sau (OQ-05 Open)
  ORDER_CREATED       = 'ORDER_CREATED',
  ORDER_CANCELLED     = 'ORDER_CANCELLED',
  COMPANY_REGISTERED  = 'COMPANY_REGISTERED',
  USER_REGISTERED     = 'USER_REGISTERED',
}

@Entity({ name: 'admin_email_notification_settings' })
@Index('idx_admin_email_notif_unique', ['adminId', 'event'], { unique: true })
export class AdminEmailNotificationSetting {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id: string;

  @Column({ name: 'admin_id', type: 'bigint' })
  adminId: string;

  @ManyToOne(() => Admin, { eager: false })
  @JoinColumn({ name: 'admin_id' })
  admin: Admin;

  @Column({ name: 'event', type: 'varchar', length: 100 })
  event: string;
  // Giá trị = AdminEmailNotificationEvent enum

  @Column({ name: 'is_enabled', type: 'boolean', default: true })
  isEnabled: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
```

---

### 1.2 Migrations

Thứ tự thực thi migration theo thứ tự timestamp. Mỗi file đặt trong `database/migrations/`.

| # | File | Mô tả |
|---|---|---|
| 1 | `<ts1>-CreateAdminRolesTable.ts` | Tạo bảng `admin_roles`, seed 3 system roles |
| 2 | `<ts2>-CreateAdminRolePermissionsTable.ts` | Tạo bảng `admin_role_permissions`, seed permissions cho system roles |
| 3 | `<ts3>-AddRoleIdAndSessionVersionToAdmins.ts` | Thêm `role_id`, `session_version` vào `admins`, cập nhật FK |
| 4 | `<ts4>-MigrateAdminRoleVarcharToFK.ts` | Data migration: gán `role_id` dựa trên giá trị `role` varchar hiện có |
| 5 | `<ts5>-CreateAdminIpWhitelistTable.ts` | Tạo bảng `admin_ip_whitelist` |
| 6 | `<ts6>-CreateAdminEmailNotificationSettingsTable.ts` | Tạo bảng `admin_email_notification_settings` |

#### Migration 1 — CreateAdminRolesTable

```typescript
// database/migrations/<ts1>-CreateAdminRolesTable.ts
export class CreateAdminRolesTable<ts1> implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE admin_roles (
        id         BIGSERIAL PRIMARY KEY,
        role_name  VARCHAR(100) NOT NULL,
        is_system  BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        deleted_at TIMESTAMPTZ NULL
      )
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX idx_admin_roles_name_active
        ON admin_roles (role_name)
        WHERE deleted_at IS NULL
    `);

    -- Seed system roles
    await queryRunner.query(`
      INSERT INTO admin_roles (role_name, is_system, created_at, updated_at)
      VALUES
        ('SUPPER_ADMIN', TRUE, NOW(), NOW()),
        ('ADMIN',        TRUE, NOW(), NOW()),
        ('OPERATOR',     TRUE, NOW(), NOW())
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS admin_roles CASCADE`);
  }
}
```

#### Migration 2 — CreateAdminRolePermissionsTable

```typescript
// database/migrations/<ts2>-CreateAdminRolePermissionsTable.ts
export class CreateAdminRolePermissionsTable<ts2> implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE admin_role_permissions (
        id         BIGSERIAL PRIMARY KEY,
        role_id    BIGINT NOT NULL REFERENCES admin_roles(id) ON DELETE CASCADE,
        module     VARCHAR(100) NOT NULL,
        can_view   BOOLEAN NOT NULL DEFAULT FALSE,
        can_edit   BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX idx_admin_role_perm_unique
        ON admin_role_permissions (role_id, module)
    `);

    -- SUPPER_ADMIN: full access tất cả modules (seed dựa trên id = 1)
    await queryRunner.query(`
      INSERT INTO admin_role_permissions (role_id, module, can_view, can_edit)
      SELECT
        (SELECT id FROM admin_roles WHERE role_name = 'SUPPER_ADMIN'),
        module,
        TRUE,
        TRUE
      FROM (VALUES
        ('COMPANY_MANAGEMENT'),('CONTRACT_MANAGEMENT'),('PRODUCT_MANAGEMENT'),
        ('MENU_MANAGEMENT'),('ORDER_MANAGEMENT'),('USER_MANAGEMENT'),
        ('PAYMENT_MANAGEMENT'),('NOTIFICATION_MANAGEMENT'),('DASHBOARD'),
        ('ADMIN_ACCOUNT_MANAGEMENT'),('SALES_ANALYTICS')
      ) AS m(module)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS admin_role_permissions CASCADE`);
  }
}
```

#### Migration 3 — AddRoleIdAndSessionVersionToAdmins

```typescript
// database/migrations/<ts3>-AddRoleIdAndSessionVersionToAdmins.ts
export class AddRoleIdAndSessionVersionToAdmins<ts3> implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE admins
        ADD COLUMN role_id         BIGINT NULL REFERENCES admin_roles(id) ON DELETE SET NULL,
        ADD COLUMN session_version INT    NOT NULL DEFAULT 0
    `);
    await queryRunner.query(`
      CREATE INDEX idx_admins_role_id ON admins (role_id)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE admins
        DROP COLUMN IF EXISTS role_id,
        DROP COLUMN IF EXISTS session_version
    `);
  }
}
```

#### Migration 4 — MigrateAdminRoleVarcharToFK

```typescript
// database/migrations/<ts4>-MigrateAdminRoleVarcharToFK.ts
export class MigrateAdminRoleVarcharToFK<ts4> implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // Gán role_id dựa trên giá trị varchar role hiện có
    await queryRunner.query(`
      UPDATE admins a
      SET role_id = r.id
      FROM admin_roles r
      WHERE UPPER(a.role) = r.role_name
        AND a.deleted_at IS NULL
    `);
    // Admin không match → role_id = NULL (xử lý manually sau)
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      UPDATE admins SET role_id = NULL
    `);
  }
}
```

#### Migration 5 — CreateAdminIpWhitelistTable

```typescript
// database/migrations/<ts5>-CreateAdminIpWhitelistTable.ts
export class CreateAdminIpWhitelistTable<ts5> implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE admin_ip_whitelist (
        id           BIGSERIAL PRIMARY KEY,
        ip_address   VARCHAR(50) NOT NULL,
        note         VARCHAR(255) NULL,
        created_by   BIGINT NULL,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        deleted_at   TIMESTAMPTZ NULL
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX idx_admin_ip_whitelist_ip
        ON admin_ip_whitelist (ip_address)
        WHERE deleted_at IS NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS admin_ip_whitelist CASCADE`);
  }
}
```

#### Migration 6 — CreateAdminEmailNotificationSettingsTable

```typescript
// database/migrations/<ts6>-CreateAdminEmailNotificationSettingsTable.ts
export class CreateAdminEmailNotificationSettingsTable<ts6> implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE admin_email_notification_settings (
        id         BIGSERIAL PRIMARY KEY,
        admin_id   BIGINT NOT NULL REFERENCES admins(id) ON DELETE CASCADE,
        event      VARCHAR(100) NOT NULL,
        is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX idx_admin_email_notif_unique
        ON admin_email_notification_settings (admin_id, event)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS admin_email_notification_settings CASCADE`);
  }
}
```

---

## 2. Redis Cache

| Key Pattern | TTL | Invalidate khi |
|---|---|---|
| `eskitchen:admin-role:list` | 300s | Tạo / sửa / xóa role |
| `eskitchen:admin-role:<roleId>` | 300s | Sửa role, sửa permission của role |
| `eskitchen:admin-ip-whitelist` | 60s | Thêm / xóa IP |
| `eskitchen:admin:session:<adminId>` | Bằng JWT TTL (e.g. 3600s) | Logout, bị disable, role bị đổi |

**Ghi chú:**
- `eskitchen:admin:session:<adminId>` lưu `session_version` tại thời điểm login. Middleware so sánh với `admins.session_version` trong DB; nếu lệch → reject và trả `401 UNAUTHORIZED`.
- `eskitchen:admin-ip-whitelist` là `SET` Redis chứa toàn bộ IP entries active (String hoặc cidr notation). TTL ngắn để đảm bảo cập nhật nhanh khi thêm/xóa.
- Không cache danh sách admin account do nhạy cảm — chỉ cache role/permission và IP whitelist.

---

## 3. API Contract

> Tất cả endpoint dưới đây đặt trong prefix `/admin/` và yêu cầu `AdminGuard` (JWT Bearer).
> SUPPER_ADMIN check thực hiện ở service layer theo BR-01 và BR-07.

---

### 3.1 Admin Account Endpoints

#### GET /admin/admin-management
Lấy danh sách tài khoản admin.

- **Auth:** Required — AdminGuard
- **Guard:** AdminGuard
- **Request Query:**
  ```
  page?: number (default 1)
  limit?: number (default 20, max 100)
  search?: string (tìm theo username hoặc email)
  orderBy?: 'createdAt' | 'userName' | 'email'
  order?: 'ASC' | 'DESC'
  ```
- **Response 200:**
  ```json
  {
    "data": {
      "items": [
        {
          "id": "1",
          "userName": "string",
          "email": "string",
          "role": { "id": "1", "roleName": "ADMIN" },
          "status": 1,
          "isSupperAdmin": false,
          "lastLoginAt": "2026-01-01T00:00:00Z",
          "createdAt": "2026-01-01T00:00:00Z"
        }
      ],
      "total": 100,
      "page": 1,
      "limit": 20
    }
  }
  ```
- **Error codes:** `401` (unauthenticated)

---

#### POST /admin/admin-management
Tạo tài khoản admin mới.

- **Auth:** Required — AdminGuard
- **Permission check:** `ADMIN_ACCOUNT_MANAGEMENT` EDIT
- **Request Body:**
  ```json
  {
    "userName": "string (required, max 255)",
    "email": "string (required, email format)",
    "password": "string (required, min 8, complexity)",
    "roleId": "string (required, UUID/bigint ID của role)"
  }
  ```
- **Response 201:** `AdminAccountItemResponse` (xem GET detail)
- **Error codes:**
  - `400` — validation fail, email/username duplicate
  - `404` — roleId không tồn tại
  - `403` — không có quyền EDIT

---

#### GET /admin/admin-management/:id
Lấy chi tiết một tài khoản admin.

- **Auth:** Required — AdminGuard
- **Response 200:** `AdminAccountItemResponse`
- **Error codes:** `404` (không tìm thấy)

---

#### PATCH /admin/admin-management/:id
Chỉnh sửa tài khoản admin.

- **Auth:** Required — AdminGuard
- **Permission check:** `ADMIN_ACCOUNT_MANAGEMENT` EDIT
- **Business rule:** SUPPER_ADMIN account không thể edit (BR-01). Chỉ SUPPER_ADMIN mới có thể đổi `roleId` (BR-07).
- **Request Body:**
  ```json
  {
    "userName": "string (optional)",
    "email": "string (optional, email format)",
    "roleId": "string (optional — chỉ SUPPER_ADMIN mới truyền được)"
  }
  ```
- **Side effect khi đổi roleId:** Tăng `session_version` của admin target → invalidate Redis session cache → force logout (BR-07b).
- **Response 200:** `AdminAccountItemResponse`
- **Error codes:**
  - `400` — validation, email duplicate
  - `403` — cố gắng edit SUPPER_ADMIN, hoặc non-SUPPER_ADMIN đổi roleId
  - `404` — account/role không tồn tại

---

#### PATCH /admin/admin-management/:id/status
Disable / Enable tài khoản admin.

- **Auth:** Required — AdminGuard
- **Permission check:** `ADMIN_ACCOUNT_MANAGEMENT` EDIT
- **Business rule:** SUPPER_ADMIN account không thể disable (BR-01).
- **Request Body:**
  ```json
  {
    "status": 1 | 2
    // 1 = ACTIVE, 2 = DISABLED
  }
  ```
- **Side effect khi disable:** Invalidate Redis session cache của admin target → force logout.
- **Response 200:** `{ "message": "OK" }`
- **Error codes:**
  - `403` — cố gắng disable SUPPER_ADMIN
  - `404` — account không tồn tại

---

### 3.2 Role & Permission Endpoints

#### GET /admin/roles
Lấy danh sách role.

- **Auth:** Required — AdminGuard
- **Cache:** `eskitchen:admin-role:list` TTL 300s
- **Response 200:**
  ```json
  {
    "data": {
      "items": [
        {
          "id": "1",
          "roleName": "SUPPER_ADMIN",
          "isSystem": true,
          "permissions": [
            { "module": "COMPANY_MANAGEMENT", "canView": true, "canEdit": true }
          ],
          "adminCount": 1
        }
      ],
      "total": 5
    }
  }
  ```
- **Error codes:** `401`

---

#### POST /admin/roles
Tạo role mới.

- **Auth:** Required — AdminGuard
- **Permission check:** `ADMIN_ACCOUNT_MANAGEMENT` EDIT
- **Request Body:**
  ```json
  {
    "roleName": "string (required, max 100, unique)",
    "permissions": [
      {
        "module": "COMPANY_MANAGEMENT",
        "canView": true,
        "canEdit": false
      }
    ]
  }
  ```
- **Business rule:** BR-03 — nếu `canEdit=true` thì service tự set `canView=true`.
- **Side effect:** Invalidate `eskitchen:admin-role:list`.
- **Response 201:** `AdminRoleDetailResponse`
- **Error codes:**
  - `400` — roleName duplicate, validation
  - `403` — không có quyền EDIT

---

#### GET /admin/roles/:id
Lấy chi tiết role và permission.

- **Auth:** Required — AdminGuard
- **Cache:** `eskitchen:admin-role:<id>` TTL 300s
- **Response 200:** `AdminRoleDetailResponse`
- **Error codes:** `404`

---

#### PATCH /admin/roles/:id
Chỉnh sửa role và permission.

- **Auth:** Required — AdminGuard
- **Permission check:** `ADMIN_ACCOUNT_MANAGEMENT` EDIT
- **Business rule:** `isSystem = true` roles không thể sửa (BR-01 / BR-05).
- **Request Body:** Tương tự POST /admin/roles
- **Side effect:** Invalidate `eskitchen:admin-role:list` và `eskitchen:admin-role:<id>`. Các admin đang dùng role này sẽ thấy permission mới ngay trong request tiếp theo (AC-12).
- **Response 200:** `AdminRoleDetailResponse`
- **Error codes:**
  - `400` — roleName duplicate
  - `403` — cố gắng sửa system role
  - `404`

---

#### DELETE /admin/roles/:id
Xóa role.

- **Auth:** Required — AdminGuard
- **Permission check:** `ADMIN_ACCOUNT_MANAGEMENT` EDIT
- **Business rule:** BR-04 — role đang được gán cho admin → từ chối, trả error kèm `adminCount`.
- **Business rule:** `isSystem = true` → từ chối (BR-01 / BR-05).
- **Response 200:** `{ "message": "OK" }`
- **Error codes:**
  - `400` — role đang được gán (`adminCount > 0`)
  - `403` — cố gắng xóa system role
  - `404`

---

### 3.3 IP Whitelist Endpoints

#### GET /admin/ip-whitelist
Lấy danh sách IP whitelist.

- **Auth:** Required — AdminGuard
- **Response 200:**
  ```json
  {
    "data": {
      "items": [
        {
          "id": "1",
          "ipAddress": "192.168.1.0/24",
          "note": "Office network",
          "createdAt": "2026-01-01T00:00:00Z"
        }
      ],
      "total": 3
    }
  }
  ```

---

#### POST /admin/ip-whitelist
Thêm IP vào whitelist.

- **Auth:** Required — AdminGuard
- **Permission check:** `ADMIN_ACCOUNT_MANAGEMENT` EDIT
- **Request Body:**
  ```json
  {
    "ipAddress": "string (required — IPv4 / IPv6 / CIDR, validate format)",
    "note": "string (optional, max 255)"
  }
  ```
- **Side effect:** Invalidate `eskitchen:admin-ip-whitelist`.
- **Response 201:** `IpWhitelistItemResponse`
- **Error codes:**
  - `400` — format IP không hợp lệ, IP đã tồn tại

---

#### DELETE /admin/ip-whitelist/:id
Xóa IP khỏi whitelist.

- **Auth:** Required — AdminGuard
- **Permission check:** `ADMIN_ACCOUNT_MANAGEMENT` EDIT
- **Side effect:** Invalidate `eskitchen:admin-ip-whitelist`.
- **Response 200:** `{ "message": "OK" }`
- **Error codes:** `404`

---

### 3.4 Email Notification Settings Endpoints

#### GET /admin/admin-management/:id/email-notifications
Lấy cấu hình email notification của một admin.

- **Auth:** Required — AdminGuard
- **Response 200:**
  ```json
  {
    "data": {
      "settings": [
        { "event": "ORDER_CREATED", "isEnabled": true },
        { "event": "COMPANY_REGISTERED", "isEnabled": false }
      ]
    }
  }
  ```

---

#### PATCH /admin/admin-management/:id/email-notifications
Cập nhật cấu hình email notification.

- **Auth:** Required — AdminGuard
- **Request Body:**
  ```json
  {
    "settings": [
      { "event": "ORDER_CREATED", "isEnabled": true },
      { "event": "COMPANY_REGISTERED", "isEnabled": false }
    ]
  }
  ```
- **Response 200:** `{ "message": "OK" }`
- **Error codes:** `400` (event không hợp lệ), `404` (admin không tồn tại)

---

### 3.5 Thay đổi Login Flow (IP Whitelist check)

Endpoint `POST /admin/auth/login` (hiện có trong `AuthService.verifyCredential`) cần bổ sung:

1. Sau khi validate credentials thành công.
2. Query `admin_ip_whitelist` (ưu tiên từ Redis cache `eskitchen:admin-ip-whitelist`).
3. Nếu whitelist rỗng → allow all (BR-06b).
4. Nếu whitelist có entry → kiểm tra IP của request (`X-Forwarded-For` hoặc `req.ip`).
5. IP không khớp → trả `403 FORBIDDEN` với message phù hợp.

---

## 4. Module Changes

### Files cần tạo mới

```
src/entities/
├── admin-role.entity.ts                              (MỚI)
├── admin-role-permission.entity.ts                   (MỚI)
├── admin-ip-whitelist.entity.ts                      (MỚI)
└── admin-email-notification-setting.entity.ts        (MỚI)

src/modules/admin/
├── services/
│   ├── admin-role.service.ts                         (MỚI)
│   ├── admin-ip-whitelist.service.ts                 (MỚI)
│   └── admin-email-notification.service.ts           (MỚI)
├── http/
│   ├── controllers/
│   │   ├── admin-management.controller.ts            (MỚI — tách riêng khỏi account.controller.ts)
│   │   ├── admin-role.controller.ts                  (MỚI)
│   │   └── admin-ip-whitelist.controller.ts          (MỚI)
│   ├── requests/
│   │   ├── create-admin-role.request.ts              (MỚI)
│   │   ├── update-admin-role.request.ts              (MỚI)
│   │   ├── create-ip-whitelist.request.ts            (MỚI)
│   │   ├── update-admin-status.request.ts            (MỚI)
│   │   ├── create-admin-management.request.ts        (MỚI)
│   │   ├── update-admin-management.request.ts        (MỚI)
│   │   └── update-email-notification.request.ts      (MỚI)
│   └── responses/
│       ├── admin-account-item.response.ts            (MỚI)
│       ├── admin-role-detail.response.ts             (MỚI)
│       ├── ip-whitelist-item.response.ts             (MỚI)
│       └── email-notification-setting.response.ts    (MỚI)
├── guards/
│   └── admin-permission.guard.ts                     (MỚI — kiểm tra EDIT/VIEW per module)
└── decorators/
    └── require-permission.decorator.ts               (MỚI)
```

### Files cần sửa

```
src/entities/admin.entity.ts
  → Thêm: roleId (FK), sessionVersion column
  → Thêm: relation adminRole: AdminRole

src/modules/admin/admin.module.ts
  → Thêm TypeOrmModule.forFeature: AdminRole, AdminRolePermission, AdminIpWhitelist, AdminEmailNotificationSetting
  → Thêm providers: AdminRoleService, AdminIpWhitelistService, AdminEmailNotificationService
  → Thêm controllers: AdminManagementController, AdminRoleController, AdminIpWhitelistController
  → Thêm guards: AdminPermissionGuard

src/modules/admin/services/auth.service.ts
  → Thêm IP Whitelist check trong verifyCredential()
  → Thêm sessionVersion vào JWT payload
  → Sửa AdminStrategy.validate() để kiểm tra sessionVersion

database/migrations/
  → 6 files migration mới (xem mục 1.2)
```

---

## 5. Cross-repo Interface

Các endpoint web-admin (E03) sẽ gọi:

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin/admin-management` | Danh sách admin account |
| POST | `/admin/admin-management` | Tạo admin mới |
| GET | `/admin/admin-management/:id` | Chi tiết admin |
| PATCH | `/admin/admin-management/:id` | Sửa admin |
| PATCH | `/admin/admin-management/:id/status` | Disable/Enable |
| GET | `/admin/admin-management/:id/email-notifications` | Cấu hình email |
| PATCH | `/admin/admin-management/:id/email-notifications` | Cập nhật email config |
| GET | `/admin/roles` | Danh sách role |
| POST | `/admin/roles` | Tạo role |
| GET | `/admin/roles/:id` | Chi tiết role |
| PATCH | `/admin/roles/:id` | Sửa role |
| DELETE | `/admin/roles/:id` | Xóa role |
| GET | `/admin/ip-whitelist` | Danh sách IP |
| POST | `/admin/ip-whitelist` | Thêm IP |
| DELETE | `/admin/ip-whitelist/:id` | Xóa IP |

**Lưu ý contract lock trước Phase 3:** Response shape `AdminAccountItemResponse`, `AdminRoleDetailResponse`, `IpWhitelistItemResponse` phải được confirm trước khi FE bắt đầu implement.

---

## 6. Non-Regression Risks

| Risk | Mức độ | Biện pháp |
|---|---|---|
| `admins.role` varchar hiện có trong JWT payload và AuthService — sau migration, JWT cũ sẽ không có `sessionVersion` | HIGH | Thêm `sessionVersion` vào JWT payload; handle gracefully khi payload thiếu field (default 0) — so sánh với `session_version` trong DB |
| `AccountService.createAdminAccount()` đang tạo admin với `role` varchar — cần update để gán `roleId` thay thế | HIGH | Sửa `createAdminAccount()` trong Phase 2 để nhận `roleId`, gán cả `role` (varchar) lẫn `role_id` (FK) để backward compatible |
| `AccountService.updateAdminAccount()` đang update `role` varchar | MEDIUM | Sửa tương tự, giữ đồng bộ cả 2 fields trong Phase 2 |
| Migration 4 (data migration varchar→FK): admin có `role` giá trị không khớp tên role sẽ có `role_id = NULL` | MEDIUM | Kiểm tra sau khi chạy migration — log danh sách admin bị NULL để xử lý thủ công |
| IP Whitelist check trong login flow: nếu Redis down, fallback cần an toàn | MEDIUM | Nếu Redis unavailable → query DB trực tiếp, không để cả login bị block |
| `AdminPermissionGuard` mới — nếu apply sai sẽ break endpoint hiện có | HIGH | Apply guard theo từng endpoint mới; các controller cũ giữ nguyên `AdminGuard` |
| Delete role cascade → `admins.role_id` SET NULL — admin mất role sẽ không thể thực hiện permission check | MEDIUM | Constraint `ON DELETE SET NULL`; handle `role_id = NULL` trong permission guard (deny all non-public) |
