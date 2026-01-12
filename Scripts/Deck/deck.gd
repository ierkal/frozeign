extends Node
class_name Deck


signal flag_added_signal(flag_name)
signal pool_unlocked(pool_name)

var _raw_cards: Array = []         # all cards loaded from JSON
var _deck: Array = []              # working deck (shuffled)
var _flags: Dictionary = {}        # active flag set { "flag": true }
var _card_states: Dictionary = {}  # per-card states { id: { "locked": bool } }
var _sequence_queue: Array = []    # forced next cards (Immediate sequences)
var current_chief_index: int = 0   # controlled by GameManager

# NEW: Tracks which pools are currently unlocked
var _unlocked_pools: Dictionary = {}

var _use_starter_phase: bool = false  # draw starter cards first

# Interview system integration
var _interview_manager = null

# NPC system integration
var _npc_generator: NpcGenerator = null
var _npc_image_composer: NpcImageComposer = null


func _ready() -> void:
	randomize()
	_reset_unlocked_pools()

# ---------------------------------------------------
# Public control interface
# ---------------------------------------------------

func begin_starter_phase() -> void:
	_use_starter_phase = true

func set_current_chief_index(idx: int) -> void:
	current_chief_index = idx

func set_interview_manager(manager) -> void:
	_interview_manager = manager


func set_npc_systems(generator: NpcGenerator, composer: NpcImageComposer) -> void:
	_npc_generator = generator
	_npc_image_composer = composer

func add_flag(flag_name: String) -> void:
	if flag_name == "":
		return
	
	# Eğer bu bayrak zaten varsa tekrar ekleme/sinyal gönderme (isteğe bağlı)
	if _flags.has(flag_name):
		return

	_flags[flag_name] = true
	
	# YENİ: Görev yöneticisine (veya dinleyen herkese) haber ver
	emit_signal("flag_added_signal", flag_name)

func has_flag(flag_name: String) -> bool:
	return _flags.get(flag_name, false)

# NEW: Pool Management
func unlock_pool(pool_name: String) -> void:
	if pool_name == "":
		return
	# Only emit signal if this is a new unlock
	if not _unlocked_pools.has(pool_name):
		_unlocked_pools[pool_name] = true
		pool_unlocked.emit(pool_name)

func is_pool_unlocked(pool_name: String) -> bool:
	return _unlocked_pools.has(pool_name)

func _reset_unlocked_pools() -> void:
	_unlocked_pools.clear()
	# Only Starter is unlocked by default
	_unlocked_pools["Starter"] = true
	
func soft_reset_deck() -> void:
	_deck.clear()
	_refill_deck()
# ---------------------------------------------------
# Loading
# ---------------------------------------------------

func load_from_json_string(json_text: String) -> void:
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Deck: JSON root must be an array")
		return
	_raw_cards = parsed.duplicate(true)
	_refill_deck()

@warning_ignore("redundant_await")
func load_from_file(path: String) -> void:
	await get_tree().process_frame
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Deck: cannot open %s" % path)
		return
	var text := f.get_as_text()
	load_from_json_string(text)


# ---------------------------------------------------
# Deck ops
# ---------------------------------------------------

func _refill_deck() -> void:
	_deck.clear()
	for card in _raw_cards:
		var id = card.get("Id", "")
		var is_death = id.begins_with("DEATH_")
		if not is_death:
			_deck.append(card)
	_deck.shuffle()

func reset_deck() -> void:
	_reset_unlocked_pools()
	_refill_deck()


# ---------------------------------------------------
# Draw logic
# ---------------------------------------------------

func draw() -> Dictionary:
	# 1) Sequence queue has priority
	if _sequence_queue.size() > 0:
		return _sequence_queue.pop_front()

	# 2) Starter phase → draw only Pool:"Starter"
	if _use_starter_phase:
		if _deck.is_empty():
			_refill_deck()

		var starter := _draw_from_starter_pool()
		if not starter.is_empty():
			return starter

		# No starter cards left → disable phase
		_use_starter_phase = false

	# 3) Normal deck draw with conditions
	if _deck.is_empty():
		_refill_deck()

	if _deck.is_empty():
		return {}

	var attempts := _deck.size()
	while attempts > 0 and not _deck.is_empty():
		attempts -= 1
		var card = _deck.pop_back()
		if _is_card_drawable(card):
			return card

	# Try once more after refill
	if _deck.is_empty():
		_refill_deck()

	attempts = _deck.size()
	while attempts > 0 and not _deck.is_empty():
		attempts -= 1
		var card2 = _deck.pop_back()
		if _is_card_drawable(card2):
			return card2

	return {}  # nothing found


func _draw_from_starter_pool() -> Dictionary:
	var i := _deck.size() - 1
	while i >= 0:
		var card = _deck[i]
		# Even in starter phase, we check if it's drawable (locked, etc.)
		if card.get("Pool", "") == "Starter" and _is_card_drawable(card):
			_deck.remove_at(i)
			return card
		i -= 1
	return {}  # no usable Starter cards left


# ---------------------------------------------------
# Availability filters
# ---------------------------------------------------

func _is_card_drawable(card: Dictionary) -> bool:
	var id: String = card.get("Id", "")
	var pool: String = card.get("Pool", "")

	# 1. Pool Lock Check (NEW)
	if not is_pool_unlocked(pool):
		return false

	# 2. Locked card (RepeatPolicy)? Skip.
	if _is_locked(id):
		return false

	# 3. RunMin / RunMax (chief-based progression)
	var run_min := int(card.get("RunMin", 0))
	var run_max := int(card.get("RunMax", 999))
	if current_chief_index < run_min or current_chief_index > run_max:
		return false

	# 4. RequireFlagsAll
	for f in card.get("RequireFlagsAll", []):
		if not has_flag(str(f)):
			return false

	# 5. RequireFlagsAny
	var any_list: Array = card.get("RequireFlagsAny", [])
	if any_list.size() > 0:
		var ok := false
		for f2 in any_list:
			if has_flag(str(f2)):
				ok = true
				break
		if not ok:
			return false

	# 6. BlockFlags
	for bf in card.get("BlockFlags", []):
		if has_flag(str(bf)):
			return false

	return true


# ---------------------------------------------------
# Lock system (RepeatPolicy)
# ---------------------------------------------------

func _is_locked(card_id: String) -> bool:
	if not _card_states.has(card_id):
		return false
	return _card_states[card_id].get("locked", false)

func _lock_card(card_id: String) -> void:
	var state = _card_states.get(card_id, {})
	state["locked"] = true
	_card_states[card_id] = state


# ---------------------------------------------------
# Sequence system (Immediate + SequenceAdvanceOn)
# ---------------------------------------------------

func _should_advance_sequence(card: Dictionary, chosen_side: String) -> bool:
	# chosen_side is JSON original side: "left" or "right"
	if card.get("SequenceMode", "Normal") != "Immediate":
		return false

	var advance_on: String = card.get("SequenceAdvanceOn", "Any")
	if advance_on == "Any":
		return true
	if advance_on == "Positive":
		return chosen_side == "left"
	if advance_on == "Negative":
		return chosen_side == "right"

	return true

func _queue_next_sequence_step(card: Dictionary) -> void:
	var sid: String = card.get("SequenceId", "")
	if sid == "":
		return

	var current_index := int(card.get("SequenceIndex", 0))
	var next_index := current_index + 1

	for c in _raw_cards:
		# Sequence ID ve Index eşleşiyor mu?
		if c.get("SequenceId", "") == sid and int(c.get("SequenceIndex", 0)) == next_index:
			
			# Kart çekilebilir durumda mı? (Flag'ler, kilitler vs.)
			# NOT: Bir önceki cevabımdaki 'ignore_pool_lock' parametresini eklediysen
			# burayı: if _is_card_drawable(c, true): yapmalısın.
			if _is_card_drawable(c):
				_sequence_queue.append(c)
				break # SADECE uygun kartı bulup eklediysek döngüyü bitir!
			
			# Eğer kart uygun değilse (örn: yanlış flag), döngü KIRILMAZ,
			# sıradaki diğer (alternatif) kartı aramaya devam eder.
# ---------------------------------------------------
# Presentation (given to CardUI)
# ---------------------------------------------------

func prepare_presented(card: Dictionary) -> Dictionary:
	# Extract NPC-related fields early
	var npc_pool = str(card.get("NpcPool", ""))
	var pool = str(card.get("Pool", ""))
	var candidate_index = int(card.get("InterviewCandidate", 0))
	var npc_name_field = str(card.get("NpcName", ""))

	# Variables for coordinated title/image handling
	var dynamic_title = ""
	var npc_image: Texture2D = null
	var resolved_npc_name = ""

	# 1. Specific NPC by name field
	if npc_name_field != "":
		resolved_npc_name = npc_name_field
		dynamic_title = npc_name_field
		if _npc_image_composer:
			npc_image = _npc_image_composer.get_or_compose_image(npc_name_field)

	# 2. Interview candidate cards
	elif candidate_index > 0 and _interview_manager:
		var candidate_name = _interview_manager.get_interview_candidate_name(candidate_index)
		if candidate_name != "":
			resolved_npc_name = candidate_name
			dynamic_title = candidate_name
			if _npc_image_composer:
				npc_image = _npc_image_composer.get_or_compose_image(candidate_name)

	# 3. Citizen pool - random regular NPCs (no profession prefix)
	elif npc_pool == "Citizen" and _npc_generator:
		var name_pool = _npc_generator.get_name_pool()
		if not name_pool.is_empty():
			var random_name = name_pool[randi() % name_pool.size()]
			resolved_npc_name = random_name
			dynamic_title = random_name
			if _npc_image_composer:
				npc_image = _npc_image_composer.get_or_compose_image(random_name)

	# 4. Profession NPC pool (Steward, Captain) - use assigned NPC with profession prefix
	elif npc_pool != "" and _npc_generator:
		var npc_data = _npc_generator.get_npc_for_profession(npc_pool)
		if not npc_data.is_empty():
			var npc_name = npc_data.get("name", "")
			resolved_npc_name = npc_name
			dynamic_title = "%s %s" % [npc_pool, npc_name]
			if _npc_image_composer:
				npc_image = _npc_image_composer.get_image_for_profession(npc_pool)

	# 5. Pool name matches a hired profession
	elif pool != "" and _npc_generator:
		var npc_data = _npc_generator.get_npc_for_profession(pool)
		if not npc_data.is_empty():
			var npc_name = npc_data.get("name", "")
			resolved_npc_name = npc_name
			dynamic_title = "%s %s" % [pool, npc_name]
			if _npc_image_composer:
				npc_image = _npc_image_composer.get_cached_image(npc_name)

	# Fallback to interview manager for interview-related cards or original title
	if dynamic_title == "" and _interview_manager:
		dynamic_title = _interview_manager.get_dynamic_title(card)
	if dynamic_title == "":
		dynamic_title = str(card.get("Title", ""))

	var present := {
		"id": card.get("Id", ""),
		"title": dynamic_title,
		"desc": card.get("Description", ""),
		"left": {},
		"right": {},
		"ui_left_original": "",
		"ui_right_original": "",
		"npc_image": npc_image
	}

	var left := {
		"text": card.get("LeftText", ""),
		"Hope": card.get("LeftHope", 0),
		"Discontent": card.get("LeftDiscontent", 0),
		"Order": card.get("LeftOrder", 0),
		"Faith": card.get("LeftFaith", 0)
	}
	var right := {
		"text": card.get("RightText", ""),
		"Hope": card.get("RightHope", 0),
		"Discontent": card.get("RightDiscontent", 0),
		"Order": card.get("RightOrder", 0),
		"Faith": card.get("RightFaith", 0)
	}

	var swap := randi() % 2 == 0
	if swap:
		# UI Left = JSON Right
		present.left = right
		present.right = left
		present["ui_left_original"] = "right"
		present["ui_right_original"] = "left"
	else:
		# UI Left = JSON Left
		present.left = left
		present.right = right
		present["ui_left_original"] = "left"
		present["ui_right_original"] = "right"

	return present


# ---------------------------------------------------
# Commit event: flags + sequence advance + RepeatPolicy
# ---------------------------------------------------

func on_card_committed(card_id: String, side: String) -> void:
	# side is JSON original side: "left" or "right"
	var card = find_card_by_id(card_id)
	if card.is_empty():
		return
	
	_mark_as_discovered(card_id)
	# 1) Add flags
	var flist: Array = []
	if side == "left":
		flist = card.get("OnLeftAddFlags", [])
	else:
		flist = card.get("OnRightAddFlags", [])

	for f in flist:
		add_flag(str(f))
		
	# 2) Unlock Pools (NEW)
	var unlock_list: Array = []
	if side == "left":
		unlock_list = card.get("OnLeftUnlockPools", [])
	else:
		unlock_list = card.get("OnRightUnlockPools", [])
		
	for p in unlock_list:
		unlock_pool(str(p))

	# 3) Immediate sequence advance (choice-dependent)
	if _should_advance_sequence(card, side):
		_queue_next_sequence_step(card)

	# 4) RepeatPolicy
	var policy: String = card.get("RepeatPolicy", "never")

	if policy == "never":
		_lock_card(card_id)

	elif policy == "repeat_on_negative":
		# Default: JSON left = positive, JSON right = negative
		if side == "left":
			_lock_card(card_id)
		else:
			pass  # right side → card stays in deck

	# policy == "always" → do nothing


func find_card_by_id(id: String) -> Dictionary:
	for card in _raw_cards:
		if card.get("Id", "") == id:
			return card
	return {}
	
# Helper to mark a card as discovered in the state dictionary
func _mark_as_discovered(card_id: String) -> void:
	var state = _card_states.get(card_id, {})
	
	# Avoid re-writing if already discovered
	if state.get("discovered", false):
		return
		
	state["discovered"] = true
	_card_states[card_id] = state

# Public API: Get the number of cards the player has encountered
func get_discovered_count() -> int:
	var count = 0
	for id in _card_states.keys():
		var state = _card_states[id]
		if state.get("discovered", false) == true:
			count += 1
	return count

# Public API: Get total valid cards (excluding Death/System cards)
func get_unique_cards_count() -> int:
	var count = 0
	for card in _raw_cards:
		var id = str(card.get("Id", ""))
		# Only count actual story cards, ignore system cards
		if not id.begins_with("DEATH_"):
			count += 1
	return count
	
# Belirli bir ID'ye sahip kartı bulup sequence sırasının en önüne koyar
func force_next_card(card_id: String) -> void:
	var card_data = find_card_by_id(card_id)
	if not card_data.is_empty():
		_sequence_queue.push_front(card_data)
	else:
		push_error("Deck: Forced card not found -> " + card_id)
