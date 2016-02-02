extends RigidBody

const ANGULAR_SPEED=4
const VELOCITY_MAX=10
const VELOCITY_ACCEL=0.05
const TARGET_DISTANCE=4
const SHOOT_RECHARGE_TIME=1
const MAX_LIFE=100
const WAYPOINT_ERROR_DELTA=1
const WAYPOINT_MAX_TIMEOUT=5

var going_backward=false
var aiming_at_target=false
var target_ray=null
var collision_ray=null
var current_target=null
var player=null
var action_timeout=0
var can_see_target=false
var remaining_shots=0
var current_direction=Vector3()
var current_waypoint=null
var current_path=null
var distance_to_collision=0
var alive=true
var no_move=false
var hit_quotas=Dictionary()
var waypoint_timeout=0

var m = FixedMaterial.new()

var navmesh=null

const random_angle_a=float(355284801)/float(256000000)

var aim_offset=Vector3()

var life=MAX_LIFE
var current_action={
	name="",
	shoot=false,
	move=true,
	follow_target=false
}


# original -----------
const walk_speed = 3;
const max_accel = 0.02;
const air_accel = 0.05;

var is_moving = false;
var on_floor = false;

func _ready():
	m.set_line_width(3)
	m.set_point_size(3)
	m.set_fixed_flag(FixedMaterial.FLAG_USE_POINT_SIZE, true)
	m.set_flag(Material.FLAG_UNSHADED, true)
	
	
	# Initialization here
	player=get_parent().get_node("player")
	target_ray=get_node("target_ray")
	target_ray.add_exception_rid(get_rid())
	#collision_ray=get_node("collision_ray")
	#collision_ray.add_exception_rid(get_rid())
	
	for n in get_tree().get_nodes_in_group("npc-wall"):
		target_ray.add_exception_rid(n.get_rid())
		


func _integrate_forces(state):
	if not alive:
		return
	
	if target_ray.is_colliding():
		distance_to_collision=(target_ray.get_collision_point()-target_ray.get_global_transform().origin).length()
	else:
		distance_to_collision=-1
	
	var yaw_t=get_node("yaw").get_global_transform()
	if current_target!=null:
		# target ray
		if target_ray.is_colliding() and target_ray.get_collider()==current_target:
			# target in sight
			can_see_target=true
		else:
			can_see_target=false
		
		var target_transform=target_ray.get_global_transform().looking_at(current_target.get_global_transform().origin+current_target.aim_offset,Vector3(0,1,0)).orthonormalized()
		target_ray.set_global_transform(target_transform)
		if not current_target.alive:
			current_target=player
	else:
		can_see_target=false
		var target_transform=yaw_t.looking_at(player.get_global_transform().origin+player.aim_offset,Vector3(0,1,0)).orthonormalized()
		target_ray.set_rotation(Vector3(0,0,0))
		var v=target_transform.basis.z-yaw_t.basis.z
		if v.length()<0.53:
			current_target=player
	
	if action_timeout<=0 and remaining_shots<=0:
		change_action(state)
	else:
		action_timeout-=state.get_step()
	
	if current_waypoint!=null:
		if get_translation().distance_to(current_waypoint)<WAYPOINT_ERROR_DELTA or waypoint_timeout<=0:
			calculate_destination()
		else:
			waypoint_timeout-=state.get_step()

	#if not get_node("yaw/floor_ray").is_colliding():
	#	avoid_fall()

	
	do_current_action(state)
	

func do_current_action(state):
	var current_t=get_node("yaw").get_global_transform()
	var current_z=current_t.basis.z
	
	var aim = get_node("yaw").get_global_transform().basis;
	var direction = Vector3();
	is_moving = false;
	
	# moving
	if current_action.move and not no_move:
		#move forward
		direction -= aim[2];
		is_moving = true;
	
	direction = direction.normalized();
	
	var ray = get_node("leg_ray");
	if ray.is_colliding():
		var up = state.get_total_gravity().normalized();
		var normal = ray.get_collision_normal();
		var floor_velocity = Vector3();
		
		var speed = walk_speed;
		var diff = floor_velocity + direction * walk_speed - state.get_linear_velocity();
		var vertdiff = aim[1] * diff.dot(aim[1]);
		diff -= vertdiff;
		diff = diff.normalized() * clamp(diff.length(), 0, max_accel / state.get_step());
		diff += vertdiff;
		apply_impulse(Vector3(), diff * get_mass());
		
		on_floor = true;
	else:
		apply_impulse(Vector3(), direction * air_accel * get_mass());
		
		on_floor = false;
	
	# set rotation

	var target_z
	if current_action.follow_target:
		target_z=target_ray.get_global_transform().basis.z
	else:
		if current_waypoint!=null:
			var tt=current_t.looking_at(current_waypoint+current_target.aim_offset,Vector3(0,1,0))
			target_z=tt.basis.z
		else:
			target_z=current_direction
	
	var vx=Vector2(current_z.x,current_z.z).angle_to(Vector2(target_z.x,target_z.z))
	
	aiming_at_target=(abs(vx)<0.3)
	 
	if not aiming_at_target:
		vx=sign(vx)
	
		
	
	state.set_angular_velocity(Vector3(0,vx*ANGULAR_SPEED,0))
	state.integrate_forces();
	var vel_speed=state.get_linear_velocity().length()/walk_speed;
	
	var speed=state.get_angular_velocity().length()*0.1+vel_speed;
	get_node("yaw/Escarabajo").set_walk_speed(speed)

func calculate_destination():
	if current_target!=null and navmesh!=null:
		if current_waypoint==null or (current_waypoint-get_translation()).length()<WAYPOINT_ERROR_DELTA or waypoint_timeout<=0:
			_update_waypoint()
		
		current_direction=get_global_transform().looking_at(current_waypoint+current_target.aim_offset,Vector3(0,1,0)).orthonormalized().basis.z
	else:
		current_direction=get_global_transform().basis.z
	
		var angle_x=randf()*PI
		var y=random_angle_a/(angle_x+0.3926875)-0.3426875
		if y<0.17:
			y=0
		else:
			if randi()%2==1:
				y=-y
		var angle_diff=y
		
		current_direction=current_direction.rotated(Vector3(0,1,0),angle_diff)

func change_action(state):
	if current_target==null:
		if randi()%3==0:
			create_move_action(state)
		else:
			create_sleep_action()
	else:
		if can_see_target and get_translation().distance_to(current_target.get_global_transform().origin)<TARGET_DISTANCE:
			create_attack_target_action()
		else:
			create_move_action(state)

func create_sleep_action():
	current_action={
		name="sleep",
		shoot=false,
		move=false,
		follow_target=false
	}
	action_timeout=0.2

func create_move_action(state):
	calculate_destination()
	current_action={
		name="move",
		shoot=false,
		move=true,
		follow_target=false
	}
	action_timeout=2

func create_attack_target_action():
	current_action={
		name="attack",
		shoot=true,
		move=false,
		follow_target=true
	}
	action_timeout=2

func hit(source):
	
	if alive:
		life=life-20
		if life<=0:
			# die
			die()
		else:
			# hurt
			create_sleep_action()
	
	var culprit=source.owner
	if culprit!=current_target:
		if culprit in hit_quotas:
			hit_quotas[culprit]+=source.power
			if hit_quotas[culprit]>MAX_LIFE/4:
				current_target=culprit
				hit_quotas.clear()
		else:
			if current_target==null:
				print(get_name()," attaqued by ",culprit.get_name())
				current_target=culprit
			else:
				hit_quotas[culprit]=source.power

func avoid_fall():
	var t=get_global_transform()
	var salt=(randi()%3)-1
	current_direction=current_direction.rotated(Vector3(0,1,0),PI+salt*PI/2)
	action_timeout=1

func die():
	#set_mode(MODE_RIGID) # set ragdoll mode
	set_use_custom_integrator(false)
	alive=false

func _update_waypoint():
	var begin=navmesh.get_closest_point(get_translation())
	var end=navmesh.get_closest_point(current_target.get_global_transform().origin)
	var p=navmesh.get_simple_path(begin,end, true)
	
	var path=Array(p)
	
	if current_path==null or current_path.size()<3:
		current_path=path
		current_waypoint=path[1]
	else:
		#remove begin and end
		path.pop_back()
		path.pop_front()
		path.invert()
		var found=false
		while not path.empty() and not found:
			var wpt=path[0]
			path.pop_front()
			for wpt_ref in current_path:
				if wpt_ref.distance_to(wpt)==0:
					found=true
					break
		
		if found:
			current_path.pop_front()
			current_waypoint=current_path[1]
		else:
			current_path=Array(p)
			current_waypoint=current_path[1]
	
	#var im = navmesh.get_node("draw")
	#im.set_material_override(m)
	#im.clear()
	#im.begin(Mesh.PRIMITIVE_POINTS, null)
	#im.add_vertex(begin)
	#im.add_vertex(end)
	#im.end()
	#im.begin(Mesh.PRIMITIVE_LINE_STRIP, null)
	#for x in p:
	#	im.add_vertex(x)
	#im.end()
	
	waypoint_timeout=WAYPOINT_MAX_TIMEOUT
