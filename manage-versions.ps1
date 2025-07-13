# Mod Version Management Script
# Generates and maintains a clean, GitHub-friendly mod version tracking system

param(
    [switch]$GenerateInitial,    # Generate initial version file from current builds
    [switch]$CheckForChanges,    # Check current builds against version file
    [switch]$UpdateVersions,     # Update version file with new hashes and increment versions
    [string]$VersionFile = "mod-versions.json"
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
    $jsonString = $versionData | ConvertTo-Json -Depth 10
    $lines = $jsonString -split "`n"
    $formattedLines = @()
    $indentLevel = 0
    
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\}' -or $trimmed -match '^\]') {
            $indentLevel--
        }
        $formattedLines += ("  " * $indentLevel) + $trimmed
        if ($trimmed -match '\{$' -or $trimmed -match '\[$') {
            $indentLevel++
        }
    }
    
    $formattedLines -join "`n" | Out-File $VersionFile -Encoding UTF8
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
    $jsonString = $versionData | ConvertTo-Json -Depth 10
    $lines = $jsonString -split "`n"
    $formattedLines = @()
    $indentLevel = 0
    
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\}' -or $trimmed -match '^\]') {
            $indentLevel--
        }
        $formattedLines += ("  " * $indentLevel) + $trimmed
        if ($trimmed -match '\{$' -or $trimmed -match '\[$') {
            $indentLevel++
        }
    }
    
    $formattedLines -join "`n" | Out-File $VersionFile -Encoding UTF8
    Write-Host "SUCCESS: Updated $updatedCount mods in $VersionFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "Usage Examples:" -ForegroundColor Cyan
Write-Host "  .\manage-versions.ps1 -GenerateInitial    # Create initial version file"
Write-Host "  .\manage-versions.ps1 -CheckForChanges    # Check for changes without updating"
Write-Host "  .\manage-versions.ps1 -UpdateVersions     # Update versions for changed mods"
