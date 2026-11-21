class_name Economy
extends RefCounted

static func scaled(values: Array, wave: int) -> int:
	return int(values[0]) + int(values[1]) * wave

static func clear_reward(wave: int) -> int:
	return scaled(DataDB.read("balance").wave_clear_bonus, wave)

static func interest(gold: int) -> int:
	return floori(gold * float(DataDB.read("balance").interest))

static func refund(invested: int) -> int:
	return floori(invested * float(DataDB.read("balance").sell_refund))

static func move_fee(invested: int) -> int:
	return ceili(invested * float(DataDB.read("balance").move_rate))
