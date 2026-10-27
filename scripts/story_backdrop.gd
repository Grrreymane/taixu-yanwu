extends Control
const FONT = preload("res://assets/fonts/hi3-sdk-zh-cn.ttf")
const NOODLE_SHOP = preload("res://assets/story/noodle-shop.png")
const MEMORY_KITCHEN = preload("res://assets/story/memory-kitchen.png")
## Quiet chapter stills for the outing and remembered kitchen.
## Native character takes remain untouched; these scenes do not pose a diner rig.
var location := "mountain"

func set_location(value: String) -> void:
	if location == value: return
	location = value
	visible = location != "mountain"
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	hide()

func _draw() -> void:
	if location == "mountain": return
	if location in ["noodle_shop","memory"]:
		var texture: Texture2D=MEMORY_KITCHEN if location=="memory" else NOODLE_SHOP
		var image_size:=Vector2(texture.get_size())
		var cover:=maxf(size.x/image_size.x,size.y/image_size.y)
		var destination:=image_size*cover
		draw_texture_rect(texture,Rect2((size-destination)*0.5,destination),false)
		return
	var memory := location == "memory"
	var top := Color("141a26") if not memory else Color("171c21")
	var bottom := Color("53433c") if not memory else Color("414344")
	for i in range(48):
		draw_rect(Rect2(0, size.y * i / 48.0, size.x, size.y / 48.0 + 1), top.lerp(bottom, float(i) / 47.0))
	var scale_factor := minf(size.x / 1280.0, size.y / 800.0)
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.44), 0, Vector2.ONE * scale_factor)
	if location == "street":
		_street()

	draw_set_transform(Vector2.ZERO)

func _street() -> void:
	# Evening street, a lit doorway, and the old sign from the manuscript.
	for side: int in [-1, 1]:
		for i in range(4):
			var x := side * (180.0 + i * 118.0)
			var height := 150.0 + (i % 3) * 31.0
			draw_rect(Rect2(x - 56, -height, 112, height + 100), Color("222a33"))
			for j in range(2):
				draw_rect(Rect2(x - 36 + j * 43, -height + 35, 22, 40), Color(0.73, 0.56, 0.35, 0.28 + 0.09 * (i % 2)))
		draw_line(Vector2(side * 92, 74), Vector2(side * 540, 240), Color("6f6150"), 2, true)
	draw_rect(Rect2(-108, -205, 216, 280), Color("403b36"))
	draw_rect(Rect2(-80, -133, 160, 207), Color("a38a60"))
	draw_rect(Rect2(-65, -125, 130, 198), Color("d3b47b"))
	draw_line(Vector2(0, -125), Vector2(0, 74), Color("685b4b"), 5, true)
	draw_rect(Rect2(-120, -200, 240, 51), Color("655541"))
	draw_string(FONT, Vector2(-60, -166), "云 吞 面", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("eddfbd"))
	draw_line(Vector2(-148, 75), Vector2(148, 75), Color("c8a16d"), 3, true)

