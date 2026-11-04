extends Button
## Main effect stays visible; optional context opens on request.
var heading:Label
var effect:Label
var info:Button
var detail:AcceptDialog
var action_label:Label

func _init() -> void:
 focus_mode=Control.FOCUS_ALL
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 for state:String in ["normal","hover","pressed","disabled","focus"]:
  var box:=StyleBoxFlat.new()
  box.bg_color=Color("152d40");box.border_color=Color("6593af")
  box.set_border_width_all(1);box.set_corner_radius_all(10)
  if state=="hover":box.bg_color=Color("23465e");box.border_color=Color("b8e9ff")
  if state=="pressed":box.bg_color=Color("0d2334")
  if state=="disabled":box.bg_color=Color("182633")
  if state=="focus":box.bg_color=Color.TRANSPARENT;box.border_color=Color.WHITE;box.set_border_width_all(3)
  add_theme_stylebox_override(state,box)
 heading=_label(28,Color.WHITE)
 effect=_label(21,Color("e1edf5"));effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 action_label=_label(16,Color("a5c8dd"))
 info=Button.new();info.text="i";info.accessibility_name="查看强化详情"
 info.add_theme_font_size_override("font_size",18)
 info.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 add_child(info)
 detail=AcceptDialog.new();detail.title="招式详情";detail.ok_button_text="关闭"
 detail.dialog_autowrap=true;detail.min_size=Vector2i(300,160)
 add_child(detail)
 info.pressed.connect(func():detail.popup_centered(Vector2i(mini(560,int(get_viewport_rect().size.x)-40),250)))
 resized.connect(_layout)

func _label(font_size:int,color:Color) -> Label:
 var label:=Label.new()
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",color)
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(label)
 return label

func set_choice(title:String,body:String,extra:String,index:int,verb:String="选取") -> void:
 heading.text=title;effect.text=body;action_label.text="%d  ·  %s  →"%[index+1,verb]
 accessibility_name=verb+" "+title;accessibility_description=body
 info.tooltip_text=extra;info.accessibility_name=title+"，查看详情";info.accessibility_description=extra
 info.visible=not extra.is_empty()
 detail.title=title;detail.dialog_text=extra
 _layout()

func _layout() -> void:
 heading.position=Vector2(24,29);heading.size=Vector2(size.x-48,46)
 effect.position=Vector2(24,97);effect.size=Vector2(size.x-48,size.y-165)
 action_label.position=Vector2(24,size.y-48);action_label.size=Vector2(size.x-80,30)
 info.position=Vector2(size.x-60,size.y-52);info.size=Vector2(36,36)
