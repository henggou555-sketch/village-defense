class_name Cfg
extends RefCounted
## All tuning numbers live here so balancing is easy.

# --- Map ---
const TILE := 32                    # one building = one tile
const PLOT_TILES := 6               # a territory plot is 6x6 tiles
const PLOT := TILE * PLOT_TILES     # plot size in pixels
const GRID := 9                     # map is 9x9 plots
const MAP := PLOT * GRID            # map size in pixels
const CORE := Vector2i(4, 4)        # the village core plot (center)

# --- Time ---
const DAY_LEN := 60.0               # 1 minute of day
const NIGHT_LEN := 180.0            # 3 minutes of night
const SPAWN_WINDOW := 150.0         # zombies arrive during the first 2.5 min of night
const MAX_NIGHTS := 100

# --- Economy ---
const START_COINS := 250
const PLOT_BASE_COST := 100         # first extra plot
const PLOT_COST_STEP := 50          # each owned plot makes the next one pricier
const MINE_INCOME := 5
const MINE_INTERVAL := 4.0
const MINE_COST_STEP := 15          # each mine makes the next one pricier
const KILL_REWARD := 2
const FUNGAL_KILL_REWARD := 3
const FUNGUS_KILL_REWARD := 10
const REFUND := 0.5                 # demolish refund

# --- Terrain clearing ---
const CLEAR_TREE := 10
const CLEAR_ROCK := 30
const CLEAR_WATER := 50
const WATER_SLOW := 0.5             # zombies and soldiers move at half speed in water

# --- Defense ---
const TURRET_RANGE := 210.0
const TURRET_DMG := 22.0
const TURRET_RATE := 0.8

const SOLDIER_COST := 40
const SOLDIER_HP := 100.0
const SOLDIER_RANGE := 150.0
const SOLDIER_LEASH := 240.0        # how far from their post soldiers will chase
const SOLDIER_DMG := 12.0
const SOLDIER_RATE := 0.6
const SOLDIER_SPEED := 80.0

# --- Enemies ---
const ZOMBIE_AGGRO := 130.0         # zombies attack structures/soldiers this close
const ZOMBIE_HP_PER_NIGHT := 0.04   # +4% hp per night
const FUNGUS_INTERVAL := 30.0
const FUNGUS_HP := 160.0
const FUNGUS_SPAWN := 4
const MAX_ZOMBIES := 500
const MAX_FUNGUS := 80

const BUILDINGS := {
	"mine": {"name": "Mine", "cost": 60, "hp": 120.0, "size": 1},
	"turret": {"name": "Turret", "cost": 100, "hp": 250.0, "size": 1},
	"wall": {"name": "Wall", "cost": 15, "hp": 300.0, "size": 1},
	"hall": {"name": "Town Hall", "cost": 0, "hp": 1000.0, "size": 2},
}


static func wave_size(night: int) -> int:
	return 5 + night * 3


static func fungal_ratio(night: int) -> float:
	if night < 2:
		return 0.0
	return clampf(0.1 + night * 0.005, 0.0, 0.5)
