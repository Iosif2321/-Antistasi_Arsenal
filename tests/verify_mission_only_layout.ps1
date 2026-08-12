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
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host "FAIL: $failure"
    }
    Write-Host ("MISSION LAYOUT FAIL: {0}/{1}" -f $failures.Count, ($passes.Count + $failures.Count))
    exit 1
}

Write-Host ("MISSION LAYOUT PASS: {0}" -f $passes.Count)

