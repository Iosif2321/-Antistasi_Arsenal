# Antistasi Arsenal

Languages: English | [Русский](#antistasi-arsenal-русская-версия)

Standalone Arma 3 addon that adds an Antistasi-style persistent arsenal module.
The main supported feature is the arsenal. The garage code is present in the
source tree as an experimental development path and is not treated as a working
feature.

## Contents

- `source/A4A_Arsenal/config.cpp` - addon config, 3DEN modules, function
  registration, remote execution whitelist.
- `source/A4A_Arsenal/functions` - addon bootstrap, module handlers, Zeus and
  editor access checks.
- `source/A4A_Arsenal/JNA` - Jeroen Arsenal based limited arsenal UI and data
  handling.
- `source/A4A_Arsenal/Stringtable.xml` - localized UI strings.
- `build.bat` - local PBO build script.
- `addons/A4A_Arsenal.pbo` - built PBO output when present.

## Requirements

The addon config declares these required addons:

- `A3_Modules_F`
- `A3_UI_F`
- `A3_Structures_F_Heli_Items_Electronics`
- `cba_main`

The build script expects Arma 3 Tools AddonBuilder at:

```text
C:\Program Files (x86)\Steam\steamapps\common\Arma 3 Tools\AddonBuilder\AddonBuilder.exe
```

`build.bat` also checks that Steam is running before it starts AddonBuilder.

## Building

Run:

```bat
build.bat
```

The script builds:

```text
source\A4A_Arsenal -> addons\A4A_Arsenal.pbo
```

If Steam is not running, the script exits before packing.

## Arsenal Module Setup

In 3DEN, use the module:

```text
Antistasi Arsenal
```

It is placed under the category:

```text
Antistasi Arsenal
```

Synchronize the module with the object that should become the arsenal access
point. The module handler initializes each synchronized object and then deletes
the module logic object.

Module attributes:

- `Arsenal ID` - unique ID used for saved arsenal data. Default: `Base`.
- `Unlock Threshold` - item count required for unlimited use. Default: `25`.

The save key uses the arsenal ID:

```text
A4A_ArsenalData_<Arsenal ID>
```

## Player Actions

Initialized arsenal objects add these player-facing actions:

- Open Arsenal - opens the limited arsenal UI.
- Select vehicle to open arsenal for it - opens the vehicle/container inventory
  transfer flow when allowed by settings.
- Export Arsenal Data - editor-only export to clipboard and RPT.
- Import Arsenal Data - editor-only import from clipboard.

The editor UI is available from the arsenal toolbar for authorized editors.
It can adjust item counts, set items to infinite, and save the edited arsenal
data.

## Editor Access

Editor access is controlled through CBA addon settings in the `Antistasi Arsenal`
category.

Use `A4A_Arsenal_EditorSteamIDs` to enter the SteamIDs that can edit arsenal
data. Separate multiple IDs with commas, semicolons, or spaces:

```text
76561198000000000,76561198000000001
```

An empty SteamID list blocks arsenal editing for everyone.

Use `A4A_Arsenal_EditAccessMode` to choose the access rule:

- `SteamID Only` - the player's SteamID must be in `A4A_Arsenal_EditorSteamIDs`.
- `SteamID + Zeus` - the player's SteamID must be in
  `A4A_Arsenal_EditorSteamIDs`, and the player must also pass
  `A4A_fnc_arsenal_isZeus`.

`SteamID + Zeus` is the default access mode.

Authorized editors can use the editor UI, import data, export data manually, and
save edited arsenal data. The server checks editor saves again before writing
the arsenal data.

For legacy mission-side configuration, `A4A_Arsenal_EditorUIDs` is still read
when `A4A_Arsenal_EditorSteamIDs` is empty:

```sqf
missionNamespace setVariable [
    "A4A_Arsenal_EditorUIDs",
    ["76561198000000000", "76561198000000001"],
    true
];
```

## CBA Settings

The addon registers these CBA settings when CBA settings are available:

- `A4A_Arsenal_ContainerAccess`
  - `Everyone`
  - `Arsenal Editors`
  - `Disabled`
- `A4A_Arsenal_EditorSteamIDs`
  - separated SteamID allowlist for arsenal editors
- `A4A_Arsenal_EditAccessMode`
  - `SteamID Only`
  - `SteamID + Zeus`
- `A4A_Arsenal_UnlockThreshold`
  - numeric threshold for unlimited use

If CBA settings are unavailable, the addon uses:

```sqf
A4A_Arsenal_ContainerAccess = 0;
A4A_Arsenal_EditorSteamIDs = "";
A4A_Arsenal_EditAccessMode = 1;
A4A_Arsenal_UnlockThreshold = 25;
```

When `A4A_Arsenal_ContainerAccess` is set to `Arsenal Editors`, the same editor
access check is used.

## Export And Import Format

Export writes a readable report and an importable SQF data block. The importable
block is between:

```text
// === BEGIN DATA ===
...
// === END DATA ===
```

The data format is an SQF array with 27 category arrays. Each category contains
entries:

```sqf
["className", count]
```

`count = -1` means infinite.

To import, copy the exported block and use the import action or `Ctrl+V` inside
the arsenal as an authorized editor.

## Notes

- Arsenal data is stored per arsenal ID.
- Editor saves are checked on the client UI path and again on the server save
  path.
- The garage module and garage scripts are not part of the supported workflow
  described here.

# Antistasi Arsenal: русская версия

[English](#antistasi-arsenal) | Русский

Самостоятельный addon для Arma 3, который добавляет постоянный модуль арсенала
в стиле Antistasi. Основная поддерживаемая функция проекта - арсенал. Код
гаража присутствует в дереве исходников как экспериментальное направление
разработки и не считается рабочей поддерживаемой функцией.

## Содержимое

- `source/A4A_Arsenal/config.cpp` - конфигурация addon, 3DEN-модули,
  регистрация функций и whitelist для remote execution.
- `source/A4A_Arsenal/functions` - запуск addon, обработчики модулей, проверки
  Zeus и доступа к редактированию.
- `source/A4A_Arsenal/JNA` - ограниченный интерфейс арсенала и обработка данных
  на основе Jeroen Arsenal.
- `source/A4A_Arsenal/Stringtable.xml` - локализованные строки интерфейса.
- `build.bat` - локальный скрипт сборки PBO.
- `addons/A4A_Arsenal.pbo` - собранный PBO, если он присутствует.

## Требования

В конфигурации addon указаны эти обязательные addons:

- `A3_Modules_F`
- `A3_UI_F`
- `A3_Structures_F_Heli_Items_Electronics`
- `cba_main`

Скрипт сборки ожидает Arma 3 Tools AddonBuilder по пути:

```text
C:\Program Files (x86)\Steam\steamapps\common\Arma 3 Tools\AddonBuilder\AddonBuilder.exe
```

`build.bat` также проверяет, что Steam запущен, перед запуском AddonBuilder.

## Сборка

Запуск:

```bat
build.bat
```

Скрипт собирает:

```text
source\A4A_Arsenal -> addons\A4A_Arsenal.pbo
```

Если Steam не запущен, скрипт завершится до упаковки.

## Настройка модуля арсенала

В 3DEN используется модуль:

```text
Antistasi Arsenal
```

Он находится в категории:

```text
Antistasi Arsenal
```

Синхронизируйте модуль с объектом, который должен стать точкой доступа к
арсеналу. Обработчик модуля инициализирует каждый синхронизированный объект, а
затем удаляет логический объект модуля.

Атрибуты модуля:

- `Arsenal ID` - уникальный ID для сохранённых данных арсенала. Значение по
  умолчанию: `Base`.
- `Unlock Threshold` - количество предметов, необходимое для неограниченного
  использования. Значение по умолчанию: `25`.

Ключ сохранения использует ID арсенала:

```text
A4A_ArsenalData_<Arsenal ID>
```

## Действия игроков

Инициализированные объекты арсенала добавляют такие действия:

- Open Arsenal - открывает ограниченный интерфейс арсенала.
- Select vehicle to open arsenal for it - открывает перенос инвентаря из
  техники или контейнера, если это разрешено настройками.
- Export Arsenal Data - экспорт данных в буфер обмена и RPT, только для
  редакторов.
- Import Arsenal Data - импорт данных из буфера обмена, только для редакторов.

Интерфейс редактора доступен авторизованным редакторам из панели инструментов
арсенала. В нём можно менять количество предметов, выставлять бесконечные
предметы и сохранять изменённые данные арсенала.

## Доступ к редактированию

Доступ к редактированию управляется через CBA-настройки addon в категории
`Antistasi Arsenal`.

В `A4A_Arsenal_EditorSteamIDs` указываются SteamID игроков, которым разрешено
редактировать данные арсенала. Несколько ID можно разделять запятыми, точками с
запятой или пробелами:

```text
76561198000000000,76561198000000001
```

Пустой список SteamID блокирует редактирование арсенала для всех.

В `A4A_Arsenal_EditAccessMode` выбирается правило доступа:

- `SteamID Only` - SteamID игрока должен быть в
  `A4A_Arsenal_EditorSteamIDs`.
- `SteamID + Zeus` - SteamID игрока должен быть в
  `A4A_Arsenal_EditorSteamIDs`, и игрок также должен пройти проверку
  `A4A_fnc_arsenal_isZeus`.

Режим по умолчанию - `SteamID + Zeus`.

Авторизованные редакторы могут использовать интерфейс редактора, импортировать
данные, вручную экспортировать данные и сохранять изменённые данные арсенала.
Перед записью данных сервер повторно проверяет право на сохранение.

Для совместимости со старой настройкой миссии `A4A_Arsenal_EditorUIDs` всё ещё
читается, если `A4A_Arsenal_EditorSteamIDs` пустой:

```sqf
missionNamespace setVariable [
    "A4A_Arsenal_EditorUIDs",
    ["76561198000000000", "76561198000000001"],
    true
];
```

## CBA-настройки

Addon регистрирует эти CBA-настройки, если CBA settings доступны:

- `A4A_Arsenal_ContainerAccess`
  - `Everyone`
  - `Arsenal Editors`
  - `Disabled`
- `A4A_Arsenal_EditorSteamIDs`
  - список SteamID редакторов арсенала
- `A4A_Arsenal_EditAccessMode`
  - `SteamID Only`
  - `SteamID + Zeus`
- `A4A_Arsenal_UnlockThreshold`
  - числовой порог для неограниченного использования

Если CBA settings недоступны, addon использует:

```sqf
A4A_Arsenal_ContainerAccess = 0;
A4A_Arsenal_EditorSteamIDs = "";
A4A_Arsenal_EditAccessMode = 1;
A4A_Arsenal_UnlockThreshold = 25;
```

Когда `A4A_Arsenal_ContainerAccess` установлен в `Arsenal Editors`, используется
та же проверка доступа, что и для редактора арсенала.

## Формат экспорта и импорта

Экспорт записывает читаемый отчёт и импортируемый SQF-блок данных. Импортируемый
блок находится между:

```text
// === BEGIN DATA ===
...
// === END DATA ===
```

Формат данных - SQF-массив с 27 массивами категорий. Каждая категория содержит
записи:

```sqf
["className", count]
```

`count = -1` означает бесконечное количество.

Для импорта скопируйте экспортированный блок и используйте действие импорта или
`Ctrl+V` внутри арсенала как авторизованный редактор.

## Примечания

- Данные арсенала хранятся отдельно для каждого Arsenal ID.
- Сохранения редактора проверяются на стороне клиентского UI и повторно на
  стороне серверного сохранения.
- Модуль гаража и скрипты гаража не входят в поддерживаемый рабочий процесс,
  описанный здесь.
