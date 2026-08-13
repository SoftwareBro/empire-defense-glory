class_name WaveManager
extends Node

## Owns the wave lifecycle: countdown -> spawn -> wait for the map to clear ->
## next wave -> victory. Level supplies the spawn callback, so this node never
## touches enemy scenes or the Path2D itself.

enum State { IDLE, COUNTDOWN, SPAWNING, CLEARING, FINISHED }

## Gold awarded per whole second skipped when calling a wave early.
const EARLY_CALL_GOLD_PER_SECOND: int = 2
## Fallback countdown when a WaveData leaves delay_before at 0.
const DEFAULT_DELAY: float = 5.0

var state: State = State.IDLE

var _waves: Array = []
var _spawn_enemy: Callable
var _wave_index: int = 0
var _countdown: float = 0.0
var _entries_running: int = 0
var _enemies_alive: int = 0


## Single source of truth for the bonus, so the HUD can never promise an amount
## that differs from what the player is actually paid.
static func early_call_bonus_for(seconds_left: float) -> int:
	return maxi(0, ceili(seconds_left)) * EARLY_CALL_GOLD_PER_SECOND


func setup(waves: Array, spawn_enemy: Callable) -> void:
	_waves = waves
	_spawn_enemy = spawn_enemy
	_wave_index = 0
	_enemies_alive = 0
	_entries_running = 0

	Events.enemy_spawned.connect(_on_enemy_spawned)
	Events.enemy_died.connect(_on_enemy_removed)
	Events.enemy_leaked.connect(_on_enemy_removed)
	Events.level_lost.connect(_on_level_lost)


func start() -> void:
	if _waves.is_empty():
		state = State.FINISHED
		push_warning("WaveManager started with no waves.")
		return
	_begin_countdown()


## True while the player can still skip a countdown for bonus gold.
func can_call_early() -> bool:
	return state == State.COUNTDOWN


func call_wave_early() -> void:
	if state != State.COUNTDOWN:
		return

	var bonus: int = early_call_bonus_for(_countdown)
	if bonus > 0:
		GameState.add_gold(bonus)
		Events.early_call_bonus.emit(bonus)

	_countdown = 0.0
	_start_wave()


func _process(delta: float) -> void:
	if state != State.COUNTDOWN:
		return

	_countdown -= delta
	Events.wave_countdown_changed.emit(maxf(_countdown, 0.0))

	if _countdown <= 0.0:
		_start_wave()


func _begin_countdown() -> void:
	var wave: WaveData = _waves[_wave_index]
	_countdown = wave.delay_before if wave.delay_before > 0.0 else DEFAULT_DELAY
	state = State.COUNTDOWN
	Events.wave_countdown_changed.emit(_countdown)


func _start_wave() -> void:
	state = State.SPAWNING
	Events.wave_countdown_changed.emit(0.0)

	var wave: WaveData = _waves[_wave_index]
	_wave_index += 1
	GameState.current_wave = _wave_index
	Events.wave_changed.emit(_wave_index, _waves.size())

	_entries_running = wave.entries.size()
	if _entries_running == 0:
		_entries_running = 1
		_on_entry_finished()
		return

	# Each entry is its own coroutine, so groups inside one wave overlap.
	for entry in wave.entries:
		_run_entry(entry)


func _run_entry(entry: WaveEntry) -> void:
	if entry == null or entry.enemy == null:
		_on_entry_finished()
		return

	if entry.start_delay > 0.0:
		await get_tree().create_timer(entry.start_delay).timeout

	for i in entry.count:
		if not is_inside_tree() or GameState.is_game_over:
			return
		_spawn_enemy.call(entry.enemy)
		if i < entry.count - 1:
			await get_tree().create_timer(entry.interval).timeout

	_on_entry_finished()


func _on_entry_finished() -> void:
	_entries_running -= 1
	if _entries_running > 0 or state != State.SPAWNING:
		return

	# Everything for this wave is on the field. Now wait for it to be cleared.
	state = State.CLEARING
	_check_progress()


func _on_enemy_spawned(_enemy: Node2D) -> void:
	_enemies_alive += 1


func _on_enemy_removed(_enemy: Node2D, _value: int) -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	_check_progress()


func _check_progress() -> void:
	if state != State.CLEARING or _enemies_alive > 0 or GameState.is_game_over:
		return

	if _wave_index >= _waves.size():
		state = State.FINISHED
		GameState.win_level()
	else:
		_begin_countdown()


func _on_level_lost() -> void:
	state = State.FINISHED
