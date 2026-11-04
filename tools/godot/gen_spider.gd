extends SceneTree
## Procedural Giant Spider sprite sheet (SRD Giant Spider; our own art).
## Run: Godot_console --headless --path . -s res://tools/godot/gen_spider.gd   (then --import)
## Writes assets/sprites/monsters/giant_spider_sheet.png and giant_spider_preview.png (editor preview).
##
## A tiny 3D model (cephalothorax + abdomen blobs, 8 two-segment legs) projected into the iso view:
## forward/right ground axes per view, z up. Shaded with the 4x4 Bayer dither and outlined like
## the other sprites.
## Sheet: 40x32 cells (Large: wider than a tile); row 0 = front 3/4 (facing screen down-left), row 1 = back 3/4 (up-left);
## columns: idle 0-1, walk 2-5, attack 6-9, hurt 10-11, death 12-16. Feet at (20, 27).

const CELL := Vector2i(40, 32)
const FEET := Vector2(20, 27)
const OUT := "res://assets/sprites/monsters/"

const OUTLINE := Color8(20, 16, 24)
const BODY := [Color8(30, 24, 30), Color8(48, 38, 44), Color8(70, 56, 60), Color8(98, 80, 80), Color8(128, 106, 98)]
const LEG := Color8(88, 72, 72)
const KNEE := Color8(128, 106, 98)
const MARK := Color8(168, 150, 120)
const EYE := Color8(220, 40, 40)
const EYE_HI := Color8(255, 170, 120)
const FANG := Color8(200, 190, 170)
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

## Screen vectors of the model's forward / right ground axes (per model px), per view.
## Iso ground: screen = ((gx - gy) * 0.71, (gx + gy) * 0.355).
const VIEWS := {
	"front": {"F": Vector2(-0.71, 0.355), "R": Vector2(-0.71, -0.355)},   # facing +y cell (down-left)
	"back": {"F": Vector2(-0.71, -0.355), "R": Vector2(0.71, -0.355)},    # facing -x cell (up-left)
}

## Legs: attach point on the cephalothorax (forward offset), foot (forward, outward). Per side.
const LEGS := [
	{"attach": 3.0, "foot": Vector2(12.0, 10.0)},
	{"attach": 1.5, "foot": Vector2(5.0, 13.0)},
	{"attach": 0.0, "foot": Vector2(-2.5, 13.0)},
	{"attach": -1.5, "foot": Vector2(-9.0, 10.5)},
]


func _init() -> void:
	var cols := 17
	var sheet := Image.create_empty(CELL.x * cols, CELL.y * 2, false, Image.FORMAT_RGBA8)
	var row := 0
	for view in ["front", "back"]:
		var poses := _poses()
		for col in poses.size():
			var img := _render(view, poses[col])
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(col * CELL.x, row * CELL.y))
		row += 1
	sheet.save_png(ProjectSettings.globalize_path(OUT + "giant_spider_sheet.png"))
	var preview := sheet.get_region(Rect2i(Vector2i.ZERO, CELL))
	preview.save_png(ProjectSettings.globalize_path(OUT + "giant_spider_preview.png"))
	print("wrote ", OUT, "giant_spider_sheet.png (", sheet.get_size(), ")")
	quit()


## A pose: body offsets + per-leg adjustments.
##   body_f / body_z: body shift forward / up; breathe: abdomen grow
##   legs: Array of 8 {df, lift, curl} (0-3 = left side front..back, 4-7 = right side)
##   front_raise: extra lift of the two front legs; fangs: 0..1; squash
func _pose(body_f := 0.0, body_z := 0.0, breathe := 0.0) -> Dictionary:
	var legs := []
	for i in 8:
		legs.append({"df": 0.0, "lift": 0.0, "curl": 0.0})
	return {"body_f": body_f, "body_z": body_z, "breathe": breathe, "legs": legs,
			"front_raise": 0.0, "fangs": 0.0, "tilt": 0.0}


func _poses() -> Array:
	var out := []
	# idle: gentle breathing + a twitch
	var a := _pose(0, 0, 0)
	var b := _pose(0, 0.5, 0.6)
	b.legs[1].df = 0.8
	b.legs[6].df = -0.8
	out.append_array([a, b])
	# walk: alternating tetrapod gait (L1 R2 L3 R4 vs the rest)
	for f in 4:
		var p := _pose(0, 0.4 if f % 2 == 1 else 0.0)
		var t := f / 4.0 * TAU
		for i in 8:
			var side := i / 4
			var k := i % 4
			var group := (k + side) % 2
			var ph := t + (PI if group == 1 else 0.0)
			p.legs[i].df = 3.0 * cos(ph)
			p.legs[i].lift = maxf(0.0, 3.0 * sin(ph))
		out.append(p)
	# attack: rear up, hold, lunge + bite, recover
	var r1 := _pose(-2, 2)
	r1.front_raise = 6.0
	r1.tilt = 2.0
	var r2 := _pose(-3, 3)
	r2.front_raise = 9.0
	r2.tilt = 3.0
	r2.fangs = 0.5
	var l1 := _pose(4, 0.5)
	l1.front_raise = 2.0
	l1.fangs = 1.0
	l1.legs[0].df = 4.0
	l1.legs[4].df = 4.0
	var rc := _pose(1, 0)
	rc.fangs = 0.3
	out.append_array([r1, r2, l1, rc])
	# hurt: recoil back, then settle
	var h1 := _pose(-3, 1)
	h1.front_raise = 3.0
	var h2 := _pose(-1.5, 0.5)
	out.append_array([h1, h2])
	# death: legs curl under, body sinks
	for f in 5:
		var d := _pose(-0.5 * f, -1.0 * f)
		for i in 8:
			d.legs[i].curl = (f + 1) / 5.0
		out.append(d)
	return out


func _render(view: String, pose: Dictionary) -> Image:
	var F: Vector2 = VIEWS[view].F
	var R: Vector2 = VIEWS[view].R
	var img := Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	var proj := func(f: float, r: float, z: float) -> Vector2:
		return FEET + F * f + R * r + Vector2(0, -z)
	var bf: float = pose.body_f
	var bz: float = pose.body_z
	var ceph := {"c": proj.call(4.0 + bf, 0.0, 6.0 + bz + pose.tilt), "rx": 4.6, "ry": 3.8}
	var abd := {"c": proj.call(-5.5 + bf, 0.0, 7.5 + bz - pose.tilt * 0.5), "rx": 7.0 + pose.breathe, "ry": 5.6 + pose.breathe}
	# Build drawables with a depth (screen y of their nearest point) and paint far -> near.
	var items := []
	for i in 8:
		var side := 1.0 if i >= 4 else -1.0
		var k := i % 4
		var leg: Dictionary = LEGS[k]
		var lp: Dictionary = pose.legs[i]
		var attach: Vector2 = proj.call(4.0 + bf + leg.attach, side * 2.2, 6.0 + bz)
		var foot_f: float = leg.foot.x + lp.df + bf * 0.3
		var foot_r: float = side * leg.foot.y
		var foot_z: float = lp.lift
		if k == 0:
			foot_z += pose.front_raise
			foot_f += pose.front_raise * 0.4
		var curl: float = lp.curl
		if curl > 0.0:
			foot_f = lerpf(foot_f, 4.0 + bf + leg.attach, curl * 0.8)
			foot_r = lerpf(foot_r, side * 3.0, curl * 0.8)
			foot_z = lerpf(foot_z, 8.0 + bz, curl * 0.7)
		var foot: Vector2 = proj.call(foot_f, foot_r, foot_z)
		var knee_f := lerpf(4.0 + bf + leg.attach, foot_f, 0.55)
		var knee_r := lerpf(side * 2.2, foot_r, 0.6) * 1.08
		var knee_z := maxf(foot_z, 6.0 + bz) + 6.0 - curl * 3.0
		var knee: Vector2 = proj.call(knee_f, knee_r, knee_z)
		items.append({"kind": "leg", "a": attach, "k": knee, "f": foot, "depth": maxf(foot.y, knee.y) - 0.1})
	items.append({"kind": "blob", "b": abd, "depth": abd.c.y + 0.0, "part": "abd"})
	items.append({"kind": "blob", "b": ceph, "depth": ceph.c.y + 0.5, "part": "ceph"})
	items.sort_custom(func(x, y): return x.depth < y.depth)
	for it in items:
		if it.kind == "leg":
			_line(img, it.a, it.k, LEG)
			_line(img, it.k, it.f, LEG)
			_put(img, it.k.round(), KNEE)
		else:
			_blob(img, it.b)
			if it.part == "abd":
				_marking(img, it.b)
	# Face: eyes + fangs on the cephalothorax front (front view only; hidden from behind).
	if view == "front":
		var c: Vector2 = ceph.c
		var front := c + F.normalized() * 3.2 + Vector2(0, -0.5)
		_put(img, (front + Vector2(-1, -1)).round(), EYE)
		_put(img, (front + Vector2(1, -1)).round(), EYE)
		_put(img, (front + Vector2(-1, -1)).round() + Vector2(0, -1), EYE_HI)
		_put(img, (front + Vector2(0, 0)).round(), EYE)
		if pose.fangs > 0.0:
			var fy: float = 1.0 + pose.fangs * 2.0
			_put(img, (front + Vector2(-1, fy)).round(), FANG)
			_put(img, (front + Vector2(1, fy)).round(), FANG)
	_outline(img)
	return img


func _blob(img: Image, b: Dictionary) -> void:
	var c: Vector2 = b.c
	var rx: float = b.rx
	var ry: float = b.ry
	for y in range(int(c.y - ry - 1), int(c.y + ry + 2)):
		for x in range(int(c.x - rx - 1), int(c.x + rx + 2)):
			var nx := (x + 0.5 - c.x) / rx
			var ny := (y + 0.5 - c.y) / ry
			var d := nx * nx + ny * ny
			if d > 1.0:
				continue
			var light := 0.62 - 0.32 * nx - 0.5 * ny - 0.25 * d
			var q: float = light * BODY.size() + (BAYER[posmod(y, 4)][posmod(x, 4)] / 16.0 - 0.5) * 0.9
			_put(img, Vector2(x, y), BODY[clampi(int(q), 0, BODY.size() - 1)])


## Pale chevrons on top of the abdomen.
func _marking(img: Image, b: Dictionary) -> void:
	var c: Vector2 = b.c + Vector2(0, -b.ry * 0.35)
	for i in 2:
		var y := c.y - 1 + i * 2.5
		_put(img, Vector2(c.x, y).round(), MARK)
		_put(img, Vector2(c.x - 1, y + 1).round(), MARK)
		_put(img, Vector2(c.x + 1, y + 1).round(), MARK)


func _line(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var p := a.round()
	var q := b.round()
	var n := int(maxf(absf(q.x - p.x), absf(q.y - p.y)))
	for i in n + 1:
		var t := 0.0 if n == 0 else float(i) / n
		_put(img, p.lerp(q, t).round(), col)


func _put(img: Image, p: Vector2, col: Color) -> void:
	var x := int(p.x)
	var y := int(p.y)
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


func _outline(img: Image) -> void:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and src.get_pixelv(p).a > 0:
					img.set_pixel(x, y, OUTLINE)
					break
