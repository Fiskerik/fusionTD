# Elemental TD

Hold Greenmarch Gate in an endless one-map Survival run. The game uses Godot 4 and draws its own playfield, towers, icons, and effects.

## Run on Windows

Open the repository’s `project.godot` in Godot 4.4 and press **F5** to start at the main menu. From PowerShell at the repository root, run `./tools/play.ps1`. The launcher uses `GODOT`, a Godot binary on PATH, or the temporary Windows engine used for verification on this machine.

To build for iPhone from Windows, follow the [Codemagic and TestFlight setup](IOS_EXPORT.md).

## Play

1. Choose **Survival**, tap an open terrain tile beside the road, and build an Arrow or Cannon. Arrow starts at 13 damage and 3.7 tiles of range. Cannon covers 2.6 tiles and deals splash damage.
2. Regular waves launch after 30 seconds. Tap **Start Wave** to launch early or **Speed** to cycle from 1× through 4× during combat. **Menu** or **Esc** pauses the game. The menu holds the status-effect guide and tower overview. Tap a forecast card for enemy portraits and stats.
3. Before every fifth wave, choose an elemental spirit. Its solo bonus starts immediately and awards the tier and gold when it ends. A spirit that reaches the gate costs five lives. Tap boss forecasts to check their abilities and weaknesses. Other regular waves have a 5% chance to include a Gilded Courier, which yields 250 extra gold on defeat.
4. Infuse an Arrow or Cannon from level 2, including during combat. The maximum infusion tiers are I at levels 2–3, II at 4–5, and III at 6. Standard elemental towers cap at levels 2, 4, and 6 with Tier I, II, and III, respectively. A Tier III unlock also lets you build a **Pure** tower of that element. The three Pure slots are shared across all elements. Each Tier II or III spirit defeated grants +10% damage for its element, and mixed towers weight the bonus by their damage split.
5. Select a level-2+ standard elemental tower, tap **Fuse**, then choose a highlighted level-2+ partner of a different element. Any dual can take a third, distinct level-2+ elemental tower. The book icon in the menu opens the tower overview, and unlocked tier badges open it filtered by element. Select a tower to inspect stats, matchups, exact effects by level, and linked fusion recipes.
6. Tap a stunned tower to Rally during a Warlock wave. After game over, **Retry** starts a fresh run.
7. **Continue** restores the last checkpoint, including active combat if the game saved during a wave. The game writes checkpoints after actions, at round boundaries, and when pausing or leaving.

Portrait and landscape use the same controls. All six elements and both starter towers fit in the build palette. Tap **Upgrade** to compare the current and next-level stats. Tap or hover an enemy to inspect its traits and active ailments. Shielded enemies block damage for 2 seconds every 5 seconds, beginning 5 seconds after spawn. After wave 10, formations gain armor, health, and reinforcements. Swift groups gain speed and have lower health and armor than standard groups. The pause menu has separate **Music**, **Sound effects**, and **Haptics** switches.

Dual fusions cost 313 gold and triple fusions cost 638 gold. For fusion, elemental tower levels 2–3 count as rank 1, levels 4–5 as rank 2, and level 6 as rank 3. A dual contributes its own rank to a triple. The fusion uses the lower ingredient rank, capped by the lowest unlocked element tier in the recipe. That same tier cap applies to upgrades. An attacking result retains at least the stronger ingredient's damage per hit.

Waves schedule up to 48 enemies, with a matching on-field cap. From wave 41, regular enemies gain extra health and armor.

New campaigns draw one of ten centered Greenmarch routes from the run seed. The saved route, earned boons, and pending choices travel with the checkpoint. After a spirit or boss encounter, pick one of three boons. Boons offered later have stronger values up to a cap. Review your picks under **Run boons** in the pause menu.

Chameleons adapt to elemental hits, Banner Bearers rally nearby enemies, Burrowers hide underground, Thieves steal gold at the gate, and Saboteurs jam the closest upgradeable tower. Upgrade or fuse a jammed tower to restore it.

Reach waves 30, 60, 90, and so on to earn a **Pure Crystal** before the wave begins. Tap **Use Crystal** to ascend a Tier III level-6 elemental tower into a level-7 **Pure** tower. It shares the three-tower limit with Pure towers built for 1,500 gold plus one Pure Crystal and displays a gold star on the board. Pure towers are ineligible for fusion. Upgrading matched ingredients before a fusion credits their advance upgrade costs against the same final fusion rank. Additional crystals add 25% damage per crystal to a Pure tower. A green chevron marks towers that can upgrade or use a crystal now.

The inspector tracks damage and kills for each tower. The chart icon ranks the five highest-damage towers on the field. Fusions inherit both towers' totals. Tap or hover an effect in the spirit or infusion picker to see its exact values. The main menu keeps detailed statistics for the three most recently finished runs.

Moon Glacier (Water + Light + Dark) ices road tiles within range. Ordinary enemies slide and then stumble so trailing mobs can catch up. Moon Orchid (Dark + Light + Nature) spreads disease on defeat. Disease damage uses each enemy's last four seconds of other damage. Bloom and each Light + Nature triple restore one gate HP after each regular wave, with up to two points from Blooms. The gate holds up to 20 HP. Excess repair adds to a 20-point barrier that absorbs damage before the gate loses lives.

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
