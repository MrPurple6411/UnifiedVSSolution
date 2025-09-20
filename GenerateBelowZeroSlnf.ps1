param(
    [switch]$Quiet
)

    # Script to generate a proper BelowZero.slnf file based on actual Build.0 entries
    $solutionPath = "UnifiedVSSolution.sln"
    $outputPath = "BelowZero.slnf"
    $metaPath = "BelowZero.slnf.meta.json"

    # Projects to exclude (known problematic projects)
    $excludedProjects = @(
    )
    function Should-ExcludeProject([string]$normalizedPath) {
        # Exclude test projects by convention
        if ($normalizedPath -match '/[^/]*Tests\.csproj$') { return $true }
        if ($normalizedPath -match '/Tests/[^/]+\.csproj$') { return $true }
        return $false
    }

    # Helper to compute a SHA256 hash of arbitrary text
    function Get-TextHash([string]$text) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ''
    }

    # Caching: skip regeneration if inputs haven't changed (solution + script + exclusions)
    if ((Test-Path $solutionPath) -and (Test-Path $outputPath) -and (Test-Path $metaPath)) {
        try {
            $solutionHash = (Get-FileHash -Path $solutionPath -Algorithm SHA256).Hash
            $scriptPath = $MyInvocation.MyCommand.Path
            $scriptHash = (Get-FileHash -Path $scriptPath -Algorithm SHA256).Hash
            $exclusionsHash = Get-TextHash ((($excludedProjects | Sort-Object) -join '|'))
            $meta = Get-Content -Raw -Path $metaPath | ConvertFrom-Json
            if ($meta -and $meta.solutionHash -eq $solutionHash -and $meta.scriptHash -eq $scriptHash -and $meta.exclusionsHash -eq $exclusionsHash) {
                if (-not $Quiet) { Write-Host "No changes detected in solution. Using existing $outputPath" -ForegroundColor DarkGray }
                exit 0
            }
        } catch {
            if (-not $Quiet) { Write-Host "Hash check failed, regenerating slnf..." -ForegroundColor Yellow }
        }
    }

    # Read the entire solution once and build maps
    $solutionText = Get-Content -Raw -Path $solutionPath

    # 1) Collect GUIDs with BelowZero Build.0 entries
    $bzGuids = New-Object System.Collections.Generic.HashSet[string]
    foreach ($line in ($solutionText -split "\r?\n")) {
        if ($line -like "*BelowZero|Any CPU.Build.0 = BelowZero|Any CPU*") {
            if ($line -match '\{([^}]+)\}') { [void]$bzGuids.Add($matches[1]) }
        }
    }
    if (-not $Quiet) { Write-Host "Found $($bzGuids.Count) projects that should build for BelowZero" }

    # 2) Build a GUID -> projectPath map by parsing Project(...) lines once
    $guidToPath = @{}
    $projRegex = [regex]'^[ ]*Project\(.*\) = ".*?", "([^"]+\.(csproj|shproj))", "\{([^}]+)\}"'
    foreach ($line in ($solutionText -split "\r?\n")) {
        $m = $projRegex.Match($line)
        if ($m.Success) {
            $path = $m.Groups[1].Value
            $guid = $m.Groups[3].Value
            $guidToPath[$guid] = $path
        }
    }

    # 3) Build the filtered project list via map lookup
    $projects = @()
    foreach ($guid in $bzGuids) {
        if ($guidToPath.ContainsKey($guid)) {
            $projectPath = $guidToPath[$guid]
            $normalizedPath = $projectPath -replace '\\', '/'
            $shouldExclude = Should-ExcludeProject $normalizedPath
            if ($shouldExclude -and -not $Quiet) { Write-Host "Excluding project: $projectPath" -ForegroundColor Yellow }
            if (-not $shouldExclude) {
                $projects += $projectPath
                if (-not $Quiet) { Write-Host "Added: $projectPath" }
            }
        }
    }

    # 4) Write the solution filter JSON
    $json = [PSCustomObject]@{
        solution = [PSCustomObject]@{
            path = "UnifiedVSSolution.sln"
            projects = @($projects | ForEach-Object { ($_ -replace '\\','/') })
        }
    }
    $json | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputPath -Encoding UTF8

    # 5) Write meta with current hashes to make caching robust
    try {
        $solutionHash = (Get-FileHash -Path $solutionPath -Algorithm SHA256).Hash
        $scriptPath = $MyInvocation.MyCommand.Path
        $scriptHash = (Get-FileHash -Path $scriptPath -Algorithm SHA256).Hash
        $exclusionsHash = Get-TextHash ((($excludedProjects | Sort-Object) -join '|'))
        $metaObj = [PSCustomObject]@{ solutionHash = $solutionHash; scriptHash = $scriptHash; exclusionsHash = $exclusionsHash }
        $metaObj | ConvertTo-Json -Depth 3 | Out-File -FilePath $metaPath -Encoding UTF8
    } catch {}

    if (-not $Quiet) {
        Write-Host "Generated $outputPath with $($projects.Count) projects"
    }

    exit 0
