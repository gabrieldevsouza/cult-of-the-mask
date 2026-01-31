extends ColorRect
class_name CrowdNPC

signal selected(npc: CrowdNPC)

@export var is_sinner: bool = false
@export var debug_show_sinner: bool = true

var velocity: Vector2 = Vector2.ZERO
var speed_min := 50.0
var speed_max := 150.0
var ui_top_margin := 120.0
var square_size := 50.0

# Efeito monóculo
var monoculo_active := false
var pulse_tween: Tween = null

func setup(_is_sinner: bool, _debug_show_sinner: bool, _velocity: Vector2, _square_size: float, _ui_top_margin: float) -> void:
	is_sinner = _is_sinner
	debug_show_sinner = _debug_show_sinner
	velocity = _velocity
	square_size = _square_size
	ui_top_margin = _ui_top_margin

	# Debug visuals: sinner can be red, otherwise gray
	if debug_show_sinner and is_sinner:
		color = Color.RED
	else:
		color = Color.GRAY

	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	# Movement is handled by spawner OR here — Wave 1 keeps it here to reduce shared state.
	var viewport_size := get_viewport().get_visible_rect().size
	position += velocity * delta

	# Bounce X
	if position.x <= 0:
		position.x = 0
		velocity.x = abs(velocity.x)
	elif position.x + square_size >= viewport_size.x:
		position.x = viewport_size.x - square_size
		velocity.x = -abs(velocity.x)

	# Bounce Y (respect UI)
	if position.y <= ui_top_margin:
		position.y = ui_top_margin
		velocity.y = abs(velocity.y)
	elif position.y + square_size >= viewport_size.y:
		position.y = viewport_size.y - square_size
		velocity.y = -abs(velocity.y)

	# Simple sinner "behavior clue" (cheap): slightly faster drift + occasional twitch
	if is_sinner:
		# tiny random twitch that stands out subtly
		if randi() % 120 == 0:
			velocity = velocity.rotated(randf_range(-0.35, 0.35))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(self)

func apply_monoculo_effect() -> void:
	if not is_sinner or monoculo_active:
		return

	monoculo_active = true
	_start_pulse()

func _start_pulse() -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()

	pulse_tween = create_tween()
	pulse_tween.set_loops()

	# Pulso: escala de 1.0 -> 1.2 -> 1.0
	pulse_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.4).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT)

func stop_monoculo_effect() -> void:
	monoculo_active = false
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	scale = Vector2(1.0, 1.0)
