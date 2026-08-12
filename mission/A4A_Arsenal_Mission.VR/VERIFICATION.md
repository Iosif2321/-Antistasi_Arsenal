# Журнал проверки mission-only перехода

Дата среза: 2026-08-12. В этом документе `PASS` означает только указанный тип
доказательства. `NOT_RUN` не заменяется выводом из исходного кода.

## Автоматические проверки

| Проверка | Статус | Что доказывает |
|---|---|---|
| `tests/verify_mission_only_layout.ps1` | PASS: 161 | Комплектность, строгий RPC, транзакции, грузовой путь и отсутствие Garage в артефакте |
| `tests/verify_mission_dependency_compatibility.ps1` | PASS: 19 | Необязательные CBA/ACE адаптеры и локальные версии |
| `tests/verify_arsenal_permissions.ps1` | PASS | Связность проверок редактора в исходном сравнительном дереве |
| `tests/verify_arsenal_regressions.ps1` | PASS | Исторические регрессии классификации и груза |
| `tests/verify_arsenal_integrity.ps1` | PASS: 87 | Статические security/integrity инварианты исходного дерева |
| `CfgConvert -test description.ext` | PASS | Парсинг конфигурации миссии |
| `CfgConvert -test mission.sqm` | PASS | Текстовый `mission.sqm` разбирается конфигурационным парсером |
| Строгий UTF-8, CR и лексический SQF scanner | NOT_RUN | Финальный файловый gate |
| `git diff --check` | NOT_RUN | Финальный whitespace gate |

## Проверка внешних API

| Проверка | Статус |
|---|---|
| CBA_A3 3.19.0 `CBA_fnc_addSetting` по извлечённому локальному SQF | PASS |
| Отсутствие `CBA_fnc_getSetting` в миссии | PASS |
| ACE3 3.21.1 `addVirtualItems/removeVirtualItems/openBox` по извлечённому локальному SQF | PASS |
| Явный local=false и отсутствие постоянного ACE box | PASS по исходному коду |

## Runtime matrix

Следующие пункты требуют запуска движка и сознательно не объявлены пройденными:

| Runtime gate | Статус | Критерий |
|---|---|---|
| SP без CBA/ACE | NOT_RUN | Legacy открывается, конечные take/return подтверждаются серверным контекстом |
| hosted MP | NOT_RUN | Хост и удалённый игрок получают независимые коррелированные сессии |
| dedicated, два клиента (two-client) | NOT_RUN | Одновременный запрос последнего предмета даёт ровно одну физическую выдачу |
| JIP и reconnect | NOT_RUN | Новый клиент получает актуальную ревизию; старые nonce/generation отклоняются |
| restart persistence | NOT_RUN | После реального перезапуска профиль восстанавливает тот же склад и ревизию |
| cargo rollback | NOT_RUN | Нехватка вместимости полностью возвращает обвес, патроны и вложенные рюкзаки |
| crate-to-vehicle и vehicle-to-crate | NOT_RUN | Техника работает только как держатель физического груза |
| CBA settings UI 3.19.0 | NOT_RUN | Пять настроек отображаются и restart-поля применяются сервером |
| ACE proxy UI 3.21.1 | NOT_RUN | Бесконечный склад открывает proxy, конечный — Legacy, proxy удаляется при закрытии |
| mixed clients | NOT_RUN | Клиент без ACE остаётся на Legacy рядом с клиентом с ACE |
| mod-heavy performance | NOT_RUN | Измерены время preload, серверный frame time, размер snapshot и сетевой трафик |

Сборка PBO не является gate: результат намеренно остаётся распакованной папкой.
Перед эксплуатационным выпуском обязательны dedicated two-client, restart и
cargo rollback сценарии; статический PASS их не заменяет.
