"""Execute complete unchanged Gob::AttachToObject14008c540..14008c6eb.
Named-part lookup, world-pose getter, allocation, five behavior constructors,
behavior setter and SetScene are explicit captured lower boundaries. This proves
the caller's missing-anchor/control flow, not part lookup or GPU pixel parity.
Read-only original hash-gated image in isolated Unicorn; no live process edits.
"""
import importlib, itertools, json, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
owner,parent,part,owner_vt,parent_vt,part_vt,name_ptr,behavior=[m.heap+n*0x1000 for n in range(1,9)]
constructors={0x140053b30:0,0x140053d70:1,0x140053d40:2,0x140053d10:3,0x140053ce0:4}
def hook(u,address,size,data):
    if address==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if address==m.stop+0x10:
        assert x==parent
        calls.append(['lookup',bytes(u.mem_read(y,32)).split(b'\0')[0].decode()]);m.finish(part if case['part'] else 0)
    elif address==m.stop+0x20:
        assert x==part and y==owner+0xa8 and z==owner+0xb4
        calls.append(['pose'])
        for index,value in enumerate([11.,12.,13.,.1,.2,.3,1.]):m.wf(y+index*4,value)
        m.finish()
    elif address==m.stop+0x30:
        assert x==owner;calls.append(['behavior',bool(y)]);m.wq(owner+0x300,y);m.finish()
    elif address==0x140c10324:
        calls.append(['allocate',x]);m.finish(behavior if case['allocation'] else 0)
    elif address in constructors:
        assert [x,y,z,w]==[behavior,owner,parent,part]
        calls.append(['constructor',constructors[address]]);m.finish(behavior)
    elif address==0x140095250:
        assert x==owner and y==0x12345678
        calls.append(['scene']);m.wq(owner+0x88,y);m.finish()
    elif not 0x14008c540<=address<=0x14008c6eb:raise AssertionError(hex(address))
u.hook_add(UC_HOOK_CODE,hook)
def run(value):
    global case,calls
    case=value;calls=[]
    u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
    for ptr,vt in [(owner,owner_vt),(parent,parent_vt),(part,part_vt)]:m.wq(ptr,vt)
    m.wq(owner_vt+0xa8,m.stop+0x30);m.wq(parent_vt+0x230,m.stop+0x10);m.wq(part_vt+0x18,m.stop+0x20)
    m.wq(parent+0x90,part if case['part'] else 0);m.wq(parent+0x88,0x12345678)
    m.wq(owner+0x88,0x87654321);m.wq(owner+0x300,0x11111111)
    for index,value in enumerate([1.,2.,3.,0.,0.,0.,1.]):m.wf(owner+0xa8+index*4,value)
    if case['name'] is not None:u.mem_write(name_ptr,case['name'].encode()+b'\0')
    sp=m.stack+0x1fc08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[owner,parent if case['parent'] else 0,name_ptr if case['name'] is not None else 0,case['flags']&0xffffffff]):u.reg_write(reg,value)
    u.emu_start(0x14008c540,m.stop,count=10000)
    assert u.reg_read(UC_X86_REG_RIP)==m.stop
    admitted=case['parent'] and case['part']
    if not admitted:
        assert calls==([['lookup',case['name']]]if case['parent']and case['name']is not None else [])+[['behavior',False]]
        assert m.q(owner+0x88)==0x87654321
        assert [m.rf(owner+0xa8+index*4)for index in range(3)]==[1.,2.,3.]
        assert u.reg_read(UC_X86_REG_RAX)==0 and m.q(owner+0x300)==0
    else:
        assert calls[-1]==['scene'] and m.q(owner+0x88)==0x12345678
    return {'case':case,'calls':calls,'attached':bool(u.reg_read(UC_X86_REG_RAX)),'sceneChanged':m.q(owner+0x88)!=0x87654321,'pose':[m.rf(owner+0xa8+i*4)for i in range(7)]}
rows=[run(dict(parent=parent_ok,part=part_ok,name=name,flags=flags,allocation=allocation))for parent_ok,part_ok,name,flags,allocation in itertools.product([False,True],[False,True],[None,'lhand',''],[-1,0,1,2,3,4,5],[False,True])]
output=m.root/'backups/animations/native-world-attachment-admission-v1.json'
assert not output.exists()
output.write_text(json.dumps(dict(binarySha256=m.digest,function='0x14008c540..0x14008c6eb',scope=__doc__,rows=rows),indent=2)+'\n')
print(json.dumps(dict(output=str(output),cases=len(rows),missingAnchorCases=sum(not row['case']['parent']or not row['case']['part']for row in rows))))
