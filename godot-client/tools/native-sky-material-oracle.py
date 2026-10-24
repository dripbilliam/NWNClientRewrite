"""Execute original PartTriMesh::Mat1400a2f50 for sky/fade object flags.
Synthetic mesh/material/scene pointers; texture/custom-shader/driver operations
are explicit lower boundaries. Captures original color/alpha and blend-mode
requests, plus the actual GL blend table. No GPU or live process mutation.
"""
import sys,importlib,struct,json,itertools
from pathlib import Path
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'scripts'))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
part,gob,node,model,material,scene=[m.heap+n*0x1000 for n in range(6)]
calls=[]
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def hook(u,a,n,data):
 if a==m.stop:u.emu_stop();return
 if a==0x1400bf050:calls.append(dict(kind='color',value=[xmm(r) for r in [UC_X86_REG_XMM0,UC_X86_REG_XMM1,UC_X86_REG_XMM2,UC_X86_REG_XMM3]]));m.finish();return
 if a==0x1400beff0:calls.append(dict(kind='blend',value=[u.reg_read(UC_X86_REG_RCX)&0xffffffff,u.reg_read(UC_X86_REG_RDX)&0xffffffff]));m.finish();return
 if a==0x140085790:calls.append(dict(kind='material-blend'));m.finish();return
 if a in [0x140082630,0x140082b80,0x1400be9e0,0x1400bea90,0x1400beb30,0x1400bee10]:m.finish(0);return
 if 0x1400a2f50<=a<0x1400a3270:return
 raise RuntimeError('Unexpected original sky material dependency '+hex(a))
u.hook_add(UC_HOOK_CODE,hook)
rows=[];fog=[.125,.375,.75]
for sky,fade,alpha,weight in itertools.product([0,1],[0,1],[.5,1],[0,.25,.5,1]):
 calls=[];u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(part+8,node);m.wq(part+0x50,gob);m.wq(part+0x58,material);m.wq(gob+0x68,model);m.wq(0x14140ac50,scene);m.wf(part+0xa8,alpha);m.wf(gob+0x108,weight);u.mem_write(gob+0x18,bytes([sky,fade]))
 for index,v in enumerate(fog):m.wf(scene+0x14c+index*4,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,part);u.emu_start(0x1400a2f50,m.stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 rows.append(dict(case=dict(sky=sky,fade=fade,alpha=alpha,weight=weight),calls=calls))
table=list(struct.unpack('<8I',u.mem_read(0x140d8aca0,32)))
out=Path(sys.argv[1]);assert not out.exists();out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,fog=fog,blendTable=table,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out),blendTable=table)))
