extends SceneTree

var passed: int = 0
var failed: int = 0
var current: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var files: PackedStringArray = DirAccess.get_files_at("res://tests")
	files.sort()
	for file: String in files:
		if not file.begins_with("test_") or not file.ends_with(".gd") or file == "test_base.gd":
			continue
		var suite: RefCounted = load("res://tests/" + file).new()
		suite.runner = self
		for method: Dictionary in suite.get_method_list():
			if String(method.name).begins_with("test_"):
				current = file + "::" + String(method.name)
				var assertions: int = passed + failed
				await suite.call(method.name)
				if passed + failed == assertions:
					check(false, "Test recorded no assertions")
	print("PASSED: %d  FAILED: %d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		printerr("FAIL [%s] %s" % [current, message])
