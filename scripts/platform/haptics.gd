class_name Haptics
extends RefCounted

static func play(milliseconds: int, enabled: bool) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds)
