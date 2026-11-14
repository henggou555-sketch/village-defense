# Village Defense (Godot 4.7)

Top-down 2D village defense. Survive 100 nights.

## Rules
- Each cycle is 4 minutes: 1 minute of day, then 3 minutes of night. There are no zombies during the day.
- Mines produce coins. Spend coins on more mines, turrets, walls, soldiers and land.
- **Territory:** the map is 9x9 plots. You start with the core plot (red outline). You can buy any plot that borders land you own.
- If a zombie is still alive inside one of your plots when night ends, you lose that plot and everything built on it. Kill invaders before dawn to keep the land.
- If any zombie enters the **core** plot, you lose the game.
- **Fungus-infested zombies** (purple with orange spots) leave a fungus patch when they die. During the night each patch spawns 4 more fungus zombies every 30 seconds. Patches stay through the day until you destroy them.

- **Terrain** is random every game: one or two winding rivers, rock fields and forests. You can't build on terrain until you clear it. Rivers never cross the core or the plots around it. Water halves the speed of zombies and soldiers.
- **Turrets** turn to face their target in 16 directions.

## Controls
| Input | Action |
|---|---|
| 1 / 2 / 3 | Mine / Turret / Wall build mode (hold and drag to place walls) |
| 4 | Recruit a soldier |
| 5 | Buy land mode |
| C | Clear land mode: remove a tree (10), rock (30) or fill water (50) on land you own. Hold and drag to clear several |
| X | Demolish mode (50% refund) |
| LMB drag | Select soldiers |
| RMB | Cancel build mode, or move selected soldiers |
| Q | Select all soldiers |
| N | Start the night early |
| F | Game speed 1x / 2x / 3x |
| P or Space | Pause |
| WASD / arrows, middle-drag, wheel | Pan and zoom the camera |

## Tuning
All numbers (costs, HP, wave sizes, timings) are in `scripts/config.gd`.

## Autotest
`godot --headless --path . -- --autotest` builds a fixed base, runs the game at 8x speed and prints a line for every day and night.
