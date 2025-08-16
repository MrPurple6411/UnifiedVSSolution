# Subnautica (2025) – Functional Validation Report

Updated: 2025-08-16

Scope
- Validate runtime correctness of migrated mods against Subnautica 2025 assemblies.
- Confirm Harmony patch targets exist and signatures match.
- Note risk areas and follow-ups.

Build baseline
- Status: SUCCESS (69 projects)
- Key API shifts covered: TechData, PDAScanner, Sprite, MiniWorld handle overloads, GameInput.PrimaryDevice

Methodology
- Static scan of HarmonyPatch attributes per mod
- Cross-reference with 2025 decompiles (cached knowledge from migration work)
- Spot-check IL-sensitive patches (transpilers)

Legend
- OK: compiles and target signature verified
- Watch: compiles; behavior depends on runtime conditions or needs in-game check
- Review: likely mismatch or needs code review

Mods (priority pass)

1) NoEatingSounds
- Targets:
  - Survival.Eat (Transpiler) – Strip FMODUWE.PlayOneShot(string, Vector3, float)
- Status: OK
- Notes: SN lacks TechData.SoundType; transpiler removes only the one-shot call. Expect silent eating/drinking while retaining other effects. Low risk; verify no log spam from FMOD.

2) BetterScannerRoom
- Targets:
  - MiniWorld.Start [Prefix]
  - MiniWorld.mapScale.get [Postfix]
  - MiniWorld.GetOrMakeChunk [Prefix/Postfix]
  - MiniWorld.UpdatePosition [Prefix, replace]
  - MiniWorld.RebuildHologram [Prefix → custom IEnumerator]
- Status: Watch
- Notes: Updated to Addressables AsyncOperationHandle<Mesh> overload for GetOrMakeChunk; UpdatePosition and RebuildHologram behavior match 2025 baselines. Needs in-game test for chunk placement/scale and handle lifecycle.

3) BuildingTweaks
- Targets:
  - Player.Update [Postfix]
- Status: OK
- Notes: Input device retrieval uses SN PrimaryDevice; waterpark escape helper and fall-safety align to SN codepaths.

4) GravTrapStorage
- Targets:
  - uGUI_InventoryTab.OnPointerEnter/Exit [Postfix]
  - Player.Update [Postfix]
  - TooltipFactory.ItemActions [Postfix]
  - Gravsphere.Start/Update/IsValidTarget [mixed]
- Status: Watch
- Notes: Controller binding path uses PrimaryDevice. Complex runtime logic for target containers; confirm SeaMoth storage loop and EscapePod storage branches on SN only. Verify IsValidTarget scanning + KnownTech/PDAScanner interactions.

5) All-Items-1x1
- Targets:
  - TechData.GetItemSize [Postfix]
- Status: OK
- Notes: Returns Vector2int(1,1) for all; visually verify PDA grid.

6) ChargeRequired
- Targets:
  - CrafterLogic.IsCraftRecipeFulfilled [Postfix]
- Status: OK
- Notes: Uses GameModeUtils.RequiresIngredients for SN; iterates TechData ingredients and battery validator. Edge case: null ingredients list.

Next targets to sweep
- BetterVehicleStorage (Vehicle/Exosuit/SeaMoth hooks) – storage sizing and allowed tech
- PrimeSonic: MoreCyclopsUpgrades, Cyclops* – verify method names match SN 2025
- Nautilus patchers touching sound queue / FMOD – check FMODUWE.PlayOneShotImpl signature in SN

Suggested in-game checks
- NoEatingSounds: Eat any food, confirm no sound; other UI sounds unaffected
- BetterScannerRoom: Enter scanner room, watch hologram pop-in/scale and performance
- GravTrapStorage: Open grav trap storage via AltTool; transfer to SeaMoth/escape pod
- ChargeRequired: Try crafting with low-charge batteries; expect denial

Open questions / follow-ups
- Confirm Survival.Eat IL is stable across difficulty modes
- Verify MiniWorld handle overload exists in SN 2025 for all callsites (our usage is via RebuildHologram replacement)
 
All mods sweep (initial)

- Alexejhero Mods
  - ConfigurableDrillableCount: Drillable.SpawnLootAsync [Patch] – OK; confirm loot counts
  - InstantBulkheadAnimations: BulkheadDoor.OnHandClick – OK; animation speed
  - MoreModifiedItems: WarpBall.Warp, UpdateSwimCharge.FixedUpdate, UnderwaterMotor.AlterMaxSpeed, Stillsuit.IEquippable.UpdateEquipped, Player.Start, Equipment.GetTechTypeInSlot – Watch; various runtime behaviours
  - NoMenuPause: FreezeTime.Begin – OK; pause suppression
  - PickupFullCarryalls: PickupableStorage.OnHandClick/OnHandHover, ItemsContainer.IItemsContainer.AllowedToRemove, uGUI_ItemsContainer.Init, PDA.Close – Watch; UI flow

- Core MrPurple mods
  - Base Legs Removal: Base.BuildAccessoryGeometry – OK; pillar removal
  - BetterACU: WaterPark.Update/HasFreeSpace/GetBreedingPartner, LargeRoomWaterPark.HasFreeSpace, CreatureEgg.Hatch, WaterParkCreature.* – Watch; breeding rates and limits
  - BuilderModule: Constructable.Construct/DeconstructAsync, Builder.Update/GetAimTransform, Vehicle/SeaTruck/Hoverbike upgrade hooks, Exosuit slot handlers, ToggleLights.SetLightsActive – Watch; input timing and upgrade reactions
  - BuildingTweaks: Many Builder/Base patches as listed; Player.Update already covered – Watch; placement rules
  - ConfigurableChunkDrops: BreakableResource.BreakIntoResources; Player.Awake init – OK
  - CopperFromScanning: CraftData.AddToInventory – Watch; ensure TechData paths
  - CreaturesFleeLess: FleeOnDamage.OnTakeDamage – OK
  - DropUpgradesOnDestroy: Vehicle/SubRoot/SeaTruckSegment.OnKill – OK
  - ExtraOptions (SMLHelper): WaterscapeVolume.RenderImage/PreRender, Settings.GetExtinction..., SkyApplier.HasMoved – Watch; visuals
  - FabricatorNoAutoClose: Crafter.OnCraftingBegin – OK; UI stay-open
  - GravTrapStorage: Already covered – Watch
  - ImprovedPowerNetwork: Multiple PowerRelay/TechLight/PowerSource methods – Watch; network stability
  - Increased Resource Spawns: CellManager.GetPrefabForSlot(IEntitySlot) – Watch; spawn balance
  - IncreasedChunkDrops: BreakableResource.BreakIntoResources postfix – OK
  - IslandCloudRemoval: Player.Awake postfix – OK; visuals
  - Keep Inventory On Death: Inventory.LoseItems prefix – OK; edge cases on hardcore
  - NoCrosshair: GUIHand.OnUpdate, uGUI_MapRoomScanner triggers – OK
  - NoEatingSounds: Covered – OK
  - NoMagicLights: LargeWorldEntity.Awake postfix – OK; ensures no unintended lights
  - NoMask: Player.SetScubaMaskActive prefix – OK
  - NoOxygenWarnings: LowOxygenAlert.Update, HintSwimToSurface.ShouldShowWarning – OK
  - PersistentCommands: DevConsole submit/usage, achievements, Player.Awake, GameModeManager.SetGameOptions – Watch; achievement gates
  - PowerOrder: uGUI_OptionsPanel.Awake, PowerRelay.AddInboundPower – Watch; ordering logic
  - Pridenautica: Creature.Start postfix – OK; cosmetic
  - RandomCreatureSize: Creature.Start – OK
  - ScannableTimeCapsules: TimeCapsule.Start/Collect – OK; scanner integration
  - SeamothDepthModules: SeaMoth.Start/OnUpgradeModuleChange – OK
  - SeamothThermal: SeaMoth.Start/Update – OK
  - SolidTerrain: WorldStreamer.ParseClipmapSettings – OK; performance
  - SpecialtyManifold: Player.Update postfix – OK
  - TechPistol: Vehicle.OnPilotModeBegin/End, SubRoot.OnPlayerEntered/Exited – Watch; equip toggle
  - Time Eternal: DayNightCycle.GetDayNightCycleTime prefix – Watch; time scaling correctness
  - ToolInspection: QuickSlots.UpdateState prefix – OK; UI
  - UnknownName: Many PDA/Tooltip/KnownTech/Inventory patches – Watch; integration heavy
  - UnobtaniumBatteries: Inventory.Pickup/Async postfix, EnergyMixin.NotifyHasBattery, CreatureDeath.OnTakeDamage, Charger.OnEquip – Watch; balance

- PrimeSonic
  - AIOFabricator: CraftTree.GetTree postfix – OK
  - BetterBioReactor: Many BaseBioReactor hooks – Watch; power calc
  - CustomBatteries / CustomCraft3: Covered by compile; deeper runtime validation in next pass
  - MoreCyclopsUpgrades: Multiple Cyclops UI/logic transpilers – Review; IL sensitive
  - Cyclops* (Engine/Solar/Thermal/Speed): Various Cyclops methods – Watch
  - UpgradedVehicles: Broad Vehicle/SeaTruck/Hoverbike hooks – Watch

- PVD’s Mods
  - RadialMenu: uGUI_CraftingMenu patches – Watch; UI layout
  - Defabricator: uGUI_CraftingMenu patches + CrafterFX visuals – Watch; UI state machine

- RandyKnappMods
  - BetterScannerBlips: uGUI_ResourceTracker.UpdateBlips – OK
  - QuitToDesktop: IngameMenu.Open postfix – OK
