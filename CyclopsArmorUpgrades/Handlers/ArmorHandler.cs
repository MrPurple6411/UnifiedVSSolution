namespace CyclopsArmorUpgrades.Handlers;

using Common;
using MoreCyclopsUpgrades.API;
using MoreCyclopsUpgrades.API.Upgrades;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using static CraftData;

internal class ArmorHandler : StackingGroupHandler
{
    private const int MaxAllowedPerTier = 6;
    private const int ArmorIndexCount = 4;

    internal const float MK1ArmorRating = 0.075f;
    internal const float MK2ArmorRating = 0.1f;
    internal const float MK3ArmorRating = 0.125f;
    internal const float MK4ArmorRating = 0.1666666666666666667f;

    private static readonly string[] ArmorClassIds = new string[ArmorIndexCount]
    {
        "CyclopsArmorMK1",
        "CyclopsArmorMK2",
        "CyclopsArmorMK3",
        "CyclopsArmorMK4"
    };

    private static readonly string[] ArmorFriendlyNames = new string[ArmorIndexCount]
    {
        "Cyclops Armor MK1",
        "Cyclops Armor MK2",
        "Cyclops Armor MK3",
        "Cyclops Armor MK4"
    };

    // Description for each tier of armor
    private static readonly string[] ArmorDescriptions = new string[ArmorIndexCount]
    {
        "Increases Cyclops armor rating by 7.5% per module.",
        "Increases Cyclops armor rating by 10% per module.",
        "Increases Cyclops armor rating by 12.5% per module.",
        "Increases Cyclops armor rating by 16.6% per module."
    };

    private static readonly List<Ingredient>[] ArmorIngredients = new List<Ingredient>[ArmorIndexCount]
    {
        new List<Ingredient>(new Ingredient[2]
        {
            new Ingredient(TechType.TitaniumIngot, 1),
            new Ingredient(TechType.Lead, 3)
        }),
        new List<Ingredient>(new Ingredient[2]
        {
            new Ingredient(TechType.TitaniumIngot, 1),
            new Ingredient(TechType.AluminumOxide, 1)
        }),
        new List<Ingredient>(new Ingredient[2]
        {
            new Ingredient(TechType.PlasteelIngot, 1),
            new Ingredient(TechType.Nickel, 1)
        }),
        new List<Ingredient>(new Ingredient[2]
        {
            new Ingredient(TechType.PlasteelIngot, 1),
            new Ingredient(TechType.Kyanite, 1)
        })
    };

    private static TechType[] ArmorTypes = new TechType[ArmorIndexCount];

    private static readonly float[] ArmorRatings = new float[ArmorIndexCount]
    {
        MK1ArmorRating, MK2ArmorRating, MK3ArmorRating, MK4ArmorRating
    };

    public static ArmorHandler Instance { get; private set; }

    public ArmorHandler(SubRoot cyclops) : base(cyclops)
    {
        this.OnFinishedUpgrades += () =>
        {
            var damageHandler = cyclops.gameObject.EnsureComponent<DamageHandler>();
            damageHandler.Initialize(cyclops);
            damageHandler.enabled = ArmorTypes.Any(t => MCUServices.CrossMod.GetUpgradeCount(cyclops, t) > 0);
            //QuickLogger.Info($"DamageHandler enabled: {damageHandler.enabled}", true);
        };

        for (int i = 0; i < ArmorIndexCount; i++)
        {
            var techType = ArmorTypes[i];
            var tier = CreateStackingTier(techType);
            tier.MaxCount = MaxAllowedPerTier;
        }
    }

    internal static void CreateAndRegisterModules()
    {
        TechType lastType = TechType.None;
        for (int i = 0; i < ArmorIndexCount; i++)
        {
            var classId = ArmorClassIds[i];
            var friendlyName = ArmorFriendlyNames[i];
            var description = ArmorDescriptions[i];
            var ingredients = ArmorIngredients[i];

            if (lastType != TechType.None)
                ingredients.Insert(0, new Ingredient(lastType, 1));

            var armorModule = new CyArmorModule(classId, friendlyName, description, ingredients);
            armorModule.Patch();
            lastType = armorModule.Info.TechType;
            ArmorTypes[i] = lastType;
        }
    }

    internal class DamageHandler : DamageModifier
    {
        private SubRoot cyclops;

        public void Initialize(SubRoot cyclops)
        {
            this.cyclops = cyclops;
        }

        public override float ModifyDamage(float damage, DamageType type)
        {
            if (!enabled)
                return damage;

            var originalDamage = damage;
            if (originalDamage <= 0f)
                return originalDamage;

            for (int i = 0; i < ArmorIndexCount; i++)
            {
                var count = MCUServices.CrossMod.GetUpgradeCount(cyclops, ArmorTypes[i]);
                if (count > 0)
                {
                    var armorRating = ArmorRatings[i];
                    var armorValue = armorRating * count;
                    damage -= originalDamage * armorValue;
                }
            }

            QuickLogger.Info($"Damage Type: {type}, Original Damage: {originalDamage}, Damage: {damage}, Damage Reduction%: {(originalDamage - damage) / originalDamage * 100}%", true);

            return Mathf.Max(damage, 0f);
        }
    }
}
