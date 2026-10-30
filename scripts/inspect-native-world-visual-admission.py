"""Run complete immutable original placeable/door/trigger visual loaders.
NewCAurObject and CResRef assignment are captured lower providers. Instrumentation
is disabled, not patched in the original image. This proves each caller's null
result bookkeeping, not lower model parsing, full replication or retry policy.
"""
import importlib,itertools,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
owner,name_ptr,model=[m.heap+n*0x1000 for n in range(1,4)]
bodies={'placeable':(0x1409b2630,0x1409b28a2),'door':(0x1409b0cf0,0x1409b0f73),'trigger':(0x1409b16d0,0x1409b1942)}
def text_at(address):return bytes(u.mem_read(address,64)).split(b'\0')[0].decode('ascii')
def hook(u,address,size,data):
    if address==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if address==0x1400931f0:
        calls.append(['NewCAurObject',text_at(x),text_at(y),z]);m.finish(model if case['loaded'] else 0)
    elif address==0x14018de80:
        assert x==owner+0x30 and y==name_ptr
        calls.append(['assign',text_at(y)]);u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x)
    elif address==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
    elif not any(lo<=address<=hi for lo,hi in bodies.values()):raise AssertionError(hex(address))
u.hook_add(UC_HOOK_CODE,hook)
def run(value):
    global case,calls
    case=value;calls=[]
    u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
    u.mem_write(0x14141e310,b'\0\0')
    u.mem_write(name_ptr,case['name'].encode()+b'\0')
    u.mem_write(owner+0x30,b'previous_model\0\0\0')
    m.wi(owner+0x44,123);m.wq(owner+0xc8,0x12345678)
    sp=m.stack+0x1fc08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[owner,name_ptr,case['mode']]):u.reg_write(reg,value)
    u.emu_start(bodies[case['kind']][0],m.stop,count=10000)
    assert u.reg_read(UC_X86_REG_RIP)==m.stop
    attempted=case['kind']!='door' or case['mode']==255
    loaded=attempted and case['loaded']
    assert u.reg_read(UC_X86_REG_RAX)&255==int(loaded),(case,hex(u.reg_read(UC_X86_REG_RAX)),calls)
    assert m.q(owner+0xc8)==(model if loaded else 0) if attempted else m.q(owner+0xc8)==0x12345678
    assert m.si(owner+0x44)==(0 if loaded else 123)
    assert text_at(owner+0x30)==(case['name'] if loaded else 'previous_model')
    assert calls==([['NewCAurObject',case['name'],case['kind'],0]] if attempted else [])+([['assign',case['name']]] if loaded else [])
    return dict(case=case,result=loaded,attempted=attempted,calls=calls,modelSlot=m.q(owner+0xc8),resref=text_at(owner+0x30),field44=m.si(owner+0x44))
rows=[run(dict(kind=kind,name=name,loaded=loaded,mode=mode)) for kind,name,loaded,mode in itertools.product(bodies,['','nw_dummy','abcdefghijklmnop'],[False,True],[0,1,255])]
out=m.root/'backups/animations/native-world-visual-admission-v1.json';assert not out.exists()
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,bodies=bodies,rows=rows),indent=2)+'\n')
print(json.dumps(dict(cases=len(rows),output=str(out))))
