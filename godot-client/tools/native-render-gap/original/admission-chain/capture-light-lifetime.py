"""Bounded original light-factory -> leaf PartLight destruction instruction proof.

Unchanged original constructor, deleting destructor, and Part base destructor.
Only allocation/light-list append/free lower providers are replaced. This proves
leaf destruction preserves the owning Gob flag; it is not a sole-writer audit,
descendant/custom-material callback proof, room census or performance result.
"""
from pathlib import Path
import sys, importlib, hashlib, json
root=Path(__file__).resolve().parents[5]
sys.path.insert(0,str(root/'scripts'))
m=importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_RSP, UC_X86_REG_RIP
assert m.digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
u=m.u;u.hook_del(m.hook_handle)
light,gob,part=[m.heap+n for n in (0,0x2000,0x4000)]
ranges=[(0x140092b10,0x140092c74),(0x14008ac40,0x14008ac74),(0x140089d20,0x140089de3)]
vtable=0x140d88008
assert int.from_bytes(u.mem_read(vtable,8),'little')==ranges[1][0]
phase='';calls=[];accesses=[];visits=set()
def hook(uc,pc,size,unused):
    if pc==m.stop:uc.emu_stop();return
    x,y=[uc.reg_read(reg) for reg in (UC_X86_REG_RCX,UC_X86_REG_RDX)]
    if pc==0x140c10324:
        assert x==0xc0;calls.append(['allocate',x]);m.finish(part)
    elif pc==0x14007db60:
        assert x==gob+0x470 and y==part;calls.append(['append',x,y]);m.finish()
    elif pc==0x140c10360:
        assert x==part and y==0xc0;calls.append(['free',x,y]);m.finish()
    elif pc==0x140c4f024:
        assert x==0;calls.append(['free_null_array',x]);m.finish()
    elif any(a<=pc<b for a,b in ranges):visits.add(pc)
    else:raise RuntimeError('Unexpected original dependency '+hex(pc))
def memory(uc,kind,address,size,value,unused):
    if phase=='destructor':accesses.append(dict(kind=kind,address=hex(address),size=size,value=value))
u.hook_add(UC_HOOK_CODE,hook)
u.hook_add(UC_HOOK_MEM_READ|UC_HOOK_MEM_WRITE,memory,begin=gob+0xf0,end=gob+0xf3)
def invoke(pc,first,second):
    rsp=m.stack+0x1fe08;m.wq(rsp,m.stop)
    u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,first);u.reg_write(UC_X86_REG_RDX,second)
    u.emu_start(pc,m.stop,count=20000)
    assert u.reg_read(UC_X86_REG_RIP)==m.stop
rows=[]
for dynamic,affect,initial in [(0,0,0),(1,0,0),(0,1,0),(1,1,0),(0,0,7),(1,0,7)]:
    for delete_flag in [0,1]:
        u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));calls.clear();accesses.clear();visits.clear()
        m.wi(light+0x100,dynamic);m.wi(light+0x104,affect);m.wi(gob+0xf0,initial)
        phase='factory';invoke(ranges[0][0],light,gob)
        before=m.si(gob+0xf0);m.wq(part+0x50,gob)
        assert int.from_bytes(u.mem_read(part,8),'little')==vtable
        phase='destructor';invoke(ranges[1][0],part,delete_flag)
        after=m.si(gob+0xf0)
        assert before==after and accesses==[]
        assert any(c[0]=='free' for c in calls)==bool(delete_flag)
        rows.append(dict(dynamic=dynamic,affect=affect,initialF0=initial,beforeDestroyF0=before,afterDestroyF0=after,deleteFlag=delete_flag,ownerFlagAccesses=list(accesses),calls=list(calls),originalInstructions=len(visits)))
out=root/'godot-client/.cache/native-render-gap/original/admission-chain/light-lifetime-instructions-a.json'
assert not out.exists(),'Preserve observations'
result=dict(version=1,success=True,subjectSha256=m.digest,vtable=dict(address=hex(vtable),deletingDestructor=hex(ranges[1][0]),bytes=bytes(u.mem_read(vtable,8)).hex()),functions=[dict(address=hex(a),end=hex(b),sha256=hashlib.sha256(bytes(u.mem_read(a,b-a))).hexdigest()) for a,b in ranges],rows=rows,limits=__doc__,scope='Actual original leaf PartLight destruction neither reads nor clears Gob+f0, after qualifying light creation or for preexisting nonzero flag. Do not derive f0 from only currently retained or admitted Godot lights. Other producers/clearers and native Gob/append/reference lifetime mapping remain open.')
out.write_text(json.dumps(result,indent=2));print(json.dumps(dict(output=str(out),sha256=hashlib.sha256(out.read_bytes()).hexdigest(),cases=len(rows))))
