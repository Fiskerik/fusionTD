# Elemental TD

Hold Greenmarch Gate in an endless one-map Survival run. The game uses Godot 4 and draws its own playfield, towers, icons, and effects.

## Run on Windows

Open the repository’s `project.godot` in Godot 4.4 and press **F5** to start at the main menu. From PowerShell at the repository root, run `./tools/play.ps1`. The launcher uses `GODOT`, a Godot binary on PATH, or the temporary Windows engine used for verification on this machine.

To build for iPhone from Windows, follow the [Codemagic and TestFlight setup](IOS_EXPORT.md).

## Play

1. Choose **Survival**, tap an open terrain tile beside the road, and build an Arrow or Cannon. Arrow starts at 13 damage and 3.7 tiles of range. Cannon covers 2.6 tiles and deals splash damage.
2. Regular waves launch after 30 seconds. Tap **Pause timer** to hold the countdown, **Start Wave** to launch early, or **Speed** to cycle from 1× through 4× during combat. **Pause** or **Esc** pauses the game. Tap a forecast chip for enemy groups, elements, armor, and speed.
3. Before waves 5, 10, 15, and every fifth wave thereafter, choose an elemental spirit. Its solo bonus starts immediately and awards the tier and gold when it ends. A spirit that reaches the gate costs five lives. Every tenth regular wave has a boss with a 50% higher bounty.
4. Infuse an Arrow or Cannon from level 2, including during combat. The maximum infusion tiers are I at levels 2–3, II at 4–5, and III at 6. Standard elemental towers cap at levels 2, 4, and 6 with Tier I, II, and III, respectively. A Tier III unlock also lets you build a **Pure** tower of that element. The three Pure slots are shared across all elements. Each Tier II or III spirit defeated grants +10% damage for its element, and mixed towers weight the bonus by their damage split.
5. Select a level-2+ standard elemental tower, tap **Fuse**, then choose a highlighted level-2+ partner of a different element. A level-2+ dual can take a third, distinct level-2+ elemental tower. The book icon opens the tower overview, and the six tier badges open it filtered by element. Select a tower to inspect stats, matchups, exact effects by level, and linked fusion recipes.
6. Tap a stunned tower to Rally during a Warlock wave. After game over, **Retry** starts a fresh run.
7. **Continue** restores the last checkpoint, including active combat if the game saved during a wave. The game writes checkpoints after actions, at round boundaries, and when pausing or leaving.

Portrait and landscape use the same controls. All six elements and both starter towers fit in the build palette. Tap **Upgrade** to compare the current and next-level stats. Tap or hover an enemy to inspect its traits and active ailments. Shielded enemies block damage for 2 seconds every 5 seconds, beginning 5 seconds after spawn. After wave 10, formations gain armor, health, and reinforcements. Swift groups gain speed and have lower health and armor than standard groups. The pause menu has separate **Music**, **Sound effects**, and **Haptics** switches.

Dual fusions cost 313 gold and triple fusions cost 638 gold. For fusion, elemental tower levels 2–3 count as rank 1, levels 4–5 as rank 2, and level 6 as rank 3. A dual contributes its own rank to a triple. The fusion uses the lower ingredient rank, capped by the lowest unlocked element tier in the recipe. That same tier cap applies to upgrades. An attacking result retains at least the stronger ingredient's damage per hit.

Reach waves 30, 60, 90, and so on to earn a **Pure Crystal** before the wave begins. Select a Tier III level-6 elemental tower or a **Pure** tower and tap **Use Crystal** to preview and confirm a permanent +25% damage per crystal. Multiple crystals can strengthen the same tower. A green chevron marks towers that can upgrade or use a crystal now.

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
