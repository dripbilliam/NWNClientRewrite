"""Read-only CheckFit oracle, build89.8193.37-17. Synthetic repositories/items
substitute lookup/list helpers; the complete original fit body executes. This
does not validate item acquisition, stacking, expansion or possession events.
"""
from pathlib import Path
import sys,hashlib,struct,json,itertools
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
uc=Uc(UC_ARCH_X86,UC_MODE_64);uc.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095)
uc.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
uc.mem_map(heap,0x10000);uc.mem_map(stack,0x10000);uc.mem_map(stop,0x1000)
repo,item,info,app,linked,vt=[heap+n for n in [0,0x1000,0x2000,0x3000,0x4000,0x5000]]
def q(a):return struct.unpack('<Q',uc.mem_read(a,8))[0]
def wi(a,v):uc.mem_write(a,struct.pack('<I',v&0xffffffff))
def wb(a,v):uc.mem_write(a,bytes([v&255]))
def wq(a,v):uc.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=uc.reg_read(UC_X86_REG_RSP);uc.reg_write(UC_X86_REG_RIP,q(rsp));uc.reg_write(UC_X86_REG_RSP,rsp+8);uc.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
case={};lookups=[];substitutions=set()
def hook(uc,a,n,_):
    if a==stop:uc.emu_stop();return
    x,y,z=[uc.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x14029ca00:finish(info if y==1 else info+0x100)
    elif a==0x14055b850:finish(app+0x100)
    elif a==0x1401690b0:finish(y+8)
    elif a==0x140169110:wq(y,q(q(y)));finish()
    elif a==0x140296470:
        lookups.append(y);index=next((i for i,r in enumerate(case['items']) if r['id']==y),None)
        if index is None or case['items'][index].get('stale',False):finish(1)
        else:wq(z,heap+0x6000+index*0x1000);finish(0)
    elif a==stop+0x100:finish(x if q(x+0x10)==6 else 0)
    elif not 0x140465c10<=a<0x140465e59:raise RuntimeError(f'Unmapped repository dependency {a:x}')
    else:return
    substitutions.add(hex(a))
uc.hook_add(UC_HOOK_CODE,hook)
pools=[[],[{'id':2,'type':6,'x':0,'y':0,'width':2,'height':2}],
 [{'id':2,'type':6,'x':0,'y':0,'width':10,'height':6}],
 [{'id':2,'type':6,'x':8,'y':5,'width':2,'height':2}],
 [{'id':1,'type':6,'x':0,'y':0,'width':2,'height':2},{'id':3,'type':6,'stale':True},
  {'id':4,'type':5,'x':0,'y':0},{'id':2,'type':6,'x':255,'y':255,'width':2,'height':2}]]
observations=[]
for x,y,(width,height),items in itertools.product([0,8,9,10,255],[0,4,5,6,35,36,255],[(1,1),(1,2),(2,1),(2,2),(0,0),(255,255)],pools):
    case={'x':x,'y':y,'width':width,'height':height,'items':items};lookups=[]
    uc.mem_write(heap,bytes(0x10000));wq(0x1412df8f8,app);wq(0x1412df970,app);wq(app+0x20,app+0x200);wq(app+8,app+0x300)
    wb(repo,10);wb(repo+1,36);wi(repo+4,60);wq(repo+0x10,linked)
    wi(item+0x40,1);wi(item+0x50,1);wb(info+0x14,width);wb(info+0x15,height);wq(vt+0x70,stop+0x100)
    wq(linked,heap+0xb000 if items else 0)
    for i,r in enumerate(items):
        node=heap+0xb000+i*0x20;wq(node,node+0x20 if i+1<len(items) else 0);wi(node+8,r['id'])
        obj=heap+0x6000+i*0x1000;wq(obj,vt);wq(obj+0x10,r['type']);wi(obj+0x40,2);wi(obj+0x50,r['id'])
        wb(obj+0x3d8,r.get('x',0));wb(obj+0x3d9,r.get('y',0));wb(info+0x114,r.get('width',2));wb(info+0x115,r.get('height',2))
    rsp=stack+0xff08;uc.mem_write(rsp,bytes(0x80));wq(rsp,stop)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[repo,item,x,y]):uc.reg_write(reg,value)
    uc.reg_write(UC_X86_REG_RSP,rsp);uc.emu_start(0x140465c10,stop,count=10000)
    assert uc.reg_read(UC_X86_REG_RIP)==stop
    observations.append({**case,'result':uc.reg_read(UC_X86_REG_RAX)&0xffffffff,'lookups':lookups})
output=root/'backups/animations/native-repository-fit-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'substitutions':sorted(substitutions),'observations':observations},indent=2))
print(json.dumps({'output':str(output),'observations':len(observations)}))
