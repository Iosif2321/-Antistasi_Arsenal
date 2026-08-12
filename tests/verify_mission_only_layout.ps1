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
    "A4A/config/settings.sqf",
    "A4A/functions/server/fn_applyUnlockThreshold.sqf",
    "A4A/functions/shared/fn_normalizeSettings.sqf",
    "A4A/functions/shared/fn_objectKey.sqf"
)

Assert-Check "unpacked mission root exists" (Test-Path -LiteralPath $missionRoot -PathType Container)

$attributesPath = Join-Path $root ".gitattributes"
$attributes = if (Test-Path -LiteralPath $attributesPath -PathType Leaf) { Get-Content -LiteralPath $attributesPath -Raw } else { "" }
Assert-Check "Git checkout preserves LF in the unpacked mission artifact" (
    $attributes -match '(?m)^mission/A4A_Arsenal_Mission\.VR/\*\*\s+text\s+eol=lf\s*$'
)

foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $missionRoot $relativePath
    Assert-Check "mission contains $relativePath" (Test-Path -LiteralPath $fullPath -PathType Leaf)
}

if (Test-Path -LiteralPath $missionRoot -PathType Container) {
    $allFiles = @(Get-ChildItem -LiteralPath $missionRoot -File -Recurse)
    $textFiles = @($allFiles | Where-Object { $_.Extension -in @(".sqf", ".hpp", ".inc", ".ext", ".cpp", ".xml", ".md", ".sqm") })
    $combined = ($textFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
    $sqfCombined = (@($allFiles | Where-Object { $_.Extension -ieq ".sqf" }) | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

    $stringtablePath = Join-Path $missionRoot "Stringtable.xml"
    $stringtable = if (Test-Path -LiteralPath $stringtablePath -PathType Leaf) { Get-Content -LiteralPath $stringtablePath -Raw } else { "" }
    $localizableSource = (@($textFiles | Where-Object {
        $_.FullName -ne $stringtablePath -and $_.Extension -in @(".sqf", ".hpp", ".inc", ".ext")
    }) | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
    $usedMissionKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($match in [regex]::Matches($localizableSource, '(?i)["''](?<key>STR_(?:JNA|JNC|A4AP)_[A-Za-z0-9_]+)["'']')) {
        [void]$usedMissionKeys.Add($match.Groups["key"].Value)
    }
    $definedMissionKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($match in [regex]::Matches($stringtable, '(?i)<Key\s+ID="(?<key>STR_(?:JNA|JNC|A4AP)_[A-Za-z0-9_]+)"')) {
        [void]$definedMissionKeys.Add($match.Groups["key"].Value)
    }
    $missingMissionKeys = @($usedMissionKeys | Where-Object { -not $definedMissionKeys.Contains($_) } | Sort-Object)
    Assert-Check ("every mission-local localization key is defined" + $(if ($missingMissionKeys.Count -gt 0) { ": " + ($missingMissionKeys -join ", ") } else { "" })) ($missingMissionKeys.Count -eq 0)
    Assert-Check "runtime artifact contains no Garage or Vehicle Arsenal surface" (
        $localizableSource -notmatch '(?i)\bGarage\b|vehicleArsenal' -and
        $stringtable -notmatch '(?i)Vehicle Arsenal|vehArsenal'
    )

    $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $invalidUtf8 = [System.Collections.Generic.List[string]]::new()
    $corruptNewlines = [System.Collections.Generic.List[string]]::new()
    foreach ($textFile in $textFiles) {
        try {
            $decoded = $strictUtf8.GetString([System.IO.File]::ReadAllBytes($textFile.FullName))
            if ($decoded.Contains([char]0xFFFD) -or $decoded.Contains([char]0)) {
                $invalidUtf8.Add($textFile.FullName.Substring($missionRoot.Length + 1))
            }
            if ($decoded -match "`r`r`n|`r(?!`n)") {
                $corruptNewlines.Add($textFile.FullName.Substring($missionRoot.Length + 1))
            }
        } catch [System.Text.DecoderFallbackException] {
            $invalidUtf8.Add($textFile.FullName.Substring($missionRoot.Length + 1))
        }
    }
    Assert-Check ("mission text is strict UTF-8" + $(if ($invalidUtf8.Count -gt 0) { ": " + ($invalidUtf8 -join ", ") } else { "" })) ($invalidUtf8.Count -eq 0)
    Assert-Check ("mission text contains no bare-CR or CRCRLF corruption" + $(if ($corruptNewlines.Count -gt 0) { ": " + ($corruptNewlines -join ", ") } else { "" })) ($corruptNewlines.Count -eq 0)

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
    Assert-Check "unlock threshold normalizer is registered as a mission function" ($functions -match 'class\s+applyUnlockThreshold\s*\{\s*\};')
    Assert-Check "settings normalizer is registered as a mission function" ($functions -match 'class\s+normalizeSettings\s*\{\s*\};')
    Assert-Check "object key helper is registered as a mission function" ($functions -match 'class\s+objectKey\s*\{\s*\};')
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

    $rpcCalls = @(
        [regex]::Matches($combined, 'remoteExec(?:Call)?\s*\[\s*"(?<name>A4A_fnc_[A-Za-z0-9_]+)"') |
            ForEach-Object { $_.Groups["name"].Value } |
            Sort-Object -Unique
    )
    $rpcWhitelist = @(
        [regex]::Matches($remoteExec, 'class\s+(?<name>A4A_fnc_[A-Za-z0-9_]+)\s*\{') |
            ForEach-Object { $_.Groups["name"].Value } |
            Sort-Object -Unique
    )
    $unlistedRpcCalls = @($rpcCalls | Where-Object { $_ -notin $rpcWhitelist })
    Assert-Check ("every literal mission RPC is explicitly whitelisted" + $(if ($unlistedRpcCalls.Count -gt 0) { ": " + ($unlistedRpcCalls -join ", ") } else { "" })) ($unlistedRpcCalls.Count -eq 0)
    Assert-Check "client-origin server endpoints always enter through unscheduled remoteExecCall" (
        $sqfCombined -notmatch '(?m)\bcall\s+A4A_fnc_(?:requestOpen|requestClose|requestWithdraw|completeWithdraw|requestReturn|completeReturn|saveEditorSnapshot|requestCargoDeposit|requestCargoWithdraw)\b'
    )

    $preInitPath = Join-Path $missionRoot "A4A/functions/bootstrap/fn_preInit.sqf"
    $serverInitPath = Join-Path $missionRoot "A4A/functions/bootstrap/fn_serverInit.sqf"
    $clientInitPath = Join-Path $missionRoot "A4A/functions/bootstrap/fn_clientInit.sqf"
    $registerPath = Join-Path $missionRoot "A4A/functions/bootstrap/fn_registerConfiguredArsenals.sqf"
    $preInit = if (Test-Path -LiteralPath $preInitPath) { Get-Content -LiteralPath $preInitPath -Raw } else { "" }
    $serverInit = if (Test-Path -LiteralPath $serverInitPath) { Get-Content -LiteralPath $serverInitPath -Raw } else { "" }
    $clientInit = if (Test-Path -LiteralPath $clientInitPath) { Get-Content -LiteralPath $clientInitPath -Raw } else { "" }
    $register = if (Test-Path -LiteralPath $registerPath) { Get-Content -LiteralPath $registerPath -Raw } else { "" }
    $unlockThresholdPath = Join-Path $missionRoot "A4A/functions/server/fn_applyUnlockThreshold.sqf"
    $unlockThreshold = if (Test-Path -LiteralPath $unlockThresholdPath) { Get-Content -LiteralPath $unlockThresholdPath -Raw } else { "" }
    $normalizeSettingsPath = Join-Path $missionRoot "A4A/functions/shared/fn_normalizeSettings.sqf"
    $normalizeSettings = if (Test-Path -LiteralPath $normalizeSettingsPath) { Get-Content -LiteralPath $normalizeSettingsPath -Raw } else { "" }
    $objectKeyPath = Join-Path $missionRoot "A4A/functions/shared/fn_objectKey.sqf"
    $objectKey = if (Test-Path -LiteralPath $objectKeyPath) { Get-Content -LiteralPath $objectKeyPath -Raw } else { "" }
    $missionSettings = Get-Content -LiteralPath (Join-Path $missionRoot "A4A/config/settings.sqf") -Raw

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
    Assert-Check "server and client settings are normalized before use" (
        $preInit -match 'A4A_fnc_normalizeSettings' -and
        $preInit.IndexOf('A4A_fnc_normalizeSettings') -lt $preInit.IndexOf('localNamespace setVariable ["A4A_ServerSettings"') -and
        $clientInit -match 'A4A_fnc_normalizeSettings'
    )
    Assert-Check "settings normalizer bounds every authority and resource limit" (
        $normalizeSettings -match 'interactionDistance' -and
        $normalizeSettings -match 'cargoDistance' -and
        $normalizeSettings -match 'sessionLifetime' -and
        $normalizeSettings -match 'transactionLifetime' -and
        $normalizeSettings -match 'maxEntries' -and
        $normalizeSettings -match 'maxCargoEntries' -and
        $normalizeSettings -match 'maxPayloadCharacters' -and
        $normalizeSettings -match 'maxAmount' -and
        $normalizeSettings -match 'editorSteamIDs' -and
        $normalizeSettings -match 'editAccessMode' -and
        $normalizeSettings -match 'finite'
    )
    Assert-Check "server init has an atomic one-time claim" ($serverInit -match 'isNil\s*\{[\s\S]*?A4A_ServerInitDone[\s\S]*?_runServerInit\s*=\s*true')
    Assert-Check "client init has an atomic one-time claim" ($clientInit -match 'isNil\s*\{[\s\S]*?A4A_ClientInitDone[\s\S]*?_runClientInit\s*=\s*true')
    Assert-Check "server loads mission-owned arsenal rows" ($register -match 'preprocessFileLineNumbers\s+"A4A\\config\\arsenals\.sqf"')
    Assert-Check "server resolves configured editor variables" ($register -match 'missionNamespace\s+getVariable\s*\[\s*_variableName\s*,\s*objNull\s*\]')
    Assert-Check "server registry stores canonical object id threshold" ($register -match 'A4A_ServerRegistry' -and $register -match '\[\s*_object\s*,\s*_arsenalId\s*,\s*_threshold\s*\]')
    Assert-Check "object keys preserve SP while requiring network identity in MP" (
        $objectKey -match 'netId\s+_object' -and
        $objectKey -match 'isMultiplayer' -and
        $objectKey -match 'str\s+_object' -and
        $register -match 'A4A_fnc_objectKey' -and
        $register -notmatch 'netId\s+_object'
    )
    $readyFalseIndex = $register.IndexOf('_ready set [_arsenalId, false]')
    $dataSetIndex = $register.IndexOf('_dataById set [_arsenalId, _data]')
    $readyTrueIndex = $register.IndexOf('_ready set [_arsenalId, true]')
    Assert-Check "registration initializes data before ready" (
        $readyFalseIndex -ge 0 -and
        $dataSetIndex -gt $readyFalseIndex -and
        $readyTrueIndex -gt $dataSetIndex
    )
    Assert-Check "registration rejects direct remote execution" ($register -match 'isRemoteExecuted[\s\S]*?exitWith')
    Assert-Check "configured threshold normalizes loaded stock before ready" (
        $register -match 'A4A_fnc_applyUnlockThreshold' -and
        $register.IndexOf('A4A_fnc_applyUnlockThreshold') -lt $readyTrueIndex
    )
    Assert-Check "initial and migrated canonical state is scheduled for durable v2 persistence" (
        $register.IndexOf('localNamespace setVariable ["A4A_ServerReady"') -ge 0 -and
        $register.LastIndexOf('A4A_fnc_schedulePersistence') -gt $register.IndexOf('localNamespace setVariable ["A4A_ServerReady"')
    )
    Assert-Check "unlock threshold converts finite stock to unlimited and preserves magazine round units" (
        $unlockThreshold -match '_threshold\s*>\s*0' -and
        $unlockThreshold -match 'CfgMagazines' -and
        $unlockThreshold -match 'getNumber[\s\S]*?count' -and
        $unlockThreshold -match '_threshold\s*\*\s*_magazineCapacity' -and
        $unlockThreshold -match '\[\s*_className\s*,\s*-1\s*\]'
    )
    Assert-Check "client bootstrap installs mission actions" ($clientInit -match 'A4A_fnc_openAction' -and $clientInit -match 'A4A_fnc_addCargoActions')
    Assert-Check "standalone threshold is not reinterpreted as a hidden member reserve" (
        $preInit -match 'A4A_fnc_isMember\s*=\s*\{\s*true\s*\}' -and
        $clientInit -match 'jna_minItemMember\s+set\s*\[\s*_index\s*,\s*0\s*\]'
    )
    $sessionLifetimeMatch = [regex]::Match($missionSettings, '\["sessionLifetime",\s*(?<seconds>\d+)\]')
    Assert-Check "default active Arsenal session supports normal loadout editing time" (
        $sessionLifetimeMatch.Success -and
        ([int]$sessionLifetimeMatch.Groups["seconds"].Value -ge 300) -and
        $normalizeSettings -match '\["sessionLifetime",\s*\["sessionLifetime",\s*900,'
    )

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
        "A4A/JNA/fn_arsenal_removeItem.sqf"
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
    Assert-Check "Legacy UI dispatcher rejects every remote invocation" (
        $legacyMain -match 'private\s+_a4aIsRemote\s*=\s*isRemoteExecuted' -and
        $legacyMain -match 'if\s*\(\s*_a4aIsRemote\s*\)\s*exitWith'
    )
    Assert-Check "mission contains no legacy direct canonical mutation path" (
        $combined -notmatch 'UpdateItemAdd|UpdateItemRemove|jn_fnc_arsenal_cargoToArsenal|A4A_Arsenal_ServerDispatcherAuthorized|A4A_Arsenal_ServerData|A4A_Arsenal_ServerSessions'
    )
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
    $legacyOpenHandlerPath = Join-Path $missionRoot "A4A/JNA/fn_arsenal_handleAction.sqf"
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
    $legacyOpenHandler = if (Test-Path -LiteralPath $legacyOpenHandlerPath) { Get-Content -LiteralPath $legacyOpenHandlerPath -Raw } else { "" }
    $resolvePlayer = if (Test-Path -LiteralPath $resolvePlayerPath) { Get-Content -LiteralPath $resolvePlayerPath -Raw } else { "" }
    $validateSession = if (Test-Path -LiteralPath $validateSessionPath) { Get-Content -LiteralPath $validateSessionPath -Raw } else { "" }

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
    Assert-Check "open and session refresh share the 900 second fallback" (
        $requestOpen -match 'getOrDefault\s*\["sessionLifetime",\s*900\]' -and
        $validateSession -match 'getOrDefault\s*\["sessionLifetime",\s*900\]'
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
    Assert-Check "client permits only one correlated open request in flight" (
        $openAction -match 'count\s+keys\s+_pending\s*>\s*0[\s\S]*?exitWith' -and
        $openAction.IndexOf('count keys _pending') -lt $openAction.IndexOf('_pending set') -and
        $legacyOpenHandler -match 'count\s+keys\s+_pending\s*>\s*0[\s\S]*?exitWith' -and
        $legacyOpenHandler.IndexOf('count keys _pending') -lt $legacyOpenHandler.IndexOf('_pending set')
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
    Assert-Check "client close waits for active transaction results before dropping the session" (
        $clientInit -match 'A4A_ClientClosePending' -and
        $clientInit -match 'A4A_ClientPendingTransactions' -and
        $clientInit -match '_generationPending' -and
        $clientInit.IndexOf('_generationPending') -lt $clientInit.IndexOf('A4A_fnc_requestClose')
    )
    Assert-Check "server close refuses a session with unfinished transactions" (
        $requestClose -match 'A4A_ServerTransactions' -and
        $requestClose -match '_hasActiveTransaction' -and
        $requestClose.IndexOf('_hasActiveTransaction') -lt $requestClose.IndexOf('_sessions deleteAt')
    )

    $requestWithdrawPath = Join-Path $missionRoot "A4A/functions/server/fn_requestWithdraw.sqf"
    $completeWithdrawPath = Join-Path $missionRoot "A4A/functions/server/fn_completeWithdraw.sqf"
    $requestReturnPath = Join-Path $missionRoot "A4A/functions/server/fn_requestReturn.sqf"
    $completeReturnPath = Join-Path $missionRoot "A4A/functions/server/fn_completeReturn.sqf"
    $expireTransactionsPath = Join-Path $missionRoot "A4A/functions/server/fn_expireTransactions.sqf"
    $refundWithdrawalPath = Join-Path $missionRoot "A4A/functions/server/fn_refundWithdrawalReservation.sqf"
    $receiveGrantPath = Join-Path $missionRoot "A4A/functions/client/fn_receiveGrant.sqf"
    $receiveResultPath = Join-Path $missionRoot "A4A/functions/client/fn_receiveTransactionResult.sqf"
    $transactionFiles = @($requestWithdrawPath, $completeWithdrawPath, $requestReturnPath, $completeReturnPath, $expireTransactionsPath, $refundWithdrawalPath, $receiveGrantPath, $receiveResultPath)
    foreach ($transactionFile in $transactionFiles) {
        Assert-Check ("transaction protocol exists: " + (Split-Path -Leaf $transactionFile)) (Test-Path -LiteralPath $transactionFile -PathType Leaf)
    }
    $requestWithdraw = if (Test-Path -LiteralPath $requestWithdrawPath) { Get-Content -LiteralPath $requestWithdrawPath -Raw } else { "" }
    $completeWithdraw = if (Test-Path -LiteralPath $completeWithdrawPath) { Get-Content -LiteralPath $completeWithdrawPath -Raw } else { "" }
    $requestReturn = if (Test-Path -LiteralPath $requestReturnPath) { Get-Content -LiteralPath $requestReturnPath -Raw } else { "" }
    $completeReturn = if (Test-Path -LiteralPath $completeReturnPath) { Get-Content -LiteralPath $completeReturnPath -Raw } else { "" }
    $expireTransactions = if (Test-Path -LiteralPath $expireTransactionsPath) { Get-Content -LiteralPath $expireTransactionsPath -Raw } else { "" }
    $refundWithdrawal = if (Test-Path -LiteralPath $refundWithdrawalPath) { Get-Content -LiteralPath $refundWithdrawalPath -Raw } else { "" }
    $receiveGrant = if (Test-Path -LiteralPath $receiveGrantPath) { Get-Content -LiteralPath $receiveGrantPath -Raw } else { "" }
    $receiveResult = if (Test-Path -LiteralPath $receiveResultPath) { Get-Content -LiteralPath $receiveResultPath -Raw } else { "" }
    $flushBatchPath = Join-Path $missionRoot "A4A/functions/shared/fn_flushClientBatch.sqf"
    $flushBatch = if (Test-Path -LiteralPath $flushBatchPath) { Get-Content -LiteralPath $flushBatchPath -Raw } else { "" }
    $beginOperationPath = Join-Path $missionRoot "A4A/functions/shared/fn_beginClientOperation.sqf"
    $beginOperation = if (Test-Path -LiteralPath $beginOperationPath) { Get-Content -LiteralPath $beginOperationPath -Raw } else { "" }
    $addItemPath = Join-Path $missionRoot "A4A/JNA/fn_arsenal_addItem.sqf"
    $removeItemPath = Join-Path $missionRoot "A4A/JNA/fn_arsenal_removeItem.sqf"
    $addItem = Get-Content -LiteralPath $addItemPath -Raw
    $removeItem = Get-Content -LiteralPath $removeItemPath -Raw

    Assert-Check "withdraw validates active session revision class and bounded amount" (
        $requestWithdraw -match 'A4A_fnc_validateActiveSession' -and
        $requestWithdraw -match 'A4A_ServerRevisions' -and
        $requestWithdraw -match 'A4A_fnc_itemTypeCached' -and
        $requestWithdraw -match 'finite\s+_amount' -and
        $requestWithdraw -match 'A4A_ServerTransactions'
    )
    $reserveIndex = $requestWithdraw.IndexOf('jn_fnc_arsenal_removeFromArray')
    $storeTransactionIndex = $requestWithdraw.IndexOf('localNamespace setVariable ["A4A_ServerTransactions"', [Math]::Max(0, $reserveIndex))
    $grantIndex = $requestWithdraw.IndexOf('A4A_fnc_receiveGrant', [Math]::Max(0, $storeTransactionIndex))
    Assert-Check "withdraw reserves finite stock before grant" (
        $reserveIndex -ge 0 -and
        $storeTransactionIndex -gt $reserveIndex -and
        $grantIndex -gt $storeTransactionIndex
    )
    Assert-Check "withdraw completion is idempotent and commits revision once" (
        $completeWithdraw -match 'state' -and
        $completeWithdraw -match 'A4A_ServerRevisions' -and
        $completeWithdraw -match 'deleteAt' -and
        $completeWithdraw -match 'A4A_fnc_receiveTransactionResult'
    )
    Assert-Check "return validates before pending commit" ($requestReturn -match 'A4A_fnc_validateActiveSession' -and $requestReturn -match 'A4A_fnc_itemTypeCached' -and $requestReturn -match 'A4A_ServerTransactions' -and $requestReturn -match 'A4A_fnc_receiveGrant')
    Assert-Check "return limits include outstanding finite withdrawal reservations" (
        $requestReturn -match '_reservedAmount' -and
        $requestReturn -match '_reservedMissingClasses' -and
        $requestReturn.IndexOf('_reservedAmount') -lt $requestReturn.IndexOf('_current + _reservedAmount + _amount')
    )
    Assert-Check "return completion commits canonical state and revision" ($completeReturn -match 'jn_fnc_arsenal_addToArray' -and $completeReturn -match 'A4A_ServerData' -and $completeReturn -match 'A4A_ServerRevisions')
    Assert-Check "successful returns apply the configured unlock threshold before canonical validation" (
        $completeReturn -match 'A4A_fnc_applyUnlockThreshold' -and
        $completeReturn.IndexOf('A4A_fnc_applyUnlockThreshold') -gt $completeReturn.IndexOf('jn_fnc_arsenal_addToArray') -and
        $completeReturn.IndexOf('A4A_fnc_applyUnlockThreshold') -lt $completeReturn.IndexOf('A4A_fnc_validateSnapshot')
    )
    Assert-Check "finite withdrawal refunds are revisioned published and persisted" (
        $refundWithdrawal -match 'jn_fnc_arsenal_addToArray' -and
        $refundWithdrawal -match 'A4A_ServerRevisions' -and
        $refundWithdrawal -match 'saveEligibleRevision' -and
        $refundWithdrawal -match 'A4A_fnc_publishSnapshot' -and
        $refundWithdrawal -match 'A4A_fnc_schedulePersistence'
    )
    Assert-Check "finite withdrawal refund atomically claims and retires one transaction" (
        $requestWithdraw -match '\["transactionId",\s*_transactionId\]' -and
        $refundWithdrawal -match '_transactionId' -and
        $refundWithdrawal -match 'A4A_ServerTransactions' -and
        $refundWithdrawal -match 'isNil\s*\{' -and
        $refundWithdrawal -match '\["state",\s*"refunding"\]' -and
        $refundWithdrawal -match 'deleteAt\s+_transactionId'
    )
    Assert-Check "failure timeout and disconnect share the revisioned withdrawal refund" (
        $completeWithdraw -match 'A4A_fnc_refundWithdrawalReservation' -and
        $expireTransactions -match 'A4A_fnc_refundWithdrawalReservation' -and
        $serverInit -match 'A4A_fnc_refundWithdrawalReservation' -and
        $expireTransactions -match 'A4A_fnc_receiveTransactionResult'
    )
    Assert-Check "client grant completes only a known pending transaction" ($receiveGrant -match 'A4A_ClientPendingTransactions' -and $receiveGrant -match '_transactionId' -and $receiveGrant -match 'A4A_fnc_completeWithdraw' -and $receiveGrant -match 'A4A_fnc_completeReturn')
    Assert-Check "client result resyncs authoritative snapshot and supports rollback" ($receiveResult -match 'count\s+_snapshot\s+isEqualTo\s+27' -and $receiveResult -match 'jna_dataList' -and $receiveResult -match '_rollback' -and $receiveResult -match 'setUnitLoadout')
    Assert-Check "legacy wrappers submit correlated transactions" (
        $addItem -match 'A4A_ClientPendingTransactions' -and $addItem -match 'A4A_fnc_flushClientBatch' -and
        $removeItem -match 'A4A_ClientPendingTransactions' -and $removeItem -match 'A4A_fnc_flushClientBatch' -and
        $flushBatch -match 'A4A_fnc_requestReturn' -and $flushBatch -match 'A4A_fnc_requestWithdraw'
    )
    Assert-Check "legacy wrappers cannot call canonical dispatcher" ($addItem -notmatch 'UpdateItemAdd|remoteExecCall\s*\[\s*"jn_fnc_arsenal"' -and $removeItem -notmatch 'UpdateItemRemove|remoteExecCall\s*\[\s*"jn_fnc_arsenal"')
    Assert-Check "Legacy UI records provisional loadout baseline" ($legacyMain -match 'A4A_fnc_beginClientOperation' -and $beginOperation -match 'A4A_ClientOperationBaseline' -and $beginOperation -match 'getUnitLoadout\s+player')
    Assert-Check "physical loadout is deferred until every batch reservation is granted" (
        $flushBatch.IndexOf('_provisionalLoadout = getUnitLoadout player') -ge 0 -and
        $flushBatch.IndexOf('player setUnitLoadout _baseline') -gt $flushBatch.IndexOf('_provisionalLoadout = getUnitLoadout player') -and
        $flushBatch.IndexOf('A4A_fnc_requestWithdraw') -gt $flushBatch.IndexOf('player setUnitLoadout _baseline') -and
        $receiveGrant -match 'findIf[\s\S]*?state[\s\S]*?granted' -and
        $receiveGrant.IndexOf('player setUnitLoadout _provisionalLoadout') -ge 0 -and
        $receiveGrant.IndexOf('true] call _sendCompletion') -gt $receiveGrant.IndexOf('player setUnitLoadout _provisionalLoadout') -and
        $receiveGrant -match 'A4A_fnc_completeWithdraw' -and $receiveGrant -match 'A4A_fnc_completeReturn'
    )
    Assert-Check "legacy dispatcher is not a remote endpoint" ($remoteExec -notmatch 'class\s+jn_fnc_arsenal\b')

    $validateSnapshotPath = Join-Path $missionRoot "A4A/functions/server/fn_validateSnapshot.sqf"
    $loadPersistencePath = Join-Path $missionRoot "A4A/functions/server/fn_loadPersistence.sqf"
    $schedulePersistencePath = Join-Path $missionRoot "A4A/functions/server/fn_schedulePersistence.sqf"
    $saveEditorPath = Join-Path $missionRoot "A4A/functions/server/fn_saveEditorSnapshot.sqf"
    $canEditPath = Join-Path $missionRoot "A4A/functions/shared/fn_canEdit.sqf"
    $persistenceFiles = @($validateSnapshotPath, $loadPersistencePath, $schedulePersistencePath, $saveEditorPath, $canEditPath, $unlockThresholdPath)
    foreach ($persistenceFile in $persistenceFiles) {
        Assert-Check ("persistence protocol exists: " + (Split-Path -Leaf $persistenceFile)) (Test-Path -LiteralPath $persistenceFile -PathType Leaf)
    }
    $validateSnapshot = if (Test-Path -LiteralPath $validateSnapshotPath) { Get-Content -LiteralPath $validateSnapshotPath -Raw } else { "" }
    $loadPersistence = if (Test-Path -LiteralPath $loadPersistencePath) { Get-Content -LiteralPath $loadPersistencePath -Raw } else { "" }
    $schedulePersistence = if (Test-Path -LiteralPath $schedulePersistencePath) { Get-Content -LiteralPath $schedulePersistencePath -Raw } else { "" }
    $saveEditor = if (Test-Path -LiteralPath $saveEditorPath) { Get-Content -LiteralPath $saveEditorPath -Raw } else { "" }
    $canEdit = if (Test-Path -LiteralPath $canEditPath) { Get-Content -LiteralPath $canEditPath -Raw } else { "" }

    Assert-Check "snapshot validator enforces 27 canonical buckets" ($validateSnapshot -match 'count\s+_candidate\s+isNotEqualTo\s+27' -and $validateSnapshot -match 'A4A_fnc_itemTypeCached' -and $validateSnapshot -match '_derivedIndex\s+isNotEqualTo\s+_bucketIndex')
    Assert-Check "snapshot validator enforces global unique bounded known rows" (
        $validateSnapshot -match 'createHashMap' -and
        $validateSnapshot -match 'toLower\s+_className' -and
        $validateSnapshot -match 'finite\s+_amount' -and
        $validateSnapshot -match '_amount\s+(?:isEqualTo|isNotEqualTo)\s+-1' -and
        $validateSnapshot -match '_maxEntries' -and
        $validateSnapshot -match '_maxPayloadCharacters' -and
        $validateSnapshot -match 'count\s+str\s+_candidate' -and
        $validateSnapshot -match '_maxAmount'
    )
    Assert-Check "persistence uses versioned envelope and validates legacy data" ($loadPersistence -match 'A4A_MissionArsenal_v2_' -and $loadPersistence -match 'A4A_ArsenalData_' -and $loadPersistence -match 'A4A_fnc_validateSnapshot' -and $loadPersistence -match '\[\s*2\s*,\s*_revision\s*,')
    Assert-Check "profile save is generation-safe and debounced" ($schedulePersistence -match 'A4A_ServerSaveGeneration' -and $schedulePersistence -match 'uiSleep\s+0\.25' -and $schedulePersistence -match 'saveProfileNamespace' -and $schedulePersistence -match 'A4A_fnc_validateSnapshot')
    Assert-Check "editor authorization uses private server settings" ($canEdit -match 'A4A_ServerSettings' -and $canEdit -match 'editorSteamIDs' -and $canEdit -match 'getPlayerUID')
    Assert-Check "editor save binds sender session revision validator and rate limit" (
        $saveEditor -match 'A4A_fnc_validateActiveSession' -and
        $saveEditor -match 'A4A_fnc_canEdit' -and
        $saveEditor -match 'A4A_ServerRevisions' -and
        $saveEditor -match 'saveEligibleRevision' -and
        $saveEditor -match 'A4A_fnc_validateSnapshot' -and
        $saveEditor -match 'A4A_ServerSaveRateLimit'
    )
    Assert-Check "editor save commits revision and broadcasts canonical replacement" ($saveEditor -match 'A4A_ServerData' -and $saveEditor -match 'A4A_fnc_publishSnapshot' -and $saveEditor -match 'A4A_fnc_schedulePersistence')
    Assert-Check "editor save applies the canonical unlock threshold before commit" (
        $saveEditor -match 'A4A_fnc_applyUnlockThreshold' -and
        $saveEditor.IndexOf('A4A_fnc_applyUnlockThreshold') -lt $saveEditor.IndexOf('_dataById set')
    )
    Assert-Check "Legacy editor calls mission-native revisioned endpoint" ($legacyMain -match 'A4A_fnc_saveEditorSnapshot' -and $legacyMain -match 'A4A_fnc_canEdit' -and $legacyMain -notmatch 'A4A_fnc_arsenal_saveRequest|A4A_fnc_arsenal_canEdit')

    $snapshotCargoPath = Join-Path $missionRoot "A4A/functions/cargo/fn_snapshotCargo.sqf"
    $restoreCargoPath = Join-Path $missionRoot "A4A/functions/cargo/fn_restoreCargo.sqf"
    $cargoDepositPath = Join-Path $missionRoot "A4A/functions/cargo/fn_requestCargoDeposit.sqf"
    $cargoWithdrawPath = Join-Path $missionRoot "A4A/functions/cargo/fn_requestCargoWithdraw.sqf"
    $cargoActionsPath = Join-Path $missionRoot "A4A/functions/client/fn_addCargoActions.sqf"
    $cargoResultPath = Join-Path $missionRoot "A4A/functions/client/fn_receiveCargoResult.sqf"
    $cargoValidationPath = Join-Path $missionRoot "A4A/functions/shared/fn_validateCargoRequest.sqf"
    $cargoFiles = @($snapshotCargoPath, $restoreCargoPath, $cargoDepositPath, $cargoWithdrawPath, $cargoActionsPath, $cargoResultPath, $cargoValidationPath)
    foreach ($cargoFile in $cargoFiles) {
        Assert-Check ("cargo transaction exists: " + (Split-Path -Leaf $cargoFile)) (Test-Path -LiteralPath $cargoFile -PathType Leaf)
    }
    $snapshotCargo = if (Test-Path -LiteralPath $snapshotCargoPath) { Get-Content -LiteralPath $snapshotCargoPath -Raw } else { "" }
    $restoreCargo = if (Test-Path -LiteralPath $restoreCargoPath) { Get-Content -LiteralPath $restoreCargoPath -Raw } else { "" }
    $cargoDeposit = if (Test-Path -LiteralPath $cargoDepositPath) { Get-Content -LiteralPath $cargoDepositPath -Raw } else { "" }
    $cargoWithdraw = if (Test-Path -LiteralPath $cargoWithdrawPath) { Get-Content -LiteralPath $cargoWithdrawPath -Raw } else { "" }
    $cargoActions = if (Test-Path -LiteralPath $cargoActionsPath) { Get-Content -LiteralPath $cargoActionsPath -Raw } else { "" }
    $cargoValidation = if (Test-Path -LiteralPath $cargoValidationPath) { Get-Content -LiteralPath $cargoValidationPath -Raw } else { "" }

    Assert-Check "cargo backup recursively preserves exact physical tuples" ($snapshotCargo -match 'getItemCargo' -and $snapshotCargo -match 'magazinesAmmoCargo' -and $snapshotCargo -match 'weaponsItemsCargo' -and $snapshotCargo -match 'everyContainer')
    Assert-Check "cargo backup records container shells once and contents recursively" (
        $snapshotCargo -match '_subcontainers' -and
        $snapshotCargo -match '_itemCounts' -and
        $snapshotCargo -match '_itemCounts\s+set\s*\[' -and
        $snapshotCargo -match 'A4A_fnc_snapshotCargo'
    )
    Assert-Check "cargo restore preserves attachments loaded rounds and all nested container types" (
        $restoreCargo -match 'addWeaponWithAttachmentsCargoGlobal' -and
        $restoreCargo -match 'addMagazineAmmoCargo' -and
        $restoreCargo -match 'addBackpackCargoGlobal' -and
        $restoreCargo -match 'addItemCargoGlobal' -and
        $restoreCargo -match 'A4A_fnc_itemTypeCached' -and
        $restoreCargo -match 'A4A_fnc_restoreCargo'
    )
    Assert-Check "cargo authority binds sender registry distance holder type and locality" (
        $cargoValidation -match 'A4A_fnc_resolveRemotePlayer' -and
        $cargoValidation -match 'A4A_ServerRegistry' -and
        $cargoValidation -match 'A4A_ServerReady' -and
        $cargoValidation -match '_holder\s+isEqualTo\s+_arsenalObject' -and
        $cargoValidation -match 'isKindOf\s+"Man"' -and
        $cargoValidation -match 'distance' -and
        $cargoValidation -match 'setOwner\s+2'
    )
    Assert-Check "cargo deposit acquires private holder lock" (
        $cargoDeposit -match 'A4A_ServerCargoLocks' -and
        $cargoValidation -match '\[_holder\]\s+call\s+A4A_fnc_objectKey'
    )
    Assert-Check "cargo locks expire safely after an interrupted script" (
        $cargoDeposit -match '_lockExpiresAt' -and $cargoDeposit -match '_existingLockUntil' -and $cargoDeposit -match 'diag_tickTime' -and
        $cargoWithdraw -match '_lockExpiresAt' -and $cargoWithdraw -match '_existingLockUntil' -and $cargoWithdraw -match 'diag_tickTime'
    )
    $depositValidateIndex = $cargoDeposit.IndexOf('A4A_fnc_validateSnapshot')
    $depositClearIndex = $cargoDeposit.IndexOf('clearMagazineCargoGlobal')
    $depositCommitIndex = $cargoDeposit.IndexOf('localNamespace setVariable ["A4A_ServerData"')
    Assert-Check "cargo deposit validates before destructive clear and canonical commit" ($depositValidateIndex -ge 0 -and $depositClearIndex -gt $depositValidateIndex -and $depositCommitIndex -gt $depositClearIndex)
    Assert-Check "cargo deposit applies the canonical unlock threshold before validation and clear" (
        $cargoDeposit -match 'A4A_fnc_applyUnlockThreshold' -and
        $cargoDeposit.IndexOf('A4A_fnc_applyUnlockThreshold') -lt $depositValidateIndex -and
        $cargoDeposit.IndexOf('A4A_fnc_applyUnlockThreshold') -lt $depositClearIndex
    )
    Assert-Check "cargo deposit has recoverable rollback and finally lock release" ($cargoDeposit -match 'A4A_fnc_snapshotCargo' -and $cargoDeposit -match 'A4A_fnc_restoreCargo' -and $cargoDeposit.LastIndexOf('deleteAt _holderKey') -gt $depositCommitIndex)
    Assert-Check "cargo deposit preserves capacity for every finite withdrawal refund" (
        $cargoDeposit -match 'A4A_ServerTransactions' -and
        $cargoDeposit -match '_refundCandidate' -and
        $cargoDeposit -match 'withdraw' -and
        $cargoDeposit -match 'unlimited' -and
        $cargoDeposit -match 'A4A_fnc_validateSnapshot'
    )
    Assert-Check "cargo withdraw validates manifest and stock before physical mutation" ($cargoWithdraw -match 'A4A_fnc_validateSnapshot' -and $cargoWithdraw -match 'jn_fnc_arsenal_itemCount' -and $cargoWithdraw.IndexOf('A4A_fnc_validateSnapshot') -lt $cargoWithdraw.IndexOf('addMagazineAmmoCargo'))
    Assert-Check "cargo withdraw verifies engine load capacity and restores exact backup on partial add" (
        $cargoWithdraw -match 'A4A_fnc_snapshotCargo' -and
        $cargoWithdraw -match 'A4A_fnc_restoreCargo' -and
        $cargoWithdraw -match '_physicalDeltaValid' -and
        $cargoWithdraw -match 'load\s+_holder\s*<='
    )
    Assert-Check "cargo withdraw rejects any unexpected physical delta" (
        $cargoWithdraw -match '_expectedPhysicalCargo' -and
        $cargoWithdraw -match '_expectedAmount' -and
        $cargoWithdraw -match '_actualAmount' -and
        $cargoWithdraw -match '_afterAmount' -and
        $cargoWithdraw -match '_expectedPhysicalCargo\s+select\s+_index'
    )
    Assert-Check "cargo commits use one revision and one snapshot notification" ($cargoDeposit -match 'A4A_ServerRevisions' -and $cargoDeposit -match 'A4A_fnc_publishSnapshot' -and $cargoDeposit -match 'A4A_fnc_schedulePersistence' -and $cargoWithdraw -match 'A4A_ServerRevisions' -and $cargoWithdraw -match 'A4A_fnc_publishSnapshot')
    Assert-Check "cargo actions treat cursor crate or vehicle as one generic holder" ($cargoActions -match 'cursorObject' -and $cargoActions -match 'A4A_fnc_requestCargoDeposit' -and $cargoActions -match 'A4A_fnc_requestCargoWithdraw' -and $cargoActions -match 'jn_fnc_arsenal_cargoToArray' -and $cargoActions -notmatch 'Garage|vehicleArsenal')
    Assert-Check "cargo code has no per-item network fanout" ($cargoDeposit -notmatch 'UpdateItemAdd|UpdateItemRemove' -and $cargoWithdraw -notmatch 'UpdateItemAdd|UpdateItemRemove')

    $missionSqmPath = Join-Path $missionRoot "mission.sqm"
    $readmePath = Join-Path $missionRoot "README_MISSION_RU.md"
    $compatibilityPath = Join-Path $missionRoot "COMPATIBILITY.md"
    $verificationPath = Join-Path $missionRoot "VERIFICATION.md"
    foreach ($artifactPath in @($missionSqmPath, $readmePath, $compatibilityPath, $verificationPath)) {
        Assert-Check ("deployable mission artifact exists: " + (Split-Path -Leaf $artifactPath)) (Test-Path -LiteralPath $artifactPath -PathType Leaf)
    }
    $missionSqm = if (Test-Path -LiteralPath $missionSqmPath) { Get-Content -LiteralPath $missionSqmPath -Raw } else { "" }
    $readme = if (Test-Path -LiteralPath $readmePath) { Get-Content -LiteralPath $readmePath -Raw } else { "" }
    $compatibility = if (Test-Path -LiteralPath $compatibilityPath) { Get-Content -LiteralPath $compatibilityPath -Raw } else { "" }
    $verification = if (Test-Path -LiteralPath $verificationPath) { Get-Content -LiteralPath $verificationPath -Raw } else { "" }
    Assert-Check "VR scenario has two vanilla slots for hosted and two-client checks" (
        ([regex]::Matches($missionSqm, 'type\s*=\s*"B_Soldier_F"')).Count -ge 2 -and
        $missionSqm -match 'isPlayer\s*=\s*1' -and
        $missionSqm -match 'isPlayable\s*=\s*1'
    )
    Assert-Check "VR scenario has the configured named vanilla arsenal crate" ($missionSqm -match 'type\s*=\s*"B_supplyCrate_F"' -and $missionSqm -match 'name\s*=\s*"a4a_arsenal_base"')
    Assert-Check "mission.sqm has no A4A CBA ACE or Garage addon dependency" ($missionSqm -notmatch 'requiredAddons|CfgPatches|type\s*=\s*"(?:A4A|Antistasi|cba_|ace_|Garage|vehicleArsenal)' -and $missionSqm -match 'addons\[\]\s*=\s*\{\s*"A3_Characters_F_BLUFOR"\s*,\s*"A3_Weapons_F_Ammoboxes"\s*\}')
    Assert-Check "Russian guide explains unpacked MPMissions deployment and scenario configuration" ($readme -match 'MPMissions' -and $readme -match 'NO_PBO|UNPACKED_MISSION' -and $readme -match 'A4A\\config\\arsenals\.sqf' -and $readme -match 'a4a_arsenal_base')
    Assert-Check "Russian guide limits vehicles to physical cargo holders and excludes Garage" ($readme -match 'Garage' -and $readme -match 'CARGO_ONLY' -and $readme -match 'NO_VEHICLE_STORAGE_OR_SPAWN')
    Assert-Check "operator guide documents persistence backup and reset" ($readme -match 'A4A_MissionArsenal_v2_' -and $readme -match 'profileNamespace' -and $readme -match 'PERSISTENCE_BACKUP' -and $readme -match 'PERSISTENCE_RESET')
    Assert-Check "compatibility matrix names installed CBA and ACE targets and optional fallbacks" ($compatibility -match 'CBA_A3\s+3\.19\.0' -and $compatibility -match 'ACE3\s+3\.21\.1' -and $compatibility -match 'NO_CBA' -and $compatibility -match 'NO_ACE' -and $compatibility -match 'Legacy')
    Assert-Check "verification distinguishes static proof from all required runtime gates" ($verification -match 'PASS' -and $verification -match 'NOT_RUN' -and $verification -match 'dedicated' -and $verification -match 'hosted' -and $verification -match 'JIP' -and $verification -match 'restart' -and $verification -match 'two-client' -and $verification -match 'cargo rollback' -and $verification -match 'performance')
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host "FAIL: $failure"
    }
    Write-Host ("MISSION LAYOUT FAIL: {0}/{1}" -f $failures.Count, ($passes.Count + $failures.Count))
    exit 1
}

Write-Host ("MISSION LAYOUT PASS: {0}" -f $passes.Count)
