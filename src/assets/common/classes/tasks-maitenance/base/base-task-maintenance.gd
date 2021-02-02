extends Node
class_name BaseMaintenanceTask

"""
To create a maintenance task:
	1. write a script that inherrits this script, and implement the required methods:
		* update(delta) the only optinal func to inherit. gets called periodicaly to run your task logic
			@delta can be 0.1ms or 2 seconds(in order to preserve bandwidth)
			it is determened by the timer in maintenancetask.tscn
				+ wait time no peers is the update interval(in seconds) when no one on the network has a gui open
				+ wait time peers is the update interwal when at least one person on the network has the gui open
		* these are supposed to be called by your update(delta) when appropriate
		  but I haven't figured out how to properly implement them
		  perhaps the best thing would be to override them for custom behaviour
		  and to call the base class, so the call can propagate to the network
			* output_low
			* output_high
			* output_low_critical
			* output_high_critical
		
		* get_update_gui_dict() -> Dictionary
			@return a dict that your gui script will parse in order to update its contents
		 
		* _handle_input_from_gui(_new_input_data: Dictionary)
			@_new_input_data when the user of your gui clicks some buttons
			this function will get called so you can act upon it.
			You choose what the dict is going to contain in your gui script
================
	2. IMPORTANT Set the just created script as the script for the instanced maintenancetask.tscn
================
	
	3. Create a scene that represents your gui,
		and create a script that inherits BaseMaintenanceTaskGui.
		Override the required methods:
			*update_gui(params: Dictionary)
			@params the parameters that are generated in get_update_gui_dict()
		
			* When the user has changed their input data, call 
			backend.input_from_gui(_new_input_data: Dictionary)
			it handles the networking stuff, and calls the
			_handle_input_from_gui(_new_input_data: Dictionary) method,
			that you overwrote in your child of BaseMaintenanceTask
			
			
------------------------------

So, to create the GasValve task that NiceMicro made:
	1. add an empty node on the map(this is so the standbutton becomes visible)
	2. instance src/assets/maps/interactables/maintenancetask/maintenancetask.tscn
		as the child of the empty node(ideally there should be one empty node for all the tasks)
	3. set Frontend Menu Name to the one set in UIManager.ui_list
	4. IMPORTANT: Load the following script:
		src/assets/common/classes/tasks-maintenance/taskgass.gd
		to be the script of the node you created in step 2.
	5. UIManager.ui_list already contains the required entry to activate the gastask ui
		"gasvalve": {"scene": preload("res://assets/ui/tasks/gasvalve/gasvalve.tscn")}
		but when writing your own task, you would add your own tscn)
"""
# the name of the gui that should represent this task to the user
# as defined in UIManager.menus
export var frontendMenuName: String

# used in regular tasks to make them able to complete
# only when our output is nominal
# name it the same as frontend name for simplicity
var taskName: String = frontendMenuName
func get_task_name() -> String:
	#return taskName
	return frontendMenuName
	
var frontend

# peers that have opened a gui on their end
var peers = Array()

func register_gui(gui) -> bool:
	# only assign a gui if we don't already have a gui
	if frontend == null:
		frontend = gui
		# tell the server we have opened a gui
		rpc_id(1, "_register_peer", Network.get_my_id())
			
	# if the gui was previously assigned, the below expression will be false
	return frontend == gui

func unregister_gui(gui):
	if frontend == gui:
		frontend = null
		# tell the server we have closed a gui
		rpc_id(1, "_unregister_peer", Network.get_my_id())

master func _register_peer(caller_id: int):
	var peer_id = get_tree().get_rpc_sender_id()
	if caller_id != peer_id:
		return
	
	if peers.has(peer_id):
		# only one peer is allowed
		return 
		
	peers.append(peer_id)
	$Timer.set_has_peers(true)
	$Timer.start()
		
master func _unregister_peer(caller_id: int):
	var peer_id = get_tree().get_rpc_sender_id()
	if caller_id != peer_id:
		return
	
	peers.erase(peer_id)
	if peers.empty():
		# no peers left, no need to waste processing power and network bandwidth
		$Timer.set_has_peers(false)
	
var last_timer_fire: float

func _ready():
	set_network_master(1)
	
	# Make sure that the ui menu name exists
	assert(UIManager.is_ui_name_valid(self.frontendMenuName))
	#warning-ignore:return_value_discarded
	MapManager.connect("interacted_with", self, "interacted_with")
	
	# only the server should start the timer
	if Network.is_network_master():
		# timer is used to save processing power,
		# no need to update tasks every frame
		#warning-ignore:return_value_discarded
		$Timer.connect("timeout", self, "_timer_update")
	
	# TODO make this wait for the idle frame, so that the child
	# of this class gets constructed, so that taskName gets populated
	#yield(somethng)
	TaskManager.register_potential_task_dependency(self)
	
func interacted_with(interactNode, _from, _interact_data):
	if interactNode != self:
		return
	UIManager.open_ui(self.frontendMenuName, {"linkedNode": self})
	
master func input_from_gui(new_input_data: Dictionary):
	if not Network.is_network_master():
		rpc_id(1, "input_from_gui", new_input_data)
		return
	_handle_input_from_gui(new_input_data)
	
"""
The child class calls this method.
This method should display a warning to the user
"""
puppet func output_low():
	if Network.is_network_master():
		rpc("output_low")
	
puppet func output_high():
	if Network.is_network_master():
		rpc("output_high")
	
puppet func output_low_critical():
	if Network.is_network_master():
		rpc("output_low_critical")
		
puppet func output_high_critical():
	if Network.is_network_master():
		rpc("output_high_critical")
	
func _timer_update():
	if not Network.is_network_master():
		return
	var current_time = OS.get_ticks_msec()
	var delta = (current_time - last_timer_fire) / 1000
	last_timer_fire = current_time
	update(delta)
	if not peers.empty():
		rpc("_update_gui", get_update_gui_dict())
	
puppetsync func _update_gui(gui_update_dict: Dictionary):
	if frontend != null:
		frontend.update_gui(gui_update_dict)

# All of the logic goes into this method
# the $Timer calls this if we are the server
func update(_delta):
	# Never can be called on base class
	# Did you forget to assign the script to the maintenance task scene instance?
	assert(false) 
	pass
	
func get_update_gui_dict():
	# Never can be called on base class
	# Did you forget to assign the script to the maintenance task scene instance?
	assert(false)
	return {}
	
func _handle_input_from_gui(_new_input_data: Dictionary):
	# Never can be called on base class
	# Did you forget to assign the script to the maintenance task scene instance?
	assert(false)
	pass
	
# called by the regular tasks to check if this task's values are in the nominal range
# player_id can be the player trying to complete the regular task, or
# TaskManager.GLOBAL_TASK_PLAYER_ID, in case the global task is being completed
func is_complete(player_id):
	# Never can be called on base class
	# Did you forget to assign the script to the maintenance task scene instance?
	assert(false)
	pass

# maintenance tasks are global by default, but the taskmanager needs all tasks
# that can be dependant on to implement this method
func is_task_global() -> bool:
	return true
