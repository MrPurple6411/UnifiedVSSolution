# UnifiedSubnautica – Build Status (latest)

Updated: 2025-08-16

Subnautica
- Status: SUCCESS
- Projects built: 69
- Duration: ~00:03
- Notes: Warnings present (expected). Major API migrations verified (TechData, Sprite, PDAScanner). No compile failures.

Below Zero
- Status: SUCCESS
- Projects built: 60
- Duration: ~00:01
- Notes: Fixed API differences for input device retrieval and MiniWorld chunk loading. No compile failures.

Highlights
- Input device API bridged across games (PrimaryDevice vs GetPrimaryDevice), used where bindings are displayed.
- MiniWorld.GetOrMakeChunk signature differences handled per game (AsyncOperationHandle<Mesh> vs Mesh).
- Prior Subnautica SN2025 migrations holding: Atlas.Sprite → UnityEngine.Sprite; CraftData → TechData; PDAScanner signature.

Next
- Keep NoEatingSounds SN path disabled until a sound-type API equivalent is confirmed for SN2025.
- Consider collapsing more preprocessors where SN2025 matches BZ APIs.
