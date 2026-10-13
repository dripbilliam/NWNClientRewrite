"""Independent Python 3.12 audioop check; WAV arrives on stdin, only a hash exits."""
import audioop
import hashlib
import json
import struct
import sys

data = sys.stdin.buffer.read()
assert data[:4] == b'RIFF' and data[8:12] == b'WAVE'
chunks = {}
offset = 12
while offset + 8 <= len(data):
    name, size = struct.unpack_from('<4sI', data, offset)
    chunks[name] = data[offset+8:offset+8+size]
    offset += 8 + size + (size & 1)
fmt = chunks[b'fmt ']
codec, channels, rate, _, block, bits = struct.unpack_from('<HHIIHH', fmt)
assert codec == 17 and channels == 1 and bits == 4
frames = struct.unpack_from('<I', chunks[b'fact'])[0]
pcm = bytearray()
raw = chunks[b'data']
for offset in range(0, len(raw), block):
    chunk = raw[offset:offset+block]
    predictor, index, reserved = struct.unpack_from('<hBB', chunk)
    assert reserved == 0
    pcm.extend(struct.pack('<h', predictor))
    # audioop is high-first; IMA WAVE is low-first.
    swapped = bytes((b >> 4) | ((b & 15) << 4) for b in chunk[4:])
    decoded, _ = audioop.adpcm2lin(swapped, 2, (predictor, index))
    pcm.extend(decoded)
pcm = pcm[:frames*2]
print(json.dumps({'frames': frames, 'rate': rate, 'pcmSha256': hashlib.sha256(pcm).hexdigest()}))
