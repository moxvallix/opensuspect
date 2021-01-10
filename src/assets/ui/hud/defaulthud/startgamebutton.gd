extends Button
# warning-ignore:unused_signal
signal gamestartpressed


# Called when the node enters the scene tree for the first time.
func _ready():
	if not Network.connection == Network.Connection.CLIENT_SERVER:
		queue_free()
	GameManager.connect('state_changed', self, '_on_state_changed')


func _pressed():
	print("game start triggered")
	# TODO: Looser coupling here would be nice
	if GameManager.get_state() == GameManager.State.Lobby:
# warning-ignore:return_value_discarded
		GameManager.transition(GameManager.State.Normal)
	else:
# warning-ignore:return_value_discarded
		GameManager.transition(GameManager.State.Lobby)
	#queue_free()

func _on_state_changed(old_state, new_state) -> void:
	match new_state:
		GameManager.State.Normal:
			text = tr("Back to Lobby")
		GameManager.State.Lobby:
			text = tr("Start Game")
