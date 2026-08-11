$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Read-ProjectFile {
    param([string]$RelativePath)
    Get-Content -LiteralPath (Join-Path $root $RelativePath) -Raw
}

function Get-SourceSection {
    param(
        [string]$Text,
        [string]$StartPattern,
        [string]$EndPattern
    )

    $match = [regex]::Match($Text, "(?ms)$StartPattern(?<Body>.*?)$EndPattern")
    if (-not $match.Success) { return "" }
    $match.Groups["Body"].Value
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
        $match = [regex]::Match($Text.Substring($offset), $pattern, $options)
        if (-not $match.Success) { return $false }
        $offset += $match.Index + $match.Length
    }
    $true
}

$config = Read-ProjectFile "source/A4A_Arsenal/config.cpp"
$stub = Read-ProjectFile "source/A4A_Arsenal/functions/fn_A4A_stub.sqf"
$cargoToArray = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_cargoToArray.sqf"
$itemType = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_itemType.sqf"
$arsenal = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal.sqf"
$requestOpen = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_requestOpen.sqf"
$addItem = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_addItem.sqf"
$removeItem = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_removeItem.sqf"

$updateItemAdd = Get-SourceSection $arsenal `
    '^\s*case\s+"UpdateItemAdd"\s*:\s*\{' `
    '^\s*case\s+"UpdateItemRemove"\s*:'
$updateItemRemove = Get-SourceSection $arsenal `
    '^\s*case\s+"UpdateItemRemove"\s*:\s*\{' `
    '^\s*case\s+"UpdateItemGui"\s*:'
$nonPlayerWeaponCargo = Get-SourceSection $cargoToArray `
    '^\s*\}\s+foreach\s+_attItems\s*;\s*\r?\n\s*\}\s+else\s*\{' `
    '^\s*if\s*\(\s*_isPlayer\s*\)\s*then\s*\{\s*$'
$privateUpdateCommitPatterns = @(
    'localNamespace\s+getVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*createHashMap\s*\]',
    'private\s+_targetData\s*=\s*\+\s*\(?\s*_serverData\s+getOrDefault\s*\[\s*_arsenalID',
    '_targetData\s+set\s*\[',
    '_serverData\s+set\s*\[\s*_arsenalID\s*,\s*_targetData\s*\]',
    'localNamespace\s+setVariable\s*\[\s*"A4A_Arsenal_ServerData"\s*,\s*_serverData\s*\]',
    'server\s+setVariable\s*\[\s*_serverKey\s*,\s*_targetData\s*\]'
)

$checks = @(
    @{
        Name = "non-player cargo preserves physical weapon base, components, and loaded rounds"
        Pass = Test-PatternsInOrder $nonPlayerWeaponCargo @(
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
        )
    },
    @{
        Name = "player inventory extraction can still inspect equipped weapon items"
        Pass = $cargoToArray -match "weaponsItems\s+_container_sub"
    },
    @{
        Name = "itemType uses safe arsenal data lookup"
        Pass = $itemType -notmatch "_data\s+select\s+_index" `
            -and $itemType -match "_data\s+param\s+\[\s*_index\s*,\s*\[\]\s*\]"
    },
    @{
        Name = "CBA settings are registered through addon preInit XEH"
        Pass = $config -match "class\s+Extended_PreInit_EventHandlers" `
            -and $config -match "A4A_fnc_A4A_stub"
    },
    @{
        Name = "CBA settings registration is guarded against duplicate calls"
        Pass = $stub -match "A4A_Arsenal_CBASettingsRegistered" `
            -and $stub -match "A4A_Arsenal_ContainerAccess" `
            -and $stub -match "A4A_Arsenal_EditAccessMode" `
            -and $stub -match "A4A_Arsenal_EditorSteamIDs" `
            -and $stub -match "A4A_Arsenal_UnlockThreshold"
    },
    @{
        Name = "CBA unlock threshold slider allows up to 25000 items"
        Pass = $stub -match "\[1,\s*25000,\s*25,\s*0\]"
    },
    @{
        Name = "hosted server arsenal open uses a local data copy"
        Pass = $requestOpen -match "jna_dataList\s*=\s*\+_data"
    },
    @{
        Name = "server item updates copy private canonical data before updating server-local compatibility mirrors"
        Pass = (Test-PatternsInOrder $updateItemAdd $privateUpdateCommitPatterns) `
            -and (Test-PatternsInOrder $updateItemRemove $privateUpdateCommitPatterns) `
            -and $updateItemAdd -notmatch '\bserver\s+getVariable\b' `
            -and $updateItemRemove -notmatch '\bserver\s+getVariable\b' `
            -and $updateItemAdd -notmatch 'server\s+setVariable\s*\[\s*_serverKey\s*,\s*_targetData\s*,\s*true\s*\]' `
            -and $updateItemRemove -notmatch 'server\s+setVariable\s*\[\s*_serverKey\s*,\s*_targetData\s*,\s*true\s*\]'
    },
    @{
        Name = "hosted server addItem does not pre-apply local data before server update"
        Pass = $addItem -match 'if\s*\(\s*!isServer\s*&&\s*\{\s*!isNil\s+"jna_dataList"\s*\}\s*\)\s*then\s*\{\s*jna_dataList\s+set\s*\[\s*_index\s*,[\s\S]*?call\s+jn_fnc_arsenal_addToArray\s*\]\s*;\s*\}' `
            -and ([regex]::Matches($addItem, '(?i)jna_dataList\s+set\s*\[')).Count -eq 1
    },
    @{
        Name = "hosted server removeItem does not pre-apply local data before server update"
        Pass = $removeItem -match 'if\s*\(\s*!isServer\s*&&\s*\{\s*!isNil\s+"jna_dataList"\s*\}\s*\)\s*then\s*\{\s*jna_dataList\s+set\s*\[\s*_index\s*,[\s\S]*?call\s+jn_fnc_arsenal_removeFromArray\s*\]\s*;\s*\}' `
            -and ([regex]::Matches($removeItem, '(?i)jna_dataList\s+set\s*\[')).Count -eq 1
    },
    @{
        Name = "itemType prefers magazine config for magazine classes that also exist in CfgWeapons"
        Pass = $itemType -match "_preferMagazineConfig" `
            -and $itemType -match "case\s*\([^)]*_preferMagazineConfig"
    }
)

$failed = $checks | Where-Object { -not $_.Pass }
if ($failed.Count -gt 0) {
    $failed | ForEach-Object { Write-Host ("STATIC FAIL: " + $_.Name) }
    exit 1
}

Write-Host "STATIC PASS: Arsenal cargo, itemType, and CBA setting source regressions are covered"
