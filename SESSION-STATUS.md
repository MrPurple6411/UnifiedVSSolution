# Project Status - Auto Version Management System

## What We've Accomplished ✅

### 1. Deterministic Build Foundation
- **100% deterministic builds verified** across 129 DLL files (69 Subnautica + 60 BelowZero)
- Enhanced `build-all.ps1` with `-Subnautica` and `-BelowZero` parameters
- Added `-Clean` and `-Rebuild` options for comprehensive build control
- All builds produce identical SHA256 hashes on repeated runs

### 2. Version Management System Core
- **`manage-versions.ps1`** - Complete hash-based version tracking script with:
  - `-GenerateInitial` - Creates baseline JSON with current mod state
  - `-CheckForChanges` - Compares current DLL hashes against stored baseline
  - `-UpdateVersions` - Auto-increments versions for changed mods
- **`mod-versions.json`** - Clean baseline with 129 mods in human-readable format:
  ```json
  {
    "BelowZero": { "ModName": { "version": "1.0.0", "hash": "SHA256...", "lastChanged": "timestamp", "dllPath": "path" } },
    "Subnautica": { "ModName": { ... } },
    "metadata": { "formatVersion": "2.0", "lastUpdated": "timestamp" }
  }
  ```

### 3. Infrastructure & Compliance
- **SSH authentication** configured for MrPurple6411 GitHub account
- **`.github/copilot-instructions.md`** - PowerShell emoji compliance rules
- **Solution filters** for targeted builds (Subnautica.slnf, BelowZero.slnf)
- **Consistent JSON formatting** with 2-space indentation

### 4. Successfully Pushed Baseline
- All changes committed and pushed to GitHub
- Baseline represents true current state (no mod code changes, only tooling)
- Ready for online checking and automation features

## Online Auto-Versioning System 🚀

Status: Implemented (with dry-run verified). Uses online baseline, selective builds, version bump, and optional commit/push.

### What it does
1. Fetches the `mod-versions.json` baseline from GitHub (raw URL) with a git fallback to `origin/main:mod-versions.json`.
2. Compares local DLL hashes vs the online baseline.
3. Selectively builds only configurations with differences (optional).
4. Auto-increments versions for changed mods and adds new mods.
5. Writes the updated `mod-versions.json` and optionally commits/pushes.

### Usage
```powershell
# Dry-run: fetch baseline, decide what would build, compute version bumps, but do not write/push
.\manage-versions.ps1 -SyncOnline -SelectiveBuild -DryRun

# Do it for real and commit/push changes (requires remote auth)
.\manage-versions.ps1 -SyncOnline -SelectiveBuild -CommitAndPush

# Limit to one configuration
.\manage-versions.ps1 -SyncOnline -OnlySubnautica -CommitAndPush
.\manage-versions.ps1 -SyncOnline -OnlyBelowZero  -CommitAndPush
```

Notes:
- Fallback path uses `git show origin/<branch>:<path>` if raw fetch fails; run `git fetch` first if needed.
- Push uses your existing git remote auth (SSH recommended). No tokens are stored by the script.
- The script preserves our 2-space JSON formatting and updates `metadata.lastUpdated`.

## Current Working Directory
`c:\Repos\MrPurple6411\UnifiedSubnautica`

## Test Commands to Verify System
```powershell
# Verify baseline works
.\manage-versions.ps1 -CheckForChanges

# Test selective builds
.\build-all.ps1 -Subnautica
.\build-all.ps1 -BelowZero
```

---
**Status**: Foundation complete, ready for online automation phase
**Next Session Goal**: Implement GitHub API integration and automated rebuild workflow

---

## Functional Validation Reports

- Subnautica (2025): docs/analysis/Subnautica-Functional-Validation.md
- Below Zero (2025): docs/analysis/BelowZero-Functional-Validation.md

## Mod Improvement Roadmaps

- Consolidated plan: docs/analysis/Mod-Roadmaps.md

Notes:
- Both reports cover high-priority mods first (NoEatingSounds, BetterScannerRoom, BuildingTweaks, GravTrapStorage, All-Items-1x1, ChargeRequired)
- Status is OK/Watch/Review with concrete targets and follow-ups
