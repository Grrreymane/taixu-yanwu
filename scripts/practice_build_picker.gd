extends CanvasLayer
signal action_requested(command:String)
const Card=preload("res://scripts/choice_card.gd")
const Paths=preload("res://scripts/armor_paths.gd")
var panel:Control
var title:Label
var cards:Array[Button]=[]
var perks:Array[CheckBox]=[]
var baseline:CheckBox
var perk_title:Label
var apply_button:Button
var cancel_button:Button
var view:Dictionary={}

func _ready() -> void:
 layer=26
 var shade:=ColorRect.new()
 shade.color=Color("081522")
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(shade)
 panel=Control.new();panel.theme=Theme.new()
 panel.theme.default_font=preload("res://assets/fonts/hi3-sdk-zh-cn.ttf")
 shade.add_child(panel)
 title=Label.new();title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 title.focus_mode=Control.FOCUS_ALL
 title.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
 title.add_theme_font_size_override("font_size",30);panel.add_child(title)
 for i in 3:
  var card=Card.new();panel.add_child(card);cards.append(card)
  card.toggle_mode=true
  var selected:=StyleBoxFlat.new();selected.bg_color=Color("254960");selected.border_color=Color("b9eaff")
  selected.set_border_width_all(2);selected.set_corner_radius_all(10)
  card.add_theme_stylebox_override("pressed",selected)
  card.pressed.connect(func():action_requested.emit("practice_core:"+str(view.options[i].id)))
 baseline=CheckBox.new();baseline.text="基础招式";baseline.accessibility_name="基础招式，不使用核心与专属强化"
 _style_button(baseline)
 baseline.pressed.connect(func():action_requested.emit("practice_core:"));panel.add_child(baseline)
 perk_title=Label.new();perk_title.text="专属强化";perk_title.add_theme_font_size_override("font_size",22);panel.add_child(perk_title)
 for i in 2:
  var box:=CheckBox.new();box.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  box.add_theme_font_size_override("font_size",19)
  _style_button(box)
  box.pressed.connect(func():action_requested.emit("practice_perk:"+str(view.perks[i].id)))
  panel.add_child(box);perks.append(box)
 cancel_button=Button.new();cancel_button.text="取消  ESC"
 _style_button(cancel_button)
 cancel_button.pressed.connect(func():action_requested.emit("practice_build_cancel"));panel.add_child(cancel_button)
 apply_button=Button.new();apply_button.text="应用并重置对练"
 _style_button(apply_button,true)
 apply_button.accessibility_description="以当前配置重新开始自由对练，双方生命、能量与冷却重置。"
 apply_button.pressed.connect(func():action_requested.emit("practice_build_apply"));panel.add_child(apply_button)
 get_viewport().size_changed.connect(_resize)
 hide()

func _style_button(button:Button,primary:bool=false) -> void:
 for state in ["normal","hover","pressed","hover_pressed","focus"]:
  var box:=StyleBoxFlat.new()
  box.bg_color=Color("b9eaff") if primary else Color("254960") if state in ["pressed","hover_pressed"] else Color("132d40")
  box.border_color=Color("b9eaff") if primary or state!="normal" else Color("567b94")
  box.set_border_width_all(2 if state in ["pressed","hover_pressed","focus"] else 1);box.set_corner_radius_all(6)
  box.content_margin_left=16;box.content_margin_right=16;box.content_margin_top=10;box.content_margin_bottom=10
  if state=="focus":box.bg_color=Color.TRANSPARENT;box.border_color=Color.WHITE
  button.add_theme_stylebox_override(state,box)
 if primary:
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,Color("10283c"))

func present(value:Dictionary) -> void:
 var entering:bool=not visible
 view=value
 title.text=Paths.STYLES.get(str(view.style),str(view.style))+" · 打法配置"
 for i in 3:
  var row:Dictionary=view.options[i]
  var selected:bool=row.id==view.core
  cards[i].set_choice(row.title,row.description,view.basics if view.basics!="" else row.hint,i,"已选" if selected else "选用")
  cards[i].set_pressed_no_signal(selected)
 baseline.set_pressed_no_signal(view.core=="")
 perk_title.visible=not view.perks.is_empty()
 for i in 2:
  perks[i].visible=i<view.perks.size()
  if not perks[i].visible:continue
  var row:Dictionary=view.perks[i]
  perks[i].text=str(row.title)+"\n"+str(row.description)
  perks[i].accessibility_name=str(row.title)
  perks[i].accessibility_description=str(row.description)
  perks[i].set_pressed_no_signal(row.id in view.selectedPerks)
 show();_resize()
 if entering:title.grab_focus()

func _resize() -> void:
 if not is_instance_valid(panel):return
 var viewport:=get_viewport().get_visible_rect().size
 var base:=Vector2(1040,690)
 var factor:=minf(1.0,minf((viewport.x-32)/base.x,(viewport.y-32)/base.y))
 panel.scale=Vector2.ONE*factor;panel.position=(viewport-base*factor)*0.5;panel.size=base
 title.position=Vector2.ZERO;title.size=Vector2(base.x,50)
 for i in 3:
  cards[i].position=Vector2(i*352,72);cards[i].size=Vector2(336,300)
 baseline.position=Vector2(0,389);baseline.size=Vector2(260,44)
 perk_title.position=Vector2(0,453);perk_title.size=Vector2(400,35)
 for i in 2:
  perks[i].position=Vector2(i*532,490);perks[i].size=Vector2(508,112)
 cancel_button.position=Vector2(266,634);cancel_button.size=Vector2(200,44)
 apply_button.position=Vector2(494,634);apply_button.size=Vector2(280,44)

func has_details() -> bool:
 for card in cards:
  if card.detail.visible:return true
 return false
