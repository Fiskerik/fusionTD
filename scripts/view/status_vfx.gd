class_name StatusVfx
extends RefCounted

const TRAIL_STYLES: Dictionary = {
	"burn": Color("#f57a41"), "poison": Color("#6eae43"),
	"slow": Color("#57a9cd"), "freeze": Color("#83cfea"), "curse": Color("#a266b5"),
	"disease": Color("#9859bb"), "slip": Color("#b9f5ff"),
}
const MAX_TRAILS: int = 112
const MAX_BURSTS: int = 64

var clock: float = 0.0
var trails: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var tracked: Dictionary = {}
var seen: Dictionary = {}

func advance(delta: float) -> void:
	clock += delta
	seen.clear()
	_expire(trails)
	_expire(bursts)

func observe(id: int, p: Vector2, statuses: PackedStringArray) -> void:
	if statuses.is_empty():
		return
	var previous: Dictionary = tracked.get(id, {})
	var old_statuses: PackedStringArray = previous.get("statuses", PackedStringArray())
	for status: String in statuses:
		if not old_statuses.has(status):
			_append(bursts, {"at": p, "status": status, "born": clock, "life": .49, "expires": clock + .49}, MAX_BURSTS)
	var last_stamp: float = previous.get("stamp", -1.0)
	var last_point: Vector2 = previous.get("point", p)
	var moved: bool = previous.is_empty() or p.distance_squared_to(last_point) > .028
	if moved and clock - last_stamp >= .13:
		var applied: int = 0
		for status: String in statuses:
			if TRAIL_STYLES.has(status):
				var life: float = .82 if status == "poison" else .55
				_append(trails, {"at": p + Vector2(0,.11), "status": status, "born": clock,
					"life": life, "expires": clock + life}, MAX_TRAILS)
				applied += 1
				if applied == 2:
					break
		last_stamp = clock
		last_point = p
	tracked[id] = {"statuses": statuses, "stamp": last_stamp, "point": last_point}
	seen[id] = true

func finish_frame() -> void:
	for id: int in tracked.keys():
		if not seen.has(id):
			tracked.erase(id)

func clear() -> void:
	trails.clear()
	bursts.clear()
	tracked.clear()
	seen.clear()

func _append(list: Array[Dictionary], value: Dictionary, limit: int) -> void:
	if list.size() == limit:
		list.pop_front()
	list.append(value)

func _expire(list: Array[Dictionary]) -> void:
	for i: int in range(list.size() - 1, -1, -1):
		if float(list[i].expires) <= clock:
			list.remove_at(i)

func draw_floor(canvas: CanvasItem) -> void:
	for mark: Dictionary in trails:
		var t: float = (clock - float(mark.born)) / float(mark.life)
		var p: Vector2 = mark.at
		var tint: Color = TRAIL_STYLES[mark.status]
		match String(mark.status):
			"poison":
				canvas.draw_circle(p, .12 + t * .11, Color("#496832", (1.0 - t) * .43))
				canvas.draw_circle(p + Vector2(-.03,.015), .10 + t * .09, Color(tint, (1.0 - t) * .64))
				for i: int in range(3):
					var bubble: Vector2 = p + Vector2((i - 1) * .09, -.025 - t * (.06 + .025 * i))
					canvas.draw_circle(bubble, .033 + .026 * sin(t * PI), Color("#ebffad", (1.0 - t) * .91))
			"slow", "freeze", "slip":
				canvas.draw_arc(p, .09 + t * .14, .19, 2.93, 12, Color(tint, (1.0 - t) * .77), .041)
				_diamond(canvas, p + Vector2(.057,-.038), .062 * (1.0 - t), Color("#eefaff", (1.0 - t) * .83))
			"burn":
				canvas.draw_circle(p, .08 + t * .08, Color("#8c634c", (1.0 - t) * .33))
				canvas.draw_circle(p - Vector2(.03,t * .16), .044 * (1.0 - t) + .015, Color("#ffa754", (1.0 - t) * .85))
				canvas.draw_circle(p + Vector2(t * .085,-t * .29), .055 + t * .047, Color("#876d61", sin(t * PI) * .28))
			_:
				canvas.draw_arc(p, .09 + t * .15, t, t + PI * 1.4, 14, Color(tint, (1.0 - t) * .58), .037)

func draw_bursts(canvas: CanvasItem) -> void:
	for burst: Dictionary in bursts:
		var t: float = (clock - float(burst.born)) / float(burst.life)
		var p: Vector2 = burst.at
		var status: String = burst.status
		var icon: String = StatusInfo.ICONS[status]
		var tint: Color = Glyphs.hue(icon)
		var alpha: float = (1.0 - t) * .85
		var reach: float = .14 + .43 * (1.0 - pow(1.0 - t, 3.0))
		canvas.draw_arc(p + Vector2(0,.077), reach, -.26, PI + .28, 17, Color(tint.darkened(.30), alpha), .047)
		for i: int in range(5):
			var direction := Vector2.from_angle(TAU * i / 5.0 + .45)
			var dot: Vector2 = p + direction * reach - Vector2(0,t * .18)
			match status:
				"slow", "freeze", "phasing", "slip":
					_diamond(canvas, dot, .076 * (1.0 - t) + .026, Color(tint.lightened(.26), alpha))
				"root":
					Glyphs.draw(canvas, "nature", dot, .079, Color(tint.darkened(.30), alpha))
				_:
					canvas.draw_circle(dot, .058 * (1.0 - t) + .026, Color(tint, alpha))
		var badge: Vector2 = p - Vector2(0,.45 + .32 * t)
		canvas.draw_circle(badge, .118, Color(tint.darkened(.55), alpha))
		canvas.draw_circle(badge, .090, Color(tint.lightened(.39), alpha))
		Glyphs.draw(canvas, icon, badge, .067, Color(tint.darkened(.62), alpha))

func _diamond(canvas: CanvasItem, p: Vector2, r: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0,-r), p + Vector2(r * .73,0),
		p + Vector2(0,r), p + Vector2(-r * .73,0)]), color)
