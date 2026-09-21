# Aurora OS 5.2.1

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
зависимостей CEF и промежуточных файлов требуется несколько гигабайт свободного
места. Перед `flutter clean` сохраните RPM вне `build/` — скрипт сохраняет их
в `dist/aurora/`.

## Особенности порта

- Ограничение Dart — `^3.11.1`, как в официальном Aurora SDK.
- `shared_preferences` и `webview_flutter` используют ограничения upstream
  без суффиксов Aurora. Для `image_picker` используется `^1.1.2`, поскольку
  Aurora-порт `1.2.3+2` объявляет `upstream_version: 1.1.2`.
- Добавлены разрешение Internet, инициализация WebView subprocess и QCA,
  упаковка subprocess и cryptopro checker, пути поиска библиотек.
- `setBackgroundColor` пропускается на Aurora: этот метод не реализован
  установленным WebView-плагином. Фон задаётся HTML/CSS.
- `aurora/main.cpp`, `aurora/CMakeLists.txt` и RPM spec намеренно сохраняются
  в Git; их автоматическая перегенерация отключена удалением служебной первой
  строки шаблона.
- Файлы Android сохранены. Android-сборка этими изменениями не проверялась.

## Проверки и распространение

Проверяются release-сборки обеих архитектур и профиль `regular` официального
валидатора Aurora. Общий `rpmlint`, запускаемый упаковщиком, сообщает о
поставляемых Flutter/CEF-библиотеках; он не заменяет профильный валидатор.
Информационные замечания анализатора об устаревших API цвета не блокируют сборку.
Запуск на физическом устройстве отдельно не проверен. Существующий шаблонный
counter-тест не соответствует интерфейсу приложения; он не используется как
подтверждение работоспособности порта.

RPM создаются **без публикационной подписи**. Для распространения нужна
[подпись источника](https://developer.auroraos.ru/doc/extended/flutter/flutter_development).
Идентификатор пока унаследован от шаблона — `com.example.aurora`; перед
публикацией задайте свою `organization` в `pubspec.yaml` и согласуйте имена
desktop/spec с новым идентификатором. В отсутствие поля `license` SDK
использует значение `Proprietary`.

Для распознавания должен быть доступен API, указанный в `API_BASE_URL`.
Загрузка KaTeX в существующем HTML также требует доступа в Интернет.
