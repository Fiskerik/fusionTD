# Elemental TD

Hold Greenmarch Gate in an endless one-map Survival run. The game uses Godot 4 and draws its own playfield, towers, icons, and effects.

## Run on Windows

Open the repository’s `project.godot` in Godot 4.4 and press **F5** to start at the main menu. From PowerShell at the repository root, run `./tools/play.ps1`. The launcher uses `GODOT`, a Godot binary on PATH, or the temporary Windows engine used for verification on this machine.

To build for iPhone from Windows, follow the [Codemagic and TestFlight setup](IOS_EXPORT.md).

## Play

1. Choose **Survival**, tap an open terrain tile beside the road, and build an Arrow or Cannon. Arrow starts at 13 damage and 3.7 tiles of range. Cannon covers 2.6 tiles and deals splash damage.
2. You get 30 seconds to build before the first wave and 10 seconds after each completed round. Swipe right anywhere on the game screen or tap **Start Wave** to launch early. Each round pays 10% interest on your current unspent gold before the first enemy spawns. During combat, tap **Speed** to cycle from 1× through 4×. **Menu** or **Esc** pauses the game. Tap a forecast card to view strong and weak tower matchups on the board, then open **Enemy details** for portraits and stats.
3. Before every fifth wave, choose an elemental spirit. Its solo bonus starts immediately and awards the tier and gold when it ends. A spirit that reaches the gate costs five lives. Tap boss forecasts to check their abilities and weaknesses. Prismheart first appears in the boss round on wave 40, after the spirit. Regular enemy waves have a 5% chance to include a Gilded Courier whose bounty is 40% of the combined bounty of the other enemies in that wave.
4. Infuse an Arrow or Cannon from level 2, including during combat. The maximum infusion tiers are I at levels 2–3, II at 4–5, and III at 6. Standard elemental towers cap at levels 2, 4, and 6 with Tier I, II, and III, respectively. A Tier III unlock also lets you build a **Pure** tower of that element. The three Pure slots are shared across all elements. Each Tier II or III spirit defeated grants +10% damage for its element, and mixed towers weight the bonus by their damage split.
5. Select a level-2+ standard elemental tower, tap **Fuse**, then choose a highlighted level-2+ partner of a different element. Any dual can take a third, distinct level-2+ elemental tower. The book icon in the menu opens the tower overview, and unlocked tier badges open it filtered by element. Select a tower to inspect stats, matchups, exact effects by level, and linked fusion recipes.
6. Tap a stunned tower to Rally during a Warlock wave. After game over, **Retry** starts a fresh run.
7. **Continue** restores the last checkpoint, including active combat if the game saved during a wave. The game writes checkpoints after actions, at round boundaries, and when pausing or leaving.

Each run starts with three stone blocks and five swap tokens. Double-tap a road tile during combat to place a stone for five seconds. It pushes enemies off that tile and holds back those behind it. You can place one per numbered wave, with a 60-second combat-time cooldown. Hold the Arrow or Cannon button, drag toward an unlocked element, and release to swap every tower of that type for the round. Release in the center to cancel.

Portrait and landscape use the same controls. All seven elements and both starter towers fit in the build palette. Earth towers hit hard in a small area at short range. Tap **Upgrade** to compare the current and next-level stats. Tap or hover an enemy to inspect its traits and active ailments. Shielded enemies block damage for 2 seconds every 5 seconds, beginning 5 seconds after spawn. After wave 10, formations gain armor, health, and reinforcements. Swift groups gain speed and have lower health and armor than standard groups. The pause menu has separate **Music**, **Sound effects**, and **Haptics** switches.

Dual fusions cost 313 gold and triple fusions cost 638 gold before discounts and upgrade credits. Credits can reduce the fee to zero. For fusion, elemental tower levels 2–3 count as rank 1, levels 4–5 as rank 2, and level 6 as rank 3. A dual contributes its own rank to a triple. The fusion uses the lower ingredient rank, capped by the lowest unlocked element tier in the recipe. That same tier cap applies to upgrades. An attacking result retains at least the stronger ingredient's damage per hit.

Waves schedule up to 48 enemies, with a matching on-field cap. From wave 41, regular enemies gain extra health and armor.

New campaigns draw one of ten centered Greenmarch routes from the run seed. The saved route, active boon, and pending choices travel with the checkpoint. After the fight, choose a new boon or keep your active one for each boss you defeated. Only one boon applies at a time. New offers gain 10% of their base potency per boss defeated after the first, up to +80% and each effect's cap. Tap the boon in the HUD or open **Active boon** in the pause menu to see its full effects.

Chameleons adapt to elemental hits, Banner Bearers rally nearby enemies, Burrowers hide underground, Thieves steal gold at the gate, and Saboteurs jam the closest upgradeable tower. Upgrade or fuse a jammed tower to restore it.

Stonegaze Basilisks appear on every wave ending in 9 and have a 10% chance to appear in other regular enemy waves. On spawn, they mark two random towers for petrification. Marked towers become inactive through the next numbered wave and its spirit trial. From wave 11, Void Wizards have a 25% chance to appear in regular enemy waves. They wait at the entrance and each corner for three seconds, then vanish for two seconds and materialize at the next corner or the gate.

Reach waves 30, 60, 90, and so on to earn a **Pure Crystal** before the wave begins. Use the upgrade preview and confirm **Use 1 Crystal** to ascend a Tier III level-6 elemental tower into a level-7 **Pure** tower. It shares the three-tower limit with Pure towers built for 1,500 gold plus one Pure Crystal and displays a gold star on the board. Level-7 Pure towers are at max level and are ineligible for fusion. Upgrading matched ingredients before a fusion credits their advance upgrade costs against the same final fusion rank. A green chevron marks towers that can upgrade or use a crystal now.

The inspector tracks damage and kills for each tower. The chart icon ranks the five highest-damage towers on the field. Fusions inherit both towers' totals. Tap or hover an effect in the spirit or infusion picker to see its exact values. The main menu keeps detailed statistics for the three most recently finished runs.

Monsoon Spire (Springwell + Electric) extends Springwell's attack-speed aura and adds chain lightning. Moon Glacier (Water + Light + Dark) ices road tiles within range. Ordinary enemies slide and then stumble so trailing mobs can catch up. Moon Orchid (Dark + Light + Nature) spreads disease on defeat. Disease damage uses each enemy's last four seconds of other damage. Bloom and each Light + Nature triple restore one gate HP after each regular wave, with up to two points from Blooms. The gate holds up to 20 HP. Excess repair adds to a 20-point barrier that absorbs damage before the gate loses lives.

Select a tower, tap **Move**, and choose a highlighted tile to relocate it. Moving costs 10% of its invested gold, rounded up. Splash hits deal full damage near impact and 55% at the outer ring.

## Verify

PowerShell:

```powershell
$env:GODOT = 'C:/path/to/Godot_v4.4.1-stable_win64_console.exe'
./tools/run_tests.ps1
& $env:GODOT --headless --path . --script res://tools/balance_bot.gd -- --runs 20 --seed 1
```

Bash:

```bash
GODOT=/path/to/godot bash tools/run_tests.sh
godot --headless --path . --script res://tools/balance_bot.gd -- --runs 20 --seed 1
```

Add `--no-fusion` or `--force-trial 2:15` after the argument separator for comparison runs. The [balance report](BALANCE_REPORT.md) records the sampled results.
