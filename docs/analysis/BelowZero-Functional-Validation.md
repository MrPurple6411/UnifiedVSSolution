# Below Zero (2025) – Functional Validation Report

Updated: 2025-08-16

Scope
- Validate runtime correctness of migrated mods against Below Zero 2025 assemblies.
- Confirm Harmony patch targets exist and signatures match.
- Note risk areas and follow-ups.

Build baseline
- Status: SUCCESS (60 projects)
- Key API shifts covered: TechData.SoundType, PDAScanner, Sprite, MiniWorld handle overloads, GameInput.GetPrimaryDevice

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
  - TechData.GetSoundType [Postfix] – Remap Food/Water to Default
- Status: OK
- Notes: Uses BZ-native sound-type API. Low risk. Quick check: eat/drink item emits no sound.

2) BetterScannerRoom
- Targets:
  - MiniWorld.Start [Prefix]
  - MiniWorld.mapScale.get [Postfix]
  - MiniWorld.GetOrMakeChunk [Prefix/Postfix]
  - MiniWorld.UpdatePosition [Prefix, replace]
  - MiniWorld.RebuildHologram [Prefix → custom IEnumerator]
- Status: Watch
- Notes: Uses Addressables AsyncOperationHandle<Mesh> overload for GetOrMakeChunk; expected in BZ 2025. Needs in-game check for chunk transform and performance.

3) BuildingTweaks
- Targets:
  - Player.Update [Postfix]
- Status: OK
- Notes: Input device via GameInput.GetPrimaryDevice; interior respawn path matches BZ. Waterpark hinting and toggles OK.

4) GravTrapStorage
- Targets:
  - uGUI_InventoryTab.OnPointerEnter/Exit [Postfix]
  - Player.Update [Postfix]
  - TooltipFactory.ItemActions [Postfix]
  - Gravsphere.Start/Update/IsValidTarget [mixed]
- Status: Watch
- Notes: Controller path uses GetPrimaryDevice. No SeaMoth/EscapePod branches in BZ; code path guarded with SUBNAUTICA defines. Validate PDAScanner interactions for BZ entries.

5) All-Items-1x1
- Targets:
  - TechData.GetItemSize [Postfix]
- Status: OK
- Notes: Forces 1x1 size; verify PDA grid.

6) ChargeRequired
- Targets:
  - CrafterLogic.IsCraftRecipeFulfilled [Postfix]
- Status: OK
- Notes: Uses GameModeManager.GetOption<bool>(CraftingRequiresResources). Ingredient/battery check mirrors SN; verify ingredient list source is TechData.

Next targets to sweep
- BetterVehicleStorage (SeaTruck/Exosuit/Hoverbike hooks); ensure method names match BZ 2025
- PrimeSonic: UpgradedVehicles/UnSlowSeaTruck – confirm SeaTruck signatures
- Nautilus sound patches around FMODUWE.PlayOneShotImpl – ensure signature stability

Suggested in-game checks
- NoEatingSounds: Consume food/water; no audio playback
- BetterScannerRoom: Scanner room hologram behaviour and chunk alignment
- GravTrapStorage: Open/close via bindings; transfer to SeaTruck lockers
- ChargeRequired: Craft with depleted batteries; expect denial

Open questions / follow-ups
- Confirm MiniWorld.GetOrMakeChunk postfix chunk transform logic matches BZ map scale dynamics
 
All mods sweep (initial)

- Alexejhero Mods
  - ConfigurableDrillableCount: Drillable.SpawnLootAsync – OK (balance)
  - InstantBulkheadAnimations: BulkheadDoor.OnHandClick – OK
  - MoreModifiedItems: WarpBall.Warp, UpdateSwimCharge.FixedUpdate, UnderwaterMotor.AlterMaxSpeed, Stillsuit.UpdateEquipped, Player.Start, Equipment.GetTechTypeInSlot – Watch
  - NoMenuPause: FreezeTime.Begin – OK
  - PickupFullCarryalls: PickupableStorage.OnHandClick/OnHandHover, ItemsContainer.AllowedToRemove, uGUI_ItemsContainer.Init, PDA.Close – Watch

- Core MrPurple mods
  - Base Legs Removal: Base.BuildAccessoryGeometry – OK
  - BetterACU: WaterPark/LargeRoomWaterPark/WaterParkCreature suite – Watch
  - BuilderModule: Large set of Builder/Constructable/Vehicle/Exosuit patches – Watch
  - BuildingTweaks: Same wide set minus SN-only branches – Watch
  - ConfigurableChunkDrops: BreakableResource.BreakIntoResources; Player.Awake – OK
  - CopperFromScanning: CraftData.AddToInventory – Watch
  - CreaturesFleeLess: FleeOnDamage.OnTakeDamage – OK
  - DropUpgradesOnDestroy: Vehicle/SubRoot/SeaTruckSegment.OnKill – OK
  - ExtraOptions (SMLHelper): WaterscapeVolume.* and SkyApplier.HasMoved – Watch; visuals
  - FabricatorNoAutoClose: Crafter.OnCraftingBegin – OK
  - GravTrapStorage: UI + Gravsphere suite – Watch; SeaTruck focus
  - ImprovedPowerNetwork: PowerRelay/TechLight/PowerSource/Start – Watch
  - Increased Resource Spawns: CellManager.GetPrefabForSlot – Watch
  - IncreasedChunkDrops: BreakableResource.BreakIntoResources – OK
  - Keep Inventory On Death: Inventory.LoseItems prefix – OK
  - NoCrosshair: GUIHand.OnUpdate, uGUI_MapRoomScanner triggers – OK
  - NoEatingSounds: TechData.GetSoundType remap – OK
  - NoMagicLights: LargeWorldEntity.Awake postfix – OK
  - NoMask: Player.SetScubaMaskActive prefix – OK
  - NoOxygenWarnings: LowOxygenAlert.Update, HintSwimToSurface.ShouldShowWarning – OK
  - PersistentCommands: DevConsole/achievements/game options/Player.Awake – Watch
  - PowerOrder: Options panel + PowerRelay.AddInboundPower – Watch
  - Pridenautica: Creature.Start postfix – OK
  - RandomCreatureSize: Creature.Start – OK
  - ScannableTimeCapsules: TimeCapsule.Start/Collect – OK (ensure BZ asset exists if used)
  - Seamoth* mods: Present in slnf but BZ lacks SeaMoth in gameplay; if compiled for BZ, conditional defines likely guard. Mark Review for any SN-only types.
  - SolidTerrain: WorldStreamer.ParseClipmapSettings – OK
  - SpecialtyManifold: Player.Update – OK
  - TechPistol: Vehicle/SubRoot events – Watch
  - Time Eternal: DayNightCycle.GetDayNightCycleTime – Watch
  - ToolInspection: QuickSlots.UpdateState – OK
  - UnknownName: PDA/Tooltip/KnownTech/Inventory suite – Watch
  - UnobtaniumBatteries: Inventory/EnergyMixin/CreatureDeath/Charger – Watch

- PrimeSonic
  - AIOFabricator: CraftTree.GetTree – OK
  - BetterBioReactor: BaseBioReactor suite – Watch
  - CustomBatteries / CustomCraft3: Runtime validation next pass
  - UnSlowSeaTruck: SeaTruck-specific patches incl. transpiler – Watch; IL stability
  - UpgradedVehicles: SeaTruck/Hoverbike/Vehicle hooks – Watch
  - MoreCyclopsUpgrades & Cyclops*: Present in SN; in BZ slnf only MCU appears; verify any Cyclops-specific targets are guarded (Cyclops is not in BZ). Mark Review for any unguarded references.

- PVD’s Mods
  - RadialMenu: uGUI_CraftingMenu suite – Watch
  - Defabricator: uGUI_CraftingMenu suite + CrafterFX – Watch

- RandyKnappMods
  - BetterScannerBlips: uGUI_ResourceTracker.UpdateBlips – OK
  - QuitToDesktop: IngameMenu.Open – OK
