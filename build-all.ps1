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
    [switch]$Rebuild
)

$ErrorActionPreference = "Stop"

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
    
    if ($configs -contains "Subnautica") {
        Write-Host "  Generating Subnautica.slnf..." -ForegroundColor Yellow
        & .\GenerateSubnauticaSlnf.ps1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FAILED to generate Subnautica solution filter" -ForegroundColor Red
            exit 1
        }
    }
    
    if ($configs -contains "BelowZero") {
        Write-Host "  Generating BelowZero.slnf..." -ForegroundColor Yellow
        & .\GenerateBelowZeroSlnf.ps1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FAILED to generate BelowZero solution filter" -ForegroundColor Red
            exit 1
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
    
    # Build command
    $buildArgs = @("build", $slnfFile, "--configuration", $config)
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
        $binPath = "bin\$config"
        $projectCount = 0
        if (Test-Path $binPath) {
            $projectCount = (Get-ChildItem -Path $binPath -Filter "*.dll" -Recurse | Where-Object { $_.Directory.Name -eq $_.BaseName }).Count
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
        
        Write-Host "$statusIcon $($_.Configuration): $($_.Status)" -ForegroundColor $statusColor
        if ($_.Status -eq "Success") {
            Write-Host "   Projects: $($_.ProjectCount), Duration: $($_.Duration)" -ForegroundColor Gray
        } else {
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
