class_name SimRng
extends RefCounted

var state: int

func _init(seed_value: int) -> void:
	state = maxi(1, (seed_value & 0xffffffff))

func take(maximum: int) -> int:
	state ^= state << 13
	state &= 0xffffffff
	state ^= state >> 17
	state ^= state << 5
	state &= 0xffffffff
	return state % maximum
