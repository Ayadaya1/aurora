# Aurora OS 5.2.1

Текущее состояние кандидата 1.0.0+4 и оставшиеся проверки: [SMOKE.md](SMOKE.md).
Имеющиеся RPM 1.0.0+3 содержат ошибку picker и не готовы к публикации.

Проект собирается в release RPM для `aarch64` (ARM64) и `armv7hl` (ARM32).
Используются Flutter для Aurora 3.41.4, Dart 3.11.1 и Aurora Platform SDK
5.2.1.200. Обычный Flutter SDK для Android не содержит сборочную цель Aurora.

## Повторная сборка на настроенном сервере

Рабочая копия с доступом к SDK находится в `/home/aurora-build/aurora-server`.
Сборка должна выполняться пользователем `aurora-build`: `sdk-assistant`
не допускает работу от root.

```bash
cd /home/aurora-build/aurora-server
runuser -u aurora-build -- ./tools/build-aurora.sh all
```

Вместо `all` можно указать `aarch64` или `armv7hl`. Дополнительные параметры
передаются в `flutter build`, например:

```bash
runuser -u aurora-build -- ./tools/build-aurora.sh aarch64 \
  --dart-define=API_BASE_URL=https://example.org
```

Результаты: `dist/aurora/*.rpm`, контрольные суммы `dist/aurora/SHA256SUMS`
и логи в `dist/aurora/logs/`. Скрипт проверяет Dart-код и каждый RPM через
`rpm-validator --profile regular`, завершаясь с ошибкой при неуспешной проверке.
Зависимости закреплены отдельно в `aurora_pubspec.lock`.

Если исходники редактируются в `/root/aurora-server`, сначала перенесите
изменённые файлы в рабочую копию и передайте их владельцу `aurora-build`.
Обе SDK и проект должны находиться по путям, доступным внутри PSDK chroot;
домашний каталог владельца SDK подходит для этого.

## Настройка другого Linux-компьютера

1. Установить [Flutter для Aurora](https://developer.auroraos.ru/doc/extended/flutter/flutter_development/install)
   версии 3.41.4 и [Platform SDK](https://developer.auroraos.ru/doc/sdk/psdk/setup)
   версии 5.2.1.200.
2. Создать цели `AuroraOS-5.2.1.200-aarch64` и `AuroraOS-5.2.1.200-armv7hl`.
3. Настроить запуск `sdk-chroot` через sudo для пользователя SDK и выполнить
   `flutter config --aurora-psdk-dir /path/to/AuroraPlatformSDK/sdks/aurora_psdk`.
4. Передать пути скрипту:

```bash
export FLUTTER_AURORA_BIN=/path/to/flutter_aurora_linux/bin/flutter
export AURORA_PSDK_DIR=/path/to/AuroraPlatformSDK/sdks/aurora_psdk
./tools/build-aurora.sh all
```

Platform SDK создаёт копии целей `.default`; для SDK, двух архитектур,
промежуточных файлов требуется несколько гигабайт свободного
места. Перед `flutter clean` сохраните RPM вне `build/` — скрипт сохраняет их
в `dist/aurora/`.

## Особенности порта

- Формулы рисуются локально через `flutter_math_fork`, без WebView/CEF и CDN.
  Это устраняет падение после онбординга на эмуляторе без HW compositing.
- Завершение онбординга сохраняется и учитывается при следующем запуске.
- `image_picker` закреплён с учётом Aurora upstream-version mapping.
- Патчи сторонних библиотек и их происхождение описаны в
  `third_party/*/AURORA_PATCH.md`. Math поддерживает расширенный TargetPlatform;
  window manager закреплён на 1.8.0 для встроенного оконного канала
  Flutter 3.41.4 и обрабатывает пустые цвета темы, камера — отсутствие
  устройства и ошибки. Android использует штатные плагины.
- Скрипт временно копирует `tools/aurora-pubspec-overrides.yaml` в
  `pubspec_overrides.yaml`, затем удаляет его. Не создавайте параллельные сборки
  в одной копии проекта. При обновлении Aurora lockfile сначала установите этот
  override, выполните Aurora `flutter pub get`, затем удалите временный файл.
- Иконки Nord Scan в четырёх размерах находятся в `aurora/icons`; файл 266×266
  для стора — `assets/branding/nord-scan-store-266.png`.
- Native main/CMake/spec/desktop закреплены в Git; перегенерация отключена.
- Изменения иконки и имени касаются только Aurora. Android APK не пересобирался.

## Проверки и распространение

Проверяются release-сборки обеих архитектур и профиль `regular` официального
валидатора Aurora. Общий `rpmlint`, запускаемый упаковщиком, сообщает о
поставляемых Flutter-библиотеках; он не заменяет профильный валидатор.
Информационные замечания анализатора об устаревших API цвета не блокируют сборку.
Flutter-тесты покрывают онбординг, ошибки выбора фото, рисование, отрисовку
и копирование формул. Запуск: `flutter test` обычным upstream SDK.
Отдельные тесты оконного плагина: `cd tools/compat_tests && flutter test`. Результаты запуска в эмуляторе и ограничения приведены в `SMOKE.md`.
Физическое устройство и Android APK отдельно не проверены.

RPM создаются **без публикационной подписи**. Для распространения нужна
[подпись источника](https://developer.auroraos.ru/doc/extended/flutter/flutter_development).
Идентификатор пока унаследован от шаблона — `com.example.aurora`; перед
публикацией задайте свою `organization` в `pubspec.yaml` и согласуйте имена
desktop/spec с новым идентификатором. В отсутствие поля `license` SDK
использует значение `Proprietary`.

Для распознавания должен быть доступен API, указанный в `API_BASE_URL`.
Отрисовка формул работает офлайн. Сервер и замеры описаны в `server/README.md`.
