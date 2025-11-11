class_name BiomeSelector
extends RefCounted

## Selects appropriate block types based on climate data
##
## This class implements biome rules that map climate conditions
## (temperature, humidity, elevation) to specific block types.
##
## Climate Zones:
## - HOT (temp > 0.66): Desert (dry) or Grassland (wet)
## - TEMPERATE (0.33 < temp < 0.66): Grassland
## - COLD (temp < 0.33): Snowy (wet) or Icy (dry)

# Climate thresholds
const TEMP_HOT_THRESHOLD: float = 0.66
const TEMP_COLD_THRESHOLD: float = 0.33
const HUMIDITY_WET_THRESHOLD: float = 0.5
const SEA_LEVEL: int = 64

# Subsurface constants
const DIRT_LAYER_DEPTH: int = 4  # How many blocks of dirt below surface


## Select the appropriate block type for a given position and climate
func select_block(temperature: float, humidity: float, elevation: int, y: int) -> Block.Type:
	# Below sea level: water or ice
	if y < SEA_LEVEL:
		if y > elevation:  # Above ocean floor but below sea level = water
			return _get_water_type(temperature)
		else:
			return _get_subsurface_block(y, elevation)

	# Above sea level but below terrain: solid ground
	if y < elevation:
		return _get_subsurface_block(y, elevation)

	# At surface level
	if y == elevation:
		return _get_surface_block(temperature, humidity)

	# Above terrain: air
	return Block.Type.AIR


## Determine surface block based on climate
func _get_surface_block(temperature: float, humidity: float) -> Block.Type:
	# HOT climates
	if temperature > TEMP_HOT_THRESHOLD:
		if humidity > HUMIDITY_WET_THRESHOLD:
			return Block.Type.GRASS  # Hot + wet = lush grassland/jungle
		else:
			return Block.Type.SAND  # Hot + dry = desert

	# COLD climates
	elif temperature < TEMP_COLD_THRESHOLD:
		if humidity > HUMIDITY_WET_THRESHOLD:
			return Block.Type.SNOW  # Cold + wet = snowy
		else:
			return Block.Type.ICE  # Cold + dry = icy tundra

	# TEMPERATE climates (default)
	else:
		return Block.Type.GRASS  # Standard grassland


## Determine water or ice for submerged areas
func _get_water_type(temperature: float) -> Block.Type:
	# Frozen water in cold climates
	if temperature < TEMP_COLD_THRESHOLD:
		return Block.Type.ICE
	else:
		return Block.Type.WATER


## Determine subsurface block (dirt near surface, stone deeper)
func _get_subsurface_block(y: int, surface_elevation: int) -> Block.Type:
	var depth_below_surface: int = surface_elevation - y

	# Dirt layer just below surface
	if depth_below_surface <= DIRT_LAYER_DEPTH:
		return Block.Type.DIRT
	# Stone deeper underground
	else:
		return Block.Type.STONE


## Get a human-readable biome name for debugging/visualization
func get_biome_name(temperature: float, humidity: float) -> String:
	if temperature > TEMP_HOT_THRESHOLD:
		if humidity > HUMIDITY_WET_THRESHOLD:
			return "Tropical Grassland"
		else:
			return "Desert"
	elif temperature < TEMP_COLD_THRESHOLD:
		if humidity > HUMIDITY_WET_THRESHOLD:
			return "Snowy Tundra"
		else:
			return "Icy Tundra"
	else:
		return "Temperate Grassland"
