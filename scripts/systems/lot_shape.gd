class_name LotShape
extends RefCounted
## Parking-lot outlines for big levels: rect, round, octagon, diamond and
## plus (a cross). A cell is part of the lot when its centre lies inside the
## outline. Every outline is row- and column-convex: leaving the lot in a
## straight line only ever crosses empty ground, so the tap rules stay the
## same as for a plain rectangle.

const SHAPES := ["rect", "round", "octagon", "diamond", "plus"]


## Normalised cell-centre coordinates in [-1, 1].
static func _uv(x: int, y: int, w: int, h: int) -> Vector2:
	return Vector2((x + 0.5 - w * 0.5) / (w * 0.5), (y + 0.5 - h * 0.5) / (h * 0.5))


static func contains(u: float, v: float, shape: String) -> bool:
	match shape:
		"round":
			return u * u + v * v <= 1.08
		"octagon":
			return absf(u) + absf(v) <= 1.42
		"diamond":
			return absf(u) + absf(v) <= 1.12
		"plus":
			return absf(u) <= 0.5 or absf(v) <= 0.5
	return true


## 1 for lot cells, 0 for cells outside the outline (row-major).
static func inside(w: int, h: int, shape: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(w * h)
	for y in h:
		for x in w:
			var uv := _uv(x, y, w, h)
			out[y * w + x] = 1 if contains(uv.x, uv.y, shape) else 0
	return out


static func count(w: int, h: int, shape: String) -> int:
	var n := 0
	for v in inside(w, h, shape):
		n += v
	return n


## Cells outside the outline as [[x, y], ...] (stored in the level).
static func holes(w: int, h: int, shape: String) -> Array:
	var out: Array = []
	var ins := inside(w, h, shape)
	for y in h:
		for x in w:
			if ins[y * w + x] == 0:
				out.append([x, y])
	return out


## The outline as a polygon in normalised coordinates.
static func outline(shape: String) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		"round":
			var r := sqrt(1.08)
			for i in 48:
				var a := TAU * i / 48.0
				pts.append(Vector2(cos(a), sin(a)) * r)
		"octagon", "diamond":
			var k := 0.42 if shape == "octagon" else 0.12
			pts = PackedVector2Array([Vector2(k, -1), Vector2(1, -k), Vector2(1, k), Vector2(k, 1), Vector2(-k, 1), Vector2(-1, k), Vector2(-1, -k), Vector2(-k, -1)])
		"plus":
			var a := 0.5
			pts = PackedVector2Array([Vector2(-a, -1), Vector2(a, -1), Vector2(a, -a), Vector2(1, -a), Vector2(1, a), Vector2(a, a),
				Vector2(a, 1), Vector2(-a, 1), Vector2(-a, a), Vector2(-1, a), Vector2(-1, -a), Vector2(-a, -a)])
		_:
			pts = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	return pts


## The paved area to draw for a lot in `rect` (pixels): the outline grown by
## `pad` so every lot cell is fully covered, clipped to the lot's bounds.
static func paved_polygon(rect: Rect2, shape: String, pad: float) -> PackedVector2Array:
	if shape == "rect" or shape == "":
		return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var c := rect.get_center()
	var half := rect.size * 0.5
	var px := PackedVector2Array()
	for p in outline(shape):
		px.append(c + p * half)
	var grown := Geometry2D.offset_polygon(px, pad, Geometry2D.JOIN_ROUND)
	if grown.is_empty():
		return px
	var bounds := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var clipped := Geometry2D.intersect_polygons(grown[0], bounds)
	return clipped[0] if not clipped.is_empty() else grown[0]
