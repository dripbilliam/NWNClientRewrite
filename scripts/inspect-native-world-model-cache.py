"""Execute complete original FindModel140098cd0..140098fd8.
BinarySearchModel, synchronous model I/O, model cast, ASCII comparison and log
are captured providers. This proves cache-hit/load/failure routing and temporary
currentmodel restoration, not the lower parser/cache eviction or async scheduler.
Read-only hash-gated original instructions, no live process changes or assets.
"""
import importlib,itertools,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
name_ptr,model,tree,dispatcher,old_model=[m.heap+n*0x1000 for n in range(1,6)]
def cstr(ptr):return bytes(u.mem_read(ptr,128)).split(b'\0')[0].decode('ascii')
def hook(u,address,size,data):
    if address==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if address==0x140c9a9fc:m.finish(0 if cstr(x).lower()==cstr(y).lower() else 1)
    elif address==0x140098ba0:calls.append('cached-lookup');m.finish(model if case['cached']else 0)
    elif address==0x140079630:calls.append('dispatcher');m.finish(dispatcher)
    elif address==0x140079f70:
        assert x==dispatcher and y==name_ptr and m.q(0x141301ae0)==0
        calls.append('read-sync')
        if case['load']=='current':m.wq(0x141301ae0,model)
        m.finish(tree if case['load']in['tree','failed-cast']else 0)
    elif address==0x14008c3a0:calls.append('cast');m.finish(0 if case['load']=='failed-cast'else model)
    elif address==0x140115890:calls.append('warning');m.finish()
    elif not 0x140098cd0<=address<=0x140098fd8:raise AssertionError(hex(address))
u.hook_add(UC_HOOK_CODE,hook)
def run(value):
    global case,calls
    case=value;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
    u.mem_write(0x14141e310,b'\0');m.wq(0x141301ae0,old_model);m.wq(0x1412e1020,0)
    if case['name']is not None:u.mem_write(name_ptr,case['name'].encode()+b'\0')
    u.mem_write(model+0x10,('other'if case['differentName']else 'cachemodel').encode()+b'\0')
    m.wi(0x1413018c0,5)
    sp=m.stack+0x1fc08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,name_ptr if case['name']is not None else 0)
    u.emu_start(0x140098cd0,m.stop,count=10000)
    assert u.reg_read(UC_X86_REG_RIP)==m.stop and m.q(0x141301ae0)==old_model
    result=u.reg_read(UC_X86_REG_RAX)
    if case['name']is None or case['name'].lower()=='null':assert result==0 and calls==[]
    elif case['cached']:assert result==model and calls==['cached-lookup']
    else:
        assert calls[:3]==['cached-lookup','dispatcher','read-sync']
        assert (result==model)==(case['load']in['tree','current'])
        assert ('warning'in calls)==(result==model and case['differentName'])
    return dict(case=case,model=bool(result),calls=calls,currentRestored=m.q(0x141301ae0)==old_model)
rows=[run(dict(name=name,cached=cached,load=load,differentName=different))for name,cached,load,different in itertools.product([None,'NULL','null','cachemodel','CacheModel'],[False,True],['failed','tree','current','failed-cast'],[False,True])]
output=m.root/'backups/animations/native-world-model-cache-v1.json';assert not output.exists()
output.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,rows=rows),indent=2)+'\n')
print(json.dumps(dict(cases=len(rows),output=str(output))))
