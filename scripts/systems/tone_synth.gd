class_name ToneSynth
extends RefCounted
## Generates short placeholder sounds as 16-bit PCM so every audio hook is
## audible before real audio files exist. Replace by dropping files into
## assets/audio/ with the same id (see AudioManager).

const RATE := 22050


static func tone(freq: float, dur: float, vol: float = 0.5, wave: String = "sine", decay: float = 0.0, freq_end: float = -1.0, attack: float = 0.004) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var release := minf(0.04, dur * 0.3)
	for i in n:
		var t := float(i) / RATE
		var f := freq if freq_end < 0.0 else lerpf(freq, freq_end, t / dur)
		phase += f / RATE
		var p := fmod(phase, 1.0)
		var s := 0.0
		if wave == "sine":
			s = sin(TAU * p)
		elif wave == "triangle":
			s = 4.0 * absf(p - 0.5) - 1.0
		elif wave == "soft_square":
			s = sin(TAU * p) + sin(TAU * p * 3.0) / 3.0 + sin(TAU * p * 5.0) / 5.0
			s *= 0.8
		elif wave == "bell":
			s = sin(TAU * p) * 0.75 + sin(TAU * p * 2.76) * 0.25 * exp(-t * 9.0)
		var env := 1.0
		if attack > 0.0:
			env = minf(1.0, t / attack)
		var rem := dur - t
		if rem < release:
			env *= rem / release
		if decay > 0.0:
			env *= exp(-t * decay)
		out[i] = s * env * vol
	return out


static func noise(dur: float, vol: float = 0.4, smooth: float = 0.5, decay: float = 0.0, seed_value: int = 7) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var raw := rng.randf_range(-1.0, 1.0)
		prev = lerpf(raw, prev, smooth)
		var env := minf(1.0, t / 0.003)
		var rem := dur - t
		if rem < 0.02:
			env *= rem / 0.02
		if decay > 0.0:
			env *= exp(-t * decay)
		out[i] = prev * env * vol
	return out


static func silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


static func concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


static func mix(a: PackedFloat32Array, b: PackedFloat32Array, offset_sec: float = 0.0) -> PackedFloat32Array:
	var off := int(offset_sec * RATE)
	var out := a.duplicate()
	if out.size() < b.size() + off:
		out.resize(b.size() + off)
	for i in b.size():
		out[i + off] += b[i]
	return out


static func notes(freqs: Array, step: float, dur: float, vol: float, wave: String = "bell", decay: float = 6.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in freqs.size():
		out = mix(out, tone(float(freqs[i]), dur, vol, wave, decay), step * i)
	return out


static func to_stream(samples: PackedFloat32Array, loop: bool = false, rate: int = RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## A soft marimba-like plink: warm fundamental, a quick woody overtone.
static func marimba(freq: float, dur: float = 0.35, vol: float = 0.2, decay: float = 9.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.002) * exp(-t * decay)
		var rem := dur - t
		if rem < 0.02:
			env *= rem / 0.02
		var v := sin(TAU * freq * t) + 0.22 * sin(TAU * freq * 4.0 * t) * exp(-t * 40.0) + 0.06 * sin(TAU * freq * 9.8 * t) * exp(-t * 70.0)
		out[i] = v * env * vol
	return out


## A round, bubbly pop (pitch glides from f0 to f1).
static func bubble(f0: float, f1: float, dur: float = 0.08, vol: float = 0.18) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var f := lerpf(f0, f1, 1.0 - pow(1.0 - k, 3.0))
		phase += f / RATE
		var env := minf(1.0, t / 0.003) * exp(-t * 28.0)
		out[i] = sin(TAU * phase) * env * vol
	return out


static func plinks(freqs: Array, step: float, vol: float = 0.18, dur: float = 0.4) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in freqs.size():
		out = mix(out, marimba(float(freqs[i]), dur, vol), step * i)
	return out


## A soft, rounded horn: a few harmonics with a gentle attack (never square).
static func horn(freq: float, dur: float, vol: float = 0.16, freq2: float = 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.015) * minf(1.0, (dur - t) / 0.04)
		var vib := 1.0 + 0.004 * sin(TAU * 6.0 * t)
		var v := 0.0
		for f in ([freq, freq2] if freq2 > 0.0 else [freq]):
			var ff: float = f * vib
			v += sin(TAU * ff * t) + 0.35 * sin(TAU * ff * 2.0 * t) + 0.12 * sin(TAU * ff * 3.0 * t)
		out[i] = v * env * vol * (0.6 if freq2 > 0.0 else 1.0)
	return out


## A soft low thud (bus bump, door, khalasi's slap on the side).
static func thud(f0: float = 150.0, f1: float = 70.0, dur: float = 0.14, vol: float = 0.3) -> PackedFloat32Array:
	return mix(bubble(f0, f1, dur, vol), noise(0.05, 0.05, 0.6, 40.0, 3))


## A little engine "brrm": a low purr gliding up.
static func engine(f0: float, f1: float, dur: float, vol: float = 0.12) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var f := lerpf(f0, f1, k)
		phase += f / RATE
		var putt := 0.55 + 0.45 * sin(TAU * f * 0.25 * t)
		var env := minf(1.0, t / 0.03) * minf(1.0, (dur - t) / 0.08)
		out[i] = (sin(TAU * phase) * 0.7 + sin(TAU * phase * 2.0) * 0.3) * putt * env * vol
	return mix(out, noise(dur, vol * 0.25, 0.92, 2.0, 5))


## All placeholder sound effects, keyed by AudioManager id. Soft and round:
## marimba plinks, bubble pops and gentle horns, nothing harsh.
static func build_sfx() -> Dictionary:
	var s := {}
	s["button_click"] = bubble(620.0, 980.0, 0.07, 0.16)
	s["select"] = mix(bubble(500.0, 820.0, 0.08, 0.16), marimba(1046.5, 0.18, 0.06))
	s["success"] = plinks([784.0, 1046.5], 0.07, 0.18)
	s["perfect"] = plinks([1046.5, 1318.5, 1568.0, 2093.0], 0.06, 0.15)
	s["failure"] = plinks([784.0, 659.3, 523.3], 0.12, 0.16)
	s["combo"] = plinks([1046.5, 1568.0], 0.05, 0.15)
	s["reward"] = plinks([523.3, 659.3, 784.0, 1046.5, 1318.5], 0.07, 0.17, 0.5)
	s["level_complete"] = plinks([523.3, 659.3, 784.0, 1046.5, 784.0, 1046.5, 1318.5, 1568.0], 0.09, 0.17, 0.6)
	s["coin_pickup"] = mix(marimba(1975.5, 0.18, 0.1), marimba(2637.0, 0.22, 0.08), 0.045)
	s["nope"] = concat([bubble(320.0, 250.0, 0.08, 0.15), silence(0.03), bubble(270.0, 210.0, 0.1, 0.13)])
	s["heart"] = plinks([784.0, 1046.5, 1318.5], 0.07, 0.16)
	s["cheer"] = plinks([784.0, 987.8, 1174.7, 1568.0], 0.07, 0.17)
	s["pop"] = bubble(500.0, 900.0, 0.08, 0.15)
	s["unlock"] = plinks([1318.5, 1975.5], 0.08, 0.14)
	# Bus park.
	s["drive"] = engine(90.0, 170.0, 0.42, 0.13)
	s["depart"] = engine(110.0, 210.0, 0.7, 0.12)
	s["bump"] = mix(thud(170.0, 80.0, 0.16, 0.32), bubble(420.0, 300.0, 0.08, 0.06), 0.02)
	s["hop"] = mix(bubble(420.0, 860.0, 0.07, 0.13), marimba(1318.5, 0.14, 0.05), 0.02)
	s["door"] = mix(thud(220.0, 140.0, 0.1, 0.2), marimba(659.3, 0.16, 0.06), 0.03)
	s["slap"] = concat([thud(130.0, 70.0, 0.1, 0.32), silence(0.06), thud(130.0, 70.0, 0.1, 0.28)])
	s["wake"] = concat([bubble(300.0, 420.0, 0.14, 0.12), bubble(420.0, 640.0, 0.16, 0.12)])
	s["crane"] = mix(noise(0.6, 0.05, 0.95, 2.5, 21), engine(260.0, 420.0, 0.6, 0.06))
	s["cones"] = mix(noise(0.25, 0.06, 0.6, 12.0, 17), plinks([784.0, 1046.5, 1318.5], 0.06, 0.12), 0.05)
	s["warning"] = plinks([523.3, 493.9, 523.3, 493.9], 0.12, 0.13)
	s["bay_open"] = mix(bubble(420.0, 880.0, 0.1, 0.18), plinks([1046.5, 1568.0], 0.07, 0.13), 0.06)
	s["shuffle"] = mix(noise(0.45, 0.05, 0.95, 4.0, 9), plinks([523.3, 659.3, 784.0, 1046.5, 1318.5], 0.06, 0.1))
	s["tunnel"] = mix(engine(70.0, 120.0, 0.5, 0.1), bubble(300.0, 500.0, 0.1, 0.06), 0.3)
	s["wipe"] = mix(noise(0.38, 0.07, 0.96, 3.0, 41), engine(120.0, 240.0, 0.38, 0.08))
	# Horns (cosmetic choice).
	s["horn_peep"] = concat([horn(523.3, 0.11), silence(0.06), horn(523.3, 0.15)])
	s["horn_pompom"] = concat([horn(330.0, 0.16, 0.18), silence(0.07), horn(330.0, 0.22, 0.18)])
	s["horn_tune"] = concat([horn(523.3, 0.12), horn(659.3, 0.12), horn(784.0, 0.22)])
	s["horn_air"] = horn(233.1, 0.55, 0.2, 277.2)
	var streams := {}
	for k in s.keys():
		streams[k] = to_stream(s[k])
	return streams


## A bouncy pentatonic marimba tune over a light "bus-ride" bass.
static func build_music() -> AudioStreamWAV:
	var rate := 16000
	var bpm := 104.0
	var beat := 60.0 / bpm
	var steps := 64
	var step_len := beat * 0.5
	var total := int(step_len * steps * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var melody := [
		7, -1, 9, 7, 4, -1, 7, -1, 9, -1, 12, -1, 9, 7, -1, -1,
		4, -1, 7, 4, 2, -1, 4, -1, 7, -1, 9, 7, 4, -1, -1, -1,
		7, -1, 9, 7, 4, -1, 7, -1, 12, -1, 14, -1, 12, 9, -1, -1,
		9, -1, 7, -1, 4, -1, 2, 4, 0, -1, -1, -1, 2, -1, 4, -1]
	var scale := {0: 261.63, 2: 293.66, 4: 329.63, 7: 392.0, 9: 440.0, 12: 523.25, 14: 587.33}
	for i in melody.size():
		var idx: int = melody[i]
		if idx < 0:
			continue
		var f: float = scale.get(idx, 392.0) * 2.0
		var start := int(i * step_len * rate)
		var n := int(rate * 0.6)
		for j in n:
			var k := (start + j) % total
			var t := float(j) / rate
			var env := minf(1.0, t / 0.003) * exp(-t * 7.0)
			out[k] += (sin(TAU * f * t) + 0.18 * sin(TAU * f * 4.0 * t) * exp(-t * 30.0)) * env * 0.08
	# Bass on every beat: C - Am - F - G, one chord per 16 steps.
	var roots := [130.81, 110.0, 87.31, 98.0]
	for i in steps:
		if i % 2 != 0:
			continue
		var f: float = roots[(i / 16) % 4] * (1.0 if i % 4 == 0 else 1.5)
		var start := int(i * step_len * rate)
		var n := int(rate * 0.22)
		for j in n:
			var k := (start + j) % total
			var t := float(j) / rate
			out[k] += sin(TAU * f * t) * minf(1.0, t / 0.005) * exp(-t * 12.0) * 0.09
	# Soft shaker on the off-beats.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in steps:
		if i % 2 == 1:
			var start := int(i * step_len * rate)
			var prev := 0.0
			for j in int(rate * 0.05):
				var raw := rng.randf_range(-1.0, 1.0)
				prev = lerpf(raw, prev, 0.3)
				out[(start + j) % total] += (raw - prev) * exp(-float(j) / rate * 60.0) * 0.025
	return to_stream(out, true, rate)


## Ambient bed per scene: a soft murmur with distant horns (park) or birds (hub).
static func build_ambient(kind: String) -> AudioStreamWAV:
	var rate := 16000
	var dur := 8.0
	var total := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if kind == "park" else 12
	var prev := 0.0
	for i in total:
		var raw := rng.randf_range(-1.0, 1.0)
		prev = lerpf(raw, prev, 0.985)
		var t := float(i) / rate
		out[i] = prev * 0.5 * (0.8 + 0.2 * sin(TAU * t / dur))
	if kind == "park":
		for at in [1.3, 4.6, 6.9]:
			var f := rng.randf_range(380.0, 560.0)
			var h := horn(f, 0.18, 0.03)
			var off := int(at * rate)
			var resampled := int(float(h.size()) * float(rate) / float(RATE))
			for j in resampled:
				var src := int(float(j) * float(RATE) / float(rate))
				if src < h.size():
					out[(off + j) % total] += h[src]
	else:
		for at in [0.7, 1.0, 3.8, 4.05, 6.2]:
			var f0 := rng.randf_range(2200.0, 3200.0)
			var off := int(at * rate)
			for j in int(rate * 0.09):
				var t := float(j) / rate
				var f := f0 + 900.0 * sin(TAU * 28.0 * t)
				out[(off + j) % total] += sin(TAU * f * t) * exp(-t * 30.0) * 0.025
	# Loop seam: fade the last 0.2 s into the start.
	var fade := int(0.2 * rate)
	for j in fade:
		var k := float(j) / fade
		out[total - fade + j] = lerpf(out[total - fade + j], out[j], k)
	return to_stream(out, true, rate)
