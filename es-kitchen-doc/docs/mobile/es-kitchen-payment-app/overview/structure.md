# es-kitchen-payment-app — Cấu trúc Source

> Repo: `es-kitchen-payment-app` · Epic: E01 User Mobile App · 14 functions
> Stack: Flutter 3.x / Riverpod (hooks_riverpod 3.0.1) / auto_route / Retrofit+Dio

---

## Cấu trúc thư mục

```
es-kitchen-payment-app/
└── lib/
    ├── app/                          ← App-level setup
    │   ├── base/                     ← Base classes (BaseState, etc.)
    │   ├── configs/                  ← App config (từ flutter_dotenv)
    │   ├── core/
    │   │   ├── enums/
    │   │   ├── extensions/           ← Dart extension methods
    │   │   ├── network/              ← Network utilities
    │   │   ├── prefs/                ← SharedPreferences wrapper
    │   │   ├── resources/            ← Colors, strings, assets paths
    │   │   ├── services/             ← Core services (Firebase, Socket.IO)
    │   │   └── utils/
    │   ├── helpers/
    │   ├── routers/
    │   │   ├── app_router.dart       ← @AutoRouterConfig — route declarations
    │   │   └── app_router.gr.dart    ← Generated — KHÔNG sửa tay
    │   └── widgets/                  ← Shared widgets
    │       ├── buttons/
    │       ├── input/
    │       ├── loading_overlay/
    │       ├── pages/
    │       ├── showcase/
    │       ├── skeletons/
    │       └── toast_overlay/
    │
    ├── data/                         ← Data layer
    │   ├── api/
    │   │   ├── app_api.dart          ← @RestApi Retrofit interface
    │   │   ├── app_api.g.dart        ← Generated — KHÔNG sửa tay
    │   │   ├── app_endpoints.dart    ← URL constants
    │   │   └── provider/
    │   │       └── api_provider.dart ← Riverpod provider cho AppApi
    │   ├── logs/
    │   │   ├── app_logger.dart
    │   │   └── app_logger_provider.dart
    │   ├── models/                   ← freezed models (+ .g.dart generated)
    │   │   ├── app/                  ← AppVersion
    │   │   ├── auth/
    │   │   ├── cart/
    │   │   ├── categories/
    │   │   ├── device/
    │   │   ├── ext/                  ← ApiResponse<T>, PaginatedResponse<T>
    │   │   ├── favorite/
    │   │   ├── notification/
    │   │   ├── order/
    │   │   ├── payment/
    │   │   ├── product/
    │   │   ├── purchase/
    │   │   ├── term/
    │   │   ├── toast/
    │   │   └── user/
    │   └── repositories/
    │       ├── repository.dart       ← ApiRepository wrapping AppApi
    │       ├── auth_repository.dart  ← Auth-specific repository
    │       └── provider/             ← Riverpod providers cho repositories
    │
    ├── features/                     ← Feature modules (1 folder per screen)
    │   ├── app_shell/                ← Root shell (wraps bottom bar + screens)
    │   │   ├── controller/
    │   │   ├── provider/
    │   │   ├── state/
    │   │   └── widgets/
    │   ├── auth/
    │   │   ├── login/
    │   │   ├── register/
    │   │   └── forgot_password/
    │   ├── bottom_bar/               ← Bottom navigation
    │   ├── menu/                     ← Menu listing (home screen)
    │   ├── search/                   ← Product search
    │   ├── product_details/          ← Product detail page
    │   ├── cart/                     ← Cart + checkout
    │   ├── favorite/                 ← Favorites list
    │   ├── purchase_history/         ← Order history
    │   ├── refund/                   ← Refund request
    │   ├── notification/             ← Notification list
    │   ├── notification_detail/      ← Notification detail
    │   ├── payment_registration/     ← Credit card / payment method setup
    │   ├── user/                     ← User profile
    │   ├── basic_information/        ← Profile info
    │   ├── policy/                   ← Terms/Privacy
    │   ├── splash/                   ← Splash screen
    │   ├── start/                    ← Onboarding / start
    │   ├── scan_code/                ← Barcode scanner
    │   ├── scan_qr/                  ← QR code scanner
    │   └── widgets/                  ← Feature-level shared widgets
    │
    ├── flavor/                       ← Flutter flavors (DEV/STG/PROD)
    └── gen/                          ← Generated assets (flutter_gen)
```

---

## Feature Module Structure (pattern nhất quán)

Mỗi feature trong `features/<feature>/`:

```
<feature>/
├── controller/
│   └── <feature>_controller.dart    ← StateNotifier business logic
├── provider/
│   └── <feature>_provider.dart      ← Riverpod provider declarations
├── state/
│   └── <feature>_state.dart         ← freezed state class
├── ui/
│   └── <feature>_page.dart          ← @RoutePage widget
└── widgets/                         ← Page-specific widgets
```

---

## Navigation (auto_route)

Route hierarchy:

```
Splash (initial)
  └── Start (onboarding)
        └── Login / Register / ForgotPassword
              └── AppShell (authenticated root)
                    ├── BottomBar (initial)  ← Menu, Favorite, Notification, User tabs
                    ├── Search
                    ├── ProductDetails
                    ├── Cart → CartDetailsConfirm → PaymentMethods
                    ├── PurchaseHistory → PurchaseDetail
                    ├── Refund
                    ├── NotificationDetail
                    ├── PaymentRegistration
                    ├── BasicInformation → EditInformation
                    ├── ScanCode / ScanQR
                    ├── Policy
                    └── CreditCardManagement / SelectCreditCard
```

**Quy tắc:**
- Navigate: `context.router.push(RouteNameRoute())` — không `Navigator.push`
- `app_router.gr.dart` là file generated — không sửa tay, chỉ thêm route trong `app_router.dart`

---

## Data Flow

```
UI (ConsumerWidget / HookConsumerWidget)
    │ ref.watch(featureProvider)
    ▼
Provider (StateNotifierProvider)
    │ notifier methods
    ▼
Controller (StateNotifier)
    │ repository calls
    ▼
ApiRepository
    │ AppApi (Retrofit)
    ▼
NestJS API
```

---

## Models (freezed)

```dart
@freezed
class ProductDetailModel with _$ProductDetailModel {
  const factory ProductDetailModel({
    required String id,
    required String name,
    @JsonKey(name: 'image_url') String? imageUrl,
  }) = _ProductDetailModel;

  factory ProductDetailModel.fromJson(Map<String, dynamic> json) =>
      _$ProductDetailModelFromJson(json);
}
```

**Sau khi thêm/sửa model:** Bắt buộc chạy:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Các file `.g.dart` là generated — không sửa tay.

---

## Riverpod Providers

```dart
// provider/menu_provider.dart
final menuControllerProvider =
    StateNotifierProvider<MenuController, MenuState>((ref) {
  final repository = ref.read(apiRepositoryProvider);
  return MenuController(repository);
});
```

```dart
// UI: ConsumerWidget
class MenuPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(menuControllerProvider);
    return state.when(
      loading: () => const CircularProgressIndicator(),
      data: (products) => ProductList(products: products),
      error: (e, _) => ErrorWidget(e.toString()),
    );
  }
}
```

**Quy tắc:**
- Dùng `hooks_riverpod` — không dùng `flutter_riverpod` standalone
- Không dùng Provider, BLoC, GetX
- `ref.read()` trong actions, `ref.watch()` trong build

---

## Payment Flow (elepay)

```dart
// elepay_flutter 3.5.2
final elepayResult = await Elepay.handlePayload(payload);
// payload từ NestJS /user/checkout
```

Không dùng Stripe hoặc payment SDK khác.

---

## Socket.IO

```dart
// Cleanup bắt buộc trong dispose
@override
void dispose() {
  socket.off('order_updated');
  socket.disconnect();
  super.dispose();
}
```

---

## Version Convention

| Env | `pubspec.yaml` version | Ghi chú |
|---|---|---|
| DEV | `0.0.<buildNumber>` | |
| STG | `0.1.<buildNumber>` | TestFlight Internal |
| PROD | `1.0.<buildNumber>` | App Store / Play Store |
