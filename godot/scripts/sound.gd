extends RefCounted
## Loads the synthesized ambience in res://sounds/ (made by tools/sounds.py) and loops it.

static var _cache := {}


static func loop(kind: String) -> AudioStream:
	if _cache.has(kind):
		return _cache[kind]
	var s: AudioStreamWAV = load("res://sounds/%s.wav" % kind)
	if s == null:
		return null
	s = s.duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	_cache[kind] = s
	return s


static func one_shot(parent: Node, kind: String, volume_db := -4.0) -> void:
	var s: AudioStream = load("res://sounds/%s.wav" % kind)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
