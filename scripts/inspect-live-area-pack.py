"""Unchanged complete original area packer consumes explicit snapshots of live
replacement-session metadata for all five Prelude areas and both format modes.
Heap is enlarged/cleared for the real 204-object/144-tile cases; no live process
is touched. Same captured server/lookup/script/expansion/2DA boundaries as the
synthetic pack oracle; no claim of actual client receipt or network transport.
"""
import importlib,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
a=importlib.import_module('inspect-native-area-pack');m=a.m;u=a.u
u.mem_map(m.heap+0x100000,0x400000);a.tiles=m.heap+0x110000;a.grass=m.heap+0x120000;a.ids=m.heap+0x130000;a.objectBase=m.heap+0x140000;a.objectStride=0x2000;a.soundRefOffset=0x1000
source=json.loads((m.root/'backups/animations/live-area-pack-cases.json').read_text());rows=[]
for i,row in enumerate(source['cases']):
 u.mem_write(m.heap+0x100000,bytes(0x400000))
 try:
  result=a.run(row['case']);native=bytes.fromhex(result['observation']['hex']);expected=bytes.fromhex(row['packetHex']);mask=bytes.fromhex(row['definedMaskHex']);assert len(native)==len(expected)
  differences=[dict(index=j,native=x,source=y,mask=b)for j,(x,y,b)in enumerate(zip(native,expected,mask))if x&b!=y&b];assert not differences,differences[:10]
  snapshot=dict(result['observation']);snapshot.pop('hex');assert snapshot==row['observation']
  rows.append(dict(format=row['case']['format'],areaId=row['case']['id'],objects=len(row['case']['ids']),tiles=len(row['case']['tiles']),bytes=len(native),definedBits=sum(b.bit_count()for b in mask),result=result['result'],diagnostics=result['diagnostics'],nativeHex=native.hex(),sourceHex=expected.hex(),definedMaskHex=mask.hex(),observation=snapshot))
 except Exception:print(json.dumps(dict(index=i,areaId=row['case']['id'],rip=hex(u.reg_read(a.UC_X86_REG_RIP)))));raise
out=m.root/'backups/animations/native-live-area-pack-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
