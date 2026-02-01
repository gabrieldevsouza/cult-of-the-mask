extends Control
class_name Protagonist

var sprite: TextureRect
var sprite_sheet_left: Texture2D
var sprite_sheet_right: Texture2D
var sprite_sheet_idle: Texture2D

# Animation - Walking
const WALK_FRAME_COUNT := 8
const ANIMATION_FPS := 10.0
var current_frame := 0
var animation_timer := 0.0
var walk_frame_width := 0
var walk_frame_height := 0
var atlas_texture: AtlasTexture

# Animation - Idle
const IDLE_FRAME_COUNT := 5
const IDLE_ANIMATION_FPS := 8.0
var idle_frame_width := 0
var idle_frame_height := 0
var is_idle := true

# Movement
var target_position: Vector2
var is_moving := false
var move_speed := 250.0
var current_direction := 1  # 1 = right, -1 = left

# Size
var sprite_size := 80.0

const SPRITE_LEFT := "res://sprites/prota_walking_left.png"
const SPRITE_RIGHT := "res://sprites/prota_walking_right.png"
const SPRITE_IDLE := "res://sprites/prota-idle.png"


func _ready() -> void:
	# Create sprite
	sprite = TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sprite)

	# Set size
	custom_minimum_size = Vector2(sprite_size, sprite_size)
	size = Vector2(sprite_size, sprite_size)
	sprite.size = Vector2(sprite_size, sprite_size)

	# Load sprite sheets
	sprite_sheet_left = load(SPRITE_LEFT)
	sprite_sheet_right = load(SPRITE_RIGHT)
	sprite_sheet_idle = load(SPRITE_IDLE)

	# Calculate walk frame dimensions
	var walk_sheet_size := sprite_sheet_right.get_size()
	walk_frame_width = int(walk_sheet_size.x / WALK_FRAME_COUNT)
	walk_frame_height = int(walk_sheet_size.y)

	# Calculate idle frame dimensions
	var idle_sheet_size := sprite_sheet_idle.get_size()
	idle_frame_width = int(idle_sheet_size.x / IDLE_FRAME_COUNT)
	idle_frame_height = int(idle_sheet_size.y)

	# Create atlas texture for animation
	atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = sprite_sheet_idle
	atlas_texture.region = Rect2(0, 0, idle_frame_width, idle_frame_height)
	sprite.texture = atlas_texture
	is_idle = true

	# Don't block mouse clicks
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Start at center of screen
	var viewport_size := get_viewport().get_visible_rect().size
	position = Vector2(viewport_size.x / 2 - sprite_size / 2, viewport_size.y / 2 - sprite_size / 2)
	target_position = position


var look_at_when_arrived: Vector2 = Vector2.ZERO
var has_look_target := false


func move_to(target: Vector2) -> void:
	# Adjust target to center the sprite on the click position
	target_position = target - Vector2(sprite_size / 2, sprite_size / 2)
	is_moving = true
	has_look_target = false

	# Update direction based on target
	if target_position.x > position.x:
		set_direction(1)
	else:
		set_direction(-1)


func move_to_and_look_at(target: Vector2, look_at: Vector2) -> void:
	move_to(target)
	look_at_when_arrived = look_at
	has_look_target = true


func set_direction(dir: int) -> void:
	current_direction = dir
	if not is_idle:
		if dir == 1:
			atlas_texture.atlas = sprite_sheet_right
		else:
			atlas_texture.atlas = sprite_sheet_left
	_update_frame()


func _switch_to_idle() -> void:
	is_idle = true
	current_frame = 0
	atlas_texture.atlas = sprite_sheet_idle
	# Flip sprite based on direction
	sprite.flip_h = (current_direction == -1)
	_update_frame()


func _switch_to_walking() -> void:
	is_idle = false
	current_frame = 0
	sprite.flip_h = false
	if current_direction == 1:
		atlas_texture.atlas = sprite_sheet_right
	else:
		atlas_texture.atlas = sprite_sheet_left
	_update_frame()


func _update_frame() -> void:
	if atlas_texture == null:
		return

	if is_idle:
		atlas_texture.region = Rect2(current_frame * idle_frame_width, 0, idle_frame_width, idle_frame_height)
	else:
		atlas_texture.region = Rect2(current_frame * walk_frame_width, 0, walk_frame_width, walk_frame_height)
	sprite.texture = atlas_texture


func _process(delta: float) -> void:
	# Update z_index based on Y position for depth sorting
	z_index = int(position.y + sprite_size)

	if is_moving:
		# Switch to walking animation if needed
		if is_idle:
			_switch_to_walking()

		# Animate while moving
		animation_timer += delta
		if animation_timer >= 1.0 / ANIMATION_FPS:
			animation_timer = 0.0
			current_frame = (current_frame + 1) % WALK_FRAME_COUNT
			_update_frame()

		# Move towards target
		var direction := (target_position - position).normalized()
		var distance := position.distance_to(target_position)

		if distance < 5.0:
			# Arrived at target
			is_moving = false

			# Look at target if specified
			if has_look_target:
				var my_center := position + Vector2(sprite_size / 2, sprite_size / 2)
				if look_at_when_arrived.x > my_center.x:
					current_direction = 1
				else:
					current_direction = -1
				has_look_target = false

			# Switch to idle animation
			_switch_to_idle()
		else:
			position += direction * move_speed * delta

			# Keep within bounds
			var viewport_size := get_viewport().get_visible_rect().size
			position.x = clamp(position.x, 0, viewport_size.x - sprite_size)
			position.y = clamp(position.y, 120, viewport_size.y - sprite_size)
	else:
		# Idle animation
		animation_timer += delta
		if animation_timer >= 1.0 / IDLE_ANIMATION_FPS:
			animation_timer = 0.0
			current_frame = (current_frame + 1) % IDLE_FRAME_COUNT
			_update_frame()
