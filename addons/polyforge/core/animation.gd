extends RefCounted
## Named, deterministic bone-transform animation clip.

var name: String
var duration: float
var loop: bool
var sample_rate: float
var tracks: Dictionary = {}

func _init(clip_name := "clip", clip_duration := 1.0, loops := true,
		clip_sample_rate := 30.0) -> void:
	name = str(clip_name)
	duration = float(clip_duration)
	loop = bool(loops)
	sample_rate = float(clip_sample_rate)
	assert(name != "", "animation clips require a stable name")
	assert(duration > 0.0, "animation clip duration must be positive")
	assert(sample_rate > 0.0, "animation clip sample rate must be positive")

func add_key(bone: String, time: float, transform: Transform3D) -> void:
	assert(bone != "", "animation keys require a bone name")
	assert(time >= 0.0 and time <= duration + 0.000001,
		"animation key time is outside the clip duration")
	if not tracks.has(bone):
		tracks[bone] = []
	var keys: Array = tracks[bone]
	if not keys.is_empty():
		assert(time > float(keys[-1].time),
			"animation keys must be added in strictly increasing time order")
	keys.append({"time": time, "transform": transform})

func sample(bone: String, time: float) -> Transform3D:
	if not tracks.has(bone) or tracks[bone].is_empty():
		return Transform3D.IDENTITY
	var keys: Array = tracks[bone]
	var local_time := fposmod(time, duration) if loop and time > duration else clampf(time, 0.0, duration)
	if local_time <= float(keys[0].time):
		return keys[0].transform
	for index in range(1, keys.size()):
		if local_time <= float(keys[index].time):
			var before: Dictionary = keys[index - 1]
			var after: Dictionary = keys[index]
			var span := maxf(float(after.time) - float(before.time), 0.0000001)
			return (before.transform as Transform3D).interpolate_with(after.transform,
				(local_time - float(before.time)) / span)
	return keys[-1].transform

func snapshot() -> Dictionary:
	return {"name": name, "duration": duration, "loop": loop,
		"sample_rate": sample_rate, "tracks": tracks}
