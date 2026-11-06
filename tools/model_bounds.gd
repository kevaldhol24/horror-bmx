extends SceneTree
## Dev tool: prints the merged AABB of every model in a folder.
## Usage: godot --headless -s tools/model_bounds.gd -- res://assets/models/city

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "res://assets/models/city"
	for f in DirAccess.get_files_at(dir):
		if not (f.ends_with(".gltf") or f.ends_with(".glb")):
			continue
		var n: Node3D = (load(dir + "/" + f) as PackedScene).instantiate()
		get_root().add_child(n)
		var box := AABB()
		var first := true
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var b: AABB = mi.global_transform * mi.get_aabb()
			if first:
				box = b
				first = false
			else:
				box = box.merge(b)
		print("%-34s pos=%s size=%s" % [f, box.position.snapped(Vector3.ONE * 0.01), box.size.snapped(Vector3.ONE * 0.01)])
		n.queue_free()
	quit()
