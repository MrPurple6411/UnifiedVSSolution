# Mod Improvement Roadmaps

Updated: 2025-08-16

Purpose
- Propose concrete, low-risk improvements for every mod to reduce conflicts, improve performance, and increase configurability.
- Phased plan per mod: Quick Wins (days), Stabilization (short sprint), Enhancements (longer).

Legend
- Conflict-hardening: minimize Harmony footprint, guard nulls, isolate side-effects, interop with other popular mods.
- Perf: avoid heavy per-frame work, caching, pooled allocations, async/Addressables hygiene.
- Config: add Nautilus options, JSON config, in-game toggles.

Note
- This roadmap is static text for review. We’ll update and check off items as we implement.

---

## Alexejhero-Subnautica-Mods

### ConfigurableDrillableCount
- Quick Wins
  - Replace raw [HarmonyPatch] with targeted overload (explicit argument types) to avoid overload confusion.
  - Add config (min/max per resource class) via Nautilus Options + JSON.
- Stabilization
  - Respect biome/rarity multipliers; expose “multiplier vs absolute” mode.
  - Guard against upstream changes in Drillable.SpawnLootAsync by signature check + soft-fail logging.
- Enhancements
  - Per-tech customization (e.g., override for specific breakables) and presets.

### InstantBulkheadAnimations
- Quick Wins
  - Use postfix + parameterized speed scale rather than replacing logic; add config slider.
- Stabilization
  - Verify interaction with door state machine; avoid race conditions with animation events.
- Enhancements
  - “Smart” mode: only speed when player nearby / in emergencies.

### MoreModifiedItems
- Quick Wins
  - Centralize config for each sub-feature (warp ball, stillsuit, swim charge, speed caps) with toggles.
  - Add runtime feature gating based on presence of other mods (Nautilus ModRegistry).
- Stabilization
  - Split patches by feature into partial classes; reduce patch scope where possible.
  - Cache reflection lookups; avoid per-frame allocations in FixedUpdate.
- Enhancements
  - Telemetry option to log conflicts in dev builds only.

### NoMenuPause
- Quick Wins
  - Config: allow per-menu category toggles.
- Stabilization
  - Ensure cinematics/cutscenes still pause; add whitelist/blacklist.
- Enhancements
  - Auto-disable for speedrun mode detection.

### PickupFullCarryalls
- Quick Wins
  - Harden UI flow: null/active checks, PDA state race guards.
  - Config toggles for Alt/Controller bindings and behavior.
- Stabilization
  - Avoid patching ItemsContainer internals where not required; prefer postfix side-effects.
- Enhancements
  - Interop with Storage rebalancing mods (AlterraHub) via safe reflection wrappers.

---

## BetterScannerRoom
- Quick Wins
  - Ensure Addressables handles are always released; add try/finally in completion lambdas.
  - Config: scan radius/interval sliders (already present) + performance presets.
- Stabilization
  - Avoid repeated dictionary allocations; pre-size structures; reuse lists in UpdatePosition.
  - Gate UpdatePosition frequency (throttle with time budget).
- Enhancements
  - Pluggable filter rules for scan types; expose events for other mods to integrate.

---

## MrPurple6411-Subnautica-Mods

### All-Items-1x1
- Quick Wins
  - Add opt-in whitelist/blacklist; exclude vehicles/modules by default.
- Stabilization
  - Conflicts: run after other size-altering mods via Harmony priority; or compute max(1x1, requested).
- Enhancements
  - Preset profiles (vanilla/minimal/compact).

### Base Legs Removal
- Quick Wins
  - Config: toggle per-foundation type; safety toggle to keep legs in extreme slopes.
- Stabilization
  - Validate mesh/physics updates to avoid floating bases.
- Enhancements
  - Visual smoothing on terrain cutouts.

### BetterACU
- Quick Wins
  - Configurable breeding rates and capacity per creature type.
  - Null guards for large water park variants.
- Stabilization
  - Avoid heavy scans each frame; schedule updates.
- Enhancements
  - Analytics overlay (dev mode) to profile breeding state.

### BuilderModule
- Quick Wins
  - Input handling guard (GetPrimaryDevice/PrimaryDevice) is already conditional; add debounce for toggles.
  - Config to enable/disable integration with vehicles/exosuit.
- Stabilization
  - Consolidate many Builder patches to reduce chance of mod conflict (postfix-first approach).
  - Cache ghost model materials.
- Enhancements
  - API surface for other mods to add custom placement rules.

### BuildingTweaks
- Quick Wins
  - Group config for all tweak toggles; expose in Nautilus UI.
- Stabilization
  - Minimize per-frame string formatting/logs; use cached messages.
- Enhancements
  - Export placement diagnostics (dev only).

### ChargeRequired
- Quick Wins
  - Config for “require charged batteries” per-tech.
- Stabilization
  - Use TechData safely; handle null ingredients.
- Enhancements
  - UI hint for missing charged items.

### ConfigurableChunkDrops
- Quick Wins
  - Config per-biome and per-breakable; presets.
- Stabilization
  - Avoid repeated TechType parsing during drops.
- Enhancements
  - Difficulty scaling hooks.

### CopperFromScanning
- Quick Wins
  - Config: reward types; cap per time window.
- Stabilization
  - Ensure CraftData.AddToInventory paths won’t duplicate or overflow.

### CreaturesFleeLess
- Quick Wins
  - Config slider for flee chance multiplier.
- Stabilization
  - Respect creature-specific behavior; cap aggression changes.

### CustomCommands
- Quick Wins
  - Validate arguments; provide help command.
- Stabilization
  - Guard DevConsole patching order; avoid exceptions breaking console.

### CustomHullPlates / CustomPosters
- Quick Wins
  - Addressables caching; preload on demand.
- Stabilization
  - Null guard missing assets; fallback placeholder.
- Enhancements
  - Drag-and-drop import UI.

### CustomizeYourSpawns
- Quick Wins
  - JSON-driven spawn tables; presets.
- Stabilization
  - Validation pass at load; soft-fail with diagnostics.

### DropUpgradesOnDestroy
- Quick Wins
  - Config: filter modules to drop; drop chance.
- Stabilization
  - Avoid double-drops when other mods hook OnKill; sentinel flag.

### ExtraOptions (SMLHelper)
- Quick Wins
  - Move heavy water render tweaks off frame path; cache coefficients.
- Stabilization
  - Add game-option profiles and safety toggles.

### FabricatorNoAutoClose
- Quick Wins
  - Config: stay-open logic whitelist.

### GravTrapStorage
- Quick Wins
  - Guard UI interactions; controller binding discovery cached.
  - Config toggles for transfer behavior; range limits.
- Stabilization
  - Pool temporary lists; avoid scanning hierarchy frequently.
- Enhancements
  - Interop with vehicle storages via optional provider interface.

### ImprovedPowerNetwork
- Quick Wins
  - Cache relay queries; reduce graph traversals.
- Stabilization
  - Add reentrancy guard; avoid storms of updates.
- Enhancements
  - Debug overlay to visualize power links (dev).

### Increased Resource Spawns / IncreasedChunkDrops
- Quick Wins
  - Config presets; caps; biome scaling.
- Stabilization
  - Avoid allocations in GetPrefabForSlot range checks.

### IslandCloudRemoval
- Quick Wins
  - Config toggle; ensure only runs once per scene.

### Keep Inventory On Death
- Quick Wins
  - Config per-slot retention; hardcore guardrails.

### NoCrosshair / NoMask / NoOxygenWarnings / NoMagicLights
- Quick Wins
  - All add trivial config toggles and minimal null guards.
- Stabilization
  - Ensure scene transitions are handled cleanly.

### NoEatingSounds
- Quick Wins
  - Add config to optionally re-enable partial sounds (e.g., drink only).
- Stabilization
  - SN transpiler: add signature guard; fallback if FMOD method changes.

### PersistentCommands
- Quick Wins
  - Configurable persistence scope; achievements handling toggles.
- Stabilization
  - Ensure patch order doesn’t break achievements in vanilla.

### PowerOrder
- Quick Wins
  - Config UI for priority ordering; safe defaults.
- Stabilization
  - Prevent cycles in relay priority.

### Pridenautica / RandomCreatureSize
- Quick Wins
  - Config toggles and ranges.

### ScannableTimeCapsules
- Quick Wins
  - Config: allow/disallow scanning rewards; caps.

### SeamothDepthModules / SeamothThermal
- Quick Wins
  - Config ranges; ensure BZ build excludes SN-only types.
- Stabilization
  - Preprocessor guard review.

### SolidTerrain
- Quick Wins
  - Config for clipmap settings; presets.
- Stabilization
  - Validate performance on low-end.

### SpecialtyManifold
- Quick Wins
  - Config toggle; dampening values exposed.

### TechPistol
- Quick Wins
  - Config for equip toggles; safe handling in vehicles.
- Stabilization
  - Avoid repeated GetComponent calls; cache.

### Time Eternal
- Quick Wins
  - Config curve for time scale; night/day ratios.
- Stabilization
  - Ensure time-dependent systems (plants, batteries) aren’t broken.

### ToolInspection
- Quick Wins
  - Config to enable/disable per-tool inspection states.

### UnknownName
- Quick Wins
  - Group configs for PDA/Tooltip/Tech gating; toggle individual features.
- Stabilization
  - Reduce patch breadth by feature-splitting; prefer postfix where possible.

### UnobtaniumBatteries
- Quick Wins
  - Config for drop rates and effects; disable in Survival if needed.
- Stabilization
  - Interop guards with battery overhaul mods.

---

## PrimeSonicSubnauticaMods

### AIOFabricator
- Quick Wins
  - Config for which trees to merge; conflict resolution policy.
- Stabilization
  - Log duplicate nodes and resolve deterministically.

### BetterBioReactor
- Quick Wins
  - Config energy-per-item; decay curves.
- Stabilization
  - Avoid per-frame recomputations; cache recipes.

### CustomBatteries / CustomCraft3
- Quick Wins
  - Validation and error visibility for bad configs.
- Stabilization
  - Namespace isolation; ensure minimal global state.

### Cyclops* and MoreCyclopsUpgrades (SN)
- Quick Wins
  - Group configs; disable features piecemeal.
- Stabilization
  - Transpiler resilience: pattern-match via CodeMatcher; add assert logging and fail-soft.
- Enhancements
  - Perf budget for HUD updates; throttle.

### UpgradedVehicles / UnSlowSeaTruck (BZ)
- Quick Wins
  - Config per-upgrade adjustments; caps.
- Stabilization
  - Transpiler signature checks; cache heavy lookups.

### MidGameBatteries
- Quick Wins
  - Config capacity and tier availability.
- Stabilization
  - Ensure balance across SN/BZ separately.

---

## PVD’s Mods

### RadialMenu
- Quick Wins
  - Config to opt-in/out; feature flags per crafting tree.
- Stabilization
  - Avoid re-layout on every frame; cache icon metrics.

### Defabricator
- Quick Wins
  - Config for allowed items; cost/refund policies.
- Stabilization
  - UI state machine guards to prevent stuck states.

---

## RandyKnappMods

### BetterScannerBlips
- Quick Wins
  - Config for blip density/filters.

### QuitToDesktop
- Quick Wins
  - Confirm menu state guards; add confirm-prompt toggle.

---

# Implementation notes (cross-cutting)
- Use Nautilus for options UI everywhere feasible; ensure configs saved per-game (SN/BZ) and per-profile.
- Prefer postfix patches where possible; keep prefixes/transpilers minimal and signature-guarded.
- Add lightweight logging (disabled by default); expose a dev mode toggle.
- Cache frequently used objects/components; avoid LINQ in per-frame paths; pool lists.
- Release Addressables handles deterministically; unify async patterns.
- Guard SN/BZ differences with clear #if and keep shared logic in helpers.
