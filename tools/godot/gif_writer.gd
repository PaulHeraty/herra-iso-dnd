class_name GifWriter
extends RefCounted
## Minimal animated GIF89a encoder (global palette, LZW, looping) for previews of generated art.
## Frames must be the same size; alpha is ignored (compose onto a background first).
## At most 256 distinct colours across all frames.

static func save(path: String, frames: Array[Image], delay_cs: int = 10) -> Error:
	if frames.is_empty():
		return ERR_INVALID_PARAMETER
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	# Global palette.
	var index := {}
	var colors: Array[int] = []
	var pixels: Array[PackedByteArray] = []
	var too_many := false
	for img in frames:
		var im := img.duplicate() as Image
		im.convert(Image.FORMAT_RGB8)
		var data := im.get_data()
		var px := PackedByteArray()
		px.resize(w * h)
		for i in w * h:
			var c := (data[i * 3] << 16) | (data[i * 3 + 1] << 8) | data[i * 3 + 2]
			if not index.has(c):
				if colors.size() >= 256:
					too_many = true
					break
				index[c] = colors.size()
				colors.append(c)
			px[i] = index[c]
		if too_many:
			break
		pixels.append(px)
	if too_many:
		# Rendered game frames: map to a fixed 6x7x6 colour cube (252 colours). Lossy, previews only.
		colors.clear()
		pixels.clear()
		for r in 6:
			for g in 7:
				for b in 6:
					colors.append((roundi(r * 51.0) << 16) | (roundi(g * 42.5) << 8) | roundi(b * 51.0))
		for img in frames:
			var im := img.duplicate() as Image
			im.convert(Image.FORMAT_RGB8)
			var data := im.get_data()
			var px := PackedByteArray()
			px.resize(w * h)
			for i in w * h:
				px[i] = roundi(data[i * 3] / 51.0) * 42 + roundi(data[i * 3 + 1] / 42.5) * 6 + roundi(data[i * 3 + 2] / 51.0)
			pixels.append(px)
	var bits := 1
	while (1 << bits) < colors.size():
		bits += 1
	bits = maxi(bits, 2)

	var out := PackedByteArray()
	out.append_array("GIF89a".to_ascii_buffer())
	_u16(out, w)
	_u16(out, h)
	out.append(0x80 | ((bits - 1) << 4) | (bits - 1))
	out.append(0)
	out.append(0)
	for i in (1 << bits):
		var c := colors[i] if i < colors.size() else 0
		out.append((c >> 16) & 255)
		out.append((c >> 8) & 255)
		out.append(c & 255)
	# Loop forever (NETSCAPE2.0).
	out.append_array(PackedByteArray([0x21, 0xFF, 0x0B]))
	out.append_array("NETSCAPE2.0".to_ascii_buffer())
	out.append_array(PackedByteArray([0x03, 0x01, 0x00, 0x00, 0x00]))
	for px in pixels:
		out.append_array(PackedByteArray([0x21, 0xF9, 0x04, 0x04]))   # GCE, disposal = keep
		_u16(out, delay_cs)
		out.append_array(PackedByteArray([0x00, 0x00]))
		out.append(0x2C)
		_u16(out, 0)
		_u16(out, 0)
		_u16(out, w)
		_u16(out, h)
		out.append(0)
		out.append(bits)
		var lzw := _lzw(px, bits)
		var i := 0
		while i < lzw.size():
			var n := mini(255, lzw.size() - i)
			out.append(n)
			out.append_array(lzw.slice(i, i + n))
			i += n
		out.append(0)
	out.append(0x3B)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(out)
	return OK


static func _u16(out: PackedByteArray, v: int) -> void:
	out.append(v & 255)
	out.append((v >> 8) & 255)


static func _lzw(px: PackedByteArray, min_size: int) -> PackedByteArray:
	var clear := 1 << min_size
	var eoi := clear + 1
	var out := PackedByteArray()
	var acc := 0
	var nbits := 0
	var size := min_size + 1
	var dict := {}
	var next := eoi + 1
	# Collect (code, bit width) pairs, then pack them LSB-first.
	var codes: Array[int] = [clear]
	var sizes: Array[int] = [size]
	var prefix := px[0]
	for i in range(1, px.size()):
		var k := px[i]
		var key := (prefix << 8) | k
		if dict.has(key):
			prefix = dict[key]
			continue
		codes.append(prefix)
		sizes.append(size)
		if next < 4096:
			dict[key] = next
			next += 1
			if next > (1 << size) and size < 12:
				size += 1
		else:
			codes.append(clear)
			sizes.append(size)
			dict.clear()
			next = eoi + 1
			size = min_size + 1
		prefix = k
	codes.append(prefix)
	sizes.append(size)
	codes.append(eoi)
	sizes.append(size)
	for j in codes.size():
		acc |= codes[j] << nbits
		nbits += sizes[j]
		while nbits >= 8:
			out.append(acc & 255)
			acc >>= 8
			nbits -= 8
	if nbits > 0:
		out.append(acc & 255)
	return out
