extends Control
class_name CrowdNPC

signal selected(npc: CrowdNPC)
signal escaped(npc: CrowdNPC)

@export var is_sinner: bool = false
@export var debug_show_sinner: bool = true

var velocity: Vector2 = Vector2.ZERO
var ui_top_margin := 120.0
var square_size := 50.0

# Escape behavior (timed)
var escaping := false
var escape_dir: Vector2 = Vector2.ZERO
var escape_speed: float = 0.0
var escape_margin: float = 40.0 # how far outside counts as "escaped"
var allow_bounce := true

# Pause movement (during dialogue)
var is_frozen := false

# Walkable areas constraint
var walkable_areas: Array[Rect2] = []
var use_walkable_areas := false

# Efeito monóculo
var monoculo_active := false
var pulse_tween: Tween = null

# Sprite animation
var sprite: TextureRect
var sprite_sheet_left: Texture2D
var sprite_sheet_right: Texture2D
var current_direction := 1  # 1 = right, -1 = left

# Animation
const FRAME_COUNT := 6
const ANIMATION_FPS := 10.0
var current_frame := 0
var animation_timer := 0.0
var frame_width := 0
var frame_height := 0
var atlas_texture: AtlasTexture

# Innocent sprite (citizens are always cultista_1)
const INNOCENT_SPRITE_LEFT := "res://sprites/cultista_1_walk_left.png"
const INNOCENT_SPRITE_RIGHT := "res://sprites/cultista_1_walk_right.png"

# Sinner sprites (randomly chosen from these options)
const SINNER_SPRITES := [
	["res://sprites/ocultista_2_walk_left.png", "res://sprites/ocultista_2_walk_right.png"],
	["res://sprites/cultista_3_walk_left_.png", "res://sprites/cultista_3_walk_right_.png"],
	["res://sprites/pecador_1_walk_left.png", "res://sprites/pecador_1_walk_rightt.png"],
]


func setup(_is_sinner: bool, _debug_show_sinner: bool, _velocity: Vector2, _square_size: float, _ui_top_margin: float) -> void:
	is_sinner = _is_sinner
	debug_show_sinner = _debug_show_sinner
	velocity = _velocity
	square_size = _square_size
	ui_top_margin = _ui_top_margin

	# Set size
	custom_minimum_size = Vector2(square_size, square_size)
	size = Vector2(square_size, square_size)

	# Create sprite if not exists
	if sprite == null:
		sprite = TextureRect.new()
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sprite)

	# Load sprite sheets
	if is_sinner:
		var sinner_index := randi() % SINNER_SPRITES.size()
		sprite_sheet_left = load(SINNER_SPRITES[sinner_index][0])
		sprite_sheet_right = load(SINNER_SPRITES[sinner_index][1])
	else:
		sprite_sheet_left = load(INNOCENT_SPRITE_LEFT)
		sprite_sheet_right = load(INNOCENT_SPRITE_RIGHT)

	# Calculate frame dimensions
	var sheet_size := sprite_sheet_right.get_size()
	frame_width = int(sheet_size.x / FRAME_COUNT)
	frame_height = int(sheet_size.y)

	# Set sprite size to match square_size
	sprite.size = Vector2(square_size, square_size)

	# Create atlas texture for animation
	atlas_texture = AtlasTexture.new()
	atlas_texture.region = Rect2(0, 0, frame_width, frame_height)

	# Set initial direction and frame
	current_frame = randi() % FRAME_COUNT  # Start at random frame
	_update_sprite_direction()

	mouse_filter = Control.MOUSE_FILTER_STOP


func _update_sprite_direction() -> void:
	var moving_right := velocity.x >= 0
	if escaping:
		moving_right = escape_dir.x >= 0

	if moving_right:
		if current_direction != 1 or atlas_texture.atlas != sprite_sheet_right:
			current_direction = 1
			atlas_texture.atlas = sprite_sheet_right
	else:
		if current_direction != -1 or atlas_texture.atlas != sprite_sheet_left:
			current_direction = -1
			atlas_texture.atlas = sprite_sheet_left

	_update_frame()


func _update_frame() -> void:
	if atlas_texture == null:
		return
	atlas_texture.region = Rect2(current_frame * frame_width, 0, frame_width, frame_height)
	sprite.texture = atlas_texture


func set_speed_magnitude(new_speed: float) -> void:
	if velocity.length() < 0.001:
		velocity = Vector2.RIGHT * new_speed
	else:
		velocity = velocity.normalized() * new_speed


# Timed escape: move towards target so we leave the screen at ~exactly duration
func start_timed_escape_to(target_pos: Vector2, duration: float) -> void:
	escaping = true
	allow_bounce = false

	var from := position
	var delta := target_pos - from
	if delta.length() < 0.001:
		escape_dir = Vector2.RIGHT
		escape_speed = 0.0
		return

	escape_dir = delta.normalized()
	escape_speed = delta.length() / max(duration, 0.001)
	_update_sprite_direction()


func _process(delta: float) -> void:
	# Update z_index based on Y position for depth sorting
	# NPCs lower on screen (higher Y) appear in front
	z_index = int(position.y + square_size)

	# Don't move if frozen (during dialogue)
	if is_frozen:
		return

	var viewport_rect := get_viewport().get_visible_rect()
	var viewport_size := viewport_rect.size

	# Animate sprite
	animation_timer += delta
	if animation_timer >= 1.0 / ANIMATION_FPS:
		animation_timer = 0.0
		current_frame = (current_frame + 1) % FRAME_COUNT
		_update_frame()

	if escaping:
		# No bounce. Leave city.
		position += escape_dir * escape_speed * delta

		# Escaped check
		if position.x + square_size < -escape_margin \
		or position.x > viewport_size.x + escape_margin \
		or position.y + square_size < -escape_margin \
		or position.y > viewport_size.y + escape_margin:
			escaped.emit(self)

		return

	# Normal movement
	var new_pos := position + velocity * delta
	var center := new_pos + Vector2(square_size / 2, square_size / 2)

	var direction_changed := false

	# Check walkable area constraints first
	if use_walkable_areas:
		if not is_point_in_walkable_area(center):
			# Find which walkable area we were in and bounce
			var old_center := position + Vector2(square_size / 2, square_size / 2)
			for area in walkable_areas:
				if area.has_point(old_center):
					# Bounce off the boundary we're hitting
					if center.x < area.position.x or center.x > area.end.x:
						velocity.x = -velocity.x
						direction_changed = true
					if center.y < area.position.y or center.y > area.end.y:
						velocity.y = -velocity.y
					break
			# Recalculate position with bounced velocity
			new_pos = position + velocity * delta
			center = new_pos + Vector2(square_size / 2, square_size / 2)
			# If still outside, just keep old position
			if not is_point_in_walkable_area(center):
				new_pos = position

	position = new_pos

	if allow_bounce:
		# Bounce X (screen edges)
		if position.x <= 0:
			position.x = 0
			velocity.x = abs(velocity.x)
			direction_changed = true
		elif position.x + square_size >= viewport_size.x:
			position.x = viewport_size.x - square_size
			velocity.x = -abs(velocity.x)
			direction_changed = true

		# Bounce Y (respect UI)
		if position.y <= ui_top_margin:
			position.y = ui_top_margin
			velocity.y = abs(velocity.y)
		elif position.y + square_size >= viewport_size.y:
			position.y = viewport_size.y - square_size
			velocity.y = -abs(velocity.y)

	# Update sprite direction if changed
	if direction_changed:
		_update_sprite_direction()

	# Sinner twitch clue (subtle)
	if is_sinner:
		if randi() % 120 == 0:
			var old_vx := velocity.x
			velocity = velocity.rotated(randf_range(-0.35, 0.35))
			# Check if direction changed
			if (old_vx >= 0) != (velocity.x >= 0):
				_update_sprite_direction()


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


func freeze() -> void:
	is_frozen = true


func unfreeze() -> void:
	is_frozen = false


func set_direction(dir: int) -> void:
	# dir: 1 = right, -1 = left
	if dir >= 0:
		current_direction = 1
		atlas_texture.atlas = sprite_sheet_right
	else:
		current_direction = -1
		atlas_texture.atlas = sprite_sheet_left
	_update_frame()


func look_at_position(target_pos: Vector2) -> void:
	# Look towards a position
	var my_center := position + Vector2(square_size / 2, square_size / 2)
	if target_pos.x > my_center.x:
		set_direction(1)  # Look right
	else:
		set_direction(-1)  # Look left


func set_walkable_areas(areas: Array[Rect2]) -> void:
	walkable_areas = areas
	use_walkable_areas = areas.size() > 0


func is_point_in_walkable_area(point: Vector2) -> bool:
	if not use_walkable_areas:
		return true
	for area in walkable_areas:
		if area.has_point(point):
			return true
	return false


func get_constrained_position(new_pos: Vector2) -> Vector2:
	if not use_walkable_areas:
		return new_pos

	var center := new_pos + Vector2(square_size / 2, square_size / 2)

	# If new position is in a walkable area, allow it
	if is_point_in_walkable_area(center):
		return new_pos

	# Otherwise, keep the old position
	return position
