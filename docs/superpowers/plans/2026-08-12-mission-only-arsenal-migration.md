# Mission-only Antistasi Arsenal Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the quantitative Antistasi Arsenal as one unpacked mission folder that runs from the scenario, requires no A4A client or server addon, preserves crate/vehicle cargo transfer, removes the Garage system, and interoperates safely with optional CBA_A3 3.19.0 and ACE3 3.21.1.

**Architecture:** The mission owns all A4A scripts, UI resources, configuration, persistence, and its strict `CfgRemoteExec` policy. The server keeps canonical stock, revisions, sessions, reservations, cargo locks, and profile persistence in private namespaces. Clients receive presentation code from the mission, open Legacy or local ACE proxy UI, and submit correlated transaction completions; they never author canonical stock directly. Crates and vehicles use one server-observed physical-cargo transaction path. Garage/storage/spawn logic is excluded from the artifact.

**Tech Stack:** Arma 3 SQF and mission config (`description.ext`, `mission.sqm`), PowerShell static/regression gates, CfgConvert configuration parsing, optional CBA Settings API, optional ACE3 Arsenal API.

---

## Task 1: Mission-only artifact contract

**Files:**
- Create: `tests/verify_mission_only_layout.ps1`
- Create: `mission/A4A_Arsenal_Mission.VR/description.ext`
- Create: `mission/A4A_Arsenal_Mission.VR/initServer.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/initPlayerLocal.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/Stringtable.xml`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/config/arsenals.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/config/settings.sqf`

- [x] Add a failing static test that requires the unpacked mission root and rejects `CfgPatches`, addon paths, `$PBOPREFIX$`, Garage files/functions, `fn_vehicleArsenal.sqf`, and PBO artifacts anywhere inside the mission artifact.
- [x] Run `powershell -NoProfile -ExecutionPolicy Bypass -File tests/verify_mission_only_layout.ps1` and confirm the missing artifact fails.
- [x] Add the minimal scenario-owned skeleton and empty, parseable configuration files.
- [x] Rerun the layout test and confirm its structural subset passes.
- [x] Commit exact task paths with message `test: define mission-only arsenal artifact`.

## Task 2: Mission configuration and strict RPC surface

**Files:**
- Modify: `tests/verify_mission_only_layout.ps1`
- Modify: `mission/A4A_Arsenal_Mission.VR/description.ext`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/CfgFunctions.hpp`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/CfgRemoteExec.hpp`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/ui/defines.hpp`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/ui/dialogs.hpp`

- [x] Extend the test to require mission-local `CfgFunctions`, `CfgRemoteExec` Functions/Commands `mode = 1`, `allowedTargets`, `jip = 0`, no arbitrary-code RPC gadgets, and all include paths relative to the mission.
- [x] Run the test and observe the missing declarations fail.
- [x] Implement the narrow client/server function registration and UI includes.
- [x] Parse `description.ext` with the available CfgConvert tool and rerun the static test.
- [x] Commit exact task paths with message `feat: define mission rpc and function surface`.

## Task 3: Deterministic bootstrap and scenario configuration

**Files:**
- Modify: `tests/verify_mission_only_layout.ps1`
- Modify: `mission/A4A_Arsenal_Mission.VR/initServer.sqf`
- Modify: `mission/A4A_Arsenal_Mission.VR/initPlayerLocal.sqf`
- Modify: `mission/A4A_Arsenal_Mission.VR/A4A/config/arsenals.sqf`
- Modify: `mission/A4A_Arsenal_Mission.VR/A4A/config/settings.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/bootstrap/fn_preInit.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/bootstrap/fn_serverInit.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/bootstrap/fn_clientInit.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/bootstrap/fn_registerConfiguredArsenals.sqf`

- [x] Add failing invariants for server-private registry/data/revision/session/transaction/cargo-lock maps, canonical object/ID/threshold resolution, ready gating, atomic one-time claims, and idempotent JIP client actions.
- [x] Run the test and confirm these invariants fail.
- [x] Implement constant-time pre-initialization and deferred registration from `[variableName, arsenalId, threshold]` rows in `arsenals.sqf`.
- [x] Ensure absent/malformed mission configuration fails closed with bounded diagnostics and never imports authority from replicated mission variables.
- [x] Rerun the targeted test.
- [x] Commit exact task paths with message `feat: bootstrap mission arsenal state`.

## Task 4: Port quantitative Legacy Arsenal without addon/Garage dependencies

**Files:**
- Modify: `tests/verify_mission_only_layout.ps1`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/Common/**`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/JNA/**`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/shared/**`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/pictures/arsenal.paa`

- [x] Add a failing inventory-manifest test listing every required Legacy/JNA/shared function and prohibiting every Garage or vehicle-Arsenal symbol.
- [x] Run the test and confirm the missing port fails.
- [x] Mechanically copy the proven quantitative Arsenal/UI helpers and assets, excluding addon bootstrap, module functions, Garage, and `fn_vehicleArsenal.sqf`.
- [x] Replace absolute addon paths and addon-only macros with mission-relative paths; make all config caches client-local or server-private as appropriate.
- [x] Run the manifest test plus a delimiter/string/comment scanner across every mission SQF.
- [x] Commit exact mission source paths with message `feat: port quantitative arsenal into mission`.

## Task 5: Correlated open/close session protocol

**Files:**
- Modify: `tests/verify_mission_only_layout.ps1`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/server/fn_requestOpen.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/server/fn_requestClose.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/client/fn_receiveOpen.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/client/fn_receiveInvalidate.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/client/fn_openAction.sqf`

- [x] Add RED checks requiring sender-to-player binding, registered/ready object, distance, UID, request nonce, server generation, canonical revision, object identity, expiry, and stale-response rejection on open/close.
- [x] Run the test and observe failure.
- [x] Implement one active generation per owner, response payload `[object, nonce, generation, revision, snapshot, presentationMode]`, matching close, disconnect/expiry cleanup, and loading/UI invalidation.
- [x] Ensure Legacy never binds an open response through a mutable global target.
- [x] Rerun the targeted test.
- [x] Commit exact paths with message `feat: correlate arsenal sessions`.

## Task 6: Server-authoritative inventory transactions

**Files:**
- Modify: `tests/verify_mission_only_layout.ps1`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/server/fn_requestWithdraw.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/server/fn_completeWithdraw.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/server/fn_requestReturn.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/server/fn_completeReturn.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/server/fn_expireTransactions.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/client/fn_receiveGrant.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/client/fn_receiveTransactionResult.sqf`
- Modify: `mission/A4A_Arsenal_Mission.VR/A4A/JNA/fn_arsenal.sqf`
- Modify: `mission/A4A_Arsenal_Mission.VR/A4A/JNA/fn_arsenal_addItem.sqf`
- Modify: `mission/A4A_Arsenal_Mission.VR/A4A/JNA/fn_arsenal_removeItem.sqf`

- [x] Add RED invariants proving clients cannot call canonical Add/Remove, every request carries the active generation and expected revision, withdrawals reserve before physical grant, completion commits once, failure/timeout refunds, duplicate messages are idempotent, and origin receives authoritative result/rollback.
- [x] Run the test and observe failure against the optimistic legacy wrappers.
- [x] Route every finite-stock take/return through transaction IDs and a server-side state machine; keep unlimited `-1` semantics explicit and bounded.
- [x] Replace client-first canonical updates with provisional UI state plus ACK/resync; invalidate full-save eligibility whenever the client lacks an acknowledged baseline.
- [x] Rerun the transaction checks and legacy regression suite.
- [x] Commit exact paths with message `feat: make arsenal inventory transactional`.

## Task 7: Canonical validation, revisions, and persistence

**Files:**
- Modify: `tests/verify_mission_only_layout.ps1`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/server/fn_validateSnapshot.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/server/fn_loadPersistence.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/server/fn_schedulePersistence.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/server/fn_saveEditorSnapshot.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/shared/fn_itemTypeCached.sqf`

- [x] Add RED cases for 27 buckets, canonical bucket/type, known config class, one global case-insensitive occurrence, amount `-1` or positive integer within cap, total entry cap, payload-string cap, expected revision, and invalid-profile fallback without partial import.
- [x] Run the test and observe failure.
- [x] Implement deep validation and load-then-publish ordering; increment revision on every canonical mutation and compare editor baselines before replace.
- [x] Implement a generation-safe 250 ms `uiSleep` coalescer and bounded editor-save rate limiting.
- [x] Rerun validation, persistence, and UTF-8/delimiter gates.
- [x] Commit exact paths with message `feat: validate and persist mission arsenal state`.

## Task 8: Atomic physical cargo for crates and vehicles

**Files:**
- Modify: `tests/verify_mission_only_layout.ps1`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/cargo/fn_snapshotCargo.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/cargo/fn_requestCargoDeposit.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/cargo/fn_requestCargoWithdraw.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/cargo/fn_restoreCargo.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/client/fn_addCargoActions.sqf`

- [x] Add RED checks for one generic crate/vehicle path, registered nearby arsenal, sender locality, server-observed holder, per-holder lock, complete tuple accounting for weapons/attachments/loaded rounds, capacity check, validate candidate before clear, rollback snapshot, bounded batch, atomic canonical revision, and finally-style lock release.
- [x] Run the test and observe failure.
- [x] Implement deposit/withdraw without Garage state, hidden staging inventory, or fire-and-forget per-item deltas.
- [x] Attach the same mission actions to configured crates and physical vehicles; treat vehicles strictly as cargo holders.
- [x] Rerun cargo tests and confirm the mission artifact contains no Garage/vehicle-storage code.
- [x] Commit exact paths with message `feat: transact crate and vehicle cargo`.

## Task 9: Optional CBA_A3 3.19.0 adapter

**Files:**
- Modify: `tests/verify_mission_only_layout.ps1`
- Create: `tests/verify_mission_dependency_compatibility.ps1`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/adapters/fn_initCbaSettings.sqf`
- Modify: `mission/A4A_Arsenal_Mission.VR/A4A/functions/shared/fn_getSetting.sqf`

- [x] Add a failing compatibility test proving there is no hard CBA dependency, `CBA_fnc_addSetting` is optional, no nonexistent `CBA_fnc_getSetting` call remains, and settings are read from the variable generated by CBA Settings with mission defaults as fallback.
- [x] Run the test and observe failure.
- [x] Implement idempotent optional setting registration and private server snapshots for authority-sensitive values.
- [x] Compare used symbols with the locally installed CBA_A3 3.19.0 source and rerun the test.
- [x] Commit exact paths with message `feat: add optional cba settings adapter`.

## Task 10: Optional ACE3 3.21.1 local proxy adapter

**Files:**
- Modify: `tests/verify_mission_dependency_compatibility.ps1`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/adapters/fn_openAceProxy.sqf`
- Create: `mission/A4A_Arsenal_Mission.VR/A4A/functions/adapters/fn_closeAceProxy.sqf`
- Modify: `mission/A4A_Arsenal_Mission.VR/A4A/JNA/fn_arsenal_aceStock.sqf`

- [x] Add RED checks for ACE feature detection, `createVehicleLocal "Land_HelipadEmpty_F"`, explicit local `false` for virtual-item changes, `openBox` on the proxy, original/proxy identity separation, current-box/session generation checks, next-frame cleanup, and Legacy fallback for finite or absent ACE support.
- [x] Run the compatibility test and observe failure.
- [x] Implement the proxy lifecycle without `initBox`/`removeBox` on persistent mission objects and without installing global ACE actions.
- [x] Compare every called signature with installed ACE3 3.21.1 source and rerun the test.
- [x] Commit exact paths with message `feat: integrate optional ace arsenal proxy`.

## Task 11: Runnable unpacked VR scenario and operator documentation

**Files:**
- Create: `mission/A4A_Arsenal_Mission.VR/mission.sqm`
- Create: `mission/A4A_Arsenal_Mission.VR/README_MISSION_RU.md`
- Create: `mission/A4A_Arsenal_Mission.VR/COMPATIBILITY.md`
- Create: `mission/A4A_Arsenal_Mission.VR/VERIFICATION.md`
- Modify: `tests/verify_mission_only_layout.ps1`

- [x] Add RED checks for a parseable VR mission, configured named arsenal crate, playable unit, no addon A4A dependency, installation/run instructions, persistence reset/backup instructions, CBA/ACE compatibility matrix, and explicit static versus runtime proof status.
- [x] Run the test and observe failure.
- [x] Create the minimal multiplayer-capable VR scenario and Russian operator guide for copying the unpacked folder into `MPMissions` and configuring arsenal object rows.
- [x] Document CBA_A3 3.19.0, ACE3 3.21.1, no-CBA, no-ACE, dedicated, hosted, JIP, reconnect, restart, two-client race, cargo rollback, and mod-heavy performance runtime gates without claiming unrun evidence.
- [x] Rerun layout and documentation checks.
- [x] Commit exact paths with message `docs: make mission-only arsenal deployable`.

## Task 12: Migration verification and handoff

**Files:**
- Modify: `tests/verify_mission_only_layout.ps1`
- Modify: `tests/verify_mission_dependency_compatibility.ps1`
- Modify: `mission/A4A_Arsenal_Mission.VR/VERIFICATION.md`
- Modify: `docs/superpowers/specs/2026-08-12-mission-only-arsenal-design.md`

- [x] Run the mission-only layout, compatibility, original permissions/regressions/integrity, strict UTF-8, bare-CR, lexical delimiter, `git diff --check`, and CfgConvert gates from a clean command log.
- [x] Verify `rg` finds no Garage, addon-only absolute path, `$PBOPREFIX$`, PBO, `CBA_fnc_getSetting`, ACE persistent-box initialization, unrestricted Functions mode, or direct client canonical mutation inside the mission artifact.
- [x] Record exact PASS/FAIL/NOT_RUN evidence and hashes in `VERIFICATION.md`; mark PBO build `NOT_APPLICABLE` because the product is unpacked and leave live Arma/ACE/CBA multiplayer tests explicitly `NOT_RUN` because engine runtime is a separate proof gate.
- [x] Review `git diff --stat`, exact staged paths, and `git diff --cached`; keep `timecraft*` and all unrelated user files unstaged.
- [x] Commit exact migration/test/document paths with message `chore: verify mission-only arsenal migration`.
