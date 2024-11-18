extends Node3D

var max_region_cards = 8
var number_of_region_cards = 68
var number_of_sanctuary_cards = 45
var region_card_size = Vector2(3, 3)
var region_rows = 2

var max_sanctuary_cards = 7
var sanctuary_rows = 1
var sanctuary_card_size = Vector2(1.9, 2.9)
var sanctuary_card_id_offset = 69

@export var min_card_gap = 0.1
@export var max_card_gap = 0.3

@onready var camera: Camera3D = %Camera
@onready var bg: MeshInstance3D = %MeshInstance3D

@export var debug: bool = true

@export var train_data_size = 1800
@export var val_data_size = 600
@export var test_data_size = 600

var data_type = "train"
var data_size = {}

@export var wait_time = 0.15
var current_time = -5
var current_image = 1
var finished = false

func draw_debug_sphere(location, size):
	var scene_root = get_tree().root.get_children()[0]
	var sphere = SphereMesh.new()
	sphere.radial_segments = 4
	sphere.rings = 4
	sphere.radius = size
	sphere.height = size * 2
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0)
	material.flags_unshaded = true
	sphere.surface_set_material(0, material)
	var node = MeshInstance3D.new()
	node.mesh = sphere
	node.global_transform.origin = location
	scene_root.add_child(node)

func randomize_camera():
	var rng = RandomNumberGenerator.new()
	
	var aabb = get_aabb()
	var objectHeight = aabb.size.y
	var objectWidth = aabb.size.x
	var screen_size = get_viewport().get_size()
	var aspect = screen_size.x / float(screen_size.y)
	objectHeight = max(objectHeight, objectWidth / aspect)
	var distance = objectHeight / tan(deg_to_rad(camera.fov / 2.0)) / 2
	
	# somewhat arbitrary values, chosen based on what looks good
	var z = rng.randf_range(1.02, 1.3)
	
	camera.position = Vector3(0, 0, distance * z) + aabb.position + aabb.size / 2
	camera.look_at(aabb.position + aabb.size / 2)

func get_aabb():
	var nw = Vector2(0, 0)
	var se = Vector2(0, 0)
	var aabb = AABB(Vector3.ZERO, Vector3.ZERO)
	var region_size = Vector3(region_card_size.x, region_card_size.y, 1)
	var sanctuary_size = Vector3(sanctuary_card_size.x, sanctuary_card_size.y, 1)
	for i in range(max_region_cards):
		var card: Sprite3D = %Regions.get_child(i)
		if card.is_visible():
			var card_aabb = AABB(card.position - region_size / 2, region_size)
			aabb = aabb.merge(card_aabb)
	for i in range(max_sanctuary_cards):
		var card: Sprite3D = %Sanctuaries.get_child(i)
		if card.is_visible():
			var card_aabb = AABB(card.position - sanctuary_size / 2, sanctuary_size)
			aabb = aabb.merge(card_aabb)
	return aabb

func get_set_bounding_box(size):
	var boxes = get_bounding_boxes(false)
	var box = [500, -500, 500, -500]
	for card_box in boxes:
		box[0] = min(box[0], card_box[0] / size.x)
		box[2] = min(box[2], card_box[2] / size.y)
		box[1] = max(box[1], card_box[1] / size.x)
		box[3] = max(box[3], card_box[3] / size.y)
	return box

func get_bounding_boxes(yolo_format = true):
	var boxes = []
	for i in range(max_region_cards):
		var card: Sprite3D = %Regions.get_child(i)
		if card.is_visible():
			boxes.append(bounding_box(card.position, region_card_size, yolo_format))
	for i in range(max_sanctuary_cards):
		var card: Sprite3D = %Sanctuaries.get_child(i)
		if card.is_visible():
			boxes.append(bounding_box(card.position, sanctuary_card_size, yolo_format))
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

func bounding_box(center, card_size, yolo_format = true):
	var width = card_size.x / 2
	var height = card_size.y / 2
	var edges = [center + Vector3(width, height, 0), center + Vector3(-width, height, 0), center + Vector3(width, -height, 0), center + Vector3(-width, -height, 0)]
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

func randomize_sanctuary_cards(gap):
	var rng = RandomNumberGenerator.new()
	var cards = []
	var temple_count = rng.randi_range(0, max_sanctuary_cards)
	while len(cards) != temple_count:
		var card = rng.randi_range(1, number_of_sanctuary_cards)
		while card in cards:
			card = rng.randi_range(1, number_of_sanctuary_cards)
		cards.append(card)
	for i in range(temple_count):
		var card: Card = %Sanctuaries.get_child(i)
		card.set_card(cards[i])
		card.show()
	for i in range(temple_count, max_sanctuary_cards):
		var card: Sprite3D = %Sanctuaries.get_child(i)
		card.hide()
	var sanctuary_offset_x = (-region_card_size.x + sanctuary_card_size.x) / 2
	for i in range(max_sanctuary_cards):
		var row = floor(i / (max_sanctuary_cards / sanctuary_rows)) - 1
		var col = i % (max_sanctuary_cards / sanctuary_rows)
		var card: Sprite3D = %Sanctuaries.get_child(i)
		card.position = Vector3(col * (sanctuary_card_size.x + gap) + sanctuary_offset_x, -row * (sanctuary_card_size.y + gap), 0)
	return cards

func randomize_region_cards(gap):
	var rng = RandomNumberGenerator.new()
	var cards = []
	var region_count = rng.randi_range(0, max_region_cards)
	while len(cards) != region_count:
		var card = rng.randi_range(1, number_of_region_cards)
		while card in cards:
			card = rng.randi_range(1, number_of_region_cards)
		cards.append(card)
	for i in range(region_count):
		var card: Card = %Regions.get_child(i)
		card.set_card(cards[i])
		card.show()
	for i in range(region_count, max_region_cards):
		var card: Sprite3D = %Regions.get_child(i)
		card.hide()
	for i in range(region_count):
		var row = floor(i / (max_region_cards / region_rows))
		var col = i % (max_region_cards / region_rows)
		var card: Sprite3D = %Regions.get_child(i)
		card.position = Vector3(col * (region_card_size.x + gap), -row * (region_card_size.y + gap), 0)
	return cards

func get_named_bounding_boxes(regions, sanctuaries):
	var boxes = get_bounding_boxes()
	var named_boxes = []
	for i in range(len(regions)):
		var card: Sprite3D = %Regions.get_child(i)
		named_boxes.append([regions[i], boxes[i]])
	for i in range(len(sanctuaries)):
		var card: Sprite3D = %Sanctuaries.get_child(i)
		named_boxes.append([sanctuaries[i] + sanctuary_card_id_offset, boxes[i + len(regions)]])
	return named_boxes

func save_bounding_boxes(boxes):
	var text = ""
	
	for box in boxes:
		var class_id = box[0] - 1
		if class_id >= 69:
			class_id -= 1
		var v1 = box[1][0]
		var v2 = box[1][1]
		var v3 = box[1][2]
		var v4 = box[1][3]
		text += "{0} {1} {2} {3} {4}\n".format({"0": class_id, "1": v1, "2": v2, "3":v3, "4":v4})
	
	var file_path = "user://labels/{0}/{1}.txt".format({"0":data_type, "1":current_image})
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func randomize_and_save_bounding_boxes():
	var rng = RandomNumberGenerator.new()
	var gap = rng.randf_range(min_card_gap, max_card_gap)
	var regions = randomize_region_cards(gap)
	var sanctuaries = randomize_sanctuary_cards(gap)
	randomize_camera()
	bg.material_override.albedo_color = Color(rng.randf_range(0, 1), rng.randf_range(0, 1), rng.randf_range(0, 1))
	# save bounding boxes
	var boxes = get_named_bounding_boxes(regions, sanctuaries)
	save_bounding_boxes(boxes)
	# can't save image here because the changes won't render until next frame

func save_image():
	var capture = get_viewport().get_texture().get_image()
	var filename = "user://images/{0}/{1}.png".format({"0":data_type, "1":current_image})
	capture.save_png(filename)

func _ready():
	var region_card_scene = preload("res://scenes/region.tscn")
	for i in range(max_region_cards):
		%Regions.add_child(region_card_scene.instantiate())
	var sanctuary_card_scene = preload("res://scenes/sanctuary.tscn")
	for i in range(max_sanctuary_cards):
		%Sanctuaries.add_child(sanctuary_card_scene.instantiate())
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
