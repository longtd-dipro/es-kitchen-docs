# DESIGN: Maintain Management — es-kitchen-api

> **Feature:** Maintain Management (Cross-repo Common)
> **Repo:** `es-kitchen-api`
> **SPEC:** `es-kitchen-docs/docs/features/maintain-management/SPEC.md`
> **Date:** 19/05/2026
> **Author:** Tech Lead
> **Status:** Draft

---

## 1. Tổng quan thiết kế

### Quyết định thiết kế chính

| Hạng mục | Quyết định | Lý do |
|---|---|---|
| PK của `maintenance_statuses` | `bigint` auto-increment | Nhất quán với pattern `app_versions` — không cần UUID cho bảng config nhỏ |
| Seed data | Trong migration `up()` | 6 rows cố định, cần có ngay sau khi deploy — không cần seed riêng |
| Public endpoint | Module `user` (đang có `/user/...`) | Public controller không cần JWT, nhất quán với `AppVersionController` |
| Redis TTL | 30 giây | Đủ nhanh để recover khi admin tắt maintain; giảm tải DB khi nhiều device check đồng thời |
| Invalidation | Del key ngay sau `PATCH` | Không đợi TTL — đảm bảo admin tắt maintain → mobile recover trong vòng 30s poll |
| Audit trail | Cột `updated_by` + `updated_at` trong chính bảng `maintenance_statuses` | Requirement hiện tại chỉ cần "người thực hiện" + "thời điểm cập nhật" — không cần separate audit log table |
| Module đặt controller public | `MaintenanceModule` riêng | Tránh coupling với `user.module.ts` (quá phình); controller public và controller admin ở cùng 1 module |

---

## 2. Database

### 2.1 Entity: `maintenance_statuses`

```
Table: maintenance_statuses
PK:    id (bigint, auto-increment)
Index: UQ (platform, environment)
```

**Columns:**

| Column | Type | Constraint | Ghi chú |
|---|---|---|---|
| `id` | `bigint` | PK, auto-increment | |
| `platform` | `varchar(20)` | NOT NULL | enum: `ios`, `android` |
| `environment` | `varchar(20)` | NOT NULL | enum: `development`, `staging`, `production` |
| `is_enabled` | `boolean` | NOT NULL, DEFAULT false | Trạng thái maintain |
| `updated_by` | `bigint` | FK → `admins.id`, NULLABLE | NULL nếu chưa ai toggle (trạng thái seed ban đầu) |
| `created_at` | `timestamptz` | NOT NULL, DEFAULT NOW() | |
| `updated_at` | `timestamptz` | NOT NULL, DEFAULT NOW() | Auto-update mỗi lần write |

**Composite unique index:** `UQ_maintenance_statuses_platform_env` trên `(platform, environment)`

### 2.2 Entity TypeScript

**File:** `src/entities/maintenance-status.entity.ts`

```typescript
export enum MaintenancePlatform {
  IOS = 'ios',
  ANDROID = 'android',
}

export enum MaintenanceEnvironment {
  DEVELOPMENT = 'development',
  STAGING = 'staging',
  PRODUCTION = 'production',
}

@Entity({ name: 'maintenance_statuses' })
@Index('UQ_maintenance_statuses_platform_env', ['platform', 'environment'], { unique: true })
export class MaintenanceStatus {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id: string;

  @Column({ type: 'varchar', length: 20 })
  platform: MaintenancePlatform;

  @Column({ type: 'varchar', length: 20 })
  environment: MaintenanceEnvironment;

  @Column({ name: 'is_enabled', type: 'boolean', default: false })
  isEnabled: boolean;

  @Column({ name: 'updated_by', type: 'bigint', nullable: true })
  updatedBy: string | null;

  @ManyToOne(() => Admin, { nullable: true, eager: false })
  @JoinColumn({ name: 'updated_by' })
  updatedByAdmin: Admin | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
```

### 2.3 Migration

**File:** `database/migrations/<timestamp>-CreateMaintenanceStatusesTable.ts`

Migration phải thực hiện theo thứ tự:
1. Tạo bảng `maintenance_statuses`
2. Tạo unique composite index
3. Seed 6 rows mặc định (`is_enabled = false`, `updated_by = NULL`)

**`up()`:**
```typescript
// 1. Tạo bảng
await queryRunner.createTable(new Table({
  name: 'maintenance_statuses',
  columns: [
    { name: 'id', type: 'bigint', isPrimary: true, isGenerated: true, generationStrategy: 'increment' },
    { name: 'platform', type: 'varchar', length: '20', isNullable: false, comment: 'ios | android' },
    { name: 'environment', type: 'varchar', length: '20', isNullable: false, comment: 'development | staging | production' },
    { name: 'is_enabled', type: 'boolean', isNullable: false, default: false },
    { name: 'updated_by', type: 'bigint', isNullable: true, comment: 'FK admins.id — NULL khi chưa có lần toggle nào' },
    { name: 'created_at', type: 'timestamptz', default: 'CURRENT_TIMESTAMP' },
    { name: 'updated_at', type: 'timestamptz', default: 'CURRENT_TIMESTAMP' },
  ],
  foreignKeys: [
    {
      name: 'FK_maintenance_statuses_updated_by',
      columnNames: ['updated_by'],
      referencedTableName: 'admins',
      referencedColumnNames: ['id'],
      onDelete: 'SET NULL',
    },
  ],
}), true);

// 2. Composite unique index
await queryRunner.createIndex('maintenance_statuses', new TableIndex({
  name: 'UQ_maintenance_statuses_platform_env',
  columnNames: ['platform', 'environment'],
  isUnique: true,
}));

// 3. Seed 6 rows mặc định
await queryRunner.query(`
  INSERT INTO maintenance_statuses (platform, environment, is_enabled, updated_by)
  VALUES
    ('ios',     'development', false, NULL),
    ('ios',     'staging',     false, NULL),
    ('ios',     'production',  false, NULL),
    ('android', 'development', false, NULL),
    ('android', 'staging',     false, NULL),
    ('android', 'production',  false, NULL)
`);
```

**`down()`:**
```typescript
await queryRunner.dropTable('maintenance_statuses');
```

---

## 3. Module Structure

**Module:** `src/modules/maintenance/`

```
src/modules/maintenance/
├── maintenance.module.ts
├── http/
│   ├── controllers/
│   │   ├── maintenance-admin.controller.ts    ← GET/PATCH, auth required (AdminGuard)
│   │   └── maintenance-public.controller.ts   ← GET check, no auth
│   ├── requests/
│   │   ├── toggle-maintenance.request.ts
│   │   └── check-maintenance.request.ts
│   └── responses/
│       ├── maintenance-status.response.ts
│       └── maintenance-check.response.ts
├── services/
│   └── maintenance.service.ts
└── maintenance.service.spec.ts
```

`MaintenanceModule` được import vào `AppModule` (không phải vào `AdminModule` hay `UserModule`) để tránh làm phình hai module đã lớn, đồng thời cho phép public controller hoạt động độc lập không cần JWT.

---

## 4. API Contract

### 4.1 GET /admin/maintenance

**Mục đích:** Admin lấy danh sách toàn bộ 6 cặp (platform × environment) với trạng thái hiện tại.

**Auth:** `AdminGuard` (Bearer JWT)

**Controller prefix:** `/admin/maintenance`

**Response 200:**
```json
{
  "data": [
    {
      "id": "1",
      "platform": "ios",
      "environment": "development",
      "isEnabled": false,
      "updatedAt": "2026-05-19T10:00:00.000Z",
      "updatedByAdmin": null
    },
    {
      "id": "2",
      "platform": "ios",
      "environment": "staging",
      "isEnabled": false,
      "updatedAt": "2026-05-19T10:00:00.000Z",
      "updatedByAdmin": null
    },
    {
      "id": "3",
      "platform": "ios",
      "environment": "production",
      "isEnabled": true,
      "updatedAt": "2026-05-19T14:30:00.000Z",
      "updatedByAdmin": {
        "id": "42",
        "userName": "admin_taro"
      }
    }
    // ... 3 rows còn lại
  ]
}
```

**Query:** `SELECT * FROM maintenance_statuses LEFT JOIN admins ON updated_by = admins.id ORDER BY platform ASC, environment ASC`

Không cần cache cho endpoint này (admin-only, ít gọi, cần real-time accuracy).

---

### 4.2 PATCH /admin/maintenance/:id

**Mục đích:** Admin toggle `is_enabled` cho một cặp cụ thể.

**Auth:** `AdminGuard` (Bearer JWT)

**Path param:** `:id` — bigint ID của bản ghi trong `maintenance_statuses`

**Request body:**
```json
{ "isEnabled": true }
```

**DTO:** `ToggleMaintenanceRequest`
```typescript
export class ToggleMaintenanceRequest {
  @IsBoolean()
  isEnabled: boolean;
}
```

**Service logic:**
1. Find `MaintenanceStatus` by `id` — throw `NotFoundException` nếu không tìm thấy
2. Lấy `adminId` từ `request.user` (JWT payload)
3. Update `is_enabled = body.isEnabled`, `updated_by = adminId`, `updated_at = NOW()`
4. Save entity
5. **Invalidate Redis cache:** `DEL eskitchen:maintenance:{platform}:{environment}`
6. Return updated record (cùng shape với item trong GET list)

**Response 200:** Object của bản ghi vừa cập nhật (cùng shape với item trong GET /admin/maintenance)

**Response 404:** Khi `:id` không tồn tại

---

### 4.3 GET /public/maintenance/check

**Mục đích:** Mobile app check trạng thái maintain trước khi khởi động. Public — không cần token.

**Controller prefix:** `/public/maintenance` (no guard)

**Query params:**

| Param | Type | Required | Giá trị hợp lệ |
|---|---|---|---|
| `platform` | string | Yes | `ios`, `android` |
| `environment` | string | Yes | `development`, `staging`, `production` |

**Request DTO:** `CheckMaintenanceRequest`
```typescript
export class CheckMaintenanceRequest {
  @IsEnum(MaintenancePlatform)
  platform: MaintenancePlatform;

  @IsEnum(MaintenanceEnvironment)
  environment: MaintenanceEnvironment;
}
```

**Service logic (cache-aside):**
1. Build Redis key: `eskitchen:maintenance:{platform}:{environment}`
2. Try `GET` key từ Redis
3. Cache hit → parse JSON, return `{ isEnabled: boolean }`
4. Cache miss → query DB: `SELECT is_enabled FROM maintenance_statuses WHERE platform = $1 AND environment = $2`
5. Set Redis: `SET key JSON EX 30`
6. Return `{ isEnabled: boolean }`

**Fail-open:** Nếu DB lỗi → catch, log error, return `{ isEnabled: false }` (không block mobile)

**Response 200:**
```json
{ "isEnabled": false }
```

**Response 400:** `platform` hoặc `environment` không hợp lệ (class-validator fail)

---

## 5. Redis Cache

### Key format

```
eskitchen:maintenance:{platform}:{environment}
```

**Ví dụ:**
- `eskitchen:maintenance:ios:production`
- `eskitchen:maintenance:android:staging`

### TTL

**30 giây** — cân bằng giữa:
- Giảm tải DB (mỗi mobile khởi động đều check, nhiều device đồng thời)
- Recovery speed khi admin tắt maintain (mobile poll mỗi 30s → kết hợp với TTL 30s → worst case 60s)

### Invalidation

Gọi `redis.del(key)` ngay sau khi `save()` trong `PATCH /admin/maintenance/:id` — không đợi TTL hết để đảm bảo trạng thái mới lan ra nhanh nhất.

### Stored value

```json
{ "isEnabled": true }
```

Không cache toàn bộ object (bao gồm updatedByAdmin) — chỉ cache field cần thiết cho public check.

---

## 6. DTO & Response

### MaintenanceStatusResponse (cho admin endpoints)

```typescript
export class MaintenanceAdminItemResponse {
  id: string;
  platform: string;
  environment: string;
  isEnabled: boolean;
  updatedAt: Date;
  updatedByAdmin: { id: string; userName: string } | null;
}

export class MaintenanceAdminListResponse {
  data: MaintenanceAdminItemResponse[];
}
```

### MaintenanceCheckResponse (cho public endpoint)

```typescript
export class MaintenanceCheckResponse {
  isEnabled: boolean;
}
```

---

## 7. Module Registration

`MaintenanceModule` import vào `AppModule`:

```typescript
// app.module.ts — thêm vào imports[]
MaintenanceModule,
```

`MaintenanceModule` khai báo:

```typescript
@Module({
  imports: [
    TypeOrmModule.forFeature([MaintenanceStatus, Admin]),
  ],
  controllers: [
    MaintenanceAdminController,
    MaintenancePublicController,
  ],
  providers: [MaintenanceService],
})
export class MaintenanceModule {}
```

`AdminGuard` được apply tại controller level trên `MaintenanceAdminController`. `MaintenancePublicController` không có guard.

---

## 8. Non-Regression Risks

| Risk | Mức độ | Biện pháp |
|---|---|---|
| `AdminGuard` import conflict với `AdminModule` guard | Thấp | Import trực tiếp `AdminStrategy` vào `MaintenanceModule` hoặc export từ `AdminModule` |
| Redis client không available khi check public | Trung bình | Wrap Redis call trong try/catch — fail-open return `{ isEnabled: false }` |
| Migration FK `updated_by → admins.id` thất bại nếu bảng `admins` chưa tồn tại | Thấp | Đảm bảo timestamp migration > timestamp migration tạo bảng `admins` |
| `PATCH` với `id` không hợp lệ (non-numeric string) | Thấp | TypeORM sẽ không match → `NotFoundException` throw đúng |
| N+1 khi load `updatedByAdmin` trong GET list | Thấp | Dùng `leftJoinAndSelect('ms.updatedByAdmin', 'admin')` trong một query duy nhất |

---

## 9. Task Breakdown (gợi ý)

| Task | Nội dung |
|---|---|
| task-1-1 | Migration: tạo bảng + seed 6 rows |
| task-1-2 | Entity `MaintenanceStatus` + enums |
| task-1-3 | `MaintenanceService` + unit test |
| task-1-4 | `MaintenanceAdminController` (GET list + PATCH toggle) |
| task-1-5 | `MaintenancePublicController` (GET check, public) + Redis cache |
| task-1-6 | `MaintenanceModule` registration + integration smoke test |
