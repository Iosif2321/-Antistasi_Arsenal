# Antistasi Arsenal — Development Branch Changelog

Этот журнал ведётся в формате, близком к официальным обновлениям Arma 3
Development Branch: дата и revision сборки, затем `KNOWN ISSUES` и короткие
пункты с префиксами `Added:`, `Changed:`, `Tweaked:`, `Fixed:`, `Optimized:` и
`Security:`.

> **DEVELOPMENT BUILD DISCLAIMER**
> Незавершённые сборки могут содержать ошибки, неполные функции и изменения
> формата данных. Исходный код, статические проверки и успешная упаковка PBO не
> доказывают корректность SQF в hosted/dedicated Arma 3. Для стабильной игры
> используйте последний проверенный release build и сохраняйте резервную копию
> `profileNamespace`.

Официальные примеры формата:

- [Arma 3 Development Branch Changelog](https://forums.bohemia.net/forums/topic/140837-development-branch-changelog/)
- [What Is Dev-Branch?](https://dev.arma3.com/dev-branch)

## Обозначения

- **Revision** — короткий Git commit текущей или базовой сборки.
- **DEV WORKTREE** — изменения существуют в рабочем дереве, но ещё не образуют
  отдельный release commit.
- **SOURCE FIXED** — детерминированная причина исправлена в исходном коде.
- **CONTAINED** — небезопасный путь отключён или перенаправлен, но полное решение
  ещё не реализовано.
- **STATIC PASS** — прошли локальные текстовые/config/archive проверки.
- **NOT RUN** — сценарий не выполнялся в движке Arma 3; это не эквивалент PASS.

---

## 12-08-2026 — DEVELOPMENT BUILD

**Addon version:** 0.5.0

**Base revision:** `8cc640a`

**Source state:** `DEV WORKTREE / UNRELEASED`

**Package size:** not assigned

### KNOWN ISSUES

- Arma 3 config/SQF loading, hosted multiplayer, dedicated server with two
  clients, JIP, reconnect, persistence restart and performance benchmark are
  **NOT RUN** for this worktree.
- Arsenal stock mutations still use an optimistic client-first flow. There is
  no transaction ID, server reservation, ACK/NACK or physical inventory
  rollback. Two clients can therefore race for the last finite item, and the
  rejected client may retain locally granted equipment until reconciliation.
- A valid nearby client session can submit a positive add delta without a
  server-observed proof that the item was physically deposited. Sender binding
  limits who can call the endpoint, but does not make the deposit authoritative.
- Full editor saves use revisions, but ordinary accepted deltas can advance the
  sender's server revision without proving that the client applied every peer
  update. A stale editor snapshot can still overwrite a newer baseline.
- Open/close uses one session per network owner without a server-issued request
  nonce. Rapid opens of different arsenals, dropped responses, disconnect and
  network-owner reuse still require a generation/expiry cleanup protocol.
- Vehicle Arsenal `Unload` sends independent fire-and-forget deposits without a
  lease or rollback. Partial server rejection can lose or split cargo.
- Container transfer validates and snapshots cargo, but physical global clear
  still precedes a recoverable canonical commit. There is no general
  `finally`/compensation path for a script error between clear and unlock.
- Experimental Garage store RPC is hardened, but dedicated retrieval remains
  incomplete and has no authoritative spawn/grant transaction.
- The documented automatic transition from finite stock to unlimited `-1` at
  the unlock threshold is not implemented as a proven supported contract.
- ACE3 finite-stock support is **CONTAINED** by forced Legacy fallback. ACE3
  Preview is currently suitable only for an all-unlimited arsenal.
- The 250 ms coalesced profile save reduces write amplification but leaves a
  bounded crash/shutdown durability window.
- `CfgFunctions.hpp` duplicates part of `config.cpp` registration and remains a
  maintenance drift risk.

### SECURITY / NETWORKING

- Security: Changed `CfgRemoteExec > Functions` from open `mode = 2` to
  deny-by-default `mode = 1` with ten explicit RPC endpoints and target
  restrictions.
- Security: Disabled global JIP by default; retained JIP only for the three
  initialization endpoints that require bootstrap replay.
- Security: Bound open, close, mutation, cargo, editor-save and Zeus requests to
  engine-derived `remoteExecutedOwner`, a real human player, private session,
  canonical object/ID, UID, distance and player state.
- Security: Rejected scheduled remote execution on transaction-sensitive
  endpoints; supported request paths use unscheduled `remoteExecCall`.
- Security: Moved canonical arsenal data, revisions, sessions, registry,
  permissions and reserve settings to server-private `localNamespace` state.
- Security: Stopped treating broadcast object and `missionNamespace` variables
  as server authority. Public data is retained only as a compatibility mirror.
- Security: Hardened bootstrap/module functions, legacy arsenal dispatcher,
  Garage dispatcher and local add/remove wrappers against direct or relayed
  peer invocation.
- Security: Reworked Zeus assignment to derive the requesting player from the
  network owner, use a private allowlist and preserve unrelated curator modules.
- Fixed: Server dispatcher now rejects unapproved remote modes on hosted
  servers as well as on dedicated/client machines.
- Fixed: Mutation payloads validate type, integer bounds, canonical item
  category, private session and available finite stock before canonical commit.
- Fixed: Cargo-to-Arsenal now derives the target Arsenal ID from the bound
  private session and observes the source cargo on the server.

### ARSENAL

- Fixed: Restored the version-1 magazine contract: stored magazine amounts are
  remaining ammunition rounds, not a partially migrated count of physical
  magazines.
- Fixed: Withdrawal, return, loaded-magazine swap and Vehicle Arsenal restore
  use the same round-pool unit and guard zero-capacity magazine definitions.
- Fixed: Ordinary bulk return credits only the measured cargo difference rather
  than the requested removal amount.
- Fixed: Loaded weapon magazine handling uses the correct weapon tuple slots and
  preserves actual remaining ammunition for primary and secondary muzzles.
- Fixed: Non-player weapon deposit reads `weaponsItemsCargo` and credits the
  physical base weapon, attachments and remaining ammunition before clear.
- Fixed: Zero-mass modded items commit according to measured physical count,
  instead of relying on a load/mass change.
- Fixed: Unlimited binocular battery stock (`-1`) is accepted correctly.
- Fixed: Item classification fallback reads `[class, amount]` pairs correctly
  and keeps unknown/Junk items reachable through the fallback category.
- Fixed: Member reserve checks are capped and repeated on the server before a
  finite-stock withdrawal is accepted.
- Changed: Quantity modifiers use `1 / 5 / 10 / 50` in supported Legacy paths;
  Vehicle Arsenal no longer substitutes `25`.

### ACE3 PREVIEW

- Changed: Any finite JNA stock automatically falls back to Legacy Arsenal.
- Added: All-unlimited ACE3 Preview uses a client-local invisible proxy object
  populated through `ace_arsenal_fnc_addVirtualItems`.
- Fixed: The persistent mission arsenal object is no longer passed to
  `ace_arsenal_fnc_initBox`, preventing a leftover ACE interaction from
  bypassing later session/finite-stock checks.
- Fixed: Proxy and original arsenal objects are stored separately: the proxy is
  used for ACE UI state, while the original object is used for sender-bound
  server close.
- Fixed: Proxy cleanup runs after ACE `displayClosed` and does not delete an
  existing mission-owned ACE box configuration.
- Fixed: ACE handlers and delayed refreshes verify that
  `ace_arsenal_currentBox` is the expected A4A proxy.
- Fixed: Existing or overlapping ACE Arsenal displays are rejected/cancelled
  before they can overwrite the active A4A snapshot.
- Changed: ACE quantity tracking advertises only ACE's native physical `1 / 5`
  Shift behavior; unsupported synthetic Ctrl `10 / 50` steps were removed.

### EDITOR / PERSISTENCE

- Added: Sender-bound `A4A_fnc_arsenal_saveRequest` endpoint for EditorSave and
  one-shot nearby imports.
- Security: Replaced executable clipboard import with `parseSimpleArray` plus
  deep server-side validation.
- Fixed: Full snapshots require exactly 27 buckets, exact `[class, amount]`
  pairs, finite integer quantities, known config classes, canonical categories,
  global case-insensitive uniqueness and bounded total size.
- Added: Server revisions reject known stale full snapshots and invalidate
  other active viewers after an accepted full replacement.
- Added: Private UID rate limit for repeated editor/import saves.
- Fixed: Profile load validates all 27 buckets before data becomes canonical;
  malformed persisted data is not admitted as trusted server state.
- Fixed: Server initialization registers canonical object/ID/threshold in a
  small unscheduled critical section, then marks data ready only after validated
  stock and revision are installed.
- Added: Server-authored UI invalidation closes loading, Legacy and ACE states
  when initialization/save admission fails.
- Optimized: Replaced synchronous per-item `saveProfileNamespace` calls with a
  generation-aware 250 ms coalescing scheduler.
- Optimized: Cargo deposit performs one canonical batch, one scheduled profile
  flush and compact viewer updates instead of persistence per class.

### GARAGE / VEHICLE ARSENAL

- Security: Added private Garage registry, typed modes/payloads, sender-derived
  player identity, proximity/state checks and server-only module bootstrap.
- Fixed: Hosted-server Garage notification no longer depends on unsafe peer UI
  dispatcher behavior.
- Fixed: Vehicle magazine controls convert requested physical magazines to the
  version-1 round-pool using guarded magazine capacity.
- Fixed: Vehicle cargo restoration cannot loop forever on a zero-capacity
  magazine and restores partial final magazines deterministically.
- Fixed: Vehicle modifiers now use `1 / 5 / 10 / 50` consistently.

### CONFIGURATION / DOCUMENTATION / VERIFICATION

- Added: CBA settings for editor allowlist/access, Legacy-versus-ACE UI style and
  unlock threshold are snapshotted once as restart-required server authority.
- Changed: Legacy remains the default UI; ACE3 remains optional and is not a
  required addon dependency.
- Added: Level-5 research artifacts, system atlas model/viewer, Arma 3 2.22
  modding analysis and source-integrity regression gates.
- Optimized: Ignored disposable `.superpowers/brainstorm/` session state while
  keeping project plans and generated documentation visible.
- Verified: permission and regression PowerShell gates passed on the audited
  dirty snapshot.
- Verified: integrity/security static gate passed `87/87` on the audited dirty
  snapshot.
- Verified: strict UTF-8/control-character scan, PowerShell parser, SQF lexical
  delimiter scan, `git diff --check` and `CfgConvert -test` passed.
- Verified: a temporary AddonBuilder PBO was created and indexed successfully;
  this proves packaging shape, not Arma runtime behavior.
- Not verified: byte-for-byte reproducible PBO output; generated
  `BIS_AddonInfo.hpp` contains a changing `timepacked` field.

---

## Historical Development Builds

Historical entries below are reconstructed from Git history. They describe what
each revision intended to change; they are not retroactive proof that the build
passed current tests or live Arma multiplayer verification.

## 11-08-2026 — DOCUMENTATION BUILD

**Addon version:** 0.5.0

**Revision:** `8cc640a`

### DOCUMENTATION

- Added: Design specification for a Russian radial Antistasi Arsenal system
  atlas, including evidence/status rules and deterministic generation workflow.

## 09-07-2026 — DEV BUILD

**Addon version:** 0.5.0

**Revision:** `d2902d4`

### ARSENAL / ZEUS

- Added: Quantity steps `1 / 5 / 10 / 50` for arsenal item operations.
- Changed: Added handling for right Shift and right Ctrl modifiers.
- Tweaked: Curator assignment logic and modifier processing.

## 14-06-2026 — DEV BUILD

**Addon version:** 0.5.0

**Revision:** `0d86c55`

### CONFIGURATION

- Changed: Raised the allowed upper bound of the arsenal unlock-threshold
  setting.
- Added: Static regression coverage for the new threshold bound.

## 06-06-2026 — DEV BUILD

**Addon version:** 0.5.0

**Revisions:** `3f4a13c`, `50631de`

### ARSENAL

- Fixed: Duplicate cargo accounting during arsenal extraction.
- Fixed: RPG-32 magazine/category duplication.
- Fixed: Magazine classes take precedence over overlapping weapon/item config
  classes during classification.
- Changed: Consolidated CBA setting initialization and defaults.
- Added: Regression checks for cargo extraction, classification and RPG-32.

## 03-06-2026 — DEV BUILD

**Addon version:** 0.5.0

**Revision:** `9f2f027`

### EDITOR

- Added: Arsenal editor access modes and Steam UID allowlist.
- Added: Shared `A4A_fnc_arsenal_canEdit` permission helper.
- Changed: Applied edit permission checks to client UI and server save paths.
- Added: README documentation and static permission-wiring tests.

## 03-03-2026 — DEV BUILD

**Addon version:** 0.5.0

**Revision:** `854aae3`

### ARSENAL / ZEUS

- Added: Multi-quantity item operations in the Legacy Arsenal UI.
- Tweaked: Curator detection and assignment behavior.

## 02-03-2026 — DEV BUILD

**Addon version:** 0.5.0

**Revisions:** `1cc36a4`, `8fe7aaa`

### ARSENAL

- Fixed: Restored `BIS_fnc_itemType` as the primary preload classifier so the
  editor displays the complete item catalog.
- Added: JNA classifier fallback for ACE/CBA classes unknown to BIS.
- Added: `MiscItem` and Junk fallback handling for otherwise uncategorized
  items.

## 01-03-2026 — VERSION 0.5.0

**Revisions:** `22e54c9`, `20a3c04`

### ARSENAL

- Fixed: Initiating clients synchronize local `jna_dataList` during add/remove;
  broadcast excludes the initiator to avoid double application.
- Fixed: Arsenal custom initialization runs synchronously to prevent the full
  arsenal list from racing an incomplete configuration preload.
- Fixed: Unknown item types are retained in Misc instead of being silently
  discarded.
- Fixed: Nil guards prevent opening an unintended full arsenal when data is
  unavailable.
- Added: Vehicle Arsenal cargo backup and reusable restore path for abnormal
  close recovery.
- Changed: Input handling moved from the legacy Zeus key-sequence file into the
  current input handler.
- Changed: Updated addon version and corrected version output in logs.

## 28-02-2026 — DEV BUILD

**Addon version:** 0.4.7

**Revision:** `36bde20`

### DATA / BUILD

- Fixed: `$PBOPREFIX$` after the A3A-to-A4A rename, restoring stringtable and
  localization paths.
- Fixed: Cargo-to-Arsenal receives an explicit Arsenal ID instead of swapping a
  global `jna_object` variable.
- Fixed: `baseWeapon` normalization is limited to weapons so GPS and modded Misc
  items such as ACE DAGR are not replaced.
- Changed: Build script checks Steam/Arma tools, sets UTF-8 code page and verifies
  source paths before packaging.
- Fixed: SQF scope/nil guards in action, stub and Garage paths.

## 21-02-2026 — VERSION 0.4.7 / A4A RENAME

**Revisions:** `08a8964`, `5efd644`, `3965df7`, `42ffbbd`, `8a18001`, `7353b49`

### ARSENAL

- Added: Player/action logging for item add, remove and editor save operations.
- Added: Arsenal ID propagation in item-update logging and cargo transfer.
- Fixed: Message/comment encoding and malformed characters.
- Tweaked: Comments and source readability across the addon.
- Changed: Renamed the addon namespace and source tree from A3A Arsenal to A4A
  Arsenal, including PBO prefix and function/config paths.

## 19-02-2026 — VERSION 0.4.6

**Revisions:** `7dddfb5`, `99bb27f`, `c925162`

### ARSENAL / VEHICLE

- Added: Additional Arsenal UI elements and localized Vehicle Arsenal strings.
- Added: CBA configuration for container access.
- Changed: Iterated clipboard/import deserialization between
  `parseSimpleArray` and guarded compatibility fallback behavior.
- Tweaked: Vehicle Arsenal data parsing and diagnostics.

## 18-02-2026 — VERSIONS 0.4.0–0.4.5

**Revisions:** `3b4b7e7`, `9e4581b`, `d3adfa5`, `d7de074`, `a95cbb5`, `c333e4f`

### CBA / ARSENAL

- Added: CBA event registration for Zeus assignment and editor save.
- Changed: Revised event registration ownership between stub and JNA init.
- Added: Diagnostics for arsenal data loading, selected categories, IDC values
  and configuration snapshots.
- Fixed: Event registration and logging defects found during the 0.4.x
  iterations.
- Changed: Advanced development versions through 0.4.0, 0.4.2, 0.4.3 and
  0.4.5.

## 17-02-2026 — VERSION 0.3 DEVELOPMENT

**Revisions:** `b47f74b`, `95fc467`, `21369b7`, `288b521`

### ARSENAL / NETWORKING

- Changed: Simplified Zeus assignment checks and removed obsolete branches.
- Added: Zeus-aware access checks for Arsenal editing.
- Fixed: Function/PBO paths and object-existence checks in module startup.
- Changed: Reworked Arsenal save/category processing and introduced remoteExec
  command support used by the early multiplayer design.
- Tweaked: Module and server diagnostics.

## 16-02-2026 — INITIAL DEVELOPMENT BUILD

**Revisions:** `b034987`, `fb84538`

### DATA / SYSTEMS

- Added: Initial Antistasi Arsenal addon source, JNA quantitative arsenal,
  Vehicle Arsenal, experimental Garage, module definitions, dialogs,
  localization and build script.
- Added: Arsenal persistence, cargo conversion, multi-arsenal identifiers and
  initial multiplayer open/close/update paths.
- Added: Zeus edit workflow, curator assignment and key-sequence input.
- Added: Initial `CfgRemoteExec` policy and CfgFunctions registration.
- Tweaked: Zeus validation, error handling and logging after initial import.

---

## Verification Policy for Future Entries

Before moving a development entry to a stable release, record these gates
independently:

1. PowerShell permission, regression and integrity checks.
2. `git diff --check`, strict UTF-8 and SQF lexical/config parse.
3. Clean PBO build and archive index verification.
4. Arma 3 RPT without config/SQF runtime errors.
5. Hosted server plus one remote client.
6. Dedicated server plus two clients and a JIP client.
7. Concurrent last-item transaction, wrong-owner RPC and stale-session tests.
8. Persistence flush, restart and reopen of multiple Arsenal IDs.
9. Legacy finite-stock and ACE3 unlimited/fallback compatibility matrix.
10. Fixed-dataset performance benchmark with raw measurements.

`STATIC PASS`, `CONFIG PASS` and `PBO PASS` must never be rewritten as
`RUNTIME PASS` without the corresponding Arma logs and scenario evidence.
