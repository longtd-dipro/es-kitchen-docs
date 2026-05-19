# DESIGN: Version Management — es-kitchen-payment-app (E01)

> **Feature:** Version Management (Cross-repo Common)
> **Repo:** `es-kitchen-payment-app`
> **Spec:** `es-kitchen-docs/docs/features/version-management/SPEC.md`
> **API Design:** `es-kitchen-docs/docs/features/version-management/es-kitchen-api/DESIGN.md`
> **Date:** 19/05/2026
> **Status:** Draft
> **Author:** Tech Lead

---

## 1. Tổng quan thay đổi

### 1.1 Breaking change từ API

API endpoint check version thay đổi:

| | Cũ | Mới |
|---|---|---|
| Path | `GET /app/version` | `GET /public/app-versions/check` |
| Params | `platform`, `version` | `platform`, `version_name`, `version_code` |
| Response | `isRequired`, `isRecommended`, `message`, `storeUrl` | `environment`, `forceUpdate`, `downloadUrl` |
| Logic | So sánh với min_version / latest_version | Exact match theo version_name + version_code |
| Not found | 404 (cũ ném lỗi) | 404 (mới: mobile phải handle gracefully với fallback) |

### 1.2 Model hiện tại cần thay thế

`AppVersionModel` hiện tại (file: `lib/data/models/app/app_version_model.dart`) dùng `isRequired`, `isRecommended`, `message` — không khớp với response mới. File này cần được refactor hoàn toàn.

---

## 2. Dart Model

### 2.1 Model mới: `CheckVersionResponse`

File: `lib/data/models/app/check_version_response.dart`

Dùng pattern `freezed` + `json_serializable` (consistent với project):

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'check_version_response.freezed.dart';
part 'check_version_response.g.dart';

@freezed
class CheckVersionResponse with _$CheckVersionResponse {
  const factory CheckVersionResponse({
    required String platform,
    @JsonKey(name: 'versionName') required String versionName,
    @JsonKey(name: 'versionCode') required int versionCode,
    required String environment,
    @JsonKey(name: 'downloadUrl') required String downloadUrl,
    @JsonKey(name: 'forceUpdate') required bool forceUpdate,
  }) = _CheckVersionResponse;

  factory CheckVersionResponse.fromJson(Map<String, dynamic> json) =>
      _$CheckVersionResponseFromJson(json);
}
```

**Lưu ý:** `AppVersionModel` cũ (`app_version_model.dart`) được giữ nguyên nếu còn được dùng bởi feature khác. Nếu chỉ dùng cho check version, đánh dấu deprecated và thay thế.

### 2.2 Enum helper

```dart
enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment fromString(String value) {
    return AppEnvironment.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppEnvironment.production, // fallback an toàn
    );
  }
}
```

---

## 3. Repository / Data Source

### 3.1 Interface

File: `lib/data/repositories/app_version_repository.dart`

```dart
abstract class AppVersionRepository {
  Future<CheckVersionResponse?> checkVersion({
    required String platform,
    required String versionName,
    required int versionCode,
  });
}
```

Trả về `null` khi API 404 (version không tìm thấy) — thay vì throw exception, để caller xử lý fallback.

### 3.2 Implementation

File: `lib/data/repositories/app_version_repository_impl.dart`

```dart
class AppVersionRepositoryImpl implements AppVersionRepository {
  const AppVersionRepositoryImpl(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<CheckVersionResponse?> checkVersion({
    required String platform,
    required String versionName,
    required int versionCode,
  }) async {
    try {
      final response = await _apiClient.checkAppVersion(
        platform: platform,
        versionName: versionName,
        versionCode: versionCode,
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // version không tìm thấy — caller dùng fallback
      }
      rethrow; // các lỗi khác (network, server error) → vẫn propagate
    }
  }
}
```

### 3.3 Retrofit API client method

File: `lib/data/remote/api_client.dart` — thêm method:

```dart
@GET('/public/app-versions/check')
Future<ApiResponse<CheckVersionResponse>> checkAppVersion({
  @Query('platform') required String platform,
  @Query('version_name') required String versionName,
  @Query('version_code') required int versionCode,
});
```

---

## 4. Riverpod Provider

File: `lib/providers/app_version_provider.dart`

### 4.1 State class

```dart
@freezed
class AppVersionState with _$AppVersionState {
  const factory AppVersionState.initial() = _Initial;
  const factory AppVersionState.loading() = _Loading;
  const factory AppVersionState.loaded({
    required CheckVersionResponse version,
    required AppEnvironment environment,
  }) = _Loaded;
  const factory AppVersionState.fallback({
    required AppEnvironment environment, // từ env variable
  }) = _Fallback;
  const factory AppVersionState.error(String message) = _Error;
}
```

### 4.2 Notifier

```dart
@riverpod
class AppVersionNotifier extends _$AppVersionNotifier {
  @override
  AppVersionState build() => const AppVersionState.initial();

  Future<void> checkVersion() async {
    state = const AppVersionState.loading();

    // Lấy version info từ package_info_plus
    final packageInfo = await PackageInfo.fromPlatform();
    final platform = Platform.isIOS ? 'ios' : 'android';

    try {
      final result = await ref
          .read(appVersionRepositoryProvider)
          .checkVersion(
            platform: platform,
            versionName: packageInfo.version,      // e.g. '0.1.12'
            versionCode: int.parse(packageInfo.buildNumber), // e.g. 39
          );

      if (result == null) {
        // API 404 — fallback về env variable
        final fallbackEnv = _getFallbackEnvironment();
        state = AppVersionState.fallback(environment: fallbackEnv);
        return;
      }

      final env = AppEnvironment.fromString(result.environment);
      state = AppVersionState.loaded(version: result, environment: env);
    } catch (e) {
      // Network error / server error — fallback gracefully
      // Không crash app; dùng env variable mặc định
      // OQ-02 chưa resolve: tạm thời fallback về env variable
      final fallbackEnv = _getFallbackEnvironment();
      state = AppVersionState.fallback(environment: fallbackEnv);
    }
  }

  AppEnvironment _getFallbackEnvironment() {
    // Đọc từ env variable được nhúng lúc build
    // Ví dụ: const String.fromEnvironment('APP_ENV', defaultValue: 'production')
    const envString = String.fromEnvironment('APP_ENV', defaultValue: 'production');
    return AppEnvironment.fromString(envString);
  }
}
```

**Lưu ý OQ-02 (chưa resolve):** Hành vi khi không có internet chưa được client confirm. Thiết kế hiện tại fallback về env variable mặc định (không crash). Nếu client yêu cầu cache kết quả từ lần check trước → cần thêm local persistence (SharedPreferences/Hive) — sẽ thiết kế bổ sung khi OQ-02 resolve.

---

## 5. Startup Flow

### 5.1 App initialization sequence

```
main() / runApp()
  ↓
SplashScreen / InitializationWidget
  ↓
appVersionNotifier.checkVersion()
  ↓
  ┌─ AppVersionState.loaded ──────────────────┐
  │  forceUpdate == true?                     │
  │    YES → navigate to ForceUpdateScreen    │
  │    NO  → set API base URL = environment   │
  │          → navigate to LoginScreen        │
  └───────────────────────────────────────────┘
  ┌─ AppVersionState.fallback ────────────────┐
  │  Set API base URL = fallback environment  │
  │  → navigate to LoginScreen (no error msg) │
  └───────────────────────────────────────────┘
  ┌─ AppVersionState.error ───────────────────┐
  │  Tương tự fallback — không crash          │
  │  → navigate to LoginScreen                │
  └───────────────────────────────────────────┘
```

### 5.2 API base URL switching

Sau khi xác định `AppEnvironment`, app set base URL của `ApiClient` / Dio instance tương ứng:

```dart
String getBaseUrl(AppEnvironment env) {
  switch (env) {
    case AppEnvironment.development:
      return const String.fromEnvironment('API_URL_DEV');
    case AppEnvironment.staging:
      return const String.fromEnvironment('API_URL_STG');
    case AppEnvironment.production:
      return const String.fromEnvironment('API_URL_PROD');
  }
}
```

Các URL này được nhúng vào app lúc build qua `--dart-define` — không hard-code, không trong `.env` file production.

---

## 6. Force Update Screen

### 6.1 Screen design

File: `lib/screens/force_update/force_update_screen.dart`

**Đặc điểm:**
- Màn hình full-screen, không có nút back.
- Không cho phép navigate ra ngoài (override `WillPopScope` / `PopScope`).
- Hiển thị thông báo buộc cập nhật.
- Nút "Download" / "Update Now" → mở `downloadUrl` bằng `url_launcher`.

```dart
class ForceUpdateScreen extends ConsumerWidget {
  const ForceUpdateScreen({
    super.key,
    required this.downloadUrl,
    required this.platform,
  });

  final String downloadUrl;
  final String platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,  // Block back navigation hoàn toàn
      child: Scaffold(
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon / illustration
              // Title: "アプリのアップデートが必要です" (hoặc theo i18n)
              // Body text giải thích
              ElevatedButton(
                onPressed: () => launchUrl(Uri.parse(downloadUrl)),
                child: const Text('Update Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 6.2 Navigation

- `ForceUpdateScreen` không có route param trên navigation stack bình thường.
- Khi `forceUpdate == true`: dùng `context.router.replaceAll([ForceUpdateRoute(...)])` — xóa toàn bộ stack, không có màn hình nào phía sau để back về.

---

## 7. Integration với Routing (auto_route)

File: `lib/router/app_router.dart`

Thêm route:
```dart
AutoRoute(page: ForceUpdateRoute.page, initial: false),
```

Startup logic nằm ở `SplashScreen` hoặc `InitializationWidget` — watch `appVersionProvider` và navigate dựa trên state.

---

## 8. Non-Regression

### 8.1 Thay đổi ảnh hưởng đến code hiện tại

| File hiện tại | Thay đổi cần thiết |
|---|---|
| `lib/data/models/app/app_version_model.dart` | Deprecated — thay bằng `check_version_response.dart`. Nếu không còn dùng bởi feature nào khác thì xóa. |
| `lib/data/models/app/app_version_model.g.dart` | Xóa cùng với model cũ (generated file). |
| API client cũ (endpoint `/app/version`) | Xóa method cũ, thêm method mới `/public/app-versions/check` với params mới. |
| Startup logic hiện tại (nếu đã gọi check version) | Refactor để dùng `AppVersionNotifier` + `CheckVersionResponse` mới. |

### 8.2 Cần coordinate với BE

- Confirm thời điểm BE deploy migration + refactor endpoint.
- **Không update Flutter trước khi BE đã deploy endpoint mới** — sẽ gây lỗi kết nối.
- Contract lock cần xác nhận: `GET /public/app-versions/check` params `platform`, `version_name`, `version_code` và response schema trước khi bắt đầu Phase 3.

---

## 9. Dependency

Đảm bảo các package sau đã có trong `pubspec.yaml`:

| Package | Mục đích |
|---|---|
| `freezed_annotation` | Immutable model |
| `json_annotation` | JSON serialization |
| `hooks_riverpod` 3.0.1 | State management |
| `riverpod_annotation` | Code generation cho provider |
| `package_info_plus` | Đọc `version` và `buildNumber` hiện tại của app |
| `url_launcher` | Mở download URL từ ForceUpdateScreen |
| `dio` + `retrofit` | HTTP client |

---

## 10. Tasks phân rã

| Task | Mô tả | Phase |
|---|---|---|
| task-3-1 | `CheckVersionResponse` model (freezed) + regenerate | Phase 3 |
| task-3-2 | `AppVersionRepository` interface + implementation | Phase 3 |
| task-3-3 | Retrofit API client — thêm method `/public/app-versions/check` | Phase 3 |
| task-3-4 | `AppVersionNotifier` + `AppVersionState` (Riverpod) | Phase 3 |
| task-3-5 | `ForceUpdateScreen` UI + PopScope block | Phase 3 |
| task-3-6 | Startup flow integration — watch provider, set base URL, navigate | Phase 3 |
| task-3-7 | Cleanup: deprecate/remove `AppVersionModel` cũ | Phase 3 |

---

## 11. Open Questions cần resolve trước Phase 3

| OQ | Câu hỏi | Impact |
|---|---|---|
| OQ-02 | Khi không có internet lúc khởi động, app có dùng cached result từ lần check trước? | Nếu YES → cần thêm local persistence (SharedPreferences/Hive) vào design |
| OQ-05 | Khi nhiều version cùng platform có Force Update = True, app check theo version nào? (SPEC: exact match theo version_name + version_code → chỉ version khớp chính xác mới bị block — confirm với client) | Ảnh hưởng logic in `AppVersionNotifier.checkVersion()` |
