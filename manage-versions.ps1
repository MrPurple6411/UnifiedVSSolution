# Mod Version Management Script
# Generates and maintains a clean, GitHub-friendly mod version tracking system

param(
    [switch]$GenerateInitial,    # Generate initial version file from current builds
    [switch]$CheckForChanges,    # Check current builds against version file
    [switch]$UpdateVersions,     # Update version file with new hashes and increment versions
    [switch]$SyncOnline,         # Full online sync: fetch baseline, selective rebuild, bump versions, optional commit/push

    # Online baseline source (defaults to this repo's main branch)
    [string]$RepoOwner = "MrPurple6411",
    [string]$RepoName = "UnifiedVSSolution",
    [string]$Branch = "main",
    [string]$VersionFile = "mod-versions.json",

    # Build orchestration
    [switch]$SelectiveBuild,     # Build only configurations that differ from online baseline
    [switch]$OnlySubnautica,     # Limit to Subnautica configuration
    [switch]$OnlyBelowZero,      # Limit to BelowZero configuration
    [string]$BuildScript = ".\\build-all.ps1",

    # Git automation
    [switch]$CommitAndPush,      # Commit and push updated version file
    [string]$CommitMessage,      # Optional custom commit message

    # Safety/diagnostics
    [switch]$DryRun,             # Do not write file or push; just report actions
    [switch]$VerboseOutput       # Extra diagnostics
)

function Get-CurrentModHashes {
    $mods = @{}
    
    Get-ChildItem ".\bin" -Directory | ForEach-Object {
        $config = $_.Name
        $mods[$config] = @{}
        
        Get-ChildItem $_.FullName -Recurse -Filter "*.dll" | ForEach-Object {
            $modName = $_.Directory.Name
            $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
            $relativePath = $_.FullName.Replace((Get-Location).Path + "\", "").Replace("\", "/")
            
            $mods[$config][$modName] = @{
                hash = $hash
                dllPath = $relativePath
                lastChanged = $_.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
        }
    }
    
    return $mods
}

function Get-DefaultVersion {
    param($modName)
    
    # Try to extract version from project file or use default
    $possiblePaths = @(
        "MrPurple6411-Subnautica-Mods\$modName\*.csproj",
        "PrimeSonicSubnauticaMods\$modName\*.csproj",
        "*\$modName\*.csproj"
    )
    
    foreach ($pattern in $possiblePaths) {
        $projFile = Get-ChildItem $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($projFile) {
            $content = Get-Content $projFile.FullName -Raw
            if ($content -match '<Version>(.*?)</Version>') {
                return $matches[1]
            }
            if ($content -match '<AssemblyVersion>(.*?)</AssemblyVersion>') {
                return $matches[1]
            }
        }
    }
    
    return "1.0.0"  # Default version
}

function Increment-Version {
    param([string]$version)
    
    if ($version -match '(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3]
        return "$major.$minor.$($patch + 1)"
    }
    
    return "1.0.1"  # Fallback
}

function Format-Json2Space {
    param([Parameter(Mandatory=$true)][object]$Object)

    $jsonString = $Object | ConvertTo-Json -Depth 12
    $lines = $jsonString -split "`n"
    $formattedLines = @()
    $indentLevel = 0

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\}' -or $trimmed -match '^\]') { $indentLevel-- }
        $formattedLines += ("  " * $indentLevel) + $trimmed
        if ($trimmed -match '\{$' -or $trimmed -match '\[$') { $indentLevel++ }
    }

    return ($formattedLines -join "`n")
}

function Get-OnlineVersionData {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$BranchName,
        [string]$FilePath
    )

    $rawUrl = "https://raw.githubusercontent.com/$Owner/$Repo/$BranchName/$FilePath"
    Write-Host "CHECKING: Downloading online baseline from $rawUrl" -ForegroundColor Cyan
    try {
        $resp = Invoke-WebRequest -Uri $rawUrl -UseBasicParsing -ErrorAction Stop
        if ($resp.StatusCode -ne 200) {
            Write-Host "ERROR: Failed to fetch online baseline (HTTP $($resp.StatusCode))" -ForegroundColor Red
        } else {
            $content = $resp.Content
            # Heuristic: If content looks like HTML or is empty, treat as invalid
            if (-not $content -or $content.TrimStart().StartsWith('<')) {
                Write-Host "ERROR: Online content does not appear to be JSON (possible 404/html)" -ForegroundColor Red
            } else {
                try {
                    return ($content | ConvertFrom-Json)
                } catch {
                    Write-Host "ERROR: Failed to parse JSON content from raw URL: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
    catch {
        Write-Host "ERROR: Exception while fetching online baseline: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Fallback: use git to retrieve the file from the remote branch
    Write-Host "CHECKING: Attempting git fallback (origin/${BranchName}:${FilePath})" -ForegroundColor Yellow
    try {
        $null = git rev-parse --verify "origin/$BranchName" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Unable to verify origin/$BranchName. Ensure 'git fetch' has been run." -ForegroundColor Red
            return $null
        }
    $refspec = "origin/${BranchName}:${FilePath}"
    $gitContent = git show $refspec 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $gitContent) {
            Write-Host "ERROR: git show failed to retrieve $FilePath from origin/$BranchName" -ForegroundColor Red
            return $null
        }
        try {
            return ($gitContent | ConvertFrom-Json)
        } catch {
            Write-Host "ERROR: Failed to parse JSON from git content: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    } catch {
        Write-Host "ERROR: Exception during git fallback: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Compare-HashesToBaseline {
    param(
        [Parameter(Mandatory=$true)]$OnlineData,
        [Parameter(Mandatory=$true)]$CurrentHashes
    )

    $summary = [ordered]@{
        Subnautica = @{
            Changed = @()
            New = @()
        }
        BelowZero = @{
            Changed = @()
            New = @()
        }
    }

    foreach ($config in $CurrentHashes.Keys) {
        foreach ($modName in $CurrentHashes[$config].Keys) {
            $currentHash = $CurrentHashes[$config][$modName].hash
            $onlineMod = $OnlineData.$config.$modName
            if ($onlineMod) {
                if ($onlineMod.hash -ne $currentHash) {
                    $summary[$config].Changed += $modName
                }
            } else {
                $summary[$config].New += $modName
            }
        }
    }
    return $summary
}

function Update-VersionDataFromHashes {
    param(
        [Parameter(Mandatory=$true)]$OnlineData,
        [Parameter(Mandatory=$true)]$CurrentHashes,
        [switch]$NoBumpUnchanged
    )

    # Clone baseline to avoid mutating input reference
    $result = $OnlineData | ConvertTo-Json -Depth 12 | ConvertFrom-Json

    foreach ($config in $CurrentHashes.Keys) {
        if (-not $result.PSObject.Properties.Name.Contains($config)) {
            $result | Add-Member -NotePropertyName $config -NotePropertyValue @{}
        }

        foreach ($modName in $CurrentHashes[$config].Keys) {
            $current = $CurrentHashes[$config][$modName]
            $existing = $result.$config.$modName

            if ($existing) {
                if ($existing.hash -ne $current.hash) {
                    $newVersion = Increment-Version $existing.version
                    $result.$config.$modName.version = $newVersion
                    $result.$config.$modName.hash = $current.hash
                    $result.$config.$modName.lastChanged = $current.lastChanged
                    $result.$config.$modName.dllPath = $current.dllPath
                } elseif (-not $NoBumpUnchanged) {
                    # Keep as-is; ensure dllPath/lastChanged reflect current (optional)
                    $result.$config.$modName.dllPath = $current.dllPath
                }
            } else {
                # New mod relative to baseline
                $version = Get-DefaultVersion $modName
                $result.$config | Add-Member -NotePropertyName $modName -NotePropertyValue @{
                    version = $version
                    hash = $current.hash
                    lastChanged = $current.lastChanged
                    dllPath = $current.dllPath
                }
            }
        }
    }

    if ($result.metadata -eq $null) {
        $result | Add-Member -NotePropertyName metadata -NotePropertyValue @{}
    }
    $result.metadata.lastUpdated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    if (-not $result.metadata.formatVersion) { $result.metadata.formatVersion = "2.0" }

    return $result
}

if ($GenerateInitial) {
    Write-Host "Generating initial mod-versions.json..." -ForegroundColor Cyan
    
    $currentMods = Get-CurrentModHashes
    
    $versionData = @{
        metadata = @{
            lastUpdated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            formatVersion = "2.0"
            description = "Mod version tracking and hash verification for UnifiedSubnautica"
        }
    }
    
    foreach ($config in $currentMods.Keys) {
        $versionData[$config] = @{}
        
        foreach ($modName in $currentMods[$config].Keys) {
            $modData = $currentMods[$config][$modName]
            $version = Get-DefaultVersion $modName
            
            $versionData[$config][$modName] = @{
                version = $version
                hash = $modData.hash
                lastChanged = $modData.lastChanged
                dllPath = $modData.dllPath
            }
        }
    }
    
    # Generate properly formatted JSON with consistent 2-space indentation
    (Format-Json2Space -Object $versionData) | Out-File $VersionFile -Encoding UTF8
    Write-Host "SUCCESS: Generated $VersionFile with $(($currentMods.Values | ForEach-Object { $_.Keys }).Count) mods" -ForegroundColor Green
}

if ($CheckForChanges) {
    Write-Host "Checking for mod changes..." -ForegroundColor Cyan
    
    if (-not (Test-Path $VersionFile)) {
        Write-Host "ERROR: Version file not found. Run with -GenerateInitial first." -ForegroundColor Red
        exit 1
    }
    
    $versionData = Get-Content $VersionFile | ConvertFrom-Json
    $currentMods = Get-CurrentModHashes
    
    $changedMods = @()
    $newMods = @()
    
    foreach ($config in $currentMods.Keys) {
        foreach ($modName in $currentMods[$config].Keys) {
            $currentHash = $currentMods[$config][$modName].hash
            
            if ($versionData.$config -and $versionData.$config.$modName) {
                $storedHash = $versionData.$config.$modName.hash
                if ($currentHash -ne $storedHash) {
                    $changedMods += "$config/$modName"
                    Write-Host "Changed: $config/$modName" -ForegroundColor Yellow
                    Write-Host "   Old: $storedHash" -ForegroundColor Gray
                    Write-Host "   New: $currentHash" -ForegroundColor Gray
                }
            } else {
                $newMods += "$config/$modName"
                Write-Host "New: $config/$modName" -ForegroundColor Blue
            }
        }
    }
    
    if ($changedMods.Count -eq 0 -and $newMods.Count -eq 0) {
        Write-Host "SUCCESS: No changes detected - all mods are up to date!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Changed mods: $($changedMods.Count)" -ForegroundColor Yellow
        Write-Host "  New mods: $($newMods.Count)" -ForegroundColor Blue
        Write-Host ""
        Write-Host "Run with -UpdateVersions to increment versions and update hashes" -ForegroundColor Magenta
    }
}

if ($UpdateVersions) {
    Write-Host "Updating mod versions..." -ForegroundColor Cyan
    
    if (-not (Test-Path $VersionFile)) {
        Write-Host "ERROR: Version file not found. Run with -GenerateInitial first." -ForegroundColor Red
        exit 1
    }
    
    $versionData = Get-Content $VersionFile | ConvertFrom-Json
    $currentMods = Get-CurrentModHashes
    
    $updatedCount = 0
    
    foreach ($config in $currentMods.Keys) {
        if (-not $versionData.$config) {
            $versionData | Add-Member -NotePropertyName $config -NotePropertyValue @{}
        }
        
        foreach ($modName in $currentMods[$config].Keys) {
            $currentHash = $currentMods[$config][$modName].hash
            $modData = $currentMods[$config][$modName]
            
            if ($versionData.$config.$modName) {
                $storedMod = $versionData.$config.$modName
                if ($currentHash -ne $storedMod.hash) {
                    # Hash changed - increment version
                    $newVersion = Increment-Version $storedMod.version
                    Write-Host "UPDATING: $config/$modName from v$($storedMod.version) to v$newVersion" -ForegroundColor Yellow
                    
                    $versionData.$config.$modName.version = $newVersion
                    $versionData.$config.$modName.hash = $currentHash
                    $versionData.$config.$modName.lastChanged = $modData.lastChanged
                    $versionData.$config.$modName.dllPath = $modData.dllPath
                    $updatedCount++
                }
            } else {
                # New mod
                $version = Get-DefaultVersion $modName
                Write-Host "NEW MOD: Adding $config/$modName v$version" -ForegroundColor Blue
                
                $versionData.$config | Add-Member -NotePropertyName $modName -NotePropertyValue @{
                    version = $version
                    hash = $currentHash
                    lastChanged = $modData.lastChanged
                    dllPath = $modData.dllPath
                }
                $updatedCount++
            }
        }
    }
    
    $versionData.metadata.lastUpdated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    # Generate properly formatted JSON with consistent 2-space indentation
    (Format-Json2Space -Object $versionData) | Out-File $VersionFile -Encoding UTF8
    Write-Host "SUCCESS: Updated $updatedCount mods in $VersionFile" -ForegroundColor Green
}

if ($SyncOnline) {
    Write-Host "ONLINE SYNC: Starting online auto-versioning workflow" -ForegroundColor Cyan

    # 1) Fetch online baseline
    $online = Get-OnlineVersionData -Owner $RepoOwner -Repo $RepoName -BranchName $Branch -FilePath $VersionFile
    if (-not $online) {
        Write-Host "ERROR: Unable to fetch online baseline. Aborting." -ForegroundColor Red
        exit 1
    }

    # 2) Compute current hashes (pre-build snapshot)
    $preHashes = Get-CurrentModHashes
    $diffSummary = Compare-HashesToBaseline -OnlineData $online -CurrentHashes $preHashes

    $configsToBuild = @()
    if ($OnlySubnautica -and -not $OnlyBelowZero) { $configsToBuild = @("Subnautica") }
    elseif ($OnlyBelowZero -and -not $OnlySubnautica) { $configsToBuild = @("BelowZero") }
    else {
        # Decide selectively based on detected differences
        if ($SelectiveBuild) {
            if (($diffSummary.Subnautica.Changed.Count -gt 0) -or ($diffSummary.Subnautica.New.Count -gt 0)) { $configsToBuild += "Subnautica" }
            if (($diffSummary.BelowZero.Changed.Count -gt 0) -or ($diffSummary.BelowZero.New.Count -gt 0)) { $configsToBuild += "BelowZero" }
            if ($configsToBuild.Count -eq 0) {
                # If we couldn't detect changes from existing bin, conservatively build both to ensure fresh hashes
                $configsToBuild = @("Subnautica", "BelowZero")
            }
        } else {
            $configsToBuild = @("Subnautica", "BelowZero")
        }
    }

    Write-Host ("CHECKING: Configurations selected to build: " + ($configsToBuild -join ", ")) -ForegroundColor Yellow

    # 3) Trigger selective rebuilds
    if ($configsToBuild.Count -gt 0) {
        if ($DryRun) {
            Write-Host "DRY-RUN: Would build configurations: $($configsToBuild -join ', ')" -ForegroundColor Magenta
        } else {
            foreach ($cfg in $configsToBuild) {
                Write-Host "BUILD: Invoking $BuildScript -$cfg" -ForegroundColor Cyan
                & $BuildScript -$cfg | Out-Host
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "ERROR: Build for $cfg failed with exit code $LASTEXITCODE" -ForegroundColor Red
                    exit 1
                }
            }
        }
    }

    # 4) Recompute hashes after build
    $postHashes = Get-CurrentModHashes
    $finalSummary = Compare-HashesToBaseline -OnlineData $online -CurrentHashes $postHashes

    $snChanged = $finalSummary.Subnautica.Changed.Count + $finalSummary.Subnautica.New.Count
    $bzChanged = $finalSummary.BelowZero.Changed.Count + $finalSummary.BelowZero.New.Count
    if (($snChanged + $bzChanged) -eq 0) {
        Write-Host "SUCCESS: No changes detected versus online baseline. Nothing to update." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "CHANGES DETECTED:" -ForegroundColor Cyan
        Write-Host "  Subnautica -> Changed: $($finalSummary.Subnautica.Changed.Count), New: $($finalSummary.Subnautica.New.Count)" -ForegroundColor Yellow
        Write-Host "  BelowZero  -> Changed: $($finalSummary.BelowZero.Changed.Count), New: $($finalSummary.BelowZero.New.Count)" -ForegroundColor Yellow
    }

    # 5) Update version data (bump for changed and add new)
    $updated = Update-VersionDataFromHashes -OnlineData $online -CurrentHashes $postHashes

    if ($DryRun) {
        Write-Host "DRY-RUN: Would write updated $VersionFile and optionally commit/push" -ForegroundColor Magenta
        exit 0
    }

    (Format-Json2Space -Object $updated) | Out-File $VersionFile -Encoding UTF8
    Write-Host "SUCCESS: Wrote updated $VersionFile" -ForegroundColor Green

    if ($CommitAndPush) {
        $snPart = if ($snChanged -gt 0) { "SN:$snChanged" } else { "" }
        $bzPart = if ($bzChanged -gt 0) { "BZ:$bzChanged" } else { "" }
        $counts = (@($snPart, $bzPart) | Where-Object { $_ -ne "" }) -join ", "
        $msg = if ($CommitMessage) { $CommitMessage } else { "Auto-bump: $counts mod(s) updated in $VersionFile" }

        Write-Host "GIT: Adding and committing $VersionFile" -ForegroundColor Cyan
        git add -- "$VersionFile"
        git commit -m "$msg" | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Host "WARNING: git commit returned non-zero exit code ($LASTEXITCODE)" -ForegroundColor Yellow
        }
        Write-Host "GIT: Pushing changes" -ForegroundColor Cyan
        git push | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: git push failed (exit code $LASTEXITCODE)" -ForegroundColor Red
            exit 1
        }
        Write-Host "SUCCESS: Changes pushed to remote" -ForegroundColor Green
    }

    exit 0
}

Write-Host ""
Write-Host "Usage Examples:" -ForegroundColor Cyan
Write-Host "  .\\manage-versions.ps1 -GenerateInitial               # Create initial version file"
Write-Host "  .\\manage-versions.ps1 -CheckForChanges               # Check for changes without updating"
Write-Host "  .\\manage-versions.ps1 -UpdateVersions                # Update versions for changed mods"
Write-Host "  .\\manage-versions.ps1 -SyncOnline -SelectiveBuild     # Fetch online baseline, build changed configs, bump and write"
Write-Host "  .\\manage-versions.ps1 -SyncOnline -DryRun             # Run without writing or pushing"
Write-Host "  .\\manage-versions.ps1 -SyncOnline -CommitAndPush      # Auto-commit and push updated file"
