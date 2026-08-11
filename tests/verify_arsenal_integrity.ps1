$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)

function Read-ProjectFile {
    param([string]$RelativePath)
    $path = Join-Path $root $RelativePath
    [System.IO.File]::ReadAllText($path, $strictUtf8)
}

function Add-Check {
    param(
        [string]$Name,
        [bool]$Pass
    )
    $script:checks += @{ Name = $Name; Pass = $Pass }
}

function Get-SourceSection {
    param(
        [string]$Text,
        [string]$StartPattern,
        [string]$EndPattern
    )

    $match = [regex]::Match(
        $Text,
        "(?ms)$StartPattern(?<Body>.*?)$EndPattern"
    )
    if (-not $match.Success) { return "" }
    $match.Groups["Body"].Value
}

function Get-BracedBodyAfterPattern {
    param(
        [string]$Text,
        [string]$Pattern
    )

    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase `
        -bor [System.Text.RegularExpressions.RegexOptions]::Multiline
    $match = [regex]::Match($Text, $Pattern, $options)
    if (-not $match.Success) { return "" }

    $openBrace = $Text.IndexOf('{', $match.Index + $match.Length)
    if ($openBrace -lt 0) { return "" }

    $depth = 1
    $inString = $false
    $inLineComment = $false
    $inBlockComment = $false
    for ($index = $openBrace + 1; $index -lt $Text.Length; $index++) {
        $char = $Text[$index]
        $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }

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
        if ($char -eq '{') {
            $depth++
            continue
        }
        if ($char -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $Text.Substring($openBrace + 1, $index - $openBrace - 1)
            }
        }
    }

    ""
}

function Get-BracedBodyContainingPattern {
    param(
        [string]$Text,
        [string]$OpenPattern,
        [string]$RequiredPattern
    )

    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase `
        -bor [System.Text.RegularExpressions.RegexOptions]::Multiline
    foreach ($match in [regex]::Matches($Text, $OpenPattern, $options)) {
        $slice = $Text.Substring($match.Index)
        $body = Get-BracedBodyAfterPattern $slice '\A\s*isNil\s*'
        if ($body -ne "" -and $body -match $RequiredPattern) { return $body }
    }
    ""
}

function Test-PatternsInOrder {
    param(
        [string]$Text,
        [string[]]$Patterns
    )

    if ($Text -eq "") { return $false }

    $offset = 0
    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase `
        -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
    foreach ($pattern in $Patterns) {
        $remaining = $Text.Substring($offset)
        $match = [regex]::Match($remaining, $pattern, $options)
        if (-not $match.Success) { return $false }
        $offset += $match.Index + $match.Length
    }
    $true
}

function Test-FirstPatternBefore {
    param(
        [string]$Text,
        [string]$BeforePattern,
        [string]$AfterPattern
    )

    if ($Text -eq "") { return $false }
    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase `
        -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
    $before = [regex]::Match($Text, $BeforePattern, $options)
    $after = [regex]::Match($Text, $AfterPattern, $options)
    $before.Success -and $after.Success -and $before.Index -lt $after.Index
}

$config = Read-ProjectFile "source/A4A_Arsenal/config.cpp"
$stub = Read-ProjectFile "source/A4A_Arsenal/functions/fn_A4A_stub.sqf"
$inputHandler = Read-ProjectFile "source/A4A_Arsenal/functions/fn_inputHandler.sqf"
$assignZeus = Read-ProjectFile "source/A4A_Arsenal/functions/fn_assignZeus.sqf"
$isZeus = Read-ProjectFile "source/A4A_Arsenal/functions/fn_arsenal_isZeus.sqf"
$arsenalLogic = Read-ProjectFile "source/A4A_Arsenal/functions/fn_arsenalLogic.sqf"
$arsenalInit = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_init.sqf"
$handleAction = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_handleAction.sqf"
$bootstrap = Read-ProjectFile "source/A4A_Arsenal/functions/fn_arsenalInit.sqf"
$moduleArsenal = Read-ProjectFile "source/A4A_Arsenal/functions/fn_moduleArsenal.sqf"
$arsenal = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal.sqf"
$addItem = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_addItem.sqf"
$removeItem = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_removeItem.sqf"
$cargoToArsenal = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_cargoToArsenal.sqf"
$cargoToArray = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_cargoToArray.sqf"
$itemType = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_itemType.sqf"
$vehicleArsenal = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_vehicleArsenal.sqf"
$aceStock = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_aceStock.sqf"
$requestOpen = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_requestOpen.sqf"
$requestClose = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_requestClose.sqf"
$garage = Read-ProjectFile "source/A4A_Arsenal/Garage/fn_garage.sqf"
$garageInit = Read-ProjectFile "source/A4A_Arsenal/Garage/fn_garageInit.sqf"
$moduleGarage = Read-ProjectFile "source/A4A_Arsenal/Garage/fn_moduleGarage.sqf"
$saveRequestPath = Join-Path $root "source/A4A_Arsenal/functions/fn_arsenal_saveRequest.sqf"
$profileSavePath = Join-Path $root "source/A4A_Arsenal/functions/fn_arsenal_scheduleProfileSave.sqf"
$saveRequest = if (Test-Path -LiteralPath $saveRequestPath) {
    [System.IO.File]::ReadAllText($saveRequestPath, $strictUtf8)
} else { "" }
$profileSave = if (Test-Path -LiteralPath $profileSavePath) {
    [System.IO.File]::ReadAllText($profileSavePath, $strictUtf8)
} else { "" }

$updateItemAdd = Get-SourceSection $arsenal `
    '^\s*case\s+"UpdateItemAdd"\s*:\s*\{' `
    '^\s*case\s+"UpdateItemRemove"\s*:'
$updateItemRemove = Get-SourceSection $arsenal `
    '^\s*case\s+"UpdateItemRemove"\s*:\s*\{' `
    '^\s*case\s+"UpdateItemGui"\s*:'
$openAce = Get-SourceSection $arsenal `
    '^\s*case\s+"OpenACE"\s*:\s*\{' `
    '^\s*case\s+"CustomControls"\s*:'
$aceActiveOverlap = Get-BracedBodyAfterPattern $openAce `
    'if\s*\(\s*_a4aAceActive\s*\)\s*exitWith'
$aceDuplicateSameObject = Get-BracedBodyAfterPattern $aceActiveOverlap `
    'if\s*\(\s*_activeArsenalObj\s+isEqualTo\s+_arsenalObj\s*\)\s*then'
$aceCrossObjectOverlap = Get-BracedBodyAfterPattern $aceActiveOverlap `
    '\}\s*else'
$aceForeignReject = Get-BracedBodyAfterPattern $openAce `
    'if\s*\(\s*!isNull\s+_existingAceDisplay\s*\)\s*exitWith'
$aceForeignRejectExecutable = [regex]::Replace(
    $aceForeignReject,
    '(?m)^\s*//[^\r\n]*(?:\r?\n|$)',
    ''
)
$aceWatchdogSpawn = Get-BracedBodyAfterPattern $openAce `
    '\[\s*_aceProxy\s*\]\s+spawn'
$importData = Get-SourceSection $arsenal `
    '^\s*case\s+"ImportData"\s*:\s*\{' `
    '^\s*case\s+"EditorOpen"\s*:'
$editorSave = Get-SourceSection $arsenal `
    '^\s*case\s+"EditorSave"\s*:\s*\{' `
    '^\s*default\s*\{'
$aceEndSession = Get-SourceSection $aceStock `
    '^\s*A4A_fnc_arsenal_aceEndSession\s*=\s*\{' `
    '^\s*A4A_fnc_arsenal_aceRegisterHandlers\s*='
$aceSyncVirtualItems = Get-SourceSection $aceStock `
    '^\s*A4A_fnc_arsenal_aceSyncVirtualItems\s*=\s*\{' `
    '^\s*A4A_fnc_arsenal_aceRelocateRadios\s*='
$aceBeginSession = Get-SourceSection $aceStock `
    '^\s*A4A_fnc_arsenal_aceBeginSession\s*=\s*\{' `
    '^\s*A4A_fnc_arsenal_aceEndSession\s*='
$aceOwnsCurrentBox = Get-SourceSection $aceStock `
    '^\s*A4A_fnc_arsenal_aceOwnsCurrentBox\s*=\s*\{' `
    '^\s*A4A_fnc_arsenal_aceScheduleStockRefresh\s*='
$aceScheduleStockRefresh = Get-SourceSection $aceStock `
    '^\s*A4A_fnc_arsenal_aceScheduleStockRefresh\s*=\s*\{' `
    '^\s*A4A_fnc_arsenal_aceOnDataListUpdate\s*='
$aceRefreshSpawn = Get-BracedBodyAfterPattern $aceScheduleStockRefresh `
    '\[\s*_display\s*,\s*_fullRefresh\s*,\s*_expectedBox\s*\]\s+spawn'
$aceGetStep = Get-SourceSection $aceStock `
    '^\s*A4A_fnc_arsenal_aceGetStep\s*=\s*\{' `
    '^\s*A4A_fnc_arsenal_aceItemConfig\s*='
$aceGetStepExecutable = [regex]::Replace(
    $aceGetStep,
    '(?m)^\s*//[^\r\n]*(?:\r?\n|$)',
    ''
)
$aceAttachKeyHandlers = Get-SourceSection $aceStock `
    '^\s*A4A_fnc_arsenal_aceAttachKeyHandlers\s*=\s*\{' `
    '^\s*A4A_fnc_arsenal_aceBeginSession\s*='
$aceAttachKeyHandlersExecutable = [regex]::Replace(
    $aceAttachKeyHandlers,
    '(?m)^\s*//[^\r\n]*(?:\r?\n|$)',
    ''
)
$editorIdsSetting = Get-SourceSection $stub `
    '^\s*\[\s*\r?\n\s*"A4A_Arsenal_EditorSteamIDs"\s*,' `
    '^\s*\]\s+call\s+CBA_fnc_addSetting\s*;'
$editAccessSetting = Get-SourceSection $stub `
    '^\s*\[\s*\r?\n\s*"A4A_Arsenal_EditAccessMode"\s*,' `
    '^\s*\]\s+call\s+CBA_fnc_addSetting\s*;'
$unlockThresholdSetting = Get-SourceSection $stub `
    '^\s*\[\s*\r?\n\s*"A4A_Arsenal_UnlockThreshold"\s*,' `
    '^\s*\]\s+call\s+CBA_fnc_addSetting\s*;'
$garageAddVehicle = Get-SourceSection $garage `
    '^\s*case\s+"addvehicle"\s*:\s*\{' `
    '^\s*case\s+"removevehicle"\s*:'
$cargoButton = Get-SourceSection $arsenal `
    '^\s*case\s+"buttonInvToJNA"\s*:\s*\{' `
    '^\s*case\s+"showMessage"\s*:'
$minItemsMember = Get-SourceSection $arsenal `
    '^\s*private\s+_minItemsMember\s*=\s*\{' `
    '^\s*private\s+_arrayAdd\s*=\s*\{'
$serverInvalidate = Get-SourceSection $arsenal `
    '^\s*case\s+"ServerInvalidate"\s*:\s*\{' `
    '^\s*case\s+"ServerNotify"\s*:'
$serverInitClaim = Get-BracedBodyContainingPattern $arsenalInit `
    '\bisNil\s*(?=\{)' `
    'A4A_Arsenal_ServerInitObjects'
$clientInitClaim = Get-BracedBodyContainingPattern $arsenalInit `
    '\bisNil\s*(?=\{)' `
    'A4A_Arsenal_ClientInitObjects'
$commonInitClaim = Get-BracedBodyContainingPattern $arsenalInit `
    '\bisNil\s*(?=\{)' `
    'A4A_Arsenal_CommonInitDone'
$remoteExecCheckClaim = Get-BracedBodyContainingPattern $arsenalInit `
    '\bisNil\s*(?=\{)' `
    'A4A_Arsenal_RemoteExecCheckDone'
$zeusSyncClaim = Get-BracedBodyContainingPattern $arsenalInit `
    '\bisNil\s*(?=\{)' `
    'A4A_Arsenal_ZeusSyncStarted'
$canonicalServerInit = Get-BracedBodyAfterPattern $arsenalInit `
    '^\s*if\s*\(\s*isServer\s*\)\s*then'
$cfgRemoteExec = Get-BracedBodyAfterPattern $config `
    '^\s*class\s+CfgRemoteExec\s*'
$remoteExecFunctions = Get-BracedBodyAfterPattern $cfgRemoteExec `
    '^\s*class\s+Functions\s*'
$remoteExecCommands = Get-BracedBodyAfterPattern $cfgRemoteExec `
    '^\s*class\s+Commands\s*'
$expectedRemoteFunctions = [ordered]@{
    'A4A_fnc_arsenalInit' = 0
    'jn_fnc_arsenal_init' = 0
    'jn_fnc_arsenal' = 0
    'jn_fnc_arsenal_requestOpen' = 2
    'jn_fnc_arsenal_requestClose' = 2
    'jn_fnc_arsenal_cargoToArsenal' = 2
    'A4A_fnc_assignZeus' = 2
    'A4A_fnc_arsenal_saveRequest' = 2
    'A4A_fnc_garageInit' = 0
    'A4A_fnc_garage' = 2
}
$declaredRemoteFunctionNames = @(
    [regex]::Matches($remoteExecFunctions, '(?m)^\s*class\s+(?<Name>[A-Za-z_][A-Za-z0-9_]*)\s*\{') |
        ForEach-Object { $_.Groups['Name'].Value }
)
$remoteFunctionWhitelistValid = $declaredRemoteFunctionNames.Count -eq $expectedRemoteFunctions.Count
$remoteFunctionJipValid = $true
$jipBootstrapFunctions = @('A4A_fnc_arsenalInit', 'jn_fnc_arsenal_init', 'A4A_fnc_garageInit')
foreach ($entry in $expectedRemoteFunctions.GetEnumerator()) {
    $name = [regex]::Escape([string]$entry.Key)
    $target = [string]$entry.Value
    $matches = [regex]::Matches(
        $remoteExecFunctions,
        "(?ms)^\s*class\s+$name\s*\{(?:(?!^\s*class\s).)*?allowedTargets\s*=\s*$target\s*;(?:(?!^\s*class\s).)*?\}\s*;"
    )
    if ($matches.Count -ne 1) { $remoteFunctionWhitelistValid = $false }

    $classBody = Get-BracedBodyAfterPattern $remoteExecFunctions "(?m)^\s*class\s+$name\s*(?=\{)"
    $hasJip = $classBody -match '(?m)^\s*jip\s*=\s*1\s*;'
    if (([string]$entry.Key -in $jipBootstrapFunctions) -ne $hasJip) {
        $remoteFunctionJipValid = $false
    }
}
$nonPlayerWeaponCargo = Get-SourceSection $cargoToArray `
    '^\s*\}\s+foreach\s+_attItems\s*;\s*\r?\n\s*\}\s+else\s*\{' `
    '^\s*if\s*\(\s*_isPlayer\s*\)\s*then\s*\{\s*$'
$updateAddPostMerge = Get-SourceSection $updateItemAdd `
    '_targetData\s+set\s*\[\s*_index\s*,[^\r\n]*jn_fnc_arsenal_addToArray[^\r\n]*\]\s*;' `
    '^\s*_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_targetData\s*\]'
$cargoPostMerge = Get-SourceSection $cargoToArsenal `
    '^\s*\}\s+forEach\s+_array\s*;' `
    '^\s*clearMagazineCargoGlobal\s+_object'

$boundMutationPatterns = @(
    '_mutationOwner\s*=\s*_a4aRemoteOwner',
    '\(\s*owner\s+_x\s*\)\s+isEqualTo\s+_mutationOwner',
    'private\s+_sessions\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerSessions"',
    'private\s+_session\s*=\s*_sessions\s+getOrDefault\s*\[\s*str\s+_mutationOwner',
    'private\s+_boundObject\s*=\s*_session\s+param\s*\[\s*0',
    'private\s+_boundID\s*=\s*_session\s+param\s*\[\s*1',
    'private\s+_boundUID\s*=\s*_session\s+param\s*\[\s*3',
    'private\s+_serverObjects\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerObjects"',
    'private\s+_validItemShape\s*=\s*_item\s+isEqualType\s+""\s*&&\s*\{\s*!\s*\(\s*_item\s+isEqualTo\s+""\s*\)\s*\}\s*&&\s*\{\s*count\s+_item\s*<=\s*256\s*\}',
    'private\s+_knownItemClass\s*=\s*false',
    'if\s*\(\s*_validItemShape\s*\)\s*then',
    '_knownItemClass\s*=',
    'isClass\s*\(\s*configFile\s*>>\s*"CfgWeapons"\s*>>\s*_item\s*\)',
    'isClass\s*\(\s*configFile\s*>>\s*"CfgMagazines"\s*>>\s*_item\s*\)',
    'isClass\s*\(\s*configFile\s*>>\s*"CfgVehicles"\s*>>\s*_item\s*\)',
    'isClass\s*\(\s*configFile\s*>>\s*"CfgGlasses"\s*>>\s*_item\s*\)',
    '_mutationOwner\s*>=\s*0',
    'count\s+_session\s*>=\s*4',
    '_boundObject\s+in\s+_serverObjects',
    '_boundUID\s+isEqualTo\s+getPlayerUID\s+_mutationPlayer',
    'alive\s+_mutationPlayer',
    '_mutationPlayer\s+distance\s+_boundObject\s*<=\s*15',
    '_index\s+isEqualType\s+0',
    '_index\s*>=\s*0',
    '_index\s*<\s*27',
    '_index\s+isEqualTo\s+floor\s+_index',
    '_validItemShape',
    '_knownItemClass',
    '_amount\s+isEqualType\s+0',
    'finite\s+_amount',
    '_amount\s*>\s*0',
    '_amount\s+isEqualTo\s+floor\s+_amount',
    '_amount\s*<=\s*1000000',
    '_updateDataList\s+isEqualTo\s+true',
    'if\s*\(\s*!_validMutation\s*\)\s*exitWith',
    '_arsenalID\s*=\s*_boundID',
    '_playerName\s*=\s*name\s+_mutationPlayer',
    '_playerUID\s*=\s*getPlayerUID\s+_mutationPlayer',
    '_targetData\s+set\s*\['
)

$privateFanoutPatterns = @(
    'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerData"',
    'private\s+_remoteTargets\s*=\s*\[\s*\]',
    'private\s+_viewerOwner\s*=\s*parseNumber\s+_x',
    'private\s+_viewerSession\s*=\s*_sessions\s+getOrDefault\s*\[\s*_x',
    '_viewerOwner\s*>\s*2',
    '_viewerOwner\s*!=\s*_mutationOwner',
    'count\s+_viewerSession\s*>=\s*4',
    '\(\s*_viewerSession\s+select\s+1\s*\)\s+isEqualTo\s+_arsenalID',
    'private\s+_viewerUID\s*=\s*_viewerSession\s+select\s+3',
    'allPlayers\s+findIf',
    '\(\s*owner\s+_x\s*\)\s+isEqualTo\s+_viewerOwner',
    '\(\s*getPlayerUID\s+_x\s*\)\s+isEqualTo\s+_viewerUID',
    '_remoteTargets\s+pushBackUnique\s+_viewerOwner',
    'forEach\s*\(\s*keys\s+_sessions\s*\)',
    'remoteExecCall\s*\[\s*"jn_fnc_arsenal"\s*,\s*_remoteTargets\s*\]'
)

$mutationRevisionPatterns = @(
    '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_targetData\s*\]',
    'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*_serverData\s*\]',
    'private\s+_serverRevisions\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerRevisions"',
    'private\s+_newRevision\s*=\s*\(\s*_serverRevisions\s+getOrDefault\s*\[\s*_arsenalID\s*,\s*0\s*\]\s*\)\s*\+\s*1',
    '_serverRevisions\s+set\s*\[\s*_arsenalID\s*,\s*_newRevision\s*\]',
    'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerRevisions"\s*,\s*_serverRevisions\s*\]',
    '_session\s+set\s*\[\s*4\s*,\s*_newRevision\s*\]',
    '_sessions\s+set\s*\[\s*str\s+_mutationOwner\s*,\s*_session\s*\]',
    'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerSessions"\s*,\s*_sessions\s*\]'
)

$mutationContinuationPatterns = @(
    'private\s+_trustedServerDispatcher\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerDispatcherAuthorized"\s*,\s*false\s*\]',
    'private\s+_serverMutationAccepted\s*=\s*!\s*\(\s*isServer\s*&&\s*\{\s*_a4aIsRemote\s*\}\s*&&\s*\{\s*!_trustedServerDispatcher\s*\}\s*\)',
    'if\s*\(\s*_updateDataList\s*\)\s*then',
    'if\s*\(\s*isServer\s*\)\s*then',
    '_serverMutationAccepted\s*=\s*false',
    'if\s*\(\s*!_validMutation\s*\)\s*exitWith',
    '_targetData\s+set\s*\[',
    'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*_serverData\s*\]',
    '_serverMutationAccepted\s*=\s*true',
    'if\s*\(\s*isServer\s*&&\s*\{\s*!_serverMutationAccepted\s*\}\s*\)\s*exitWith',
    'missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_active"',
    'uiNamespace\s+getVariable\s*\[\s*"arsenalDisplay"'
)

$checks = @()

# fn_A4A_stub is registered in CfgFunctions and therefore has the same public
# remote surface as the other function entry points. Reject a direct RPC at
# the first executable statement so it cannot refresh private server authority.
Add-Check "direct remote A4A stub calls are rejected before private authority snapshots" `
    ($stub -match '(?s)\A(?:\s*//[^\r\n]*(?:\r?\n|$))*\s*if\s*\(\s*isRemoteExecuted\s*\)\s*exitWith\s*\{' `
        -and (Test-FirstPatternBefore $stub `
            'if\s*\(\s*isRemoteExecuted\s*\)\s*exitWith\s*\{' `
            'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerEditorSteamIDs"'))
Add-Check "security settings are restart-required and captured once as private preInit authority" `
    ($editorIdsSetting -match '(?s)^\s*"EDITBOX"\s*,[\s\S]*,\s*1\s*,\s*\{\s*\}\s*,\s*true\s*$' `
        -and $editAccessSetting -match '(?s)^\s*"LIST"\s*,[\s\S]*,\s*1\s*,\s*\{\s*\}\s*,\s*true\s*$' `
        -and $unlockThresholdSetting -match '(?s)^\s*"SLIDER"\s*,[\s\S]*,\s*1\s*,\s*\{\s*\}\s*,\s*true\s*$' `
        -and (Test-PatternsInOrder $stub @(
            'if\s*\(\s*isServer\s*\)\s*then\s*\{',
            'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerEditorSteamIDs"\s*,\s*missionNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_EditorSteamIDs"',
            'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerEditAccessMode"\s*,\s*missionNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_EditAccessMode"',
            'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerUnlockThreshold"\s*,\s*missionNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_UnlockThreshold"',
            'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerLimits"\s*,\s*createHashMap\s*\]'
        )) `
        -and ([regex]::Matches($stub, 'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_Server(?:EditorSteamIDs|EditAccessMode|UnlockThreshold)"')).Count -eq 3 `
        -and $stub -notmatch '(?i)missionNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_(?:EditorSteamIDs|EditAccessMode|UnlockThreshold)"[^\]]*,\s*true\s*\]' `
        -and $stub -notmatch '(?i)publicVariable\s+"A4A_Arsenal_(?:EditorSteamIDs|EditAccessMode|UnlockThreshold)"')
Add-Check "CBA settings lifecycle is loaded before the preInit authority snapshot" `
    ($config -match '(?s)requiredAddons\s*\[\s*\]\s*=\s*\{[^}]*"cba_main"[^}]*\}' `
        -and $config -match '(?s)requiredAddons\s*\[\s*\]\s*=\s*\{[^}]*"cba_settings"[^}]*\}')
Add-Check "CfgRemoteExec is deny-by-default with only the audited RPC whitelist" `
    ($remoteExecFunctions -match '(?m)^\s*mode\s*=\s*1\s*;' `
        -and ([regex]::Matches($remoteExecFunctions, '(?m)^\s*mode\s*=')).Count -eq 1 `
        -and $remoteExecFunctions -match '(?m)^\s*jip\s*=\s*0\s*;' `
        -and $remoteFunctionWhitelistValid `
        -and $remoteFunctionJipValid `
        -and ([regex]::Matches($remoteExecFunctions, '(?m)^\s*jip\s*=\s*1\s*;')).Count -eq 3 `
        -and $remoteExecFunctions -notmatch '(?i)BIS_fnc_(?:spawn|call|execVM)|A4A_fnc_A4A_stub|A4A_fnc_module|A4A_fnc_arsenalLogic|jn_fnc_arsenal_(?:addItem|removeItem)|A4A_fnc_arsenal_scheduleProfileSave|jn_fnc_arsenal_handleAction' `
        -and $remoteExecCommands -match '(?m)^\s*mode\s*=\s*1\s*;' `
        -and $remoteExecCommands -match '(?m)^\s*jip\s*=\s*0\s*;' `
        -and $remoteExecCommands -notmatch '(?m)^\s*class\s+[A-Za-z_][A-Za-z0-9_]*\s*\{')
Add-Check "scheduled JNA initialization uses atomic per-machine object and common winner claims" `
    ((Test-PatternsInOrder $serverInitClaim @(
        'private\s+_serverInitObjects\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerInitObjects"',
        'if\s*\(\s*_object\s+in\s+_serverInitObjects\s*\)\s*then',
        '_runServerInit\s*=\s*false',
        '\}\s*else\s*\{',
        '_serverInitObjects\s+pushBack\s+_object',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerInitObjects"\s*,\s*_serverInitObjects\s*\]'
    )) -and (Test-PatternsInOrder $clientInitClaim @(
        'private\s+_clientInitObjects\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ClientInitObjects"',
        'if\s*\(\s*_object\s+in\s+_clientInitObjects\s*\)\s*then',
        '_runClientInit\s*=\s*false',
        '\}\s*else\s*\{',
        '_clientInitObjects\s+pushBack\s+_object',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ClientInitObjects"\s*,\s*_clientInitObjects\s*\]'
    )) -and (Test-PatternsInOrder $commonInitClaim @(
        'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_CommonInitDone"\s*,\s*false\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_CommonInitDone"\s*,\s*true\s*\]',
        '_runCommonInit\s*=\s*true'
    )) -and (Test-PatternsInOrder $arsenalInit @(
        'private\s+_runCommonInit\s*=\s*false',
        'if\s*\(\s*_runCommonInit\s*\)\s*then\s*\{',
        '\[\s*"Preload"\s*\]\s+call\s+jn_fnc_arsenal'
    )) -and $commonInitClaim -notmatch '\[\s*"Preload"\s*\]\s+call\s+jn_fnc_arsenal' `
        -and (Test-PatternsInOrder $remoteExecCheckClaim @(
            'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_RemoteExecCheckDone"\s*,\s*false\s*\]',
            'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_RemoteExecCheckDone"\s*,\s*true\s*\]',
            '_runRemoteExecCheck\s*=\s*true'
        )) -and (Test-PatternsInOrder $arsenalInit @(
            'private\s+_runRemoteExecCheck\s*=\s*false',
            'if\s*\(\s*_runRemoteExecCheck\s*\)\s*then\s*\{',
            'configFile\s*>>\s*"CfgRemoteExec"'
        )) -and (Test-PatternsInOrder $zeusSyncClaim @(
            'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ZeusSyncStarted"\s*,\s*false\s*\]',
            'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ZeusSyncStarted"\s*,\s*true\s*\]',
            '_startZeusSync\s*=\s*true'
        )) -and (Test-PatternsInOrder $arsenalInit @(
            'private\s+_startZeusSync\s*=\s*false',
            'if\s*\(\s*_startZeusSync\s*\)\s*then\s*\{',
            '\[\s*\]\s+spawn\s*\{'
        )))

# V1 persisted magazine values are remaining-ammunition pools. These checks
# prevent another partial, unversioned conversion to physical-magazine counts.
Add-Check "cargo extraction preserves remaining-ammo units for loose and loaded magazines" `
    (([regex]::Matches($cargoToArray, '_amount\s*=\s*_x\s+select\s+1\s*;')).Count -ge 2)
Add-Check "non-player cargo extraction credits each physical weapon tuple" `
    (Test-PatternsInOrder $nonPlayerWeaponCargo @(
        'private\s+_weaponTuple\s*=\s*_x',
        'private\s+_weaponClass\s*=\s*_weaponTuple\s+param\s*\[\s*0\s*,\s*""\s*\]',
        'if\s*!\s*\(\s*_weaponClass\s+isEqualTo\s+""\s*\)\s*then',
        'private\s+_baseWeapon\s*=\s*_weaponClass\s+call\s+bis_fnc_baseWeapon',
        'private\s+_weaponIndex\s*=\s*_baseWeapon\s+call\s+jn_fnc_arsenal_itemType',
        '\[\s*_array\s*,\s*_weaponIndex\s*,\s*_baseWeapon\s*,\s*1\s*\]\s+call\s+_addToArray',
        'private\s+_component\s*=\s*_weaponTuple\s+param\s*\[\s*_x\s*,\s*""\s*\]',
        'if\s*\(\s*_component\s+isEqualType\s+""\s*&&\s*\{\s*!\s*\(\s*_component\s+isEqualTo\s+""\s*\)\s*\}\s*\)\s*then',
        '\[\s*_array\s*,\s*_component\s+call\s+jn_fnc_arsenal_itemType\s*,\s*_component\s*,\s*1\s*\]\s+call\s+_addToArray',
        'forEach\s*\[\s*1\s*,\s*2\s*,\s*3\s*,\s*6\s*\]',
        'private\s+_loadedMagazine\s*=\s*_weaponTuple\s+param\s*\[\s*_x\s*,\s*\[\]\s*\]',
        'if\s*\(\s*_loadedMagazine\s+isEqualType\s*\[\s*\]\s*&&\s*\{\s*count\s+_loadedMagazine\s*>=\s*2\s*\}\s*\)\s*then',
        'private\s+_magClass\s*=\s*_loadedMagazine\s+select\s+0',
        'private\s+_remainingRounds\s*=\s*_loadedMagazine\s+select\s+1',
        'if\s*\(\s*_magClass\s+isEqualType\s+""\s*&&\s*\{\s*!\s*\(\s*_magClass\s+isEqualTo\s+""\s*\)\s*\}\s*&&\s*\{\s*_remainingRounds\s*>\s*0\s*\}\s*\)\s*then',
        '\[\s*_array\s*,\s*IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL\s*,\s*_magClass\s*,\s*_remainingRounds\s*\]\s+call\s+_addToArray',
        'forEach\s*\[\s*4\s*,\s*5\s*\]',
        'forEach\s*\(\s*weaponsItemsCargo\s+_container_sub\s*\)'
    ))
Add-Check "legacy magazine take debits actual ammunition inserted" `
    ($arsenal -match '_container\s+addMagazineAmmoCargo\s*\[\s*_item\s*,\s*1\s*,\s*_count\s*\]\s*;[\s\S]{0,220}_totalCount\s*=\s*_totalCount\s*\+\s*_count\s*;')
Add-Check "legacy magazine return credits actual remaining ammunition" `
    ($arsenal -match '_totalCount\s*=\s*_totalCount\s*\+\s*\(_x\s+select\s+1\)\s*;')
Add-Check "vehicle magazine transfer remains round-pool compatible" `
    ($vehicleArsenal -match '_magazineCapacity\s*=\s*\(getNumber\s*\(configfile\s*>>\s*"CfgMagazines"\s*>>\s*_item\s*>>\s*"count"\)\)\s*max\s*1' `
        -and $vehicleArsenal -match '_count\s*=\s*_count\s*\*\s*_magazineCapacity' `
        -and $vehicleArsenal -match 'if\s*\(_amount\s*!=\s*-1\s*&&\s*\{_count\s*>\s*_withdrawableAmount\}\)')
Add-Check "vehicle magazine restore cannot loop on zero config capacity" `
    ($vehicleArsenal -match 'private\s+_count\s*=\s*\(getNumber\s*\(configfile\s*>>\s*"CfgMagazines"\s*>>\s*_item\s*>>\s*"count"\)\)\s*max\s*1' `
        -and $vehicleArsenal -match '_ammoToAdd\s*=\s*_amount\s+min\s+_count' `
        -and $vehicleArsenal -match '_amount\s*=\s*_amount\s*-\s*_ammoToAdd')

# Unit-independent deterministic correctness.
Add-Check "itemType fallback reads class from JNA pair records" `
    ($itemType -match '_storedClass\s*=\s*_x\s+param\s*\[\s*0\s*,\s*""\s*\]' `
        -and $itemType -notmatch 'tolower\s+_x')
Add-Check "unknown config classes may reach the pair-aware JNA fallback" `
    ($itemType -notmatch 'if\s*\(isNil\s+"_itemCategory"\s*\|\|\s*\{_itemCategory\s*==\s*"Junk"\}\)\s*exitWith')
Add-Check "ordinary bulk return uses a measured class-specific cargo delta" `
    ($arsenal -match '_beforeItemCount' -and $arsenal -match '_afterItemCount' `
        -and $arsenal -match '_totalCount\s*=\s*\(_beforeItemCount\s*-\s*_afterItemCount\)\s*max\s*0')
Add-Check "infinite binocular battery stock is accepted" `
    ($arsenal -match '_batteryStock\s*==\s*-1\s*\|\|\s*\{_batteryStock\s*>\s*0\}')
Add-Check "stored weapon tuples keep both loaded magazines and the index-6 bipod" `
    ($arsenal -match 'forEach\s*\[0,\s*1,\s*2,\s*3,\s*6\]' `
        -and $arsenal -match 'forEach\s*\[4,\s*5\]' `
        -and $arsenal -match '_loadedMagazine\s+select\s+1')

# Server authority is a private localNamespace map. The GameLogic variable may
# remain as a compatibility mirror, but no server path may read it as canonical.
Add-Check "JNA init owns canonical data in a private localNamespace map" `
    ((Test-PatternsInOrder $arsenalInit @(
        'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*createHashMap\s*\]',
        '_serverData\s+getOrDefault\s*\[\s*_arsenalID',
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_data\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*_serverData\s*\]'
    )) -and $arsenalInit -notmatch '\bserver\s+getVariable\b')
Add-Check "JNA init deeply validates persisted profile data before canonical admission" `
    (Test-PatternsInOrder $arsenalInit @(
        '_data\s*=\s*profileNamespace\s+getVariable\s*\[\s*_profileKey',
        'private\s+_validatePersistedData\s*=\s*\{',
        '_candidate\s+isEqualType\s*\[\s*\][\s\S]{0,80}count\s+_candidate\s*==\s*27',
        'private\s+_valid\s*=\s*true',
        'if\s*!\s*\(\s*_x\s+isEqualType\s*\[\s*\]\s*\)\s*exitWith\s*\{\s*_valid\s*=\s*false\s*\}',
        'private\s+_seen\s*=\s*createHashMap',
        '_x\s+isEqualType\s*\[\s*\][\s\S]{0,80}count\s+_x\s*==\s*2',
        '_className\s+isEqualType\s+""',
        '!\s*\(\s*_className\s+isEqualTo\s+""\s*\)',
        'count\s+_className\s*<=\s*256',
        '_amount\s+isEqualType\s+0',
        'finite\s+_amount',
        '_amount\s+isEqualTo\s+floor\s+_amount',
        '_amount\s*==\s*-1[\s\S]{0,100}_amount\s*>\s*0[\s\S]{0,80}_amount\s*<=\s*100000000',
        '_seen\s+getOrDefault',
        '_totalEntries\s*>\s*10000',
        'if\s*!\s*\(\s*\[_data\]\s+call\s+_validatePersistedData\s*\)\s*then',
        '_data\s*=\s*_defaultData',
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_data\s*\]'
    ))
Add-Check "requestOpen reads only private canonical data" `
    ((Test-PatternsInOrder $requestOpen @(
        'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*createHashMap\s*\]',
        'private\s+_data\s*=\s*_serverData\s+getOrDefault\s*\[\s*_arsenalID',
        'private\s+_payload\s*=\s*if[\s\S]{0,160}\+_data',
        'remoteExecCall\s*\[\s*"jn_fnc_arsenal"\s*,\s*_clientOwner\s*\]'
    )) -and $requestOpen -notmatch 'server\s+getVariable')
Add-Check "requestClose saves only private canonical data" `
    ((Test-PatternsInOrder $requestClose @(
        'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*createHashMap\s*\]',
        'private\s+_data\s*=\s*_serverData\s+getOrDefault\s*\[\s*_arsenalID',
        'if\s*\(\s*count\s+_data\s*==\s*27\s*\)',
        'profileNamespace\s+setVariable\s*\[[\s\S]{0,180},\s*_data\s*\]'
    )) -and $requestClose -notmatch 'server\s+getVariable')
Add-Check "UpdateItemAdd commits through private canonical data before its server-local mirror" `
    ((Test-PatternsInOrder $updateItemAdd @(
        'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*createHashMap\s*\]',
        'private\s+_targetData\s*=\s*\+\s*\(?\s*_serverData\s+getOrDefault\s*\[\s*_arsenalID',
        '_targetData\s+set\s*\[',
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_targetData\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*_serverData\s*\]',
        'server\s+setVariable\s*\[\s*_serverKey\s*,\s*_targetData\s*\]'
    )) -and $updateItemAdd -notmatch 'server\s+getVariable' `
        -and $updateItemAdd -notmatch 'server\s+setVariable\s*\[\s*_serverKey\s*,\s*_targetData\s*,\s*true\s*\]')
Add-Check "UpdateItemRemove commits through private canonical data before its server-local mirror" `
    ((Test-PatternsInOrder $updateItemRemove @(
        'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*createHashMap\s*\]',
        'private\s+_targetData\s*=\s*\+\s*\(?\s*_serverData\s+getOrDefault\s*\[\s*_arsenalID',
        '_targetData\s+set\s*\[',
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_targetData\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*_serverData\s*\]',
        'server\s+setVariable\s*\[\s*_serverKey\s*,\s*_targetData\s*\]'
    )) -and $updateItemRemove -notmatch 'server\s+getVariable' `
        -and $updateItemRemove -notmatch 'server\s+setVariable\s*\[\s*_serverKey\s*,\s*_targetData\s*,\s*true\s*\]')
Add-Check "missing canonical revisions initialize and bind each opened private session" `
    ((Test-PatternsInOrder $arsenalInit @(
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_data\s*\]',
        'private\s+_serverRevisions\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerRevisions"',
        'if\s*\(\s*isNil\s*\{\s*_serverRevisions\s+get\s+_arsenalID\s*\}\s*\)\s*then\s*\{\s*_serverRevisions\s+set\s*\[\s*_arsenalID\s*,\s*0\s*\]\s*;\s*localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerRevisions"\s*,\s*_serverRevisions\s*\]\s*;\s*\}'
    )) -and ([regex]::Matches($arsenalInit, '(?i)_serverRevisions\s+set\s*\[\s*_arsenalID\s*,\s*0\s*\]')).Count -eq 1 `
        -and (Test-PatternsInOrder $requestOpen @(
        'private\s+_data\s*=\s*_serverData\s+getOrDefault\s*\[\s*_arsenalID',
        'private\s+_sessions\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerSessions"',
        'private\s+_serverRevisions\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerRevisions"',
        'private\s+_revision\s*=\s*_serverRevisions\s+getOrDefault\s*\[\s*_arsenalID\s*,\s*0\s*\]',
        '_sessions\s+set\s*\[\s*str\s+_clientOwner\s*,\s*\[\s*_arsenalObj\s*,\s*_arsenalID\s*,\s*diag_tickTime\s*,\s*getPlayerUID\s+_requestPlayer\s*,\s*_revision\s*\]\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerSessions"\s*,\s*_sessions\s*\]'
    )))
Add-Check "UpdateItemAdd advances canonical revision and only the initiating session baseline" `
    ((Test-PatternsInOrder $updateItemAdd $mutationRevisionPatterns) `
        -and ([regex]::Matches($updateItemAdd, '(?i)\b_[A-Za-z0-9_]+\s+set\s*\[\s*4\s*,')).Count -eq 1 `
        -and ([regex]::Matches($updateItemAdd, '(?i)\b_sessions\s+set\s*\[')).Count -eq 1)
Add-Check "UpdateItemRemove advances canonical revision and only the initiating session baseline" `
    ((Test-PatternsInOrder $updateItemRemove $mutationRevisionPatterns) `
        -and ([regex]::Matches($updateItemRemove, '(?i)\b_[A-Za-z0-9_]+\s+set\s*\[\s*4\s*,')).Count -eq 1 `
        -and ([regex]::Matches($updateItemRemove, '(?i)\b_sessions\s+set\s*\[')).Count -eq 1)

# ACE is allowed only for unlimited V1 stock until it has an authoritative,
# full-loadout transaction protocol. Also reject the invalid nullary `keys` use.
Add-Check "ACE helper does not use keys as a nullary keyboard-state command" `
    ($aceStock -notmatch '(?im)\bkeys\s*(?:;|\}|\)|$)')
Add-Check "finite stock explicitly falls back from ACE Preview to Legacy" `
    ($arsenal -match 'A4A_aceFiniteStockDetected' `
        -and $arsenal -match 'Finite JNA stock requires Legacy UI')
Add-Check "Legacy remains the default UI" `
    ($stub -match '\[\[0,\s*1\],\s*\["Legacy \(JNA\)",\s*"ACE3 Preview[^\"]*"\],\s*0\]')

# Narrow sender-bound containment for privileged and session-management paths.
Add-Check "requestOpen derives the client owner from remoteExecutedOwner" `
    (Test-PatternsInOrder $requestOpen @(
        'private\s+_networkRequest\s*=\s*isRemoteExecuted',
        'if\s*\(\s*_networkRequest\s*\)\s*then\s*\{\s*_clientOwner\s*=\s*remoteExecutedOwner',
        '&&\s*\{\s*\(\s*owner\s+_x\s*\)\s+isEqualTo\s+_clientOwner\s*\}\s*\)\s*exitWith\s*\{\s*_requestPlayer\s*=\s*_x',
        'private\s+_serverArsenalRegistry\s*=\s*localNamespace\s+getVariable',
        '_sessions\s+set\s*\[\s*str\s+_clientOwner'
    ))
Add-Check "requestClose derives the client owner from remoteExecutedOwner" `
    (Test-PatternsInOrder $requestClose @(
        'if\s*\(\s*!isServer\s*\)\s*exitWith',
        'private\s+_networkRequest\s*=\s*isRemoteExecuted',
        'if\s*\(\s*_networkRequest\s*&&\s*\{\s*canSuspend\s*\}\s*\)\s*exitWith',
        'private\s+_localHostRequest\s*=\s*!_networkRequest\s*&&\s*\{\s*hasInterface\s*\}\s*&&\s*\{\s*!isDedicated\s*\}',
        'if\s*\(\s*!_networkRequest\s*&&\s*\{\s*!_localHostRequest\s*\}\s*\)\s*exitWith',
        'if\s*\(\s*_networkRequest\s*\)\s*then\s*\{\s*_clientOwner\s*=\s*remoteExecutedOwner',
        '_sessionKey\s*=\s*str\s+_clientOwner',
        '_session\s*=\s*_sessions\s+getOrDefault\s*\[\s*_sessionKey',
        'if\s*\(\s*count\s+_session\s*<\s*2\s*\)\s*exitWith',
        '&&\s*\{\s*\(\s*owner\s+_x\s*\)\s+isEqualTo\s+_clientOwner\s*\}\s*\)\s*exitWith\s*\{\s*_requestPlayer\s*=\s*_x',
        'if\s*\(\s*isNull\s+_requestPlayer\s*\|\|\s*\{\s*count\s+_session\s*>=\s*4\s*&&\s*\{\s*!\s*\(\s*\(\s*_session\s+select\s+3\s*\)\s+isEqualTo\s+getPlayerUID\s+_requestPlayer\s*\)\s*\}\s*\}\s*\)\s*exitWith',
        'if\s*\(\s*isNull\s+_boundArsenalObj\s*\|\|\s*\{\s*!\s*\(\s*_arsenalObj\s+isEqualTo\s+_boundArsenalObj\s*\)\s*\}\s*\|\|\s*\{\s*!\s*\(\s*_boundArsenalObj\s+in\s+_serverArsenalObjects\s*\)\s*\}\s*\)\s*exitWith',
        '_sessions\s+deleteAt\s+_sessionKey'
    ))
Add-Check "direct remote arsenalLogic dispatcher calls are rejected" `
    ($arsenalLogic -match 'if\s*\(\s*isRemoteExecuted\s*\)\s*exitWith' `
        -and $arsenalLogic -match 'rejected remote invocation')
Add-Check "Zeus grant is sender-bound and SteamID allowlisted" `
    ((Test-PatternsInOrder $assignZeus @(
        'if\s*\(\s*!isServer\s*\)\s*exitWith',
        'if\s*\(\s*isRemoteExecuted\s*&&\s*\{\s*canSuspend\s*\}\s*\)\s*exitWith',
        'params\s*\[\s*\[\s*"_player"\s*,\s*objNull',
        'private\s+_localHostRequest\s*=\s*!isRemoteExecuted\s*&&\s*\{\s*hasInterface\s*\}\s*&&\s*\{\s*!isDedicated\s*\}\s*&&\s*\{\s*local\s+_player\s*\}',
        'private\s+_senderOwner\s*=\s*if\s*\(\s*isRemoteExecuted\s*\)\s*then\s*\{\s*remoteExecutedOwner\s*\}\s*else\s*\{\s*owner\s+_player\s*\}',
        'if\s*\(\s*_senderOwner\s*!=\s*owner\s+_player\s*\)\s*exitWith',
        'A4A_Arsenal_ServerEditorSteamIDs'
    )) -and (Test-PatternsInOrder $inputHandler @(
        'if\s*\(\s*isServer\s*\)\s*then',
        '\[\s*player\s*\]\s+call\s+A4A_fnc_assignZeus',
        'else\s*\{',
        '\[\s*player\s*\]\s+remoteExecCall\s*\[\s*"A4A_fnc_assignZeus"\s*,\s*2\s*\]'
    )))
Add-Check "server Zeus authorization ignores the replicated UI cache" `
    ($isZeus -match 'if\s*\(isServer\)\s*exitWith' `
        -and $isZeus -match 'getAssignedCuratorLogic')
Add-Check "privileged Zeus and editor save no longer use identity-less CBA server events" `
    ($inputHandler -notmatch 'A4A_assignZeusRequest[\s\S]{0,100}CBA_fnc_serverEvent' `
        -and $arsenal -notmatch 'A4A_editorSaveRequest[\s\S]{0,100}CBA_fnc_serverEvent' `
        -and $arsenalInit -notmatch 'A4A_assignZeusRequest' `
        -and $arsenalInit -notmatch 'A4A_editorSaveRequest')

Add-Check "remote mutation, session, Garage, and Zeus endpoints reject scheduled RPCs and callers use remoteExecCall" `
    ((Test-PatternsInOrder $arsenal @(
        'private\s+_a4aIsRemote\s*=\s*isRemoteExecuted',
        '_mode\s*=\s*\[_this',
        'if\s*\(\s*isServer\s*&&\s*\{\s*_a4aIsRemote\s*\}\s*&&\s*\{\s*_mode\s+in\s+\[\s*"UpdateItemAdd"\s*,\s*"UpdateItemRemove"\s*\]\s*\}\s*&&\s*\{\s*canSuspend\s*\}\s*\)\s*exitWith'
    )) -and (Test-PatternsInOrder $requestOpen @(
        'if\s*\(\s*!isServer\s*\)\s*exitWith',
        'private\s+_networkRequest\s*=\s*isRemoteExecuted',
        'if\s*\(\s*_networkRequest\s*&&\s*\{\s*canSuspend\s*\}\s*\)\s*exitWith'
    )) -and (Test-PatternsInOrder $requestClose @(
        'if\s*\(\s*!isServer\s*\)\s*exitWith',
        'private\s+_networkRequest\s*=\s*isRemoteExecuted',
        'if\s*\(\s*_networkRequest\s*&&\s*\{\s*canSuspend\s*\}\s*\)\s*exitWith'
    )) -and (Test-PatternsInOrder $garage @(
        'private\s+_garageIsRemote\s*=\s*isRemoteExecuted',
        'private\s+_garageInternalCall\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Garage_InternalCall"\s*,\s*false\s*\]',
        'private\s+_garageTrustedBootstrap\s*=\s*isServer\s*&&\s*\{\s*_garageIsRemote\s*\}\s*&&\s*\{\s*_garageRemoteOwner\s+isEqualTo\s+2\s*\}\s*&&\s*\{\s*_normalizedMode\s+isEqualTo\s+"initserver"\s*\}',
        'if\s*\(\s*isServer\s*&&\s*\{\s*_garageIsRemote\s*\}\s*&&\s*\{\s*canSuspend\s*\}\s*&&\s*\{\s*!_garageInternalCall\s*\}\s*&&\s*\{\s*!_garageTrustedBootstrap\s*\}\s*\)\s*exitWith'
    )) -and $assignZeus -match 'if\s*\(\s*isRemoteExecuted\s*&&\s*\{\s*canSuspend\s*\}\s*\)\s*exitWith' `
        -and $addItem -match 'remoteExecCall\s*\[\s*"jn_fnc_arsenal"\s*,\s*2\s*\]' `
        -and $removeItem -match 'remoteExecCall\s*\[\s*"jn_fnc_arsenal"\s*,\s*2\s*\]' `
        -and $handleAction -match 'remoteExecCall\s*\[\s*"jn_fnc_arsenal_requestOpen"\s*,\s*2\s*\]' `
        -and $arsenalInit -match 'remoteExecCall\s*\[\s*"jn_fnc_arsenal_requestOpen"\s*,\s*2\s*\]' `
        -and $arsenalInit -match 'remoteExecCall\s*\[\s*"jn_fnc_arsenal_requestClose"\s*,\s*2\s*\]' `
        -and $arsenal -match 'remoteExecCall\s*\[\s*"jn_fnc_arsenal_requestClose"\s*,\s*2\s*\]' `
        -and $aceStock -match 'remoteExecCall\s*\[\s*"jn_fnc_arsenal_requestClose"\s*,\s*2\s*\]' `
        -and $garage -match 'remoteExecCall\s*\[\s*"A4A_fnc_garage"\s*,\s*2\s*\]' `
        -and $inputHandler -match 'remoteExecCall\s*\[\s*"A4A_fnc_assignZeus"\s*,\s*2\s*\]' `
        -and ($addItem + $removeItem + $handleAction + $arsenalInit + $arsenal + $aceStock + $garage + $inputHandler) -notmatch '\bremoteExec\s*\[\s*"(?:jn_fnc_arsenal|jn_fnc_arsenal_requestOpen|jn_fnc_arsenal_requestClose|A4A_fnc_garage|A4A_fnc_assignZeus)"')

# The generic dispatcher is still remotely callable in mode=2, so each stock
# mutation must bind engine sender -> player -> private session -> registry,
# replace identity/ID payload fields, and validate the delta before mutation.
Add-Check "dispatcher captures engine-authenticated remote execution context" `
    ((Test-PatternsInOrder $arsenal @(
        'private\s+_a4aIsRemote\s*=\s*isRemoteExecuted\s*;',
        'private\s+_a4aRemoteOwner\s*=\s*if\s*\(\s*_a4aIsRemote\s*\)\s*then\s*\{\s*remoteExecutedOwner\s*\}',
        'if\s*\(\s*!isServer\s*&&[\s\S]{0,160}_a4aRemoteOwner\s*!=\s*2[\s\S]{0,80}\)\s*exitWith',
        '_mode\s*=\s*\[_this',
        'isServer[\s\S]{0,80}_a4aIsRemote[\s\S]{0,120}!\s*\(\s*_mode\s+in\s+\[\s*"UpdateItemAdd"\s*,\s*"UpdateItemRemove"\s*\]\s*\)',
        'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerDispatcherAuthorized"\s*,\s*false\s*\]',
        '\)\s*exitWith\s*\{[\s\S]{0,180}rejected remote server dispatcher mode'
    )))
Add-Check "UpdateItemAdd is sender, session, registry, and payload bound before mutation" `
    (Test-PatternsInOrder $updateItemAdd $boundMutationPatterns)
Add-Check "UpdateItemRemove is sender, session, registry, and payload bound before mutation" `
    (Test-PatternsInOrder $updateItemRemove $boundMutationPatterns)
Add-Check "UpdateItem validates item string shape before the first config lookup in both cases" `
    ((Test-FirstPatternBefore $updateItemAdd `
        'private\s+_validItemShape\s*=\s*_item\s+isEqualType\s+""' `
        'configFile\s*>>\s*"CfgWeapons"\s*>>\s*_item') `
        -and (Test-FirstPatternBefore $updateItemRemove `
            'private\s+_validItemShape\s*=\s*_item\s+isEqualType\s+""' `
            'configFile\s*>>\s*"CfgWeapons"\s*>>\s*_item') `
        -and (Test-PatternsInOrder $updateItemAdd @(
            'private\s+_validItemShape\s*=\s*_item\s+isEqualType\s+""[\s\S]{0,100}count\s+_item\s*<=\s*256',
            'private\s+_knownItemClass\s*=\s*false',
            'if\s*\(\s*_validItemShape\s*\)\s*then',
            '_knownItemClass\s*=',
            'configFile\s*>>\s*"CfgWeapons"\s*>>\s*_item',
            'private\s+_validMutation\s*=',
            '_validItemShape',
            '_knownItemClass'
        )) -and (Test-PatternsInOrder $updateItemRemove @(
            'private\s+_validItemShape\s*=\s*_item\s+isEqualType\s+""[\s\S]{0,100}count\s+_item\s*<=\s*256',
            'private\s+_knownItemClass\s*=\s*false',
            'if\s*\(\s*_validItemShape\s*\)\s*then',
            '_knownItemClass\s*=',
            'configFile\s*>>\s*"CfgWeapons"\s*>>\s*_item',
            'private\s+_validMutation\s*=',
            '_validItemShape',
            '_knownItemClass'
        )))
Add-Check "server mutation and full-save classification disable stored UI fallback" `
    ((Test-PatternsInOrder $itemType @(
        'params\s*\[\s*"_item"\s*,\s*\[\s*"_allowStoredFallback"\s*,\s*true\s*,\s*\[\s*true\s*\]\s*\]\s*\]',
        'if\s*\(\s*_return\s*==\s*-1\s*&&\s*\{\s*_allowStoredFallback\s*\}\s*\)\s*then',
        'missionNamespace\s+getVariable\s*\[\s*"jna_dataList"\s*,\s*\[\s*\]\s*\]'
    )) -and (Test-PatternsInOrder $updateItemAdd @(
        'private\s+_targetData\s*=',
        'private\s+_derivedIndex\s*=\s*\[\s*_item\s*,\s*false\s*\]\s+call\s+jn_fnc_arsenal_itemType',
        'if\s*\(\s*_derivedIndex\s*!=\s*_index\s*\)\s*exitWith'
    )) -and (Test-PatternsInOrder $updateItemRemove @(
        'private\s+_targetData\s*=',
        'private\s+_derivedIndex\s*=\s*\[\s*_item\s*,\s*false\s*\]\s+call\s+jn_fnc_arsenal_itemType',
        'if\s*\(\s*_derivedIndex\s*!=\s*_index\s*\)\s*exitWith'
    )) -and (Test-PatternsInOrder $saveRequest @(
        'private\s+_derivedIndex\s*=\s*\[\s*_className\s*,\s*false\s*\]\s+call\s+jn_fnc_arsenal_itemType',
        'if\s*\(\s*_derivedIndex\s*!=\s*_bucketIndex\s*\)\s*exitWith'
    )))
Add-Check "UpdateItemAdd rejects over-limit post-merge canonical candidates before commit" `
    ($updateAddPostMerge -match '(?s)private\s+(?<Amount>_[A-Za-z][A-Za-z0-9_]*)\s*=\s*_x\s+(?:param\s*\[\s*1|select\s+1)[^;]*;[\s\S]*?finite\s+\k<Amount>[\s\S]*?\k<Amount>\s+isEqualTo\s+floor\s+\k<Amount>[\s\S]*?\k<Amount>\s*==\s*-1[\s\S]*?\k<Amount>\s*>\s*0[\s\S]*?\k<Amount>\s*<=\s*100000000' `
        -and $updateAddPostMerge -match '(?s)(?<EntryCount>_[A-Za-z][A-Za-z0-9_]*)\s*=\s*\k<EntryCount>\s*\+\s*count\s+_x\s*;[\s\S]*?\k<EntryCount>\s*>\s*10000' `
        -and $updateAddPostMerge -match '(?s)\}\s+forEach\s+_targetData\s*;\s*if\s*!\s*\(\s*_[A-Za-z][A-Za-z0-9_]*\s*\)\s*exitWith\s*\{')
Add-Check "UpdateItemAdd stops rejected server mutations before ACE or UI continuation" `
    ((Test-PatternsInOrder $updateItemAdd $mutationContinuationPatterns) `
        -and ([regex]::Matches($updateItemAdd, '_serverMutationAccepted\s*=\s*false')).Count -eq 1 `
        -and ([regex]::Matches($updateItemAdd, '_serverMutationAccepted\s*=\s*true')).Count -eq 1)
Add-Check "UpdateItemRemove stops rejected server mutations before ACE or UI continuation" `
    ((Test-PatternsInOrder $updateItemRemove $mutationContinuationPatterns) `
        -and ([regex]::Matches($updateItemRemove, '_serverMutationAccepted\s*=\s*false')).Count -eq 1 `
        -and ([regex]::Matches($updateItemRemove, '_serverMutationAccepted\s*=\s*true')).Count -eq 1)
Add-Check "UpdateItemRemove checks canonical availability before debit" `
    (Test-PatternsInOrder $updateItemRemove @(
        'jn_fnc_arsenal_itemCount',
        '_available\s*<\s*_amount',
        'exitWith',
        'jn_fnc_arsenal_removeFromArray'
    ))
Add-Check "clients accept remote UpdateItem deltas only from server owner 2" `
    ($updateItemAdd -match '!isServer[\s\S]{0,180}_a4aIsRemote[\s\S]{0,180}_a4aRemoteOwner\s*!=\s*2' `
        -and $updateItemRemove -match '!isServer[\s\S]{0,180}_a4aIsRemote[\s\S]{0,180}_a4aRemoteOwner\s*!=\s*2')

# Client wrappers only request target 2. Sanitized peer fanout happens once,
# after server commit, with recipients derived from private bound sessions.
Add-Check "add and remove wrappers send stock requests only to server target 2" `
    (([regex]::Matches($addItem, 'remoteExecCall\s*\[\s*"jn_fnc_arsenal"\s*,\s*2\s*\]')).Count -eq 1 `
        -and ([regex]::Matches($removeItem, 'remoteExecCall\s*\[\s*"jn_fnc_arsenal"\s*,\s*2\s*\]')).Count -eq 1 `
        -and ([regex]::Matches($addItem, 'remoteExecCall\s*\[\s*"jn_fnc_arsenal"')).Count -eq 1 `
        -and ([regex]::Matches($removeItem, 'remoteExecCall\s*\[\s*"jn_fnc_arsenal"')).Count -eq 1 `
        -and $addItem -notmatch 'jna_playersInArsenal' `
        -and $removeItem -notmatch 'jna_playersInArsenal')
Add-Check "UpdateItemAdd fans out committed deltas from private sessions" `
    ((Test-PatternsInOrder $updateItemAdd $privateFanoutPatterns) `
        -and $updateItemAdd -notmatch 'jna_playersInArsenal')
Add-Check "UpdateItemRemove fans out committed deltas from private sessions" `
    ((Test-PatternsInOrder $updateItemRemove $privateFanoutPatterns) `
        -and $updateItemRemove -notmatch 'jna_playersInArsenal')
Add-Check "direct remote add and remove wrapper invocations are rejected" `
    ($addItem -match 'if\s*\(\s*isRemoteExecuted\s*\)\s*exitWith' `
        -and $addItem -match 'rejected direct remote addItem wrapper' `
        -and $removeItem -match 'if\s*\(\s*isRemoteExecuted\s*\)\s*exitWith' `
        -and $removeItem -match 'rejected direct remote removeItem wrapper')

Add-Check "arsenal bootstrap and module entry points reject client-authored remote origin" `
    ((Test-PatternsInOrder $bootstrap @(
        'if\s*\(\s*isRemoteExecuted\s*&&\s*\{\s*remoteExecutedOwner\s*!=\s*2\s*\}\s*\)\s*exitWith',
        'if\s*\(\s*isServer\s*\)\s*then',
        '_object\s+setVariable\s*\[\s*"A4A_Arsenal_ID"',
        '\[\s*_object\s*\]\s+remoteExec\s*\[\s*"JN_fnc_arsenal_init"\s*,\s*0\s*,\s*_object\s*\]'
    )) -and (Test-PatternsInOrder $moduleArsenal @(
        'if\s*\(\s*isRemoteExecuted\s*&&\s*\{\s*remoteExecutedOwner\s*!=\s*2\s*\}\s*\)\s*exitWith',
        'if\s*\(\s*!_activated\s*\)\s*exitWith',
        'if\s*\(\s*!isServer\s*\)\s*exitWith',
        'remoteExec\s*\[\s*"A4A_fnc_arsenalInit"',
        'deleteVehicle\s+_logic'
    )) -and (Test-PatternsInOrder $arsenalInit @(
        'if\s*\(\s*isRemoteExecuted\s*&&\s*\{\s*remoteExecutedOwner\s*!=\s*2\s*\}\s*\)\s*exitWith',
        '_object\s+setVariable\s*\[\s*"A4A_Arsenal_Initialized"',
        'if\s*\(\s*isServer\s*\)\s*then',
        'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerObjects"'
    )))
Add-Check "arsenal bootstrap atomically registers canonical maps before scheduling the full JIP initializer" `
    ((Test-PatternsInOrder $bootstrap @(
        'if\s*\(\s*isServer\s*\)\s*then',
        '_object\s+setVariable\s*\[\s*"A4A_Arsenal_ID"\s*,\s*_arsenalID\s*,\s*true\s*\]',
        '_object\s+setVariable\s*\[\s*"A4A_Arsenal_Threshold"\s*,\s*_unlockThreshold\s*,\s*true\s*\]',
        'isNil\s*\{',
        'private\s+_serverObjects\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerObjects"\s*,\s*\[\s*\]\s*\]',
        '_serverObjects\s+pushBackUnique\s+_object',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerObjects"\s*,\s*_serverObjects\s*\]',
        'private\s+_serverRegistry\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerRegistry"\s*,\s*\[\s*\]\s*\]',
        '_serverRegistry\s+pushBack\s*\[\s*_object\s*,\s*_arsenalID\s*,\s*_unlockThreshold\s*\]',
        '_serverRegistry\s+set\s*\[\s*_registryIndex\s*,\s*\[\s*_object\s*,\s*_arsenalID\s*,\s*_unlockThreshold\s*\]\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerRegistry"\s*,\s*_serverRegistry\s*\]',
        'if\s*\(\s*isNil\s*\{\s*localNamespace\s+getVariable\s+"A4A_Arsenal_ServerData"\s*\}\s*\)\s*then\s*\{\s*localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*createHashMap\s*\]',
        'if\s*\(\s*isNil\s*\{\s*localNamespace\s+getVariable\s+"A4A_Arsenal_ServerRevisions"\s*\}\s*\)\s*then\s*\{\s*localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerRevisions"\s*,\s*createHashMap\s*\]',
        'if\s*\(\s*isNil\s*\{\s*localNamespace\s+getVariable\s+"A4A_Arsenal_ServerReadyObjects"\s*\}\s*\)\s*then\s*\{\s*localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerReadyObjects"\s*,\s*\[\s*\]\s*\]',
        'nil\s*\}\s*;',
        '\[\s*_object\s*\]\s+remoteExec\s*\[\s*"JN_fnc_arsenal_init"\s*,\s*0\s*,\s*_object\s*\]'
    )) -and $bootstrap -notmatch '\[\s*_object\s*\]\s+remoteExecCall\s*\[\s*"JN_fnc_arsenal_init"')

Add-Check "JNA server initialization resolves canonical ID and threshold only from its private registry" `
    ((Test-PatternsInOrder $canonicalServerInit @(
        'private\s+_canonicalRegistry\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerRegistry"\s*,\s*\[\s*\]\s*\]',
        'private\s+_canonicalIndex\s*=\s*_canonicalRegistry\s+findIf',
        'if\s*\(\s*_canonicalIndex\s*<\s*0\s*\)\s*then',
        '_serverRegistrationValid\s*=\s*false',
        '\}\s*else\s*\{',
        'private\s+_canonicalEntry\s*=\s*_canonicalRegistry\s+select\s+_canonicalIndex',
        '_arsenalID\s*=\s*_canonicalEntry\s+select\s+1',
        '_unlockThreshold\s*=\s*_canonicalEntry\s+param\s*\[\s*2\s*,\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerUnlockThreshold"'
    )) -and $canonicalServerInit -notmatch '_object\s+getVariable\s*\[\s*"A4A_Arsenal_(?:ID|Threshold)"' `
        -and $arsenalInit -notmatch 'missionNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_(?:EditorSteamIDs|EditAccessMode|EditorUIDs)"' `
        -and $arsenalInit -notmatch 'missionNamespace\s+getVariable\s*\[\s*"A4A_arsenalLimits"')
Add-Check "canonical readiness is published after data and revision, then required by open and save" `
    ((Test-PatternsInOrder $arsenalInit @(
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_data\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*_serverData\s*\]',
        'private\s+_serverRevisions\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerRevisions"',
        '_serverRevisions\s+set\s*\[\s*_arsenalID\s*,\s*0\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerRevisions"\s*,\s*_serverRevisions\s*\]',
        'private\s+_readyObjects\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerReadyObjects"\s*,\s*\[\s*\]\s*\]',
        '_readyObjects\s+pushBackUnique\s+_object',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerReadyObjects"\s*,\s*_readyObjects\s*\]'
    )) -and (Test-PatternsInOrder $requestOpen @(
        'private\s+_readyObjects\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerReadyObjects"',
        'if\s*!\s*\(\s*_arsenalObj\s+in\s+_readyObjects\s*\)\s*exitWith\s*\{',
        'private\s+_arsenalID\s*=\s*\(\s*_serverArsenalRegistry\s+select\s+_registryIndex\s*\)\s+select\s+1',
        'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerData"'
    )) -and (Test-PatternsInOrder $saveRequest @(
        'private\s+_readyObjects\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerReadyObjects"',
        'if\s*!\s*\(\s*_arsenalObj\s+in\s+_readyObjects\s*\)\s*exitWith\s*\{',
        'A4A_fnc_arsenal_canEdit',
        'private\s+_sessions\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerSessions"',
        'private\s+_canonicalID\s*=\s*\(\s*_serverArsenalRegistry\s+select\s+_registryIndex\s*\)\s+select\s+1',
        'private\s+_arsenalID\s*=\s*_canonicalID',
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_validatedData\s*\]'
    )))
Add-Check "ServerInvalidate terminates loading and both Legacy and owned ACE UI state" `
    (Test-PatternsInOrder $serverInvalidate @(
        'private\s+_loadingIds\s*=\s*missionNamespace\s+getVariable\s*\[\s*"BIS_fnc_startLoadingScreen_ids"',
        'if\s*\(\s*"jn_fnc_arsenal"\s+in\s+_loadingIds\s*\)\s*then',
        '\[\s*"jn_fnc_arsenal"\s*\]\s+call\s+BIS_fnc_endLoadingScreen',
        'private\s+_display\s*=\s*uiNamespace\s+getVariable\s*\[\s*"arsenalDisplay"',
        '_display\s+closeDisplay\s+2',
        'if\s*\(\s*missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_active"\s*,\s*false\s*\]\s*\)\s*then',
        'private\s+_aceDisplay\s*=\s*findDisplay\s+1127001',
        '_aceDisplay\s+closeDisplay\s+2',
        'if\s*\(\s*missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_active"\s*,\s*false\s*\]\s*&&\s*\{\s*!isNil\s+"A4A_fnc_arsenal_aceEndSession"\s*\}\s*\)\s*then',
        '\[\s*\]\s+call\s+A4A_fnc_arsenal_aceEndSession',
        'systemChat\s+_message'
    ))

Add-Check "garage bootstrap and module reject client-authored remote origin and register privately" `
    ((Test-PatternsInOrder $garageInit @(
        'if\s*\(\s*isRemoteExecuted\s*&&\s*\{\s*remoteExecutedOwner\s*!=\s*2\s*\}\s*\)\s*exitWith',
        '_object\s+setVariable\s*\[\s*"A4A_Garage_Initialized"',
        'if\s*\(\s*isServer\s*\)\s*then',
        'localNamespace\s+getVariable\s*\[\s*"A4A_Garage_ServerRegistry"',
        '_registry\s+pushBack\s*\[\s*_object\s*,\s*_garageID\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Garage_ServerRegistry"\s*,\s*_registry\s*\]'
    )) -and (Test-PatternsInOrder $moduleGarage @(
        'if\s*\(\s*isRemoteExecuted\s*&&\s*\{\s*remoteExecutedOwner\s*!=\s*2\s*\}\s*\)\s*exitWith',
        'if\s*\(\s*!_activated\s*\)\s*exitWith',
        'if\s*\(\s*!isServer\s*\)\s*exitWith',
        'remoteExec\s*\[\s*"A4A_fnc_garageInit"',
        'deleteVehicle\s+_logic'
    )))
Add-Check "garage dispatcher rejects peer calls and allowlists only remote addVehicle" `
    (Test-PatternsInOrder $garage @(
        'private\s+_garageIsRemote\s*=\s*isRemoteExecuted',
        'private\s+_garageRemoteOwner\s*=\s*if\s*\(\s*_garageIsRemote\s*\)\s*then\s*\{\s*remoteExecutedOwner\s*\}',
        'private\s+_garageInternalCall\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Garage_InternalCall"\s*,\s*false\s*\]',
        'private\s+_garageTrustedBootstrap\s*=\s*isServer\s*&&\s*\{\s*_garageIsRemote\s*\}\s*&&\s*\{\s*_garageRemoteOwner\s+isEqualTo\s+2\s*\}\s*&&\s*\{\s*_normalizedMode\s+isEqualTo\s+"initserver"\s*\}',
        'if\s*\(\s*!isServer[\s\S]{0,140}_garageRemoteOwner\s*!=\s*2[\s\S]{0,80}\)\s*exitWith',
        'if\s*\(\s*isServer\s*&&\s*\{\s*_garageIsRemote\s*\}\s*&&\s*\{\s*!\s*\(\s*_normalizedMode\s+isEqualTo\s+"addvehicle"\s*\)\s*\}\s*&&\s*\{\s*!_garageTrustedBootstrap\s*\}\s*&&\s*\{\s*!_garageInternalCall\s*\}\s*\)\s*exitWith',
        'rejected\s+remote\s+server\s+dispatcher\s+mode',
        'switch\s+_normalizedMode\s+do'
    ))
Add-Check "garage bootstrap admits only owner-2 initServer while private capability scopes other nested calls" `
    ((Test-PatternsInOrder $garageInit @(
        'if\s*\(\s*isServer\s*\)\s*then',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Garage_ServerRegistry"\s*,\s*_registry\s*\]',
        '\[\s*"initServer"\s*,\s*\[\s*_garageID\s*\]\s*\]\s+call\s+A4A_fnc_garage'
    )) -and (Test-PatternsInOrder $garage @(
        'private\s+_garageInternalCall\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Garage_InternalCall"\s*,\s*false\s*\]',
        'private\s+_garageTrustedBootstrap\s*=\s*isServer\s*&&\s*\{\s*_garageIsRemote\s*\}\s*&&\s*\{\s*_garageRemoteOwner\s+isEqualTo\s+2\s*\}\s*&&\s*\{\s*_normalizedMode\s+isEqualTo\s+"initserver"\s*\}',
        'if\s*\(\s*isServer\s*&&\s*\{\s*_garageIsRemote\s*\}\s*&&\s*\{\s*canSuspend\s*\}\s*&&\s*\{\s*!_garageInternalCall\s*\}\s*&&\s*\{\s*!_garageTrustedBootstrap\s*\}\s*\)\s*exitWith',
        'if\s*\(\s*!isServer[\s\S]{0,140}_garageRemoteOwner\s*!=\s*2[\s\S]{0,80}\)\s*exitWith',
        '&&\s*\{\s*!_garageTrustedBootstrap\s*\}\s*&&\s*\{\s*!_garageInternalCall\s*\}',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Garage_InternalCall"\s*,\s*true\s*\]',
        '\[\s*"getCatIndex"\s*,\s*\[\s*_vehicle\s*\]\s*\]\s+call\s+A4A_fnc_garage',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Garage_InternalCall"\s*,\s*false\s*\]'
    )))
Add-Check "garage addVehicle derives owner and validates private registry plus proximity" `
    (Test-PatternsInOrder $garageAddVehicle @(
        'if\s*\(\s*_garageIsRemote\s*\)\s*then',
        '_clientOwner\s*=\s*_garageRemoteOwner',
        '\(\s*owner\s+_x\s*\)\s+isEqualTo\s+_clientOwner',
        'localNamespace\s+getVariable\s*\[\s*"A4A_Garage_ServerRegistry"',
        '_x\s+select\s+1\)\s+isEqualTo\s+_garageID',
        '_requestPlayer\s+distance\s+_garageObject\s*>\s*30',
        '_vehicle\s+distance\s+_garageObject\s*>\s*25',
        '\)\s*exitWith\s*\{[\s\S]{0,160}rejected addVehicle',
        'deleteVehicle\s+_vehicle'
    ))
Add-Check "garage dispatcher mode and addVehicle payload are type constrained before use" `
    ((Test-PatternsInOrder $garage @(
        'params\s*\[\s*\[\s*"_mode"\s*,\s*""\s*,\s*\[\s*""\s*\]\s*\]\s*,\s*\[\s*"_params"\s*,\s*\[\s*\]\s*,\s*\[\s*\[\s*\]\s*\]\s*\]\s*\]',
        'if\s*\(\s*_mode\s+isEqualTo\s+""\s*\)\s*exitWith',
        'private\s+_normalizedMode\s*=\s*toLower\s+_mode',
        'switch\s+_normalizedMode\s+do'
    )) -and (Test-PatternsInOrder $garageAddVehicle @(
        '_params\s+params\s*\[\s*\[\s*"_garageID"\s*,\s*""\s*,\s*\[\s*""\s*\]\s*\]\s*,\s*\[\s*"_vehicle"\s*,\s*objNull\s*,\s*\[\s*objNull\s*\]\s*\]\s*,\s*\[\s*"_clientOwner"\s*,\s*-1\s*,\s*\[\s*0\s*\]\s*\]\s*\]',
        'if\s*\(\s*_garageIsRemote\s*\)\s*then',
        '_clientOwner\s*=\s*_garageRemoteOwner',
        'private\s+_registry\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Garage_ServerRegistry"'
    )))
Add-Check "garage requester notification is host-safe and server-targeted for remote owners" `
    (Test-PatternsInOrder $garageAddVehicle @(
        'private\s+_notifyRequester\s*=\s*\{',
        'params\s*\[\s*\[\s*"_message"\s*,\s*""\s*,\s*\[\s*""\s*\]\s*\]\s*\]',
        'if\s*\(\s*_message\s+isEqualTo\s+""\s*\)\s*exitWith',
        'if\s*\(\s*_clientOwner\s+isEqualTo\s+clientOwner\s*&&\s*\{\s*hasInterface\s*\}\s*&&\s*\{\s*!isDedicated\s*\}\s*\)\s*then',
        'systemChat\s+_message',
        'if\s*\(\s*_clientOwner\s*>\s*2\s*\)\s*then',
        '\[\s*"ServerNotify"\s*,\s*\[\s*_message\s*\]\s*\]\s+remoteExecCall\s*\[\s*"jn_fnc_arsenal"\s*,\s*_clientOwner\s*\]',
        '\[\s*"Garage request rejected by server validation\."\s*\]\s+call\s+_notifyRequester'
    ))

Add-Check "server reserve policy uses private startup defaults and rejects replicated per-class overrides" `
    ((Test-PatternsInOrder $stub @(
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerUnlockThreshold"\s*,\s*missionNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_UnlockThreshold"',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerLimits"\s*,\s*createHashMap\s*\]'
    )) -and (Test-PatternsInOrder $arsenalInit @(
        'if\s*\(\s*isServer\s*\)\s*then\s*\{\s*A4A_guestItemLimit\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerUnlockThreshold"',
        'jna_minItemMember\s*=\s*jna_minItemMember\s+apply\s*\{\s*A4A_guestItemLimit\s*\}',
        'if\s*\(\s*isNil\s*\{\s*localNamespace\s+getVariable\s+"A4A_Arsenal_ServerMinItems"\s*\}\s*\)\s*then',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerMinItems"\s*,\s*\+jna_minItemMember\s*\]',
        'if\s*\(\s*isNil\s*\{\s*localNamespace\s+getVariable\s+"A4A_Arsenal_ServerLimits"\s*\}\s*\)\s*then',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerLimits"\s*,\s*createHashMap\s*\]'
    )) -and $arsenalInit -notmatch 'missionNamespace\s+getVariable\s*\[\s*"A4A_arsenalLimits"' `
        -and $arsenalInit -notmatch '\bA4A_arsenalLimits\s+get\b' `
        -and (Test-PatternsInOrder $minItemsMember @(
        'private\s+_minimums\s*=\s*if\s*\(\s*isServer\s*\)\s*then',
        'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerMinItems"\s*,\s*\[\s*\]\s*\]',
        'missionNamespace\s+getVariable\s*\[\s*"jna_minItemMember"',
        'private\s+_limits\s*=\s*if\s*\(\s*isServer\s*\)\s*then',
        'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerLimits"\s*,\s*createHashMap\s*\]',
        'missionNamespace\s+getVariable\s*\[\s*"A4A_arsenalLimits"',
        '_limits\s+getOrDefault\s*\[\s*_item\s*,\s*_min\s*\]'
    )) -and $minItemsMember -notmatch 'server\s+getVariable')

# Cargo transfer is destructive. Its sender/session/registry validation and
# busy lock must all precede any clear*CargoGlobal call; it must not fan out.
Add-Check "cargo batch rejects an over-limit complete candidate before destructive clear or commit" `
    ($cargoPostMerge -match '(?s)private\s+(?<Amount>_[A-Za-z][A-Za-z0-9_]*)\s*=\s*_x\s+(?:param\s*\[\s*1|select\s+1)[^;]*;[\s\S]*?finite\s+\k<Amount>[\s\S]*?\k<Amount>\s+isEqualTo\s+floor\s+\k<Amount>[\s\S]*?\k<Amount>\s*==\s*-1[\s\S]*?\k<Amount>\s*>\s*0[\s\S]*?\k<Amount>\s*<=\s*100000000' `
        -and $cargoPostMerge -match '(?s)(?<EntryCount>_[A-Za-z][A-Za-z0-9_]*)\s*=\s*\k<EntryCount>\s*\+\s*count\s+_x\s*;[\s\S]*?\k<EntryCount>\s*>\s*10000' `
        -and $cargoPostMerge -match '(?s)\}\s+forEach\s+_targetData\s*;\s*if\s*!\s*\(\s*_[A-Za-z][A-Za-z0-9_]*\s*\)\s*exitWith\s*\{[\s\S]*?_object\s+setVariable\s*\[\s*"A4A_JNA_cargoToArsenal_busy"\s*,\s*false\s*\]')
Add-Check "cargo transfer rejects scheduled execution and its UI caller uses remoteExecCall target 2" `
    ((Test-PatternsInOrder $cargoToArsenal @(
        'if\s*\(\s*!isServer\s*\)\s*exitWith',
        'if\s*\(\s*canSuspend\s*\)\s*exitWith',
        'params\s*\[\s*\[\s*"_object"',
        'private\s+_networkRequest\s*=\s*isRemoteExecuted',
        'A4A_JNA_cargoToArsenal_busy',
        'private\s+_array\s*=\s*_object\s+call\s+jn_fnc_arsenal_cargoToArray',
        'clearMagazineCargoGlobal\s+_object'
    )) -and (Test-PatternsInOrder $cargoButton @(
        'private\s+_object\s*=\s*missionnamespace\s+getVariable\s*\[\s*"jna_object"',
        '\[\s*_object\s*,\s*_object\s*\]\s+remoteExecCall\s*\[\s*"jn_fnc_arsenal_cargoToArsenal"\s*,\s*2\s*\]'
    )) -and $cargoButton -notmatch '\bremoteExec\s*\[')
Add-Check "cargo endpoint binds sender, player, private session, and registry before clearing" `
    ((Test-PatternsInOrder $cargoToArsenal @(
        'private\s+_networkRequest\s*=\s*isRemoteExecuted',
        'private\s+_senderOwner\s*=\s*if\s*\(\s*_networkRequest\s*\)\s*then\s*\{\s*remoteExecutedOwner\s*\}',
        '\(\s*owner\s+_x\s*\)\s+isEqualTo\s+_senderOwner',
        'private\s+_sessions\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerSessions"',
        'private\s+_session\s*=\s*_sessions\s+getOrDefault\s*\[\s*str\s+_senderOwner',
        'private\s+_boundObject\s*=\s*_session\s+param\s*\[\s*0',
        'private\s+_arsenalID\s*=\s*_session\s+param\s*\[\s*1',
        'private\s+_boundUID\s*=\s*_session\s+param\s*\[\s*3',
        'private\s+_serverObjects\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerObjects"',
        '_object\s+isEqualTo\s+_boundObject',
        '_arsenalObj\s+isEqualTo\s+_boundObject',
        '_boundObject\s+in\s+_serverObjects',
        '_boundUID\s+isEqualTo\s+getPlayerUID\s+_requestPlayer',
        '_requestPlayer\s+distance\s+_boundObject\s*>\s*15',
        '\)\s*exitWith\s*\{[\s\S]{0,180}sender/session/object binding failed',
        'A4A_JNA_cargoToArsenal_busy',
        'private\s+_array\s*=\s*_object\s+call\s+jn_fnc_arsenal_cargoToArray',
        'if\s*\(\s*count\s+_array\s*!=\s*27[\s\S]{0,100}count\s+_targetData\s*!=\s*27[\s\S]{0,80}\)\s*exitWith',
        '_deltas\s+pushBack',
        'clearMagazineCargoGlobal\s+_object',
        'clearItemCargoGlobal\s+_object',
        'clearWeaponCargoGlobal\s+_object',
        'clearBackpackCargoGlobal\s+_object'
    )) -and $cargoToArsenal -match '!isNull\s+_arsenalObj\s*&&\s*\{\s*!\s*\(\s*_arsenalObj\s+isEqualTo\s+_boundObject\s*\)' `
        -and $cargoToArsenal -notmatch 'jna_playersInArsenal')
Add-Check "cargo endpoint commits privately then fans out only from private sessions" `
    ((Test-PatternsInOrder $cargoToArsenal @(
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_targetData\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerData"',
        'server\s+setVariable',
        'private\s+_remoteTargets\s*=\s*\[\s*\]',
        'private\s+_viewerOwner\s*=\s*parseNumber\s+_x',
        'private\s+_viewerSession\s*=\s*_sessions\s+getOrDefault\s*\[\s*_x',
        '_viewerOwner\s*>\s*2',
        'count\s+_viewerSession\s*>=\s*4',
        '\(\s*_viewerSession\s+select\s+1\s*\)\s+isEqualTo\s+_arsenalID',
        'private\s+_viewerUID\s*=\s*_viewerSession\s+select\s+3',
        '\(\s*owner\s+_x\s*\)\s+isEqualTo\s+_viewerOwner',
        '\(\s*getPlayerUID\s+_x\s*\)\s+isEqualTo\s+_viewerUID',
        '_remoteTargets\s+pushBackUnique\s+_viewerOwner',
        'forEach\s*\(\s*keys\s+_sessions\s*\)',
        'remoteExecCall\s*\[\s*"jn_fnc_arsenal"\s*,\s*_remoteTargets\s*\]'
    )) -and $cargoToArsenal -notmatch 'jna_playersInArsenal')
Add-Check "cargo commit advances canonical revision without advancing viewer session baselines" `
    ((Test-PatternsInOrder $cargoToArsenal @(
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_targetData\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*_serverData\s*\]',
        'private\s+_serverRevisions\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerRevisions"',
        '_serverRevisions\s+set\s*\[\s*_arsenalID\s*,\s*\(\s*_serverRevisions\s+getOrDefault\s*\[\s*_arsenalID\s*,\s*0\s*\]\s*\)\s*\+\s*1\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerRevisions"\s*,\s*_serverRevisions\s*\]',
        'private\s+_remoteTargets\s*=\s*\[\s*\]'
    )) -and $cargoToArsenal -notmatch '(?i)\b_[A-Za-z0-9_]+\s+set\s*\[\s*4\s*,' `
        -and $cargoToArsenal -notmatch '(?i)\b_sessions\s+set\s*\[')
Add-Check "hosted cargo continuation uses its private session and scoped dispatcher capability" `
    (Test-PatternsInOrder $cargoToArsenal @(
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_targetData\s*\]',
        'private\s+_hostSession\s*=\s*_sessions\s+getOrDefault\s*\[\s*str\s+clientOwner\s*,\s*\[\s*\]\s*\]',
        'if\s*\(\s*!isDedicated\s*&&\s*\{\s*hasInterface\s*\}[\s\S]{0,180}\(\s*_hostSession\s+select\s+1\s*\)\s+isEqualTo\s+_arsenalID\s*\}\s*\)\s*then',
        'jna_dataList\s+set\s*\[\s*_index',
        'private\s+_previousDispatcherAuth\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerDispatcherAuthorized"\s*,\s*false\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerDispatcherAuthorized"\s*,\s*true\s*\]',
        '\[\s*"UpdateItemAdd"\s*,\s*\[\s*_index\s*,\s*_item\s*,\s*_amount\s*,\s*false\s*,\s*"CargoToArsenal"\s*,\s*_boundUID\s*,\s*_arsenalID\s*\]\s*\]\s+call\s+jn_fnc_arsenal',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerDispatcherAuthorized"\s*,\s*_previousDispatcherAuth\s*\]',
        'forEach\s+_deltas'
    ))

# Network endpoints retain an explicit local-host path. Local server wrappers
# are rejected only when engine remote execution is actually active.
Add-Check "singleplayer and hosted server retain explicit local trusted paths" `
    ((Test-PatternsInOrder $requestOpen @(
        '_localHostRequest\s*=\s*!_networkRequest\s*&&\s*\{\s*hasInterface\s*\}\s*&&\s*\{\s*!isDedicated\s*\}\s*&&\s*\{\s*_clientOwner\s+isEqualTo\s+clientOwner\s*\}',
        'if\s*\(\s*_localHostRequest\s*\)\s*then[\s\S]{0,300}_requestPlayer\s*=\s*player',
        '_sessions\s+set\s*\[\s*str\s+_clientOwner',
        'jna_dataList\s*=\s*\+_data',
        '\[_mode\s*,\s*_payload\]\s+call\s+jn_fnc_arsenal'
    )) -and (Test-PatternsInOrder $requestClose @(
        '_localHostRequest\s*=\s*!_networkRequest\s*&&\s*\{\s*hasInterface\s*\}\s*&&\s*\{\s*!isDedicated\s*\}\s*&&\s*\{\s*_clientOwner\s+isEqualTo\s+clientOwner\s*\}',
        '_sessionKey\s*=\s*str\s+_clientOwner',
        'if\s*\(\s*_localHostRequest\s*\)\s*then\s*\{\s*_requestPlayer\s*=\s*player\s*\}',
        '_sessions\s+deleteAt\s+_sessionKey'
    )) -and (Test-PatternsInOrder $cargoToArsenal @(
        'else\s*\{\s*if\s*\(\s*hasInterface[\s\S]{0,160}local\s+player',
        '_requestPlayer\s*=\s*player',
        '_senderOwner\s*=\s*clientOwner',
        '_session\s*=\s*_sessions\s+getOrDefault\s*\[\s*str\s+_senderOwner',
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_targetData\s*\]'
    )) -and (Test-PatternsInOrder $saveRequest @(
        'else\s*\{\s*if\s*\(\s*hasInterface[\s\S]{0,160}local\s+_localPlayer',
        '_requestPlayer\s*=\s*_localPlayer',
        '_senderOwner\s*=\s*clientOwner',
        '_session\s*=\s*_sessions\s+getOrDefault\s*\[\s*str\s+_senderOwner',
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_validatedData\s*\]'
    )) -and (Test-PatternsInOrder $updateItemAdd @(
        'else\s*\{[\s\S]{0,260}hasInterface[\s\S]{0,200}local\s+player',
        '_mutationPlayer\s*=\s*player',
        '_mutationOwner\s*=\s*clientOwner',
        '_session\s*=\s*_sessions\s+getOrDefault\s*\[\s*str\s+_mutationOwner',
        '_targetData\s+set\s*\['
    )) -and (Test-PatternsInOrder $updateItemRemove @(
        'else\s*\{[\s\S]{0,260}hasInterface[\s\S]{0,200}local\s+player',
        '_mutationPlayer\s*=\s*player',
        '_mutationOwner\s*=\s*clientOwner',
        '_session\s*=\s*_sessions\s+getOrDefault\s*\[\s*str\s+_mutationOwner',
        '_targetData\s+set\s*\['
    )) -and $addItem -match 'if\s*\(\s*isRemoteExecuted\s*\)\s*exitWith' `
        -and $removeItem -match 'if\s*\(\s*isRemoteExecuted\s*\)\s*exitWith')

Add-Check "ACE preview opens an A4A-owned client-local proxy, not the persistent arsenal object" `
    ((Test-PatternsInOrder $openAce @(
        'private\s+_aceProxy\s*=\s*createVehicleLocal\s*\[\s*"Land_HelipadEmpty_F"',
        '\[\s*_arsenalObj\s*,\s*_aceProxy\s*\]\s+call\s+A4A_fnc_arsenal_aceBeginSession',
        '\[\s*_aceProxy\s*,\s*player\s*\]\s+call\s+ace_arsenal_fnc_openBox'
    )) -and (Test-PatternsInOrder $aceBeginSession @(
        'params\s*\[\s*"_arsenalObj"\s*,\s*"_aceBox"\s*\]',
        'setVariable\s*\[\s*"A4A_aceStock_arsenalObj"\s*,\s*_arsenalObj\s*\]',
        'setVariable\s*\[\s*"A4A_aceStock_box"\s*,\s*_aceBox\s*\]',
        '\[\s*_item\s*,\s*_amount\s*\]\s+call\s+A4A_fnc_arsenal_aceSyncVirtualItems'
    )) -and (Test-PatternsInOrder $aceSyncVirtualItems @(
        'missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_box"\s*,\s*objNull\s*\]',
        '\[\s*_arsenalObj\s*,\s*\[\s*_item\s*\]\s*\]\s+call\s+ace_arsenal_fnc_addVirtualItems'
    )) -and $openAce -notmatch '\]\s+call\s+ace_arsenal_fnc_initBox' `
        -and $aceStock -notmatch '\]\s+call\s+ace_arsenal_fnc_initBox')
Add-Check "ACE callbacks and delayed refreshes are bound to the exact active proxy" `
    (($aceOwnsCurrentBox -match '(?s)^\s*private\s+_expectedBox\s*=\s*missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_box"\s*,\s*objNull\s*\]\s*;\s*!isNull\s+_expectedBox\s*&&\s*\{\s*\(\s*missionNamespace\s+getVariable\s*\[\s*"ace_arsenal_currentBox"\s*,\s*objNull\s*\]\s*\)\s+isEqualTo\s+_expectedBox\s*\}\s*;?\s*\}\s*;\s*$') `
        -and (Test-PatternsInOrder $aceScheduleStockRefresh @(
        'private\s+_expectedBox\s*=\s*missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_box"\s*,\s*objNull\s*\]',
        '\[\s*_display\s*,\s*_fullRefresh\s*,\s*_expectedBox\s*\]\s+spawn'
    )) -and (Test-PatternsInOrder $aceRefreshSpawn @(
        'params\s*\[\s*"_display"\s*,\s*"_fullRefresh"\s*,\s*"_expectedBox"\s*\]',
        'uiSleep\s+0\.1',
        'if\s*\(\s*isNull\s+_display\s*\|\|\s*\{\s*!\s*\(\s*missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_active"\s*,\s*false\s*\]\s*\)\s*\}\s*\|\|\s*\{\s*!\s*\(\s*\(\s*missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_box"\s*,\s*objNull\s*\]\s*\)\s+isEqualTo\s+_expectedBox\s*\)\s*\}\s*\|\|\s*\{\s*!\s*\(\s*\[\s*\]\s+call\s+A4A_fnc_arsenal_aceOwnsCurrentBox\s*\)\s*\}\s*\)\s*exitWith\s*\{\s*\}',
        'call\s+ace_arsenal_fnc_refresh'
    )) -and ([regex]::Matches(
        $aceStock,
        'if\s*!\s*\(\s*\[\s*\]\s+call\s+A4A_fnc_arsenal_aceOwnsCurrentBox\s*\)\s*exitWith',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )).Count -ge 6)
Add-Check "OpenACE ignores same-object duplicates, rejects foreign displays, and cancels cross-object overlap before replacing state" `
    ((Test-PatternsInOrder $openAce @(
        'private\s+_existingAceDisplay\s*=\s*findDisplay\s+1127001',
        'private\s+_a4aAceActive\s*=\s*missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_active"\s*,\s*false\s*\]',
        'if\s*\(\s*_a4aAceActive\s*\)\s*exitWith',
        'if\s*\(\s*!isNull\s+_existingAceDisplay\s*\)\s*exitWith',
        'jna_dataList\s*=\s*\+_data',
        'private\s+_aceProxy\s*=\s*createVehicleLocal'
    )) -and (Test-PatternsInOrder $aceActiveOverlap @(
        'private\s+_activeArsenalObj\s*=\s*missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_arsenalObj"\s*,\s*objNull\s*\]',
        'if\s*\(\s*_activeArsenalObj\s+isEqualTo\s+_arsenalObj\s*\)\s*then'
    )) -and (Test-PatternsInOrder $aceCrossObjectOverlap @(
        'if\s*\(\s*!isNull\s+_existingAceDisplay\s*\)\s*then\s*\{\s*_existingAceDisplay\s+closeDisplay\s+2\s*\}',
        '\[\s*\]\s+call\s+A4A_fnc_arsenal_aceEndSession',
        '\[\s*clientOwner\s*,\s*_arsenalObj\s*\]\s+remoteExecCall\s*\[\s*"jn_fnc_arsenal_requestClose"\s*,\s*2\s*\]'
    )) -and $aceDuplicateSameObject -match 'duplicate\s+ACE\s+open\s+ignored' `
        -and $aceDuplicateSameObject -notmatch 'jna_dataList\s*=' `
        -and $aceForeignRejectExecutable -match '(?s)^\s*private\s+_lsIds\s*=\s*missionNamespace\s+getVariable\s*\[\s*"BIS_fnc_startLoadingScreen_ids"\s*,\s*\[\s*\]\s*\]\s*;\s*if\s*\(\s*"jn_fnc_arsenal"\s+in\s+_lsIds\s*\)\s*then\s*\{\s*\[\s*"jn_fnc_arsenal"\s*\]\s+call\s+BIS_fnc_endLoadingScreen\s*\}\s*;\s*if\s*\(\s*!isNull\s+_arsenalObj\s*\)\s*then\s*\{\s*\[\s*clientOwner\s*,\s*_arsenalObj\s*\]\s+remoteExecCall\s*\[\s*"jn_fnc_arsenal_requestClose"\s*,\s*2\s*\]\s*;\s*\}\s*;\s*systemChat\s+"[^"]+"\s*;\s*diag_log\s+"[^"]+"\s*;?\s*$' `
        -and ([regex]::Matches($openAce, 'jna_dataList\s*=\s*\+_data')).Count -eq 1)
Add-Check "OpenACE watchdog ends only the still-active proxy session when ACE did not bind it" `
    ((Test-PatternsInOrder $openAce @(
        '\[\s*_aceProxy\s*\]\s+spawn'
    )) -and (Test-PatternsInOrder $aceWatchdogSpawn @(
        'params\s*\[\s*"_expectedProxy"\s*\]',
        'uiSleep\s+3',
        'if\s*\(\s*missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_active"\s*,\s*false\s*\]\s*&&\s*\{\s*\(\s*missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_box"\s*,\s*objNull\s*\]\s*\)\s+isEqualTo\s+_expectedProxy\s*\}\s*&&\s*\{\s*isNull\s*\(\s*findDisplay\s+1127001\s*\)\s*\|\|\s*\{\s*!\s*\(\s*\(\s*missionNamespace\s+getVariable\s*\[\s*"ace_arsenal_currentBox"\s*,\s*objNull\s*\]\s*\)\s+isEqualTo\s+_expectedProxy\s*\)\s*\}\s*\}\s*\)\s*then\s*\{\s*diag_log\s+"[^"]+"\s*;\s*\[\s*\]\s+call\s+A4A_fnc_arsenal_aceEndSession\s*;?\s*\}'
    )))
Add-Check "ACE key handlers preserve native Shift-only 1-or-5 transfer semantics" `
    (($aceGetStepExecutable -match '(?s)^\s*params\s*\[\s*\[\s*"_shiftState"\s*,\s*false\s*,\s*\[\s*false\s*\]\s*\]\s*\]\s*;\s*private\s+_shift\s*=\s*_shiftState\s*\|\|\s*\{\s*uiNamespace\s+getVariable\s*\[\s*"A4A_arsenalShift"\s*,\s*false\s*\]\s*\}\s*;\s*\[\s*1\s*,\s*5\s*\]\s+select\s+_shift\s*\}\s*;\s*$') `
        -and $aceAttachKeyHandlersExecutable -match '(?s)^\s*params\s*\[\s*"_display"\s*\]\s*;\s*_display\s+displayAddEventHandler\s*\[\s*"KeyDown"\s*,\s*\{\s*params\s*\[\s*""\s*,\s*""\s*,\s*"_shift"\s*,\s*""\s*,\s*""\s*\]\s*;\s*uiNamespace\s+setVariable\s*\[\s*"A4A_arsenalShift"\s*,\s*_shift\s*\]\s*;\s*false\s*\}\s*\]\s*;\s*_display\s+displayAddEventHandler\s*\[\s*"KeyUp"\s*,\s*\{\s*params\s*\[\s*""\s*,\s*""\s*,\s*"_shift"\s*,\s*""\s*,\s*""\s*\]\s*;\s*uiNamespace\s+setVariable\s*\[\s*"A4A_arsenalShift"\s*,\s*_shift\s*\]\s*;\s*false\s*\}\s*\]\s*;\s*\}\s*;\s*$' `
        -and ([regex]::Matches($aceAttachKeyHandlers, 'displayAddEventHandler\s*\[\s*"Key(?:Down|Up)"')).Count -eq 2 `
        -and ([regex]::Matches($aceAttachKeyHandlers, 'uiNamespace\s+setVariable\s*\[\s*"A4A_arsenalShift"\s*,\s*_shift\s*\]')).Count -eq 2 `
        -and ([regex]::Matches($aceAttachKeyHandlers, '(?im)^\s*false\s*$')).Count -eq 2 `
        -and $aceAttachKeyHandlers -notmatch '(?i)\b_(?:ctrl|control|alt)[A-Za-z0-9_]*|A4A_arsenal(?:Ctrl|Alt)')
Add-Check "ACE action overlap guard dominates the first requestOpen RPC" `
    ((Test-PatternsInOrder $handleAction @(
        'private\s+_uiStyle\s*=\s*0',
        'if\s*\(\s*_uiStyle\s+isEqualTo\s+1\s*&&\s*\{\s*missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_active"\s*,\s*false\s*\]\s*\|\|\s*\{\s*!isNull\s*\(\s*findDisplay\s+1127001\s*\)\s*\}\s*\}\s*\)\s*exitWith',
        'missionNamespace\s+setVariable\s*\[\s*"jna_object"\s*,\s*_this\s+select\s+0\s*\]',
        '\[\s*clientOwner\s*,\s*_arsenalObj\s*,\s*_uiStyle\s*\]\s+remoteExecCall\s*\[\s*"jn_fnc_arsenal_requestOpen"\s*,\s*2\s*\]'
    )) -and (Test-FirstPatternBefore $handleAction `
        'if\s*\(\s*_uiStyle\s+isEqualTo\s+1[\s\S]*?\)\s*exitWith' `
        'remoteExecCall\s*\[\s*"jn_fnc_arsenal_requestOpen"') `
        -and ([regex]::Matches($handleAction, 'missionNamespace\s+setVariable\s*\[\s*"jna_object"')).Count -eq 1 `
        -and ([regex]::Matches($handleAction, 'remoteExecCall\s*\[\s*"jn_fnc_arsenal_requestOpen"')).Count -eq 1)
Add-Check "ACE session deletes its local proxy next frame and closes the original session" `
    ((Test-PatternsInOrder $aceEndSession @(
        'missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_arsenalObj"',
        'missionNamespace\s+getVariable\s*\[\s*"A4A_aceStock_box"',
        'deleteVehicle\s+_box',
        '\[\s*_cleanupProxy\s*,\s*\[\s*_aceBox\s*\]\s*\]\s+call\s+CBA_fnc_execNextFrame',
        '\[\s*clientOwner\s*,\s*_arsenalObj\s*\]\s+remoteExecCall\s*\[\s*"jn_fnc_arsenal_requestClose"\s*,\s*2\s*\]'
    )) -and $aceEndSession -match 'setVariable\s*\[\s*"A4A_aceStock_box"\s*,\s*nil\s*\]' `
        -and $aceEndSession -match 'setVariable\s*\[\s*"A4A_aceStock_arsenalObj"\s*,\s*nil\s*\]')

Add-Check "ImportData and EditorSave share the same validated saveRequest route" `
    ($importData -notmatch 'profileNamespace\s+setVariable|server\s+setVariable|saveProfileNamespace' `
        -and $editorSave -notmatch 'profileNamespace\s+setVariable|server\s+setVariable|saveProfileNamespace' `
        -and (Test-PatternsInOrder $importData @(
            'private\s+_oneShotImport\s*=\s*_this\s+param\s*\[\s*1\s*,\s*false\s*,\s*\[\s*true\s*\]\s*\]',
            'jna_dataList\s*=\s*_parsed',
            'if\s*\(\s*isServer\s*\)\s*then',
            'isNil\s*\{\s*\[\s*_importArsenalObj\s*,\s*\+jna_dataList\s*,\s*player\s*,\s*_oneShotImport\s*\]\s+call\s+A4A_fnc_arsenal_saveRequest\s*\}',
            '\[\s*_importArsenalObj\s*,\s*\+jna_dataList\s*,\s*objNull\s*,\s*_oneShotImport\s*\]\s+remoteExecCall\s*\[\s*"A4A_fnc_arsenal_saveRequest"\s*,\s*2\s*\]'
        )) `
        -and $editorSave -match '\[\s*_arsenalObj\s*,\s*\+jna_dataList\s*,\s*player\s*\]\s+call\s+A4A_fnc_arsenal_saveRequest' `
        -and $editorSave -match '\[\s*_arsenalObj\s*,\s*\+jna_dataList\s*\]\s+remoteExecCall\s*\[\s*"A4A_fnc_arsenal_saveRequest"\s*,\s*2\s*\]')
Add-Check "standalone Import action binds the actual target and requests one-shot validation" `
    (Test-PatternsInOrder $arsenalInit @(
        '_object\s+addAction\s*\[\s*"<t\s+color=''#ffaa00''>Import Arsenal Data</t>"',
        'params\s*\[\s*"_target"\s*\]',
        'missionNamespace\s+setVariable\s*\[\s*"jna_object"\s*,\s*_target\s*\]',
        '\[\s*"ImportData"\s*,\s*\[\s*_target\s*,\s*true\s*\]\s*\]\s+call\s+jn_fnc_arsenal'
    ))
Add-Check "ImportData reports submission only until the server confirms the save" `
    ($importData -match 'Import request submitted to the server' `
        -and $importData -match 'Waiting for confirmation' `
        -and $importData -notmatch 'STR_JNA_ACT_IMPORT_OK|Import successful|Import OK|Imported[^\r\n]*successfully')
Add-Check "ImportData parses declarative arrays and validates them before assignment" `
    ((Test-PatternsInOrder $importData @(
        'private\s+_parsed\s*=\s*parseSimpleArray\s+_dataText',
        '(?m)^\s*if\s*\(\s*isNil\s+"_parsed"\s*\)\s*exitWith',
        '(?m)^\s*if\s*!\s*\(\s*_parsed\s+isEqualType\s*\[\s*\]\s*\)\s*exitWith',
        'count\s+_parsed\s*!=\s*27',
        'private\s+_validImport\s*=\s*true',
        '_x\s+isEqualType\s*\[\s*\][\s\S]{0,80}count\s+_x\s*==\s*2',
        '_className\s+isEqualType\s+""',
        '_entryAmount\s+isEqualType\s+0',
        'finite\s+_entryAmount',
        '_entryAmount\s+isEqualTo\s+floor\s+_entryAmount',
        '_entryAmount\s*==\s*-1[\s\S]{0,100}_entryAmount\s*>\s*0[\s\S]{0,80}_entryAmount\s*<=\s*100000000',
        '_seen\s+getOrDefault',
        '_importEntries\s*>\s*10000',
        'if\s*\(\s*!_validImport\s*\)\s*exitWith',
        'jna_dataList\s*=\s*_parsed'
    )) -and $importData -notmatch 'call\s+compile\s+_dataText')
Add-Check "shared saveRequest validates local and remote callers before private canonical commit" `
    ((Test-PatternsInOrder $saveRequest @(
        'params\s*\[[\s\S]{0,260}\[\s*"_oneShotImport"\s*,\s*false\s*,\s*\[\s*true\s*\]\s*\]\s*\]',
        '_networkRequest\s*=\s*isRemoteExecuted',
        '_senderOwner\s*=\s*if\s*\(\s*_networkRequest\s*\)\s*then\s*\{\s*remoteExecutedOwner\s*\}',
        '\(\s*owner\s+_x\s*\)\s+isEqualTo\s+_senderOwner',
        'if\s*\(\s*canSuspend\s*\)\s*exitWith',
        'private\s+_serverArsenalRegistry\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerRegistry"',
        'private\s+_registryIndex\s*=\s*_serverArsenalRegistry\s+findIf',
        '\(\s*_x\s+select\s+0\s*\)\s+isEqualTo\s+_arsenalObj',
        '_requestPlayer\s+distance\s+_arsenalObj\s*>\s*10',
        'A4A_fnc_arsenal_canEdit',
        'private\s+_sessions\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerSessions"',
        'private\s+_session\s*=\s*_sessions\s+getOrDefault\s*\[\s*str\s+_senderOwner',
        'private\s+_canonicalID\s*=\s*\(\s*_serverArsenalRegistry\s+select\s+_registryIndex\s*\)\s+select\s+1',
        'private\s+_validBoundSession\s*=',
        'count\s+_session\s*>=\s*4',
        '\(\s*_session\s+select\s+0\s*\)\s+isEqualTo\s+_arsenalObj',
        '\(\s*_session\s+select\s+1\s*\)\s+isEqualTo\s+_canonicalID',
        '\(\s*_session\s+select\s+3\s*\)\s+isEqualTo\s+getPlayerUID\s+_requestPlayer',
        'if\s*\(\s*!_validBoundSession\s*&&\s*\{\s*!_oneShotImport\s*\}\s*\)\s*exitWith',
        'private\s+_ephemeralSession\s*=\s*!_validBoundSession',
        'private\s+_currentRevision\s*=\s*_serverRevisions\s+getOrDefault\s*\[\s*_canonicalID\s*,\s*0\s*\]',
        'if\s*\(\s*_ephemeralSession\s*\)\s*then',
        '_session\s*=\s*\[\s*_arsenalObj\s*,\s*_canonicalID\s*,\s*diag_tickTime\s*,\s*getPlayerUID\s+_requestPlayer\s*,\s*_currentRevision\s*\]',
        'if\s*\(\s*_expectedRevision\s*!=\s*_currentRevision\s*\)\s*exitWith',
        'count\s+_dataList\)\s*!=\s*27',
        '_bucket\s+isEqualType\s*\[\s*\]',
        '_entry\s+isEqualType\s*\[\s*\][\s\S]{0,80}count\s+_entry\s*==\s*2',
        '_className\s+isEqualType\s+""',
        '!\s*\(\s*_className\s+isEqualTo\s+""\s*\)',
        'count\s+_className\s*<=\s*256',
        '_amount\s+isEqualType\s+0',
        'finite\s+_amount',
        'floor\s+_amount\s*==\s*_amount',
        '_amount\s*==\s*-1[\s\S]{0,100}_amount\s*>\s*0[\s\S]{0,80}_amount\s*<=\s*100000000',
        '_seenClasses\s+getOrDefault',
        '_validatedBucket\s+pushBack\s*\[\s*_className\s*,\s*_amount\s*\]',
        '_totalEntries\s*>\s*10000',
        '_validatedData\s+pushBack\s+_validatedBucket',
        'if\s*\(\s*!_valid\s*\|\|\s*\{\s*count\s+_validatedData\s*!=\s*27\s*\}\s*\)\s*exitWith',
        'private\s+_arsenalID\s*=\s*_canonicalID',
        'private\s+_serverData\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerData"',
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_validatedData\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*_serverData\s*\]',
        'profileNamespace\s+setVariable\s*\[\s*_profileKey\s*,\s*_validatedData\s*\]'
    )) -and $saveRequest -match 'hasInterface[\s\S]{0,180}local\s+_localPlayer')
Add-Check "shared saveRequest rejects stale session revision before validating or committing a snapshot" `
    (Test-PatternsInOrder $saveRequest @(
        'private\s+_serverRevisions\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerRevisions"',
        'private\s+_currentRevision\s*=\s*_serverRevisions\s+getOrDefault\s*\[\s*_canonicalID\s*,\s*0\s*\]',
        'if\s*\(\s*_ephemeralSession\s*\)\s*then',
        '_session\s*=\s*\[\s*_arsenalObj\s*,\s*_canonicalID\s*,\s*diag_tickTime\s*,\s*getPlayerUID\s+_requestPlayer\s*,\s*_currentRevision\s*\]',
        'private\s+_expectedRevision\s*=\s*_session\s+param\s*\[\s*4\s*,\s*-1\s*,\s*\[\s*0\s*\]\s*\]',
        'if\s*\(\s*_expectedRevision\s*!=\s*_currentRevision\s*\)\s*exitWith',
        'private\s+_valid\s*=\s*true',
        'if\s*\(\s*!_valid\s*\|\|\s*\{\s*count\s+_validatedData\s*!=\s*27\s*\}\s*\)\s*exitWith',
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_validatedData\s*\]'
    ))
Add-Check "shared saveRequest rate-limits each authorized UID for two seconds before deep validation" `
    (Test-PatternsInOrder $saveRequest @(
        'private\s+_expectedRevision\s*=\s*_session\s+param\s*\[\s*4\s*,\s*-1',
        'if\s*\(\s*_expectedRevision\s*!=\s*_currentRevision\s*\)\s*exitWith',
        'private\s+_saveRateLimits\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerSaveRateLimits"\s*,\s*createHashMap\s*\]',
        'private\s+_saveRateKey\s*=\s*getPlayerUID\s+_requestPlayer',
        'private\s+_saveNow\s*=\s*diag_tickTime',
        'private\s+_lastSaveAttempt\s*=\s*_saveRateLimits\s+getOrDefault\s*\[\s*_saveRateKey\s*,\s*-1000\s*\]',
        'if\s*\(\s*\(\s*_saveNow\s*-\s*_lastSaveAttempt\s*\)\s*<\s*2\s*\)\s*exitWith',
        '_saveRateLimits\s+set\s*\[\s*_saveRateKey\s*,\s*_saveNow\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerSaveRateLimits"\s*,\s*_saveRateLimits\s*\]',
        'if\s*\(\s*\(\s*count\s+_dataList\s*\)\s*!=\s*27\s*\)\s*exitWith'
    ))
Add-Check "shared saveRequest globally rejects duplicate, unknown, and wrong-bucket classes before commit" `
    (Test-PatternsInOrder $saveRequest @(
        'private\s+_seenClasses\s*=\s*createHashMap',
        '\{\s*private\s+_bucket\s*=\s*_x',
        'private\s+_bucketIndex\s*=\s*_forEachIndex',
        'private\s+_knownClass\s*=',
        'isClass\s*\(\s*configFile\s*>>\s*"CfgWeapons"\s*>>\s*_className\s*\)',
        'isClass\s*\(\s*configFile\s*>>\s*"CfgMagazines"\s*>>\s*_className\s*\)',
        'isClass\s*\(\s*configFile\s*>>\s*"CfgVehicles"\s*>>\s*_className\s*\)',
        'isClass\s*\(\s*configFile\s*>>\s*"CfgGlasses"\s*>>\s*_className\s*\)',
        'if\s*\(\s*!_knownClass\s*\)\s*exitWith',
        'private\s+_derivedIndex\s*=\s*\[\s*_className\s*,\s*false\s*\]\s+call\s+jn_fnc_arsenal_itemType',
        'if\s*\(\s*_derivedIndex\s*!=\s*_bucketIndex\s*\)\s*exitWith',
        'private\s+_classKey\s*=\s*toLower\s+_className',
        'if\s*\(\s*_seenClasses\s+getOrDefault\s*\[\s*_classKey\s*,\s*false\s*\]\s*\)\s*exitWith',
        '_seenClasses\s+set\s*\[\s*_classKey\s*,\s*true\s*\]',
        '_validatedBucket\s+pushBack\s*\[\s*_className\s*,\s*_amount\s*\]',
        'if\s*\(\s*!_valid\s*\|\|\s*\{\s*count\s+_validatedData\s*!=\s*27\s*\}\s*\)\s*exitWith',
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_validatedData\s*\]'
    ))
Add-Check "successful bound-session save advances author revision then invalidates other viewer sessions" `
    (Test-PatternsInOrder $saveRequest @(
        '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_validatedData\s*\]',
        '_currentRevision\s*=\s*_currentRevision\s*\+\s*1',
        '_serverRevisions\s+set\s*\[\s*_arsenalID\s*,\s*_currentRevision\s*\]',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerRevisions"\s*,\s*_serverRevisions\s*\]',
        'if\s*\(\s*!_ephemeralSession\s*\)\s*then',
        '_session\s+set\s*\[\s*4\s*,\s*_currentRevision\s*\]',
        '_sessions\s+set\s*\[\s*str\s+_senderOwner\s*,\s*_session\s*\]',
        'private\s+_viewerKey\s*=\s*_x',
        '!\s*\(\s*_viewerKey\s+isEqualTo\s+str\s+_senderOwner\s*\)',
        '&&\s*\{\s*\(\s*_viewerSession\s+select\s+1\s*\)\s+isEqualTo\s+_arsenalID\s*\}',
        '_sessions\s+deleteAt\s+_viewerKey',
        'if\s*\(\s*_viewerOwner\s+isEqualTo\s+clientOwner\s*&&\s*\{\s*hasInterface\s*\}\s*&&\s*\{\s*!isDedicated\s*\}\s*\)\s*then',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerDispatcherAuthorized"\s*,\s*true\s*\]',
        '\[\s*"ServerInvalidate"\s*,\s*\[\s*_invalidateMessage\s*\]\s*\]\s+call\s+jn_fnc_arsenal',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerDispatcherAuthorized"\s*,\s*false\s*\]',
        'if\s*\(\s*_viewerOwner\s*>\s*2\s*\)\s*then',
        '\[\s*"ServerInvalidate"\s*,\s*\[\s*_invalidateMessage\s*\]\s*\]\s+remoteExecCall\s*\[\s*"jn_fnc_arsenal"\s*,\s*_viewerOwner\s*\]',
        'forEach\s*\(\s*\+\s*\(\s*keys\s+_sessions\s*\)\s*\)',
        'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerSessions"\s*,\s*_sessions\s*\]'
    ))
Add-Check "editor save request is registered and validates engine sender plus payload shape" `
    ((Test-Path -LiteralPath $saveRequestPath) `
        -and $config -match 'class\s+arsenal_saveRequest\s*\{\s*\};' `
        -and $saveRequest -match 'remoteExecutedOwner' `
        -and $saveRequest -match 'A4A_fnc_arsenal_canEdit' `
        -and $saveRequest -match 'count\s+_dataList\)\s*!=\s*27' `
        -and $saveRequest -match '_entry\s+isEqualType\s*\[\]')

# Persistence batching and source hygiene.
Add-Check "profile save helper uses a private generation and retries trailing writes" `
    ((Test-Path -LiteralPath $profileSavePath) `
        -and $config -match 'class\s+arsenal_scheduleProfileSave\s*\{\s*\};' `
        -and (Test-PatternsInOrder $profileSave @(
            'if\s*\(\s*!isServer\s*\)\s*exitWith',
            'if\s*!\s*\(\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ProfileSaveAuthorized"\s*,\s*false\s*\]\s*\)\s*exitWith',
            'private\s+_generation\s*=\s*\(\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ProfileSaveGeneration"\s*,\s*0\s*\]\s*\)\s*\+\s*1',
            'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ProfileSaveGeneration"\s*,\s*_generation\s*\]',
            'if\s*\(\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ProfileSaveScheduled"\s*,\s*false\s*\]\s*\)\s*exitWith',
            'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ProfileSaveScheduled"\s*,\s*true\s*\]',
            'while\s*\{\s*true\s*\}\s*do',
            '\buiSleep\s+0\.25',
            'private\s+_flushGeneration\s*=\s*localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ProfileSaveGeneration"',
            'saveProfileNamespace',
            'private\s+_repeat\s*=\s*false',
            'isNil\s*\{',
            'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ProfileSaveGeneration"[\s\S]{0,100}isEqualTo\s+_flushGeneration',
            'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ProfileSaveScheduled"\s*,\s*false\s*\]',
            '_repeat\s*=\s*true',
            'if\s*\(\s*!_repeat\s*\)\s*exitWith'
        )) `
        -and ([regex]::Matches($arsenal, 'A4A_fnc_arsenal_scheduleProfileSave')).Count -ge 2 `
        -and $cargoToArsenal -match 'A4A_fnc_arsenal_scheduleProfileSave' `
        -and $requestClose -match 'A4A_fnc_arsenal_scheduleProfileSave' `
        -and $saveRequest -match 'A4A_fnc_arsenal_scheduleProfileSave' `
        -and $profileSave -notmatch '(?im)^\s*sleep\s+0\.25')

$actionPath = Join-Path $root "source/A4A_Arsenal/JNA/fn_arsenal_handleAction.sqf"
$actionBytes = [System.IO.File]::ReadAllBytes($actionPath)
$actionTextLatin1 = [System.Text.Encoding]::GetEncoding(28591).GetString($actionBytes)
Add-Check "action handler has no CRCRLF or bare-CR corruption" `
    ($actionTextLatin1 -notmatch "`r`r`n" -and $actionTextLatin1 -notmatch "`r(?!`n)")

$failed = @($checks | Where-Object { -not $_.Pass })
if ($failed.Count -gt 0) {
    $failed | ForEach-Object { Write-Host ("STATIC FAIL: " + $_.Name) }
    Write-Host ("STATIC FAILED: {0}/{1} source-integrity checks" -f $failed.Count, $checks.Count)
    exit 1
}

Write-Host ("STATIC PASS: {0} source-integrity invariants matched" -f $checks.Count)
