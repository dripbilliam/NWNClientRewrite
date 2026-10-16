"""Untouched property enumeration, validity/scalar and pool-membership
wrappers. VM/object casts, constructors, allocation and pool-index queries
are captured. Native cursor, exposure/icon/duration guards, INT comparisons
and scalar dispatch execute; full item-property creation/application is separate.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);app,item,pool,storage,effect,ints,vtable,allocated=[m.heap+n*0x1000 for n in range(1,9)]
def hook(u,a,n,_):
    global output
    if a==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a in [0x140286160,0x140286110]:m.wi(y,99 if a==0x140286160 else c.get('query',1));m.finish(1)
    elif a==0x140286030:m.wq(z,effect if c.get('exists',True) else 0);m.finish(1)
    elif a==0x140286330:output=dict(type=int.from_bytes(u.mem_read(z+8,2),'little'),index=(z-storage)//0x200 if storage<=z<storage+0x1000 else None);m.finish(1)
    elif a==0x140286410:output=y&0xffffffff;m.finish(1)
    elif a==0x14055b4c0:m.finish(item if c.get('exists',True) else 0)
    elif a==0x14055b6c0:m.finish(item if c.get('exists',True) and c.get('objectType',6)==6 else 0)
    elif a==m.stop+0x10:m.finish(item if c.get('objectType',6)>4 else 0)
    elif a==m.stop+0x20:m.finish(item if c.get('objectType',6)==6 else 0)
    elif a==0x140c10324:m.finish(allocated)
    elif a==0x1404233d0:m.wq(x+0x48,ints);m.finish(x)
    elif a in [0x140423770,0x140c10360,0x140c4f024]:m.finish()
    elif a in [0x1404686d0,0x140468ef0]:
        source=c.get('active' if a==0x1404686d0 else 'passive',[]);value=source[y&0xffffffff];m.wi(allocated,value or 0);m.finish(allocated if value is not None else 0)
    elif not any(lo<=a<hi for lo,hi in [(0x140528e60,0x140529060),(0x140529240,0x1405293d0),(0x1405294b0,0x14052954b),(0x140533570,0x140533600),(0x1405282e0,0x1405283e6),(0x140423fc0,0x140423fcb)]):raise AssertionError(f'Uncaptured property query dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,output
    c=case;output=None;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df910,app);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(item,vtable);u.mem_write(item+0xc,bytes([c.get('objectType',6)]));m.wq(vtable+0x20,m.stop+0x10);m.wq(vtable+0x70,m.stop+0x20)
    m.wq(item+0x150,pool);m.wi(item+0x158,len(c.get('effects',[])));u.mem_write(item+0x248,struct.pack('<H',c.get('cursor',0)&65535));m.wi(item+0x370,len(c.get('active',[])));m.wi(item+0x380,len(c.get('passive',[])))
    for i,e in enumerate(c.get('effects',[])):
        ptr=storage+i*0x200;m.wq(pool+i*8,ptr);u.mem_write(ptr+8,struct.pack('<HH',e['type']&65535,e['durationType']&65535));m.wi(ptr+0x20,e['exposed'])
    u.mem_write(effect+8,struct.pack('<HH',c.get('type',91)&65535,c.get('durationType',0)&65535));m.wq(effect+0x48,ints)
    for i,value in enumerate(c.get('integers',[-1,2,3,4,5,6,7,8])):m.wi(ints+i*4,value)
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,app);u.reg_write(UC_X86_REG_RDX,c.get('ordinal',612));u.reg_write(UC_X86_REG_R8,1)
    entry={'enumerate':0x140528e60,'valid':0x140533570,'value':0x1405294b0 if c.get('ordinal')==614 else 0x1405292e0,'has':0x1405282e0,'duration':0x140529240}[c['mode']]
    u.emu_start(entry,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    if isinstance(output,int) and output>=0x80000000:output-=0x100000000
    return dict(case=c,output=output,cursor=int.from_bytes(u.mem_read(item+0x248,2),'little'))
rows=[]
for ordinal,cursor,type,duration,exposed in itertools.product([612,613],[0,1,4],[0,30,67,91],[0,1,2,3,9],[0,1]):rows.append(run(dict(mode='enumerate',ordinal=ordinal,cursor=cursor,effects=[dict(type=type,durationType=duration,exposed=exposed),dict(type=91,durationType=2,exposed=1)])))
for mode,type,exists in itertools.product(['valid','value'],[0,30,91,65535],[False,True]):
    for ordinal in ([614,734,769,770,771,772,0] if mode=='value' else [615]):rows.append(run(dict(mode=mode,type=type,exists=exists,ordinal=ordinal)))
for type,exists,query in itertools.product([3,5,6,9],[False,True],[-1,0,1,2,65535,65536,65537]):rows.append(run(dict(mode='has',objectType=type,exists=exists,query=query,active=[None,1],passive=[2,65535])))
for type,exists,duration in itertools.product([0,30,91,65535],[False,True],range(16)):rows.append(run(dict(mode='duration',type=type,exists=exists,durationType=duration,ordinal=615)))
out=m.root/'backups/animations/native-item-property-query-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
