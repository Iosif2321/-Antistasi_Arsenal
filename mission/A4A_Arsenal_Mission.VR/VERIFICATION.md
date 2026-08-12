# Журнал проверки mission-only перехода

Дата среза: 2026-08-12. В этом документе `PASS` относится только к явно
названному доказательству. Статический анализ, CfgConvert и просмотр PBO не
считаются доказательством выполнения SQF внутри Arma 3. Непроведённые проверки
остаются `NOT_RUN`.

## Автоматические проверки

Команды запущены из корня репозитория на ветке `mission-only-arsenal`.

| Проверка | Результат | Что подтверждено |
|---|---|---|
| `tests/verify_mission_only_layout.ps1` | `PASS: 199` | Единственная миссионная поставка, относительные пути, mode-1 RPC, коррелированные сессии, транзакции, порог разблокировки, SP-safe object key, грузовой путь, полная таблица mission-local строк, отсутствие addon/Garage/Vehicle Arsenal/PBO и встроенные UTF-8/CR/лексические проверки |
| `tests/verify_mission_dependency_compatibility.ps1` | `PASS: 23` | Необязательные CBA/ACE-адаптеры и точные локальные сигнатуры |
| `tests/verify_arsenal_permissions.ps1` | `PASS` | Сохранены проверки редакторских полномочий в историческом сравнительном дереве |
| `tests/verify_arsenal_regressions.ps1` | `PASS` | Сохранены регрессии классификации, физического груза и источника CBA-настроек |
| `tests/verify_arsenal_integrity.ps1` | `PASS: 87` | Статические security/integrity-инварианты исторического сравнительного дерева |
| `CfgConvert -test description.ext` | `PASS` (exit `0`) | Конфигурация сценария разобрана официальным конфигурационным инструментом Arma 3 Tools |
| `CfgConvert -test mission.sqm` | `PASS` (exit `0`) | Эталонная VR-миссия разобрана CfgConvert |
| PowerShell parser для двух mission-тестов | `PASS` | Оба новых тестовых сценария разобраны без синтаксических ошибок |
| XML parser для `Stringtable.xml` | `PASS` | Таблица строк является корректным XML; все 10 перенесённых scarcity/ammo ключей определены |
| Строгий UTF-8, NUL/replacement, bare CR/CRCRLF, строки/комментарии и баланс `()[]{}` | `PASS` | Все 79 текстовых файлов и SQF внутри mission artifact прошли встроенный scanner |
| Сопоставление `remoteExec`/`remoteExecCall` с literal whitelist | `PASS` | В исходном коде нет динамического имени RPC; каждый вызов объявлен в `CfgRemoteExec.hpp` |
| Запрещённые addon/Garage/PBO/CBA/ACE-паттерны | `PASS` | В исполняемом коде mission artifact нет старых Garage/vehicle-Arsenal и прямых канонических mutation-endpoint, addon-absolute path, prefix marker, unrestricted RPC mode, недокументированного CBA getter или постоянной ACE-box инициализации |
| PBO и `$PBOPREFIX$` в папке сценария | `PASS: отсутствуют` | Поставка остаётся читаемой распакованной папкой |
| `git diff --check master` | `PASS` (exit `0`) | Нет whitespace-ошибок; сообщения `LF will be replaced by CRLF` являются предупреждением локальной Git-конфигурации, не ошибкой diff |

## Хеши ключевых файлов

SHA-256 на момент статической проверки:

| Файл | SHA-256 |
|---|---|
| `description.ext` | `38F1D4D23025AF9ECAB5296827ED79B7A178EE94035BA3282B3BA8AF9E7FBFCC` |
| `mission.sqm` | `91C44835B20D3A92B90EE69DE077D4E6DE9DAF0181D872945C378F08A772B414` |
| `A4A/CfgFunctions.hpp` | `97D75CB14D6029A6DFB3DA5305E0EEA1677025F4672206B6C0189D09382E10E5` |
| `A4A/CfgRemoteExec.hpp` | `2190FE7840380736293C052CBA3D50D70BD1D104B7933FB17CBA0C3BEA2C079A` |
| `tests/verify_mission_only_layout.ps1` | `FAACB801C682FDDA9E61836B8CB341657F5FCF7BD10E7A16E29CAB492CDB3338` |
| `tests/verify_mission_dependency_compatibility.ps1` | `A8312E94792EE68DF5E855613EF269AE7C326B49675A15EFC4CCF334715B6031` |

## Проверка актуальности внешних API

Официальные теги сверены 2026-08-12. Последние стабильные semver-релизы:

- CBA_A3 `v3.19.0`, commit
  `1fb8cbcb1c81d6af09435f3cfa6d5989d1a2f5ac` — `PASS`;
- ACE3 `v3.21.1`, commit
  `3c20631a573b6aff8b0e26676c81d8f55384e7b8` — `PASS`.

Локальные Workshop-архивы использовались только для чтения фактических SQF API:

| Компонент | Локальное доказательство | Результат |
|---|---|---|
| CBA_A3 3.19.0 `CBA_fnc_addSetting` | `cba_settings.pbo`, 479078 байт, SHA-256 `5F09865E3616EC8795B13544A7EA1075C3FF495F632F3F27C1669D04A4EDD1D3` | Восьмиаргументная сигнатура и результирующая глобальная переменная подтверждены |
| Отсутствие `CBA_fnc_getSetting` | весь mission artifact | `PASS` |
| ACE3 3.21.1 Arsenal API | `ace_arsenal.pbo`, 1104219 байт, SHA-256 `1983B7DF0F0E0A4EF8B9C99911E31F8AA82CD5C42ADBFFA080CAE94861BF3A59` | `addVirtualItems`, `removeVirtualItems`, `openBox` подтверждены |
| Local ACE proxy | исходный код сценария | Явный `false`, `createVehicleLocal`, раздельные original/proxy, без постоянного ACE box — `PASS` по исходному коду |

PBO CBA/ACE не копировались и не изменялись. Они не являются частью результата.

## Runtime matrix

Следующие строки требуют реального запуска движка и сознательно не объявлены
пройденными:

| Runtime gate | Статус | Критерий |
|---|---|---|
| SP без CBA/ACE | `NOT_RUN` | Legacy открывается; локальный fallback object key стабилен; конечные take/return подтверждаются серверным контекстом SP |
| hosted MP, два игрока | `NOT_RUN` | Хост и удалённый игрок получают независимые nonce/generation; ревизии сходятся |
| dedicated MP, два клиента | `NOT_RUN` | Одновременный запрос последней единицы даёт ровно одну физическую выдачу |
| JIP и reconnect | `NOT_RUN` | Новый клиент получает текущую ревизию; старые nonce/generation отклоняются |
| restart persistence | `NOT_RUN` | Реальный рестарт восстанавливает тот же склад и мигрирует старый ключ без частичного импорта |
| timeout/disconnect rollback | `NOT_RUN` | Резерв конечного запаса возвращается и рассылается при отказе, таймауте и disconnect |
| cargo rollback | `NOT_RUN` | Нехватка вместимости полностью восстанавливает оружие, обвес, оставшиеся патроны и вложенные рюкзаки |
| ящик и пустая техника как cargo holder | `NOT_RUN` | Deposit и отдельно подтверждённый withdraw используют один generic holder-контракт; техника не сохраняется и не создаётся |
| unlock threshold | `NOT_RUN` | При достижении порога конечная позиция становится бесконечной; для магазинов порог умножается на фактическую ёмкость магазина |
| CBA Settings UI 3.19.0 | `NOT_RUN` | Пять настроек отображаются; их defaults совпадают с mission settings; restart-поля применяются на сервере |
| ACE proxy UI 3.21.1 | `NOT_RUN` | Бесконечный склад открывает временный proxy; конечный — Legacy; proxy очищается при close/reject/invalidate |
| mixed clients | `NOT_RUN` | Клиент без ACE остаётся на Legacy рядом с клиентом с ACE, без общей глобальной ACE-привязки |
| mod-heavy performance | `NOT_RUN` | Измерены preload, server frame time, размер snapshot и сетевой трафик |

## Статус упаковки и выпуска

PBO build имеет статус `NOT_APPLICABLE`: по контракту результат должен оставаться
распакованной папкой сценария. Запуск AddonBuilder/MakePbo не является gate и не
проводился.

Статическая миграция завершена, но эксплуатационный выпуск нельзя считать
runtime-подтверждённым, пока как минимум dedicated two-client, restart,
timeout/disconnect и cargo rollback строки остаются `NOT_RUN`. Только реальный
запуск Arma 3 и соответствующий RPT могут изменить их статус.
