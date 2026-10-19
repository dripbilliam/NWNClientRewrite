"""Read-only candidate search around REA's native message-sender call sites.

Raw immediate-byte matches are candidates only, not instruction/dataflow proof.
Inspect their containing procedures before assigning packet semantics.
"""
import hashlib,json,struct
from pathlib import Path
root=Path(__file__).resolve().parent.parent
data=(root/'../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=struct.unpack_from('<I',data,0x3c)[0]
num=struct.unpack_from('<H',data,pe+6)[0]
opt=struct.unpack_from('<H',data,pe+20)[0]
sections=[struct.unpack_from('<IIII',data,pe+24+opt+i*40+8)for i in range(num)]
raw=json.loads((root/'backups/animations/rea-network-server-send-callers.json').read_text())
d=(raw.get('structuredContent')or json.loads(raw['content'][0]['text']))['normalized_result']
refs=[int(r['source_address'],16)for r in d['incoming_references']if r['call']]
hits=[]
for a in refs:
 rva=a-0x140000000
 off=next(raw+rva-va for vs,va,size,raw in sections if va<=rva<va+max(vs,size))
 b=data[off-96:off]
 if any(x in b for x in [bytes.fromhex('41b012'),bytes.fromhex('41b812000000')]):hits.append(dict(address=hex(a),precedingBytes=b.hex()))
print(json.dumps(dict(target=digest,calls=len(refs),candidate18Calls=hits)))
