# Historical Survival balance report

This study predates the standalone bonus rounds. Current spirit trials have one attempt, and their outcomes follow different rules. Tier II now starts at 2,100 HP, with 7.4% growth per regular wave after wave 7.

Godot 4.4.1, twenty seeds per scenario (1–20). The default and fusion-disabled bots ran to defeat or wave 44. Forced-trial runs ended after the specified trial wave or defeat. The bot reports cleared waves, gate lives, unspent gold, spirit leaks, and boss outcomes. All 200 runs completed without script errors.

The comparison bot uses the original set of build sites and their original unlock timing. Players can build on any open terrain tile from wave 1.

## Baseline and fusion comparison

| Check | Brief target | Measured |
|---|---:|---:|
| Runs losing gate lives to the opening packs, waves 1–3 | 0 | 0/20 |
| Median lives lost by wave 9 | ≤3 | 0 |
| Tier I spirit wins, waves 4, 7, 10, and 13 | ≥90% each | 20/20 each, all on one pass |
| Wave 10 Warlock kills | ≥70% | 20/20 |
| Wave 20 Ram Captain kills | ≥50% | 18/20 |
| Median wave cleared | 22–40 | 35.5 |
| Fusion versus no fusion | With fusion ≥ without | 35.5 versus 34.0 median cleared |
| Highest wave cleared | 30-wave smoke coverage | 39 |

The fusion strategy made a median of four fusions. Ten fusion runs killed the wave 30 Necromancer, compared with one run without fusion.

## Forced Water Spirit trials

An eventual kill includes wins after the spirit returns. Leaks are counted even when the final leak ends the run. The forced harness can place a spirit between normal selection waves and provide its tier prerequisite.

| Tier and wave | Eventually killed | Defeated on first pass | Median leaks | Brief eventual-kill target |
|---|---:|---:|---:|---:|
| II · 6 | 0/20 | 0/20 | 4 | ≤5% |
| II · 7 | 0/20 | 0/20 | 4 | Earliest regular Tier II trial |
| II · 9 | 20/20 | 0/20 | 3 | ≤5% |
| II · 12 | 20/20 | 0/20 | 1 | ≤5% |
| II · 15 | 20/20 | 0/20 | 1 | 40–70% |
| II · 18 | 20/20 | 0/20 | 1 | ≥85% |
| III · 24 | 6/20 | 0/20 | 3 | ≤5% |
| III · 33 | 9/13 attempts | 0/13 | 1 | ≥50% |

Thirteen of twenty seeds reached wave 33. Nine of all twenty completed that forced trial. At waves 9, 12, 15, and 24 the eventual kill rate exceeded the brief's target. The single-pass wins remained at zero. A separate scripted opening invested in pure Fire after Fire I and defeated Fire II on wave 7 with ten gate lives left. That result is covered by a regression test.

## Tuning changes

- Raised the base clear reward from 20 to 63 so the opening funds six level-1 Cannons. Reduced the first Tier I spirit to 390 HP. Both the five-Arrow and six-Cannon opening tests win their first trial without a leak.
- Preview runs initially stalled at wave 20. Reduced Warlock, Ram Captain, and Necromancer HP multipliers in successive probes to 12, 11, and 11, respectively. The final baseline clears wave 35.5 at the median.
- Trial probes replaced the flat-before-threshold rules with damageable HP curves. The final Tier II curve starts at 2,850 HP with 6% growth per wave after wave 7. Tier III starts at 12,000 HP with 3.5% growth per wave after wave 12. Tier II and III armor are 19 and 40.
- Increased attacking duals' base damage by 25% and diversified the bot's fusions. The fusion and no-fusion runs used the same seed set.
