extends CanvasLayer
signal chosen(id:String)
signal cancelled
const Paths=preload("res://scripts/night_paths.gd")
var buttons:Array[Button]=[]
var panel:VBoxContainer

func _ready() -> void:
 layer=25
 var root:=ColorRect.new()
 root.color=Color(0.02,0.06,0.10,0.94)
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(root)
 var center:=CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.add_child(center)
 panel=VBoxContainer.new()
 panel.theme=Theme.new()
 panel.theme.default_font=preload("res://assets/fonts/hi3-sdk-zh-cn.ttf")
 panel.add_theme_constant_override("separation",18)
 center.add_child(panel)
 var title:=Label.new()
 title.text="白夜执事 · 选择本轮打法"
 title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 title.add_theme_font_size_override("font_size",32)
 panel.add_child(title)
 var subtitle:=Label.new()
 subtitle.text="核心立即生效。每条路线有两项专属强化，过关后选择。"
 subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 subtitle.add_theme_font_size_override("font_size",16)
 panel.add_child(subtitle)
 for index in 3:
  var core:Dictionary=Paths.options()[index]
  var button:=Button.new()
  button.text="%d   %s\n%s\n%s"%[index+1,core.title,core.description,core.hint]
  button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  button.add_theme_font_size_override("font_size",19)
  button.custom_minimum_size=Vector2(0,116)
  var style:=StyleBoxFlat.new()
  style.bg_color=Color("153343")
  style.border_color=Color("64b9d1")
  style.set_border_width_all(1)
  style.content_margin_left=18;style.content_margin_right=18
  button.add_theme_stylebox_override("normal",style)
  var hover:=style.duplicate()
  hover.bg_color=Color("235167")
  button.add_theme_stylebox_override("hover",hover)
  button.add_theme_stylebox_override("focus",hover)
  button.pressed.connect(func():chosen.emit(str(core.id)))
  panel.add_child(button)
  buttons.append(button)
 var back:=Button.new()
 back.text="返回  ESC"
 back.custom_minimum_size.y=40
 back.pressed.connect(func():cancelled.emit())
 panel.add_child(back)
 get_viewport().size_changed.connect(_resize)
 _resize()
 hide()

func _resize() -> void:
 if is_instance_valid(panel):panel.custom_minimum_size.x=minf(900.0,get_viewport().get_visible_rect().size.x-48.0)

func open(font:Font) -> void:
 panel.theme.default_font=font
 show()
