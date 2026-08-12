$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$missionRoot = Join-Path $repoRoot "mission/A4A_Arsenal_Mission.VR"
$failures = [System.Collections.Generic.List[string]]::new()
$passes = [System.Collections.Generic.List[string]]::new()

function Assert-Compat {
    param([string]$Name, [bool]$Condition)
    if ($Condition) { $passes.Add($Name) } else { $failures.Add($Name) }
}

function Read-TextOrEmpty {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return Get-Content -LiteralPath $Path -Raw
    }
    return ""
}

$description = Read-TextOrEmpty (Join-Path $missionRoot "description.ext")
$functionConfig = Read-TextOrEmpty (Join-Path $missionRoot "A4A/CfgFunctions.hpp")
$cbaAdapterPath = Join-Path $missionRoot "A4A/functions/adapters/fn_initCbaSettings.sqf"
$getSettingPath = Join-Path $missionRoot "A4A/functions/shared/fn_getSetting.sqf"
$serverInitPath = Join-Path $missionRoot "A4A/functions/bootstrap/fn_serverInit.sqf"
$registryPath = Join-Path $missionRoot "A4A/functions/bootstrap/fn_registerConfiguredArsenals.sqf"
$cargoValidationPath = Join-Path $missionRoot "A4A/functions/shared/fn_validateCargoRequest.sqf"
$legacyHandlerPath = Join-Path $missionRoot "A4A/JNA/fn_arsenal_handleAction.sqf"
$cbaAdapter = Read-TextOrEmpty $cbaAdapterPath
$getSetting = Read-TextOrEmpty $getSettingPath
$serverInit = Read-TextOrEmpty $serverInitPath
$registry = Read-TextOrEmpty $registryPath
$cargoValidation = Read-TextOrEmpty $cargoValidationPath
$legacyHandler = Read-TextOrEmpty $legacyHandlerPath

Assert-Compat "mission has no hard CBA requiredAddons or include" (
    $description -notmatch 'requiredAddons|cba_settings\.sqf|\\x\\cba\\' -and
    $functionConfig -notmatch 'requiredAddons|\\x\\cba\\'
)
Assert-Compat "optional CBA adapter and mission-native getter exist" (
    (Test-Path -LiteralPath $cbaAdapterPath -PathType Leaf) -and
    (Test-Path -LiteralPath $getSettingPath -PathType Leaf)
)
Assert-Compat "CBA registration is capability checked and idempotent" (
    $cbaAdapter -match 'isNil\s+"CBA_fnc_addSetting"' -and
    $cbaAdapter -match 'A4A_ClientCbaSettingsRegistered|A4A_ServerCbaSettingsRegistered' -and
    $cbaAdapter -match 'isRemoteExecuted'
)
Assert-Compat "five mission settings use documented CBA addSetting API" (
    ([regex]::Matches($cbaAdapter, 'call\s+CBA_fnc_addSetting\s*;')).Count -eq 5 -and
    $cbaAdapter -match 'A4A_Mission_CargoAccess' -and
    $cbaAdapter -match 'A4A_Mission_EditorSteamIDs' -and
    $cbaAdapter -match 'A4A_Mission_EditAccessMode' -and
    $cbaAdapter -match 'A4A_Mission_UnlockThreshold' -and
    $cbaAdapter -match 'A4A_Mission_UIStyle'
)
Assert-Compat "mission setting getter reads CBA result variables with defaults" (
    $getSetting -match 'missionNamespace\s+getVariable' -and
    $getSetting -match 'A4A_Mission_UIStyle' -and
    $getSetting -match '_default' -and
    $getSetting -notmatch 'CBA_fnc_getSetting'
)
$allMissionSqf = (Get-ChildItem -LiteralPath $missionRoot -Recurse -Filter *.sqf -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
Assert-Compat "mission never calls nonexistent CBA_fnc_getSetting" ($allMissionSqf -notmatch 'CBA_fnc_getSetting')
Assert-Compat "server captures authority-sensitive CBA values once before registry creation" (
    $serverInit -match 'A4A_fnc_initCbaSettings' -and
    $serverInit.IndexOf('A4A_fnc_initCbaSettings') -lt $serverInit.IndexOf('A4A_fnc_registerConfiguredArsenals') -and
    $cbaAdapter -match 'A4A_ServerCbaAuthorityCaptured' -and
    $cbaAdapter -match 'A4A_ServerSettings' -and
    $cbaAdapter -match 'editorSteamIDs' -and
    $cbaAdapter -match 'editAccessMode'
)
Assert-Compat "server-only CBA snapshots drive threshold and cargo access" (
    $registry -match 'unlockThresholdOverride' -and
    $cargoValidation -match 'cargoAccess' -and
    $cargoValidation -match 'A4A_fnc_canEdit'
)
Assert-Compat "legacy handler uses mission getter rather than CBA getter" (
    $legacyHandler -match 'A4A_fnc_getSetting' -and
    $legacyHandler -notmatch 'CBA_fnc_getSetting'
)

$cbaMod = "D:/SteamLibrary/steamapps/workshop/content/107410/450814997/mod.cpp"
$cbaPbo = "D:/SteamLibrary/steamapps/workshop/content/107410/450814997/addons/cba_settings.pbo"
if ((Test-Path -LiteralPath $cbaMod) -and (Test-Path -LiteralPath $cbaPbo)) {
    $cbaModText = Get-Content -LiteralPath $cbaMod -Raw
    Assert-Compat "local CBA_A3 compatibility target is 3.19.0" ($cbaModText -match '3\.19\.0')
    Assert-Compat "local CBA settings PBO is available for API audit" ((Get-Item -LiteralPath $cbaPbo).Length -gt 0)
} else {
    Write-Host "NOTE: local CBA Workshop installation not found; installed-version assertions skipped."
}

$aceOpenPath = Join-Path $missionRoot "A4A/functions/adapters/fn_openAceProxy.sqf"
$aceClosePath = Join-Path $missionRoot "A4A/functions/adapters/fn_closeAceProxy.sqf"
$aceStockPath = Join-Path $missionRoot "A4A/JNA/fn_arsenal_aceStock.sqf"
$aceOpen = Read-TextOrEmpty $aceOpenPath
$aceClose = Read-TextOrEmpty $aceClosePath
$aceStock = Read-TextOrEmpty $aceStockPath

Assert-Compat "ACE adapter files exist without hard mission dependency" (
    (Test-Path -LiteralPath $aceOpenPath -PathType Leaf) -and
    (Test-Path -LiteralPath $aceClosePath -PathType Leaf) -and
    $description -notmatch 'requiredAddons.*ace_|\\z\\ace\\'
)
Assert-Compat "ACE adapter feature-detects local client APIs and falls back to Legacy" (
    $aceOpen -match 'isNil\s+"ace_arsenal_fnc_openBox"' -and
    $aceOpen -match 'isNil\s+"ace_arsenal_fnc_addVirtualItems"' -and
    $aceOpen -match 'finite' -and
    $aceOpen -match '\["Open",\s*\[jna_dataList\]\]\s+call\s+jn_fnc_arsenal'
)
Assert-Compat "ACE uses an A4A-owned client-local proxy with explicit local calls" (
    $aceOpen -match 'createVehicleLocal\s+\["Land_HelipadEmpty_F"' -and
    $aceOpen -match '\[_proxy,\s*_items,\s*false\]\s+call\s+ace_arsenal_fnc_addVirtualItems' -and
    $aceOpen -match '\[_proxy,\s*player,\s*false\]\s+call\s+ace_arsenal_fnc_openBox' -and
    ($aceOpen + $aceClose) -notmatch 'ace_arsenal_fnc_initBox|ace_arsenal_fnc_removeBox'
)
Assert-Compat "ACE proxy state separates original object proxy nonce and generation" (
    $aceOpen -match 'originalObject' -and
    $aceOpen -match 'proxy' -and
    $aceOpen -match 'requestNonce' -and
    $aceOpen -match 'generation'
)
Assert-Compat "ACE ownership checks currentBox and matching client session generation" (
    $aceStock -match 'ace_arsenal_currentBox' -and
    $aceStock -match 'A4A_ClientSession' -and
    $aceStock -match 'generation' -and
    $aceStock -match 'A4A_ClientAceProxyState'
)
Assert-Compat "ACE cleanup is idempotent local next-frame and correlated to requestClose" (
    $aceClose -match '\[_proxy,\s*true,\s*false\]\s+call\s+ace_arsenal_fnc_removeVirtualItems' -and
    $aceClose -match 'CBA_fnc_execNextFrame|uiSleep\s+0' -and
    $aceClose -match 'deleteVehicle\s+_proxy' -and
    $aceClose -match 'A4A_fnc_requestClose' -and
    $aceClose -match 'requestNonce' -and
    $aceClose -match 'generation'
)

$aceMod = "D:/SteamLibrary/steamapps/workshop/content/107410/463939057/mod.cpp"
$acePbo = "D:/SteamLibrary/steamapps/workshop/content/107410/463939057/addons/ace_arsenal.pbo"
if ((Test-Path -LiteralPath $aceMod) -and (Test-Path -LiteralPath $acePbo)) {
    $aceModText = Get-Content -LiteralPath $aceMod -Raw
    Assert-Compat "local ACE3 compatibility target is 3.21.1" ($aceModText -match '3\.21\.1')
    Assert-Compat "local ACE Arsenal PBO is available for API audit" ((Get-Item -LiteralPath $acePbo).Length -gt 0)
} else {
    Write-Host "NOTE: local ACE3 Workshop installation not found; installed-version assertions skipped."
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host "FAIL: $failure" }
    Write-Host ("MISSION DEPENDENCY COMPATIBILITY FAIL: {0}/{1}" -f $failures.Count, ($passes.Count + $failures.Count))
    exit 1
}

Write-Host ("MISSION DEPENDENCY COMPATIBILITY PASS: {0}" -f $passes.Count)
