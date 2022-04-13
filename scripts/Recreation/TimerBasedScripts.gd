extends Timer

onready var gameLogic = $"../"

var round_finished = false
var speed = 0.0

const MISSILE = 6
const SPLIT = 2
const BOMB_LEVEL_DELAY = 5
const PLANE_LEVEL_DELAY = 1
const SAT_LEVEL_DELAY = 2

#func doLevelOld(levelSet: String):
#	if level_start == false:
#		return
#	level_start = false #how to stop weirdness with yields and _process
#	round_finished = false
#	var currentSet = File.new()
#	if currentSet.open(levelSet, File.READ):
#		push_error("level at " + levelSet + " failed to load")
#	speed = float(currentSet.get_line())
#	waitTime = float(currentSet.get_line())
#	var currentLine
#	while currentSet.get_position() != currentSet.get_len():
#		start(waitTime)
#		yield(self, "timeout")
#		currentLine = currentSet.get_line()
#		for charInd in range(5):
#			var parseChar = ord(currentLine[charInd])
#			if parseChar < 58: #character is number
#				parseChar -= 48 #subtract 58 as digits start at 58
#			else: #character is uppercase letter
#				parseChar -= 55 #subtract 55 to make "A" 10
#			if parseChar > 35: #character is invalid, push_error and stop
#				push_error("character fell out of valid number range")
#				break
#			match charInd:
#				0:
#					for _number in range(parseChar):
#						gameLogic.fireEnemy(speed)
#				1:
#					for _number in range(parseChar):
#						gameLogic.fireEnemy(speed, int(rand_range(175,275)))
#				2:
#					for _number in range(parseChar):
#						gameLogic.fireBomb(speed)
#				3:
#					for _number in range(parseChar):
#						gameLogic.fireBomber(speed, int(rand_range(50,150)), 1 if rand_range(0,1) > 0.5 else -1, 0)
#				4:
#					for _number in range(parseChar):
#						gameLogic.fireBomber(speed, int(rand_range(50,150)), 1 if rand_range(0,1) > 0.5 else -1, 0)
#	round_finished = true

func _process(_delta):
	if gameLogic.gameMode == "PlayStartLevel":
		doLevel( #fix this asap
			float(gameLogic.levelNum)/10, #speed
			.15/(float(gameLogic.levelNum)/10), #time between volleys
			gameLogic.levelNum * MISSILE, #normal missiles
			gameLogic.levelNum * SPLIT, #splitting missiles
			gameLogic.levelNum - BOMB_LEVEL_DELAY if gameLogic.levelNum > BOMB_LEVEL_DELAY else 0, #smart bombs (start at level 6)
			gameLogic.levelNum - PLANE_LEVEL_DELAY if gameLogic.levelNum > PLANE_LEVEL_DELAY else 0, #bombers (start at level 2)
			gameLogic.levelNum - SAT_LEVEL_DELAY if gameLogic.levelNum > SAT_LEVEL_DELAY else 0 #satellites (start at level 3)
		)
		gameLogic.gameMode = "PlayPersist"

func doLevel(newSpeed: float = 0.1, waitTime: float = 1.0, normal: int = 0, split: int = 0, smart: int = 0, plane: int = 0, satellite: int = 0):
	round_finished = false
	speed = newSpeed
	while normal > 0 or split > 0 or smart > 0 or plane > 0 or satellite > 0:
		start(waitTime)
		yield(self, "timeout")
		if normal > 0:
			gameLogic.fireEnemy(speed)
			gameLogic.fireEnemy(speed)
			gameLogic.fireEnemy(speed)
			normal -= 3
		if split > 0:
			gameLogic.fireEnemy(speed, int(rand_range(175,275)))
			split -= 1
		if smart > 0:
			gameLogic.fireBomb(speed)
			smart -= 1
		if plane > 0:
			gameLogic.fireBomber(speed, int(rand_range(50,150)), 1 if rand_range(0,1) > 0.5 else -1, 0)
			plane -= 1
		if satellite > 0:
			gameLogic.fireBomber(speed, int(rand_range(50,150)), 1 if rand_range(0,1) > 0.5 else -1, 0)
			satellite -= 1
	round_finished = true

func doInfo():
	gameLogic.HUD.get_node("InfoLabel/InfoLabelData").text = (
		"        1" +
		"\n\n\n" +
		str(round(float(gameLogic.levelNum)/2)) +
		"         "
	)
	gameLogic.HUD.get_node("InfoLabel").show()
	gameLogic.HUD.get_node("CoinLabel").hide()
	gameLogic.HUD.get_node("AlphaLabel").show()
	gameLogic.HUD.get_node("DeltaLabel").show()
	gameLogic.HUD.get_node("OmegaLabel").show()
	gameLogic.HUD.get_node("PlayerScore").show()
	gameLogic.HUD.get_node("HighScore").hide()
	gameLogic.HUD.get_node("TitleText").hide()
	gameLogic.Silos.ammo = [10,10,10]
	start(1.5)
	yield(self, "timeout")
	gameLogic.HUD.get_node("InfoLabel").hide()
	gameLogic.gameMode = "PlayStart"
