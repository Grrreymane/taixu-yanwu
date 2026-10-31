extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const STEP:=1.0/60.0
class Volatile extends "res://scripts/campaign.gd":
 func _load_record() -> void: pass
 func _save_record() -> void: pass
func _initialize() -> void:
 var rows: Array=[]
 for legacy: bool in [true,false]:
  for profile: String in ["azure_empyrea","fenghuang","night_squire","shadow_knight","hawk_of_the_fog"]:
   for policy: String in ["j_only","reactive"]:
    for seed_value in [3103,42,105,888]:
     var c:=Volatile.new()
     c.begin_trial("mirror",seed_value)
     if legacy:
      c.run_rules_version=c.LEGACY_RULES_VERSION
      c.stages=c._make_stages(true)
     var stages: Array=[]
     while c.phase=="fight":
      var game:=Combat.new()
      game.set_player_profile(profile)
      game.start_encounter(c.encounter(),c.combat_carry())
      var frames:=0
      while not game.ended and frames<3600:
       var distance: float=absf(game.enemy.x-game.player.x)
       var movement: float=signf(game.enemy.x-game.player.x) if distance>1.18 else 0.0
       var guard:=false
       var dodge:=false
       if policy=="reactive":
        for foe: Dictionary in game.enemies:
         if foe.hp<=0 or foe.state!="attack" or absf(foe.x-game.player.x)>float(foe.attack.range)+0.4: continue
         var until: float=foe.attack.windup-foe.stateTime
         if until>=-0.02 and until<0.10:
          if foe.attack.unblockable: dodge=true
          else: guard=true
        if dodge: game.action("dodge")
        elif guard: game.action("guard")
       if not guard and not dodge:
        if game.player.state in ["idle","move","guard"]:
         if policy=="reactive" and game.player.energy>=100 and game.ultimate.is_empty(): game.action("ultimate")
         elif policy=="reactive" and game.player.skillCooldown<=0 and distance<2.2: game.action("ability")
         elif distance<1.65: game.action("light")
        elif game.player.state=="attack": game.action("light")
       game.update(STEP,movement,guard)
       frames+=1
      c.finish(game.snapshot())
      stages.append({"stage":c.stage_index+1,"winner":game.winner,"hp":game.player.hp,"damageTaken":game.stats.damageTaken,"parries":game.stats.parries,"dodges":game.stats.dodges,"seconds":frames*STEP})
      if c.phase=="reward":
       var pick:=0
       for index in c.reward_options.size():
        var id: String=c.reward_options[index].id
        if c.carry.hp<50 and id in ["breath","calm","reflection"]: pick=index; break
        if id in ["fist","iron","finisher","chainflow","crack"]: pick=index
       c.choose_reward(pick)
      elif c.phase!="cleared": break
     rows.append({"legacy":legacy,"profile":profile,"policy":policy,"seed":seed_value,"cleared":c.phase=="cleared","stages":stages,"rewards":c.reward_ids.duplicate()})
 FileAccess.open("res://build/reports/replay-run-audit.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 for legacy: bool in [true,false]:
  for policy: String in ["j_only","reactive"]:
   var cases: Array=rows.filter(func(row): return row.legacy==legacy and row.policy==policy)
   print(JSON.stringify({"legacy":legacy,"policy":policy,"runs":cases.size(),"clears":cases.filter(func(row): return row.cleared).size(),"averageStage":cases.reduce(func(total,row): return total+row.stages.size(),0.0)/cases.size(),"averageDamage":cases.reduce(func(total,row): return total+row.stages.reduce(func(damage,stage): return damage+stage.damageTaken,0.0),0.0)/cases.size()}))
 quit()
