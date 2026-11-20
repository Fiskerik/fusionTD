extends RefCounted

var runner: SceneTree

func check(condition: bool, message: String = "") -> void:
	runner.check(condition, message)

func equal(actual: Variant, expected: Variant, message: String = "") -> void:
	check(actual == expected, "%s (got %s, expected %s)" % [message, actual, expected])

func near(actual: float, expected: float, message: String = "") -> void:
	check(absf(actual - expected) < 0.0001, "%s (got %f, expected %f)" % [message, actual, expected])
