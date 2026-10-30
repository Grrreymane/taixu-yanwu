extends "res://tests/victory_presentation_suite.gd"
const Combat=preload("res://scripts/combat.gd")
class PracticeMain extends "res://scripts/main.gd":
 func _load_fighter_choice() -> void: fighter=FighterRoster.resolve()
 func _save_fighter_choice() -> void: pass
func _run() -> void:
 _clock_contract()
 _health_contract()
 await _buttons_contract()
 print(JSON.stringify({"suite":"practice_fixes","checks":checks,"passed":failures.is_empty(),"failures":failures}))
 quit(0 if failures.is_empty() else 1)
func _advance(game,seconds:float) -> void:
 for i in ceili(seconds*120.0):game.update(1.0/120.0)
func _health_contract() -> void:
 for profile in ["azure_empyrea","fenghuang","night_squire","shadow_knight","hawk_of_the_fog"]:
  var game=Combat.new();game.set_player_profile(profile);game.start_sparring();game.set_training(true)
  game.player.hp=10;game.enemy.hp=10;game.set_infinite_hp(true)
  _check(game.player.hp==game.player.maxHp and game.enemy.hp==game.enemy.maxHp,"toggle refills both sides: "+profile)
  game.player.x=-0.6;game.enemy.x=0.6
  game.action("ultimate");_advance(game,5.0)
  _check(game.player.hp==game.player.maxHp and game.enemy.hp==game.enemy.maxHp and not game.ended,"ultimate cannot kill either side: "+profile)
  if profile=="shadow_knight":game.player.lightningHits=2;game.player.eclipseRemaining=5.0
  var dealt:float=game.stats.damageDealt
  game._state(game.enemy,"idle");game._receive(game.player,game.enemy,Combat.HEAVY.duplicate())
  _check(game.enemy.hp==game.enemy.maxHp and game.stats.damageDealt>dealt and game.hit_stop>0.0,"heavy/discharge preserves contact feedback: "+profile)
  game._state(game.player,"idle");game._receive(game.enemy,game.player,Combat.HEAVY.duplicate())
  _check(game.player.hp==game.player.maxHp and game.stats.damageTaken>0 and game.player.state=="stagger","incoming hit keeps stagger and damage feedback: "+profile)
  game.start_sparring();_check(game.infinite_hp,"sparring restart retains option")
  game.set_infinite_hp(false);game._receive(game.enemy,game.player,Combat.HEAVY.duplicate())
  _check(game.player.hp<game.player.maxHp,"turning off restores damage")
  game.set_infinite_hp(true);game.start_encounter({"enemies":[{"hp":100.0}]});game.set_infinite_hp(true)
  _check(not game.infinite_hp,"campaign cannot enable practice-only health")
 var boss=Combat.new();boss.start_sparring();boss.set_infinite_hp(true)
 boss._take_health(boss.enemy,boss.enemy.maxHp*0.6);boss._check_boss_phase(boss.enemy)
 _check(boss.enemy.phase==2 and boss.enemy.hp==boss.enemy.maxHp,"infinite health still permits the boss second phase and ultimate")
func _click(world,button:Button) -> void:
 var point:Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
 var motion=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
 var press=InputEventMouseButton.new();press.position=point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press,true)
 # This reproduces the bug: the results update several times during a click.
 _frames(world,8)
 await process_frame
 var release=press.duplicate();release.pressed=false;root.push_input(release,true)
 await process_frame
func _buttons_contract() -> void:
 root.size=Vector2i(1440,900)
 var world=PracticeMain.new();world.campaign=VolatileCampaign.new();root.add_child(world);world.set_process(false)
 for mode in ["practice","trial"]:
  for name in ["VictoryReplay","VictoryAgain","VictoryMenu","VictoryOtherMode"]:
   world._action("menu");world._action(mode)
   if mode=="trial":world.campaign.stage_index=world.campaign.stages.size()-1;world._begin_encounter(false)
   _finish_fixture(world,true);world.victory.skip();_frames(world,2)
   await process_frame
   var button:Button=world.hud._result_panel.get_node(name)
   _check(button.is_visible_in_tree(),mode+" result button visible: "+name)
   var plays:int=world.victory.plays
   await _click(world,button)
   if name=="VictoryReplay":_check(world.victory.plays==plays+1 and world.victory.playing(),mode+" replay button activates across UI refresh")
   elif name=="VictoryMenu":_check(world.campaign.phase=="menu" and not world.victory.visible,mode+" return-home button activates across UI refresh")
   else:
    _check(world.campaign.phase=="fight" and not world.victory.visible,mode+" result navigation activates: "+name)
    _check(world.campaign.mode==(mode if name=="VictoryAgain" else "trial" if mode=="practice" else "practice"),"result navigates to correct mode")
 world._action("menu");world._action("practice");_finish_fixture(world,true);world.victory.skip();world.victory.set_focused(false);world.victory.set_focused(true);_frames(world,2)
 _check(not world.victory.paused and world.hud._result_again.is_visible_in_tree(),"finished result remains operable after tab focus change")
 world.free();await process_frame
