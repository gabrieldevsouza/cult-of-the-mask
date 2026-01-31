extends Control
class_name CrowdNPC

signal selected(npc: CrowdNPC)
signal escaped(npc: CrowdNPC)

const WALK_SHEET = preload("res://sprites/cultist_left_walk.png")
const SINNER_SHEET = preload("res://sprites/sinner_walk_left.png")
const SPARKLES_SHEET = preload("res://sprites/sparkles.png")
const WALK_ANIM := &"walk"
const SPARKLES_ANIM := &"sparkles"
const FRAME_SIZE := Vector2i(64, 64)
const CULTIST_ANIM_FPS := 10.0
const SINNER_ANIM_FPS := 12.0
const SPARKLES_ANIM_FPS := 6.0
const SPARKLES_FRAMES := 5
const SPARKLES_PULSE_SCALE := 1.2
const SPARKLES_ALPHA_MIN := 0.10
const SPARKLES_ALPHA_MAX := 0.40

static var _shared_frames_cultist: SpriteFrames
static var _shared_frames_sinner: SpriteFrames
static var _shared_frames_sparkles: SpriteFrames

@export var is_sinner: bool = false
@export var debug_show_sinner: bool = false
@export var debug_tint_sinner: bool = false

var velocity: Vector2 = Vector2.ZERO
var ui_top_margin := 120.0
var square_size := 50.0
var base_tint := Color.WHITE

var sprite: AnimatedSprite2D
var sparkles: AnimatedSprite2D
var sparkles_base_scale := Vector2.ONE
var sparkles_pulse_tween: Tween
var facing_right := false

# Escape behavior (timed)
var escaping := false
var escape_dir: Vector2 = Vector2.ZERO
var escape_speed: float = 0.0
var escape_margin: float = 40.0 # how far outside counts as "escaped"
var allow_bounce := true

# Efeito monóculo
var monoculo_active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_sprite()
	_apply_sprite_layout()


func setup(_is_sinner: bool, _debug_show_sinner: bool, _debug_tint_sinner: bool, _velocity: Vector2, _square_size: float, _ui_top_margin: float) -> void:
	is_sinner = _is_sinner
	debug_show_sinner = _debug_show_sinner
	debug_tint_sinner = _debug_tint_sinner
	velocity = _velocity
	square_size = _square_size
	ui_top_margin = _ui_top_margin

	if debug_show_sinner and debug_tint_sinner and is_sinner:
		base_tint = Color(1.2, 0.3, 0.3, 1.0)
	else:
		base_tint = Color.WHITE

	set_tint(base_tint)
	_apply_sprite_layout()


func set_speed_magnitude(new_speed: float) -> void:
	if velocity.length() < 0.001:
		velocity = Vector2.RIGHT * new_speed
	else:
		velocity = velocity.normalized() * new_speed


func set_tint(tint: Color) -> void:
	modulate = tint


func _ensure_sprite() -> void:
	if sprite and is_instance_valid(sprite):
		return

	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = _get_shared_frames(is_sinner)
	sprite.animation = WALK_ANIM
	sprite.centered = true
	add_child(sprite)

	var frame_count := sprite.sprite_frames.get_frame_count(WALK_ANIM)
	if frame_count > 0:
		sprite.frame = randi() % frame_count
	sprite.play()


func _apply_sprite_layout() -> void:
	if not sprite:
		return

	size = Vector2(square_size, square_size)
	var scale_factor := square_size / float(FRAME_SIZE.x)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.position = Vector2(square_size * 0.5, square_size * 0.5)

	if sparkles and is_instance_valid(sparkles):
		var sparkles_frame_size = _get_sparkles_frame_size()
		var sparkle_scale := square_size / float(sparkles_frame_size.y)
		sparkles_base_scale = Vector2(sparkle_scale, sparkle_scale)
		sparkles.scale = sparkles_base_scale
		sparkles.position = sprite.position
		sparkles.flip_h = sprite.flip_h


static func _get_shared_frames(for_sinner: bool) -> SpriteFrames:
	if for_sinner:
		if _shared_frames_sinner:
			return _shared_frames_sinner
		_shared_frames_sinner = _build_frames(SINNER_SHEET, SINNER_ANIM_FPS)
		return _shared_frames_sinner

	if _shared_frames_cultist:
		return _shared_frames_cultist

	_shared_frames_cultist = _build_frames(WALK_SHEET, CULTIST_ANIM_FPS)
	return _shared_frames_cultist


static func _get_shared_sparkles_frames() -> SpriteFrames:
	if _shared_frames_sparkles:
		return _shared_frames_sparkles

	var frames := SpriteFrames.new()
	frames.add_animation(SPARKLES_ANIM)
	frames.set_animation_speed(SPARKLES_ANIM, SPARKLES_ANIM_FPS)
	frames.set_animation_loop(SPARKLES_ANIM, true)

	var texture_size := SPARKLES_SHEET.get_size()
	var frame_width := texture_size.x / SPARKLES_FRAMES
	var frame_height := texture_size.y
	for i in range(SPARKLES_FRAMES):
		var atlas := AtlasTexture.new()
		atlas.atlas = SPARKLES_SHEET
		atlas.region = Rect2(Vector2(i * frame_width, 0), Vector2(frame_width, frame_height))
		frames.add_frame(SPARKLES_ANIM, atlas)

	_shared_frames_sparkles = frames
	return _shared_frames_sparkles


static func _get_sparkles_frame_size() -> Vector2:
	var texture_size := SPARKLES_SHEET.get_size()
	return Vector2(texture_size.x / SPARKLES_FRAMES, texture_size.y)


static func _build_frames(sheet: Texture2D, fps: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(WALK_ANIM)
	frames.set_animation_speed(WALK_ANIM, fps)
	frames.set_animation_loop(WALK_ANIM, true)

	var texture_size := sheet.get_size()
	var columns := int(texture_size.x / FRAME_SIZE.x)
	for i in range(columns):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(Vector2(i * FRAME_SIZE.x, 0), Vector2(FRAME_SIZE.x, FRAME_SIZE.y))
		frames.add_frame(WALK_ANIM, atlas)

	return frames


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


func _process(delta: float) -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	var viewport_size := viewport_rect.size

	if escaping:
		# No bounce. Leave city.
		position += escape_dir * escape_speed * delta
		_update_facing(escape_dir.x)

		# Escaped check
		if position.x + square_size < -escape_margin \
		or position.x > viewport_size.x + escape_margin \
		or position.y + square_size < -escape_margin \
		or position.y > viewport_size.y + escape_margin:
			escaped.emit(self)

		return

	# Normal movement
	position += velocity * delta
	_update_facing(velocity.x)

	if allow_bounce:
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


func _update_facing(dx: float) -> void:
	if not sprite:
		return
	if abs(dx) < 1.0:
		return
	facing_right = dx > 0.0
	sprite.flip_h = facing_right
	if sparkles and is_instance_valid(sparkles):
		sparkles.flip_h = facing_right


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(self)


func apply_monoculo_effect() -> void:
	if not is_sinner or monoculo_active:
		return
	monoculo_active = true
	_ensure_sparkles()
	sparkles.visible = true
	sparkles.play()
	_start_sparkles_pulse()


func _ensure_sparkles() -> void:
	if sparkles and is_instance_valid(sparkles):
		return

	_ensure_sprite()
	sparkles = AnimatedSprite2D.new()
	sparkles.name = "Sparkles"
	sparkles.sprite_frames = _get_shared_sparkles_frames()
	sparkles.animation = SPARKLES_ANIM
	sparkles.centered = true
	sparkles.z_index = sprite.z_index + 1
	sparkles.visible = false
	sparkles.modulate.a = SPARKLES_ALPHA_MAX
	add_child(sparkles)
	_apply_sprite_layout()


func _start_sparkles_pulse() -> void:
	if sparkles_pulse_tween and is_instance_valid(sparkles_pulse_tween):
		sparkles_pulse_tween.kill()

	sparkles_pulse_tween = create_tween()
	sparkles_pulse_tween.set_loops()

	sparkles_pulse_tween.tween_property(sparkles, "scale", sparkles_base_scale * SPARKLES_PULSE_SCALE, 0.4).set_ease(Tween.EASE_IN_OUT)
	sparkles_pulse_tween.parallel().tween_property(sparkles, "modulate:a", SPARKLES_ALPHA_MAX, 0.4).set_ease(Tween.EASE_IN_OUT)
	sparkles_pulse_tween.tween_property(sparkles, "scale", sparkles_base_scale, 0.4).set_ease(Tween.EASE_IN_OUT)
	sparkles_pulse_tween.parallel().tween_property(sparkles, "modulate:a", SPARKLES_ALPHA_MIN, 0.4).set_ease(Tween.EASE_IN_OUT)


func stop_monoculo_effect() -> void:
	monoculo_active = false
	if sparkles_pulse_tween and is_instance_valid(sparkles_pulse_tween):
		sparkles_pulse_tween.kill()
	if sparkles and is_instance_valid(sparkles):
		sparkles.stop()
		sparkles.visible = false
		sparkles.scale = sparkles_base_scale
