extends RefCounted
## Deterministic planar four-bar linkage solving for baked mechanical animation.

static func _circle_intersections(first: Vector2, first_radius: float,
		second: Vector2, second_radius: float) -> Array[Vector2]:
	var delta := second - first
	var distance := delta.length()
	if distance <= 0.0000001 or distance > first_radius + second_radius or \
			distance < absf(first_radius - second_radius):
		return []
	var along := (first_radius * first_radius - second_radius * second_radius +
		distance * distance) / (2.0 * distance)
	var height_sq := maxf(first_radius * first_radius - along * along, 0.0)
	var midpoint := first + delta * (along / distance)
	var perpendicular := Vector2(-delta.y, delta.x) * (sqrt(height_sq) / distance)
	return [midpoint + perpendicular, midpoint - perpendicular]

static func _frame_between(first: Vector3, second: Vector3) -> Transform3D:
	var direction := second - first
	assert(not direction.is_zero_approx(), "mechanical link endpoints must differ")
	var x_axis := direction.normalized()
	var z_axis := Vector3.FORWARD
	if absf(x_axis.dot(z_axis)) > 0.999:
		z_axis = Vector3.UP
	var y_axis := z_axis.cross(x_axis).normalized()
	z_axis = x_axis.cross(y_axis).normalized()
	return Transform3D(Basis(x_axis, y_axis, z_axis), (first + second) * 0.5)

static func solve_four_bar(config: Dictionary, sample_count := 64) -> Dictionary:
	assert(sample_count >= 4, "four-bar animation requires at least four samples")
	var crank_center: Vector2 = config.crank_center
	var beam_pivot: Vector2 = config.beam_pivot
	var crank_radius := float(config.crank_radius)
	var beam_rear_length := float(config.beam_rear_length)
	var pitman_length := float(config.pitman_length)
	var beam_front_length := float(config.get("beam_front_length", beam_rear_length))
	var plane_z := float(config.get("plane_z", 0.0))
	var phase := float(config.get("phase", 0.0))
	var branch_sign := float(config.get("branch_sign", 1.0))
	var samples := []
	var previous := Vector2.ZERO
	var have_previous := false
	var maximum_length_error := 0.0
	var maximum_step := 0.0
	for sample_index in range(sample_count + 1):
		var fraction := float(sample_index) / float(sample_count)
		var crank_angle := phase + fraction * TAU
		var crank_pin := crank_center + Vector2(cos(crank_angle), sin(crank_angle)) * crank_radius
		var candidates := _circle_intersections(beam_pivot, beam_rear_length,
			crank_pin, pitman_length)
		if candidates.is_empty():
			return {"ok": false, "error": "four-bar dimensions have no physical solution",
				"samples": samples}
		var rear_pin: Vector2
		if have_previous:
			rear_pin = candidates[0] if candidates[0].distance_to(previous) <= \
				candidates[1].distance_to(previous) else candidates[1]
			maximum_step = maxf(maximum_step, rear_pin.distance_to(previous))
		else:
			var cross_a := (crank_pin - beam_pivot).cross(candidates[0] - beam_pivot)
			rear_pin = candidates[0] if cross_a * branch_sign >= 0.0 else candidates[1]
		have_previous = true
		previous = rear_pin
		var rear_direction := (rear_pin - beam_pivot).normalized()
		var front_pin := beam_pivot - rear_direction * beam_front_length
		var crank3 := Vector3(crank_pin.x, crank_pin.y, plane_z)
		var rear3 := Vector3(rear_pin.x, rear_pin.y, plane_z)
		var front3 := Vector3(front_pin.x, front_pin.y, plane_z)
		var pivot3 := Vector3(beam_pivot.x, beam_pivot.y, plane_z)
		var center3 := Vector3(crank_center.x, crank_center.y, plane_z)
		maximum_length_error = maxf(maximum_length_error,
			absf(crank_pin.distance_to(rear_pin) - pitman_length))
		samples.append({
			"phase": fraction,
			"crank_pin": crank3,
			"beam_rear_pin": rear3,
			"beam_front_pin": front3,
			"frames": {
				"crank": Transform3D(Basis(Vector3.FORWARD, crank_angle), center3),
				"flywheel": Transform3D(Basis(Vector3.FORWARD, crank_angle), center3),
				"walking_beam": Transform3D(Basis(Vector3.FORWARD,
					atan2(rear_direction.y, rear_direction.x)), pivot3),
				"horsehead": Transform3D(Basis(Vector3.FORWARD,
					atan2(rear_direction.y, rear_direction.x)), front3),
				"pitman": _frame_between(crank3, rear3),
				"polish_rod": Transform3D(Basis.IDENTITY, front3),
				"pump_shaft": Transform3D(Basis.IDENTITY, front3),
			},
		})
	var loop_error := 0.0
	for name in samples[0].frames:
		var first: Transform3D = samples[0].frames[name]
		var last: Transform3D = samples[-1].frames[name]
		loop_error = maxf(loop_error, first.origin.distance_to(last.origin))
		loop_error = maxf(loop_error, first.basis.get_rotation_quaternion().angle_to(
			last.basis.get_rotation_quaternion()))
	return {"ok": true, "samples": samples,
		"maximum_fixed_length_error": maximum_length_error,
		"maximum_continuity_step": maximum_step,
		"loop_closure_error": loop_error,
		"pitman_length": pitman_length}

static func bake_clip(clip, solved: Dictionary, bone_rests: Dictionary) -> void:
	assert(bool(solved.get("ok", false)), "cannot bake an unsolved mechanical linkage")
	for bone_name in bone_rests:
		var rest: Transform3D = bone_rests[bone_name]
		for sample in solved.samples:
			if not sample.frames.has(bone_name): continue
			var current: Transform3D = sample.frames[bone_name]
			clip.add_key(str(bone_name), float(sample.phase) * float(clip.duration),
				rest.affine_inverse() * current)
