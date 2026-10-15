"""Original Add/RemoveLoopingVisualEffect list owners. Transform map
constructor/copy/equality/free and array allocation are captured boundaries.
Native field widths, growth, reverse duplicate search, count mutation and
record shifts execute unchanged. Constant scope0 only; no controller import.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);actor,records,argument=m.heap,m.heap+0x1000,m.heap+0x9000
def hook(u,a,n,_):
    global allocation
    if a==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x140368530:allocation+=1;ptr=m.heap+0x10000+allocation*0x100; m.wq(ptr,ptr);m.wq(x,ptr);m.finish(ptr)
    elif a in [0x140369220,0x140369860,0x140c10360]:m.finish()
    elif a in [0x14048ae40,0x1403591a0]:u.mem_write(x,bytes(u.mem_read(y,16)));m.finish(x)
    elif a==0x14048e1c0:m.wi(x+12,y);m.finish()
    elif a==0x14048aef0:m.finish(int(x==z))
    elif not any(lo<=a<hi for lo,hi in [(0x14048da00,0x14048db90),(0x140498960,0x140498ae1)]):raise AssertionError(f'Uncaptured looping visual dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global allocation
    allocation=0;u.mem_write(m.heap,bytes(0x100000));m.wq(actor+0x160,records);m.wi(actor+0x168,len(case['rows']));m.wi(actor+0x16c,case['capacity'])
    def store(ptr,row):
        id,source,body,token=row;u.mem_write(ptr,struct.pack('<H',id&65535));m.wi(ptr+4,source);u.mem_write(ptr+8,bytes([body&255]));m.wq(ptr+16,argument+token*0x100);m.wq(argument+token*0x100,argument+token*0x100);m.wq(ptr+24,1)
    for i,row in enumerate(case['rows']):store(records+i*32,row)
    id,source,body,token=case['value'];m.wq(argument,argument+token*0x100);m.wq(argument+8,1);m.wq(argument+token*0x100,argument+token*0x100)
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);m.wi(rsp+0x20,0);m.wq(rsp+0x28,argument);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[actor,id&0xffffffff,source&0xffffffff,body&0xffffffff]):u.reg_write(reg,value)
    u.emu_start(0x14048da00 if case['mode']=='add' else 0x140498960,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    result=[]
    for i in range(m.si(actor+0x168)):
        ptr=records+i*32;result.append([int.from_bytes(u.mem_read(ptr,2),'little'),m.si(ptr+4)&0xffffffff,u.mem_read(ptr+8,1)[0],(m.q(ptr+16)-argument)//0x100])
    return dict(case=case,rows=result,capacity=m.si(actor+0x16c))
rows=[]
for count,capacity in [(0,0),(0,16),(1,16),(16,16),(17,32),(32,32)]:
    for id,source,body in [(1,99,0),(65537,-1,257),(-1,0,255)]:rows.append(run(dict(mode='add',rows=[[i,10+i,0,1] for i in range(count)],capacity=capacity,value=[id,source,body,2])))
for recordsInput in [[],[[1,99,0,1]],[[1,99,0,1],[2,100,1,2],[1,99,0,1],[3,101,0,1]],[[2,100,1,2],[1,99,0,1],[3,101,0,1]]]:
    for value in itertools.product([1,2,65537],[99,100,-1],[0,1,256],[1,2]):rows.append(run(dict(mode='remove',rows=recordsInput,capacity=16,value=list(value))))
out=m.root/'backups/animations/native-looping-visual-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
