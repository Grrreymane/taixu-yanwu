extends CanvasLayer
signal chosen(id:String)
signal cancelled
const Paths=preload("res://scripts/armor_paths.gd")
const Card=preload("res://scripts/choice_card.gd")
var buttons:Array[Button]=[]
var core_ids:Array[String]=[]
var panel:Control
var title:Label
var back:Button

func _ready() -> void:
 layer=25
 var root:=ColorRect.new()
 root.color=Color(0.02,0.06,0.10,0.96)
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(root)
 panel=Control.new();panel.theme=Theme.new()
 panel.theme.default_font=preload("res://assets/fonts/hi3-sdk-zh-cn.ttf")
 root.add_child(panel)
 title=Label.new();title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 title.add_theme_font_size_override("font_size",32);panel.add_child(title)
 for index in 3:
  var card=Card.new();panel.add_child(card)
  card.pressed.connect(func():chosen.emit(core_ids[index]))
  buttons.append(card)
 back=Button.new();back.text="返回  ESC";back.accessibility_name="返回装甲选择"
 back.pressed.connect(func():cancelled.emit());panel.add_child(back)
 get_viewport().size_changed.connect(_resize)
 hide()

func _resize() -> void:
 if not is_instance_valid(panel):return
 var viewport:=get_viewport().get_visible_rect().size
 var narrow:=viewport.x<760.0
 var base:=Vector2(600,650) if narrow else Vector2(1000,470)
 var factor:=minf(1.0,minf((viewport.x-32)/base.x,(viewport.y-32)/base.y))
 panel.scale=Vector2.ONE*factor;panel.position=(viewport-base*factor)*0.5;panel.size=base
 title.position=Vector2.ZERO;title.size=Vector2(base.x,60)
 for i in 3:
  buttons[i].position=Vector2(0,82+i*158) if narrow else Vector2(i*338,88)
  buttons[i].size=Vector2(600,144) if narrow else Vector2(324,300)
  if narrow:
   buttons[i].heading.position=Vector2(24,14)
   buttons[i].effect.position=Vector2(210,18);buttons[i].effect.size=Vector2(360,94)
   buttons[i].action_label.position=Vector2(24,99)
 back.position=Vector2((base.x-220)*0.5,base.y-45);back.size=Vector2(220,44)

func open(font:Font,style:String="night_squire") -> void:
 panel.theme.default_font=font
 title.text=Paths.STYLES.get(style,style)+" · 核心打法"
 core_ids.clear()
 var rows:Array=Paths.options(style)
 for i in 3:
  var row:Dictionary=rows[i];core_ids.append(str(row.id))
  buttons[i].set_choice(row.title,row.description,Paths.BASICS.get(style,row.hint),i,"选用")
 show();_resize()

func has_details() -> bool:
 for card in buttons:
  if card.detail.visible:return true
 return false
