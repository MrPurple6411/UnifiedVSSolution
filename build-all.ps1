#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Comprehensive build script for all UnifiedSubnautica configurations
.DESCRIPTION
    This script regenerates solution filters and builds both Subnautica and BelowZero configurations.
    It ensures all projects are included based on current Build.0 entries in the solution file.
.PARAMETER SkipRegenerate
    Skip regenerating solution filters (use existing ones)
.PARAMETER Subnautica
    Build only Subnautica configuration
.PARAMETER BelowZero
    Build only BelowZero configuration
.PARAMETER Verbose
    Enable verbose build output
.PARAMETER Clean
    Clean before building
.PARAMETER Rebuild
    Clean and then build (combines Clean + Build)
.PARAMETER Project
    One or more project name/path fragments to filter. If provided, only matching projects will be built.
.EXAMPLE
    .\build-all.ps1
    .\build-all.ps1 -Subnautica
    .\build-all.ps1 -BelowZero
    .\build-all.ps1 -Verbose -Clean
    .\build-all.ps1 -Rebuild
#>

param(
    [switch]$SkipRegenerate,
    [switch]$Subnautica,
    [switch]$BelowZero,
    [switch]$Verbose,
    [switch]$Clean,
    [switch]$Rebuild,
    # Build only a subset of projects by name or path fragment (case-insensitive). Example: -Project AutoScanningChip, CopperFromScanning
    [string[]]$Project
)

$ErrorActionPreference = "Stop"

# Resolve script directory and generator paths for reliability across job runspaces
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$genSNPath = Join-Path $scriptDir 'GenerateSubnauticaSlnf.ps1'
$genBZPath = Join-Path $scriptDir 'GenerateBelowZeroSlnf.ps1'

# Determine if we're doing a selective build based on project filters
$isSelective = ($Project -and $Project.Count -gt 0)

# Parse configurations to build
$configs = @()
if ($Subnautica -and -not $BelowZero) {
    $configs = @("Subnautica")
} elseif ($BelowZero -and -not $Subnautica) {
    $configs = @("BelowZero")
} else {
    # Default: build both if no specific configuration is specified, or if both are specified
    $configs = @("Subnautica", "BelowZero")
}

Write-Host "UnifiedSubnautica Batch Build Script" -ForegroundColor Cyan
Write-Host "Configurations to build: $($configs -join ', ')" -ForegroundColor Yellow

# Step 1: Regenerate solution filters (unless skipped)
if (-not $SkipRegenerate) {
    Write-Host "`nStep 1: Regenerating solution filters..." -ForegroundColor Green

    $doSubnautica = $configs -contains "Subnautica"
    $doBelowZero = $configs -contains "BelowZero"

    # If both configurations are selected, generate in parallel to save time
    if ($doSubnautica -and $doBelowZero) {
        Write-Host "  Running Subnautica.slnf and BelowZero.slnf generation in parallel..." -ForegroundColor Yellow

        $jobs = @()
        $jobs += Start-Job -Name "Gen-SN" -ScriptBlock {
            param($quiet, $genPath, $workDir)
            Set-Location $workDir
            if ($quiet) { & $genPath -Quiet } else { & $genPath }
        } -ArgumentList @($isSelective, $genSNPath, $scriptDir)

        $jobs += Start-Job -Name "Gen-BZ" -ScriptBlock {
            param($quiet, $genPath, $workDir)
            Set-Location $workDir
            if ($quiet) { & $genPath -Quiet } else { & $genPath }
        } -ArgumentList @($isSelective, $genBZPath, $scriptDir)

        Wait-Job -Job $jobs | Out-Null

        $failed = $false
        foreach ($j in $jobs) {
            if ($j.State -ne 'Completed') { $failed = $true }
            # surface any job errors
            $errs = ($j.ChildJobs | ForEach-Object { $_.Error })
            if ($errs -and $errs.Count -gt 0) { $failed = $true }
            Receive-Job -Job $j | ForEach-Object { if ($_) { Write-Host "  [$($j.Name)] $_" -ForegroundColor DarkGray } }
            Remove-Job -Job $j -Force | Out-Null
        }

        # Verify files exist
        if (-not (Test-Path 'Subnautica.slnf')) { $failed = $true; Write-Host "  Missing Subnautica.slnf after generation" -ForegroundColor Red }
        if (-not (Test-Path 'BelowZero.slnf')) { $failed = $true; Write-Host "  Missing BelowZero.slnf after generation" -ForegroundColor Red }

        if ($failed) {
            Write-Host "FAILED to generate solution filters" -ForegroundColor Red
            exit 1
        }
    }
    else {
        if ($doSubnautica) {
            Write-Host "  Generating Subnautica.slnf..." -ForegroundColor Yellow
            if ($isSelective) { & $genSNPath -Quiet } else { & $genSNPath }
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path 'Subnautica.slnf')) {
                Write-Host "FAILED to generate Subnautica solution filter" -ForegroundColor Red
                exit 1
            }
        }
        if ($doBelowZero) {
            Write-Host "  Generating BelowZero.slnf..." -ForegroundColor Yellow
            if ($isSelective) { & $genBZPath -Quiet } else { & $genBZPath }
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path 'BelowZero.slnf')) {
                Write-Host "FAILED to generate BelowZero solution filter" -ForegroundColor Red
                exit 1
            }
        }
    }

    Write-Host "SUCCESS: Solution filters regenerated successfully" -ForegroundColor Green
} else {
    Write-Host "`nSkipping solution filter regeneration (using existing filters)" -ForegroundColor Yellow
}

# Step 2: Clean if requested
if ($Clean -or $Rebuild) {
    Write-Host "`nStep 2: Cleaning previous builds..." -ForegroundColor Green
    
    # First try dotnet clean
    dotnet clean UnifiedVSSolution.sln
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: dotnet clean failed, continuing anyway..." -ForegroundColor Yellow
    }
    
    # Then manually remove bin and obj directories for thorough clean
    Write-Host "  Removing bin and obj directories..." -ForegroundColor Yellow
    if (Test-Path "bin") {
        Remove-Item -Path "bin" -Recurse -Force
        Write-Host "  Removed bin directory" -ForegroundColor Cyan
    }
    if (Test-Path "obj") {
        Remove-Item -Path "obj" -Recurse -Force  
        Write-Host "  Removed obj directory" -ForegroundColor Cyan
    }
    
    # Also clean project-specific obj directories
    $objDirs = @(Get-ChildItem -Path "." -Recurse -Directory -Name "obj" -ErrorAction SilentlyContinue)
    if ($objDirs.Count -gt 0) {
        foreach ($objDir in $objDirs) {
            $objPath = Join-Path $PWD $objDir
            if (Test-Path $objPath) {
                Remove-Item -Path $objPath -Recurse -Force
                Write-Host "  Removed $objPath" -ForegroundColor Cyan
            }
        }
    }
    
    # Clean zip directories (both inside solution and legacy outside locations)
    Write-Host "  Removing zip directories..." -ForegroundColor Yellow
    $zipDirs = @("Zips_Subnautica", "Zips_BelowZero", "..\Zips_Subnautica", "..\Zips_BelowZero")
    foreach ($zipDir in $zipDirs) {
        if (Test-Path $zipDir) {
            Remove-Item -Path $zipDir -Recurse -Force
            Write-Host "  Removed $zipDir" -ForegroundColor Cyan
        }
    }
    
    Write-Host "  Clean completed" -ForegroundColor Green
    
    # Verify cleanup
    Write-Host "`nStep 3: Verifying cleanup..." -ForegroundColor Green
    
    $binExists = Test-Path "bin"
    $objExists = Test-Path "obj"
    $remainingObjDirs = @(Get-ChildItem -Path "." -Recurse -Directory -Name "obj" -ErrorAction SilentlyContinue)
    $zipSubnauticaExists = Test-Path "Zips_Subnautica"
    $zipBelowZeroExists = Test-Path "Zips_BelowZero"
    
    Write-Host "  bin directory exists: $binExists" -ForegroundColor $(if ($binExists) { "Red" } else { "Green" })
    Write-Host "  obj directory exists: $objExists" -ForegroundColor $(if ($objExists) { "Red" } else { "Green" })
    Write-Host "  Remaining obj directories: $($remainingObjDirs.Count)" -ForegroundColor $(if ($remainingObjDirs.Count -gt 0) { "Red" } else { "Green" })
    Write-Host "  Zips_Subnautica exists: $zipSubnauticaExists" -ForegroundColor $(if ($zipSubnauticaExists) { "Red" } else { "Green" })
    Write-Host "  Zips_BelowZero exists: $zipBelowZeroExists" -ForegroundColor $(if ($zipBelowZeroExists) { "Red" } else { "Green" })
    
    if ($remainingObjDirs.Count -gt 0) {
        Write-Host "  Found obj directories:" -ForegroundColor Yellow
        $remainingObjDirs | ForEach-Object {
            $fullPath = Get-ChildItem -Path "." -Recurse -Directory -Filter "obj" | Where-Object { $_.Name -eq $_ } | Select-Object -First 1
            Write-Host "    $($fullPath.FullName)" -ForegroundColor Yellow
        }
    }
    
    $cleanSuccess = -not $binExists -and -not $objExists -and $remainingObjDirs.Count -eq 0 -and -not $zipSubnauticaExists -and -not $zipBelowZeroExists
    
    if ($cleanSuccess) {
        Write-Host "`nSUCCESS: All build artifacts have been cleaned!" -ForegroundColor Green
    } else {
        Write-Host "`nWARNING: Some build artifacts may remain" -ForegroundColor Yellow
    }
    
    # If only cleaning (not rebuilding), exit here
    if ($Clean -and -not $Rebuild) {
        exit 0
    }
}

# Step 3: Build configurations (skip if only cleaning)
if (-not $Clean -or $Rebuild) {
    $buildResults = @()
    $totalStartTime = Get-Date

    foreach ($config in $configs) {
    $configStartTime = Get-Date
    Write-Host "`nBuilding $config configuration..." -ForegroundColor Green
    
    $slnfFile = "$config.slnf"
    if (-not (Test-Path $slnfFile)) {
        Write-Host "ERROR: Solution filter $slnfFile not found!" -ForegroundColor Red
        $buildResults += [PSCustomObject]@{
            Configuration = $config
            Status = "Failed"
            Error = "Solution filter not found"
            Duration = "N/A"
            ProjectCount = 0
        }
        continue
    }
    
    # If selective mode is enabled, generate a temporary filtered solution filter with only the requested projects
    $slnfToBuild = $slnfFile
    $matchedCount = $null
    if ($isSelective) {
        if (-not $Project -or $Project.Count -eq 0) {
            Write-Host "ERROR: Project filters were expected but none were provided." -ForegroundColor Red
            $buildResults += [PSCustomObject]@{
                Configuration = $config
                Status = "Failed"
                Error = "Selective build requested without any project filters"
                Duration = "00:00"
                ProjectCount = 0
            }
            continue
        }

        try {
            $json = Get-Content -Raw -Path $slnfFile | ConvertFrom-Json
        }
        catch {
            Write-Host "ERROR: Failed to parse $slnfFile as JSON: $_" -ForegroundColor Red
            $buildResults += [PSCustomObject]@{
                Configuration = $config
                Status = "Failed"
                Error = "Invalid slnf JSON"
                Duration = "00:00"
                ProjectCount = 0
            }
            continue
        }

        $allProjects = @($json.solution.projects)
        # Normalize filters: split comma-delimited entries and trim whitespace
        $filters = @()
        foreach ($arg in $Project) {
            if ($null -ne $arg) {
                $parts = $arg -split ','
                foreach ($p2 in $parts) {
                    $t = $p2.Trim()
                    if (-not [string]::IsNullOrWhiteSpace($t)) { $filters += $t }
                }
            }
        }
        $filtered = @()

        foreach ($p in $allProjects) {
            $pNoExt = [System.IO.Path]::GetFileNameWithoutExtension($p)
            foreach ($f in $filters) {
                if ([string]::IsNullOrWhiteSpace($f)) { continue }
                if ($p -like "*${f}*" -or $pNoExt.Equals($f, [System.StringComparison]::InvariantCultureIgnoreCase)) {
                    $filtered += $p
                    break
                }
            }
        }

        # Ensure uniqueness
    $filtered = $filtered | Sort-Object -Unique

        if ($filtered.Count -eq 0) {
            Write-Host "  Selective build: no projects matched for $config. Skipping this configuration." -ForegroundColor Yellow
            $buildResults += [PSCustomObject]@{
                Configuration = $config
                Status = "Skipped"
                Error = "No matching projects for selective build"
                Duration = "00:00"
                ProjectCount = 0
            }
            continue
        }

        Write-Host "  Selective build enabled. Projects matched ($($filtered.Count)):" -ForegroundColor Yellow
        foreach ($fp in $filtered) { Write-Host "    $fp" -ForegroundColor DarkYellow }

        $selectiveObj = [PSCustomObject]@{
            solution = [PSCustomObject]@{
                path = $json.solution.path
                projects = @($filtered)
            }
        }

        $selectivePath = "$config.selective.slnf"
        $selectiveObj | ConvertTo-Json -Depth 5 | Out-File -FilePath $selectivePath -Encoding UTF8
        $slnfToBuild = $selectivePath
        $matchedCount = $filtered.Count
    }

    # Build command
    $buildArgs = @("build", $slnfToBuild, "--configuration", $config)
    if ($Verbose) {
        $buildArgs += "--verbosity", "detailed"
    }
    
    Write-Host "  Executing: dotnet $($buildArgs -join ' ')" -ForegroundColor Cyan
    
    # Execute build
    & dotnet @buildArgs
    $buildExitCode = $LASTEXITCODE
    $configEndTime = Get-Date
    $duration = $configEndTime - $configStartTime
    
    # Check results        
    if ($buildExitCode -eq 0) {
        # Count built projects
    if ($isSelective -and $null -ne $matchedCount) {
            $projectCount = [int]$matchedCount
        } else {
            $binPath = "bin\$config"
            $projectCount = 0
            if (Test-Path $binPath) {
                $projectCount = (Get-ChildItem -Path $binPath -Filter "*.dll" -Recurse | Where-Object { $_.Directory.Name -eq $_.BaseName }).Count
            }
        }
        
        Write-Host "SUCCESS: $config build completed successfully!" -ForegroundColor Green
        Write-Host "   Projects built: $projectCount" -ForegroundColor Cyan
        Write-Host "   Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Cyan
        
        $buildResults += [PSCustomObject]@{
            Configuration = $config
            Status = "Success"
            Error = $null
            Duration = $duration.ToString('mm\:ss')
            ProjectCount = $projectCount
        }
    } else {
        Write-Host "FAILED: $config build failed (exit code: $buildExitCode)" -ForegroundColor Red
        
        $buildResults += [PSCustomObject]@{
            Configuration = $config
            Status = "Failed"
            Error = "Build failed with exit code $buildExitCode"
            Duration = $duration.ToString('mm\:ss')
            ProjectCount = 0
        }
    }
    }

    # Step 4: Summary
    $totalEndTime = Get-Date
    $totalDuration = $totalEndTime - $totalStartTime

    Write-Host "`nBuild Summary" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan

    $buildResults | ForEach-Object {
        $statusColor = if ($_.Status -eq "Success") { "Green" } else { "Red" }
        $statusIcon = if ($_.Status -eq "Success") { "[SUCCESS]" } else { "[FAILED]" }
        
        if ($_.Status -eq "Skipped") {
            Write-Host "[SKIPPED] $($_.Configuration): No matching projects" -ForegroundColor Yellow
        } elseif ($_.Status -eq "Success") {
            Write-Host "$statusIcon $($_.Configuration): $($_.Status)" -ForegroundColor $statusColor
            Write-Host "   Projects: $($_.ProjectCount), Duration: $($_.Duration)" -ForegroundColor Gray
        } else {
            Write-Host "$statusIcon $($_.Configuration): $($_.Status)" -ForegroundColor $statusColor
            Write-Host "   Error: $($_.Error)" -ForegroundColor Red
        }
    }

    Write-Host "`nTotal Duration: $($totalDuration.ToString('mm\:ss'))" -ForegroundColor Cyan

    # Final exit code
    $failedBuilds = $buildResults | Where-Object { $_.Status -eq "Failed" }
    if ($failedBuilds.Count -gt 0) {
        Write-Host "`nFAILED: $($failedBuilds.Count) configuration(s) failed to build" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "`nSUCCESS: All configurations built successfully!" -ForegroundColor Green
        exit 0
    }
}
