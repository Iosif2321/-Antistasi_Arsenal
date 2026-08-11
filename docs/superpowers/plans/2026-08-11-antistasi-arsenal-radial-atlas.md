# Antistasi Arsenal Radial System Atlas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a detailed Russian-language, self-contained radial HTML/SVG atlas that explains the current Antistasi Arsenal implementation, including the uncommitted ACE3 Preview branch, without changing runtime behavior or overstating live proof.

**Architecture:** A project-owned UTF-8 JSON file is the sole editable semantic model. The installed `creating-radial-system-atlases` generator owns geometry, camera behavior, accessibility, explanations and the autonomous HTML output; the generated HTML is never hand-edited. Evidence status is kept narrow: source presence is `implemented`, executed automated proof may be `verified`, current ACE integration is `prototype`, and unexecuted Arma 3 scenarios are `not_run`.

**Tech Stack:** JSON schema version 1, Node.js ESM generator and validator, inline HTML/CSS/JavaScript/SVG, PowerShell regression tests, SHA-256 determinism checks, Chromium browser self-test and visual inspection.

---

## Execution constraints

- Execute in the current working tree because the atlas must describe the
  uncommitted ACE3 Preview implementation. A clean worktree from `HEAD` would
  omit required evidence.
- Preserve every existing change under `source/A4A_Arsenal`.
- Create only:
  - `tools/docs/antistasi-arsenal-system-atlas.json`;
  - `docs/assets/antistasi-arsenal-system-atlas-ru.html`.
- Do not modify the generator under
  `C:/Users/Ded/.codex/skills/creating-radial-system-atlases`.
- Do not hand-edit the generated HTML.
- Do not stage or commit implementation artifacts unless the user separately
  authorizes it. This intentionally overrides the generic frequent-commit
  guidance because the explicitly requested atlas skill has a no-commit gate.
- Do not add actual SteamIDs, tokens, hostnames, account identifiers or
  absolute machine paths to the JSON model.
- Treat `.superpowers/brainstorm/` as disposable design-companion state, not an
  atlas source or deliverable.

## File responsibilities

| File | Responsibility |
|---|---|
| `tools/docs/antistasi-arsenal-system-atlas.json` | Authoritative facts, semantic IDs, statuses, sources, plain-language logic and explicit cross-system edges. |
| `docs/assets/antistasi-arsenal-system-atlas-ru.html` | Deterministically generated autonomous viewer with inline SVG/CSS/JS and explanation registry. |
| `docs/superpowers/specs/2026-08-11-antistasi-arsenal-radial-atlas-design.md` | Approved design contract; read-only during execution unless a discovered contradiction requires user review. |
| `tests/verify_arsenal_permissions.ps1` | Existing permission wiring proof; execute without modification. |
| `tests/verify_arsenal_regressions.ps1` | Existing cargo, item type, CBA and hosted-server proof; execute without modification. |

## Canonical semantic inventory

Use these IDs exactly. They are the stable contract between authored edges,
the validator and the generated explanation registry.

### Center and stages

| Type | ID | Title |
|---|---|---|
| center | `arsenal-state` | `ЯДРО ANTISTASI ARSENAL` |
| stage | `receive-operation` | `Принять операцию` |
| stage | `resolve-scope` | `Разрешить область` |
| stage | `authorize-operation` | `Проверить право` |
| stage | `classify-item` | `Классифицировать предмет` |
| stage | `compute-delta` | `Вычислить дельту` |
| stage | `apply-state` | `Применить состояние` |
| stage | `sync-persist` | `Синхронизировать и сохранить` |

### Branch and panel IDs

| Branch | Panels |
|---|---|
| `bootstrap` | `eden-module`, `cba-settings`, `function-registry`, `object-init-jip`, `duplicate-guards` |
| `stock-model` | `data-shape`, `infinite-threshold`, `item-classification`, `stock-helpers`, `special-configs` |
| `server-state` | `keyed-state`, `defensive-copy`, `viewer-sessions`, `persistence`, `hosted-server` |
| `legacy-ui` | `action-open`, `open-data`, `take-return`, `quantity-modifiers`, `close-restore`, `failure-paths` |
| `ace-preview` | `ui-selection`, `virtual-items`, `session-lifecycle`, `cargo-delta`, `equipped-items`, `category-fallback` |
| `containers` | `select-nearby`, `access-policy`, `cargo-extract`, `cargo-transfer`, `transfer-guards`, `vehicle-boundary` |
| `editor` | `editor-access`, `editor-ui`, `import-export`, `editor-save`, `zeus-path` |
| `network` | `remote-whitelist`, `open-close`, `item-updates`, `viewer-fanout`, `init-jip` |
| `verification` | `permission-tests`, `regression-tests`, `ace-live-gate`, `multiplayer-persistence-gate`, `garage-boundary`, `failure-catalog` |

### Explicit edge IDs

| Edge ID | From | To | Type | Status |
|---|---|---|---|---|
| `bootstrap-to-server` | `branch:bootstrap` | `branch:server-state` | `control` | `implemented` |
| `legacy-open-to-network` | `panel:legacy-ui:action-open` | `panel:network:open-close` | `control` | `implemented` |
| `network-to-server` | `branch:network` | `branch:server-state` | `control` | `implemented` |
| `stock-to-server` | `branch:stock-model` | `branch:server-state` | `data` | `implemented` |
| `server-to-legacy` | `branch:server-state` | `branch:legacy-ui` | `data` | `implemented` |
| `server-to-ace` | `branch:server-state` | `branch:ace-preview` | `data` | `prototype` |
| `ace-to-stock` | `branch:ace-preview` | `branch:stock-model` | `data` | `prototype` |
| `containers-to-stock` | `branch:containers` | `branch:stock-model` | `data` | `implemented` |
| `editor-identity-to-save` | `panel:editor:editor-access` | `panel:editor:editor-save` | `identity` | `implemented` |
| `editor-save-to-server` | `panel:editor:editor-save` | `branch:server-state` | `control` | `implemented` |

## Task 1: Capture baseline evidence and create the intentionally incomplete model

**Files:**

- Create: `tools/docs/antistasi-arsenal-system-atlas.json`
- Read: `docs/superpowers/specs/2026-08-11-antistasi-arsenal-radial-atlas-design.md`
- Read: `README.md`
- Read: `source/A4A_Arsenal/config.cpp`
- Read: `source/A4A_Arsenal/CfgFunctions.hpp`
- Read: `source/A4A_Arsenal/functions/*.sqf`
- Read: `source/A4A_Arsenal/JNA/*.sqf`
- Read: `tests/verify_arsenal_permissions.ps1`
- Read: `tests/verify_arsenal_regressions.ps1`

- [ ] **Step 1: Reconfirm the dirty baseline before authoring**

Run:

```powershell
git status --short
git diff --stat
git diff -- source/A4A_Arsenal/CfgFunctions.hpp source/A4A_Arsenal/config.cpp source/A4A_Arsenal/functions/fn_A4A_stub.sqf source/A4A_Arsenal/JNA/fn_arsenal.sqf source/A4A_Arsenal/JNA/fn_arsenal_aceStock.sqf
```

Expected: the current ACE3 Preview changes remain present; no atlas JSON or
generated HTML exists yet; no source file is modified by this step.

- [ ] **Step 2: Build a focused source index before writing claims**

Run:

```powershell
rg -n "A4A_Arsenal_ID|A4A_Arsenal_Threshold|jna_dataList_|A4A_ArsenalData_|profileNamespace|playersInArsenal|remoteExec|remoteExecCall|A4A_fnc_arsenal_canEdit|A4A_Arsenal_UIStyle|A4A_aceStock_|ace_arsenal_|cargoToArsenal|SAVE_JNA" source/A4A_Arsenal README.md tests
```

Expected: every planned center/stage/branch claim can be traced to at least one
source or documentation location. If a claim has no evidence, mark it
`unknown` or remove it instead of inferring it.

- [ ] **Step 3: Create the UTF-8 root, metadata, center and seven stages**

Create `tools/docs/antistasi-arsenal-system-atlas.json` with this root shape and
the complete center logic below. Keep `branches` and `edges` empty only for the
red validator step:

```json
{
  "schemaVersion": 1,
  "meta": {
    "title": "ANTISTASI ARSENAL — системный атлас",
    "subtitle": "Авторитетный количественный запас: Legacy JNA и ACE3 Preview",
    "description": "Карта показывает, как один Arsenal ID связывает настройку модуля, серверный запас из 27 категорий, пользовательский интерфейс, контейнерные операции, права редактора, сетевую синхронизацию и персистентность.",
    "language": "ru",
    "evidenceDate": "2026-08-11",
    "generatedFor": "администраторы миссий, разработчики, тестировщики и сопровождающие",
    "canvas": {"width": 170000, "height": 170000},
    "center": {
      "id": "arsenal-state",
      "title": "ЯДРО ANTISTASI ARSENAL",
      "subtitle": "Authoritative Quantitative Stock",
      "summary": "Вычисляет, применяет и сохраняет авторитетное количественное состояние одного арсенала для проверенной операции.",
      "details": [
        "Работает в области одного Arsenal ID и серверного массива из 27 категорий.",
        "Проверяет контекст операции, доступ и доступное количество до изменения состояния.",
        "Передаёт отображение и физическое изменение экипировки адаптеру Legacy JNA или ACE3."
      ],
      "technical": [
        "stateKey = jna_dataList_{arsenalId}",
        "persistKey = A4A_ArsenalData_{arsenalId}",
        "entry = [className, count]; count = -1 means infinite"
      ],
      "sources": [
        "README.md",
        "source/A4A_Arsenal/JNA/fn_arsenal.sqf",
        "source/A4A_Arsenal/functions/fn_arsenalLogic.sqf"
      ],
      "status": "implemented",
      "logic": {
        "preview": "Ядро принимает одну проверенную операцию и превращает её в новое авторитетное состояние конкретного арсенала.",
        "purpose": "Не допустить, чтобы локальный интерфейс, другой Arsenal ID или неподтверждённый редактор произвольно изменили общий количественный запас.",
        "input": "Тип операции, объект и Arsenal ID, текущая серверная копия запаса, политика доступа и подтверждённый контекст клиента.",
        "steps": [
          "Определить область одного арсенала и активного участника.",
          "Проверить право на запрошенную операцию и классифицировать предмет.",
          "Вычислить допустимую количественную дельту с учётом остатка и порога.",
          "Применить дельту к безопасной копии серверного состояния.",
          "Разослать результат нужным клиентам и сохранить состояние."
        ],
        "decision": "Достаточно ли подтверждённого контекста и запаса, чтобы принять операцию для этого Arsenal ID.",
        "output": "Новая авторитетная копия количественного запаса и адресное обновление активных интерфейсов.",
        "next": "Результат получает Legacy JNA или ACE3 Preview, а долговременную копию получает слой персистентности.",
        "failure": "При неизвестном предмете, недостаточном запасе, пустых данных или отсутствии права операция отклоняется либо переводится в явно описанный fallback без переиспользования чужого состояния.",
        "status": "Основное количественное ядро реализовано; живое MP-поведение подтверждается отдельно."
      }
    }
  },
  "stages": [],
  "branches": [],
  "edges": []
}
```

Populate `stages` in the canonical order. Each stage must include `id`, Russian
`title`, `summary`, one to three `details`, one or two `technical` facts,
relative `sources`, an evidence `status`, and plain-language `logic` for the
risky stages `authorize-operation`, `compute-delta` and `apply-state`.

Use these source mappings:

| Stage | Sources | Status |
|---|---|---|
| `receive-operation` | `JNA/fn_arsenal.sqf`, `JNA/fn_arsenal_requestOpen.sqf`, `JNA/fn_arsenal_cargoToArsenal.sqf`, `functions/fn_arsenalLogic.sqf` | `implemented` |
| `resolve-scope` | `JNA/fn_arsenal_init.sqf`, `JNA/fn_arsenal_requestOpen.sqf`, `JNA/fn_arsenal.sqf` | `implemented` |
| `authorize-operation` | `functions/fn_arsenal_canEdit.sqf`, `JNA/fn_arsenal_init.sqf`, `functions/fn_arsenalLogic.sqf` | `implemented` |
| `classify-item` | `JNA/fn_arsenal_itemType.sqf`, `JNA/fn_arsenal_itemCount.sqf` | `implemented` |
| `compute-delta` | `JNA/fn_arsenal_addItem.sqf`, `JNA/fn_arsenal_removeItem.sqf`, `JNA/fn_arsenal_handleAction.sqf`, `JNA/fn_arsenal_aceStock.sqf` | `prototype` because ACE participates |
| `apply-state` | `JNA/fn_arsenal.sqf`, `functions/fn_arsenalLogic.sqf` | `implemented` |
| `sync-persist` | `JNA/fn_arsenal.sqf`, `JNA/fn_arsenal_requestClose.sqf`, `JNA/fn_arsenal_cargoToArsenal.sqf`, `functions/fn_arsenalLogic.sqf` | `implemented` |

- [ ] **Step 4: Run the intended red validation gate**

Run:

```powershell
$atlasSkillDir = 'C:\Users\Ded\.codex\skills\creating-radial-system-atlases'
$atlasInput = (Resolve-Path 'tools/docs/antistasi-arsenal-system-atlas.json').Path
node "$atlasSkillDir/scripts/validate-radial-atlas.mjs" --input "$atlasInput"
```

Expected: FAIL because the schema requires at least three branches. Any JSON
parse, encoding, identifier or privacy error is an unintended failure and must
be fixed before Task 2.

## Task 2: Add bootstrap, stock-model and server-state branches

**Files:**

- Modify: `tools/docs/antistasi-arsenal-system-atlas.json`

- [ ] **Step 1: Add the three branches with exact semantic IDs**

Add `bootstrap`, `stock-model` and `server-state` in that order. Use the
following content contract for each panel:

| Panel | Factual content | Required sources | Status |
|---|---|---|---|
| `bootstrap:eden-module` | 3DEN module attributes, synchronized object and module deletion after initialization | `config.cpp`, `functions/fn_moduleArsenal.sqf` | `implemented` |
| `bootstrap:cba-settings` | container access, editor SteamID text, edit mode, threshold and Legacy/ACE UI selection | `functions/fn_A4A_stub.sqf` | `implemented` |
| `bootstrap:function-registry` | A4A/JN registration, preInit and ACE postInit | `config.cpp`, `CfgFunctions.hpp` | `implemented` |
| `bootstrap:object-init-jip` | published object variables and JIP-safe initialization calls | `functions/fn_arsenalInit.sqf`, `JNA/fn_arsenal_init.sqf` | `implemented` |
| `bootstrap:duplicate-guards` | settings, object and ACE handler one-time guards | `functions/fn_A4A_stub.sqf`, `JNA/fn_arsenal_init.sqf`, `JNA/fn_arsenal_aceStock.sqf` | `implemented` |
| `stock-model:data-shape` | 27 arrays and `[className, count]` entries | `README.md`, `JNA/fn_arsenal_init.sqf`, `JNA/fn_arsenal.sqf` | `implemented` |
| `stock-model:infinite-threshold` | `-1` infinite state and finite-to-unlimited threshold behavior | `README.md`, `functions/fn_arsenalLogic.sqf`, `JNA/fn_arsenal_addItem.sqf` | `implemented` |
| `stock-model:item-classification` | category selection and safe `param` lookup | `JNA/fn_arsenal_itemType.sqf` | `implemented` initially; promote narrow checked claim after tests |
| `stock-model:stock-helpers` | count/list/add/remove array helpers | `JNA/fn_arsenal_itemCount.sqf`, `JNA/fn_arsenal_inList.sqf`, `JNA/fn_arsenal_addToArray.sqf`, `JNA/fn_arsenal_removeFromArray.sqf` | `implemented` |
| `stock-model:special-configs` | magazine preference, placeable explosives and radio category handling | `JNA/fn_arsenal_itemType.sqf`, `JNA/fn_arsenal_aceStock.sqf` | `prototype` |
| `server-state:keyed-state` | server variable and profile key scoped by Arsenal ID | `JNA/fn_arsenal_init.sqf`, `JNA/fn_arsenal.sqf` | `implemented` |
| `server-state:defensive-copy` | copy before server mutation to avoid alias pre-application | `JNA/fn_arsenal.sqf`, `JNA/fn_arsenal_addItem.sqf`, `JNA/fn_arsenal_removeItem.sqf` | `implemented` |
| `server-state:viewer-sessions` | open/close tracking per Arsenal ID | `JNA/fn_arsenal_requestOpen.sqf`, `JNA/fn_arsenal_requestClose.sqf` | `implemented` |
| `server-state:persistence` | profile load, mutation persistence and save boundary | `JNA/fn_arsenal_init.sqf`, `JNA/fn_arsenal.sqf`, `functions/fn_arsenalLogic.sqf` | `implemented` |
| `server-state:hosted-server` | local-copy and non-pre-application safeguards | `JNA/fn_arsenal_requestOpen.sqf`, `JNA/fn_arsenal_addItem.sqf`, `JNA/fn_arsenal_removeItem.sqf`, `tests/verify_arsenal_regressions.ps1` | `implemented` until test runs |

Every panel must contain a concise `summary`, two or three behavioral
`details`, one or two `technical` facts and only relative source paths. Supply
full `logic` for `infinite-threshold`, `defensive-copy`, `persistence` and
`hosted-server`; their failure descriptions must say what happens when state is
missing, aliased or scoped to the wrong Arsenal ID.

- [ ] **Step 2: Validate the first complete three-branch model**

Run:

```powershell
$atlasSkillDir = 'C:\Users\Ded\.codex\skills\creating-radial-system-atlases'
$atlasInput = (Resolve-Path 'tools/docs/antistasi-arsenal-system-atlas.json').Path
node "$atlasSkillDir/scripts/validate-radial-atlas.mjs" --input "$atlasInput"
```

Expected: `Validation passed` or the validator's equivalent success line. Fix
the JSON model, not the validator, for duplicate IDs, malformed arrays,
insufficient detail or secret-like content.

## Task 3: Add Legacy JNA, ACE3 Preview and container branches

**Files:**

- Modify: `tools/docs/antistasi-arsenal-system-atlas.json`

- [ ] **Step 1: Add the Legacy JNA branch**

Use the canonical panel IDs and this evidence map:

| Panel | Factual content | Sources | Status |
|---|---|---|---|
| `action-open` | player action, loading state and inventory snapshot | `JNA/fn_arsenal_handleAction.sqf` | `implemented` |
| `open-data` | server request, local/remote response and copied `jna_dataList` | `JNA/fn_arsenal_requestOpen.sqf`, `JNA/fn_arsenal.sqf` | `implemented` |
| `take-return` | stock decrement/increment around physical inventory behavior | `JNA/fn_arsenal.sqf`, `JNA/fn_arsenal_addItem.sqf`, `JNA/fn_arsenal_removeItem.sqf` | `implemented` |
| `quantity-modifiers` | normal, Shift and Ctrl quantities | `JNA/fn_arsenal.sqf`, `JNA/fn_arsenal_handleAction.sqf` | `implemented` |
| `close-restore` | requestClose, TFAR/loadout cleanup and session removal | `JNA/fn_arsenal_init.sqf`, `JNA/fn_arsenal_requestClose.sqf` | `implemented` |
| `failure-paths` | missing data, empty arsenal and loading-screen recovery | `JNA/fn_arsenal.sqf`, `JNA/fn_arsenal_handleAction.sqf` | `implemented` |

Supply full `logic` for `action-open`, `take-return` and `failure-paths`.

- [ ] **Step 2: Add the ACE3 Preview branch with prototype boundaries**

Use status `prototype` for the branch and every panel unless a panel describes
only an already executed static check. Use this evidence map:

| Panel | Factual content | Sources |
|---|---|---|
| `ui-selection` | CBA UI mode, server mode selection and Legacy fallback | `functions/fn_A4A_stub.sqf`, `JNA/fn_arsenal_handleAction.sqf`, `JNA/fn_arsenal_requestOpen.sqf`, `JNA/fn_arsenal.sqf` |
| `virtual-items` | initial mirroring and per-item stock synchronization | `JNA/fn_arsenal_aceStock.sqf` |
| `session-lifecycle` | handler registration, begin session, display open/close and end session | `JNA/fn_arsenal_aceStock.sqf` |
| `cargo-delta` | before snapshot, current inventory count and accepted real delta | `JNA/fn_arsenal_aceStock.sqf` |
| `equipped-items` | previous/current slot comparison and stock updates | `JNA/fn_arsenal_aceStock.sqf` |
| `category-fallback` | hidden unsupported tabs, radio relocation and missing ACE fallback | `JNA/fn_arsenal_aceStock.sqf`, `JNA/fn_arsenal_itemType.sqf`, `JNA/fn_arsenal.sqf` |

Every ACE panel logic status must state that code exists in the current working
tree but the live multiplayer scenario is not proven. `cargo-delta` logic must
explain that ACE mutates inventory before emitting the event, so the bridge
derives the real change from before/after cargo state.

- [ ] **Step 3: Add the containers branch**

Use this evidence map:

| Panel | Factual content | Sources | Status |
|---|---|---|---|
| `select-nearby` | object selection and distance/vehicle conditions | `JNA/fn_arsenal_init.sqf` | `implemented` |
| `access-policy` | everyone/editor/disabled policy | `functions/fn_A4A_stub.sqf`, `JNA/fn_arsenal_init.sqf`, `functions/fn_arsenal_canEdit.sqf` | `implemented` |
| `cargo-extract` | classification of container and player inventory cargo | `JNA/fn_arsenal_cargoToArray.sqf` | `implemented` |
| `cargo-transfer` | server-side additions and viewer updates | `JNA/fn_arsenal_cargoToArsenal.sqf` | `implemented` |
| `transfer-guards` | busy flag and scope resolution | `JNA/fn_arsenal_cargoToArsenal.sqf` | `implemented` |
| `vehicle-boundary` | existing vehicle arsenal code is an experimental boundary, not the supported primary feature | `README.md`, `JNA/fn_vehicleArsenal.sqf` | `prototype` |

Supply full `logic` for `cargo-extract`, `cargo-transfer` and
`vehicle-boundary`. The cargo extraction panel must not claim that
`weaponsItemsCargo` is used for container cargo after the current regression
change.

- [ ] **Step 4: Validate the six-branch model**

Run the input validator again. Expected: PASS with six branches and no endpoint
checks yet because `edges` remains empty.

## Task 4: Add editor, network and verification branches

**Files:**

- Modify: `tools/docs/antistasi-arsenal-system-atlas.json`

- [ ] **Step 1: Add the editor branch**

| Panel | Factual content | Sources | Status |
|---|---|---|---|
| `editor-access` | SteamID allowlist, optional Zeus requirement and empty-list denial | `functions/fn_arsenal_canEdit.sqf` | `implemented` until test runs |
| `editor-ui` | editor open, category switching, count modification and infinite state | `JNA/fn_arsenal.sqf` | `implemented` |
| `import-export` | readable report and importable data-block boundaries | `README.md`, `JNA/fn_arsenal.sqf` | `implemented` |
| `editor-save` | client request plus server-side reauthorization and persistence | `JNA/fn_arsenal.sqf`, `functions/fn_arsenalLogic.sqf` | `implemented` until test runs |
| `zeus-path` | Zeus detection/assignment path without exposing personal IDs | `functions/fn_arsenal_isZeus.sqf`, `functions/fn_assignZeus.sqf`, `functions/fn_inputHandler.sqf` | `implemented` |

Supply full `logic` for `editor-access` and `editor-save`; explicitly say that
the server does not trust client UI authorization by itself.

- [ ] **Step 2: Add the network branch**

| Panel | Factual content | Sources | Status |
|---|---|---|---|
| `remote-whitelist` | function allowlist and allowedTargets | `config.cpp` | `implemented` |
| `open-close` | clientOwner request, local hosted response and remote client response | `JNA/fn_arsenal_requestOpen.sqf`, `JNA/fn_arsenal_requestClose.sqf` | `implemented` |
| `item-updates` | server add/remove mutation commands | `JNA/fn_arsenal.sqf`, `JNA/fn_arsenal_addItem.sqf`, `JNA/fn_arsenal_removeItem.sqf` | `implemented` |
| `viewer-fanout` | updates restricted to viewers of one Arsenal ID | `JNA/fn_arsenal.sqf`, `JNA/fn_arsenal_cargoToArsenal.sqf` | `implemented` |
| `init-jip` | public object state and persistent initialization calls | `functions/fn_moduleArsenal.sqf`, `functions/fn_arsenalInit.sqf`, `JNA/fn_arsenal_init.sqf` | `implemented` |

Supply full `logic` for `remote-whitelist`, `open-close` and `viewer-fanout`.
Do not claim that static `CfgRemoteExec` inspection proves a live dedicated
server route.

- [ ] **Step 3: Add the verification branch**

| Panel | Meaning | Sources | Status before execution |
|---|---|---|---|
| `permission-tests` | exact permission-wiring assertions | `tests/verify_arsenal_permissions.ps1` | `not_run` |
| `regression-tests` | cargo, item type, CBA and hosted-server assertions | `tests/verify_arsenal_regressions.ps1` | `not_run` |
| `ace-live-gate` | two-client ACE interaction, finite/infinite stock, take/return, reconnect and close | current ACE source plus explicit test description | `not_run` |
| `multiplayer-persistence-gate` | hosted and dedicated restart/reopen behavior for separate Arsenal IDs | `README.md` plus explicit test description | `not_run` |
| `garage-boundary` | Garage exists but is not a supported working feature | `README.md`, `source/A4A_Arsenal/Garage` | `prototype` |
| `failure-catalog` | missing data, unavailable ACE, permission denial, empty stock and unsafe scope | relevant source files from other branches | `implemented` |

Full `logic` is mandatory for every verification panel. Each live gate must
name the exact missing in-game scenario rather than saying only “not tested.”

- [ ] **Step 4: Validate the nine-branch model**

Run the input validator. Expected: PASS with exactly nine branches, seven
stages, 49 panels and no edges.

## Task 5: Add explicit edges and verify the semantic model

**Files:**

- Modify: `tools/docs/antistasi-arsenal-system-atlas.json`

- [ ] **Step 1: Add the ten canonical explicit edges**

Use the exact IDs and endpoints from the canonical inventory. Each edge must
include a short Russian `label`, `status` and `logic`. Use this label contract:

```json
[
  {"id":"bootstrap-to-server","from":"branch:bootstrap","to":"branch:server-state","type":"control","label":"инициализированный Arsenal ID","status":"implemented"},
  {"id":"legacy-open-to-network","from":"panel:legacy-ui:action-open","to":"panel:network:open-close","type":"control","label":"запрос открыть или закрыть","status":"implemented"},
  {"id":"network-to-server","from":"branch:network","to":"branch:server-state","type":"control","label":"авторитетная команда изменения","status":"implemented"},
  {"id":"stock-to-server","from":"branch:stock-model","to":"branch:server-state","type":"data","label":"категория, класс и количество","status":"implemented"},
  {"id":"server-to-legacy","from":"branch:server-state","to":"branch:legacy-ui","type":"data","label":"копия текущего запаса","status":"implemented"},
  {"id":"server-to-ace","from":"branch:server-state","to":"branch:ace-preview","type":"data","label":"запас для ACE virtual items","status":"prototype"},
  {"id":"ace-to-stock","from":"branch:ace-preview","to":"branch:stock-model","type":"data","label":"принятая фактическая дельта","status":"prototype"},
  {"id":"containers-to-stock","from":"branch:containers","to":"branch:stock-model","type":"data","label":"классифицированный cargo","status":"implemented"},
  {"id":"editor-identity-to-save","from":"panel:editor:editor-access","to":"panel:editor:editor-save","type":"identity","label":"разрешение редактора","status":"implemented"},
  {"id":"editor-save-to-server","from":"panel:editor:editor-save","to":"branch:server-state","type":"control","label":"проверенное сохранение","status":"implemented"}
]
```

For each edge logic, explain sender, receiver, decision, safe failure and current
evidence boundary. Do not treat source imports as edges.

- [ ] **Step 2: Run the complete source-model validator**

Run:

```powershell
$atlasSkillDir = 'C:\Users\Ded\.codex\skills\creating-radial-system-atlases'
$atlasInput = (Resolve-Path 'tools/docs/antistasi-arsenal-system-atlas.json').Path
node "$atlasSkillDir/scripts/validate-radial-atlas.mjs" --input "$atlasInput"
```

Expected: PASS with valid endpoint references, semantic IDs, supported statuses
and no credential-like values.

- [ ] **Step 3: Run content-specific JSON assertions**

Run:

```powershell
$model = Get-Content -Raw -Encoding UTF8 'tools/docs/antistasi-arsenal-system-atlas.json' | ConvertFrom-Json
if ($model.stages.Count -ne 7) { throw "Expected 7 stages" }
if ($model.branches.Count -ne 9) { throw "Expected 9 branches" }
$panelCount = ($model.branches | ForEach-Object { $_.panels.Count } | Measure-Object -Sum).Sum
if ($panelCount -ne 49) { throw "Expected 49 panels, got $panelCount" }
if ($model.edges.Count -ne 10) { throw "Expected 10 explicit edges" }
if (($model.branches | Where-Object id -eq 'ace-preview').status -ne 'prototype') { throw "ACE branch must remain prototype" }
$liveStatuses = $model.branches | Where-Object id -eq 'verification' | Select-Object -ExpandProperty panels | Where-Object id -in @('ace-live-gate','multiplayer-persistence-gate') | Select-Object -ExpandProperty status
if ($liveStatuses -contains 'verified') { throw "Live gates cannot be verified by source authoring" }
'PASS: semantic inventory and proof boundaries'
```

Expected: `PASS: semantic inventory and proof boundaries`.

## Task 6: Generate and validate the autonomous HTML

**Files:**

- Create: `docs/assets/antistasi-arsenal-system-atlas-ru.html`
- Read only: `tools/docs/antistasi-arsenal-system-atlas.json`

- [ ] **Step 1: Generate the HTML using only the bundled generator**

Run:

```powershell
$atlasSkillDir = 'C:\Users\Ded\.codex\skills\creating-radial-system-atlases'
$atlasInput = (Resolve-Path 'tools/docs/antistasi-arsenal-system-atlas.json').Path
$atlasOutputDir = New-Item -ItemType Directory -Force 'docs/assets'
$atlasOutput = Join-Path $atlasOutputDir.FullName 'antistasi-arsenal-system-atlas-ru.html'
node "$atlasSkillDir/scripts/build-radial-atlas.mjs" --input "$atlasInput" --output "$atlasOutput"
```

Expected: generator success and one new HTML file. Do not open the file in an
editor to make visual adjustments.

- [ ] **Step 2: Validate the generated artifact**

Run:

```powershell
node "$atlasSkillDir/scripts/validate-radial-atlas.mjs" --input "$atlasInput" --html "$atlasOutput"
```

Expected: PASS for one inline SVG, semantic/logic coverage, valid endpoints,
accessible objects, reusable explanations, privacy patterns and absence of
active external resources.

- [ ] **Step 3: Prove deterministic generation**

Run:

```powershell
$hashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $atlasOutput).Hash
node "$atlasSkillDir/scripts/build-radial-atlas.mjs" --input "$atlasInput" --output "$atlasOutput"
$hashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $atlasOutput).Hash
if ($hashBefore -ne $hashAfter) { throw "Deterministic generation failed: $hashBefore != $hashAfter" }
"PASS: deterministic SHA256 $hashAfter"
```

Expected: identical hashes and one `PASS: deterministic SHA256 ...` line.

- [ ] **Step 4: Verify autonomy, privacy and Russian encoding**

Run:

```powershell
$jsonText = Get-Content -Raw -Encoding UTF8 'tools/docs/antistasi-arsenal-system-atlas.json'
$htmlText = Get-Content -Raw -Encoding UTF8 'docs/assets/antistasi-arsenal-system-atlas-ru.html'
if ($jsonText.Contains([char]0xFFFD) -or $htmlText.Contains([char]0xFFFD)) { throw 'Replacement character found' }
if ($jsonText -match 'Р Р°|РЎС‚|РђСЂ') { throw 'JSON mojibake found' }
if ($htmlText -match 'Р Р°|РЎС‚|РђСЂ') { throw 'HTML mojibake found' }
if ($htmlText -match '<script\s+src=|<link\s+[^>]*href=|<iframe|<object|fetch\s*\(|XMLHttpRequest|WebSocket') { throw 'Active external resource or network API found' }
if ($jsonText -match '7656119\d+|C:\\Users\\|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}') { throw 'Private or machine-specific data found in JSON' }
if ($htmlText -match '7656119\d+|C:\\Users\\|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}') { throw 'Private or machine-specific data found in HTML' }
'PASS: UTF-8, autonomy and privacy checks'
```

Expected: `PASS: UTF-8, autonomy and privacy checks`.

## Task 7: Execute generator and project verification gates

**Files:**

- Read only: `tools/docs/antistasi-arsenal-system-atlas.json`
- Read only: `docs/assets/antistasi-arsenal-system-atlas-ru.html`
- Read only: `tests/verify_arsenal_permissions.ps1`
- Read only: `tests/verify_arsenal_regressions.ps1`

- [ ] **Step 1: Run the reusable generator self-test**

Run:

```powershell
$atlasSkillDir = 'C:\Users\Ded\.codex\skills\creating-radial-system-atlases'
node --test "$atlasSkillDir/scripts/self-test.mjs"
```

Expected: all Node subtests PASS.

- [ ] **Step 2: Run the browser interaction self-test**

Run:

```powershell
$env:RADIAL_ATLAS_BROWSER_TEST = '1'
try {
    node --test "$atlasSkillDir/scripts/self-test.mjs"
} finally {
    Remove-Item Env:RADIAL_ATLAS_BROWSER_TEST -ErrorAction SilentlyContinue
}
```

Expected: all static and Chromium interaction subtests PASS. If Chromium cannot
run because of an explicit environment or policy blocker, record this exact
gate as `NOT_RUN`; do not substitute DOM/source inspection and call it equal.

- [ ] **Step 3: Run the arsenal permission regression test**

Run:

```powershell
& 'tests/verify_arsenal_permissions.ps1'
```

Expected: `PASS: Arsenal edit permission checks are wired`.

- [ ] **Step 4: Run the arsenal behavior regression test**

Run:

```powershell
& 'tests/verify_arsenal_regressions.ps1'
```

Expected: `PASS: Arsenal cargo, itemType, and CBA setting regressions are covered`.

- [ ] **Step 5: Update only evidence statuses justified by executed tests**

If both project tests pass, change these exact JSON statuses from `not_run` or
`implemented` to `verified` only for the assertions they directly cover:

- `verification:permission-tests` → `verified`;
- `verification:regression-tests` → `verified`;
- the narrow permission-wiring claim in `editor:editor-access` and
  `editor:editor-save` may be `verified`;
- the narrow safe-lookup and magazine-preference claims in
  `stock-model:item-classification` may be `verified`;
- the narrow hosted-copy claim in `server-state:hosted-server` may be
  `verified`;
- the container attachment-preservation claim covered by the regression test
  may be `verified`.

Do not promote `ace-preview`, `ace-live-gate`,
`multiplayer-persistence-gate`, Legacy UI runtime behavior or remote execution
runtime behavior. Regenerate, revalidate and repeat the deterministic hash gate
after every status change.

Expected: updated HTML remains deterministic and all validators PASS.

## Task 8: Perform visual and interaction inspection

**Files:**

- Read only: `docs/assets/antistasi-arsenal-system-atlas-ru.html`

- [ ] **Step 1: Load the browser-control skill before controlling the in-app browser**

Read completely:

```text
C:/Users/Ded/.codex/plugins/cache/openai-bundled/browser/26.803.41515/skills/control-in-app-browser/SKILL.md
```

Expected: browser interaction follows the current installed instructions.

- [ ] **Step 2: Open the generated file directly**

Open:

```text
file:///C:/Users/Ded/Documents/Projects/ARMA%203%20Scripts/@Antistasi_Arsenal/docs/assets/antistasi-arsenal-system-atlas-ru.html
```

Expected: one fixed viewport, no native page scrollbars, full-map fit view,
toolbar, legends, mini-map, center, seven-stage inner cycle and nine branches.

- [ ] **Step 3: Inspect topology and readability**

Visually verify:

1. the center and all seven stages are distinct;
2. all nine branch hubs appear;
3. every branch has at least one readable panel after zooming;
4. cards do not overlap within a branch;
5. rails do not cover essential card text;
6. branch colors remain distinguishable and status is not color-only;
7. rightmost and bottommost cards remain reachable;
8. Russian text has no mojibake.

Expected: PASS or a precise model-level correction. For crowding, change
branch order, panel grouping or canvas size in JSON, regenerate and repeat. Do
not edit HTML geometry.

- [ ] **Step 4: Inspect camera behavior**

Exercise left-drag pan, cursor-centered wheel zoom, `+`, `−`, `Вписать всё`,
`Центр` and arrow-key pan.

Expected: camera remains finite, controls stay inside the viewport and the page
does not expose native scrollbars.

- [ ] **Step 5: Inspect explanations and edges**

Verify:

1. a 200 ms hover preview on the center;
2. click-pinned detailed center explanation;
3. a long pinned ACE or verification panel with internal scrolling;
4. Enter/Space pinning and Escape closing;
5. one explicit edge shows a visible line and wide hit target;
6. selecting that edge highlights both endpoints;
7. popovers near right and bottom edges use adaptive placement and remain
   inside the viewport;
8. repeated click and background click close as specified.

Expected: all applicable interactions PASS. Touch pan, pinch and second-touch
pin must be exercised when the available browser surface supports touch;
otherwise record only that touch portion as `NOT_RUN`.

- [ ] **Step 6: Inspect a compact desktop viewport**

Resize or emulate a compact desktop viewport near 800×600 and repeat fit,
popover, edge and toolbar checks.

Expected: no native page scrollbar, no clipped toolbar, and the pinned popover
scrolls internally.

## Task 9: Final integrity and handoff

**Files:**

- Verify: `tools/docs/antistasi-arsenal-system-atlas.json`
- Verify: `docs/assets/antistasi-arsenal-system-atlas-ru.html`
- Verify untouched: all pre-existing modified `source/A4A_Arsenal` files

- [ ] **Step 1: Re-run the complete machine-verification sequence**

Run source validation, HTML validation, two-generation SHA-256 comparison,
Node self-test, browser self-test when available, both PowerShell regression
tests, UTF-8 scan and privacy scan using the exact commands from Tasks 5–7.

Expected: every applicable automated gate PASS; any unavailable browser/touch
or live Arma 3 gate is explicitly `NOT_RUN` with its blocker.

- [ ] **Step 2: Verify deliverables and working-tree preservation**

Run:

```powershell
Get-Item 'tools/docs/antistasi-arsenal-system-atlas.json','docs/assets/antistasi-arsenal-system-atlas-ru.html' | Select-Object FullName,Length,LastWriteTime
git status --short
git diff --name-only
git diff --cached --name-only
```

Expected:

- both requested files exist;
- pre-existing source modifications remain present and unaltered by the atlas
  work;
- only the JSON and generated HTML are new implementation deliverables;
- no implementation path is staged.

- [ ] **Step 3: Produce the final evidence-backed handoff**

Report:

- clickable absolute paths to the JSON and HTML;
- branch, panel, edge and stage counts;
- input validator result;
- HTML validator result;
- deterministic SHA-256 result;
- Node self-test result;
- browser self-test result or exact `NOT_RUN` blocker;
- project regression-test results;
- visual-inspection coverage;
- touch and live Arma 3 gates as PASS or `NOT_RUN` without inference;
- confirmation that generated HTML was not hand-edited;
- confirmation that unrelated source changes were preserved;
- confirmation that no implementation staging, commit, push or deployment was
  performed.

Expected: the handoff distinguishes source evidence, automated proof, visual
interaction proof and unexecuted live-runtime proof.
