extends Node2D


onready var HUD := $HUDAndTitleScreen
onready var Player := $CanvasLayer2/PlayerCrosshair
onready var Earth := $EarthHolder
onready var Cities := $EarthHolder/CityHolder
onready var Silos := $EarthHolder/SiloHolder
onready var TimedVars := $GeneralTimer

var gameMode = "Menu"
var highscoreTable := {}
var scoreTotal = 0
var score = 0
var targetArray = []
var missileDict = {}
var smartBombDict = {}
var explosionDict = {}
var bomberDict = {}
var madDict = {}
var stored_cities = 0
var bonus_minimum = 5000
var levelNum := 1
var levelColors = {"enemyAndHud": "dfff0000", "player": "df0022ff", "ground": "ffc600", "background": "000000"} #Enemy (and HUD) color, Player color, Ground color, Background color
var variantMode = false


const SCREEN_WIDTH = 256.0
const SPLIT_DIFFERENCE = 0.3
const E_NATURAL = 2.71828182846

onready var playerMissile := preload("res://scenes/PlayerMissile.tscn")
onready var enemyMissile := preload("res://scenes/EnemyMissile.tscn")
onready var smartBomb := preload("res://scenes/SmartBomb.tscn")
onready var enemyBomber := preload("res://scenes/Bomber.tscn")
onready var targetPointer := preload("res://scenes/TargetGraphic.tscn")
onready var missileTrail := preload("res://scenes/MissileTrail.tscn")
onready var explosionScene := preload("res://scenes/Explosion.tscn")
onready var popupLabel := preload("res://scenes/PopupLabel.tscn")

onready var madBossFight := preload("res://scenes/MAD.tscn")

#func readHighScoreTable():
#	var table = File.new()
#	var currentline
#	if table.file_exists("user://highscore.csv"):
#		table.open("user://highscore.csv", File.READ)
#		while table.get_position() != table.get_len():
#			currentline = table.get_csv_line()
#			highscoreTable[currentline[0]] = int(currentline[1])
#	else:
#		table.open("user://highscore.csv", File.WRITE)
#		table.store_csv_line(["SOL", "7500"])
#		highscoreTable["SOL"] = 7500
#	table.close()

func doTrail():
	for missile in missileDict:
		missileDict[missile][0].set_point_position(1, missile.global_position)

func explosion(exPosition: Vector2, group: String = "Neutral"):
	var newExplosion = explosionScene.instance()
	add_child(newExplosion)
	newExplosion.add_to_group(group)
	newExplosion.position = exPosition
	explosionDict[newExplosion] = [newExplosion.position, newExplosion.scale]

func checkMissileState(empty: bool = false) -> bool:
	var newMissileDict = missileDict.duplicate(true)
	for missile in missileDict:
		if missile.ready_to_boom or missile.clear_me or empty:
			if missile.ready_to_boom:
				if missile.is_in_group("Player"):
					explosion(missile.global_position, "Player")
				else:
					if missile.reason == "Player":
						explosion(missile.global_position, "Player")
						score += 25*round(float(levelNum)/2)
						if missile.split_timer > 0:
							score += 2*(25*round(float(levelNum)/2))
					else:
						explosion(missile.global_position)
			newMissileDict.erase(missile)
			missileDict[missile][0].queue_free()
			if missileDict[missile].size() == 2 and typeof(missileDict[missile][1]) != TYPE_INT:
				missileDict[missile][1].queue_free()
			missile.queue_free()
		if missile.split_timer == 0:
			fireEnemy($GeneralTimer.speed, -1, missile.position,  newMissileDict)
			fireEnemy($GeneralTimer.speed, -1, missile.position,  newMissileDict)
	missileDict = newMissileDict.duplicate(true)
	if missileDict.size() == 0:
		return false
	return true

func checkSmartBombState(empty: bool = false) -> bool:
	var newSmartBombDict = smartBombDict.duplicate()
	for bomb in smartBombDict:
		if bomb.ready_to_boom or bomb.clear_me or empty:
			if bomb.ready_to_boom:
				if bomb.reason == "Player":
					explosion(bomb.global_position, "Player")
					score += 25*round(float(levelNum)/2)
				else:
					explosion(bomb.global_position)
			newSmartBombDict.erase(bomb)
			bomb.queue_free()
		else:
			bomb.explosions = explosionDict
			newSmartBombDict[bomb] = bomb.position
	smartBombDict = newSmartBombDict.duplicate()
	if smartBombDict.size() == 0:
		return false
	return true

func checkBomberState(empty: bool = false) -> bool:
	var newBomberDict = bomberDict.duplicate()
	for bomber in bomberDict:
		if bomber.ready_to_boom or bomber.clear_me or empty:
			if bomber.ready_to_boom:
				if bomber.reason == "Player":
					explosion(bomber.global_position, "Player")
					score += 25*round(float(levelNum)/2)
				else:
					explosion(bomber.global_position)
			newBomberDict.erase(bomber)
			bomber.queue_free()
		if bomber.deploy_timer == 0:
			fireEnemy($GeneralTimer.speed, -1, bomber.position, missileDict)
			bomber.deploy_timer = int(rand_range(60,140))
	bomberDict = newBomberDict.duplicate()
	if bomberDict.size() == 0:
		return false
	return true

func checkMADState(empty: bool = false) -> bool:
	var newMADDict = madDict.duplicate()
	for mad in madDict:
		if mad.ready_to_boom or empty:
			if mad.ready_to_boom:
				score += 250*round(float(levelNum)/2)
			newMADDict.erase(mad)
			mad.queue_free()
			TimedVars.boss_finished = true
		if mad.state == "Idle" and rand_range(0, max(-log(levelNum) + E_NATURAL, 0.01)) < 0.02 and mad.shoot_timer < 1:
			mad.get_node("FireWeapon").play()
			var chooseWeapon = rand_range(0, max(-log(levelNum) + E_NATURAL, 0.02))
			if chooseWeapon > 0 and chooseWeapon < 0.015:
				fireSmartBomb(0.1)
			else:
				fireEnemy(
					$GeneralTimer.speed,
					int(rand_range(-1, 100)),
					Vector2(
						mad.global_position.x + 6 + rand_range(-5, 5), #screen position + middle of sprite + random shift
						mad.global_position.y + 5 #screen position + the bottom of the sprite
					),
					missileDict
				)
			mad.shoot_timer = rand_range(1, max(12 * (-log(levelNum) + E_NATURAL), 4))
		if mad.state == "Hit_1" and rand_range(0, max(-log(levelNum) + E_NATURAL, 0.01)) < 0.02 and mad.call_timer < 1:
			for _a in range(levelNum):
				fireBomber(float(levelNum)/10, 100, 1 if rand_range(0,1) > 0.5 else -1, 1 if rand_range(0,1) > 0.5 else 0)
			mad.call_timer = rand_range(1, 25*(-log(levelNum) + E_NATURAL))
	madDict = newMADDict.duplicate()
	if madDict.size() == 0:
		return false
	return true

func checkExplosionState(empty: bool = false) -> bool:
	var newExplosionDict = explosionDict.duplicate(true)
	for explosion in explosionDict:
		newExplosionDict[explosion][1] = explosion.scale
		if explosion.finished or empty:
			newExplosionDict.erase(explosion)
			explosion.queue_free()
	explosionDict = newExplosionDict.duplicate(true)
	if explosionDict.size() == 0:
		return false
	return true

func fire(baseID: int):
	var newTarget = targetPointer.instance()
	add_child(newTarget)
	newTarget.position = Player.global_position
	var newMissile = playerMissile.instance()
	add_child(newMissile)
	newMissile.add_to_group("Player")
	match baseID:
		0:
			newMissile.global_position = Vector2(20,206)
		1:
			newMissile.global_position = Vector2(124,206)
			newMissile.fast = true
		2:
			newMissile.global_position = Vector2(240,206)
	var newTrail = missileTrail.instance()
	add_child(newTrail)
	newTrail.default_color = Color(levelColors.player)
	newTrail.add_point(newMissile.global_position)
	newTrail.add_point(newMissile.global_position)
	newMissile.angle = newMissile.get_angle_to(Player.global_position)
	newMissile.target = Player.global_position
	newMissile.ready = true
	missileDict[newMissile] = [newTrail, newTarget]

func pickRandomTarget(accuracy: float = 0):
	accuracy = clamp(accuracy, 0, 10) #stops weird stuff:tm:
	var target_picked = targetArray[int(rand_range(0,9))]
	return Vector2(target_picked.x + rand_range(-10+accuracy,10-accuracy), target_picked.y)

func fireEnemy(speed: float = 0.3, split: int = -1, start_location: Vector2 = Vector2(-1,-1),  dictionary: Dictionary = missileDict):
	var newMissile = enemyMissile.instance()
	add_child(newMissile)
	newMissile.global_position = Vector2(rand_range(0,1)*SCREEN_WIDTH, 0)
	newMissile.split_timer = split
	newMissile.speed = speed
	newMissile.angle = newMissile.get_angle_to(pickRandomTarget(speed))
	if start_location != Vector2(-1,-1):
		newMissile.global_position = start_location
		newMissile.angle += rand_range(-SPLIT_DIFFERENCE, SPLIT_DIFFERENCE)
	var newTrail = missileTrail.instance()
	add_child(newTrail)
	newTrail.default_color = Color(levelColors.enemyAndHud)
	newTrail.add_point(newMissile.global_position)
	newTrail.add_point(newMissile.global_position)
	newMissile.ready = true
	dictionary[newMissile] = [newTrail, split]

func fireSmartBomb(speed: float = 0.3, start_location: Vector2 = Vector2(-1,-1)):
	var newBomb = smartBomb.instance()
	add_child(newBomb)
	newBomb.global_position = start_location
	if start_location == Vector2(-1, -1):
		newBomb.global_position = Vector2(rand_range(0,1)*SCREEN_WIDTH, 0)
	newBomb.speed = speed
	newBomb.target = pickRandomTarget(10)
	newBomb.ready = true
	smartBombDict[newBomb] = newBomb.position

func fireBomber(speed: float = 0.3, fire_timer: int = 66, facing: int = 1, type: int = 1):
	var newBomber = enemyBomber.instance()
	add_child(newBomber)
	newBomber.speed = speed
	newBomber.deploy_timer = fire_timer
	newBomber.facing = facing
	newBomber.type = type
	newBomber.global_position = Vector2(SCREEN_WIDTH, int(rand_range(50,130))) if facing == -1 else Vector2(0, int(rand_range(50,130)))
	newBomber.scale.x = facing
	bomberDict[newBomber] = newBomber.position
	newBomber.ready = true

func fireMAD():
	var newMad = madBossFight.instance()
	add_child(newMad)
	newMad.health = float(levelNum)
	newMad.health_start = float(levelNum)
	HUD.get_node("BossHealthBar").max_value = float(levelNum)
	HUD.get_node("BossHealthBar").value = float(levelNum)
	newMad.position = Vector2((SCREEN_WIDTH/2)-11, -30)
	newMad.state = "Intro"
	madDict[newMad] = newMad.position

func checkForLife() -> int:
	return int(Cities.cities[0]) + int(Cities.cities[1]) + int(Cities.cities[2]) + int(Cities.cities[3]) + int(Cities.cities[4]) + int(Cities.cities[5])

func checkForAmmo() -> bool:
	return Silos.ammo[0] > 0 or Silos.ammo[1] > 0 or Silos.ammo[2] > 0

func doResultsScreen():
	if checkExplosionState(true):
		push_error("Explosion persisted after game end")
	if checkMissileState(true):
		push_error("Missile persisted after game end")
	if checkBomberState(true):
		push_error("Bomber/Satellite persisted and game end")
	if checkSmartBombState(true):
		push_error("Smart Bomb persisted and game end")
	TimedVars.levelEnd()
	gameMode = "ResultsWait"

func doEndScreen():
	HUD.get_node("InfoLabel").text = "FINAL SCORE:"
	HUD.get_node("InfoLabel/InfoLabelData").text = "\n\n" + str(scoreTotal + score)
	TimedVars.gameEnd()
	HUD.get_node("InfoLabel").show()
	gameMode = "GameOverWait"

func updateSiloCounts():
	HUD.get_node("AlphaLabel").text = ""
	HUD.get_node("DeltaLabel").text = ""
	HUD.get_node("OmegaLabel").text = ""
	if Silos.ammo[0] < 4:
		HUD.get_node("AlphaLabel").text = "LOW"
	if Silos.ammo[0] == 0:
		HUD.get_node("AlphaLabel").text = "OUT"
		if variantMode:
			HUD.get_node("AlphaLabel").text = "REL"
	if Silos.ammo[1] < 4:
		HUD.get_node("DeltaLabel").text = "LOW"
	if Silos.ammo[1] == 0:
		HUD.get_node("DeltaLabel").text = "OUT"
		if variantMode:
			HUD.get_node("DeltaLabel").text = "REL"
	if Silos.ammo[2] < 4:
		HUD.get_node("OmegaLabel").text = "LOW"
	if Silos.ammo[2] == 0:
		HUD.get_node("OmegaLabel").text = "OUT"
		if variantMode:
			HUD.get_node("OmegaLabel").text = "REL"

func doGame():
	if Input.is_action_just_pressed("fire_alpha"):
		if Silos.ammo[0] > 0 and Silos.baseState[0] == "Ready":
			Silos.ammo[0] -= 1
			Silos.get_node("SiloAlpha").frame = 10 - Silos.ammo[0]
			fire(0)
			if Silos.ammo[0] == 3:
				Silos.get_node("SiloAlpha/Low").play()
			else:
				Silos.get_node("SiloAlpha/Fire").play()
		elif Silos.ammo[1] == 0:
			Silos.get_node("SiloAlpha/Empty").play()
	if Input.is_action_just_pressed("fire_delta"):
		if Silos.ammo[1] > 0 and Silos.baseState[1] == "Ready":
			Silos.ammo[1] -= 1
			Silos.get_node("SiloDelta").frame = 10 - Silos.ammo[1]
			fire(1)
			if Silos.ammo[1] == 3:
				Silos.get_node("SiloDelta/Low").play()
			else:
				Silos.get_node("SiloDelta/Fire").play()
		elif Silos.ammo[1] == 0:
			Silos.get_node("SiloDelta/Empty").play()
	if Input.is_action_just_pressed("fire_omega"):
		if Silos.ammo[2] > 0 and Silos.baseState[2] == "Ready":
			Silos.ammo[2] -= 1
			Silos.get_node("SiloOmega").frame = 10 - Silos.ammo[2]
			fire(2)
			if Silos.ammo[2] == 3:
				Silos.get_node("SiloOmega/Low").play()
			else:
				Silos.get_node("SiloOmega/Fire").play()
		elif Silos.ammo[2] == 0:
			Silos.get_node("SiloOmega/Empty").play()
	if variantMode:
		if Input.is_action_pressed("reload_alpha"):
			Silos.reload(0, checkForLife())
		else:
			Silos.baseState[0] = "Ready"
		if Input.is_action_pressed("reload_delta"):
			Silos.reload(1, checkForLife())
		else:
			Silos.baseState[1] = "Ready"
		if Input.is_action_pressed("reload_omega"):
			Silos.reload(2, checkForLife())
		else:
			Silos.baseState[2] = "Ready"
	updateSiloCounts()
	doTrail()
	var currentState = 0
	currentState += int(checkMissileState())
	currentState += int(checkSmartBombState())
	currentState += int(checkBomberState())
	currentState += int(checkExplosionState())
	currentState += int(checkMADState())
	HUD.get_node("PlayerScore").text = str(scoreTotal + score)
	HUD.get_node("PlayerScore").show()
	if currentState == 0 and TimedVars.round_finished and TimedVars.boss_finished:
		if checkForLife():
			gameMode = "Results"
		else:
			gameMode = "GameOver"

func buildDefaults() -> void:
	gameMode = "Menu"
	highscoreTable = {}
	scoreTotal = 0
	score = 0
	targetArray = []
	missileDict = {}
	smartBombDict = {}
	explosionDict = {}
	bomberDict = {}
	madDict = {}
	stored_cities = 0
	levelNum = 1
	levelColors = {"enemyAndHud": "dfff0000", "player": "df0022ff", "ground": "ffc600", "background": "000000"}
	Cities.cities = [true, true, true, true, true, true]
	Silos.ammo = [10,10,10]
	Silos.ammoReloadTimer = [0.0,0.0,0.0]
	Silos.baseState = ["Ready","Ready","Ready"]
	targetArray = [
		Cities.get_node("L3").global_position,
		Cities.get_node("L2").global_position,
		Cities.get_node("L1").global_position,
		Cities.get_node("R1").global_position,
		Cities.get_node("R2").global_position,
		Cities.get_node("R3").global_position,
		Silos.get_node("SiloAlpha").global_position,
		Silos.get_node("SiloDelta").global_position,
		Silos.get_node("SiloOmega").global_position
	]

func _ready():
	buildDefaults()
	
	HUD.get_node("PlayerScore").hide()
	HUD.get_node("HighScore").hide()
	HUD.get_node("InfoLabel").hide()
	HUD.get_node("TitleText").show()
	HUD.get_node("VariantSwitch").show()
	HUD.get_node("ControlSwitch").show()
	HUD.get_node("BossHealthBar").hide()
	HUD.get_node("VariantBonus").hide()

func _physics_process(_delta):
	if gameMode == "Menu":
		HUD.get_node("TitleText/TitleTextVar").set_text("CLASSIC MODE")
		if variantMode:
			HUD.get_node("TitleText/TitleTextVar").set_text("M.A.D. MODE")
		if Input.is_action_pressed("start"):
			gameMode = "InfoScreen"
	if gameMode == "InfoScreen":
		$GeneralTimer.doInfo()
		gameMode = "InfoScreenWait"
	if gameMode == "InfoStart":
		$GeneralTimer.doRoundStart()
		gameMode = "InfoWait"
	if gameMode == "PlayPersist" or gameMode == "PlayStartLevel": #do this first to make sure that timer script will activate on next frame
		doGame()
	if gameMode == "PlayStart":
		Player.show()
		gameMode = "PlayStartLevel"
	if gameMode == "Results":
		doResultsScreen()
	if gameMode == "GameOver":
		doEndScreen()
	if gameMode == "Reset":
		if get_tree().reload_current_scene():
			push_error("scene failed to reload")

func Report_Omega(_area):
	HUD.get_node("OmegaLabel").text = "OUT"
	Silos.get_node("SiloOmega").frame = 10


func Report_Delta(_area):
	HUD.get_node("DeltaLabel").text = "OUT"
	Silos.get_node("SiloDelta").frame = 10


func Report_Alpha(_area):
	HUD.get_node("AlphaLabel").text = "OUT"
	Silos.get_node("SiloAlpha").frame = 10


func VariantSwitch(button_pressed):
	if button_pressed:
		variantMode = true
		bonus_minimum = 0
	else:
		variantMode = false
		bonus_minimum = 5000
	buildDefaults()


func ControlSwitch(button_pressed):
	if button_pressed:
		Player.mode = 1
	else:
		Player.mode = 0
	buildDefaults()
