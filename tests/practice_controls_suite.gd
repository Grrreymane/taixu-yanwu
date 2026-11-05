extends "res://tests/practice_builds_suite.gd"
const Combat=preload("res://scripts/combat.gd")
const Rules=preload("res://scripts/armor_mechanics.gd")
const Night=preload("res://scripts/night_paths.gd")

func _run() -> void:
 _energy()
 _costs()
 _patterns()
 await _settings_flow()
 print(JSON.stringify({"suite":"practice_controls","checks":checks,"passed":failures.is_empty(),"failures":failures}))
 quit(0 if failures.is_empty() else 1)

func _energy() -> void:
 for style in Paths.STYLES:
  var g=Combat.new();g.set_player_profile(style);g.start_sparring();g.set_training(true);g.set_infinite_hp(true)
  g.player.energy=0;g.set_infinite_energy(true)
  _check(g.player.energy==100,"enabling immediately refills SP: "+style)
  for attempt in 2:
   _check(g.action("ultimate"),"repeat ultimate can start: %s %d"%[style,attempt])
   _check(g.player.energy==100 and g.infinite_energy,"activation keeps SP full")
   var original:Dictionary=g.ultimate.duplicate(true)
   _check(not g.action("ultimate") and g.ultimate==original,"SP does not allow cancelling a running ultimate")
   for i in 125:
    g.update(0.1)
    _check(g.player.energy==100,"SP stays full throughout activation, burst and recovery")
    if style=="night_squire" and g.ultimate.is_empty() and g.player.nightBurstRemaining>0:
     _check(not g.action("ultimate"),"White Night burst cannot be restarted before its natural end")
   _check(g.ultimate.is_empty() and g.player.state=="idle","ultimate retains its authored end")
  g.set_infinite_energy(false)
  _check(g.action("ultimate") and g.player.energy==0,"turning off restores normal ultimate cost: "+style)
  g.set_infinite_energy(true)
  _check(g.player.energy==100 and not g.ultimate.is_empty(),"mid-ultimate toggle refills SP without interrupting animation")
  g.start_sparring("chain")
  _check(g.infinite_energy and g.infinite_hp and g.training,"sparring restart retains all test toggles")
  g.start_encounter({"enemies":[{"hp":300.0}]},{"energy":40.0})
  g.set_infinite_energy(true);g.spend_energy(10.0)
  _check(not g.infinite_energy and g.player.energy==30,"trial rejects infinite SP and restores spending")

func _costs() -> void:
 for enabled in [false,true]:
  var g=Combat.new();g.set_player_profile("shadow_knight");g.start_sparring();g.set_training(true);g.set_infinite_energy(enabled)
  Paths.setup(g.player,"mo_heavy",["mo_follow"]);g.player.armorState.chaseUntil=2.0
  var attack:Dictionary={"name":"ability"};Rules.prepare(g,attack)
  _check(g.player.energy==(100.0 if enabled else 90.0) and g.player.armorState.chaseUntil<0,"chase consumes its ticket in both modes, SP only when finite")
  Paths.setup(g.player,"mo_eclipse",[]);g.player.energy=100;g.player.eclipseRemaining=5.0
  attack={"name":"ability","hitIndex":2,"hitWindows":[0.1,0.2,0.3]}
  Rules.contact(g,attack,g.enemy)
  _check(g.player.energy==(100.0 if enabled else 85.0) and g.player.eclipseRemaining==7.0,"eclipse extension still happens when SP is unlimited")
  for i in 8:Rules.contact(g,{"name":"ability","hitIndex":2,"hitWindows":[0.1,0.2,0.3]},g.enemy)
  _check(g.player.armorState.eclipseAdded==6.0,"unlimited SP does not remove per-burst extension cap")
  g=Combat.new();g.set_player_profile("hawk_of_the_fog");g.start_sparring();g.set_training(true);g.set_infinite_energy(enabled)
  Paths.setup(g.player,"fo_flash",[]);g.player.skillCooldown=8.0
  Rules.contact(g,{"name":"heavy","fogLink":true,"fogCharges":1},g.enemy)
  _check(g.player.energy==(100.0 if enabled else 90.0) and g.player.skillCooldown==0,"fog SP refund link still consumes its normal cost when finite")

func _patterns() -> void:
 for pattern in Night.BOSS:
  var g=Combat.new();g.start_sparring(pattern);g.set_infinite_hp(true)
  _check(g.enemy.bossPattern==pattern and g.enemy.weaponCycle==Night.BOSS[pattern].cycle,"practice receives actual trial kit: "+pattern)
  var signature_seen:=false
  # The real AI must approach and begin its signature weapon without a fixture attack.
  for i in 720:
   g.update(1.0/120.0)
   if g.enemy.state=="attack":
    signature_seen=g.enemy.attack.weapon==pattern
    break
  _check(signature_seen,"AI initiates selected pattern: "+pattern)
  g.set_training(true);g.enemy.aiRound=1;g.enemy.phase=1
  g._sentience_attack(g.enemy,"light",1 if pattern=="sword" else 0,false)
  if pattern=="sword":
   g.enemy.stateTime=g.enemy.attack.duration-0.005;g._advance_fighter(g.enemy,0.01)
   _check(g.enemy.state=="dodge" and g.enemy.dodgeDirection==-g.enemy.facing,"sword retains authored retreat")
  elif pattern=="spear":
   _check(g.enemy.attack.nativeNext==-1,"first-phase spear leaves a single-thrust opening")
   g.enemy.attack.contactOutcome="miss";g.enemy.stateTime=g.enemy.attack.duration-0.005;g._advance_fighter(g.enemy,0.01)
   _check(g.enemy.punishUntil>=g.time+0.84,"missed spear exposes the real punish window")
  else:
   _check(g.enemy.attack.nativeNext==1,"chain has two linked sweeps")
   g._sentience_attack(g.enemy,"light",1,false)
   _check(g.enemy.attack.unblockable and g.enemy.attack.motion=="senti_chain_2","second sweep retains native motion and red warning")
  g.enemy.phase=2;g.enemy.aiRound=5;g._sentience_attack(g.enemy,"light",0,false)
  _check(g.enemy.attack.weapon=="burst" and g.enemy.attack.unblockable,"pattern keeps second-phase ultimate")

func _settings_flow() -> void:
 var prefs=Builds.new();prefs.restore_settings({"infiniteEnergy":"yes","enemyPattern":"missing"})
 _check(prefs.settings()=={"infiniteEnergy":false,"enemyPattern":"sword"},"malformed settings fall back safely")
 var world=PracticeMain.new();world.campaign=VolatileCampaign.new();root.add_child(world);world.set_process(false)
 world._action("trial");world._action("night_core:az_yang");world._action("story_skip");world._action("menu")
 var checkpoint:Dictionary=world.campaign.resume_data.duplicate(true)
 world._action("practice");world._action("training");world._action("practice_infinite_hp")
 _open(world,"az_yin",["az_fracture"]);world._action("practice_build_apply")
 _frames(world,1);world.hud._infinite_energy_button.grab_focus();_key(world,KEY_SPACE)
 _check(world.game.infinite_energy and world.game.player.state=="idle","keyboard toggle does not trigger an unwanted dodge")
 world._action("ultimate")
 _check(world.game.player.energy==100 and not world.game.ultimate.is_empty(),"main live toggle feeds real ultimate")
 _open(world,"az_yin");world._action("practice_enemy:chain")
 world._action("practice_build_cancel")
 _check(world.game.enemy.bossPattern=="sword" and not world.game.ultimate.is_empty(),"cancel preserves old boss, energy and active cinematic")
 for pattern in Night.BOSS:
  world._action("practice_build");world._action("practice_enemy:"+pattern)
  world._action("practice_enemy:unknown")
  _check(world.practice_view.enemyPattern==pattern,"invalid pattern cannot replace valid draft")
  world._action("practice_build_apply")
  _check(world.game.enemy.bossPattern==pattern and world.game.enemy.phase==1 and world.game.enemy.aiRound==0,"pattern switch starts clean opening")
  _check(world.game.ultimate.is_empty() and not world.cinematic_running and not world.knockout.active,"switch clears cinematic and KO states")
  _check(world.game.player.armorCore=="az_yin" and world.game.player.armorPerks.has("az_fracture"),"pattern switch preserves active core and perks")
  _check(world.game.training and world.game.infinite_hp and world.game.infinite_energy,"pattern switch retains all practice toggles")
  _check(world.campaign.resume_data==checkpoint,"pattern switch cannot alter trial checkpoint")
  world._action("ultimate")
 world._action("practice_build");world._action("practice_build_apply")
 world.game.enemy.hp=0;world.game.enemy.state="dead";world.game._check_end()
 world._action("practice_infinite_energy")
 _check(not world.game.infinite_energy and world.knockout.active,"energy can switch during KO without cancelling it")
 world._action("practice_build");world._action("practice_enemy:spear");world._action("practice_build_apply")
 _check(world.game.enemy.bossPattern=="spear" and not world.game.ended and not world.game.infinite_energy,"new pattern clears KO and keeps finite SP setting")
 world._action("practice_infinite_energy")
 prefs.restore_settings(JSON.parse_string(JSON.stringify(world.practice_builds.settings())))
 _check(prefs.infinite_energy and prefs.enemy_pattern=="spear","global settings serialize independently of armor")
 world._action("menu");world._action("select_style:night_squire");world._action("practice")
 _check(world.game.infinite_energy and world.game.enemy.bossPattern=="spear","changing armor retains energy and opponent preference")
 world._action("menu");world._action("continue");world._action("story_skip")
 world._action("practice_infinite_energy");world._action("practice_enemy:chain")
 _check(not world.game.infinite_energy and world.game.player.armorCore=="az_yang","practice settings never enable trial cheats")
 world.free();await process_frame;await process_frame
