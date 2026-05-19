# DESIGN: Maintain Management — es-kitchen-payment-app (E01)

> **Feature:** Maintain Management (Cross-repo Common)
> **Repo:** `es-kitchen-payment-app`
> **SPEC:** `es-kitchen-docs/docs/features/maintain-management/SPEC.md`
> **Date:** 19/05/2026
> **Author:** Tech Lead
> **Status:** Draft

---

## 1. Tổng quan thiết kế

### Quyết định thiết kế chính

| Hạng mục | Quyết định | Lý do |
|---|---|---|
| Điểm check maintain | `SplashScreen` — trước khi navigate đến bất kỳ route nào | BR-03: check trước tất cả flow — Splash là điểm entry duy nhất của app |
| Provider type | `AsyncNotifier` (Riverpod 3 / hooks_riverpod 3.0.1) | Nhất quán với pattern StateNotifierProvider, đủ đơn giản cho use case này |
| Polling khi block | `Timer.periodic` trong notifier, cancel khi `isEnabled = false` | Không dùng library phụ; `Timer` đủ dùng cho interval 30s |
| Fail-open | Catch exception trong `checkMaintenance()` → return `false` | BR-05: không block user khi API không khả dụng |
| Overlay widget | `Stack` + `Positioned.fill` tại root `AppShell` hoặc `MaterialApp.builder` | Z-index cao nhất, không dismissable, không ảnh hưởng route stack |
| Không dismiss | Không có close button; `WillPopScope` + `PopScope` chặn back gesture | BR-04 |
| Nội dung popup | Cố định (không tùy chỉnh) | Out of scope: "Maintain message tùy chỉnh" |
| Platform detect | `Platform.isIOS` / `Platform.isAndroid` (dart:io) | Build-time info, không cần thêm package |
| Environment detect | `AppConfig` từ `flavor/` (đã có trong app) | Flavor-based env đã được setup trong project |

---

## 2. API Endpoint

**Endpoint:** `GET /public/maintenance/check`

**Query params:**

| Param | Type | Giá trị |
|---|---|---|
| `platform` | String | `ios` hoặc `android` |
| `environment` | String | `development`, `staging`, `production` |

**Response:**
```json
{ "isEnabled": false }
```

**Không cần auth header** — public endpoint.

---

## 3. Dart Model (freezed)

**File:** `lib/data/models/maintenance/maintenance_check_response.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'maintenance_check_response.freezed.dart';
part 'maintenance_check_response.g.dart';

@freezed
class MaintenanceCheckResponse with _$MaintenanceCheckResponse {
  const factory MaintenanceCheckResponse({
    @JsonKey(name: 'isEnabled') required bool isEnabled,
  }) = _MaintenanceCheckResponse;

  factory MaintenanceCheckResponse.fromJson(Map<String, dynamic> json) =>
      _$MaintenanceCheckResponseFromJson(json);
}
```

Sau khi tạo file: chạy `dart run build_runner build --delete-conflicting-outputs` để generate `.freezed.dart` và `.g.dart`.

---

## 4. API Definition (Retrofit)

**File:** `lib/data/api/app_api.dart` — thêm method vào `AppApi` interface:

```dart
// Thêm vào abstract class AppApi
@GET('/public/maintenance/check')
Future<MaintenanceCheckResponse> checkMaintenance(
  @Query('platform') String platform,
  @Query('environment') String environment,
);
```

Sau khi sửa: chạy `dart run build_runner build --delete-conflicting-outputs`.

---

## 5. Repository

**File:** `lib/data/repositories/repository.dart` — thêm method:

```dart
// Trong ApiRepository
Future<bool> checkMaintenance({
  required String platform,
  required String environment,
}) async {
  final response = await _api.checkMaintenance(platform, environment);
  return response.isEnabled;
}
```

Nếu `ApiRepository` interface được tách riêng, khai báo method tương ứng trong interface.

---

## 6. Platform & Environment Helpers

**File:** `lib/app/core/utils/maintenance_platform_helper.dart`

```dart
import 'dart:io';
import 'package:es_kitchen/flavor/app_config.dart';   // path tùy cấu trúc flavor

class MaintenancePlatformHelper {
  /// Trả về 'ios' hoặc 'android'
  static String get currentPlatform =>
      Platform.isIOS ? 'ios' : 'android';

  /// Trả về 'development', 'staging', 'production'
  /// Đọc từ AppConfig (flavor-based)
  static String get currentEnvironment => AppConfig.environment;
}
```

`AppConfig.environment` phải trả về đúng giá trị `'development'` | `'staging'` | `'production'` — xác nhận với flavor config hiện có.

---

## 7. Riverpod Provider & Notifier

### 7.1 State

**File:** `lib/features/maintenance/state/maintenance_state.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'maintenance_state.freezed.dart';

@freezed
class MaintenanceState with _$MaintenanceState {
  const factory MaintenanceState({
    @Default(false) bool isEnabled,
    @Default(false) bool isChecking,   // true khi đang gọi API lần đầu
    @Default(false) bool isPolling,    // true khi Timer đang chạy
  }) = _MaintenanceState;
}
```

### 7.2 Controller (StateNotifier)

**File:** `lib/features/maintenance/controller/maintenance_controller.dart`

```dart
import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../data/repositories/provider/repository_provider.dart';
import '../../../app/core/utils/maintenance_platform_helper.dart';
import '../state/maintenance_state.dart';

class MaintenanceController extends StateNotifier<MaintenanceState> {
  MaintenanceController(this._repository) : super(const MaintenanceState());

  final ApiRepository _repository;
  Timer? _pollingTimer;

  static const _pollInterval = Duration(seconds: 30);

  /// Gọi khi app khởi động (trong SplashController hoặc AppShell)
  Future<void> checkOnStartup() async {
    state = state.copyWith(isChecking: true);
    try {
      final isEnabled = await _repository.checkMaintenance(
        platform: MaintenancePlatformHelper.currentPlatform,
        environment: MaintenancePlatformHelper.currentEnvironment,
      );
      state = state.copyWith(isEnabled: isEnabled, isChecking: false);
      if (isEnabled) {
        _startPolling();
      }
    } catch (_) {
      // Fail-open: lỗi mạng → tiếp tục app bình thường
      state = state.copyWith(isEnabled: false, isChecking: false);
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    state = state.copyWith(isPolling: true);
    _pollingTimer = Timer.periodic(_pollInterval, (_) => _pollCheck());
  }

  Future<void> _pollCheck() async {
    try {
      final isEnabled = await _repository.checkMaintenance(
        platform: MaintenancePlatformHelper.currentPlatform,
        environment: MaintenancePlatformHelper.currentEnvironment,
      );
      if (!isEnabled) {
        // Admin đã tắt maintain — dismiss overlay, dừng polling
        _stopPolling();
        state = state.copyWith(isEnabled: false);
      }
    } catch (_) {
      // Fail-open: poll error không làm gì — tiếp tục polling chu kỳ sau
    }
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    state = state.copyWith(isPolling: false);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
```

### 7.3 Provider

**File:** `lib/features/maintenance/provider/maintenance_provider.dart`

```dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../data/repositories/provider/repository_provider.dart';
import '../controller/maintenance_controller.dart';
import '../state/maintenance_state.dart';

final maintenanceControllerProvider =
    StateNotifierProvider<MaintenanceController, MaintenanceState>((ref) {
  final repository = ref.read(apiRepositoryProvider);
  return MaintenanceController(repository);
});
```

---

## 8. Integration vào App Startup

### Điểm trigger: SplashController

**File:** `lib/features/splash/controller/splash_controller.dart` — thêm check maintain trước khi navigate:

```dart
// Trong SplashController.initializeApp() hoặc tương đương
Future<void> initializeApp() async {
  // 1. Check maintain TRƯỚC tất cả flow khác
  await ref.read(maintenanceControllerProvider.notifier).checkOnStartup();

  // maintenanceControllerProvider sẽ tự giữ state — không navigate nếu isEnabled = true
  // Overlay widget ở AppShell/MaterialApp.builder sẽ tự render

  // 2. Tiếp tục các init khác (auth check, etc.) — chỉ thực hiện nếu maintain OFF
  final isUnderMaintenance = ref.read(maintenanceControllerProvider).isEnabled;
  if (isUnderMaintenance) return; // dừng ở đây — overlay sẽ hiển thị

  // 3. Continue normal startup flow (auth check, navigate to login/home...)
  await _checkAuthState();
}
```

---

## 9. Maintenance Overlay Widget

**File:** `lib/features/maintenance/widgets/maintenance_overlay.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MaintenanceOverlay extends StatelessWidget {
  const MaintenanceOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,            // Chặn back button / gesture
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.85),
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.build_circle_outlined, size: 80.sp, color: Colors.white),
                SizedBox(height: 24.h),
                Text(
                  'メンテナンス中',    // "Under Maintenance" — nội dung cố định per SPEC Out of Scope
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                Text(
                  'ただいまメンテナンス中です。\nしばらくお待ちください。',
                  style: TextStyle(color: Colors.white70, fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**Nội dung cố định** — Out of scope: "Maintain message tùy chỉnh" (SPEC mục 7).

---

## 10. Overlay Placement — MaterialApp.builder

Overlay đặt tại `MaterialApp.builder` để đảm bảo z-index cao nhất, overlay toàn bộ route stack:

**File:** `lib/app/app.dart` hoặc `lib/main.dart` — trong `MaterialApp` hoặc `MaterialApp.router`:

```dart
// Trong root app widget — ConsumerWidget
@override
Widget build(BuildContext context, WidgetRef ref) {
  final maintenanceState = ref.watch(maintenanceControllerProvider);

  return MaterialApp.router(
    routerConfig: _appRouter.config(),
    builder: (context, child) {
      return Stack(
        children: [
          child ?? const SizedBox.shrink(),
          if (maintenanceState.isEnabled)
            const Positioned.fill(
              child: MaintenanceOverlay(),
            ),
        ],
      );
    },
  );
}
```

Cách này đảm bảo `MaintenanceOverlay` render phía trên toàn bộ route tree, kể cả dialog hay bottom sheet đang mở.

---

## 11. Feature Directory Structure

```
lib/features/maintenance/
├── controller/
│   └── maintenance_controller.dart
├── provider/
│   └── maintenance_provider.dart
├── state/
│   └── maintenance_state.dart
│   └── maintenance_state.freezed.dart      ← generated
└── widgets/
    └── maintenance_overlay.dart
```

```
lib/data/models/maintenance/
├── maintenance_check_response.dart
├── maintenance_check_response.freezed.dart  ← generated
└── maintenance_check_response.g.dart        ← generated
```

---

## 12. Sequence Diagram

```
User opens app
      │
      ▼
SplashController.initializeApp()
      │
      ├─ maintenanceController.checkOnStartup()
      │       │
      │       ├─ GET /public/maintenance/check?platform=ios&environment=production
      │       │       │
      │       │       ├─ [Response: isEnabled=false]
      │       │       │       → state.isEnabled = false
      │       │       │       → continue normal startup
      │       │       │
      │       │       ├─ [Response: isEnabled=true]
      │       │       │       → state.isEnabled = true
      │       │       │       → _startPolling()
      │       │       │       → return (stop startup)
      │       │       │       → MaterialApp.builder shows MaintenanceOverlay
      │       │       │
      │       │       └─ [Network error / timeout]
      │       │               → catch → state.isEnabled = false (fail-open)
      │       │               → continue normal startup
      │       │
      │       ▼ (polling active, every 30s)
      │  _pollCheck()
      │       ├─ [isEnabled=true]  → do nothing, keep overlay
      │       └─ [isEnabled=false] → _stopPolling(), state.isEnabled=false
      │                             → overlay auto-dismisses (ref.watch reactive)
      │
      ▼
  Normal app flow (auth check → login / home)
```

---

## 13. Non-Regression Risks

| Risk | Biện pháp |
|---|---|
| `Platform.isIOS` / `Platform.isAndroid` trả về sai trên web | App là mobile-only (iOS + Android) — không cần handle web |
| `AppConfig.environment` trả về giá trị khác với enum của API (`'dev'` vs `'development'`) | Xác nhận giá trị string trong `AppConfig` khớp với API enum trước khi release; viết unit test cho `MaintenancePlatformHelper` |
| Timer không bị cancel khi widget dispose | `MaintenanceController.dispose()` cancel timer — đảm bảo provider `scope` hợp lý (root-scoped) |
| Overlay render khi `isChecking = true` (flickering) | Chỉ render overlay khi `isEnabled = true` — không render khi đang check |
| `PopScope` không chặn back gesture trên một số Android version | Test trên Android 12+ và 13+; bổ sung `onPopInvoked: (didPop) {}` nếu cần |
| Polling tiếp tục sau khi app vào background | `Timer.periodic` tiếp tục chạy ở background là acceptable (interval 30s, request nhỏ) — nếu cần optimize sau có thể dùng `WidgetsBindingObserver` |

---

## 14. Task Breakdown (gợi ý)

| Task | Nội dung |
|---|---|
| task-3-1 | `MaintenanceCheckResponse` model (freezed) + `checkMaintenance()` trong `AppApi` |
| task-3-2 | `checkMaintenance()` method trong `ApiRepository` |
| task-3-3 | `MaintenancePlatformHelper` + `MaintenanceState` (freezed) |
| task-3-4 | `MaintenanceController` (check + polling + fail-open) + unit test |
| task-3-5 | `MaintenanceOverlay` widget (UI) |
| task-3-6 | Integration: `MaterialApp.builder` overlay + `SplashController` trigger |
| task-3-7 | Manual test: check ON/OFF, polling recover, fail-open (network off) |
