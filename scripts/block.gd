class_name Block extends RefCounted

enum Type {
	AIR = 0,
	STONE = 1,
	DIRT = 2,
	GRASS = 3,
	SAND = 4,
	WATER = 5,
	SNOW = 6,
	ICE = 7
}

# Block type to color mapping (we'll use simple colors for now, textures come later)
static func get_color(type: Type) -> Color:
	match type:
		Type.AIR:
			return Color(0, 0, 0, 0)
		Type.STONE:
			return Color(0.5, 0.5, 0.5)
		Type.DIRT:
			return Color(0.6, 0.4, 0.2)
		Type.GRASS:
			return Color(0.2, 0.8, 0.2)
		Type.SAND:
			return Color(0.9, 0.85, 0.6)
		Type.WATER:
			return Color(0.2, 0.4, 0.8, 0.7)
		Type.SNOW:
			return Color(0.95, 0.95, 1.0)
		Type.ICE:
			return Color(0.7, 0.85, 1.0, 0.8)
		_:
			return Color(1, 0, 1) # Magenta for undefined blocks

# Returns true if the block is solid (not air or water)
static func is_solid(type: Type) -> bool:
	return type != Type.AIR and type != Type.WATER

# Returns true if the block is transparent
static func is_transparent(type: Type) -> bool:
	return type == Type.AIR or type == Type.WATER or type == Type.ICE
