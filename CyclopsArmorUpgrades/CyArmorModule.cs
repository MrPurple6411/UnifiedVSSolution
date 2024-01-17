namespace CyclopsArmorUpgrades;

using MoreCyclopsUpgrades.API;
using MoreCyclopsUpgrades.API.Upgrades;
using Nautilus.Crafting;
using System.Collections.Generic;
using static CraftData;
using System.Reflection;
using System.IO;

internal class CyArmorModule : CyclopsUpgrade
{
    private readonly List<Ingredient> ingredients;

    public CyArmorModule(string classId, string friendlyName, string description, List<Ingredient> ingredients) : base(classId, friendlyName, description)
    {
        this.ingredients = ingredients;        
    }

    public override CraftTree.Type FabricatorType => CraftTree.Type.CyclopsFabricator;

    public override string[] StepsToFabricatorTab => MCUServices.CrossMod.StepsToCyclopsModulesTabInCyclopsFabricator;

    public override TechType RequiredForUnlock => TechType.Cyclops;

    public override string AssetsFolder => Path.Combine(Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location), "Assets");

    protected override TechType PrefabTemplate => TechType.CyclopsShieldModule;

    protected override RecipeData GetBlueprintRecipe()
    {
        return new RecipeData()
        {
            craftAmount = 1,
            Ingredients = ingredients,
        };
    }
}
