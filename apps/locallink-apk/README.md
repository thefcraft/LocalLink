# locallink_mobile

## Build

```sh
flutter build apk \
  --dart-define=BASE_URL=https://local-link-registry.vercel.app \
  --dart-define=API_KEY=locallink-api-key
```

## Dev

```sh
flutter run -t lib/main_dev.dart
```
