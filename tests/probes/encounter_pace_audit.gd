extends SceneTree
## Fixed seed, ordinary offensive inputs, no defense. Records repeatable
## behavior evidence; does not pretend these simple bots model skilled play.
const Combat=preload("res://scripts/combat.gd")
const STEP:=1.0/60.0
class VolatileCampaign extends "res://scripts/campaign.gd":
	func _load_record() -> void:pass
	func _save_record() -> void:pass
func _initialize() -> void:
	var campaign:=VolatileCampaign.new()
	campaign.begin_trial("mirror",3103)
	var rows: Array=[]
	for profile: String in ["azure_empyrea","fenghuang","night_squire"]:
		for policy: String in ["j_only","all_offense"]:
			for stage in campaign.stages.size():
				var game=Combat.new();game.set_player_profile(profile)
				game.start_encounter(campaign.stages[stage],campaign.carry)
				var attacks: Array=[]
				var contacts: Array=[]
				var reactions: Array=[]
				game.event.connect(func(data: Dictionary):
					if data.type=="attack" and data.side=="enemy":attacks.append({"time":game.time,"id":data.sourceId})
					if data.type=="hit" and data.side=="enemy":contacts.append({"time":game.time,"id":data.sourceId})
					if data.get("counter",false):reactions.append(data.duplicate(true)))
				var wall_time:=0.0
				for frame in 2400:
					if game.ended:break
					var distance: float=absf(game.enemy.x-game.player.x)
					var movement: float=signf(game.enemy.x-game.player.x) if distance>1.18 else 0.0
					if game.player.state in ["idle","move","guard"]:
						if policy=="all_offense" and game.player.energy>=100.0 and game.ultimate.is_empty():game.action("ultimate")
						elif policy=="all_offense" and game.player.skillCooldown<=0.0 and distance<2.0:game.action("ability")
						elif distance<1.65:game.action("light")
					elif game.player.state=="attack":game.action("light")
					game.update(STEP,movement)
					wall_time+=STEP
				rows.append({"profile":profile,"policy":policy,"stage":stage+1,"wallTime":wall_time,"simTime":game.time,"winner":game.winner,"enemyAttacks":attacks.size(),"enemyContacts":contacts.size(),"damageTaken":game.stats.damageTaken,"damageDealt":game.stats.damageDealt,"kills":game.stats.kills,"enemyIdsAttacking":attacks.map(func(item):return item.id),"remainingHp":game.player.hp,"reactions":reactions})
				for connection in game.event.get_connections():game.event.disconnect(connection.callable)
	var result={"seed":3103,"scope":"Isolated default stages; 40s cap; ordinary J/move or Q/E/J/move; no guard, dodge or reactive strategy.","rows":rows}
	var suffix: String="after" if "--after" in OS.get_cmdline_user_args() else "before"
	FileAccess.open("res://build/reports/encounter-pace-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	for profile: String in ["azure_empyrea","fenghuang","night_squire"]:
		for policy: String in ["j_only","all_offense"]:
			var cases: Array=rows.filter(func(row):return row.profile==profile and row.policy==policy)
			print(JSON.stringify({"profile":profile,"policy":policy,"stageWins":cases.filter(func(row):return row.winner=="player").size(),"untouchedWins":cases.filter(func(row):return row.winner=="player" and row.damageTaken==0.0).size(),"totalEnemyContacts":cases.reduce(func(total,row):return total+row.enemyContacts,0),"seconds":cases.map(func(row):return snappedf(row.wallTime,0.1))}))
	quit()
