# Subnautica 2025 Update: API changes and migration plan

This note captures what changed between Subnautica 2023 and Subnautica 2025 (SN), how SN 2025 compares to Below Zero 2025 (BZ), and a clean plan to update mods using the preprocessors already in this repo. No reflection hacks; only compile-time updates.

## quick findings

- Input formatting moved from `uGUI` to `GameInput` in SN 2025
  - `uGUI.FormatButton(...)` no longer exists. In-game UI (e.g., `HandReticle`) now composes text using `GameInput.FormatButton(button, ...)`.
  - `GameInput` changed shape in SN 2025: it’s now a static class with an `IGameInput` backend.
  - Primary device accessor changed:
    - 2023: `GameInput.GetPrimaryDevice()`
    - 2025: `GameInput.PrimaryDevice` (property)

- Crafting/data APIs line up more with BZ behavior
  - `CraftData.GetItemSize(TechType)` calls fail in SN 2025 (removed/moved); BZ has `TechData.GetItemSize`. SN 2025 should use the BZ-style path.
  - Eat sound lookup moved away from `CraftData.GetUseEatSound(...)`; BZ uses `TechData.SoundType`. SN 2025 should follow the BZ path here as well.

- Sprites: `Atlas.Sprite` removed
  - Use `UnityEngine.Sprite`. BZ already does this; SN 2025 follows suit.

- TooltipFactory / ITechData patches need refresh
  - A patch targeting `TooltipFactory.WriteIngredients(ITechData...)` fails due to `ITechData` missing/renamed. We need to locate the current hook in SN 2025 and update the target (second pass after the input/craft/sprite fixes).

## evidence sources

- Decompiled SN 2025 shows `public static class GameInput` and `HandReticle` building UI strings with `GameInput.FormatButton(...)`.
- `uGUI.cs` exists but provides no `FormatButton` API; all references in mods that call `uGUI.FormatButton` are now broken.
- Build errors across mods match these changes:
  - Input/UI:
    - Missing `uGUI.FormatButton`: BetterScannerRoom, GravTrapStorage
    - `GameInput.GetPrimaryDevice` no longer present: BuildingTweaks, GravTrapStorage
    - Using `GameInput` as a generic type argument fails (now static): PickupFullCarryalls / InventoryOpener
  - Data:
    - `CraftData.GetItemSize` missing: All-Items-1x1, BuilderModule
    - `CraftData.GetUseEatSound` missing: NoEatingSounds
  - Sprites:
    - `Atlas.Sprite` types: CustomCraft3, MoreCyclopsUpgrades, CustomBatteries
  - Tooltips:
    - `TooltipFactory.WriteIngredients(ITechData ...)` signature no longer matches: UnknownName

## migration plan (preprocessor-first)

Use the preprocessors you already rely on (SN vs BZ). Where SN 2025 aligns with BZ behavior, prefer the BZ code path for SN 2025 as well. Keep changes minimal and compile-time only.

1) Input and binding display
- Replace `uGUI.FormatButton(...)` with `GameInput.FormatButton(...)`.
- Replace `GameInput.GetPrimaryDevice()` with `GameInput.PrimaryDevice`.
- Remove any use of `GameInput` as a type parameter or instance (it’s static in SN 2025). Use the static API.
- Preprocessor: apply these changes under SN, and consider doing the same under BZ 2025 (the `uGUI.FormatButton` API appears gone there too).

2) Item sizes and consume sounds
- Switch SN 2025 to BZ-style calls:
  - Item size: `TechData.GetItemSize(techType)`
  - Eat sound: intercept via `TechData.SoundType` instead of `CraftData.GetUseEatSound`
- Many mods already have `#if BELOWZERO` branches that can be re-used for SN 2025.

3) Sprites
- Replace `using Sprite = Atlas.Sprite;` with `using Sprite = UnityEngine.Sprite;` under SN 2025 (BZ already uses `UnityEngine.Sprite`).

4) TooltipFactory / ITechData
- Locate the current `TooltipFactory.WriteIngredients` (or replacement) in SN 2025 and update the patch signature. If it moved to a different class, retarget there.
- If necessary, temporarily exclude this patch under SN 2025 until we pinpoint the exact entry point.

## code change cheat sheet

- Input formatting
  - Before: `uGUI.FormatButton(GameInput.Button.LeftHand, true, "InputSeparator", false)`
  - After (SN 2025): `GameInput.FormatButton(GameInput.Button.LeftHand, false)`

- Primary device
  - Before: `GameInput.GetPrimaryDevice() == GameInput.Device.Controller`
  - After (SN 2025): `GameInput.PrimaryDevice == GameInput.Device.Controller`

- Item size
  - Before (SN 2023): `CraftData.GetItemSize(techType)`
  - After (SN 2025/BZ): `TechData.GetItemSize(techType)`

- Eat sound
  - Before (SN 2023): patch `CraftData.GetUseEatSound`
  - After (SN 2025/BZ): patch `TechData.GetSoundType` and map food/water sounds to `Default`

- Sprite alias
  - Before (SN 2023): `using Sprite = Atlas.Sprite;`
  - After (SN 2025/BZ): `using Sprite = UnityEngine.Sprite;`

## proposed order of operations

- Pass 1 (unblock builds):
  - Update input formatting and device access in: BetterScannerRoom, GravTrapStorage, BuildingTweaks, PickupFullCarryalls.
  - Swap `CraftData.GetItemSize` and `CraftData.GetUseEatSound` usages to the BZ-style calls for SN 2025 in: All-Items-1x1, BuilderModule, NoEatingSounds.
  - Replace `Atlas.Sprite` with `UnityEngine.Sprite` in: CustomCraft3, MoreCyclopsUpgrades, CustomBatteries.
  - Build SN; capture the next error set.

- Pass 2 (tooltips):
  - Find the new tooltip writer signature for SN 2025 and adjust the `UnknownName` patch.
  - Build again; proceed to any stragglers.

## notes

- Nautilus source is available in the workspace and already standardizes on `UnityEngine.Sprite` and helper utilities; it should integrate cleanly with the above.
- Where SN 2025 matches BZ behavior, prefer sharing the BZ branch to minimize maintenance and further divergence.
- No runtime reflection or dynamic probing is proposed—only compile-time, minimal, targeted updates.
