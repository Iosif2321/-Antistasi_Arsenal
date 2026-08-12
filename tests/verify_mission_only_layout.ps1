$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$missionRelative = "mission/A4A_Arsenal_Mission.VR"
$missionRoot = Join-Path $root $missionRelative
$failures = [System.Collections.Generic.List[string]]::new()
$passes = [System.Collections.Generic.List[string]]::new()

function Assert-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Pass
    )

    if ($Pass) {
        $script:passes.Add($Name)
    } else {
        $script:failures.Add($Name)
    }
}

function Test-SqfLexicalBalance {
    param([Parameter(Mandatory = $true)][string]$Path)

    $text = Get-Content -LiteralPath $Path -Raw
    $stack = [System.Collections.Generic.Stack[char]]::new()
    $pairs = @{ ')' = '('; ']' = '['; '}' = '{' }
    $inString = $false
    $inLineComment = $false
    $inBlockComment = $false

    for ($index = 0; $index -lt $text.Length; $index++) {
        $char = $text[$index]
        $next = if ($index + 1 -lt $text.Length) { $text[$index + 1] } else { [char]0 }

        if ($inLineComment) {
            if ($char -eq "`n") { $inLineComment = $false }
            continue
        }
        if ($inBlockComment) {
            if ($char -eq '*' -and $next -eq '/') {
                $inBlockComment = $false
                $index++
            }
            continue
        }
        if ($inString) {
            if ($char -eq '"') {
                if ($next -eq '"') {
                    $index++
                } else {
                    $inString = $false
                }
            }
            continue
        }

        if ($char -eq '/' -and $next -eq '/') {
            $inLineComment = $true
            $index++
            continue
        }
        if ($char -eq '/' -and $next -eq '*') {
            $inBlockComment = $true
            $index++
            continue
        }
        if ($char -eq '"') {
            $inString = $true
            continue
        }
        if ($char -in @('(', '[', '{')) {
            $stack.Push($char)
            continue
        }
        if ($pairs.ContainsKey([string]$char)) {
            if ($stack.Count -eq 0 -or $stack.Pop() -ne $pairs[[string]$char]) {
                return $false
            }
        }
    }

    return (-not $inString -and -not $inBlockComment -and $stack.Count -eq 0)
}

$requiredFiles = @(
    "description.ext",
    "initServer.sqf",
    "initPlayerLocal.sqf",
    "Stringtable.xml",
    "A4A/config/arsenals.sqf",
    "A4A/config/settings.sqf"
)

Assert-Check "unpacked mission root exists" (Test-Path -LiteralPath $missionRoot -PathType Container)

foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $missionRoot $relativePath
    Assert-Check "mission contains $relativePath" (Test-Path -LiteralPath $fullPath -PathType Leaf)
}

if (Test-Path -LiteralPath $missionRoot -PathType Container) {
    $allFiles = @(Get-ChildItem -LiteralPath $missionRoot -File -Recurse)
    $textFiles = @($allFiles | Where-Object { $_.Extension -in @(".sqf", ".hpp", ".inc", ".ext", ".cpp", ".xml", ".md") })
    $combined = ($textFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

    Assert-Check "mission contains no PBO archive" (@($allFiles | Where-Object { $_.Extension -ieq ".pbo" }).Count -eq 0)
    Assert-Check "mission contains no addon prefix marker" (@($allFiles | Where-Object { $_.Name -eq '$PBOPREFIX$' }).Count -eq 0)
    Assert-Check "mission contains no Garage directory" (@(Get-ChildItem -LiteralPath $missionRoot -Directory -Recurse | Where-Object { $_.Name -ieq "Garage" }).Count -eq 0)
    Assert-Check "mission contains no vehicle Arsenal implementation" (@($allFiles | Where-Object { $_.Name -ieq "fn_vehicleArsenal.sqf" }).Count -eq 0)
    Assert-Check "mission declares no CfgPatches addon" ($combined -notmatch "(?m)\bclass\s+CfgPatches\b")
    Assert-Check "mission has no addon-root absolute path" ($combined -notmatch [regex]::Escape("\A4A_Arsenal\"))
    Assert-Check "mission has no Garage symbols" ($combined -notmatch "(?i)A4A_(?:fnc_)?(?:module)?Garage|A4A_GRG_|fn_vehicleArsenal")

    $descriptionPath = Join-Path $missionRoot "description.ext"
    $functionsPath = Join-Path $missionRoot "A4A/CfgFunctions.hpp"
    $remoteExecPath = Join-Path $missionRoot "A4A/CfgRemoteExec.hpp"
    $description = if (Test-Path -LiteralPath $descriptionPath) { Get-Content -LiteralPath $descriptionPath -Raw } else { "" }
    $functions = if (Test-Path -LiteralPath $functionsPath) { Get-Content -LiteralPath $functionsPath -Raw } else { "" }
    $remoteExec = if (Test-Path -LiteralPath $remoteExecPath) { Get-Content -LiteralPath $remoteExecPath -Raw } else { "" }

    Assert-Check "description includes mission CfgFunctions" ($description -match '#include\s+"A4A\\CfgFunctions\.hpp"')
    Assert-Check "description includes mission CfgRemoteExec" ($description -match '#include\s+"A4A\\CfgRemoteExec\.hpp"')
    Assert-Check "mission CfgFunctions file exists" (Test-Path -LiteralPath $functionsPath -PathType Leaf)
    Assert-Check "mission CfgRemoteExec file exists" (Test-Path -LiteralPath $remoteExecPath -PathType Leaf)
    Assert-Check "function paths are mission relative" ($functions -notmatch '=\s*"\\' -and $functions -notmatch "QPATHTOFOLDER")
    Assert-Check "remote Functions are whitelist only" ($remoteExec -match 'class\s+Functions\s*\{[\s\S]*?mode\s*=\s*1\s*;' -and $remoteExec -match 'class\s+Functions\s*\{[\s\S]*?jip\s*=\s*0\s*;')
    Assert-Check "remote Commands are whitelist only" ($remoteExec -match 'class\s+Commands\s*\{[\s\S]*?mode\s*=\s*1\s*;' -and $remoteExec -match 'class\s+Commands\s*\{[\s\S]*?jip\s*=\s*0\s*;')
    Assert-Check "server RPC endpoints target server" (
        $remoteExec -match 'class\s+A4A_fnc_requestOpen\s*\{\s*allowedTargets\s*=\s*2\s*;' -and
        $remoteExec -match 'class\s+A4A_fnc_requestWithdraw\s*\{\s*allowedTargets\s*=\s*2\s*;' -and
        $remoteExec -match 'class\s+A4A_fnc_requestCargoDeposit\s*\{\s*allowedTargets\s*=\s*2\s*;'
    )
    Assert-Check "interface RPC endpoints support clients and hosted server" (
        $remoteExec -match 'class\s+A4A_fnc_receiveOpen\s*\{\s*allowedTargets\s*=\s*0\s*;' -and
        $remoteExec -match 'class\s+A4A_fnc_receiveGrant\s*\{\s*allowedTargets\s*=\s*0\s*;' -and
        $remoteExec -match 'class\s+A4A_fnc_receiveTransactionResult\s*\{\s*allowedTargets\s*=\s*0\s*;'
    )
    Assert-Check "no arbitrary-code remote function is whitelisted" ($remoteExec -notmatch '(?i)BIS_fnc_(?:spawn|call|execVM)|CBA_fnc_globalExecute|A4A_fnc_.*(?:exec|eval|code)')
    Assert-Check "all A4A RPC classes disable JIP" (-not ($remoteExec -match 'class\s+A4A_fnc_[^{]+\{[^}]*jip\s*=\s*1'))

    $preInitPath = Join-Path $missionRoot "A4A/functions/bootstrap/fn_preInit.sqf"
    $serverInitPath = Join-Path $missionRoot "A4A/functions/bootstrap/fn_serverInit.sqf"
    $clientInitPath = Join-Path $missionRoot "A4A/functions/bootstrap/fn_clientInit.sqf"
    $registerPath = Join-Path $missionRoot "A4A/functions/bootstrap/fn_registerConfiguredArsenals.sqf"
    $preInit = if (Test-Path -LiteralPath $preInitPath) { Get-Content -LiteralPath $preInitPath -Raw } else { "" }
    $serverInit = if (Test-Path -LiteralPath $serverInitPath) { Get-Content -LiteralPath $serverInitPath -Raw } else { "" }
    $clientInit = if (Test-Path -LiteralPath $clientInitPath) { Get-Content -LiteralPath $clientInitPath -Raw } else { "" }
    $register = if (Test-Path -LiteralPath $registerPath) { Get-Content -LiteralPath $registerPath -Raw } else { "" }

    foreach ($bootstrapPath in @($preInitPath, $serverInitPath, $clientInitPath, $registerPath)) {
        Assert-Check ("bootstrap exists: " + (Split-Path -Leaf $bootstrapPath)) (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)
    }

    $serverPrivateNames = @(
        "A4A_ServerRegistry",
        "A4A_ServerData",
        "A4A_ServerRevisions",
        "A4A_ServerReady",
        "A4A_ServerSessions",
        "A4A_ServerTransactions",
        "A4A_ServerCargoLocks",
        "A4A_ServerSettings"
    )
    foreach ($privateName in $serverPrivateNames) {
        Assert-Check "preInit creates private $privateName" ($preInit -match [regex]::Escape("localNamespace setVariable [`"$privateName`""))
    }

    Assert-Check "preInit server state is atomically claimed" ($preInit -match 'isServer[\s\S]*?isNil\s*\{[\s\S]*?A4A_ServerStateInitialized')
    Assert-Check "server init has an atomic one-time claim" ($serverInit -match 'isNil\s*\{[\s\S]*?A4A_ServerInitDone[\s\S]*?_runServerInit\s*=\s*true')
    Assert-Check "client init has an atomic one-time claim" ($clientInit -match 'isNil\s*\{[\s\S]*?A4A_ClientInitDone[\s\S]*?_runClientInit\s*=\s*true')
    Assert-Check "server loads mission-owned arsenal rows" ($register -match 'preprocessFileLineNumbers\s+"A4A\\config\\arsenals\.sqf"')
    Assert-Check "server resolves configured editor variables" ($register -match 'missionNamespace\s+getVariable\s*\[\s*_variableName\s*,\s*objNull\s*\]')
    Assert-Check "server registry stores canonical object id threshold" ($register -match 'A4A_ServerRegistry' -and $register -match '\[\s*_object\s*,\s*_arsenalId\s*,\s*_threshold\s*\]')
    $readyFalseIndex = $register.IndexOf('_ready set [_arsenalId, false]')
    $dataSetIndex = $register.IndexOf('_dataById set [_arsenalId, _data]')
    $readyTrueIndex = $register.IndexOf('_ready set [_arsenalId, true]')
    Assert-Check "registration initializes data before ready" (
        $readyFalseIndex -ge 0 -and
        $dataSetIndex -gt $readyFalseIndex -and
        $readyTrueIndex -gt $dataSetIndex
    )
    Assert-Check "registration rejects direct remote execution" ($register -match 'isRemoteExecuted[\s\S]*?exitWith')
    Assert-Check "client bootstrap installs mission actions" ($clientInit -match 'A4A_fnc_openAction' -and $clientInit -match 'A4A_fnc_addCargoActions')

    $legacyFiles = @(
        "A4A/defineCommon.inc",
        "A4A/Common/defineCommon.inc",
        "A4A/Common/fn_common_addActionSelect.sqf",
        "A4A/Common/fn_common_addActionCancel.sqf",
        "A4A/Common/fn_common_updateActionCancel.sqf",
        "A4A/Common/fn_common_removeActionCancel.sqf",
        "A4A/Common/fn_common_getActionCanceled.sqf",
        "A4A/Common/Array/defineCommon.inc",
        "A4A/Common/Array/fn_common_array_add.sqf",
        "A4A/Common/Array/fn_common_array_remove.sqf",
        "A4A/JNA/defineCommon.inc",
        "A4A/JNA/fn_arsenal.sqf",
        "A4A/JNA/fn_arsenal_aceStock.sqf",
        "A4A/JNA/fn_arsenal_addItem.sqf",
        "A4A/JNA/fn_arsenal_addToArray.sqf",
        "A4A/JNA/fn_arsenal_cargoToArray.sqf",
        "A4A/JNA/fn_arsenal_handleAction.sqf",
        "A4A/JNA/fn_arsenal_inList.sqf",
        "A4A/JNA/fn_arsenal_itemCount.sqf",
        "A4A/JNA/fn_arsenal_itemType.sqf",
        "A4A/JNA/fn_arsenal_loadInventory.sqf",
        "A4A/JNA/fn_arsenal_removeFromArray.sqf",
        "A4A/JNA/fn_arsenal_removeItem.sqf",
        "A4A/pictures/unloadvehicle.paa"
    )
    foreach ($legacyFile in $legacyFiles) {
        Assert-Check "ported quantitative file: $legacyFile" (Test-Path -LiteralPath (Join-Path $missionRoot $legacyFile) -PathType Leaf)
    }

    $forbiddenPortFiles = @(
        "A4A/JNA/fn_arsenal_init.sqf",
        "A4A/JNA/fn_arsenal_requestOpen.sqf",
        "A4A/JNA/fn_arsenal_requestClose.sqf",
        "A4A/JNA/fn_arsenal_cargoToArsenal.sqf",
        "A4A/JNA/fn_vehicleArsenal.sqf",
        "A4A/functions/fn_moduleArsenal.sqf",
        "A4A/functions/fn_moduleGarage.sqf"
    )
    foreach ($forbiddenPortFile in $forbiddenPortFiles) {
        Assert-Check "addon-only file excluded: $forbiddenPortFile" (-not (Test-Path -LiteralPath (Join-Path $missionRoot $forbiddenPortFile)))
    }

    $legacyMainPath = Join-Path $missionRoot "A4A/JNA/fn_arsenal.sqf"
    $legacyMain = if (Test-Path -LiteralPath $legacyMainPath) { Get-Content -LiteralPath $legacyMainPath -Raw } else { "" }
    Assert-Check "Legacy dispatcher retains preload and open modes" ($legacyMain -match 'case\s+"Preload"' -and $legacyMain -match 'case\s+"Open"')
    Assert-Check "Legacy dispatcher retains quantitative item rendering" ($legacyMain -match 'jna_dataList' -and $legacyMain -match 'jn_fnc_arsenal_itemCount')
    Assert-Check "ported scripts do not include addon macro header" ($combined -notmatch 'script_component\.hpp|QPATHTOFOLDER')

    $invalidSqf = @(
        $allFiles |
            Where-Object { $_.Extension -ieq ".sqf" } |
            Where-Object { -not (Test-SqfLexicalBalance -Path $_.FullName) } |
            ForEach-Object { $_.FullName.Substring($missionRoot.Length + 1) }
    )
    Assert-Check ("mission SQF lexical balance" + $(if ($invalidSqf.Count -gt 0) { ": " + ($invalidSqf -join ", ") } else { "" })) ($invalidSqf.Count -eq 0)

    $requestOpenPath = Join-Path $missionRoot "A4A/functions/server/fn_requestOpen.sqf"
    $requestClosePath = Join-Path $missionRoot "A4A/functions/server/fn_requestClose.sqf"
    $receiveOpenPath = Join-Path $missionRoot "A4A/functions/client/fn_receiveOpen.sqf"
    $receiveInvalidatePath = Join-Path $missionRoot "A4A/functions/client/fn_receiveInvalidate.sqf"
    $openActionPath = Join-Path $missionRoot "A4A/functions/client/fn_openAction.sqf"
    $resolvePlayerPath = Join-Path $missionRoot "A4A/functions/shared/fn_resolveRemotePlayer.sqf"
    $validateSessionPath = Join-Path $missionRoot "A4A/functions/shared/fn_validateActiveSession.sqf"
    $publishSnapshotPath = Join-Path $missionRoot "A4A/functions/shared/fn_publishSnapshot.sqf"
    $sessionFiles = @($requestOpenPath, $requestClosePath, $receiveOpenPath, $receiveInvalidatePath, $openActionPath, $resolvePlayerPath, $validateSessionPath, $publishSnapshotPath)
    foreach ($sessionFile in $sessionFiles) {
        Assert-Check ("session protocol exists: " + (Split-Path -Leaf $sessionFile)) (Test-Path -LiteralPath $sessionFile -PathType Leaf)
    }
    $requestOpen = if (Test-Path -LiteralPath $requestOpenPath) { Get-Content -LiteralPath $requestOpenPath -Raw } else { "" }
    $requestClose = if (Test-Path -LiteralPath $requestClosePath) { Get-Content -LiteralPath $requestClosePath -Raw } else { "" }
    $receiveOpen = if (Test-Path -LiteralPath $receiveOpenPath) { Get-Content -LiteralPath $receiveOpenPath -Raw } else { "" }
    $openAction = if (Test-Path -LiteralPath $openActionPath) { Get-Content -LiteralPath $openActionPath -Raw } else { "" }
    $resolvePlayer = if (Test-Path -LiteralPath $resolvePlayerPath) { Get-Content -LiteralPath $resolvePlayerPath -Raw } else { "" }

    Assert-Check "remote player binding filters virtual and empty-UID entities" ($resolvePlayer -match 'remoteExecutedOwner|_senderOwner' -and $resolvePlayer -match 'VirtualMan_F' -and $resolvePlayer -match 'getPlayerUID')
    Assert-Check "open request validates sender registry readiness and distance" (
        $requestOpen -match 'A4A_fnc_resolveRemotePlayer' -and
        $requestOpen -match 'A4A_ServerRegistry' -and
        $requestOpen -match 'A4A_ServerReady' -and
        $requestOpen -match 'distance' -and
        $requestOpen -match 'getPlayerUID'
    )
    Assert-Check "open request stores nonce generation revision session" (
        $requestOpen -match '_requestNonce' -and
        $requestOpen -match 'A4A_ServerSessionGenerations' -and
        $requestOpen -match 'A4A_ServerRevisions' -and
        $requestOpen -match 'A4A_ServerSessions'
    )
    Assert-Check "open response carries correlated object nonce generation revision snapshot" (
        $requestOpen -match 'A4A_fnc_receiveOpen' -and
        $requestOpen -match '\[\s*_object\s*,\s*_requestNonce\s*,\s*_generation\s*,\s*_revision\s*,\s*\+(?:_data|_snapshot)'
    )
    Assert-Check "open action records pending request before server RPC" (
        $openAction -match 'A4A_ClientPendingRequests' -and
        $openAction.IndexOf('_pending set') -ge 0 -and
        $openAction.IndexOf('A4A_fnc_requestOpen') -gt $openAction.IndexOf('_pending set')
    )
    Assert-Check "open receiver accepts only server and matches pending object nonce" (
        $receiveOpen -match 'remoteExecutedOwner\s+(?:isEqualTo|isNotEqualTo)\s+2' -and
        $receiveOpen -match 'A4A_ClientPendingRequests' -and
        $receiveOpen -match '_requestNonce' -and
        $receiveOpen -match 'isEqualTo\s+_object'
    )
    Assert-Check "open receiver binds canonical generation revision snapshot" (
        $receiveOpen -match 'A4A_ClientSession' -and
        $receiveOpen -match '_generation' -and
        $receiveOpen -match '_revision' -and
        $receiveOpen -match 'jna_dataList' -and
        $receiveOpen -match 'count\s+_snapshot\s+isEqualTo\s+27'
    )
    Assert-Check "close request matches object nonce generation before delete" (
        $requestClose -match 'A4A_fnc_validateActiveSession' -and
        $requestClose -match '_requestNonce' -and
        $requestClose -match '_generation' -and
        $requestClose -match 'deleteAt'
    )
    Assert-Check "client installs correlated Legacy close handler" ($clientInit -match 'arsenalClosed' -and $clientInit -match 'A4A_ClientSession' -and $clientInit -match 'A4A_fnc_requestClose')
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host "FAIL: $failure"
    }
    Write-Host ("MISSION LAYOUT FAIL: {0}/{1}" -f $failures.Count, ($passes.Count + $failures.Count))
    exit 1
}

Write-Host ("MISSION LAYOUT PASS: {0}" -f $passes.Count)
