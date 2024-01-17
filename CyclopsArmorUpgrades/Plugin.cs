namespace CyclopsArmorUpgrades;

using BepInEx;
using Common;
using CyclopsArmorUpgrades.Handlers;
using MoreCyclopsUpgrades.API;

[BepInPlugin(MyPluginInfo.PLUGIN_GUID, MyPluginInfo.PLUGIN_NAME, MyPluginInfo.PLUGIN_VERSION)]
[BepInDependency(Nautilus.PluginInfo.PLUGIN_GUID, Nautilus.PluginInfo.PLUGIN_VERSION)]
[BepInDependency(MoreCyclopsUpgrades.MyPluginInfo.PLUGIN_GUID, MoreCyclopsUpgrades.MyPluginInfo.PLUGIN_VERSION)]
[BepInIncompatibility("com.ahk1221.smlhelper")]
public class Plugin : BaseUnityPlugin
{
    public void Awake()
    {
        QuickLogger.Info("Started patching. Version: " + QuickLogger.GetAssemblyVersion());
        ArmorHandler.CreateAndRegisterModules();
        MCUServices.Register.CyclopsUpgradeHandler((cyclops) => new ArmorHandler(cyclops));
        QuickLogger.Info("Finished patching.");
    }
}