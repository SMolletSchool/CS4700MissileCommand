extends Node2D

var speed = 0.5
var ready = false
var facing = 1
var ready_to_boom = false
var clear_me = false
var deploy_timer = 66
var type = 0

const SCREEN_SIZE = 256

func _process(_delta):
	if ready:
		match type:
			0:
				$Bomber/Area2D.monitoring = 1
				$Bomber.show()
			1:
				$Satellite/Area2D.monitoring = 1
				$Satellite.show()
		show()
		position += Vector2(speed*facing,0)
		if deploy_timer != -1:
			if deploy_timer > 0:
				deploy_timer -= 1
		if position.x > SCREEN_SIZE+10 and facing == 1 or position.x < -10 and facing == -1: #looks cleaner to have offsets offscreen
			clear_me = true

func Bomber_Hit(_area):
	ready_to_boom = true