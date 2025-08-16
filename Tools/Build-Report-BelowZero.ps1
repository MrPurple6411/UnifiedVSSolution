<#!
.SYNOPSIS
  Builds Below Zero configuration and generates a per-project compile status report (Markdown + JSON).

.DESCRIPTION
  Runs the existing build-all.ps1 with -BelowZero, tees output to docs/build-logs, parses per-project results
  from the standard "succeeded/failed" lines, and writes a summary matrix to docs/build-status/BelowZero.

.NOTES
  Windows PowerShell 5.1 compatible. No emoji in output.
#>

[CmdletBinding()]
param(
  [switch]$Clean,
  [switch]$Rebuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSCommandPath
$repo = Resolve-Path (Join-Path $root '..')
Set-Location $repo

$ts = Get-Date -Format yyyyMMdd-HHmmss
$logsDir = Join-Path $repo 'docs/build-logs'
$statusDir = Join-Path $repo 'docs/build-status/BelowZero'
New-Item -ItemType Directory -Force -Path $logsDir, $statusDir | Out-Null

$logFile = Join-Path $logsDir ("BelowZero-" + $ts + '.log')

$buildArgs = @('-BelowZero','-Verbose')
if ($Clean)   { $buildArgs += '-Clean' }
if ($Rebuild) { $buildArgs += '-Rebuild' }

Write-Host "CHECKING: Running build-all.ps1 $($buildArgs -join ' ')"

# Run build and tee output
$last = & powershell -NoProfile -ExecutionPolicy Bypass -Command ".\build-all.ps1 $($buildArgs -join ' ') *>&1 | Tee-Object -FilePath '$logFile'" | Out-String

function Get-AssemblyNameFromCsproj([string]$csprojPath) {
  try {
    [xml]$xml = Get-Content -LiteralPath $csprojPath -Raw
    $asm = $xml.Project.PropertyGroup.AssemblyName | Where-Object { $_ -and $_.Trim() -ne '' } | Select-Object -First 1
    if ($asm) { return [string]$asm }
  } catch {}
  return [System.IO.Path]::GetFileNameWithoutExtension($csprojPath)
}

# Enumerate projects from BelowZero.slnf
$slnfPath = Join-Path $repo 'BelowZero.slnf'
if (-not (Test-Path $slnfPath)) { throw "BelowZero.slnf not found at $slnfPath" }
$slnfJson = Get-Content -LiteralPath $slnfPath -Raw | ConvertFrom-Json
$projectRelPaths = @()
if ($slnfJson.solution -and $slnfJson.solution.projects) {
  $projectRelPaths = @($slnfJson.solution.projects)
} elseif ($slnfJson.projects) {
  $projectRelPaths = @($slnfJson.projects)
}

$projects = @()
foreach ($rel in $projectRelPaths) {
  if (-not $rel) { continue }
  $csproj = Join-Path $repo $rel
  if (-not (Test-Path $csproj)) { continue }
  $projName = [System.IO.Path]::GetFileNameWithoutExtension($csproj)
  $asmName = Get-AssemblyNameFromCsproj $csproj
  $dllPath = Join-Path $repo ("bin/BelowZero/$projName/$asmName.dll")
  $projDir = Split-Path -Parent $csproj
  $projects += [PSCustomObject]@{ Name=$projName; Assembly=$asmName; Csproj=$csproj; Dll=$dllPath; Dir=$projDir }
}

# Determine per-project status by presence of output DLL
$results = @{}
foreach ($p in $projects) {
  $results[$p.Name] = if (Test-Path $p.Dll) { 'succeeded' } else { 'failed' }
}

# Collect error lines per failing project from log
$logLines = Get-Content -LiteralPath $logFile
$errorsByProject = @{}
foreach ($p in $projects | Where-Object { $results[$_.Name] -eq 'failed' }) {
  $projErrors = New-Object System.Collections.Generic.List[string]
  $pathPattern = [regex]::Escape($p.Dir) + '\\'
  $namePattern = '(?i)\b' + [regex]::Escape($p.Name) + '\b'
  foreach ($line in $logLines) {
    if ($line -match ' error ' -and ($line -match $pathPattern -or $line -match $namePattern)) {
      $projErrors.Add($line)
    }
    if ($projErrors.Count -ge 5) { break }
  }
  if ($projErrors.Count -eq 0) {
    foreach ($line in $logLines) {
      if ($line -match ' error ') { $projErrors.Add($line) }
      if ($projErrors.Count -ge 3) { break }
    }
  }
  $errorsByProject[$p.Name] = $projErrors.ToArray()
}

$summary = [System.Collections.Generic.List[object]]::new()
foreach ($p in $projects | Sort-Object Name) {
  $name = $p.Name
  $state = $results[$name]
  $err   = if ($errorsByProject.ContainsKey($name)) { $errorsByProject[$name] } else { @() }
  $summary.Add([PSCustomObject]@{ project=$name; assembly=$p.Assembly; status=$state; sampleErrors=$err })
}

$jsonPath = Join-Path $statusDir ('summary-' + $ts + '.json')
$mdPath   = Join-Path $statusDir ('summary-' + $ts + '.md')

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$rows = @("| Project | Status | Notes |","|---|---|---|")
foreach ($row in $summary) {
  $errLines = @()
  if ($row.sampleErrors) { $errLines = @($row.sampleErrors) }
  $note = if ($errLines.Count -gt 0) { ($errLines -join '<br>') } else { '' }
  $rows += "| $($row.project) | $($row.status.ToUpper()) | $note |"
}
$rows | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host "SUCCESS: Wrote $jsonPath"
Write-Host "SUCCESS: Wrote $mdPath"
Write-Host "SUCCESS: Build log at $logFile"
