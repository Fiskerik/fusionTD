class_name GameAudio
extends Node

const SAMPLE_RATE: int = 22050
const VOICES: int = 8
const GREENMARCH: AudioStreamWAV = preload("res://assets/audio/greenmarch.wav")
# Each note holds offset, length, starting pitch, ending pitch, and noise amount.
const CUES: Dictionary = {
	"ui": [[0., .09, 620., 820., .01]],
	"build": [[0., .10, 320., 520., .08], [.06, .11, 620., 700., .0]],
	"upgrade": [[0., .11, 440., 550., .02], [.065, .12, 660., 880., .0]],
	"infuse": [[0., .18, 520., 785., .02], [.08, .22, 900., 1160., .0]],
	"fuse": [[0., .18, 330., 470., .07], [.08, .23, 610., 790., .02], [.165, .24, 880., 1040., .0]],
	"sell": [[0., .12, 625., 390., .03]],
	"arrow": [[0., .077, 580., 245., .29]],
	"cannon": [[0., .22, 122., 51., .57]],
	"magic": [[0., .12, 660., 310., .13]],
	"coin": [[0., .09, 935., 1160., .00], [.05, .12, 1300., 1530., .01]],
	"gate": [[0., .28, 160., 65., .25], [.12, .27, 280., 140., .03]],
	"countdown": [[0., .105, 760., 590., .01]],
	"wave": [[0., .16, 330., 390., .02], [.11, .21, 500., 659., .0]],
	"spirit": [[0., .25, 405., 620., .03], [.11, .32, 696., 940., .025]],
	"unlock": [[0., .13, 523., 540., .0], [.09, .14, 660., 730., .0], [.18, .23, 830., 1047., .0]],
	"clear": [[0., .15, 406., 530., .01], [.09, .19, 630., 760., .0]],
}
const MIN_GAPS_MS: Dictionary = {"arrow": 110, "cannon": 180, "magic": 130, "coin": 95, "gate": 180}

static var streams: Dictionary = {}
var enabled: bool = true
var voices: Array[AudioStreamPlayer] = []
var next_time: Dictionary = {}
var music: AudioStreamPlayer

func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -16.0
	var score: AudioStreamWAV = GREENMARCH.duplicate()
	score.loop_mode = AudioStreamWAV.LOOP_FORWARD
	score.loop_end = roundi(score.get_length() * score.mix_rate)
	music.stream = score
	add_child(music)
	for i: int in range(VOICES):
		var player := AudioStreamPlayer.new()
		player.volume_db = -15.0
		add_child(player)
		voices.append(player)

func set_sound(enabled_value: bool) -> void:
	enabled = enabled_value
	if not enabled:
		for player: AudioStreamPlayer in voices:
			player.stop()

func set_music(active: bool) -> void:
	if active and not music.playing:
		music.play()
	elif not active:
		music.stop()

func play(cue: String) -> void:
	if not enabled or not CUES.has(cue):
		return
	var now: int = Time.get_ticks_msec()
	if now < int(next_time.get(cue, 0)):
		return
	var voice: AudioStreamPlayer
	for player: AudioStreamPlayer in voices:
		if not player.playing:
			voice = player
			break
	if voice == null:
		if cue not in ["gate", "spirit", "unlock", "wave", "countdown"]:
			return
		voice = voices[0]
		voice.stop()
	next_time[cue] = now + int(MIN_GAPS_MS.get(cue, 45))
	voice.stream = stream_for(cue)
	voice.play()

static func stream_for(cue: String) -> AudioStreamWAV:
	if not streams.has(cue):
		streams[cue] = _synthesize(CUES[cue])
	return streams[cue]

static func _synthesize(notes: Array) -> AudioStreamWAV:
	var duration: float = 0.0
	for note: Array in notes:
		duration = maxf(duration, float(note[0]) + float(note[1]))
	var size: int = ceili((duration + .015) * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(size * 2)
	var noise_seed: int = 17421
	for sample: int in range(size):
		var t: float = float(sample) / SAMPLE_RATE
		var combined: float = 0.0
		noise_seed = (1664525 * noise_seed + 1013904223) & 0xffffffff
		var noise: float = float(noise_seed & 0xffff) / 32767.5 - 1.0
		for note: Array in notes:
			var age: float = t - float(note[0])
			var length: float = note[1]
			if age < 0.0 or age >= length:
				continue
			var pitch: float = note[2]
			var delta: float = float(note[3]) - pitch
			var angle: float = TAU * age * (pitch + .5 * delta * age / length)
			var envelope: float = smoothstep(0., .009, age) * pow(1.0 - age / length, 1.8)
			var tone: float = sin(angle) * .81 + sin(2.0 * angle) * .15 + sin(3.0 * angle) * .04
			combined += lerpf(tone, noise, float(note[4])) * envelope * .55
		data.encode_s16(sample * 2, roundi(clampf(combined, -1., 1.) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
