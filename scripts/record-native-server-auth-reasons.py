"""Record exact auth-result switch targets and installed English TLK text."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import pefile

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--report', required=True)
output = Path(p.parse_args().report).resolve()
if output.exists():
    raise SystemExit('Refusing to overwrite original observations')
install = ROOT.parent / 'FullDecomp/NwnRootInstall'
raw = (install / 'bin/win32/nwserver.exe').read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert digest == '98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6'
pe = pefile.PE(data=raw)
base = pe.OPTIONAL_HEADER.ImageBase
assert pe.get_data(0x1a920, 10) == bytes.fromhex('0fb7c2ffc883f806773f')
table = pe.get_data(0x1a96c, 7*4)
tlk = (install / 'lang/en/data/dialog.tlk').read_bytes()
assert tlk[:8] == b'TLK V3.0'
count, strings = struct.unpack_from('<II', tlk, 12)
rows = []
for result, target in enumerate(struct.unpack('<7I', table), 1):
    instructions = pe.get_data(target, 6)
    assert instructions[0] == 0xb8 and instructions[5] == 0xc3
    ref = struct.unpack_from('<I', instructions, 1)[0]
    assert ref < count
    offset, length = struct.unpack_from('<II', tlk, 20+ref*40+28)
    value = tlk[strings+offset:strings+offset+length]
    rows.append({'authenticationResult': result, 'switchTarget': hex(base+target),
                 'exactMovEaxRet': instructions.hex(), 'strRef': ref,
                 'englishText': value.decode('cp1252'), 'textBytesSha256': hashlib.sha256(value).hexdigest()})
report = {'success': True, 'binarySha256': digest,
          'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'englishTlkSha256': hashlib.sha256(tlk).hexdigest(),
          'switch': {'procedure': '0x14001a920', 'tableAddress': '0x14001a96c', 'tableBytes': table.hex()},
          'rows': rows,
          'scope': 'Exact static auth-result1..7 to original English TLK reason mapping; no runtime credential data. Does not by itself establish why a particular key-auth result was produced or authorize bypass/retry/key substitution.',
          'serversStarted': 0, 'nativeBuilds': 0, 'gpu': False}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'success': True, 'observedResult2': rows[1], 'report': str(output)}))
