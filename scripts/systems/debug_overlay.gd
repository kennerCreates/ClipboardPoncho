extends CanvasLayer
class_name DebugOverlay
## Performance overlay showing FPS, frame time, and draw calls
##
## Toggle with F3 key. Updates every frame with current performance metrics.

# UI Elements
var panel: PanelContainer
var label: Label

# Performance tracking
var frame_times: Array[float] = []
const MAX_FRAME_SAMPLES: int = 60  # Average over 1 second at 60fps

# Visibility state
var overlay_visible: bool = false

func _ready() -> void:
	# Create UI hierarchy
	_create_ui()

	# Start hidden
	visible = overlay_visible

	# Set to process input
	set_process_input(true)

func _create_ui() -> void:
	# Create panel container
	panel = PanelContainer.new()
	panel.position = Vector2(10, 10)
	add_child(panel)

	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	# Create label
	label = Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)

func _input(event: InputEvent) -> void:
	# Toggle with F3 key
	if event is InputEventKey:
		if event.keycode == KEY_F3 and event.pressed and not event.echo:
			toggle()

func toggle() -> void:
	overlay_visible = not overlay_visible
	visible = overlay_visible

func _process(delta: float) -> void:
	if not overlay_visible:
		return

	# Track frame time
	frame_times.append(delta)
	if frame_times.size() > MAX_FRAME_SAMPLES:
		frame_times.pop_front()

	# Calculate average frame time
	var avg_frame_time = 0.0
	for ft in frame_times:
		avg_frame_time += ft
	avg_frame_time /= frame_times.size()

	# Get performance metrics
	var fps = Engine.get_frames_per_second()
	var frame_time_ms = avg_frame_time * 1000.0
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects_drawn = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var vertices_drawn = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)

	# Get memory usage
	var static_mem = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0  # MB
	var static_mem_max = Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1024.0 / 1024.0  # MB

	# Update label
	label.text = """FPS: %d
Frame Time: %.2f ms
Draw Calls: %d
Objects: %d
Vertices: %d
Memory: %.1f / %.1f MB""" % [
		fps,
		frame_time_ms,
		draw_calls,
		objects_drawn,
		vertices_drawn,
		static_mem,
		static_mem_max
	]
