extends Node3D

var number_of_region_cards = 77
var number_of_sanctuary_cards = 53

var region_card_size = Vector3(3, 3, 0)
var sanctuary_card_size = Vector3(1.9, 2.9, 0)

var card_ids: Array[int] = []

var region_card_scene = preload("res://scenes/region.tscn")
var sanctuary_card_scene = preload("res://scenes/sanctuary.tscn")

@onready var camera: Camera3D = %Camera
@onready var bg: MeshInstance3D = %Background

@export var debug: bool = true

@export var train_data_size = 1800
@export var val_data_size = 600
@export var test_data_size = 600

@export var card_space_size: Vector3 = Vector3(17.77, 10, 3)	
@export var card_rotation_limits: Vector3 = Vector3(45, 10, 45)

@export var max_cards = 16

var data_type = "train"
var data_size = {}

@export var wait_time = 0.15
var current_time = -5
var current_image = 1
var finished = false

enum CardType {
	REGION,
	SANCTUARY,
}

func draw_debug_sphere(location, size, color = Color.RED):
	var scene_root = get_tree().root.get_children()[0]
	var sphere = SphereMesh.new()
	sphere.radial_segments = 4
	sphere.rings = 4
	sphere.radius = size
	sphere.height = size * 2
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.flags_unshaded = true
	sphere.surface_set_material(0, material)
	var node = MeshInstance3D.new()
	node.mesh = sphere
	node.global_transform.origin = location
	scene_root.add_child(node)

func position_camera():
	var rng = RandomNumberGenerator.new()
	
	var aabb = get_aabb()
	var objectHeight = aabb.size.y
	var objectWidth = aabb.size.x
	var screen_size = get_viewport().get_size()
	var aspect = screen_size.x / float(screen_size.y)
	objectHeight = max(objectHeight, objectWidth / aspect)
	var distance = objectHeight / tan(deg_to_rad(camera.fov / 2.0)) / 2
	distance += aabb.size.z / 2
	
	# somewhat arbitrary values, chosen based on what looks good
	var z = rng.randf_range(1.02, 1.3)
	
	if debug:
		draw_debug_sphere(aabb.position, 0.1, Color.GREEN)
		draw_debug_sphere(aabb.position + aabb.size, 0.1, Color.GREEN)
	
	camera.position = Vector3(0, 0, distance * z) + aabb.position + aabb.size / 2
	camera.look_at(aabb.position + aabb.size / 2)

func get_aabb():
	var nw = Vector2(0, 0)
	var se = Vector2(0, 0)
	var aabb = AABB(Vector3.ZERO, Vector3.ZERO)
	for i in range(len(card_ids)):
		var id = card_ids[i]
		var card: Sprite3D = %Cards.get_child(i)
		if i == 0:
			aabb.position = card.position
		if get_card_type(id) == CardType.REGION:
			aabb = aabb.merge(get_card_aabb(i, region_card_size))
		else:
			aabb = aabb.merge(get_card_aabb(i, sanctuary_card_size))
	return aabb

func get_card_type(id: int) -> CardType:
	if id < number_of_region_cards:
		return CardType.REGION
	return CardType.SANCTUARY

func get_card_index_from_id(id: int) -> int:
	if id < number_of_region_cards:
		return id + 1
	return id - number_of_region_cards + 1

func get_bounding_boxes(yolo_format = true):
	var boxes = []
	for i in range(len(card_ids)):
		var id = card_ids[i]
		var card: Sprite3D = %Cards.get_child(i)
		if get_card_type(id) == CardType.REGION:
			boxes.append(bounding_box(i, region_card_size, yolo_format))
		else:
			boxes.append(bounding_box(i, sanctuary_card_size, yolo_format))
	return boxes

func convert_to_yolo(size, box):
	var dw = 1./size[0]
	var dh = 1./size[1]
	var x = (box[0] + box[1])/2.0
	var y = (box[2] + box[3])/2.0
	var w = box[1] - box[0]
	var h = box[3] - box[2]
	x = x*dw
	w = w*dw
	y = y*dh
	h = h*dh
	return [x,y,w,h]

func get_card_edges(index, card_size):
	var width = card_size.x / 2
	var height = card_size.y / 2
	var edges = [Vector3(width, height, 0), Vector3(-width, height, 0), Vector3(width, -height, 0), Vector3(-width, -height, 0)]
	var global_edges: Array[Vector3] = []
	for pos in edges:
		var card: Sprite3D = %Cards.get_child(index)
		var global_pos = card.to_global(pos)
		global_edges.append(global_pos)
	return global_edges

func get_card_aabb(index, card_size):
	var edges = get_card_edges(index, card_size)
	var min: Vector3 = edges[0]
	var max: Vector3 = edges[0]
	for pos in edges:
		min.x = min(min.x, pos.x)
		min.y = min(min.y, pos.y)
		min.z = min(min.z, pos.z)
		max.x = max(max.x, pos.x)
		max.y = max(max.y, pos.y)
		max.z = max(max.z, pos.z)
	var aabb = AABB(min, max - min)
	if debug:
		draw_debug_sphere(min, 0.1, Color.BLUE)
		draw_debug_sphere(max, 0.1, Color.BLUE)
	return aabb

func bounding_box(index, card_size, yolo_format = true):
	var edges = get_card_edges(index, card_size)
	var projected_edges: Array[Vector2] = []
	for pos in edges:
		projected_edges.append(camera.unproject_position(pos))
		if debug:
			draw_debug_sphere(pos, 0.1)
	var box = [projected_edges[0].x, projected_edges[0].x, projected_edges[0].y, projected_edges[0].y]
	for pos in projected_edges:
		box[0] = min(box[0], pos.x)
		box[2] = min(box[2], pos.y)
		box[1] = max(box[1], pos.x)
		box[3] = max(box[3], pos.y)
	if yolo_format:
		var size = get_viewport().get_size()
		return convert_to_yolo([size.x, size.y], box)
	return box

func randomize_cards():
	var rng = RandomNumberGenerator.new()
	while %Cards.get_child_count() > 0:
		var card: Sprite3D = %Cards.get_child(0)
		%Cards.remove_child(card)
		card.queue_free()
	var cards: Array[int] = []
	var card_count = rng.randi_range(0, max_cards)
	for i in range(card_count):
		var id = rng.randi_range(0, number_of_region_cards + number_of_sanctuary_cards - 1)
		cards.append(id)
		if get_card_type(id) == CardType.REGION:
			%Cards.add_child(region_card_scene.instantiate())
		else:
			%Cards.add_child(sanctuary_card_scene.instantiate())
		# TODO: randomize position and rotation
		var card: Card = %Cards.get_child(i)
		card.set_card(get_card_index_from_id(id))
		card.position.x = rng.randf_range(0, card_space_size.x)
		card.position.y = rng.randf_range(0, card_space_size.y)
		card.position.z = rng.randf_range(0, card_space_size.z)
		card.rotate_x(rng.randf_range(-card_rotation_limits.x, card_rotation_limits.x) / 180 * PI)
		card.rotate_y(rng.randf_range(-card_rotation_limits.y, card_rotation_limits.y) / 180 * PI)
		card.rotate_z(rng.randf_range(-card_rotation_limits.z, card_rotation_limits.z) / 180 * PI)
	return cards

func get_named_bounding_boxes():
	var boxes = get_bounding_boxes()
	var named_boxes = []
	for i in range(len(card_ids)):
		var id = card_ids[i]
		var card: Sprite3D = %Cards.get_child(i)
		named_boxes.append([id, boxes[i]])
	return named_boxes

func save_bounding_boxes(boxes):
	var text = ""
	
	for box in boxes:
		var class_id = box[0]
		var v1 = box[1][0]
		var v2 = box[1][1]
		var v3 = box[1][2]
		var v4 = box[1][3]
		text += "{0} {1} {2} {3} {4}\n".format({"0": class_id, "1": v1, "2": v2, "3":v3, "4":v4})
	
	var file_path = "user://labels/{0}/{0}{1}.txt".format({"0":data_type, "1":current_image})
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func randomize_and_save_bounding_boxes():
	var rng = RandomNumberGenerator.new()
	card_ids = randomize_cards()
	position_camera()
	bg.material_override.albedo_color = Color(rng.randf_range(0, 1), rng.randf_range(0, 1), rng.randf_range(0, 1))
	var boxes = get_named_bounding_boxes()
	save_bounding_boxes(boxes)
	# can't save image here because the changes won't render until next frame

func save_image():
	var capture = get_viewport().get_texture().get_image()
	var filename = "user://images/{0}/{0}{1}.png".format({"0":data_type, "1":current_image})
	capture.save_png(filename)

func _ready():
	data_size = {
		"train": train_data_size,
		"val": val_data_size,
		"test": test_data_size
	}
	randomize_and_save_bounding_boxes()

func _process(delta):
	if debug:
		return
	if finished:
		return
	current_time += delta
	if current_time < wait_time:
		return
	save_image()
	current_image += 1
	if current_image > data_size[data_type]:
		current_image = 1
		if data_type == "train":
			data_type = "val"
		elif data_type == "val":
			data_type = "test"
		elif data_type == "test":
			finished = true
			return
	current_time = 0
	randomize_and_save_bounding_boxes()
