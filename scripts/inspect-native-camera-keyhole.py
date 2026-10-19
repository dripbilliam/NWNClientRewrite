"""Execute the original Camera::GetCanKeyholeDissolve58c50 and
BoxAbovePlane22b350 with synthetic part bounds and camera state. No rendering,
live process changes or asset copies. Calls execute original pinned PE bytes;
only the existing allocator/stack-cookie harness boundaries are captured.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
u.hook_del(t.hook_handle)
camera,part,plane=[m.heap+i*0x1000 for i in [40,42,44]]
def put(a,v):u.mem_write(a,struct.pack('<'+'f'*len(v),*v))
def hook(u,a,n,data):
 if any(lo<=a<hi for lo,hi in [(0x140058c50,0x140058d00),(0x140061af0,0x140061b00),(0x14022b350,0x14022b400)]):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for enabled,owner,height,zmax,normal,d in itertools.product([False,True],[0,1],[0,1,1.00001],[0,1,2],[[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1],[.3,-.4,.5]],[0,-2,2]):
 t.reset(dict(format=1));case=dict(enabled=enabled,owner=owner,height=height,min=[-1,-1,-1],max=[1,1,zmax],plane=normal+[d])
 u.mem_write(camera+0xe58,bytes([int(enabled)]));put(camera+0xe5c,case['plane']);m.wf(camera+0xe6c,height);m.wq(part+0x50,owner);put(part+0x68,case['min']);put(part+0x74,case['max']);put(plane,case['plane'])
 value=w.call(0x140058c50,[camera,part])&255
 w.call(0x14022b350,[part+0x68,part+0x74,plane])
 from unicorn.x86_const import UC_X86_REG_XMM0
 distance=struct.unpack('<f',(u.reg_read(UC_X86_REG_XMM0)&0xffffffff).to_bytes(4,'little'))[0]
 rows.append(dict(case=case,value=bool(value),distance=distance))
out=m.root/'backups/animations/native-camera-keyhole-observations.json'
out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,rows=rows),indent=2)+'\n')
print(json.dumps(dict(rows=len(rows),output=str(out))))
