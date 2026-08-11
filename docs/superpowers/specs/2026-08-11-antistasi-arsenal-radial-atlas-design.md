# Antistasi Arsenal radial system atlas design

Date: 2026-08-11

Status: approved design, awaiting written-spec review

Audience: mission administrators, addon developers, testers and maintainers

## Objective

Create a detailed Russian-language radial system atlas for the current
`@Antistasi_Arsenal` working tree. The atlas must explain the operating model
at an administrator-friendly level while exposing exact technical flows,
responsibility boundaries, evidence status and source locations for developers.

The primary artifact is a self-contained HTML document that works directly via
`file:///` and visually follows the same center-out reading model as the RICON
system atlas: one large navigable radial SVG, fixed camera controls, a mini-map,
interactive nodes and edges, hover previews and pinned detailed explanations.

## Scope

Included:

- the current implementation in the working directory, including uncommitted
  ACE3 Preview work;
- 3DEN module setup and CBA bootstrap;
- the 27-category JNA quantitative stock model;
- authoritative server state, per-Arsenal-ID separation and persistence;
- Legacy JNA user-interface flows;
- ACE3 Preview stock bridge and lifecycle;
- container and vehicle cargo transfer paths relevant to arsenal stock;
- editor access, import, export and server-side save authorization;
- remote execution and client/server trust boundaries;
- automated checks, failure handling and missing live proof gates.

Excluded:

- presenting the Garage source tree as a supported working feature;
- changing arsenal runtime behavior;
- changing the reusable atlas generator;
- publishing, deploying or pushing generated atlas artifacts;
- embedding secrets, personal platform identifiers, private hostnames or
  absolute machine-specific paths in generated content.

Garage may appear only as an explicitly marked experimental boundary so the
reader does not confuse its presence in the source tree with supported arsenal
behavior.

## Authoritative evidence

The model must derive factual claims from:

- `README.md`;
- `source/A4A_Arsenal/config.cpp`;
- `source/A4A_Arsenal/CfgFunctions.hpp`;
- `source/A4A_Arsenal/functions/fn_moduleArsenal.sqf`;
- `source/A4A_Arsenal/functions/fn_arsenalInit.sqf`;
- `source/A4A_Arsenal/functions/fn_arsenalLogic.sqf`;
- `source/A4A_Arsenal/functions/fn_arsenal_canEdit.sqf`;
- `source/A4A_Arsenal/functions/fn_arsenal_isZeus.sqf`;
- relevant `source/A4A_Arsenal/JNA/fn_arsenal*.sqf` files;
- `source/A4A_Arsenal/JNA/fn_vehicleArsenal.sqf`;
- `tests/verify_arsenal_permissions.ps1`;
- `tests/verify_arsenal_regressions.ps1`;
- the current Git diff for the ACE3 Preview branch.

Filename presence alone is not evidence. Each authored panel must be tied to
the implementation or documentation that supports its claim.

## Center invariant

The atlas center represents a decision authority, not a logo or table of
contents:

> The system computes, applies and persists the authoritative quantitative
> state of one arsenal for a validated player, container or editor operation,
> using server-held 27-category stock, module/CBA policy and access context,
> while leaving user-interface presentation and physical loadout mutation to
> the Legacy JNA or ACE3 adapter.

The center must communicate:

- which operation is being evaluated;
- which Arsenal ID owns the state;
- whether the operation is permitted;
- which stock delta is accepted;
- what becomes authoritative after the operation;
- which adapter or consumer receives the resulting state.

## Ordered central stages

The inner cycle contains seven stages in this order:

1. **Receive operation** — open, take, return, cargo transfer, editor change or
   close.
2. **Resolve scope** — identify the arsenal object, Arsenal ID, client and
   active session.
3. **Authorize** — evaluate availability, editor policy, SteamID/Zeus access,
   container policy and the server-side recheck where applicable.
4. **Classify item** — map an item to one of the 27 categories and read its
   current finite, empty or infinite state.
5. **Compute delta** — account for direction, quantity modifiers, real ACE
   cargo delta, remaining stock and the unlock threshold.
6. **Apply authoritative state** — mutate a copied server-side data structure,
   never an unsafe shared alias.
7. **Synchronize and persist** — update active viewers, profile-backed storage
   and adapter/session state.

The generated stage cycle is structural. Detailed initialization and adapter
behavior belong to responsibility branches rather than being forced into the
cycle.

## Responsibility branches

The atlas uses nine branches. Branch order is intentional so initialization is
near the top, UI adapters occupy opposing sectors, authoritative state and
network flow remain visually connected, and verification sits near system
outputs.

### 1. Deployment and bootstrap

Panels cover:

- the 3DEN module and synchronized object;
- Arsenal ID and Unlock Threshold attributes;
- CBA preInit settings registration;
- function registration and postInit hooks;
- object initialization, JIP behavior and duplicate-init guards.

Expected status: `implemented`, with individual checks marked `verified` only
when an executed test directly proves the stated behavior.

### 2. Stock model and classification

Panels cover:

- the 27 category arrays;
- `[className, count]` entries;
- `-1` as infinite stock;
- `itemType`, `itemCount` and `inList` behavior;
- unlock threshold conversion;
- magazine/config precedence, ACE explosives and radio-category handling.

Expected status: mostly `implemented`; narrow claims covered by executed
regression checks may be `verified`.

### 3. Server authority and persistence

Panels cover:

- per-Arsenal-ID server keys;
- loading from `profileNamespace`;
- defensive copies before mutation;
- persistence and save boundaries;
- tracking clients currently viewing an arsenal;
- hosted-server behavior and local/remote update distinctions.

Expected status: `implemented`. Live multiplayer persistence remains
`not_run` unless exercised in Arma 3 during this task.

### 4. Legacy JNA interface

Panels cover:

- action handling and player inventory snapshots;
- opening requests and data delivery;
- taking and returning items;
- Shift/Ctrl quantity modifiers;
- UI update and close lifecycle;
- missing-data and loading-screen failure paths.

Expected status: `implemented`. A static code path is not treated as live UI
proof.

### 5. ACE3 Preview adapter

Panels cover:

- CBA selection between Legacy and ACE UI;
- availability checking and fallback to Legacy;
- ACE virtual-item initialization from JNA stock;
- session begin/end and event-handler registration;
- cargo snapshots and calculation of real inventory deltas;
- equipped-item synchronization;
- unavailable stock and radio/ACRE/TFAR category handling.

Expected status: `prototype`. This status remains even where individual helper
functions are implemented because the full live multiplayer interaction has
not been demonstrated in this task.

### 6. Containers and vehicles

Panels cover:

- nearby object selection;
- container access policy;
- cargo extraction and categorization;
- transfer into arsenal stock;
- busy guards and concurrent-viewer updates;
- preservation of weapon attachments and loaded magazines;
- the boundary between supported cargo transfer and experimental vehicle
  arsenal code.

Expected status: a mixture of `implemented`, narrow `verified` regression
claims and `prototype` for experimental vehicle behavior.

### 7. Editor, import and export

Panels cover:

- SteamID allowlist parsing without embedding actual IDs;
- optional Zeus requirement;
- editor-open and editor-modify paths;
- finite/infinite count changes;
- export format and import block boundaries;
- server-side authorization before `SAVE_JNA` persistence.

Expected status: `implemented`; authorization wiring becomes `verified` only
after the permission test passes.

### 8. Network and trust boundaries

Panels cover:

- open and close requests;
- item-add and item-remove updates;
- server ownership of persistent mutation;
- update fan-out to active viewers of the same Arsenal ID;
- `CfgRemoteExec` targets;
- public/JIP state used during initialization;
- safe failure when an expected remote path is unavailable.

Expected status: `implemented`, while live dedicated-server behavior remains
`not_run` without an in-game multiplayer test.

### 9. Verification, failures and proof gaps

Panels cover:

- permission regression checks;
- cargo, item-type, CBA and hosted-server regression checks;
- empty or malformed data handling;
- ACE-to-Legacy fallback;
- live proof gates for hosted and dedicated multiplayer;
- the Garage experimental boundary;
- the distinction between source evidence, automated proof and live evidence.

Expected status is per panel: executed checks may be `verified`; required live
scenarios are `not_run`; uncertain behavior is `unknown` rather than inferred.

## Explicit cross-system edges

Structural core-to-branch and branch-to-panel spokes are generated
automatically. Authored edges are limited to relationships that materially
explain behavior:

- bootstrap to server authority: initialized object and scoped Arsenal ID;
- Legacy UI to network: open/close request and item operation;
- ACE3 Preview to stock model: virtual-item mirror and accepted delta;
- container transfer to stock model: categorized cargo additions;
- editor access to server authority: authorized save command;
- network to server authority: authoritative mutation request;
- server authority to Legacy UI: current stock copy/update;
- server authority to ACE3 Preview: current stock copy/update;
- server authority to persistence: state save boundary;
- permission checks to editor operations: identity decision;
- test evidence to verification panels: automated verdict, not live runtime
  telemetry.

Every interactive edge must have a visible line, a wide hit target, a semantic
ID, an edge type, a direction where appropriate, a plain-language explanation
and endpoint highlighting.

## Explanation model

Every center, stage, branch, panel and explicit edge receives a reusable
explanation entry. Important elements include explicit Russian-language fields
for:

- preview;
- purpose;
- input;
- three to seven ordered actions;
- decision or gate;
- output;
- next owner;
- failure behavior;
- current evidence status.

Code symbols, formulas and source paths remain in technical fields and source
lists. Plain-language logic explains behavior without requiring SQF knowledge.

## Visual and interaction contract

The generated page is a navigable map rather than a poster:

- one large inline SVG on a fixed, scrollbar-free HTML viewport;
- center, stage ring, branch hubs and one to eight panels per branch;
- automatic deterministic center-out geometry;
- branch-specific color paired with labels and status text;
- structural cycle, spokes and authored cross-links;
- one fixed reusable HTML popover;
- 200 ms hover/focus preview;
- pinned detailed view after click, Enter, Space or second touch;
- internal scrolling for long pinned content;
- adaptive right/left/bottom/top placement;
- endpoint highlighting when an edge is selected;
- mouse drag, wheel zoom, one-touch pan and two-touch pinch zoom;
- zoom buttons, “Вписать всё”, “Центр” and arrow-key pan;
- keyboard-focusable semantic SVG groups with accessible names;
- restrictive CSP and no active external resources or network APIs.

The full-map scale is for topology. Text is read after zooming or opening an
explanation; labels must not be shrunk merely to make the full map readable.

## Evidence semantics

Statuses are evidence claims:

- `implemented`: code or configuration exists;
- `verified`: the exact stated behavior has direct executed evidence;
- `prototype`: partial or experimental implementation;
- `planned`: design only;
- `blocked`: a named blocker prevents progress;
- `not_run`: a required scenario was not executed;
- `unknown`: evidence is insufficient.

Documentation, source inspection, successful generation and local tests must
not be presented as live Arma 3 proof. The missing runtime gate is written into
the relevant panel.

## Project-owned source and generated output

Authoritative model:

`tools/docs/antistasi-arsenal-system-atlas.json`

Generated interactive artifact:

`docs/assets/antistasi-arsenal-system-atlas-ru.html`

The HTML is generated only by:

`C:/Users/Ded/.codex/skills/creating-radial-system-atlases/scripts/build-radial-atlas.mjs`

The generated HTML/SVG must never be hand-edited. Content corrections are made
in the JSON model and the artifact is regenerated.

A standalone SVG is not required because the user requested an interactive
HTML artifact and a raw SVG would not include the fixed camera and popover
controller.

## Verification plan

Use a task-specific PowerShell variable for the skill directory and absolute
paths for every command:

```powershell
$atlasSkillDir = 'C:\Users\Ded\.codex\skills\creating-radial-system-atlases'
$atlasInput = (Resolve-Path 'tools/docs/antistasi-arsenal-system-atlas.json').Path
$atlasOutput = (Resolve-Path 'docs/assets/antistasi-arsenal-system-atlas-ru.html').Path

node "$atlasSkillDir/scripts/validate-radial-atlas.mjs" --input "$atlasInput"
node "$atlasSkillDir/scripts/build-radial-atlas.mjs" --input "$atlasInput" --output "$atlasOutput"
node "$atlasSkillDir/scripts/validate-radial-atlas.mjs" --input "$atlasInput" --html "$atlasOutput"
node --test "$atlasSkillDir/scripts/self-test.mjs"
```

Additional gates:

1. Generate twice without changing the JSON and compare SHA-256 hashes.
2. Run the browser self-test with `RADIAL_ATLAS_BROWSER_TEST=1`, then remove the
   temporary environment variable.
3. Run `tests/verify_arsenal_permissions.ps1`.
4. Run `tests/verify_arsenal_regressions.ps1`.
5. Inspect the generated artifact for credential-like content, personal IDs,
   private hostnames and absolute machine paths.
6. Visually inspect full-map topology, center and stage ring, at least one panel
   per branch, one selected explicit edge, endpoint highlighting, preview,
   pinned long explanation, right and bottom edge placement and a compact
   desktop viewport.
7. Exercise touch input when the available browser surface supports it.
8. Mark live Arma 3 dedicated/hosted multiplayer behavior `not_run` unless the
   scenario is actually executed.

Browser unavailability is reported as `NOT_RUN` with the exact blocker. Static
source inspection is not substituted for visual or interaction proof.

## Risks and mitigations

- **Crowding:** use a large square canvas in the 140000–180000 range, group
  duplicate details and adjust branch order before considering a split.
- **False proof:** keep evidence status narrow and write missing live gates into
  explanations.
- **Drift:** generate from a project-owned JSON model and keep source paths on
  technical cards.
- **Encoding:** create the JSON as UTF-8 and verify Russian strings in both the
  model and HTTP/file rendering.
- **Privacy:** use semantic roles instead of real SteamIDs and reject secret-like
  data with the validator.
- **Dirty worktree:** stage exact paths only and never use broad Git staging.
- **Generated-file divergence:** never hand-edit the HTML; regenerate after
  every source-model change and require deterministic hashes.

## Acceptance criteria

The task is complete only when:

- the JSON source validates;
- the HTML validates;
- two generations from the same input produce identical SHA-256 hashes;
- generator Node self-tests pass;
- browser self-tests pass or are explicitly `NOT_RUN` with a blocker;
- project regression tests pass;
- visual inspection covers the required topology and interaction cases;
- the requested files exist at the documented paths;
- Russian text renders without mojibake;
- evidence statuses do not overclaim live behavior;
- unrelated working-tree changes remain untouched;
- only the approved design specification is committed at the design gate;
- no generated atlas artifact is committed, pushed or deployed without the
  corresponding implementation and verification gate.
