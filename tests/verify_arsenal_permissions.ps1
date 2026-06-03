$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Read-ProjectFile {
    param([string]$RelativePath)
    Get-Content -LiteralPath (Join-Path $root $RelativePath) -Raw
}

$config = Read-ProjectFile "source/A4A_Arsenal/config.cpp"
$init = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal_init.sqf"
$arsenal = Read-ProjectFile "source/A4A_Arsenal/JNA/fn_arsenal.sqf"
$logic = Read-ProjectFile "source/A4A_Arsenal/functions/fn_arsenalLogic.sqf"
$stub = Read-ProjectFile "source/A4A_Arsenal/functions/fn_A4A_stub.sqf"
$canEditPath = Join-Path $root "source/A4A_Arsenal/functions/fn_arsenal_canEdit.sqf"
$canEdit = if (Test-Path -LiteralPath $canEditPath) {
    Get-Content -LiteralPath $canEditPath -Raw
} else {
    ""
}

$checks = @(
    @{
        Name = "canEdit function file exists"
        Pass = Test-Path -LiteralPath $canEditPath
    },
    @{
        Name = "canEdit function is registered"
        Pass = $config -match "class\s+arsenal_canEdit\s*\{\s*\};"
    },
    @{
        Name = "arsenal init edit actions use canEdit"
        Pass = $init -match "A4A_fnc_arsenal_canEdit" -and $init -notmatch "A4A_fnc_arsenal_isZeus"
    },
    @{
        Name = "arsenal UI editor/import paths use canEdit"
        Pass = $arsenal -match 'case "ExportData": \{[\s\S]*?A4A_fnc_arsenal_canEdit' `
            -and $arsenal -match 'case "ImportData": \{[\s\S]*?A4A_fnc_arsenal_canEdit' `
            -and $arsenal -match 'case "EditorOpen": \{[\s\S]*?A4A_fnc_arsenal_canEdit' `
            -and $arsenal -match 'case "EditorModify": \{[\s\S]*?A4A_fnc_arsenal_canEdit' `
            -and $arsenal -match 'case "EditorSave": \{[\s\S]*?A4A_fnc_arsenal_canEdit' `
            -and $arsenal -notmatch 'case "EditorOpen": \{[\s\S]*?A4A_fnc_arsenal_isZeus'
    },
    @{
        Name = "server-side editor save checks canEdit"
        Pass = $logic -match 'case "SAVE_JNA": \{[\s\S]*?A4A_fnc_arsenal_canEdit'
    },
    @{
        Name = "CBA settings expose editor SteamIDs and access mode"
        Pass = $stub -match "A4A_Arsenal_EditorSteamIDs" `
            -and $stub -match '"EDITBOX"' `
            -and $stub -match "A4A_Arsenal_EditAccessMode" `
            -and $stub -match '"SteamID Only"' `
            -and $stub -match '"SteamID \+ Zeus"'
    },
    @{
        Name = "canEdit requires SteamID allowlist"
        Pass = $canEdit -match "A4A_Arsenal_EditorSteamIDs" `
            -and $canEdit -match "A4A_Arsenal_EditorUIDs" `
            -and $canEdit -match "getPlayerUID" `
            -and $canEdit -match "_playerUID\s+in\s+_allowedSteamIDs" `
            -and $canEdit -match "count\s+_allowedSteamIDs\)\s*==\s*0\)\s*exitWith\s*\{\s*false\s*\}"
    },
    @{
        Name = "canEdit supports SteamID-only and SteamID-plus-Zeus modes"
        Pass = $canEdit -match "A4A_Arsenal_EditAccessMode" `
            -and $canEdit -match "A4A_fnc_arsenal_isZeus" `
            -and $canEdit -match "_requiresZeus"
    }
)

$failed = $checks | Where-Object { -not $_.Pass }
if ($failed.Count -gt 0) {
    $failed | ForEach-Object { Write-Host ("FAIL: " + $_.Name) }
    exit 1
}

Write-Host "PASS: Arsenal edit permission checks are wired"
