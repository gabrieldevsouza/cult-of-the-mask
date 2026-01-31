extends ColorRect
class_name CrowdNPC

signal selected(npc: CrowdNPC)
signal escaped(npc: CrowdNPC)

@export var is_sinner: bool = false
@export var debug_show_sinner: bool = true

var velocity: Vector2 = Vector2.ZERO
var ui_top_margin := 120.0
var square_size := 50.0

# Escape behavior
var escaping := false
var escape_dir: Vector2 = Vector2.ZERO
var escape_speed: float = 0.0
var escape_margin: float = 30.0  # how far outside counts as "escaped"

# Efeito monóculo
var monoculo_active := false
var pulse_tween: Tween = null

func setup(_is_sinner: bool, _debug_show_sinner: bool, _velocity: Vector2, _square_size: float, _ui_top_margin: float) -> void:
	is_sinner = _is_sinner
	debug_show_sinner = _debug_show_sinner
	velocity = _velocity
	square_size = _square_size
	ui_top_margin = _ui_top_margin

	if debug_show_sinner and is_sinner:
		color = Color.RED
	else:
		color = Color.GRAY

	mouse_filter = Control.MOUSE_FILTER_STOP

func set_speed_magnitude(new_speed: float) -> void:
	if velocity.length() < 0.001:
		velocity = Vector2.RIGHT * new_speed
	else:
		velocity = velocity.normalized() * new_speed

func start_escape(uniform_speed: float, preferred_dir: Vector2 = Vector2.ZERO) -> void:
	escaping = true
	escape_speed = uniform_speed

	if preferred_dir.length() > 0.001:
		escape_dir = preferred_dir.normalized()
	else:
		# If no dir provided, keep going in current direction
		if velocity.length() < 0.001:
			escape_dir = Vector2.RIGHT
		else:
			escape_dir = velocity.normalized()

func _process(delta: float) -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	var viewport_size := viewport_rect.size

	if escaping:
		# Escape movement: NO BOUNCE. Let them leave the screen.
		position += escape_dir * escape_speed * delta

		# Escaped check (fully outside with margin)
		if position.x + square_size < -escape_margin \
		or position.x > viewport_size.x + escape_margin \
		or position.y + square_size < -escape_margin \
		or position.y > viewport_size.y + escape_margin:
			escaped.emit(self)

		return

	# Normal movement (in-city): bounce
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

	# Sinner twitch clue (subtle)
	if is_sinner:
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
	if pulse_tween and is_instance_valid(pulse_tween):
		pulse_tween.kill()

	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.4).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT)

func stop_monoculo_effect() -> void:
	monoculo_active = false
	if pulse_tween and is_instance_valid(pulse_tween):
		pulse_tween.kill()
	scale = Vector2(1.0, 1.0)
