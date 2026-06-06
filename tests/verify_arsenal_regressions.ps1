$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Read-ProjectFile {
    param([string]$RelativePath)
    Get-Content -LiteralPath (Join-Path $root $RelativePath) -Raw
}

$config = Read-ProjectFile "source/A4A_Arsenal/config.cpp"
$stub = Read-ProjectFile "source/A4A_Arsenal/functions/fn_A4A_stub.sqf"
$cargoToArray = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_cargoToArray.sqf"
$itemType = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_itemType.sqf"
$arsenal = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal.sqf"
$requestOpen = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_requestOpen.sqf"
$addItem = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_addItem.sqf"
$removeItem = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_removeItem.sqf"

$checks = @(
    @{
        Name = "container cargo transfer does not split weapon cargo attachments or loaded magazines"
        Pass = $cargoToArray -notmatch "weaponsItemsCargo\s+_container_sub"
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
        Name = "hosted server arsenal open uses a local data copy"
        Pass = $requestOpen -match "jna_dataList\s*=\s*\+_data"
    },
    @{
        Name = "server item updates copy persistent data before mutating it"
        Pass = ([regex]::Matches($arsenal, [regex]::Escape("private _targetData = +(server getVariable")).Count -ge 2)
    },
    @{
        Name = "hosted server addItem does not pre-apply local data before server update"
        Pass = $addItem -match 'if\s*\(!isServer\s*&&\s*\{!isNil "jna_dataList"\}\)\s*then\s*\{'
    },
    @{
        Name = "hosted server removeItem does not pre-apply local data before server update"
        Pass = $removeItem -match 'if\s*\(!isServer\s*&&\s*\{!isNil "jna_dataList"\}\)\s*then\s*\{'
    },
    @{
        Name = "itemType prefers magazine config for magazine classes that also exist in CfgWeapons"
        Pass = $itemType -match "_preferMagazineConfig" `
            -and $itemType -match "case\s*\([^)]*_preferMagazineConfig"
    }
)

$failed = $checks | Where-Object { -not $_.Pass }
if ($failed.Count -gt 0) {
    $failed | ForEach-Object { Write-Host ("FAIL: " + $_.Name) }
    exit 1
}

Write-Host "PASS: Arsenal cargo, itemType, and CBA setting regressions are covered"
