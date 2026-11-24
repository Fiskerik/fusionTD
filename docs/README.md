# Elemental TD

Hold Greenmarch Gate for as many waves as you can in Survival. The run continues until the gate falls. You can leave and resume from a checkpoint. Older Quick, Standard, and Endless checkpoints can still be resumed.

## Run on Windows

Open the repository’s `project.godot` in Godot 4.4 and press **F5** to start at the main menu. From PowerShell at the repository root, run `./tools/play.ps1`. The launcher uses `GODOT`, a Godot binary on PATH, or the temporary Windows engine used for verification on this machine.

To build for iPhone from Windows, follow the [Codemagic and TestFlight setup](IOS_EXPORT.md).

## Play

1. Start Survival, tap an open terrain tile beside the road, and build an Arrow or Cannon. Arrow starts at 13 damage and 3.7 tiles of range. Cannon covers 2.6 tiles and deals splash damage.
2. You get 30 seconds before the first wave, 10 seconds before regular waves, and 20 seconds before events. Swipe right or tap **Start Wave** to launch early. Each combat round pays 4% interest on unspent gold before the first enemy spawns. **Menu** pauses the game. The **book** opens the tower and element overview while combat continues. Tap a forecast card to pin a compact preview, then expand it for enemy details and tower matchups.
3. Each five-wave block has three short waves, one medium wave, and an event. Every tenth wave is a boss encounter preceded by a separate solo Spirit trial while any element tiers remain locked. The bonus trial leaves the wave number unchanged. Wave 35 is a Spirit trial. Scheduled Roadside Merchants offer gate repairs from wave 65. The wave-10 Warlock can disable just one tower for two seconds, once per fight. Later bosses have recharging Reflect shields. Regular enemy waves have a 5% chance to include a Gilded Courier whose bounty is 40% of the combined bounty of the other enemies in that wave.
4. Infuse an Arrow or Cannon from level 2, including during combat. The maximum infusion tiers are I at levels 2–3, II at 4–5, and III at 6. Standard elemental towers cap at levels 2, 4, and 6 with Tier I, II, and III, respectively. A Tier III unlock also lets you build a **Pure** tower of that element. The three Pure slots are shared across all elements. Each Tier II or III spirit defeated grants +10% damage for its element, and mixed towers weight the bonus by their damage split.
5. Select a level-2+ standard elemental tower, tap **Fuse**, then choose a highlighted level-2+ partner of a different element. Any dual can take a third, distinct level-2+ elemental tower. The book icon in the menu opens the tower overview, and unlocked tier badges open it filtered by element. Select a tower to inspect stats, matchups, exact effects by level, and linked fusion recipes.
6. Tap a stunned tower to Rally during a Warlock wave. After game over, **Retry** starts a fresh run.
7. **Continue** restores the last checkpoint, including active combat if the game saved during a wave. The game writes checkpoints after actions, at round boundaries, and when pausing or leaving.

Each run starts with three stone blocks. Double-tap a road tile during combat to place a stone for five seconds. It pushes enemies off that tile and holds back those behind it. You can place one per numbered wave, with a 60-second combat-time cooldown.

Portrait and landscape use the same controls. All seven elements and both starter towers fit in the build palette. Earth towers hit hard in a small area at short range. Tap **Upgrade** to compare the current and next-level stats. Tap or hover an enemy to inspect its traits and active ailments. Shielded enemies block damage for 2 seconds every 5 seconds, beginning 5 seconds after spawn. After wave 10, formations gain armor, health, and reinforcements. Swift groups gain speed and have lower health and armor than standard groups. The pause menu has separate **Music**, **Sound effects**, and **Haptics** switches.

Dual fusions cost 344 gold and triple fusions cost 798 gold before discounts and upgrade credits. Credits can reduce the fee to zero. For fusion, elemental tower levels 2–3 count as rank 1, levels 4–5 as rank 2, and level 6 as rank 3. A dual contributes its own rank to a triple. The fusion uses the lower ingredient rank, capped by the lowest unlocked element tier in the recipe. That same tier cap applies to upgrades. An attacking result retains at least the stronger ingredient's damage per hit.

Waves schedule up to 48 enemies, with a matching on-field cap. Most regular waves from wave 6 have a single visible elemental affinity. Some remain neutral, and some mix two elements from wave 11. From wave 41, regular enemies gain extra health and armor.

New campaigns draw one of ten centered Greenmarch routes from the run seed. The saved route, active boon, and pending choices travel with the checkpoint. After the fight, each defeated boss offers a weaker general boon, a boon for an unlocked element, and a stronger boon from the full elemental roster. The unlocked slot draws from the full roster if you have yet to unlock an element. Choose one offer or keep the active boon. Offers gain 10 percentage points of base potency every ten waves after wave 10 through wave 100, then four points every ten waves. Individual effects have caps. Tap the boon in the HUD or open **Active boon** in the pause menu to see its full effects.

Chameleons adapt to elemental hits, Banner Bearers rally nearby enemies, Burrowers hide underground, Thieves steal gold at the gate, and Saboteurs jam the closest upgradeable tower. Upgrade or fuse a jammed tower to restore it.

Stonegaze Basilisks stay out of wave 9. They appear on every subsequent wave ending in 9 and have a 10% chance to appear in other regular enemy waves. On spawn, they mark two random towers for petrification. Marked towers become inactive through the next numbered wave and its spirit trial. From wave 15, Void Wizards have a 25% chance to appear in regular enemy waves. They wait for three seconds at each stop, or six seconds from wave 30, then vanish for two seconds before materializing at the next corner or the castle.

Reach waves 30, 60, 90, and so on to earn a **Pure Crystal** before the wave begins. Either ascend a level-6 elemental tower or build a level-7 **Pure** tower directly for 1,500 gold and one Pure Crystal. These towers share a three-tower limit, display a gold star on the board, and are ineligible for fusion. A green chevron marks towers that can upgrade now.

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

Use the same seeds with `--opening dark` and `--opening water` to compare starter elements. Add `--no-fusion` or `--force-trial 2:15` for other comparison runs. The [balance report](BALANCE_REPORT.md) records earlier samples.
