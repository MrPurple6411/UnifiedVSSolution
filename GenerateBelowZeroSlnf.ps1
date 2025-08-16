# Script to generate a BelowZero.slnf file based on actual Build.0 entries
$solutionPath = "UnifiedVSSolution.sln"
$outputPath = "BelowZero.slnf"

# Projects to exclude (known problematic projects)
$excludedProjects = @(
    "PrimeSonicSubnauticaMods/MidGameBatteries/MidGameBatteries.csproj"
)
function Should-ExcludeProject([string]$normalizedPath) {
    foreach ($excluded in $excludedProjects) {
        if ($normalizedPath -eq $excluded) { return $true }
    }
    if ($normalizedPath -match '/[^/]*Tests\.csproj$') { return $true }
    if ($normalizedPath -match '/Tests/[^/]+\.csproj$') { return $true }
    return $false
}

# Get all GUIDs that have BelowZero Build.0 entries
$belowZeroGuids = Select-String -Path $solutionPath -Pattern "\.BelowZero\|Any CPU\.Build\.0 = BelowZero\|Any CPU" | 
    ForEach-Object { 
        if ($_.Line -match '\{([^}]+)\}') { 
            $matches[1] 
        } 
    }

Write-Host "Found $($belowZeroGuids.Count) projects that should build for BelowZero"

# Read the solution file to get project paths
$solutionContent = Get-Content $solutionPath
$projects = @()

foreach ($guid in $belowZeroGuids) {
    $projectLine = $solutionContent | Where-Object { $_ -match ".*$guid.*" -and $_ -match '^Project\(' }
    if ($projectLine) {
        # Extract project path from line like: Project("{...}") = "ProjectName", "ProjectPath", "{GUID}"
        if ($projectLine -match '"([^"]+\.csproj|[^"]+\.shproj)"') {
            $projectPath = $matches[1]
            
            # Check if project should be excluded
            $normalizedPath = $projectPath -replace '\\', '/'
            $shouldExclude = Should-ExcludeProject $normalizedPath
            if ($shouldExclude) {
                Write-Host "Excluding project: $projectPath" -ForegroundColor Yellow
            }
            
            if (-not $shouldExclude) {
                $projects += $projectPath
                Write-Host "Added: $projectPath"
            }
        }
    }
}

# Generate the solution filter content
$slnfContent = @"
{
  "solution": {
    "path": "UnifiedVSSolution.sln",
    "projects": [
"@

# Add each project path (using forward slashes for consistency)
for ($i = 0; $i -lt $projects.Count; $i++) {
    $comma = if ($i -eq $projects.Count - 1) { "" } else { "," }
    $projectPath = $projects[$i] -replace '\\', '/'
    $slnfContent += "`r`n      `"$projectPath`"$comma"
}

$slnfContent += @"

    ]
  }
}
"@

# Write the solution filter file
$slnfContent | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "Generated $outputPath with $($projects.Count) projects"
Write-Host "Projects included:"
$projects | ForEach-Object { Write-Host "  $_" }

# Explicitly exit with success code
exit 0
