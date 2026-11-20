class_name Economy
extends RefCounted

static func scaled(values: Array, wave: int) -> int:
	return int(values[0]) + int(values[1]) * wave

static func clear_reward(wave: int, gold: int) -> int:
	var cfg: Dictionary = DataDB.read("balance")
	return scaled(cfg.wave_clear_bonus, wave) + mini(int(cfg.interest_cap), floori(gold * float(cfg.interest)))

static func refund(invested: int) -> int:
	return floori(invested * float(DataDB.read("balance").sell_refund))

static func move_fee(invested: int) -> int:
	return ceili(invested * float(DataDB.read("balance").move_rate))
