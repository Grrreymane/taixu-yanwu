extends Node3D

const Combat=preload("res://scripts/combat.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Actor=preload("res://scripts/actor.gd")
const Arena=preload("res://scripts/arena.gd")
const HUD=preload("res://scripts/hud.gd")
const Effects=preload("res://scripts/effects.gd")
const SentienceEffects=preload("res://scripts/sentience_effects.gd")
const Music=preload("res://scripts/music.gd")
const CharacterVoice=preload("res://scripts/character_voice.gd")
const DialogueVoiceCues=preload("res://scripts/dialogue_voice_cues.gd")
const UltimateCamera=preload("res://scripts/ultimate_camera.gd")
const FenghuangCamera=preload("res://scripts/fenghuang_camera.gd")
const NightSquireCamera=preload("res://scripts/night_squire_camera.gd")
const LightningCamera=preload("res://scripts/lightning_camera.gd")
const BattleCamera=preload("res://scripts/battle_camera.gd")
const EnemyHealthDisplay=preload("res://scripts/enemy_health_display.gd")
const KnockoutPresentation=preload("res://scripts/knockout_presentation.gd")
const CombatAccent=preload("res://scripts/combat_accent.gd")
const UltimateFocus=preload("res://scripts/ultimate_focus.gd")
const FighterRoster=preload("res://scripts/fighter_roster.gd")
const SentienceProfile=preload("res://scripts/sentience_profile.gd")
const VictoryPresentation=preload("res://scripts/victory_presentation.gd")
const StoryPresentation=preload("res://scripts/story_presentation.gd")
const BossEntrance=preload("res://scripts/boss_entrance.gd")
const CharacterPreview=preload("res://scripts/character_preview.gd")
const REGION_COLORS := [Color("48c6ef"),Color("69dbb6"),Color("f5b05f")]

var game=Combat.new()
var campaign=Campaign.new()
var fighter: Dictionary=FighterRoster.resolve()
var appearance_choices: Dictionary={}
const FIGHTER_SETTINGS := "user://fighter-preferences.cfg"
var victory=VictoryPresentation.new()
var story=StoryPresentation.new()
var boss_entrance=BossEntrance.new()
var story_after:=""
var player: Node3D
var enemy_nodes: Dictionary={}
var enemy_markers: Dictionary={}
var death_times: Dictionary={}
var arena: Node3D
var hud: CanvasLayer
var effects: Node3D
var sentience_effects=SentienceEffects.new()
var music=Music.new()
var voice=CharacterVoice.new()
var dialogue_voice=DialogueVoiceCues.new()
var camera:=Camera3D.new()
var combat_accent=CombatAccent.new()
var ultimate_focus=UltimateFocus.new()
var knockout=KnockoutPresentation.new()
var knockout_started:=false
var knockout_pending:=false
var knockout_paused:=false
var ready_to_play:=false
var visual_time:=0.0
var touch_move:=0.0
var touch_guard:=false
var shake:=0.0
var end_time:=0.0
var end_delay:=1.15
var stage_countdown:=0.0
var telemetry_time:=0.0
var events: Array=[]
var js_callback
var menu_target:=Vector3(0.5,1.45,0)
var character_preview=CharacterPreview.new()
var camera_base:=Vector3(0,3.1,12.0)
var impact_age:=1.0
var impact_duration:=0.2
var impact_strength:=0.0
var impact_direction:=1.0
var impact_fresh:=false
var feel_frames: Array=[]
var cinematic_entry: Dictionary={}
var cinematic_frame: Dictionary={}
var cinematic_player_x:=0.0
var cinematic_target_x:=0.0
var cinematic_facing:=1.0
var cinematic_running:=false
var cinematic_return_time:=1.0
var cinematic_return_from: Dictionary={}
var camera_roll:=0.0
var _bar_font: Font=preload("res://assets/fonts/hi3-sdk-zh-cn.ttf")

func _ready() -> void:
 arena=Arena.new()
 add_child(arena)
 effects=Effects.new()
 add_child(effects)
 add_child(sentience_effects)
 add_child(music)
 add_child(voice)
 add_child(camera)
 camera.fov=34.0
 camera.position=Vector3(0,3.1,12.0)
 camera.look_at(Vector3(0,1.4,0))
 camera.current=true
 add_child(combat_accent)
 add_child(ultimate_focus)
 add_child(knockout)
 hud=HUD.new()
 add_child(hud)
 hud.action_requested.connect(_action)
 hud.move_changed.connect(func(value: float): touch_move=value)
 hud.guard_changed.connect(func(value: bool): touch_guard=value)
 add_child(story)
 story.finished.connect(_finish_story)
 add_child(boss_entrance)
 boss_entrance.skip_requested.connect(_skip_boss_entrance)
 boss_entrance.finished.connect(func():
  _clear_inputs()
  stage_countdown=0.8
  sentience_effects.clear())
 hud.set_ready(false)
 game.event.connect(_event)
 _load_fighter_choice()
 game.set_player_profile(str(fighter.style.combatProfile))
 player=Actor.new()
 add_child(player)
 player.setup(false,fighter)
 ready_to_play=true
 hud.set_ready(true)
 _init_bridge()
 print("DUEL_READY")

func _init_bridge() -> void:
 if not OS.has_feature("web"): return
 js_callback=JavaScriptBridge.create_callback(_js_action)
 var browser=JavaScriptBridge.get_interface("window")
 browser.__godotAction=js_callback
 JavaScriptBridge.eval("window.__godotReady=true; document.title='太虚演武 · 识境演武';")

func _js_action(arguments: Array) -> void:
 if arguments.is_empty(): return
 var command: String=str(arguments[0])
 if command=="move" and arguments.size()>1: touch_move=clampf(float(arguments[1]),-1.0,1.0)
 elif command=="guard_held" and arguments.size()>1: touch_guard=bool(arguments[1])
 else: _action(command)

func _input(event: InputEvent) -> void:
 if campaign.phase!="menu" or story.active or (is_instance_valid(hud) and hud.is_guide_open()):
  character_preview.cancel()
 if ready_to_play and campaign.phase=="menu" and not story.active and is_instance_valid(hud) and not hud.is_guide_open():
  # Input positions use the stretched canvas; HUD telemetry exposes browser
  # pixels. Convert the region back so small windows keep the same hit area.
  if hud.has_method("preview_rect") and character_preview.handle(event,get_viewport().get_final_transform().affine_inverse()*hud.preview_rect()):
   get_viewport().set_input_as_handled()
   return
 if ready_to_play and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_V:
  _action("voice")
  get_viewport().set_input_as_handled()
  return
 if is_instance_valid(hud) and hud.has_method("handle_modal_input") and hud.handle_modal_input(event): return
 if not event is InputEventKey or not event.pressed or event.echo: return
 if story.active:
  if event.physical_keycode in [KEY_ENTER,KEY_SPACE]: story.advance()
  elif event.physical_keycode==KEY_ESCAPE: story.skip()
  elif event.physical_keycode==KEY_M: music.toggle()
  get_viewport().set_input_as_handled()
  return
 if boss_entrance.active:
  if event.physical_keycode in [KEY_ENTER,KEY_SPACE,KEY_ESCAPE]: _skip_boss_entrance()
  elif event.physical_keycode==KEY_M: music.toggle()
  get_viewport().set_input_as_handled()
  return
 if ready_to_play and event.physical_keycode!=KEY_M:
  music.unlock()
  voice.unlock()
 var actions: Dictionary={KEY_ENTER:"start",KEY_J:"light",KEY_K:"heavy",KEY_Q:"ultimate",KEY_E:"ability",KEY_L:"guard",KEY_SPACE:"dodge",KEY_ESCAPE:"pause",KEY_R:"restart",KEY_T:"training",KEY_1:"reward_0",KEY_2:"reward_1",KEY_3:"reward_2",KEY_M:"music"}
 if actions.has(event.physical_keycode):
  var command: String=actions[event.physical_keycode]
  if event.physical_keycode==KEY_ENTER:
   if victory.playing(): command="victory_skip"
   elif campaign.phase=="failed": command="retry"
   elif campaign.phase=="cleared": command="practice" if campaign.mode=="practice" else "restart"
   elif game.paused: command="pause"
  _action(command)
  get_viewport().set_input_as_handled()

func _clear_inputs() -> void:
 touch_move=0.0
 touch_guard=false
 character_preview.cancel()

func _action(command: String) -> void:
 if not ready_to_play: return
 if command=="voice":
  voice.toggle()
  return
 if knockout.active:
  if command=="pause":
   if game.paused:
    game.action("pause")
    knockout_paused=false
   else: knockout_paused=not knockout_paused
   _clear_inputs()
   return
  if command not in ["menu","music"]: return
 if is_instance_valid(hud) and hud.has_method("is_guide_open") and hud.is_guide_open():
  if command=="menu": hud.close_fighter_guide()
  elif command=="music": music.toggle()
  return
 if boss_entrance.active and command not in ["menu","music","pause"]:
  if command in ["start","boss_skip","story_skip"]: _skip_boss_entrance()
  return
 if story.active:
  if command=="story_next": story.advance()
  elif command=="story_skip": story.skip()
  elif command=="music": music.toggle()
  elif command=="menu":
   story_after=""
   story.skip()
   _action("menu")
  return
 if command=="music":
  music.toggle()
  return
 music.unlock()
 voice.unlock()
 if command.begins_with("contract:"):
  campaign.select_contract(command.trim_prefix("contract:"))
  return
 if command=="contract_all":
  campaign.select_all_contracts()
  return
 if command=="preview_reset":
  if campaign.phase=="menu": character_preview.reset()
  return
 if command.begins_with("select_style:") or command.begins_with("select_appearance:"):
  if campaign.phase!="menu": return
  if command.begins_with("select_style:"):
   var style_id: String=command.trim_prefix("select_style:")
   _select_fighter(style_id,str(appearance_choices.get(style_id,"")))
  else:
   _select_fighter(str(fighter.styleId),command.trim_prefix("select_appearance:"))
  return
 if command=="victory_skip":
  victory.skip()
  effects.clear()
  sentience_effects.clear()
  return
 if command=="victory_replay":
  if campaign.phase=="cleared" and game.winner=="player": _begin_victory()
  return
 if victory.visible and command in ["pause","victory_pause"]:
  victory.toggle_pause()
  _clear_inputs()
  return
 if command=="menu":
  stage_countdown=0.0
  _clear_inputs()
  story.reset()
  game.reset()
  campaign.back_to_menu()
  character_preview.reset()
  _sync_actors()
  arena.set_region(0)
  return
 if command in ["start","restart","practice","trial"]:
  if command=="start" and campaign.phase!="menu": return
  _clear_inputs()
  if command=="practice" or (command=="restart" and campaign.mode=="practice"):
   var preserve_training: bool=campaign.mode=="practice" and campaign.phase!="menu"
   stage_countdown=0.0
   campaign.begin_practice()
   story.reset()
   if not preserve_training: game.set_training(false)
   game.start_sparring()
   game.enemy.name="识之律者"
   game.enemy.tint=Color("d96583")
   arena.set_region(0)
   effects.set_palette(REGION_COLORS[0])
   _sync_actors()
  else:
   campaign.begin_trial()
   _begin_encounter()
  return
 if command=="retry":
  if campaign.mode=="practice": _action("practice")
  elif campaign.retry(): _begin_encounter(false)
  return
 if command.begins_with("reward_"):
  if campaign.choose_reward(int(command.trim_prefix("reward_"))):
   # Commit the chosen technique once, then let both characters respond to
   # its full ordered history while the next encounter stays frozen.
   _begin_encounter(false)
   _begin_story("reward")
  return
 if campaign.phase!="fight": return
 if stage_countdown>0.0 and command!="pause": return
 if command=="training":
  if campaign.mode=="practice": game.set_training(not game.training)
 else: game.action(command)

func _begin_encounter(with_story: bool=true) -> void:
 _clear_inputs()
 var config: Dictionary=campaign.encounter()
 game.start_encounter(config,campaign.carry)
 stage_countdown=2.1
 _sync_actors()
 var region: int=int(config.regionIndex)
 arena.set_region(region)
 effects.set_palette(REGION_COLORS[region])
 effects.handle_event({"type":"spawnStage","x":game.player.x,"region":region,"title":config.title})
 hud.notify_text(str(config.title))
 if campaign.mode=="trial" and campaign.stage_index==campaign.stages.size()-1:
  boss_entrance.queue_entrance()
 if with_story and campaign.stage_index==0: _begin_story("intro")

func _begin_boss_entrance() -> void:
 _clear_inputs()
 effects.clear()
 sentience_effects.clear()
 combat_accent.clear()
 impact_strength=0.0
 shake=0.0
 boss_entrance.begin(float(game.player.x),float(game.enemy.x))
 voice.set_context(_voice_context())
 voice.handle_event({"type":"bossEntrance","side":"enemy","sourceId":game.enemy.id,"boss":true})
 var actor: Node3D=enemy_nodes.get(str(game.enemy.id),null)
 if is_instance_valid(actor): actor.reset_presentation()
 sentience_effects.handle_event({"type":"bossEntrance","x":game.enemy.x,"facing":-1.0})

func _skip_boss_entrance() -> void:
 var size:=get_viewport().get_visible_rect().size
 boss_entrance.skip(size.x/maxf(size.y,1.0))
 voice.stop_entrance()
 _clear_inputs()

func _begin_story(key: String,after: String="") -> void:
 _clear_inputs()
 voice.clear()
 dialogue_voice.reset()
 story_after=after
 story.begin(key,campaign.snapshot(game.snapshot()),fighter)
 impact_strength=0.0
 combat_accent.clear()

func _finish_story() -> void:
 _clear_inputs()
 voice.stop_dialogue()
 var after:=story_after
 story_after=""
 if after=="victory": _begin_victory()

func _select_fighter(style_id: String,appearance_id: String) -> void:
 var next: Dictionary=FighterRoster.resolve("fuhua",style_id,appearance_id)
 if next.is_empty(): return
 if next.styleId==fighter.styleId and next.appearanceId==fighter.appearanceId: return
 voice.clear()
 var replacement=Actor.new()
 replacement.visible=false
 add_child(replacement)
 replacement.setup(false,next)
 if not replacement.ready_for_combat:
  replacement.queue_free()
  hud.notify_text("角色载入失败，请重新选择")
  return
 appearance_choices[str(fighter.styleId)]=str(fighter.appearanceId)
 player.visible=false
 player.queue_free()
 player=replacement
 player.visible=true
 fighter=next
 appearance_choices[str(fighter.styleId)]=str(fighter.appearanceId)
 game.set_player_profile(str(fighter.style.combatProfile))
 character_preview.reset()
 _clear_inputs()
 effects.clear()
 visual_time=0.0
 _save_fighter_choice()

func _load_fighter_choice() -> void:
 var config:=ConfigFile.new()
 fighter=FighterRoster.resolve()
 appearance_choices.clear()
 var remembered: Variant={}
 var style_id: String=FighterRoster.DEFAULT_STYLE
 var skin_id: String=FighterRoster.DEFAULT_APPEARANCE
 if config.load(FIGHTER_SETTINGS)==OK:
  style_id=str(config.get_value("fighter","style",style_id))
  skin_id=str(config.get_value("fighter","appearance",skin_id))
  remembered=config.get_value("fighter","appearances",{})
 if OS.has_feature("web"):
  var saved: Variant=JavaScriptBridge.eval("(function(){try{return localStorage.getItem('taixu.fighter');}catch(e){return null;}})()",true)
  if saved is String:
   var value: Variant=JSON.parse_string(saved)
   if value is Dictionary:
    style_id=str(value.get("style",style_id))
    skin_id=str(value.get("appearance",skin_id))
    remembered=value.get("appearances",{})
 if remembered is Dictionary:
  for key in remembered:
   if not FighterRoster.resolve("fuhua",str(key),str(remembered[key])).is_empty():
    appearance_choices[str(key)]=str(remembered[key])
 var choice: Dictionary=FighterRoster.resolve("fuhua",style_id,skin_id)
 if not choice.is_empty(): fighter=choice
 appearance_choices[str(fighter.styleId)]=str(fighter.appearanceId)

func _save_fighter_choice() -> void:
 var config:=ConfigFile.new()
 config.set_value("fighter","style",fighter.styleId)
 config.set_value("fighter","appearance",fighter.appearanceId)
 config.set_value("fighter","appearances",appearance_choices)
 config.save(FIGHTER_SETTINGS)
 if OS.has_feature("web"):
  var encoded: String=JSON.stringify({"style":fighter.styleId,"appearance":fighter.appearanceId,"appearances":appearance_choices})
  JavaScriptBridge.eval("try{localStorage.setItem('taixu.fighter',"+JSON.stringify(encoded)+");}catch(e){}",true)

func _roster_snapshot() -> Dictionary:
 var styles: Array=[]
 var appearances: Array=[]
 for entry: Dictionary in FighterRoster.list_styles(str(fighter.characterId)):
  styles.append({"id":entry.id,"name":entry.name,"description":entry.description,"portraitPath":entry.get("portraitPath",""),"roleTag":entry.get("roleTag","")})
 for entry: Dictionary in FighterRoster.list_appearances(str(fighter.characterId),str(fighter.styleId)):
  appearances.append({"id":entry.id,"name":entry.name})
 return {"canSelect":campaign.phase=="menu","characterId":fighter.characterId,"styleId":fighter.styleId,"appearanceId":fighter.appearanceId,"styles":styles,"appearances":appearances}

func _sync_actors() -> void:
 for node in enemy_nodes.values():
  node.visible=false
  node.queue_free()
 enemy_nodes.clear()
 enemy_markers.clear()
 death_times.clear()
 if campaign.phase=="menu": return
 var opponent: Dictionary=SentienceProfile.selection()
 if opponent.is_empty():
  push_error("识之律者资源未能载入："+JSON.stringify(SentienceProfile.availability()))
  ready_to_play=false
  hud.set_ready(false)
  hud.notify_text("识之律者资源未能载入，请重新加载")
  return
 for foe in game.enemies:
  var actor:=Actor.new()
  add_child(actor)
  actor.setup(false,opponent)
  actor.set_enemy_style(_enemy_tint(foe),bool(foe.get("boss",false)))
  enemy_nodes[str(foe.id)]=actor
  enemy_markers[str(foe.id)]=_create_marker(actor,foe)

func _enemy_tint(foe: Dictionary) -> Color:
 var value=foe.get("tint","57bddd")
 if value is Color: return Color("57bddd") if value==Color.WHITE else value
 return Color(str(value))

func _create_marker(actor: Node3D,foe: Dictionary) -> Dictionary:
 var holder:=Node3D.new()
 actor.add_child(holder)
 holder.set_as_top_level(true)
 var title:=Label3D.new()
 title.font=_bar_font
 title.font_size=36
 title.pixel_size=0.004
 title.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 title.text=str(foe.get("name","残影"))
 title.modulate=_enemy_tint(foe).lightened(0.20)
 title.outline_size=3
 title.outline_modulate=Color("182d3f")
 title.position.y=0.16
 title.no_depth_test=true
 holder.add_child(title)
 var background:=_marker_quad(Color("162f42"),Vector2(0.78,0.045))
 holder.add_child(background)
 var fill:=_marker_quad(_enemy_tint(foe),Vector2(0.78,0.045))
 fill.position.z=0.01
 holder.add_child(fill)
 return {"holder":holder,"fill":fill,"title":title}

func _marker_quad(color: Color,size: Vector2) -> MeshInstance3D:
 var item:=MeshInstance3D.new()
 var shape:=QuadMesh.new()
 shape.size=size
 item.mesh=shape
 var material:=StandardMaterial3D.new()
 material.albedo_color=color
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
 material.no_depth_test=true
 item.material_override=material
 return item

func _event(data: Dictionary) -> void:
 data.appearanceId=str(fighter.get("appearanceId","default"))
 if is_instance_valid(voice) and voice.is_inside_tree():
  voice.set_context(_voice_context())
  voice.handle_event(data)
 combat_accent.handle_event(data)
 events.append(data)
 if events.size()>100: events.pop_front()
 if is_instance_valid(effects): effects.handle_event(data)
 if is_instance_valid(sentience_effects): sentience_effects.handle_event(data)
 var kind: String=data.type
 if kind in ["hit","ultHit"]:
  var target: Node3D=player if data.get("targetSide","")=="player" else enemy_nodes.get(str(data.get("targetId","")),null)
  var strong: bool=bool(data.get("heavy",false)) or bool(data.get("final",false))
  var direction: float=float(data.get("facing",game.player.facing if data.get("side","")=="player" else -game.player.facing))
  if is_instance_valid(target):
   target.flash()
   # A protected counter still takes chip damage, but its native weapon
   # motion continues. Do not visually recoil a hit that did not interrupt it.
   if not bool(data.get("armored",false)): target.react_impact("hit",direction,strong)
  _camera_impact(0.095 if kind=="ultHit" and strong else 0.075 if strong else 0.035,direction,0.19 if strong else 0.13)
 elif kind=="block":
  var defender: Node3D=player if data.get("targetSide","")=="player" else enemy_nodes.get(str(data.get("targetId","")),null)
  var direction: float=float(data.get("facing",1.0))
  if is_instance_valid(defender): defender.react_impact("block",direction,bool(data.get("heavy",false)))
  _camera_impact(0.035 if data.get("heavy",false) else 0.022,direction,0.12)
 elif kind=="parry":
  var defender: Node3D=player if data.get("side","")=="player" else enemy_nodes.get(str(data.get("sourceId","")),null)
  var attacker: Node3D=player if data.get("targetSide","")=="player" else enemy_nodes.get(str(data.get("targetId","")),null)
  var direction: float=float(data.get("facing",1.0))
  if is_instance_valid(defender): defender.react_impact("parry",-direction,true)
  if is_instance_valid(attacker): attacker.react_impact("hit",direction,false)
  _camera_impact(0.055,direction,0.18)
 elif kind=="reset":
  dialogue_voice.reset()
  knockout.clear()
  knockout_started=false
  knockout_pending=false
  knockout_paused=false
  boss_entrance.clear()
  end_delay=1.15
  victory.clear()
  impact_age=1.0
  impact_strength=0.0
  shake=0.0
  feel_frames.clear()
  cinematic_entry.clear()
  cinematic_frame.clear()
  cinematic_running=false
  cinematic_return_time=1.0
  cinematic_return_from.clear()
  camera_roll=0.0
  camera.fov=34.0
  if is_instance_valid(player): player.reset_presentation()
  for actor in enemy_nodes.values():
   if is_instance_valid(actor): actor.reset_presentation()
 elif kind=="ultimate":
  cinematic_player_x=float(data.x)
  cinematic_target_x=float(data.targetX)
  cinematic_facing=float(game.player.facing)
  cinematic_entry={"position":camera_base,"target":menu_target,"fov":camera.fov,"roll":camera_roll,"shot":"entry"}
  cinematic_running=true
  cinematic_return_time=1.0
 elif kind=="pause":
  # Focus loss can suspend the web frame loop before the next _process call.
  music.set_context(campaign.phase,game.paused,not game.ultimate.is_empty())
 elif kind=="enemyDown":
  var count:=0
  for foe: Dictionary in game.enemies:
   if float(foe.hp)<=0.0: count+=1
  if count==game.enemies.size() and game.player.hp>0.0:
   # Let a multi-hit native ultimate reach its actual finishing strike.
   # Its later impact cue still fires when an earlier hit killed the target.
   if game.ultimate.is_empty(): _begin_knockout("player",count)
   else: knockout_pending=true
  elif not knockout_started:
   knockout.begin({"final":false,"count":count,"total":game.enemies.size()})
 elif kind=="ultimateImpact" and bool(data.get("final",false)) and knockout_pending:
  _begin_knockout("player",game.enemies.size())
 elif kind=="end":
  # The finishing hit owns the full sequence. End may arrive later while
  # the original ultimate clip completes; it must never replay the K.O.
  _begin_knockout(str(data.get("winner","enemy")),game.enemies.size() if data.get("winner","")=="player" else 0)
  end_delay=0.0
 if not is_instance_valid(hud): return
 if kind=="parry":
  hud.notify_text("极限防御 · J 追击" if data.get("side","")=="player" else "极限防御")
 elif kind=="stanceChange":
  hud.notify_text("腿式 · 远击破势" if data.get("stance","")=="kick" else "拳式 · 近身快攻")
 elif kind=="evade": hud.notify_text("极限闪避")
 elif kind=="guardBreak":
  hud.notify_text("架势击破")
  _camera_impact(0.085,float(data.get("facing",game.player.facing)),0.22)
 elif kind=="bossPhase":
  hud.notify_text("识之律者 · 入梦！红光用闪避")
  _camera_impact(0.075,game.player.facing,0.24)
 elif kind=="attack" and data.get("weapon","")=="burst" and data.get("side","")=="enemy":
  hud.notify_text("识之律者 · 必杀！闪避红光")
 elif kind=="weaponChange" and data.get("side","")=="enemy":
  hud.notify_text(str(data.get("label","识律变招")))
 elif kind=="training": hud.notify_text("木人练习" if game.training else "实战对练")
 elif kind=="ability":
  if data.get("side","")=="player": hud.notify_text(str(fighter.get("style",{}).get("abilityName","寸劲")) if game.player_profile!="azure_empyrea" else "寸劲 · 破阵")
 elif kind=="start" and campaign.mode=="practice": hud.notify_text("自由对练")
 elif kind=="reset": end_time=0.0

func _begin_knockout(winner: String,count: int) -> void:
 if knockout_started: return
 knockout_started=true
 knockout_pending=false
 knockout_paused=false
 _clear_inputs()
 combat_accent.clear()
 knockout.begin({"final":true,"winner":winner,"count":count,"total":game.enemies.size()})

func _begin_victory() -> void:
 # Results are already committed by Campaign.finish. Replay only changes art.
 _clear_inputs()
 victory.begin()
 player.reset_presentation()
 effects.clear()
 sentience_effects.clear()
 effects.handle_event({"type":"victory","style":str(fighter.style.combatProfile),"x":0.0})
 impact_age=1.0
 impact_strength=0.0
 shake=0.0
 cinematic_running=false
 cinematic_return_time=1.0
 cinematic_return_from.clear()
 arena.set_ink_cinematic(false)

func _process(delta: float) -> void:
 if not ready_to_play: return
 var dt: float=minf(delta,0.05)
 var movement: float=touch_move
 if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): movement-=1.0
 if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): movement+=1.0
 var guard: bool=touch_guard or Input.is_physical_key_pressed(KEY_L)
 knockout.tick(dt,game.paused or knockout_paused)
 var ko_frame: Dictionary=knockout.snapshot()
 var ko_scale: float=0.0 if knockout_paused or (knockout_started and not knockout.focused) else float(ko_frame.timeScale)
 if knockout.active:
  movement=0.0
  guard=false
 var sim_before: float=game.time
 if boss_entrance.pending and not story.active: _begin_boss_entrance()
 if campaign.phase=="fight" and not story.active and not boss_entrance.active:
  if stage_countdown>0.0:
   if not game.paused: stage_countdown=maxf(0.0,stage_countdown-dt)
  else: game.update(dt*ko_scale,movement,guard)
 var sim_delta: float=game.time-sim_before
 # A KO can start inside game.update. Freeze that contact's actors and
 # particles together on the very first rendered finishing frame.
 ko_frame=knockout.snapshot()
 ko_scale=0.0 if knockout_paused or (knockout_started and not knockout.focused) else float(ko_frame.timeScale)
 var visual_dt: float=0.0 if game.paused or story.active or boss_entrance.active or campaign.phase in ["reward","cleared","failed"] else dt*ko_scale
 var finish_freeze: bool=game.ended and game.hit_stop>0.0
 visual_time+=visual_dt
 if game.ended and campaign.phase=="fight" and not story.active:
  end_time+=0.0 if finish_freeze else visual_dt
  if end_time>=end_delay and not knockout.active and not knockout_paused and knockout.focused:
   campaign.finish(game.snapshot())
   _clear_inputs()
   if campaign.phase=="cleared" and game.winner=="player":
    if campaign.mode=="trial": _begin_story("victory","victory")
    else: _begin_victory()
   elif campaign.phase=="failed" and campaign.mode=="trial": _begin_story("defeat")
 story.tick(dt)
 boss_entrance.tick(dt,game.paused)
 victory.tick(dt)
 var pf: Dictionary=game.player.duplicate(true)
 if campaign.phase=="menu":
  pf.x=1.9
  pf.facing=1
  pf.stateTime=visual_time
  pf.presentationYaw=character_preview.yaw
 elif stage_countdown>0.0:
  pf.stateTime=2.1-stage_countdown
 elif game.ended and pf.state=="dead": pf.stateTime=end_time
 var ult_time: float=game.ultimate.get("time",-1.0)
 var health_display: Dictionary=EnemyHealthDisplay.plan(game.enemies)
 arena.set_ink_cinematic(ult_time>=0.0 and game.player_profile=="azure_empyrea")
 var actor_delta: float=visual_dt if stage_countdown>0.0 or not game.started or game.ended else sim_delta
 if finish_freeze or ko_scale==0.0: actor_delta=0.0
 if victory.visible:
  player.animate_victory(victory.time)
 else:
  player.animate_fighter(pf,actor_delta,visual_time,ult_time)
 player.visible=not story.active and (not boss_entrance.active or boss_entrance.time>=BossEntrance.RETURN_AT)
 for source in game.enemies:
  var id: String=str(source.id)
  if not enemy_nodes.has(id): continue
  var actor: Node3D=enemy_nodes[id]
  var foe: Dictionary=source.duplicate(true)
  if stage_countdown>0.0:
   foe.state="idle"
   foe.stateTime=2.1-stage_countdown
  var boss_actor: bool=boss_entrance.active and id==str(game.enemy.id)
  if boss_actor: foe=boss_entrance.actor_state(source)
  if foe.hp<=0:
   death_times[id]=float(death_times.get(id,0.0))+actor_delta
   foe.stateTime=death_times[id]
   foe.state="dead"
  actor.animate_fighter(foe,(dt if not game.paused and boss_entrance.focused else 0.0) if boss_actor else actor_delta,boss_entrance.time if boss_actor else visual_time,ult_time)
  actor.visible=campaign.phase!="menu" and not victory.visible and not story.active and (foe.hp>0 or float(foe.stateTime)<actor.death_duration())
  var marker: Dictionary=enemy_markers[id]
  marker.holder.visible=id in health_display.overheadIds and campaign.phase=="fight" and not game.paused and not story.active and not boss_entrance.active and not knockout.active and ult_time<0.0
  marker.title.visible=(id==str(game.enemy.id) or bool(foe.get("boss",false))) and game.time>2.3
  marker.holder.position=Vector3(foe.x,3.20 if foe.get("boss",false) else 2.98,0.3)
  var ratio: float=clampf(float(foe.hp)/maxf(float(foe.maxHp),1.0),0,1)
  marker.fill.scale.x=maxf(0.001,ratio)
  marker.fill.position.x=(ratio-1.0)*0.39
 arena.update_arena(visual_dt,visual_time)
 effects.update_fighters(game.player,game.enemies)
 sentience_effects.update_fighters(game.player,game.enemies)
 effects.visible=not story.active
 sentience_effects.visible=not story.active
 # A contact pause freezes the action and its ink together. End/intro effects
 # still finish on the presentation clock when the simulation is not running.
 var fx_dt: float=actor_delta
 if boss_entrance.active: fx_dt=dt if not game.paused and boss_entrance.focused else 0.0
 elif victory.visible: fx_dt=dt if victory.focused and not victory.paused else 0.0
 effects.tick(fx_dt)
 sentience_effects.tick(fx_dt)
 combat_accent.tick(fx_dt)
 _camera(dt,visual_dt,ult_time)
 if ult_time>=0.0 and str(cinematic_frame.get("composition","full"))=="portrait" and not story.active and not boss_entrance.active:
  # The opening cut-in belongs to the performer. Close opponents used to
  # fill half the frame as a cropped torso; restore them at the action cut.
  for actor in enemy_nodes.values(): actor.visible=false
  sentience_effects.visible=false
 if knockout.active: camera.fov-=float(ko_frame.cameraPulse)*2.4
 combat_accent.present(camera,campaign.phase=="fight" and ult_time<0.0 and not story.active and not boss_entrance.active and not knockout.active)
 ultimate_focus.present(camera,game.player_profile,ult_time,cinematic_player_x,cinematic_target_x,campaign.phase=="fight" and not story.active and not boss_entrance.active)
 var state: Dictionary=game.snapshot()
 state.ready=ready_to_play
 state.fps=Engine.get_frames_per_second()
 state.stageCountdown=stage_countdown
 state.healthDisplay=health_display
 state.ko=ko_frame
 state.campaign=campaign.snapshot(state)
 state.campaign.storyRoute=str(story.decision.get("routeTitle",""))
 state.fighter=FighterRoster.presentation_identity(str(fighter.characterId),str(fighter.styleId),str(fighter.appearanceId))
 state.roster=_roster_snapshot()
 state.characterPreview=character_preview.snapshot()
 state.victory=victory.snapshot()
 state.story=story.snapshot()
 state.bossEntrance=boss_entrance.snapshot()
 state.victory.shot=cinematic_frame.get("shot","battle")
 voice.set_context(_voice_context())
 var spoken_line: Dictionary=state.story.duplicate()
 if story.active and story.index<story.lines.size(): spoken_line.mood=story.lines[story.index].get("mood","")
 var voice_cue: Dictionary=dialogue_voice.next(spoken_line,game.player_profile)
 if not voice_cue.is_empty(): voice.play_dialogue(voice_cue)
 # Hit-stop and cinematic slow motion never chop or pitch-shift the actor's
 # voice. Only deliberate pause / focus loss suspends its playback cursor.
 voice.tick(dt)
 state.voice=voice.snapshot()
 if music.has_method("set_voice_duck"): music.set_voice_duck(bool(state.voice.get("playing",false)))
 if music.has_method("set_encounter"): music.set_encounter(campaign.mode,campaign.stage_index,campaign.phase)
 music.set_context("menu" if story.active else campaign.phase,game.paused or knockout_paused or (victory.visible and victory.paused),ult_time>=0.0)
 music.tick(dt)
 state.music=music.snapshot()
 hud.update_status(state)
 hud.visible=not story.active and not boss_entrance.active
 state.ui=hud.presentation_snapshot()
 var player_pose: Dictionary=player.presentation_snapshot()
 var enemy_pose: Dictionary={}
 var focused_enemy: Node3D=enemy_nodes.get(str(game.enemy.id),null)
 if is_instance_valid(focused_enemy): enemy_pose=focused_enemy.presentation_snapshot()
 feel_frames.append({"frame":Engine.get_process_frames(),"simTime":game.time,"simDelta":sim_delta,"fxDelta":fx_dt,"hitStop":game.hit_stop,"playerMotion":player_pose.get("motion",""),"playerSourceTime":player_pose.get("sourceTime",0.0),"playerDefenseTime":player_pose.get("defenseTime",0.0),"playerDefensePhase":player_pose.get("defensePhase","none"),"playerDefenseWeight":player_pose.get("defenseWeight",0.0),"enemyMotion":enemy_pose.get("motion",""),"enemySourceTime":enemy_pose.get("sourceTime",0.0),"playerX":game.player.x,"enemyX":game.enemy.x,"cameraKick":shake})
 if feel_frames.size()>60: feel_frames.pop_front()
 telemetry_time+=dt
 if OS.has_feature("web") and telemetry_time>0.10:
  telemetry_time=0.0
  state.events=events
  state.vfx=effects.snapshot()
  state.vfx.sentience=sentience_effects.snapshot()
  state.feel={"player":player_pose,"enemy":enemy_pose,"cameraKick":shake,"cameraPosition":[camera.position.x,camera.position.y,camera.position.z],"fxDelta":fx_dt,"simDelta":sim_delta}
  state.feel.accent=combat_accent.snapshot()
  state.feel.ultimateFocus=ultimate_focus.snapshot()
  state.feelFrames=feel_frames
  var return_at: float=LightningCamera.return_at(game.player_profile) if game.player_profile in ["shadow_knight","hawk_of_the_fog"] else NightSquireCamera.RETURN_AT if game.player_profile=="night_squire" else FenghuangCamera.RETURN_AT if game.player_profile=="fenghuang" else UltimateCamera.RETURN_AT
  state.cinematic={"active":ult_time>=0.0,"returning":(ult_time>=return_at) or cinematic_return_time<0.28,"shot":cinematic_frame.get("shot","battle"),"fov":camera.fov,"roll":camera_roll,"position":[camera.position.x,camera.position.y,camera.position.z],"target":[menu_target.x,menu_target.y,menu_target.z],"facing":cinematic_facing}
  state.cinematic.composition=cinematic_frame.get("composition","full")
  state.engine="Godot "+Engine.get_version_info().string
  JavaScriptBridge.eval("window.__godotState="+JSON.stringify(state)+";",true)

func _voice_context() -> Dictionary:
 var boss_id:=""
 for foe: Dictionary in game.enemies:
  if bool(foe.get("boss",false)): boss_id=str(foe.id)
 return {"phase":campaign.phase,"paused":game.paused or knockout_paused or (victory.visible and victory.paused),"storyActive":story.active,"playerProfile":game.player_profile,"enemyCount":game.enemies.size(),"bossId":boss_id,"ultimateActive":not game.ultimate.is_empty()}

func _camera_impact(strength: float,direction: float,duration: float) -> void:
 # Multiple targets share one kick, rather than stacking a screen-sized shake.
 if impact_age<impact_duration and impact_strength>strength: return
 impact_age=0.0
 impact_fresh=true
 impact_strength=strength
 impact_direction=direction
 impact_duration=duration

func _camera(_dt: float,visual_dt: float,ult_time: float) -> void:
 var target:=Vector3(0,1.4,0)
 var pos:=Vector3(0,3.1,12.0)
 var aspect: float=get_viewport().get_visible_rect().size.x/maxf(get_viewport().get_visible_rect().size.y,1.0)
 if boss_entrance.active:
  cinematic_frame=boss_entrance.frame(aspect)
  camera_base=cinematic_frame.position
  menu_target=cinematic_frame.target
  camera.fov=cinematic_frame.fov
  camera_roll=0.0
  camera.position=camera_base
  camera.look_at(menu_target)
  return
 if story.active:
  cinematic_frame=story.frame(aspect)
  camera_base=cinematic_frame.position
  menu_target=cinematic_frame.target
  camera.fov=cinematic_frame.fov
  camera_roll=0.0
  camera.position=camera_base
  camera.look_at(menu_target)
  return
 if victory.visible:
  cinematic_frame=VictoryPresentation.frame(victory.time,aspect,str(fighter.styleId))
  camera_base=cinematic_frame.position
  menu_target=cinematic_frame.target
  camera.fov=cinematic_frame.fov
  camera_roll=0.0
  camera.position=camera_base
  camera.look_at(menu_target)
  return
 if campaign.phase=="menu":
  target=Vector3(0.8,1.48,0)
  pos=Vector3(0.8,1.85,maxf(7.6,2.7/(tan(deg_to_rad(camera.fov*0.5))*aspect)))
 else:
  var enemy_positions: Array=[]
  for foe in game.enemies:
   if foe.hp>0: enemy_positions.append(foe.x)
  var framing: Dictionary=BattleCamera.frame(game.player.x,enemy_positions,aspect)
  pos=framing.position
  target=framing.target
 var battle: Dictionary={"position":pos,"target":target,"fov":34.0,"roll":0.0,"shot":"battle"}
 if ult_time>=0.0:
  if game.player_profile in ["shadow_knight","hawk_of_the_fog"]:
   cinematic_frame=LightningCamera.sample(ult_time,{"playerX":cinematic_player_x,"targetX":cinematic_target_x,"facing":cinematic_facing,"aspect":aspect,"entry":cinematic_entry,"battle":battle},game.player_profile)
  elif game.player_profile=="night_squire":
   cinematic_frame=NightSquireCamera.sample(ult_time,{"playerX":cinematic_player_x,"targetX":cinematic_target_x,"facing":cinematic_facing,"aspect":aspect,"entry":cinematic_entry,"battle":battle})
  elif game.player_profile=="fenghuang":
   cinematic_frame=FenghuangCamera.sample(ult_time,{"playerX":cinematic_player_x,"targetX":cinematic_target_x,"facing":cinematic_facing,"aspect":aspect,"entry":cinematic_entry,"battle":battle})
  else:
   cinematic_frame=UltimateCamera.sample(ult_time,cinematic_player_x,cinematic_target_x,cinematic_facing,aspect,cinematic_entry,battle)
  camera_base=cinematic_frame.position
  menu_target=cinematic_frame.target
  camera.fov=cinematic_frame.fov
  camera_roll=cinematic_frame.roll
 else:
  if cinematic_running:
   cinematic_running=false
   cinematic_return_time=0.0
   cinematic_return_from={"position":camera_base,"target":menu_target,"fov":camera.fov,"roll":camera_roll,"shot":"return"}
  if cinematic_return_time<0.28:
   cinematic_return_time+=visual_dt
   cinematic_frame=UltimateCamera._blend(cinematic_return_from,battle,cinematic_return_time/0.28,"return")
   camera_base=cinematic_frame.position
   menu_target=cinematic_frame.target
   camera.fov=cinematic_frame.fov
   camera_roll=cinematic_frame.roll
  else:
   cinematic_frame=battle
   camera_base=camera_base.lerp(pos,1.0-exp(-visual_dt*7.0))
   menu_target=menu_target.lerp(target,1.0-exp(-visual_dt*9.0))
   camera.fov=34.0
   camera_roll=0.0
 if ult_time<0.0 and cinematic_return_time>=0.28 and campaign.phase=="fight":
  camera.fov-=1.4*combat_accent.amount()
 # Show the actual impulse on the first rendered contact frame, even when
 # that frame took 30–50 ms. Later recoil can settle while bodies hit-stop.
 if impact_fresh: impact_fresh=false
 else: impact_age+=visual_dt
 var progress: float=clampf(impact_age/maxf(impact_duration,0.001),0.0,1.0)
 shake=impact_strength*pow(1.0-progress,2.0)
 var kick:=Vector3(impact_direction*cos(progress*PI*1.4),sin(progress*PI*2.0)*0.18,-0.45)*shake
 camera.position=camera_base+kick
 # Translating only the eye then aiming back at the same contact point
 # cancelled almost all visible shake. Move the framing in XY with the eye.
 camera.look_at(menu_target+Vector3(kick.x,kick.y,0.0))
 camera.rotate_object_local(Vector3(0,0,1),deg_to_rad(camera_roll))

func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
  if is_instance_valid(knockout): knockout.set_focused(false)
  boss_entrance.focused=false
  victory.set_focused(false)
  if is_instance_valid(story): story.focused=false
 elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
  if is_instance_valid(knockout): knockout.set_focused(true)
  boss_entrance.focused=true
  victory.set_focused(true)
  if is_instance_valid(story): story.focused=true
 if is_instance_valid(music) and music.is_inside_tree():
  if what==NOTIFICATION_APPLICATION_FOCUS_OUT: music.set_focused(false)
  elif what==NOTIFICATION_APPLICATION_FOCUS_IN: music.set_focused(true)
 if is_instance_valid(voice) and voice.is_inside_tree():
  if what==NOTIFICATION_APPLICATION_FOCUS_OUT: voice.set_focused(false)
  elif what==NOTIFICATION_APPLICATION_FOCUS_IN: voice.set_focused(true)
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and ready_to_play and game.started and campaign.phase=="fight" and not story.active and not boss_entrance.active and not game.paused and not game.ended and not knockout.active:
  game.action("pause")
  _clear_inputs()

