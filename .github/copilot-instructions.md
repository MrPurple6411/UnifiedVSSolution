# Copilot Instructions

This is a C# mod development project for Subnautica games using MSBuild and PowerShell automation.

**PowerShell Scripts**: Never use emoji characters in PowerShell scripts as they cause compatibility issues with Windows PowerShell. Use text-based status indicators instead (e.g., "SUCCESS:", "ERROR:", "CHECKING:").

**Build System**: Use the established build-all.ps1 script with -Subnautica or -BelowZero parameters for deterministic builds. Additional options include -Clean (clean before build) and -Rebuild (full rebuild).
