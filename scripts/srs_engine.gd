class_name SRSEngine
extends RefCounted

## Hybrid SM-2 + Leitner Intra-Session & Cross-Session Spaced Repetition Engine (Édition CEFR A1–B1)
## Tracks:
## - 45 3D Vocabulary Objects across 9 CEFR A1–B1 Sectors (`cards`)
## - 16 A2–B1 Grammar & Phonetic Breach Cards (`grammar_cards`)
## - 12 A2 3D Spatial/Scale/Motion Modifier Drills (`modifier_cursor`)
## - 16 DELF A2–B1 Situational Listening Scenarios (`scenario_cursor`)

const SAVE_PATH := "user://srs_progress.json"
const MAX_WORKING_SET := 5

var global_step: int = 0
# sector_filter:
#  -1 = Adaptive Full Course (A1 -> A2 -> B1)
#  -2 = CEFR A1 Track (Sectors 1-4)
#  -3 = CEFR A2 Track (Sectors 5-7 + Modifiers + A2 Scenarios + A2 Grammar)
#  -4 = CEFR B1 Track (Sectors 8-9 + B1 Scenarios + B1 Grammar)
#  -5 = Special Mode: A2 3D Spatial & Comparative Modifiers
#  -6 = Special Mode: DELF A2-B1 Situational Listening Scenarios
#  -7 = Special Mode: A2-B1 Grammar & Phonetic Breaches (3D Crystals)
#  0..8 = Specific Sector 1..9
var sector_filter: int = -1
var l1_mode: int = 0 # 0 = Adaptive Fade (Recommended), 1 = Always Show English, 2 = Full French Immersion
var cards: Dictionary = {} # vocab_id -> Dictionary
var grammar_cards: Dictionary = {} # gram_id -> Dictionary
var recent_history: Array[String] = []
var modifier_cursor: int = 0
var scenario_cursor: int = 0


func _init() -> void:
	_init_default_cards()
	load_progress()


func _init_default_cards() -> void:
	cards.clear()
	for item in VocabData.ITEMS:
		var vid: String = item["id"]
		cards[vid] = {
			"id": vid,
			"seen": false,
			"calibrated": false,
			"tier": 0,
			"ease": 2.3,
			"interval": 0,
			"due_step": 0,
			"correct": 0,
			"wrong": 0,
			"streak": 0,
			"last_timestamp": 0,
			"confused_with": {},
		}
	grammar_cards.clear()
	for g in VocabData.GRAMMAR_BREACHES:
		var gid: String = g["id"]
		grammar_cards[gid] = {
			"id": gid,
			"seen": false,
			"tier": 0,
			"ease": 2.3,
			"interval": 0,
			"due_step": 0,
			"correct": 0,
			"wrong": 0,
			"streak": 0,
		}


func reset_progress() -> void:
	global_step = 0
	recent_history.clear()
	modifier_cursor = 0
	scenario_cursor = 0
	_init_default_cards()
	save_progress()


func save_progress() -> void:
	var payload := {
		"version": 2,
		"global_step": global_step,
		"sector_filter": sector_filter,
		"l1_mode": l1_mode,
		"modifier_cursor": modifier_cursor,
		"scenario_cursor": scenario_cursor,
		"cards": cards,
		"grammar_cards": grammar_cards,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "\t"))
		f.close()


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	global_step = int(parsed.get("global_step", 0))
	sector_filter = clampi(int(parsed.get("sector_filter", -1)), -7, VocabData.SECTORS.size() - 1)
	l1_mode = clampi(int(parsed.get("l1_mode", 0)), 0, 2)
	modifier_cursor = int(parsed.get("modifier_cursor", 0))
	scenario_cursor = int(parsed.get("scenario_cursor", 0))
	var saved_cards: Dictionary = parsed.get("cards", {})
	var now_unix := int(Time.get_unix_time_from_system())
	for vid in saved_cards.keys():
		if cards.has(vid) and typeof(saved_cards[vid]) == TYPE_DICTIONARY:
			for k in saved_cards[vid].keys():
				cards[vid][k] = saved_cards[vid][k]
			var last_ts := int(cards[vid].get("last_timestamp", 0))
			if bool(cards[vid]["seen"]) and last_ts > 0 and (now_unix - last_ts) > 43200:
				cards[vid]["due_step"] = min(int(cards[vid]["due_step"]), global_step)
	var saved_gram: Dictionary = parsed.get("grammar_cards", {})
	for gid in saved_gram.keys():
		if grammar_cards.has(gid) and typeof(saved_gram[gid]) == TYPE_DICTIONARY:
			for k in saved_gram[gid].keys():
				grammar_cards[gid][k] = saved_gram[gid][k]


func get_candidate_pool() -> Array[String]:
	if sector_filter >= 0 and sector_filter < VocabData.SECTORS.size():
		return VocabData.get_sector_ids(sector_filter)
	if sector_filter == -2:
		return VocabData.get_cefr_vocab_ids("A1")
	if sector_filter == -3:
		return VocabData.get_cefr_vocab_ids("A2")
	if sector_filter == -4:
		return VocabData.get_cefr_vocab_ids("B1")
	return VocabData.get_all_ids()


func get_words_to_calibrate(max_new: int = 3) -> Array[String]:
	# Special non-vocab-calibration drill modes jump straight into combat waves
	if sector_filter in [-5, -6, -7]:
		return []

	var pool := get_candidate_pool()
	var active_learning := 0
	for vid in pool:
		var c: Dictionary = cards[vid]
		if bool(c["seen"]) and int(c["tier"]) < 2:
			active_learning += 1

	var slots := maxi(0, MAX_WORKING_SET - active_learning)
	var limit := mini(max_new, slots)
	var seen_in_pool := 0
	for vid in pool:
		if bool(cards[vid]["seen"]):
			seen_in_pool += 1
	if seen_in_pool < 4:
		limit = maxi(limit, 4 - seen_in_pool)

	var to_intro: Array[String] = []
	for vid in pool:
		if to_intro.size() >= limit:
			break
		if not bool(cards[vid]["calibrated"]):
			to_intro.append(vid)
	return to_intro


func mark_calibrated(vid: String) -> void:
	if not cards.has(vid):
		return
	cards[vid]["seen"] = true
	cards[vid]["calibrated"] = true
	cards[vid]["last_timestamp"] = int(Time.get_unix_time_from_system())
	if int(cards[vid]["correct"]) == 0 and int(cards[vid]["wrong"]) == 0:
		cards[vid]["due_step"] = global_step
	save_progress()


func select_next_target() -> String:
	var pool := get_candidate_pool()
	var seen_ids: Array[String] = []
	for vid in pool:
		if bool(cards[vid]["seen"]):
			seen_ids.append(vid)

	if seen_ids.size() < 4:
		for vid in pool:
			if not bool(cards[vid]["seen"]):
				cards[vid]["seen"] = true
				cards[vid]["calibrated"] = true
				cards[vid]["due_step"] = global_step
				seen_ids.append(vid)
			if seen_ids.size() >= 4:
				break

	var last_id: String = recent_history.back() if not recent_history.is_empty() else ""
	var best_id := seen_ids[0]
	var best_score := -999999.0

	for vid in seen_ids:
		var c: Dictionary = cards[vid]
		var overdue := float(global_step - int(c["due_step"]))
		var tier_val := int(c["tier"])
		var score := 0.0
		if overdue >= 0.0:
			score += 100.0 + overdue * 12.0
		else:
			score += overdue * 8.0
		score += float(4 - tier_val) * 6.0
		score += float(mini(int(c["wrong"]), 5)) * 4.5
		if vid == last_id and seen_ids.size() > 1:
			score -= 500.0
		score += randf() * 2.5

		if score > best_score:
			best_score = score
			best_id = vid

	recent_history.append(best_id)
	if recent_history.size() > 8:
		recent_history.pop_front()
	return best_id


## Builds the full Pedagogical Prompt Specification for a standard Vocabulary target word
func build_prompt_spec(target_id: String) -> Dictionary:
	var item := VocabData.get_by_id(target_id)
	var c: Dictionary = cards[target_id]
	var tier := int(c["tier"])
	var cefr_badge: String = str(item.get("cefr", "A1"))

	var use_female := (global_step % 2 == 1)
	var speaker_name := "LT. DENISE" if use_female else "CMDT. HENRI"
	var audio_file := ""
	var prompt_fr := ""
	var sub_en := ""
	var mode_tag := ""
	var required_decoy := ""
	var show_fr_text := true
	var show_en_text := false

	if tier == 0:
		mode_tag = "%s • TIER 0 • CALIBRAGE" % cefr_badge
		audio_file = ("cmd_%s_f.ogg" % target_id) if use_female else ("cmd_%s_m.ogg" % target_id)
		prompt_fr = item["cmd_f"] if use_female else item["cmd_m"]
		sub_en = "%s (%s) — %s" % [item["fr_def"], item["fr_indef"], item["en"]]
		show_fr_text = true
		show_en_text = (l1_mode != 2)
	elif tier == 1:
		mode_tag = "%s • TIER 1 • RECONNAISSANCE FR" % cefr_badge
		audio_file = ("cmd_%s_f.ogg" % target_id) if use_female else ("cmd_%s_m.ogg" % target_id)
		prompt_fr = item["cmd_f"] if use_female else item["cmd_m"]
		sub_en = "%s — %s" % [item["fr_def"], item["en"]]
		show_fr_text = true
		show_en_text = (l1_mode == 1)
	elif tier == 2:
		mode_tag = "%s • TIER 2 • ÉCOUTE PURE (SANS TEXTE)" % cefr_badge
		audio_file = ("cmd_%s_f.ogg" % target_id) if use_female else ("cmd_%s_m.ogg" % target_id)
		prompt_fr = item["cmd_f"] if use_female else item["cmd_m"]
		sub_en = "%s — %s" % [item["fr_def"], item["en"]]
		show_fr_text = false
		show_en_text = (l1_mode == 1)
	else:
		var use_inhibit := ((int(c["correct"]) + global_step) % 2 == 1)
		if use_inhibit:
			mode_tag = "%s • TIER %d • PIÈGE NÉGATIF (NE TIREZ PAS...)" % [cefr_badge, tier]
			audio_file = "inhibit_%s.ogg" % target_id
			prompt_fr = item["inhibit"]
			sub_en = "Avoid decoy! Shoot: %s (%s)" % [item["fr_def"], item["en"]]
			required_decoy = item["inhibit_decoy"]
			var item_idx := VocabData.get_all_ids().find(target_id)
			speaker_name = "LT. DENISE" if (item_idx % 2 == 0) else "CMDT. HENRI"
		else:
			mode_tag = "%s • TIER %d • ÉNIGME DESCRIPTIVE" % [cefr_badge, tier]
			audio_file = "desc_%s.ogg" % target_id
			prompt_fr = item["desc"]
			sub_en = "%s → %s (%s)" % [item["desc_en"], item["fr_def"], item["en"]]
			var item_idx := VocabData.get_all_ids().find(target_id)
			speaker_name = "CMDT. HENRI" if (item_idx % 2 == 0) else "LT. DENISE"
		show_fr_text = false
		show_en_text = (l1_mode == 1)

	return {
		"prompt_type": "VOCAB",
		"target_id": target_id,
		"tier": tier,
		"speaker": speaker_name,
		"mode_tag": mode_tag,
		"audio_file": audio_file,
		"slow_audio_file": "slow_%s.ogg" % target_id,
		"word_audio_file": "word_%s.ogg" % target_id,
		"prompt_fr": prompt_fr,
		"sub_en": sub_en,
		"show_fr_text": show_fr_text,
		"show_en_text": show_en_text,
		"required_decoy": required_decoy,
	}


## Builds an A2 3D Spatial, Comparative/Superlative or Motion Modifier Prompt
func build_modifier_prompt_spec(force_index: int = -1) -> Dictionary:
	var idx := force_index if force_index >= 0 else (modifier_cursor % VocabData.MODIFIER_DRILLS.size())
	modifier_cursor += 1
	var drill: Dictionary = VocabData.MODIFIER_DRILLS[idx]
	var pool := get_candidate_pool()
	var base_vid: String = pool[randi() % pool.size()] if not pool.is_empty() else "valise"
	var item := VocabData.get_by_id(base_vid)

	return {
		"prompt_type": "MODIFIER",
		"drill_id": drill["id"],
		"layout": drill["layout"],
		"base_vocab_id": base_vid,
		"target_id": "MOD_TARGET",
		"tier": 2,
		"speaker": drill["speaker"],
		"mode_tag": "%s • MODIFICATEURS & ESPACE 3D" % drill["cefr"],
		"audio_file": drill["audio"],
		"slow_audio_file": "",
		"prompt_fr": drill["prompt_fr"],
		"sub_en": "%s  |  %s" % [drill["prompt_en"], drill["rule"]],
		"rule": drill["rule"],
		"show_fr_text": (l1_mode == 1),
		"show_en_text": (l1_mode == 1),
		"required_decoy": "",
		"base_fr": item.get("fr_def", base_vid),
	}


## Builds a DELF A2–B1 Situational Listening Dialogue / Scenario Prompt
func build_scenario_prompt_spec(force_index: int = -1) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for sc in VocabData.SCENARIOS:
		if sector_filter == -3 and String(sc["cefr"]) == "A2":
			candidates.append(sc)
		elif sector_filter == -4 and String(sc["cefr"]) == "B1":
			candidates.append(sc)
		else:
			candidates.append(sc)
	if candidates.is_empty():
		candidates = VocabData.SCENARIOS

	var idx := force_index if force_index >= 0 else (scenario_cursor % candidates.size())
	scenario_cursor += 1
	var sc: Dictionary = candidates[idx % candidates.size()]
	var tid: String = sc["target_id"]
	var item := VocabData.get_by_id(tid)

	return {
		"prompt_type": "SCENARIO",
		"scenario_id": sc["id"],
		"target_id": tid,
		"decoys": sc["decoys"],
		"tier": 3,
		"speaker": sc["speaker"],
		"mode_tag": "DELF %s • COMPRÉHENSION ORALE EN CONTEXTE" % sc["cefr"],
		"audio_file": sc["audio"],
		"slow_audio_file": "",
		"prompt_fr": "%s\n→ %s" % [sc["prompt_fr"], sc["question_fr"]],
		"question_fr": sc["question_fr"],
		"sub_en": "%s  →  Cible : %s (%s)" % [sc["prompt_en"], item["fr_def"], item["en"]],
		"show_fr_text": false,
		"show_en_text": (l1_mode == 1),
		"required_decoy": sc["decoys"][0],
	}


## Selects the highest-priority Grammar Breach card for the current CEFR track
func select_next_grammar_id() -> String:
	var pool: Array[String] = []
	for g in VocabData.GRAMMAR_BREACHES:
		var gid: String = g["id"]
		var cefr_str: String = g["cefr"]
		if sector_filter == -3 and cefr_str.begins_with("A2"):
			pool.append(gid)
		elif sector_filter == -4 and cefr_str == "B1":
			pool.append(gid)
		elif sector_filter not in [-3, -4]:
			pool.append(gid)
	if pool.is_empty():
		pool = VocabData.get_all_grammar_ids()

	var best_id := pool[0]
	var best_score := -999999.0
	var last_id: String = recent_history.back() if not recent_history.is_empty() else ""

	for gid in pool:
		var gc: Dictionary = grammar_cards[gid]
		var overdue := float(global_step - int(gc["due_step"]))
		var tier_val := int(gc["tier"])
		var score := 0.0
		if not bool(gc["seen"]):
			score += 85.0
		elif overdue >= 0.0:
			score += 110.0 + overdue * 10.0
		else:
			score += overdue * 6.0
		score += float(4 - tier_val) * 5.0
		score += float(mini(int(gc["wrong"]), 5)) * 5.0
		if gid == last_id and pool.size() > 1:
			score -= 400.0
		score += randf() * 2.0
		if score > best_score:
			best_score = score
			best_id = gid

	recent_history.append(best_id)
	if recent_history.size() > 8:
		recent_history.pop_front()
	return best_id


## Builds an A2–B1 Holographic Data-Crystal Grammar & Phonetic Breach Prompt
func build_grammar_prompt_spec(force_gram_id: String = "") -> Dictionary:
	var gid := force_gram_id if force_gram_id != "" else select_next_grammar_id()
	var g := VocabData.get_grammar_by_id(gid)
	var gc: Dictionary = grammar_cards[gid]
	var tier := int(gc["tier"])

	return {
		"prompt_type": "GRAMMAR",
		"grammar_id": gid,
		"target_id": g["correct"],
		"options": g["options"],
		"tier": tier,
		"speaker": g["speaker"],
		"mode_tag": "%s • BRÈCHE GRAMMATICALE : %s" % [g["cefr"], g["category"]],
		"audio_file": g["audio"],
		"slow_audio_file": "",
		"prompt_fr": g["sentence_cloze"],
		"sentence_full": g["sentence_full"],
		"sub_en": "%s  |  Règle : %s" % [g["en"], g["rule"]],
		"rule": g["rule"],
		"en": g["en"],
		"show_fr_text": true,
		"show_en_text": (l1_mode != 2 and tier == 0) or (l1_mode == 1),
		"required_decoy": "",
	}


## Master Wave Prompt Router: weaves Vocabulary, 3D Modifiers, DELF Scenarios & Grammar Crystals!
func build_wave_prompt_spec(prompt_in_wave: int) -> Dictionary:
	if sector_filter == -5:
		return build_modifier_prompt_spec()
	if sector_filter == -6:
		return build_scenario_prompt_spec()
	if sector_filter == -7:
		return build_grammar_prompt_spec()

	# In CEFR A2 (-3), CEFR B1 (-4), or Full Adaptive (-1), weave the 4 pedagogical pillars across the 6-prompt wave:
	if sector_filter in [-1, -3, -4]:
		if prompt_in_wave == 4:
			return build_modifier_prompt_spec()
		if prompt_in_wave == 5:
			return build_scenario_prompt_spec()
		if prompt_in_wave == 6:
			return build_grammar_prompt_spec()

	# In specific A2/B1 Sectors (4..8), include a 3D Modifier on prompt 5 and Grammar/Scenario on prompt 6:
	if sector_filter >= 4 and sector_filter <= 8:
		if prompt_in_wave == 5:
			return build_modifier_prompt_spec()
		if prompt_in_wave == 6:
			return build_grammar_prompt_spec()

	var target_id := select_next_target()
	return build_prompt_spec(target_id)


func select_distractors(target_id: String, count: int = 4, required_decoy: String = "") -> Array[String]:
	var distractors: Array[String] = []
	if required_decoy != "" and required_decoy != target_id:
		distractors.append(required_decoy)

	if cards.has(target_id):
		var conf_map: Dictionary = cards[target_id].get("confused_with", {})
		var personal_keys := conf_map.keys()
		personal_keys.sort_custom(func(a, b): return int(conf_map[a]) > int(conf_map[b]))
		for k in personal_keys:
			var ks := str(k)
			if ks != target_id and not distractors.has(ks) and distractors.size() < count:
				distractors.append(ks)

	var item := VocabData.get_by_id(target_id)
	var built_in: Array = item.get("confusables", [])
	for b in built_in:
		var bs := str(b)
		if bs != target_id and cards.has(bs) and not distractors.has(bs) and distractors.size() < count:
			if bool(cards[bs]["seen"]) or int(cards[target_id]["tier"]) >= 2 or sector_filter < 0:
				distractors.append(bs)

	var pool := get_candidate_pool()
	var shuffled_seen: Array[String] = []
	var shuffled_rest: Array[String] = []
	for vid in pool:
		if vid == target_id or distractors.has(vid):
			continue
		if bool(cards[vid]["seen"]):
			shuffled_seen.append(vid)
		else:
			shuffled_rest.append(vid)
	shuffled_seen.shuffle()
	shuffled_rest.shuffle()

	for vid in shuffled_seen:
		if distractors.size() >= count:
			break
		distractors.append(vid)
	for vid in shuffled_rest:
		if distractors.size() >= count:
			break
		distractors.append(vid)
	if distractors.size() < count:
		var all_ids := VocabData.get_all_ids()
		all_ids.shuffle()
		for vid in all_ids:
			if vid != target_id and not distractors.has(vid):
				distractors.append(vid)
			if distractors.size() >= count:
				break
	return distractors


func record_result(target_id: String, clean_first_try: bool, used_assistance: bool, wrong_shot_ids: Array[String]) -> Dictionary:
	global_step += 1
	if not cards.has(target_id):
		save_progress()
		return {"prev_tier": 2, "new_tier": 2, "next_in_prompts": 4}

	var c: Dictionary = cards[target_id]
	c["seen"] = true
	c["last_timestamp"] = int(Time.get_unix_time_from_system())
	var prev_tier := int(c["tier"])

	var conf_map: Dictionary = c.get("confused_with", {})
	for wid in wrong_shot_ids:
		if wid != "" and wid != target_id and cards.has(wid):
			conf_map[wid] = int(conf_map.get(wid, 0)) + 1
			var wc: Dictionary = cards[wid]
			var w_conf: Dictionary = wc.get("confused_with", {})
			w_conf[target_id] = int(w_conf.get(target_id, 0)) + 1
			wc["confused_with"] = w_conf
			wc["due_step"] = mini(int(wc["due_step"]), global_step + 2)
	c["confused_with"] = conf_map

	if not clean_first_try:
		c["wrong"] = int(c["wrong"]) + 1
		c["streak"] = 0
		c["ease"] = maxf(1.3, float(c["ease"]) - 0.22)
		c["tier"] = maxi(0, prev_tier - 1)
		c["interval"] = 2
		c["due_step"] = global_step + 2
	elif used_assistance:
		c["correct"] = int(c["correct"]) + 1
		c["streak"] = int(c["streak"]) + 1
		c["ease"] = maxf(1.3, float(c["ease"]) - 0.05)
		c["interval"] = 3
		c["due_step"] = global_step + 3
	else:
		c["correct"] = int(c["correct"]) + 1
		c["streak"] = int(c["streak"]) + 1
		c["ease"] = minf(3.0, float(c["ease"]) + 0.10)
		var new_tier := mini(4, prev_tier + 1)
		c["tier"] = new_tier
		var base_intervals := [2, 3, 6, 11, 22]
		var base_iv: int = base_intervals[new_tier]
		var scaled_iv := maxi(2, int(round(float(base_iv) * (float(c["ease"]) / 2.3))))
		c["interval"] = scaled_iv
		c["due_step"] = global_step + scaled_iv

	save_progress()
	return {
		"prev_tier": prev_tier,
		"new_tier": int(c["tier"]),
		"next_in_prompts": int(c["interval"]),
	}


func record_grammar_result(gram_id: String, clean_first_try: bool, used_assistance: bool) -> Dictionary:
	global_step += 1
	if not grammar_cards.has(gram_id):
		return {"prev_tier": 0, "new_tier": 1, "next_in_prompts": 3}
	var gc: Dictionary = grammar_cards[gram_id]
	gc["seen"] = true
	var prev_tier := int(gc["tier"])
	if not clean_first_try:
		gc["wrong"] = int(gc["wrong"]) + 1
		gc["streak"] = 0
		gc["tier"] = maxi(0, prev_tier - 1)
		gc["interval"] = 2
		gc["due_step"] = global_step + 2
	elif used_assistance:
		gc["correct"] = int(gc["correct"]) + 1
		gc["streak"] = int(gc["streak"]) + 1
		gc["interval"] = 3
		gc["due_step"] = global_step + 3
	else:
		gc["correct"] = int(gc["correct"]) + 1
		gc["streak"] = int(gc["streak"]) + 1
		var new_tier := mini(4, prev_tier + 1)
		gc["tier"] = new_tier
		var base_intervals := [2, 4, 7, 12, 20]
		gc["interval"] = base_intervals[new_tier]
		gc["due_step"] = global_step + int(gc["interval"])
	save_progress()
	return {
		"prev_tier": prev_tier,
		"new_tier": int(gc["tier"]),
		"next_in_prompts": int(gc["interval"]),
	}


func get_summary_stats() -> Dictionary:
	var seen_cnt := 0
	var listening_ready := 0
	var mastered_cnt := 0
	var due_cnt := 0
	var total_ok := 0
	var total_err := 0
	for vid in cards.keys():
		var c: Dictionary = cards[vid]
		if bool(c["seen"]):
			seen_cnt += 1
			if int(c["due_step"]) <= global_step:
				due_cnt += 1
		if int(c["tier"]) >= 2:
			listening_ready += 1
		if int(c["tier"]) >= 3:
			mastered_cnt += 1
		total_ok += int(c["correct"])
		total_err += int(c["wrong"])

	var gram_seen := 0
	var gram_mastered := 0
	for gid in grammar_cards.keys():
		var gc: Dictionary = grammar_cards[gid]
		if bool(gc["seen"]):
			gram_seen += 1
		if int(gc["tier"]) >= 2:
			gram_mastered += 1
		total_ok += int(gc["correct"])
		total_err += int(gc["wrong"])

	var acc := 100.0 if (total_ok + total_err) == 0 else (100.0 * float(total_ok) / float(total_ok + total_err))
	return {
		"total_words": cards.size(),
		"seen": seen_cnt,
		"listening_ready": listening_ready,
		"mastered": mastered_cnt,
		"gram_total": grammar_cards.size(),
		"gram_seen": gram_seen,
		"gram_mastered": gram_mastered,
		"due_now": due_cnt,
		"accuracy": acc,
	}
