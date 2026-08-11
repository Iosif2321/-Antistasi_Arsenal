# Arma 3 2.22: полный технический разбор изменений для моддинга — от критического к неважному

> Версия документа: 2026-08-11
>
> Обновление игры: Arma 3 2.22
>
> Основной источник: [SPOTREP #00120](https://dev.arma3.com/post/spotrep-00120)
> Справочник команд: [Bohemia Interactive Community Wiki](https://community.bohemia.net/wiki/Main_Page)

## 1. Назначение и границы документа

Это не дословный перевод changelog. Документ объясняет:

- что делает каждая новая или изменённая команда, функция, конфигурационная возможность и система;
- каким было прежнее ограничение;
- что конкретно изменилось в 2.22;
- какие категории модов и миссий затрагиваются;
- где возможен регресс совместимости;
- что следует проверить после обновления.

Документ намеренно не привязан к конкретному моду или репозиторию. Под «влиянием» понимается влияние на любые SQF-миссии, PBO-аддоны, editor extensions, UI-моды, оружейные и транспортные моды, нативные extensions и dedicated server.

Материал отсортирован по практической важности. Сначала перечислены изменения, которые способны сломать существующий мод или требуют обязательного regression-теста; затем универсальные новые возможности; после них — важные только для отдельных типов модов; в конце — эксплуатационные и контентные изменения с низким приоритетом.

### 1.1. Достоверность и расхождения источников

SPOTREP — первичный источник состава релиза. Wiki используется для назначения, синтаксиса, параметров, возвращаемых значений и locality команд. Некоторые страницы Wiki всё ещё содержат предупреждение «доступно только в Development branch до выхода 2.22», хотя 2.22 уже опубликована. Это считается устаревшим текстом страницы, а не доказательством отсутствия команды в Main Branch.

Есть отдельная нестыковка: SPOTREP #00120 относит variadic arguments препроцессора к 2.22, тогда как текущая страница [PreProcessor Commands](https://community.bohemia.net/wiki/PreProcessor_Commands) помечает подраздел Variadic Arguments версией 2.24. Поэтому наличие конкретных variadic-возможностей следует проверять командой-пробой на фактически установленном build, а не только по номеру версии в Wiki.

### 1.2. Обозначения locality

- **Local argument** — объект должен быть локален машине, выполняющей команду.
- **Local effect** — результат виден только на выполняющей машине.
- **Global effect** — движок распространяет результат по сети.
- **Server-side command/event** — относится к отдельному серверному scripting-интерфейсу, а не обязательно к обычному SQF, выполняемому на dedicated server.

## Приоритетная сортировка: от критического к неважному

Это основной маршрут чтения документа. Подробный справочник ниже сохраняет полный контекст, синтаксис и официальные ссылки, а здесь все изменения сгруппированы по необходимости реакции моддера.

### P0 — критическое: проверить до публикации или обновления мода

Эти изменения потенциально меняют поведение уже существующего кода либо маскируют ошибку. Их следует считать обязательной частью regression-теста.

#### 1. `Cannot find base class` стал warning

Движок теперь пытается загрузить класс без отсутствующего родителя. Игра может успешно запуститься, хотя класс потерял унаследованные `model`, `scope`, `simulation`, controls, event handlers или другие обязательные свойства. Это самый опасный compatibility-пункт релиза, потому что фатальная ошибка превращается в поздний скрытый дефект. Подробности: [раздел 6](#6-изменение-обработки-config-errors).

#### 2. Перепакованы все официальные аддоны

Неофициальные ссылки на внутренние пути vanilla PBO, неявные зависимости и ошибки порядка загрузки могут проявиться как missing data. Нужны clean baseline, Steam integrity check и сравнение RPT. Подробности: [раздел 2.3](#23-перепаковка-всех-официальных-аддонов).

#### 3. Изменился результат `throwables` и `currentThrowable`

В массив добавлено количество боеприпасов, а `throwables` умеет возвращать пустые магазины. Любой код с фиксированными индексами или `params` старой длины необходимо проверить. Подробности: [раздел 5.2](#52-throwables-и-currentthrowable).

#### 4. Изменён area-синтаксис `nearEntities`

Формат согласован с `inArea`; одновременно исправлено игнорирование area и ошибочное возвращение всех entities для несуществующего type. Код мог зависеть от прежнего ошибочного поведения. Подробности: [раздел 5.1](#51-nearentities-и-area-format).

#### 5. Исправлена ориентация `getAllPylonsInfo`

Старый результат pylon transform был перевёрнут. Мод, вручную инвертирующий orientation, после 2.22 может получить двойную инверсию. Подробности: [раздел 11](#11-исправления-команд-назначение-и-влияние).

#### 6. Исправлены config-based Event Handlers

`WeaponChanged`, `EpeContactStart`, `EpeContactEnd` и `EpeContact` больше не требуют наличия scripted EH того же типа. Старый workaround может теперь создать двойную обработку. Подробности: [раздел 8](#8-event-handlers-и-multiplayer).

#### 7. Удалена многопоточность `lineIntersects*`

Синтаксис не удалён, но выполнение больше не использует отозванную multithread-реализацию. Raycast-heavy моды могут получить performance regression. Подробности: [раздел 10](#10-производительность-и-сетевой-движок).

#### 8. 32-bit и старые Windows объявлены устаревшими

Launcher убрал запуск 32-bit. Нативные extensions должны иметь рабочую 64-bit сборку и корректную pre-load проверку. Подробности: [разделы 2.1 и 13](#13-native-extensions).

### P1 — очень важное: широкое положительное влияние, обязательный MP-тест

#### 1. `setUnitLoadout` network desync fix

Исправлена рассинхронизация оружия между машинами. Это улучшение, но все loadout, respawn, arsenal и role-системы следует перепроверить с двумя клиентами и JIP. Подробности: [раздел 11](#11-исправления-команд-назначение-и-влияние).

#### 2. `profileNamespace` и HashMap

Исправлена подмена отсутствующих HashMap values на `nil` при сохранении. Persistence-системам нужен тест старых данных, save/reload и schema validation. Подробности: [раздел 7](#7-сохранение-hashmap-и-script-state).

#### 3. Оружейная совместимость

`compatibleItems`, `compatibleMagazines` и `canAdd` стали регистронезависимыми для muzzle/slot; `compatibleMagazines` принимает ammo; исправлены дубли, invalid classes и работа с модами. Добавлена обратная команда `compatibleWeapons`. Подробности: [раздел 4.2](#42-оружие-и-пилоны).

#### 4. Event Handlers, JIP и damage sync

Исправлены projectile в `Dammaged`, duplicate static damage events, JIP разрушенных объектов, `Take` при Rearm, Group EH re-entry и ряд `Ref to nonnetwork object`. Подробности: [раздел 8](#8-event-handlers-и-multiplayer).

#### 5. Netcode и packet loss

Добавлен fast retransmit и заявлены общие улучшения netcode. Это влияет на все MP-моды, но реальный эффект требуется измерять под packet loss и высокой нагрузкой. Подробности: [раздел 10](#10-производительность-и-сетевой-движок).

#### 6. Config introspection и наследование

Новые синтаксисы `configHierarchy`, `configClasses`, `needReload`, корректный Config Viewer, более точные `Updating base class` и `CfgPatches::skipWhenAnyAddonPresent`. Подробности: [разделы 5.6 и 6](#56-config-introspection).

### P2 — важное: универсальные новые возможности для SQF/framework-модов

#### 1. Script Handle Promises и новый `waitUntil`

Promise-result, `continueWith`, ожидание handle, timeout и interval позволяют строить асинхронную композицию без ручных namespace-флагов и бесконечных polling-loop. Подробности и синтаксис: [раздел 4.5](#45-асинхронность-и-управление-выполнением).

#### 2. Variadic arguments препроцессора

Универсальные macros могут принимать переменное число аргументов. Есть расхождение версий между SPOTREP и Wiki, поэтому поддержку нужно проверить на build. Подробности: [раздел 1.1](#11-достоверность-и-расхождения-источников).

#### 3. Интерактивные действия

`shownAction`, `hideActions`, `hiddenActions`, `ActionTargetChanged` и расширенный `BIS_fnc_holdActionAdd` дают контролируемое управление engine actions без постоянного UI polling. Подробности: [раздел 4.3](#43-интерактивные-действия).

#### 4. UI и world-space HUD

Расширены `drawIcon3D`, `getTextureInfo`, `getTextWidth`, `CT_PROGRESS`, UI2Texture и добавлен `DisplayOpened`. Подробности: [раздел 4.6](#46-ui-display-и-3d-drawing).

#### 5. Серверный scripting и администрирование

Новые server-side events, `spawn`, JSON-команды, role control, RCon monitoring, `PublicSettings`, `-mpmissions`, `-keysFolder`, connection-state logging и `idleFPSLimit`. Подробности: [раздел 14](#14-dedicated-server-и-администрирование).

#### 6. 3DEN API

Добавлены условия, события connections, RegEx-поиск, `$mission`, `CreateTextFile`, preview Entity ID; исправлены copy/paste, markers, attributes и vehicle seats. Подробности: [раздел 9](#9-3den-и-editor-extensions).

### P3 — важное только для отдельных типов модов

#### Физика, буксировка и составные машины

`attachChild`, `detachChild`, `childAttached`, `parentAttached` и joint drives создают PhysX-соединения. Возможности значительные, но Wiki предупреждает о проблемном MP-поведении. Подробности: [раздел 4.1](#41-physx-joints-attachchild-и-связанные-команды).

#### Авиация, пилоны и сенсоры

Generic pylons, `pylonAction`, новые pylon config entries, `setTargetSize`, `LaserTargetChanged`, animated sensors, `stallSpeedForced` и новые pod-классы. Подробности: [разделы 3.1, 4.2 и 4.4](#31-новая-техника-и-авиационные-системы).

#### Native extensions

`RVFeature_ArgumentNoEscapeString`, чтение R2T, texture source `extension` и `CfgExtensions` pre-load verification. Подробности: [раздел 13](#13-native-extensions).

#### Радио, VoN и звук

50 дополнительных custom channels, VoN callsign, channel map controls, XAudio 2.9, WASAPI, looped sounds и новые sound controllers. Подробности: [разделы 5.3 и 5.4](#53-звук).

#### Камеры, дисплеи и Render-to-Texture

RenderTargets увеличены с 8 до 10, extension может читать/поставлять texture, улучшены UI2Texture и thermal PP. Подробности: [разделы 12.3 и 13](#123-графика).

#### AI, damage, simulation и крупные sandbox-системы

Новые suppression-параметры гранат, `disableAI "HEARING"`, `aiAmmoUsageFlagsStrict`, `aiAwareIsCautious`, structure EH, `DestructColumn`, vehicle seat order и множество AI/physics fixes. Подробности: [раздел 12](#12-остальные-engine-fixes-по-системам).

### P4 — средний приоритет: эксплуатационные улучшения

- CPU affinity-параметры полезны только после измерений; неверная pinning ухудшает производительность.
- `MPMissionsCache` cleanup управляет только кэшем, а не сохранениями.
- Dedicated Server больше не требует XAudio DLL и не блокирует config-файл.
- Launcher запускает Server/Profiling/Diagnostics и несколько экземпляров игры.
- `maxCustomFileSize` теперь предотвращает отправку слишком большого файла вместо последующего kick.
- Улучшены Server Browser, LAN/Direct Connect, VoN indicator, input device recovery, RPT formatting и editor load speed.

Подробности: [разделы 10, 14 и 15](#15-launcher).

### P5 — низкий приоритет и неважное для большинства системных модов

К этой группе относятся:

- новые варианты MH-80 и их визуальные textures, если мод не работает с авиацией;
- исправления конкретных vanilla showcases и campaigns;
- отдельные звуки, LOD, Fire/View/PhysX Geometry конкретных vanilla assets;
- косметика Zeus, Eden и Launcher;
- экспериментальные AI-переводы интерфейса;
- Community Guides и YouTube links;
- Proton/Mac исправления для Windows-only PBO без extension.

Полный перечень контентных правок сохранён в [разделе 3](#3-data-полный-список-и-техническое-влияние), чтобы низкий приоритет не означал потерю информации.

## 2. Платформа и совместимость релиза

### 2.1. Main Branch, Legacy и ОС

- Main Branch, Windows Dedicated Server и Linux Dedicated Server обновлены до 2.22.
- Для сравнения доступна Legacy-ветка 2.20 с кодом `Arma3Legacy220`. Это лучший способ отделить регресс движка от регресса мода: одинаковый PBO и миссия запускаются на 2.20 и 2.22 с одинаковыми параметрами.
- 32-bit, Windows 7 и Windows 8 объявлены устаревшими. Launcher больше не показывает запуск 32-bit binary, хотя бинарники пока распространяются. Нативный мод должен иметь исправную 64-bit DLL/SO и не рассчитывать на 32-bit fallback.
- Обновление относится и к экспериментальным Mac-портам, но их ограничения не снимаются.

### 2.2. Contact data packs

Contact разделён на:

- полный `-mod=Contact` для одиночной кампании First Contact;
- Contact Platform для sandbox и multiplayer, загружаемый по умолчанию.

Полный `-mod=Contact` не считается полностью multiplayer-совместимым. Серверным сборкам не следует подключать его без конкретной необходимости и отдельного тестирования клиентов. Contact подписан новым A3C-ключом, который можно использовать в политике допустимых клиентских данных.

### 2.3. Перепаковка всех официальных аддонов

Все базовые аддоны перепакованы новым pipeline. Bohemia ожидает отсутствие функциональных изменений, но это широкое изменение физического состава данных. Возможные симптомы регресса:

- `Cannot open object` и `Cannot load texture`;
- отсутствующий config parent после изменения порядка загрузки;
- неверные относительные пути к модели, материалу, текстуре или звуку;
- отличия signature verification;
- мод, который неофициально ссылался на внутренний путь внутри vanilla PBO, перестаёт находить ресурс.

После обновления нужны проверка целостности Steam, чистый запуск без модов, затем запуск каждого мод-набора с анализом RPT.

## 3. DATA: полный список и техническое влияние

### 3.1. Новая техника и авиационные системы

1. **MH-80 Assault Ghost Hawk.** Новый базовый контентный класс. Влияет на моды, перечисляющие классы техники вручную, системы распознавания семейства H-80, Zeus-фильтры, логистику и баланс стоимости.
2. **MH-80 DAP Ghost Hawk.** Вооружённый вариант Direct Action Penetrator. Важен для систем пилонов, dynamic loadout, vehicle role classification и threat evaluation AI.
3. **ECM Pod в laser/decoy-вариантах.** Новые пилонные классы радиоэлектронного противодействия. Системы, строящие списки совместимых пилонов, должны обнаруживать их через config, а не только через жёсткий whitelist.
4. **Radar Pod.** Добавляет сенсорное оборудование как пилонный компонент.
5. **Camera Pod.** Добавляет оптический компонент; связан с новой командой [`pylonAction`](https://community.bohemia.net/wiki/pylonAction), которая умеет обращаться к компонентам пилона.
6. **Searchlight Pod с IR и без IR.** Добавляет обычное и инфракрасное освещение на пилоне.
7. **12.7 mm Minigun pylon weapon.** Новый класс пилонного оружия, магазинов и боеприпасов; затрагивает генераторы совместимости и UI loadout.
8. **Black/Dazzle sand/Dazzle tropic варианты контейнеров.** Увеличивают число классов/texture variants; модам не следует считать display name уникальным идентификатором.
9. **Сброс внешних топливных баков H-80.** Состояние пилона и масса/запас топлива могут изменяться во время полёта. Скриптам мониторинга loadout нельзя считать первоначальный список пилонов постоянным.
10. **H-80 Vehicle-in-Vehicle для небольших объектов.** Логистика может использовать ViV; скрипты cargo accounting должны различать inventory cargo и физически загруженные объекты.
11. **Выдвижная штанга дозаправки MH-80.** Пока визуальная. Наличие анимации не означает встроенную передачу топлива.
12. **FFV-места на дверях MH-80 Assault.** Меняются `fullCrew`, seat paths, get-in order и логика стрельбы пассажиров.

### 3.2. Локализация, Editor и действия

1. Добавлены болгарская, венгерская, украинская, словацкая и Latin-локализации. Они экспериментально сгенерированы AI; отдельные строки могут быть неточными.
2. Mobile Radar получил Eden-атрибут вращения антенны.
3. Audio Options получил выбор input device и live playback микрофона.
4. Script Command Utility экспортирует шаблон подсветки SQF для Notepad++.
5. [`BIS_fnc_holdActionAdd`](https://community.bohemia.net/wiki/BIS_fnc_holdActionAdd) получил больше параметров базовой команды [`addAction`](https://community.bohemia.net/wiki/addAction). Hold Action — это длительное действие с состояниями начала, прогресса, завершения и прерывания. Расширение позволяет передать больше настроек нативного action: условия, расстояние, приоритет и UI-поведение. Точные добавленные позиции параметров следует брать из актуальной сигнатуры функции, а не копировать старый массив аргументов.
6. [`BIS_fnc_channelNumToRadioChannelID`](https://community.bohemia.net/wiki/BIS_fnc_channelNumToRadioChannelID) и [`BIS_fnc_radioChannelIDToChannelNum`](https://community.bohemia.net/wiki/BIS_fnc_radioChannelIDToChannelNum) конвертируют номер пользовательского канала и внутренний Radio Channel ID. Это особенно важно после расширения числа custom channels.
7. `SpectrumAnalyzerOpened` и `SpectrumAnalyzerClosed` добавлены в [Scripted Event Handlers](https://community.bohemia.net/wiki/Arma_3:_Scripted_Event_Handlers). Они дают модам момент входа/выхода из Spectrum UI без постоянного polling дисплея.

### 3.3. Оптимизации и изменения базовых данных

1. [`BIS_fnc_returnParents`](https://community.bohemia.net/wiki/BIS_fnc_returnParents) и [`BIS_fnc_returnChildren`](https://community.bohemia.net/wiki/BIS_fnc_returnChildren) оптимизированы. Эти функции обходят config inheritance вверх или вниз. Моды, индексирующие тысячи классов, должны получить меньшие задержки, но формат результата не заявлен изменённым.
2. Chemical Detector, Decon Kit, Antidote Kit и LDF UAV Controller перенесены в `Weapons_F`, чтобы не вызывать ошибочный DLC branding. Моды, ссылавшиеся на физический PBO-путь модели, должны проверить ссылки.
3. Детектор радио теперь проверяет любой предмет в radio inventory slot. Модовое радио может распознаваться по слоту, а не только по ожидаемому class name.
4. PCML damage config изменён так, чтобы AI мог атаковать тяжёлые танки.
5. Save/Load Eden сортируется по времени последнего сохранения.
6. Ускорен Eden Ammo Box Attribute UI.
7. Шрифт script errors поддерживает non-ASCII. Это меняет только отображение диагностики, не кодировку SQF-файлов.

### 3.4. Геометрия, модели и конкретные исправления DATA

Каждый пункт ниже — локальная правка официального контента. Она важна только модам, использующим соответствующий объект или наследующим его конфиг/модель:

- изменена View Geometry нескольких зданий Livonia/Tanoa;
- изменена Collision Geometry Small Church Livonia;
- изменена Fire Geometry Garage Office;
- изменена View Geometry `House_1W03_F`, `House_2W03_F`, `House_2W04_F`, `House_2W05_F`, `IndustrialShed_01_F`, `u_House_Big_01_V1_F`;
- исправлены Physics Layer Geometry больших Barracks и их дверей;
- исправлены `numberOfDoors` у `Land_House_1B01_F`, `Land_House_1W05_F`, `Land_House_1W10_F`;
- исправлено наследование Church;
- исправлены occluders домов Livonia;
- скорректирована walkable surface USS Freedom и устранено расхождение частей при повороте корабля;
- исправлены Fire Geometry, PhysX tail geometry и AFM-анимация колёс Ghost Hawk;
- второй ротор Huron получил отдельное hit selection name;
- HEMTT Ammo получил отсутствовавшую геометрию дымохода в первом Resolution LOD;
- исправлены ground texture LDF Sweater, default texture Portable Flag Pole и серый texture variant SUV;
- исправлены звук двери Greenhouse, Decon Shower, SAM после уничтожения и T-100X Railgun;
- исправлен T-100X VFX config;
- скорректированы длительности музыкальных треков и supply position AL-6;
- Karts helmets правильно помечаются как DLC в Arsenal;
- Chemlight Module показывает все параметры;
- `RscCustomInfoAirborneMiniMap` больше не перезаписывает переменную `RscCustomInfoMiniMap`;
- [`BIS_fnc_initListNBoxSorting`](https://community.bohemia.net/wiki/BIS_fnc_initListNBoxSorting) показывает правильные иконки направления сортировки;
- [`BIS_fnc_gridToPos`](https://community.bohemia.net/wiki/BIS_fnc_gridToPos) снова работает в Eden;
- [`BIS_fnc_kbTellLocal`](https://community.bohemia.net/wiki/BIS_fnc_kbTellLocal) проверяет mission/campaign config;
- [`groupID`](https://community.bohemia.net/wiki/groupID) правильно передаётся Group Callsign Module по сети.

Остальные DATA fixes относятся к официальным сценариям Beyond Hope, Altis Requiem, Old Man, CoF Green, Anomalous Phenomena, Laws of War, First Contact, Escape from Stratis, Firing Drills и Community Guides. Они не меняют публичный моддинг API, но могут быть полезны как сигнал: миссии, копировавшие исправленные vanilla-скрипты, не получают правку автоматически.

## 4. Новые SQF-команды 2.22: подробный справочник

### 4.1. PhysX joints: `attachChild` и связанные команды

#### [`attachChild`](https://community.bohemia.net/wiki/attachChild)

**Назначение.** Физически соединяет parent и child через PhysX joint. В отличие от [`attachTo`](https://community.bohemia.net/wiki/attachTo), связь может иметь ограничения перемещения, поворота, пружины, демпфирование, предел разрыва и drives.

**Основной синтаксис:**

```sqf
[parent, child] attachChild [
    jointType,
    localFrameParent,
    localFrameChild,
    miscFlags,
    jointDescription
];
```

`jointType` поддерживает `"6DOFJoint"`, `"RevoluteJoint"` и `"FixedJoint"`. Локальные frames задают позицию и ориентацию joint в model space обоих объектов. Важная тонкость Wiki: `dirPos` и `upPos` — позиции, а не готовые direction vectors. `miscFlags` содержит как минимум управление столкновением parent/child и break force. `jointDescription` задаёт linear, swing, twist limits и drives.

**Что добавлено в 2.22.** До этого типичный SQF использовал жёсткий `attachTo` либо специализированные tow-механизмы. Теперь движок предоставляет общий PhysX joint.

**Влияние.** Открывает физические прицепы, tow bars, шарниры, подвесы, рампы и составные машины. Официальная Wiki прямо предупреждает, что MP-поведение команды пока неудовлетворительно. Любая multiplayer-система должна тестировать locality, JIP, миграцию owner и разрыв joint.

#### [`detachChild`](https://community.bohemia.net/wiki/detachChild)

Отсоединяет объект, ранее прикреплённый через `attachChild`.

```sqf
detachChild parent;
```

Эффект глобальный при локальном parent. Возвращаемое значение на Wiki указано как `Nothing or Object`, поэтому код не должен пока строить критическую логику на типе результата.

#### [`childAttached`](https://community.bohemia.net/wiki/childAttached) и [`parentAttached`](https://community.bohemia.net/wiki/parentAttached)

Getter-команды для графа PhysX-соединения: первая получает child для parent, вторая parent для child. Они относятся именно к `attachChild`, а не ко всем `attachTo`-связям.

#### Joint drives

- [`setJointDrivePosition`](https://community.bohemia.net/wiki/setJointDrivePosition): `joint setJointDrivePosition position`; задаёт целевую XYZ-позицию linear drive относительно joint.
- [`setJointDriveOrientation`](https://community.bohemia.net/wiki/setJointDriveOrientation): задаёт целевую ориентацию angular drive.
- [`setJointDriveLinearVelocity`](https://community.bohemia.net/wiki/setJointDriveLinearVelocity): задаёт целевую линейную скорость.
- [`setJointDriveAngularVelocity`](https://community.bohemia.net/wiki/setJointDriveAngularVelocity): задаёт целевую угловую скорость.

Drive должен быть заранее описан в `attachChild`. Команды не «телепортируют» child, а задают цель пружинно-демпфированной PhysX-системе с лимитом силы. Они имеют local effect, поэтому network ownership критичен.

### 4.2. Оружие и пилоны

#### [`compatibleWeapons`](https://community.bohemia.net/wiki/compatibleWeapons)

**Назначение.** Выполняет обратный поиск: по attachment, magazine или WeaponSlotsInfo slot возвращает совместимые оружия.

```sqf
private _weapons = compatibleWeapons "bipod_01_F_blk";
// [[weaponClass, "UnderBarrelSlot"], ...]
```

Для magazine возвращается `[weapon, muzzle]`, где primary muzzle обозначается `"this"`. Для attachment/slot возвращается `[weapon, slot]`.

**Что добавлено.** Раньше стандартные команды в основном отвечали на прямой вопрос «что совместимо с этим оружием». Теперь можно построить обратный индекс без полного ручного перебора `CfgWeapons`.

**Влияние.** Ускоряет динамические арсеналы, validation loadout, генераторы лута и compatibility UI. Результат — массив пар, а не плоский список class names.

#### [`removeWeaponItem`](https://community.bohemia.net/wiki/removeWeaponItem)

Удаляет конкретный magazine из конкретного muzzle:

```sqf
unit removeWeaponItem [muzzle, magazineClass];
```

Команда особенно нужна для `Throw` muzzle при `keepInInventory = 0`. Эффект глобальный, аргумент unit должен быть локален. Не следует путать с `removePrimaryWeaponItem`: новая команда адресует muzzle явно.

#### [`pylonAction`](https://community.bohemia.net/wiki/pylonAction)

Универсальный вызов action у пилона или его компонента:

```sqf
pylonAction [vehicle, pylonIndexOrName, actionPath, arguments];
```

Индекс пилона начинается с 1. `-1` адресует `TransportPylonsComponent`. `actionPath` — строковый путь вроде `CameraComponent.0.SetLightState`; поддерживается wildcard `*`. Возвращаемый тип зависит от action. Документированные примеры возможностей:

- включение/чтение света CameraComponent;
- получение индекса последнего стрелявшего пилона;
- вызов `animateSource` на пилоне.

Locality и MP-эффект зависят от конкретного action, поэтому универсального правила remote execution нет.

#### [`compatibleItems`](https://community.bohemia.net/wiki/compatibleItems), [`compatibleMagazines`](https://community.bohemia.net/wiki/compatibleMagazines), [`canAdd`](https://community.bohemia.net/wiki/canAdd)

Это существующие команды, но 2.22 существенно улучшает их:

- muzzle и weapon slot сравниваются без учёта регистра;
- `compatibleMagazines` принимает ammo class и возвращает magazines, содержащие этот ammo;
- устранены дубли при запросе через muzzle;
- исправлена работа `compatibleMagazines` с модами;
- invalid class больше не должен приводить compatibility-команды к crash.

Синтаксисы:

```sqf
compatibleItems weaponClass;
compatibleItems [weaponClass, slotClass];

compatibleMagazines weaponOrAmmoClass;
compatibleMagazines [weaponClass, muzzleClass];

weaponClass canAdd attachmentOrMagazine;
weaponClass canAdd [attachmentClass, slotClass];
weaponClass canAdd [magazineClass, muzzleClass];
```

**Совместимость.** Мод, вручную приводивший все результаты к lowercase, обычно продолжит работать. Риск появляется, если код ожидал дубли в результате, полагался на ошибочный case-sensitive отказ или компенсировал неправильную работу собственным альтернативным списком.

### 4.3. Интерактивные действия

#### [`shownAction`](https://community.bohemia.net/wiki/shownAction)

Возвращает внутренний enum действия, которое сейчас показывается игроку, либо `0`. Например, `91` означает пользовательское действие `addAction`.

```sqf
private _actionEnum = shownAction;
```

Это позволяет UI-моду узнать, какое engine action конкурирует с его собственным интерфейсом.

#### [`hideActions`](https://community.bohemia.net/wiki/hideActions)

Локально скрывает/возвращает действия по enum:

```sqf
hideActions ["HideSelected", [1, 2]];
hideActions ["HideAllButSelected", [91]];
```

Режимы: показать выбранные, скрыть выбранные, показать всё кроме выбранных, скрыть всё кроме выбранных. Состояние относится к текущему focused player и сбрасывается после respawn, поэтому его нужно применять заново.

#### [`hiddenActions`](https://community.bohemia.net/wiki/hiddenActions)

Getter для `hideActions`:

```sqf
private _allHidden = hiddenActions [];
private _subset = hiddenActions [1, 2, 91];
```

#### `ActionTargetChanged` Mission EH

Документирован на странице [Mission Event Handlers](https://community.bohemia.net/wiki/Arma_3:_Mission_Event_Handlers). Сообщает о смене цели контекстного действия. Это event-driven альтернатива постоянному polling cursor target/action UI.

### 4.4. Сенсоры, свет и состояние объекта

#### [`getLightInfo`](https://community.bohemia.net/wiki/getLightInfo)

Получает свойства `#lightpoint` или `#lightreflector`:

```sqf
private _all = getLightInfo _light;
private _intensity = _light getLightInfo 0;
```

Полный массив содержит intensity, diffuse/ambient color, daylight, IR, flare, attenuation, attachment, cone и volume shape. Индексный синтаксис получает только одно свойство. До 2.22 для многих параметров света был setter без симметричного getter.

#### [`setTargetSize`](https://community.bohemia.net/wiki/setTargetSize)

Переопределяет visual/IR/radar target size транспорта:

```sqf
private _previous = vehicle setTargetSize [visualSize, irSize, radarSize];
private _current = vehicle setTargetSize [];
```

Диапазон visual size — 0..2; `-1` снимает override и возвращает config value. Пустой массив работает как getter. Эффект local, хотя аргумент может быть глобальным, поэтому одинаковое sensor-поведение в MP требует согласованного выполнения.

#### [`objectParent`](https://community.bohemia.net/wiki/objectParent)

В 2.22 команда также возвращает владельца LaserTarget. Это позволяет связать лазерную цель с объектом-источником без отдельного реестра.

#### `LaserTargetChanged` Entity EH

Сообщает о смене LaserTarget. Полезен для LST, guided weapons, designator UI и контроля передачи цели.

### 4.5. Асинхронность и управление выполнением

#### [Script Handle Promises](https://community.bohemia.net/wiki/Script_Handle)

До 2.22 Script Handle главным образом идентифицировал `spawn`/`execVM` и проверялся через [`scriptDone`](https://community.bohemia.net/wiki/scriptDone) или завершался через [`terminate`](https://community.bohemia.net/wiki/terminate). В 2.22 handle может представлять promise с результатом.

- Handle обычного `spawn`/`execVM` resolve-ится возвращаемым значением скрипта.
- Пустой handle можно создать через строковый вариант `spawn` и завершить `terminate result`.
- [`continueWith`](https://community.bohemia.net/wiki/continueWith) добавляет continuation, исполняемый после завершения.
- `waitUntil handle` ждёт promise и возвращает result.

```sqf
private _handle = 0 spawn {
    uiSleep 1;
    42
};

_handle continueWith {
    diag_log format ["Result: %1", _this];
};

private _result = waitUntil [_handle, 5];
```

Promise не делает SQF многопоточным: scheduled scripts всё ещё обслуживаются scheduler. Новшество — композиция результата и continuation без ручных namespace-флагов.

#### [`waitUntil`](https://community.bohemia.net/wiki/waitUntil)

Новые синтаксисы 2.22:

```sqf
waitUntil [conditionCode, timeoutSeconds, intervalSeconds];
waitUntil scriptHandle;
waitUntil [scriptHandle, timeoutSeconds];
```

При timeout возвращается `Nothing`. Timeout и interval используют game time semantics, связанные с `sleep`, а не UI time. Обычный `waitUntil { condition }` остаётся. Новый interval заменяет ручной `sleep` внутри condition и делает нагрузку явной.

### 4.6. UI, display и 3D drawing

#### [`drawIcon3D`](https://community.bohemia.net/wiki/drawIcon3D)

Получил расширенный синтаксис, progress bar, отдельный group icon offset, custom arrow texture и `@shadowColor`. Это позволяет одному draw call формировать более богатый world-space HUD. Дополнительно исправлено добавление draw item в очередь при паузе и применение размера `@arrowText`.

Моды должны проверить старые массивы параметров: добавление альтернативного синтаксиса не означает автоматической поломки старого, но wrapper-функции, валидирующие точное число аргументов, могут не принимать новую форму.

#### [`getTextureInfo`](https://community.bohemia.net/wiki/getTextureInfo)

Альтернативный синтаксис возвращает экранную ширину текстуры. Это помогает рассчитывать фактический размер UI/3D-иконки.

#### [`getTextWidth`](https://community.bohemia.net/wiki/getTextWidth)

Может использовать текущий font и size по умолчанию, уменьшая необходимость дублировать параметры контрола.

#### [`typeOf`](https://community.bohemia.net/wiki/typeOf)

Теперь принимает Controls и Displays, позволяя диагностировать класс открытого UI-объекта тем же общим механизмом.

#### `DisplayOpened` Mission EH

Централизованно сообщает об открытии display. Полезен для overlay-модов, accessibility, UI instrumentation и подавления конфликтующих действий.

#### `CT_PROGRESS` и UI2Texture

- `CT_PROGRESS` поддерживает scripted texture.
- [`closeDisplay`](https://community.bohemia.net/wiki/closeDisplay) для UI2Texture немедленно закрывает и выгружает display.
- `submenuXOffset`, `submenuYOffset`, `colorStripBorder` расширяют настройку меню.
- исправлены четыре границы `CT_MENU` и non-ASCII input у `CT_WEBBROWSER`.

### 4.7. Остальные новые команды

- [`combatPace`](https://community.bohemia.net/wiki/combatPace): получает текущий combat pace персонажа.
- [`enableFreeLook`](https://community.bohemia.net/wiki/enableFreeLook): разрешает/запрещает free look.
- [`getAnimationsQueue`](https://community.bohemia.net/wiki/getAnimationsQueue): возвращает очередь анимаций; полезно для state machines и диагностики.
- [`getAimDirectionAndUp`](https://community.bohemia.net/wiki/getAimDirectionAndUp): возвращает aim direction и up vector без ручного восстановления orientation.
- [`enableGunStabilization`](https://community.bohemia.net/wiki/enableGunStabilization): управляет стабилизацией оружия скриптом.
- [`pylonAction`](https://community.bohemia.net/wiki/pylonAction): описана выше.
- [`triggerAmmo`](https://community.bohemia.net/wiki/triggerAmmo): новый синтаксис задаёт trigger time и trigger distance.
- [`hashValue`](https://community.bohemia.net/wiki/hashValue): принимает Script Handle; [`diag_activeSQFScripts`](https://community.bohemia.net/wiki/diag_activeSQFScripts) показывает хэш handle.
- [`getVideoOptions`](https://community.bohemia.net/wiki/getVideoOptions): сообщает о ReShade, DXVK и подобных изменениях renderer; это диагностика, а не античит-доказательство.
- [`shownAction`](https://community.bohemia.net/wiki/shownAction), [`hideActions`](https://community.bohemia.net/wiki/hideActions), [`hiddenActions`](https://community.bohemia.net/wiki/hiddenActions): описаны выше.

## 5. Расширения существующих команд и форматов

### 5.1. `nearEntities` и area format

[`nearEntities`](https://community.bohemia.net/wiki/nearEntities) теперь использует area/marker format, согласованный с [`inArea`](https://community.bohemia.net/wiki/inArea). Также исправлено:

- area не игнорируется при запросе любого entity type;
- несуществующий type возвращает пустой список, а не все entities.

**Риск совместимости.** Старый код мог случайно зависеть от ошибочного «вернуть всё» или передавать нестандартно сформированный area. Такие вызовы нужно тестировать отдельно.

### 5.2. `throwables` и `currentThrowable`

[`throwables`](https://community.bohemia.net/wiki/throwables) получил параметр возврата пустых magazines. Формат результатов [`throwables`](https://community.bohemia.net/wiki/throwables) и [`currentThrowable`](https://community.bohemia.net/wiki/currentThrowable) теперь включает ammo count.

Это потенциально breaking change для кода, который делает `_result params [...]` по старой длине либо обращается к элементам по фиксированным индексам без проверки `count`.

### 5.3. Звук

- [`playSound3D`](https://community.bohemia.net/wiki/playSound3D) и [`playSoundUI`](https://community.bohemia.net/wiki/playSoundUI) получили loop option.
- [`soundParams`](https://community.bohemia.net/wiki/soundParams) возвращает looped state и может вернуть все IDs текущего звука.
- добавлены sound controllers `water`, `damage`, interior и `activeSensors`.
- XAudio обновлён до 2.9; input переведён на Windows Audio Session API; Dedicated Server больше не требует XAudio DLL.

### 5.4. Радиоканалы

- добавлено 50 custom channels к существующим 10;
- custom channel может иметь VoN callsign;
- [`radioChannelInfo`](https://community.bohemia.net/wiki/radioChannelInfo) получил новый синтаксис;
- [`setCurrentChannel`](https://community.bohemia.net/wiki/setCurrentChannel) исправлен для последнего custom channel;
- [`enableChannel`](https://community.bohemia.net/wiki/enableChannel) получил `mapMarkersEnabled` и `mapDrawingEnabled`.

Моды не должны хранить канал в диапазоне 0..9 как универсальное предположение и должны использовать conversion-функции channel number/ID.

### 5.5. Транспорт, места и AI

- [`moveInAny`](https://community.bohemia.net/wiki/moveInAny) позволяет задавать типы мест и порядок поиска, а также учитывать/игнорировать locked seats.
- [`emptyPositions`](https://community.bohemia.net/wiki/emptyPositions) получил согласованный синтаксис.
- исправлены undefined behavior совместного `moveInAny`/[`moveInCargo`](https://community.bohemia.net/wiki/moveInCargo) и соблюдение `getInProxyOrder`.
- [`disableAI`](https://community.bohemia.net/wiki/disableAI) получил `HEARING` и возможность блокировать leader commanding.
- [`setTurretLimits`](https://community.bohemia.net/wiki/setTurretLimits) получил soft-set.
- [`limitSpeed`](https://community.bohemia.net/wiki/limitSpeed) с `false` возвращает default limit.
- [`UAVControl`](https://community.bohemia.net/wiki/UAVControl) получил multiplayer-compatible синтаксис.
- [`animationState`](https://community.bohemia.net/wiki/animationState) и [`getUnitMovesInfo`](https://community.bohemia.net/wiki/getUnitMovesInfo) работают с животными.

### 5.6. Config introspection

- [`configHierarchy`](https://community.bohemia.net/wiki/configHierarchy), [`configClasses`](https://community.bohemia.net/wiki/configClasses), [`needReload`](https://community.bohemia.net/wiki/needReload) получили альтернативные синтаксисы.
- [`getEventHandlerInfo`](https://community.bohemia.net/wiki/getEventHandlerInfo) поддерживает Eden events.
- [`config array +=`](https://community.bohemia.net/wiki/Config.cpp) умеет добавлять array value.
- [`CfgPatches::skipWhenAnyAddonPresent`](https://community.bohemia.net/wiki/CfgPatches) позволяет не активировать patch при наличии одного из заменяющих аддонов.
- config parser разрешает `delete` и повторное объявление одного класса для намеренной смены base class.

## 6. Изменение обработки config errors

### 6.1. `Cannot find base class` больше не останавливает загрузку

Раньше отсутствие base class было config error. В 2.22 это warning, а движок пытается загрузить класс без наследования.

Это повышает живучесть запуска, но создаёт риск скрытого дефекта:

- класс существует, но не содержит унаследованных display names, model, scope, simulation или event handlers;
- следующий patch наследуется уже от неполного класса;
- проблема проявляется не в config parser, а позднее при spawn или открытии UI.

Поэтому отсутствие fatal error нельзя считать доказательством корректного мода. `Cannot find base class` следует трактовать как блокирующую ошибку в CI/RPT-анализе самого мода.

### 6.2. `Updating base class`

- сообщение теперь показывает более точный источник;
- исправлен неправильный original config для класса без members;
- warnings подавляются для forward declaration, кроме режима `-debug`;
- базовые vanilla warnings очищены.

Для глубокого config-аудита мод следует запускать с `-debug`, иначе часть сигналов о порядке загрузки намеренно скрыта.

## 7. Сохранение, HashMap и script state

### 7.1. [`profileNamespace`](https://community.bohemia.net/wiki/profileNamespace)

`profileNamespace` — пространство переменных профиля, физически сохраняемое командой [`saveProfileNamespace`](https://community.bohemia.net/wiki/saveProfileNamespace). Оно переживает перезапуск миссии/игры в рамках соответствующего профиля, но не является общей сетевой базой данных.

В 2.22 исправлен случай, когда несуществующие значения HashMap превращались в `nil` при сохранении HashMap в `profileNamespace`.

**Практический эффект:** сериализованный map должен точнее сохранять различие между отсутствующим key и значением, затронутым прежней ошибкой. Однако сложные persistence-системы всё равно должны иметь schema version, validation и резервный export: фикс движка не заменяет миграцию данных.

### 7.2. HashMapObject

- `compileFinal` сохраняет `NoCopy` flag HashMapObject;
- [`createHashMapObject`](https://community.bohemia.net/wiki/createHashMapObject) принимает string в `#type`;
- unscheduled `#flag` больше не теряет call stack.

### 7.3. Save/load fixes

- Object/Group/Script аргументы Mission EH не становятся null после загрузки save;
- `worldName` не переводится в lowercase;
- underground map Contact загружается с правильным состоянием и позицией;
- сохранение на map screen не даёт серый фон.

## 8. Event Handlers и multiplayer

Новые или исправленные события:

- `OnMissionInit`, `OnMarkerCreated`, `OnHandleChatMessage` server-side events;
- `OnAutoSelectRole`, `OnPlayerSelectRole` и server-side [`getRoles`](https://community.bohemia.net/wiki/getRoles);
- `LaserTargetChanged` Entity EH;
- `VoNStateChanged` Entity EH;
- `ScriptSpawned` Mission EH;
- `AmmoExplodedNear` Entity EH;
- `JointAttached`/`JointDetached` EH;
- `ActionTargetChanged` и `DisplayOpened` Mission EH;
- `OnConnectionAdded`/`OnConnectionRemoved` 3DEN EH;
- structure damage/destroy Scripted EH calls;
- `WeaponChanged` срабатывает при Throw muzzle;
- config EH `WeaponChanged`, `EpeContactStart`, `EpeContactEnd`, `EpeContact` не требуют дублирующего scripted EH;
- `Take` EH срабатывает на Rearm;
- [`Dammaged`](https://community.bohemia.net/wiki/Arma_3:_Event_Handlers#Dammaged) получает projectile в MP от другого игрока;
- устранены duplicate damage events у static structures;
- Group EH не падает при re-entrant событии;
- `isEject` в `GetOutMan` согласован с [`moveOut`](https://community.bohemia.net/wiki/moveOut).

Основной риск — не поломка, а двойная обработка в моде, который раньше добавлял workaround scripted EH только для того, чтобы активировать config EH. После 2.22 оба обработчика могут честно срабатывать.

## 9. 3DEN и editor extensions

Добавлено:

- script conditions для custom connections, context menu items и attributes;
- disabled cursor у запрещённой связи;
- стрелочное отображение направления custom connection;
- wildcard/RegEx поиск Create Tree;
- [`typeOf`](https://community.bohemia.net/wiki/typeOf) для Controls/Displays;
- `CreateTextFile` action в папку scenario;
- [`get3DENEntityID`](https://community.bohemia.net/wiki/get3DENEntityID) в preview;
- `$mission` в [`addonFiles`](https://community.bohemia.net/wiki/addonFiles);
- `OnConnectionAdded`/`OnConnectionRemoved`.

Исправлено:

- `OnEditableEntityRemoved` получает Entity ID и срабатывает для units удаляемой group;
- custom connections к markers отображаются и получают marker name;
- object-specific attribute conditions применяются;
- connections сохраняются в copy/paste и compositions;
- [`get3DENConnections`](https://community.bohemia.net/wiki/get3DENConnections) возвращает правильные Group/Waypoint connections;
- размещение units в vehicle учитывает get-in order и locked seats;
- pylon UI сохраняет default weapons и показывает правильных turret owners;
- Config Viewer показывает правильный parents array;
- legacy modules показывают Module Description;
- ускорены Create Tree и Load Mission.

## 10. Производительность и сетевой движок

- Fast retransmit уменьшает задержку повторной передачи при packet loss.
- Заявлена общая оптимизация netcode.
- Car/Tank loading оптимизирован: быстрее Eden load и меньше spawn spikes.
- AI sensor visibility checks оптимизированы.
- MFD radar filtering и Eden Create Tree search стали multithreaded.
- Запуск игры ускорен, включая случай модов, спамящих ошибками.
- `-cpuAffinity` задаёт доступные процессу ядра; `-cpuMainThreadAffinity` отдельно задаёт affinity main thread. Неверная ручная pinning может ухудшить производительность, поэтому параметры требуют измерения, а не применения «на глаз».
- `idleFPSLimit` ограничивает FPS пустого dedicated server.
- Multithreading у [`lineIntersects`](https://community.bohemia.net/wiki/lineIntersects) и [`lineIntersectsSurfaces`](https://community.bohemia.net/wiki/lineIntersectsSurfaces) удалён из-за crashes. Синтаксис остаётся, но моды с тысячами raycasts могут увидеть performance regression.

## 11. Исправления команд: назначение и влияние

Каждая строка ниже содержит ссылку на отдельную Wiki-страницу команды, если она существует.

- [`setUnitLoadout`](https://community.bohemia.net/wiki/setUnitLoadout): устанавливает полный loadout unit; исправлен network weapon desync. Loadout/respawn/arsenal-системам нужен MP-тест с наблюдателем и JIP.
- [`fullCrew`](https://community.bohemia.net/wiki/fullCrew): возвращает экипаж и места; static weapon больше не имеет ложного пустого driver position.
- [`allDiaryRecords`](https://community.bohemia.net/wiki/allDiaryRecords) и [`allDiarySubjects`](https://community.bohemia.net/wiki/allDiarySubjects): получение записей/тем дневника больше не блокирует визуальное обновление после изменения.
- [`createSoundSource`](https://community.bohemia.net/wiki/createSoundSource): источник звука учитывает скорость звука.
- [`nearSupplies`](https://community.bohemia.net/wiki/nearSupplies): исправлен альтернативный синтаксис.
- [`calculatePath`](https://community.bohemia.net/wiki/calculatePath): строит путь AI; работает при начальной позиции далеко за terrain bounds.
- [`setMarkerShadow`](https://community.bohemia.net/wiki/setMarkerShadow): shadow marker синхронизируется в MP.
- [`selectLeader`](https://community.bohemia.net/wiki/selectLeader): при выборе unit другой group выполняется неявный join вместо потенциального crash.
- [`lockCameraTo`](https://community.bohemia.net/wiki/lockCameraTo): temporary lock не застревает за turret limits.
- [`selectionPosition`](https://community.bohemia.net/wiki/selectionPosition): не падает до загрузки Shape Geometry.
- [`create3DENEntity`](https://community.bohemia.net/wiki/create3DENEntity): не падает при создании animal.
- [`setVehicleAmmoDef`](https://community.bohemia.net/wiki/setVehicleAmmoDef): устранён возможный crash.
- [`attachTo`](https://community.bohemia.net/wiki/attachTo): `followBoneRotation` применяет hand IK и head mimic.
- [`curatorEditableObjects`](https://community.bohemia.net/wiki/curatorEditableObjects): не копит неудаляемые null objects.
- [`getAllPylonsInfo`](https://community.bohemia.net/wiki/getAllPylonsInfo): исправлена перевёрнутая orientation transform. Старую ручную инверсию следует удалить после проверки.
- [`currentZeroing`](https://community.bohemia.net/wiki/currentZeroing): правильный результат в FFV и устранён crash.
- [`drawLaser`](https://community.bohemia.net/wiki/drawLaser): лазер виден при активном PiP.
- [`setVariable`](https://community.bohemia.net/wiki/setVariable): targeted syntax в singleplayer работает ожидаемо.
- [`forceUnicode`](https://community.bohemia.net/wiki/forceUnicode): влияет на string comparison `==`/`!=`.
- [`currentVisionMode`](https://community.bohemia.net/wiki/currentVisionMode): правильно возвращает thermal mode локального player.
- [`forceSpeed`](https://community.bohemia.net/wiki/forceSpeed): VTOL после `forceSpeed 0` останавливается и зависает.
- [`setDamage`](https://community.bohemia.net/wiki/setDamage): можно определять locality scripted damage у static structures; duplicate events исправлены.
- [`setMarkerShadow`](https://community.bohemia.net/wiki/setMarkerShadow): исправлена network sync.
- [`compatibleMagazines`](https://community.bohemia.net/wiki/compatibleMagazines): исправлены моды, invalid classes и дубли muzzle.
- [`setCurrentChannel`](https://community.bohemia.net/wiki/setCurrentChannel): работает с последним из расширенного набора custom channels.
- [`get3DENConnections`](https://community.bohemia.net/wiki/get3DENConnections): правильный синтаксис Group/Waypoint.

## 12. Остальные engine fixes по системам

### 12.1. AI и движение

- AI не прекращает бой после выхода из remote control;
- amphibious tanks лучше управляются в воде;
- AI предупреждает о вражеской гранате и гранаты участвуют в suppression;
- `suppressionRadiusGrenadeClose` и `dangerRadiusGrenadeClose` задают ближние радиусы;
- `aiAmmoUsageFlagsStrict` заставляет строго соблюдать ammo usage flags;
- `aiAwareIsCautious = 0` меняет осторожное поведение tanks;
- CYCLE waypoint и CommandChanged больше не вызывают описанные crashes;
- VTOL/autopilot/helipad исправлены;
- UAV снова доступен после respawn;
- увеличенные units и смещающие origin анимации корректнее проходят collision test.

### 12.2. Повреждения и физика

- JIP получает разрушенные powerlines/communication towers;
- streetlights не оставляют floating lights при disabled simulation;
- wire mines обновляют trigger position после перемещения;
- PhysX object, проваливающийся под terrain, возвращается наверх и переводится в sleep;
- `collisionSoundOverride` и `collisionDamageCoef` добавлены building types;
- новый `DestructColumn` расширяет типы разрушения;
- ShipX/Speedboat/SDV gun stabilization исправлена.

### 12.3. Графика

- RenderTargets увеличены с 8 до 10;
- ARGB8888 PAA поддерживается;
- scripted PP виден в thermal imaging;
- SuperExt emissive использует alpha multiplier;
- Refract `Special1` отключает aberration и time-based normal UV;
- `visualTargetSize` config снова реально влияет на sensor detection;
- `beamThickness` IR laser применяется;
- `activeSensorsPhase` прекращается после destruction.

### 12.4. Server Browser, VoN и служебный UI

- LAN/Direct Connect не ограничен 16 результатами;
- Direct Connect и повторные refresh не ломают списки;
- исправлены potential browser/currentZeroing crashes;
- disabled chat channels сбрасываются между серверами;
- VoN indicator не конфликтует с другими speakers;
- input device восстанавливается без restart;
- PrintScreen не замораживает игру;
- dead body inventory показывает оба dropped weapons и не дёргает оружие;
- ampersand не ломает item tooltip;
- последние элементы Eden ammo box имеют Add/Remove.

## 13. Native extensions

### 13.1. `RVFeature_ArgumentNoEscapeString`

Новый [Extension Feature Flag](https://community.bohemia.net/wiki/Extensions#Feature_Flags) сообщает движку, что extension поддерживает передачу строк без старого дополнительного escaping. Это снижает расходы на преобразование и уменьшает риск двойного unescape. Extension должен объявлять flag только после реализации соответствующего контракта.

### 13.2. `RVExtensionGGetR2TTexture`

Extension может читать Render-to-Texture. Возможные применения: computer vision, внешнее кодирование видеопотока, аналитика изображения и специальные дисплеи. Это потенциально дорогая операция; частоту и размер копирования нужно профилировать.

### 13.3. Texture source `extension`

Нативное расширение может выступать источником динамической текстуры. Это обратное направление относительно чтения R2T: extension поставляет изображение движку.

### 13.4. `CfgExtensions` pre-load verification EH

[CfgExtensions](https://community.bohemia.net/wiki/CfgExtensions) получает проверку перед загрузкой. Мод может заранее выявить отсутствующую/неподходящую DLL, архитектуру или policy-проблему вместо позднего неясного отказа.

Launcher теперь отмечает моды, содержащие extensions.

## 14. Dedicated Server и администрирование

- `getServerInfo` передаёт `PublicSettings` из [server.cfg](https://community.bohemia.net/wiki/server.cfg). Публиковать там следует только не секретные настройки.
- Server-side scripting получил `spawn`, `toJSON`, `fromJSON`, `supportInfo`, role events и `getRoles`.
- `logPlayerConnectionStates` логирует progress подключения.
- `timeStampFormatConsole` меняет формат timestamp.
- `-mpmissions=` задаёт MP mission source.
- BattlEye RCon `#mpmissions` перечисляет доступные миссии.
- `#monitords` можно отдельно отправлять в RCon; исправлена одновременная печать в консоль/RCon.
- `-keysFolder=` задаёт папку signature keys.
- `MPMissionsCache` автоматически очищается выше 1 ГБ: удаляются старейшие файлы >50 МБ, кроме пяти новых. Это cache, не persistence namespace.
- client не отправляет файл больше `maxCustomFileSize`; это предотвращает kick, но сервер не получит custom face/sound сверх лимита.
- server config больше не заблокирован на редактирование запущенным процессом.
- Dedicated Server больше не требует XAudio DLL.
- warning сообщает Headless Client slot без имени.
- `idleFPSLimit` снижает нагрузку пустого сервера.

## 15. Launcher

- предлагает compatibility data mod для Creator DLC server, если DLC не куплен;
- разрешает редактировать моды при запущенной игре;
- разрешает несколько экземпляров игры — полезно для локального client/server/JIP теста;
- запускает Server, Profiling и Diagnostics executables;
- показывает extension icon;
- исправляет случайное заполнение custom command-line parameters;
- ускоряет profile scan и поддерживает обнаружение Proton 11;
- удаляет UI-запуск 32-bit.

## 16. Проверка совместимости мода с 2.22

### 16.1. Минимальный обязательный тест

1. Запустить чистую 2.22 без модов и сохранить baseline RPT.
2. Подключить только тестируемый мод.
3. Проверить RPT на `Cannot find base class`, `Updating base class`, `Cannot open object`, missing texture/material/sound и signature errors.
4. Запустить dedicated server, два клиента и JIP-клиент.
5. Проверить сохранение/загрузку, respawn, owner migration и reconnect.
6. Прогнать weapon compatibility, `setUnitLoadout`, cargo и vehicle seats.
7. Проверить UI после respawn и повторного открытия display.
8. Для extension проверить только 64-bit, pre-load verification и отказ без DLL.
9. Для performance сравнить frame time 2.20 Legacy и 2.22, особенно при `lineIntersects*`.

### 16.2. Потенциально breaking места

- старый разбор массива `throwables`/`currentThrowable`;
- старый area format `nearEntities`;
- ручная инверсия `getAllPylonsInfo`;
- reliance на case-sensitive compatibility failure;
- workaround scripted EH, дублирующий теперь исправленный config EH;
- игнорирование `Cannot find base class`, ставшего warning;
- PhysX joint в MP без ownership/JIP стратегии;
- предположение о максимуме 10 custom radio channels;
- предположение, что `worldName` всегда lowercase после load;
- performance budget, рассчитанный на удалённый multithread raycast.

## 17. Итоговая градация по приоритетам

Этот краткий итог повторяет порядок основного приоритетного раздела: сначала потенциально несовместимые изменения, затем универсальные возможности, специализированные системы и низкоприоритетный контент.

### 17.1. P0–P1: критическое и очень важное для большинства моддеров

- новый статус `Cannot find base class` и более информативный `Updating base class`;
- перепаковка всех официальных PBO;
- `profileNamespace`/HashMap fix;
- `setUnitLoadout` MP desync fix;
- compatibility-команды оружия;
- новый `nearEntities` area format;
- новый формат `throwables`/`currentThrowable`;
- Event Handler fixes и риск двойных workaround handlers;
- 64-bit/старые ОС deprecation;
- netcode и JIP fixes;
- удаление multithreading у `lineIntersects*`;
- возможность нескольких экземпляров игры для теста.

### 17.2. P2–P3: универсально важное и важное для определённых классов модов

- PhysX joints — towing/compound vehicles;
- generic pylons и `pylonAction` — авиация/vehicle loadouts;
- promises и новый `waitUntil` — framework/async systems;
- 3DEN additions — editor extensions/modules;
- `drawIcon3D`, CT_PROGRESS, DisplayOpened, hideActions — UI/HUD;
- target/light/sensor API — radar/stealth/lighting;
- XAudio/WASAPI — VoN/radio/audio;
- R2T и CfgExtensions — native extensions;
- server-side role/JSON/events — server frameworks;
- custom channels — radio mods;
- RenderTargets 8→10 — camera/display mods.

### 17.3. P4–P5: эксплуатационное и неважное для типичного системного мода

- конкретные MH-80 variants и их textures, если мод не работает с авиацией;
- исправления официальных showcases/campaigns;
- отдельные звуки, LOD и геометрия vanilla assets, если мод их не наследует;
- cosmetic Eden/Launcher/Zeus изменения;
- новые AI-переводы интерфейса;
- Community Guides и YouTube links;
- Proton/Mac исправления для Windows-only PBO без extension;
- `MPMissionsCache` cleanup как обычная эксплуатационная функция.

## 18. Ссылки

- [SPOTREP #00120](https://dev.arma3.com/post/spotrep-00120)
- [All Arma Commands Pages](https://community.bohemia.net/wiki/All_Arma_Commands_Pages)
- [Arma 3 Scripting Commands](https://community.bohemia.net/wiki/Category:Arma_3:_Scripting_Commands)
- [PreProcessor Commands](https://community.bohemia.net/wiki/PreProcessor_Commands)
- [Script Handle](https://community.bohemia.net/wiki/Script_Handle)
- [Arma 3 Event Handlers](https://community.bohemia.net/wiki/Arma_3:_Event_Handlers)
- [Arma 3 Mission Event Handlers](https://community.bohemia.net/wiki/Arma_3:_Mission_Event_Handlers)
- [Arma 3 Scripted Event Handlers](https://community.bohemia.net/wiki/Arma_3:_Scripted_Event_Handlers)
- [Arma 3 Vehicle Loadouts](https://community.bohemia.net/wiki/Arma_3:_Vehicle_Loadouts)
- [Extensions](https://community.bohemia.net/wiki/Extensions)
- [server.cfg](https://community.bohemia.net/wiki/server.cfg)
