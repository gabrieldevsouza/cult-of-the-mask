extends Node
class_name AudioManagerClass

## AudioManager - Sistema de Audio para Cult of the Mask
##
## Gerencia BGM (Background Music), SFX (Sound Effects) e sons ambientes.
## Implementa transicoes suaves entre musicas e controle de volume por categoria.

# Sinais
signal bgm_changed(track_name: String)
signal sfx_played(sfx_name: String)

# Configuracoes de volume (0.0 a 1.0)
var master_volume := 1.0
var bgm_volume := 0.7
var sfx_volume := 0.8
var ambient_volume := 0.5

# Estado atual
var current_bgm: String = ""
var current_phase: int = 0
var is_muted := false

# Nodes de audio (criados dinamicamente)
var bgm_player: AudioStreamPlayer
var bgm_player_crossfade: AudioStreamPlayer  # Para crossfade entre musicas
var sfx_players: Array[AudioStreamPlayer] = []
var ambient_player: AudioStreamPlayer

# Pool de SFX players para evitar cortes
const SFX_POOL_SIZE := 8

# Duracao padrao de crossfade em segundos
const CROSSFADE_DURATION := 1.5

# Paths dos arquivos de audio
const AUDIO_PATH := "res://audio/"
const BGM_PATH := AUDIO_PATH + "bgm/"
const SFX_PATH := AUDIO_PATH + "sfx/"
const AMBIENT_PATH := AUDIO_PATH + "ambient/"

# Mapeamento de BGMs por contexto
enum BGMType {
	NONE,
	MENU,
	INTRO,
	PHASE_EARLY,      # Fases 2-3 (Euforia/Poder)
	PHASE_MID,        # Fase 4 (Transicao)
	PHASE_LATE,       # Fases 5-6 (Deterioracao/Isolamento)
	SINNER_DIALOGUE,  # Dialogo com mascarado
	VICTORY,
	GAMEOVER
}

# Mapeamento de arquivos BGM
# Arquivos estao diretamente em res://audio/
var bgm_files := {
	BGMType.MENU: "TELA DE INICIO.ogg",
	BGMType.INTRO: "IGREJA - FASE 1.ogg",
	BGMType.PHASE_EARLY: "MUSICA FASES.mp3",
	BGMType.PHASE_MID: "MUSICA FASES.mp3",
	BGMType.PHASE_LATE: "MUSICA FASES.mp3",
	BGMType.SINNER_DIALOGUE: "MUSICA FASES.mp3",
	BGMType.VICTORY: "FINAL.mp3",
	BGMType.GAMEOVER: "FINAL.mp3"
}

# Mapeamento de SFX
enum SFXType {
	# UI
	UI_CLICK,
	UI_HOVER,
	UI_BACK,

	# Gameplay
	NPC_SELECT,
	KILL_VISCERAL,
	KILL_INNOCENT,
	ITEM_COLLECT,
	ITEM_SPECIAL,

	# Feedback
	TIMER_TICK,
	TIMER_WARNING,
	HEARTBEAT,
	PHASE_COMPLETE,

	# Psicologicos (fases tardias)
	WHISPER,
	CRY_DISTANT,
	LAUGH_MUFFLED,
	FOOTSTEP_ECHO
}

var sfx_files := {
	SFXType.UI_CLICK: "ui_click.ogg",
	SFXType.UI_HOVER: "ui_hover.ogg",
	SFXType.UI_BACK: "ui_back.ogg",

	SFXType.NPC_SELECT: "npc_select.ogg",
	SFXType.KILL_VISCERAL: "kill_visceral.ogg",
	SFXType.KILL_INNOCENT: "kill_innocent.ogg",
	SFXType.ITEM_COLLECT: "item_collect.ogg",
	SFXType.ITEM_SPECIAL: "item_special.ogg",

	SFXType.TIMER_TICK: "timer_tick.ogg",
	SFXType.TIMER_WARNING: "timer_warning.ogg",
	SFXType.HEARTBEAT: "heartbeat.ogg",
	SFXType.PHASE_COMPLETE: "phase_complete.ogg",

	SFXType.WHISPER: "whisper.ogg",
	SFXType.CRY_DISTANT: "cry_distant.ogg",
	SFXType.LAUGH_MUFFLED: "laugh_muffled.ogg",
	SFXType.FOOTSTEP_ECHO: "footstep_echo.ogg"
}

# Cache de recursos carregados
var _bgm_cache := {}
var _sfx_cache := {}

# Timers para efeitos
var _heartbeat_timer: Timer
var _tick_timer: Timer
var _whisper_timer: Timer


func _ready() -> void:
	_setup_audio_players()
	_setup_timers()
	_preload_common_sfx()


func _setup_audio_players() -> void:
	# BGM principal
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = "Music"
	add_child(bgm_player)

	# BGM para crossfade
	bgm_player_crossfade = AudioStreamPlayer.new()
	bgm_player_crossfade.name = "BGMPlayerCrossfade"
	bgm_player_crossfade.bus = "Music"
	add_child(bgm_player_crossfade)

	# Pool de SFX players
	for i in SFX_POOL_SIZE:
		var sfx_player := AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer_%d" % i
		sfx_player.bus = "SFX"
		add_child(sfx_player)
		sfx_players.append(sfx_player)

	# Ambient player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Ambient"
	add_child(ambient_player)


func _setup_timers() -> void:
	# Timer para heartbeat (quando timer baixo)
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.name = "HeartbeatTimer"
	_heartbeat_timer.wait_time = 0.8
	_heartbeat_timer.timeout.connect(_on_heartbeat_tick)
	add_child(_heartbeat_timer)

	# Timer para tick do relogio
	_tick_timer = Timer.new()
	_tick_timer.name = "TickTimer"
	_tick_timer.wait_time = 1.0
	_tick_timer.timeout.connect(_on_timer_tick)
	add_child(_tick_timer)

	# Timer para sussurros aleatorios (fases tardias)
	_whisper_timer = Timer.new()
	_whisper_timer.name = "WhisperTimer"
	_whisper_timer.wait_time = 8.0
	_whisper_timer.timeout.connect(_on_whisper_tick)
	add_child(_whisper_timer)


func _preload_common_sfx() -> void:
	# Pre-carrega SFX mais usados
	var common_sfx := [
		SFXType.UI_CLICK,
		SFXType.NPC_SELECT,
		SFXType.KILL_VISCERAL,
		SFXType.HEARTBEAT
	]
	for sfx_type in common_sfx:
		_load_sfx(sfx_type)


# === CONTROLE DE BGM ===

func play_bgm(bgm_type: BGMType, crossfade := true) -> void:
	if is_muted:
		return

	var file_name: String = bgm_files.get(bgm_type, "")
	if file_name.is_empty():
		stop_bgm(crossfade)
		return

	# BGM files are directly in AUDIO_PATH (not in bgm subfolder)
	var full_path := AUDIO_PATH + file_name

	# Verifica se o arquivo existe
	if not ResourceLoader.exists(full_path):
		push_warning("AudioManager: BGM nao encontrado: " + full_path)
		return

	# Nao reinicia se ja esta tocando a mesma musica
	if current_bgm == file_name and bgm_player.playing:
		return

	var stream := _load_bgm(full_path)
	if stream == null:
		return

	current_bgm = file_name

	if crossfade and bgm_player.playing:
		_crossfade_to(stream)
	else:
		bgm_player.stream = stream
		bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)
		bgm_player.play()

	bgm_changed.emit(file_name)


func stop_bgm(fade_out := true) -> void:
	if not bgm_player.playing:
		return

	current_bgm = ""

	if fade_out:
		var tween := create_tween()
		tween.tween_property(bgm_player, "volume_db", -80.0, CROSSFADE_DURATION)
		tween.tween_callback(bgm_player.stop)
	else:
		bgm_player.stop()


func _crossfade_to(new_stream: AudioStream) -> void:
	# Move a musica atual para o player de crossfade
	bgm_player_crossfade.stream = bgm_player.stream
	bgm_player_crossfade.volume_db = bgm_player.volume_db
	bgm_player_crossfade.play(bgm_player.get_playback_position())

	# Inicia a nova musica no player principal
	bgm_player.stream = new_stream
	bgm_player.volume_db = -80.0
	bgm_player.play()

	# Tween de crossfade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(bgm_player, "volume_db", linear_to_db(bgm_volume * master_volume), CROSSFADE_DURATION)
	tween.tween_property(bgm_player_crossfade, "volume_db", -80.0, CROSSFADE_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(bgm_player_crossfade.stop)


func _load_bgm(path: String) -> AudioStream:
	if _bgm_cache.has(path):
		return _bgm_cache[path]

	var stream := load(path) as AudioStream
	if stream:
		_bgm_cache[path] = stream
	return stream


# === CONTROLE DE SFX ===

func play_sfx(sfx_type: SFXType, volume_modifier := 1.0) -> void:
	if is_muted:
		return

	var file_name: String = sfx_files.get(sfx_type, "")
	if file_name.is_empty():
		return

	var full_path := SFX_PATH + file_name

	if not ResourceLoader.exists(full_path):
		# Tenta usar foom_0.wav como fallback para kill
		if sfx_type == SFXType.KILL_VISCERAL:
			full_path = "res://sounds/foom_0.wav"
			if not ResourceLoader.exists(full_path):
				push_warning("AudioManager: SFX nao encontrado: " + SFX_PATH + file_name)
				return
		else:
			push_warning("AudioManager: SFX nao encontrado: " + full_path)
			return

	var stream := _load_sfx_from_path(full_path)
	if stream == null:
		return

	var player := _get_available_sfx_player()
	if player == null:
		return

	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume * master_volume * volume_modifier)
	player.play()

	sfx_played.emit(file_name)


func _load_sfx(sfx_type: SFXType) -> AudioStream:
	var file_name: String = sfx_files.get(sfx_type, "")
	if file_name.is_empty():
		return null

	var full_path := SFX_PATH + file_name
	return _load_sfx_from_path(full_path)


func _load_sfx_from_path(path: String) -> AudioStream:
	if _sfx_cache.has(path):
		return _sfx_cache[path]

	if not ResourceLoader.exists(path):
		return null

	var stream := load(path) as AudioStream
	if stream:
		_sfx_cache[path] = stream
	return stream


func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player
	# Se todos estao ocupados, usa o primeiro (interrompe)
	return sfx_players[0]


# === CONTROLE DE AMBIENT ===

func play_ambient(file_name: String) -> void:
	if is_muted:
		return

	var full_path := AMBIENT_PATH + file_name

	if not ResourceLoader.exists(full_path):
		push_warning("AudioManager: Ambient nao encontrado: " + full_path)
		return

	var stream := load(full_path) as AudioStream
	if stream == null:
		return

	ambient_player.stream = stream
	ambient_player.volume_db = linear_to_db(ambient_volume * master_volume)
	ambient_player.play()


func stop_ambient(fade_out := true) -> void:
	if not ambient_player.playing:
		return

	if fade_out:
		var tween := create_tween()
		tween.tween_property(ambient_player, "volume_db", -80.0, 1.0)
		tween.tween_callback(ambient_player.stop)
	else:
		ambient_player.stop()


# === FUNCOES DE CONVENIENCIA POR CONTEXTO ===

func play_menu_music() -> void:
	play_bgm(BGMType.MENU)


func play_intro_music() -> void:
	play_bgm(BGMType.INTRO)


func play_phase_music(phase: int) -> void:
	current_phase = phase

	match phase:
		2, 3:
			play_bgm(BGMType.PHASE_EARLY)
		4:
			play_bgm(BGMType.PHASE_MID)
		5, 6:
			play_bgm(BGMType.PHASE_LATE)
			# Inicia sussurros aleatorios nas fases tardias
			_whisper_timer.start()
		_:
			stop_bgm()
			_whisper_timer.stop()


func play_sinner_music() -> void:
	play_bgm(BGMType.SINNER_DIALOGUE)


func play_victory_music() -> void:
	_whisper_timer.stop()
	play_bgm(BGMType.VICTORY)


func play_gameover_music() -> void:
	_whisper_timer.stop()
	play_bgm(BGMType.GAMEOVER)


# === SFX DE CONVENIENCIA ===

func play_ui_click() -> void:
	play_sfx(SFXType.UI_CLICK)


func play_ui_hover() -> void:
	play_sfx(SFXType.UI_HOVER, 0.5)


func play_npc_select() -> void:
	play_sfx(SFXType.NPC_SELECT)


func play_kill_sound(is_innocent := false) -> void:
	if is_innocent:
		play_sfx(SFXType.KILL_INNOCENT)
	else:
		play_sfx(SFXType.KILL_VISCERAL)


func play_item_collect(is_special := false) -> void:
	if is_special:
		play_sfx(SFXType.ITEM_SPECIAL)
	else:
		play_sfx(SFXType.ITEM_COLLECT)


func play_phase_complete() -> void:
	play_sfx(SFXType.PHASE_COMPLETE)


# === EFEITOS DE PRESSAO/TENSAO ===

func start_heartbeat() -> void:
	if not _heartbeat_timer.is_stopped():
		return
	_heartbeat_timer.start()


func stop_heartbeat() -> void:
	_heartbeat_timer.stop()


func start_timer_ticks() -> void:
	if not _tick_timer.is_stopped():
		return
	_tick_timer.start()


func stop_timer_ticks() -> void:
	_tick_timer.stop()


func _on_heartbeat_tick() -> void:
	play_sfx(SFXType.HEARTBEAT, 0.7)


func _on_timer_tick() -> void:
	play_sfx(SFXType.TIMER_TICK, 0.4)


func _on_whisper_tick() -> void:
	# Chance aleatoria de tocar efeito psicologico
	var rand := randf()
	if rand < 0.4:
		play_sfx(SFXType.WHISPER, 0.3)
	elif rand < 0.6:
		play_sfx(SFXType.CRY_DISTANT, 0.25)
	elif rand < 0.75:
		play_sfx(SFXType.LAUGH_MUFFLED, 0.2)

	# Varia o tempo ate o proximo
	_whisper_timer.wait_time = randf_range(5.0, 15.0)


# === EFEITO DE SILENCIO ESTRATEGICO ===

func fade_to_silence(duration := 2.0) -> void:
	## Fade gradual para silencio total - usado em momentos de tensao maxima
	var tween := create_tween()
	tween.set_parallel(true)

	if bgm_player.playing:
		tween.tween_property(bgm_player, "volume_db", -80.0, duration)
	if ambient_player.playing:
		tween.tween_property(ambient_player, "volume_db", -80.0, duration)


func restore_from_silence(duration := 1.0) -> void:
	## Restaura volumes apos silencio
	var tween := create_tween()
	tween.set_parallel(true)

	if bgm_player.stream != null:
		tween.tween_property(bgm_player, "volume_db", linear_to_db(bgm_volume * master_volume), duration)
	if ambient_player.stream != null:
		tween.tween_property(ambient_player, "volume_db", linear_to_db(ambient_volume * master_volume), duration)


# === CONTROLE DE VOLUME ===

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_update_all_volumes()


func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	if bgm_player.playing:
		bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)


func set_ambient_volume(value: float) -> void:
	ambient_volume = clampf(value, 0.0, 1.0)
	if ambient_player.playing:
		ambient_player.volume_db = linear_to_db(ambient_volume * master_volume)


func toggle_mute() -> void:
	is_muted = not is_muted
	if is_muted:
		bgm_player.volume_db = -80.0
		ambient_player.volume_db = -80.0
	else:
		_update_all_volumes()


func _update_all_volumes() -> void:
	if bgm_player.playing:
		bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)
	if ambient_player.playing:
		ambient_player.volume_db = linear_to_db(ambient_volume * master_volume)
