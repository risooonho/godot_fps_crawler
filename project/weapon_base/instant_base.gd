
extends "projectile_abstract.gd"

const SPLIT_STEP=PI/64

onready var ray=get_node("direction/RayCast")
onready var direction=get_node("direction")
var subrays=[]

onready var explosion_class=null

var power=1
var velocity=Vector3()

func set_owner(value):
	.set_owner(value)
	power=5
	ray.add_exception_rid(owner)

func shoot():
	var special=false
	if explosion_class != null and randi()%data.get_modifier("attack.elemental_chance") ==0 :
		special=true
	
	_shoot_ray(ray,special)
	for r in subrays:
		_shoot_ray(r,special)
	
	return true

func _shoot_ray(r,special):
	if r.is_colliding():
		var object=r.get_collider()
		var p=r.get_collision_point()
		if object.has_method("hit"):
			object.hit(self,special)
		var instance=bullet_factory.get_impact()  
		instance.set_translation(p)
		owner.get_parent_spatial().add_child(instance)
		if special :
			var explosion=explosion_class.instance()
			explosion.owner=owner
			var t=Transform()
			t.origin=p
			explosion.set_transform(t)
			explosion.rescale(0.2*data.get_modifier("attack.size"))
			owner.get_parent_spatial().add_child(explosion)

func reset():
	explosion_class=bullet_factory.get_impact_explosion_class(data.get_modifier("attack.elemental_impact"))
	var i=subrays.size()

	var is_right=true
	var delta_angle=-i/2*SPLIT_STEP

	while i<data.get_modifier("attack.split_factor"):
		if is_right:
			delta_angle=-delta_angle+SPLIT_STEP
		else:
			delta_angle=-delta_angle
		is_right=!is_right
		
		var r=RayCast.new()
		subrays.append(r)
		i+=1
		r.set_cast_to(Vector3(0,0,-1000))
		r.set_enabled(true)
		r.add_exception_rid(owner)
		direction.add_child(r)
		r.rotate_y(delta_angle)

	if data.get_modifier("attack.autoaim") or data.get_modifier("projectile.homing"):
		set_process(true)
	else:
		set_process(false)
		direction.set_transform(Transform())

func _process(delta):
	if owner.current_target!=null:
		var t=direction.get_global_transform()
		direction.set_global_transform(t.looking_at(owner.current_target.get_global_transform().origin,Vector3(0,1,0)))
	else:
		direction.set_transform(Transform())