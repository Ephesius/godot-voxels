extends Label

## FPS Counter - displays performance metrics in top-left corner

# Update interval in seconds (don't update every frame, too flickery)
const UPDATE_INTERVAL: float = 0.1

var time_since_update: float = 0.0
var frame_count: int = 0

# Optional references for additional stats
var chunk_manager: ChunkManager = null
var player: Node3D = null

func _ready() -> void:
	# Position in top-left corner with some padding
	position = Vector2(10, 10)

	# Style the label for readability
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color.YELLOW)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 2)

func _process(delta: float) -> void:
	time_since_update += delta
	frame_count += 1

	# Update display at regular intervals
	if time_since_update >= UPDATE_INTERVAL:
		var fps: float = frame_count / time_since_update
		var frame_time: float = (time_since_update / frame_count) * 1000.0  # Convert to ms

		# Build stats text
		var stats_text: String = "FPS: %.1f\nFrame Time: %.2f ms" % [fps, frame_time]

		# Add player position if available
		if player != null:
			stats_text += "\n\nPosition: X: %.1f  Y: %.1f  Z: %.1f" % [
				player.position.x,
				player.position.y,
				player.position.z
			]

		# Add chunk manager stats if available
		if chunk_manager != null:
			var chunks_loaded: int = chunk_manager.chunks.size()
			var queue_size: int = chunk_manager.chunk_generation_queue.size()
			var being_generated: int = chunk_manager.chunks_being_generated.size()

			stats_text += "\n\nChunks Loaded: %d" % chunks_loaded
			stats_text += "\nGeneration Queue: %d" % queue_size
			stats_text += "\nBeing Generated: %d" % being_generated

		text = stats_text

		# Reset counters
		time_since_update = 0.0
		frame_count = 0

func set_chunk_manager(cm: ChunkManager) -> void:
	chunk_manager = cm

func set_player(p: Node3D) -> void:
	player = p
