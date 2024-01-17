namespace Common;

using System.Collections;
using System.Threading.Tasks;
using UnityEngine;
using UWE;

public static class Extensions
{
    public static TechType GetTechType(this string techTypeName)
    {
        if (TechTypeExtensions.FromString(techTypeName, out TechType techType, true))
            return techType;

        QuickLogger.Error($"Failed to parse TechType from string: {techTypeName}");
        return TechType.None;
    }

    public static T SafeParseEnum<T>(this string value)
    {
        try
        {
            return (T)System.Enum.Parse(typeof(T), value, true);
        }
        catch
        {
            QuickLogger.Error($"Failed to parse enum {typeof(T).Name} from string: {value}");
            return default;
        }
    }

    public static string GetDisplayName(this TechType techType)
    {
        return Language.main.Get(techType);
    }

    public static string GetClassId(this TechType techType)
    {
        return CraftData.GetClassIdForTechType(techType);
    }

    public static IEnumerator GetPrefabAsync(this TechType techType, IOut<GameObject> @out)
    {
        return CraftData.GetPrefabForTechTypeAsync(techType, false, @out);
    }



}