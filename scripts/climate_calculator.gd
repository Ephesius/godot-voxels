class_name ClimateCalculator
extends RefCounted

## Calculates climate properties (temperature, humidity, elevation) for world positions
##
## This class determines environmental conditions based on:
## - Distance from equator (z=0) for base temperature
## - Perlin noise for humidity variation (x and z axes)
## - Perlin noise for elevation generation
## - Elevation-based temperature adjustment (higher = cooler)

# World constants
const WORLD_HALF_WIDTH: int = 1500  # Distance from center to pole (z-axis)
const SEA_LEVEL: int = 64
const MIN_TERRAIN_HEIGHT: int = 40
const MAX_TERRAIN_HEIGHT: int = 150
const TERRAIN_HEIGHT_RANGE: int = MAX_TERRAIN_HEIGHT - MIN_TERRAIN_HEIGHT

# Temperature adjustment
const ELEVATION_TEMP_REDUCTION: float = 0.4  # How much elevation reduces temperature

# Noise generators
var elevation_noise: FastNoiseLite
var humidity_noise: FastNoiseLite

func _init(seed_value: int = 0) -> void:
	# Initialize elevation noise (for terrain height)
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = seed_value
	elevation_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	elevation_noise.frequency = 0.003  # Low frequency = smooth, rolling hills
	elevation_noise.fractal_octaves = 4  # Multiple octaves for detail
	elevation_noise.fractal_lacunarity = 2.0
	elevation_noise.fractal_gain = 0.5

	# Initialize humidity noise (for biome variation along x-axis)
	humidity_noise = FastNoiseLite.new()
	humidity_noise.seed = seed_value + 1000  # Different seed for variation
	humidity_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	humidity_noise.frequency = 0.005  # Slightly higher frequency for more variation
	humidity_noise.fractal_octaves = 2


## Calculate all climate data for a given world position
func get_climate_at(world_x: int, world_z: int) -> Dictionary:
	var base_temp: float = _calculate_base_temperature(world_z)
	var humidity: float = _calculate_humidity(world_x, world_z)
	var elevation: int = _calculate_elevation(world_x, world_z, base_temp)
	var final_temp: float = _adjust_temperature_for_elevation(base_temp, elevation)

	return {
		"temperature": clampf(final_temp, 0.0, 1.0),
		"humidity": clampf(humidity, 0.0, 1.0),
		"elevation": elevation
	}


## Calculate base temperature from distance to equator
## Returns: 0.0 (polar/cold) to 1.0 (equatorial/hot)
func _calculate_base_temperature(world_z: int) -> float:
	var distance_from_equator: float = abs(world_z) / float(WORLD_HALF_WIDTH)
	# Use a curve for more realistic temperature distribution
	# 1.0 at equator, gradual falloff to poles
	return 1.0 - pow(distance_from_equator, 0.8)


## Calculate humidity using Perlin noise
## Returns: 0.0 (dry/desert) to 1.0 (wet/rainforest)
func _calculate_humidity(world_x: int, world_z: int) -> float:
	var noise_value: float = humidity_noise.get_noise_2d(world_x, world_z)
	# Convert from [-1, 1] to [0, 1]
	return (noise_value + 1.0) / 2.0


## Calculate elevation using Perlin noise
## Considers base temperature to create realistic terrain
## (e.g., flatter terrain near poles, varied terrain in temperate zones)
func _calculate_elevation(world_x: int, world_z: int, base_temp: float) -> int:
	var noise_value: float = elevation_noise.get_noise_2d(world_x, world_z)

	# Convert noise from [-1, 1] to [0, 1]
	var normalized_noise: float = (noise_value + 1.0) / 2.0

	# Apply temperature-based terrain variation
	# Polar regions (low temp) have flatter terrain
	# Temperate/tropical regions have more variation
	var terrain_multiplier: float = 0.5 + (base_temp * 0.5)  # 0.5 to 1.0

	# Calculate height in range [MIN_TERRAIN_HEIGHT, MAX_TERRAIN_HEIGHT]
	var height_variation: float = normalized_noise * TERRAIN_HEIGHT_RANGE * terrain_multiplier
	var final_height: int = MIN_TERRAIN_HEIGHT + int(height_variation)

	return clampi(final_height, MIN_TERRAIN_HEIGHT, MAX_TERRAIN_HEIGHT)


## Adjust temperature based on elevation (higher altitude = cooler)
func _adjust_temperature_for_elevation(base_temp: float, elevation: int) -> float:
	# Calculate how far above sea level we are (normalized)
	var elevation_above_sea: float = maxf(0.0, elevation - SEA_LEVEL)
	var max_elevation_above_sea: float = MAX_TERRAIN_HEIGHT - SEA_LEVEL
	var elevation_factor: float = elevation_above_sea / max_elevation_above_sea

	# Reduce temperature based on elevation
	return base_temp - (elevation_factor * ELEVATION_TEMP_REDUCTION)
