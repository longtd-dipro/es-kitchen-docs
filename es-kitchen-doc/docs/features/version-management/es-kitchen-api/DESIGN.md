# DESIGN: Version Management — es-kitchen-api

> **Feature:** Version Management (Cross-repo Common)
> **Repo:** `es-kitchen-api`
> **Spec:** `es-kitchen-docs/docs/features/version-management/SPEC.md`
> **Date:** 19/05/2026
> **Status:** Draft
> **Author:** Tech Lead

---

## 1. Phân tích entity hiện tại

### 1.1 AppVersion entity hiện tại (bảng `app_versions`)

```
id                       bigint PK auto-increment
platform                 varchar UNIQUE ('ios' | 'android')
min_version              varchar
latest_version           varchar
store_url                varchar
force_update_message     varchar nullable
recommend_update_message varchar nullable
created_at               timestamp
updated_at               timestamp
```

**Vấn đề với thiết kế hiện tại so với SPEC mới:**

| Vấn đề | Chi tiết |
|---|---|
| Schema 1-row-per-platform | Unique constraint trên `platform` — chỉ lưu được 1 record iOS + 1 record Android. SPEC yêu cầu nhiều version records, mỗi record có `version_name` + `version_code` + `environment` riêng. |
| Thiếu `version_name` và `version_code` | Không có trường lưu version name cụ thể (ví dụ `0.1.12`) và version code (build number). |
| Thiếu `environment` | Không có trường để map version → environment (development / staging / production). |
| Thiếu `force_update` boolean | Hiện có `force_update_message` (varchar) nhưng không có boolean flag. Logic force update hiện tại so sánh với `min_version` — SPEC yêu cầu per-record boolean. |
| Thiếu `description` | Không có trường mô tả tự do. |
| Thiếu `download_url` riêng | `store_url` tồn tại nhưng vai trò tương đương `download_url` trong SPEC. |
| Thiếu `deleted_at` (soft delete) | Không có soft delete — cần thêm. |

### 1.2 Service / Controller hiện tại

- `GET /app/version?platform=&version=` trong `UserModule` — public endpoint, logic so sánh `min_version` / `latest_version`.
- `AppVersionService.getVersionInfo()` — query theo platform (findOne), so sánh version string.
- `AppVersionModel` trong Flutter dùng `isRequired`, `isRecommended`, `message`, `storeUrl`.

**Quyết định thiết kế:**

Thiết kế bảng `app_versions` mới hoàn toàn với schema phù hợp SPEC. Migration sẽ:
1. Drop constraint `UQ_app_versions_platform`.
2. Thêm các cột mới: `version_name`, `version_code`, `environment`, `force_update`, `description`, `download_url`, `deleted_at`.
3. Thêm unique constraint composite: `(platform, version_name, version_code)` — áp dụng cho non-deleted records.
4. Giữ nguyên `store_url` (đổi alias thành `download_url` trong API — cột DB giữ tên `download_url`).
5. Endpoint cũ `GET /app/version` trong UserModule cần được refactor để dùng schema mới (xem mục Non-Regression).

---

## 2. Database Design

### 2.1 Schema mới — bảng `app_versions`

```sql
id            bigserial PRIMARY KEY
platform      varchar(10)  NOT NULL  -- 'ios' | 'android'
version_name  varchar(20)  NOT NULL  -- e.g. '1.0.12', '0.1.2'
version_code  integer      NOT NULL  -- build number, e.g. 39
environment   varchar(20)  NOT NULL  -- 'development' | 'staging' | 'production'
download_url  varchar(500) NOT NULL
description   text         NULLABLE
force_update  boolean      NOT NULL  DEFAULT false
created_at    timestamptz  NOT NULL  DEFAULT NOW()
updated_at    timestamptz  NOT NULL  DEFAULT NOW()
deleted_at    timestamptz  NULLABLE  -- soft delete
```

**Indexes:**
- `UQ_app_versions_platform_vname_vcode` — UNIQUE trên `(platform, version_name, version_code)` WHERE `deleted_at IS NULL`
- `IDX_app_versions_platform` — INDEX trên `platform` (để filter)
- `IDX_app_versions_deleted_at` — INDEX trên `deleted_at` (để loại trừ deleted records)

### 2.2 Enum values

```typescript
// Giữ enum AppPlatform hiện có
export enum AppPlatform {
  IOS = 'ios',
  ANDROID = 'android',
}

// Thêm enum mới
export enum AppEnvironment {
  DEVELOPMENT = 'development',
  STAGING = 'staging',
  PRODUCTION = 'production',
}
```

### 2.3 Entity TypeORM mới

File: `src/entities/app-version.entity.ts` — **thay thế hoàn toàn** entity hiện tại.

```typescript
@Entity({ name: 'app_versions' })
export class AppVersion {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id: string;

  @Column({ type: 'varchar', length: 10 })
  platform: AppPlatform;

  @Column({ name: 'version_name', type: 'varchar', length: 20 })
  versionName: string;

  @Column({ name: 'version_code', type: 'integer' })
  versionCode: number;

  @Column({ type: 'varchar', length: 20 })
  environment: AppEnvironment;

  @Column({ name: 'download_url', type: 'varchar', length: 500 })
  downloadUrl: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ name: 'force_update', type: 'boolean', default: false })
  forceUpdate: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;
}
```

---

## 3. Migration Plan

### 3.1 Migration: `AlterAppVersionsTable` (timestamp mới)

Migration này thực hiện **ALTER** bảng hiện có — không drop để tránh mất data.

**up():**
```sql
-- 1. Drop unique constraint cũ (platform unique)
ALTER TABLE app_versions DROP CONSTRAINT IF EXISTS "UQ_app_versions_platform";
DROP INDEX IF EXISTS "UQ_app_versions_platform";

-- 2. Thêm cột mới
ALTER TABLE app_versions
  ADD COLUMN IF NOT EXISTS version_name  varchar(20)  NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS version_code  integer      NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS environment   varchar(20)  NOT NULL DEFAULT 'production',
  ADD COLUMN IF NOT EXISTS download_url  varchar(500) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS description   text,
  ADD COLUMN IF NOT EXISTS force_update  boolean      NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_at    timestamptz;

-- 3. Migrate data cũ: dùng store_url → download_url, min_version → version_name
UPDATE app_versions SET
  version_name = min_version,
  version_code = 1,
  download_url = store_url,
  environment  = 'production'
WHERE version_name = '';

-- 4. Drop cột cũ không còn dùng
ALTER TABLE app_versions
  DROP COLUMN IF EXISTS min_version,
  DROP COLUMN IF EXISTS latest_version,
  DROP COLUMN IF EXISTS store_url,
  DROP COLUMN IF EXISTS force_update_message,
  DROP COLUMN IF EXISTS recommend_update_message;

-- 5. Drop DEFAULT sau khi migrate
ALTER TABLE app_versions
  ALTER COLUMN version_name DROP DEFAULT,
  ALTER COLUMN version_code DROP DEFAULT,
  ALTER COLUMN environment   DROP DEFAULT,
  ALTER COLUMN download_url  DROP DEFAULT;

-- 6. Đổi timestamp sang timestamptz
ALTER TABLE app_versions
  ALTER COLUMN created_at TYPE timestamptz USING created_at AT TIME ZONE 'UTC',
  ALTER COLUMN updated_at TYPE timestamptz USING updated_at AT TIME ZONE 'UTC';

-- 7. Unique partial index (chỉ non-deleted)
CREATE UNIQUE INDEX "UQ_app_versions_platform_vname_vcode"
  ON app_versions (platform, version_name, version_code)
  WHERE deleted_at IS NULL;

-- 8. Support indexes
CREATE INDEX "IDX_app_versions_platform"   ON app_versions (platform);
CREATE INDEX "IDX_app_versions_deleted_at" ON app_versions (deleted_at);
```

**down():**
```sql
-- Reverse: drop new indexes, drop new columns, re-add old columns, re-add old unique
DROP INDEX IF EXISTS "UQ_app_versions_platform_vname_vcode";
DROP INDEX IF EXISTS "IDX_app_versions_platform";
DROP INDEX IF EXISTS "IDX_app_versions_deleted_at";

ALTER TABLE app_versions
  ADD COLUMN IF NOT EXISTS min_version              varchar NOT NULL DEFAULT '1.0.0',
  ADD COLUMN IF NOT EXISTS latest_version           varchar NOT NULL DEFAULT '1.0.0',
  ADD COLUMN IF NOT EXISTS store_url                varchar NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS force_update_message     varchar,
  ADD COLUMN IF NOT EXISTS recommend_update_message varchar;

UPDATE app_versions SET
  min_version    = version_name,
  latest_version = version_name,
  store_url      = download_url;

ALTER TABLE app_versions
  DROP COLUMN IF EXISTS version_name,
  DROP COLUMN IF EXISTS version_code,
  DROP COLUMN IF EXISTS environment,
  DROP COLUMN IF EXISTS download_url,
  DROP COLUMN IF EXISTS description,
  DROP COLUMN IF EXISTS force_update,
  DROP COLUMN IF EXISTS deleted_at;

CREATE UNIQUE INDEX "UQ_app_versions_platform"
  ON app_versions (platform);
```

---

## 4. Module Structure

Feature `app-version` được tách thành 2 controller trong 2 module:

```
src/modules/admin/
├── http/
│   ├── controllers/
│   │   └── app-version.controller.ts     ← CRUD + list, @UseGuards(AdminGuard)
│   ├── requests/
│   │   ├── create-app-version.request.ts
│   │   ├── update-app-version.request.ts
│   │   └── list-app-version.request.ts
│   └── responses/
│       ├── app-version-item.response.ts
│       └── app-version-list.response.ts
└── services/
    └── app-version.service.ts            ← CRUD logic + cache invalidate

src/modules/user/
├── http/
│   ├── controllers/
│   │   └── app-version.controller.ts     ← Public check endpoint (giữ nguyên file, refactor logic)
│   ├── requests/
│   │   └── check-app-version.request.ts  ← Thay GetAppVersionRequest (thêm version_code)
│   └── responses/
│       └── check-app-version.response.ts ← Response mới (thay AppVersionResponse)
└── services/
    └── app-version.service.ts            ← getVersionInfo() refactored
```

`AppVersion` entity được thêm vào `TypeOrmModule.forFeature()` trong cả `AdminModule` và `UserModule`.

---

## 5. API Contract

### 5.1 Admin CRUD — Auth required (`AdminGuard`)

Prefix module: `/admin` (global prefix từ `main.ts`)

#### GET /admin/app-versions

List tất cả version, filter theo platform, không phân trang (data nhỏ, per SPEC).

**Query params:**
```
platform?  'ios' | 'android'   — optional, không truyền = All
```

**Response 200:**
```json
{
  "data": [
    {
      "id": "1",
      "platform": "ios",
      "versionName": "1.0.12",
      "versionCode": 39,
      "environment": "production",
      "downloadUrl": "https://apps.apple.com/app/id123456",
      "description": "Release notes...",
      "forceUpdate": false,
      "createdAt": "2026-05-19T09:00:00.000Z",
      "updatedAt": "2026-05-19T09:00:00.000Z"
    }
  ]
}
```

#### POST /admin/app-versions

**Request body:**
```json
{
  "platform": "ios",
  "versionName": "1.0.13",
  "versionCode": 40,
  "environment": "production",
  "downloadUrl": "https://apps.apple.com/app/id123456",
  "description": "Bug fixes",
  "forceUpdate": false
}
```

**Response 201:** `AppVersionItemResponse` (object đơn lẻ)

**Error 409:** Duplicate `(platform, versionName, versionCode)`

#### PUT /admin/app-versions/:id

**Request body:** Tất cả fields (same as POST — full replace).

**Response 200:** `AppVersionItemResponse`

**Error 404:** Version không tồn tại hoặc đã bị soft delete.

#### DELETE /admin/app-versions/:id

Soft delete — set `deleted_at = NOW()`.

**Response 200:** `{ "message": "Version deleted successfully" }`

**Error 404:** Version không tồn tại hoặc đã bị xóa.

---

### 5.2 Public check — No auth

#### GET /public/app-versions/check

Endpoint public, không cần JWT. Mobile app gọi khi khởi động.

**Query params:**
```
platform      'ios' | 'android'   — required
version_name  string               — required, e.g. '0.1.12'
version_code  integer              — required, e.g. 39
```

**Logic:**
1. Query `app_versions` WHERE `platform = :platform AND version_name = :versionName AND version_code = :versionCode AND deleted_at IS NULL`.
2. Nếu tìm thấy → trả về record với `forceUpdate`, `environment`, `downloadUrl`.
3. Nếu không tìm thấy → trả về HTTP 404 (mobile fallback về env variable mặc định).

**Response 200:**
```json
{
  "data": {
    "platform": "ios",
    "versionName": "0.1.12",
    "versionCode": 39,
    "environment": "staging",
    "downloadUrl": "https://testflight.apple.com/join/xxx",
    "forceUpdate": false
  }
}
```

**Response 404:**
```json
{
  "statusCode": 404,
  "message": "Version not found"
}
```

Mobile xử lý 404 bằng cách fallback về env variable — không crash.

---

## 6. Redis Cache

### 6.1 Pattern: cache-aside

**Key:** `eskitchen:app-version:{platform}:{version_name}:{version_code}`

Ví dụ: `eskitchen:app-version:ios:0.1.12:39`

**TTL:** 300 giây (5 phút) — đủ ngắn để thay đổi từ admin có hiệu lực sớm, đủ dài để giảm DB load khi nhiều thiết bị khởi động đồng thời.

**Scope:** Chỉ cache `GET /public/app-versions/check` (public endpoint, high traffic). Admin CRUD endpoints không cache.

### 6.2 Cache flow

```
GET /public/app-versions/check
  ↓
Check Redis key "eskitchen:app-version:{platform}:{versionName}:{versionCode}"
  ↓ HIT                       ↓ MISS
Return cached JSON         Query PostgreSQL
                              ↓
                           Set Redis key với TTL=300s
                              ↓
                           Return result
```

### 6.3 Cache invalidation

Khi admin thực hiện PUT hoặc DELETE trên một version record:
- Invalidate key: `eskitchen:app-version:{platform}:{versionName}:{versionCode}` của record đó.
- Không cần invalidate wildcard vì key đã specific theo version.

Khi admin tạo version mới (POST): không cần invalidate (key mới chưa tồn tại trong cache).

---

## 7. DTO Design

### 7.1 Request DTOs (Admin)

**`CreateAppVersionRequest`:**
```typescript
class CreateAppVersionRequest {
  @IsEnum(AppPlatform)
  platform: AppPlatform;

  @IsString()
  @Matches(/^\d+(\.\d+)+$/, { message: 'version_name must be numeric dot-separated, e.g. 1.0.12' })
  @MaxLength(20)
  versionName: string;

  @IsInt()
  @Min(1)
  versionCode: number;

  @IsEnum(AppEnvironment)
  environment: AppEnvironment;

  @IsUrl()
  @MaxLength(500)
  downloadUrl: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsBoolean()
  @IsOptional()
  forceUpdate?: boolean;  // default: false
}
```

**`UpdateAppVersionRequest`:** Identical to `CreateAppVersionRequest` (PUT = full replace).

**`ListAppVersionRequest`:**
```typescript
class ListAppVersionRequest {
  @IsOptional()
  @IsEnum(AppPlatform)
  platform?: AppPlatform;
}
```

### 7.2 Request DTO (Public)

**`CheckAppVersionRequest`:**
```typescript
class CheckAppVersionRequest {
  @IsEnum(AppPlatform)
  platform: AppPlatform;

  @IsString()
  @Matches(/^\d+(\.\d+)+$/)
  @Transform(({ value }) => value?.trim())
  versionName: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  versionCode: number;
}
```

### 7.3 Response DTOs

**`AppVersionItemResponse`:**
```typescript
class AppVersionItemResponse {
  id: string;
  platform: string;
  versionName: string;
  versionCode: number;
  environment: string;
  downloadUrl: string;
  description: string | null;
  forceUpdate: boolean;
  createdAt: string;
  updatedAt: string;
}
```

**`AppVersionListResponse`:**
```typescript
class AppVersionListResponse {
  data: AppVersionItemResponse[];
}
```

**`CheckAppVersionResponse`:**
```typescript
class CheckAppVersionResponse {
  platform: string;
  versionName: string;
  versionCode: number;
  environment: string;
  downloadUrl: string;
  forceUpdate: boolean;
}
```

---

## 8. Service Logic

### 8.1 AdminAppVersionService

```
listVersions(query: ListAppVersionRequest)
  → findBy({ platform?, deletedAt: IsNull() })
  → OrderBy createdAt DESC

createVersion(dto: CreateAppVersionRequest)
  → Check duplicate: (platform, versionName, versionCode) WHERE deleted_at IS NULL
  → Throw 409 nếu đã tồn tại
  → save()

updateVersion(id: string, dto: UpdateAppVersionRequest)
  → findOne WHERE id AND deleted_at IS NULL → 404 if not found
  → Check duplicate trừ id hiện tại → 409 if conflict
  → save()
  → invalidate Redis key

deleteVersion(id: string)
  → findOne WHERE id AND deleted_at IS NULL → 404 if not found
  → softDelete(id) — set deleted_at
  → invalidate Redis key
```

### 8.2 UserAppVersionService (refactored)

```
checkVersion(query: CheckAppVersionRequest)
  → Check Redis cache key
  → HIT: return cached
  → MISS:
      findOne WHERE platform + version_name + version_code + deleted_at IS NULL
      → 404 if not found (mobile handles fallback)
      → Set Redis TTL=300s
      → return CheckAppVersionResponse
```

---

## 9. Non-Regression

### 9.1 Breaking change: AppVersion entity

Entity hiện tại được dùng bởi `UserModule/app-version.service.ts`. Service này cần được refactor đồng thời với migration.

**Checklist non-regression:**

| Item | Action |
|---|---|
| `AppVersionService.getVersionInfo()` trong UserModule | Refactor toàn bộ — logic so sánh `min_version`/`latest_version` không còn áp dụng |
| `AppVersionResponse` (response cũ) | Thay bằng `CheckAppVersionResponse` mới |
| `GetAppVersionRequest` (request cũ) | Thay bằng `CheckAppVersionRequest` (thêm `versionCode`) |
| `AppVersionController` trong UserModule | Route `GET /app/version` cần đổi thành `GET /public/app-versions/check` |
| Flutter `AppVersionModel` | Cần update tương ứng (xem payment-app DESIGN.md) |

### 9.2 Route change

| Cũ | Mới | Ghi chú |
|---|---|---|
| `GET /app/version?platform=&version=` | `GET /public/app-versions/check?platform=&version_name=&version_code=` | Thêm `version_code` param; đổi `version` → `version_name` |

Cần coordinate với Flutter team trước khi deploy.

---

## 10. Tasks phân rã

| Task | Mô tả | Phase |
|---|---|---|
| task-1-1 | Migration: AlterAppVersionsTable | Phase 1 |
| task-1-2 | Refactor AppVersion entity + enums | Phase 1 |
| task-2-1 | AdminAppVersionService + DTOs + Repository | Phase 2 |
| task-2-2 | AdminAppVersionController (CRUD) + AdminModule registration | Phase 2 |
| task-2-3 | Refactor UserModule AppVersionService + Controller (public check + Redis) | Phase 2 |
| task-2-4 | Unit tests: AdminAppVersionService, UserAppVersionService | Phase 2 |
