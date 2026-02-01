extends Control
class_name CollectibleItem

signal collected(item_name: String)

@export var item_name: String = ""

const ITEM_COLORS := {
	"monoculo": Color(0.2, 0.4, 0.9),    # Azul
	"relogio": Color(0.9, 0.7, 0.2),      # Dourado
	"calice": Color(0.7, 0.1, 0.1),       # Vermelho sangue
	"lagrima": Color(0.8, 0.9, 1.0),      # Branco azulado
	"rosario": Color(0.3, 0.3, 0.3),      # Cinza escuro
}

const ITEM_LABELS := {
	"monoculo": "M",
	"relogio": "R",
	"calice": "♰",
	"lagrima": "💧",
	"rosario": "✝",
}

const ITEM_TEXTURES := {
	"monoculo": preload("res://images/monoculo.png"),
	"relogio": preload("res://images/relogio_de_bolso_2.png"),
	"rosario": preload("res://images/cruz_de_malta_fds.png"),
	"lagrima": preload("res://images/frasco_de_lagrima.png"),
	"calice": preload("res://images/calice.png"),
}

var color_rect: ColorRect
var item_label: Label
var texture_rect: TextureRect
var pulse_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(40, 40)
	size = Vector2(40, 40)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_create_visuals()
	_start_pulse_animation()

	# Update z_index based on Y position for depth sorting
	z_index = int(position.y + 40)


func _create_visuals() -> void:
	# Use texture if available, otherwise fall back to colored rect with label
	if ITEM_TEXTURES.has(item_name):
		texture_rect = TextureRect.new()
		texture_rect.texture = ITEM_TEXTURES[item_name]
		texture_rect.size = Vector2(40, 40)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(texture_rect)
	else:
		color_rect = ColorRect.new()
		color_rect.size = Vector2(40, 40)
		color_rect.color = ITEM_COLORS.get(item_name, Color.WHITE)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(color_rect)

		item_label = Label.new()
		item_label.text = ITEM_LABELS.get(item_name, "?")
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_label.size = Vector2(40, 40)
		item_label.add_theme_font_size_override("font_size", 20)
		item_label.add_theme_color_override("font_color", Color.WHITE)
		item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(item_label)


func _start_pulse_animation() -> void:
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(self, "modulate:a", 0.6, 0.5)
	pulse_tween.tween_property(self, "modulate:a", 1.0, 0.5)


func setup(p_item_name: String) -> void:
	item_name = p_item_name
	# Update texture if available
	if texture_rect and ITEM_TEXTURES.has(item_name):
		texture_rect.texture = ITEM_TEXTURES[item_name]
	elif color_rect:
		color_rect.color = ITEM_COLORS.get(item_name, Color.WHITE)
	if item_label:
		item_label.text = ITEM_LABELS.get(item_name, "?")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_clicked()


func _on_clicked() -> void:
	if pulse_tween:
		pulse_tween.kill()
	collected.emit(item_name)
	queue_free()
