"""Read-only full creature/placeable body-bag appearance and script queries.
Physical table GetINT, string allocation, VM pops and canonical lookups are
captured; native short circuits, fallbacks, raw query rows and BYTE writes run.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
actor,placeable,app,rules,tables,bodybag,appearance,vm,string=[m.heap+n*0x1000 for n in range(9)]
ranges=[(0x140390230,0x14039041c),(0x1404b3b80,0x1404b3d63),(0x14053e2f0,0x14053e437),(0x14051fa50,0x14051fadf)]
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==0x140c10370:finish()
    elif a==0x140c10368:finish(string)
    elif a==0x1401a7010:
        name='bodybag' if x==bodybag else 'appearance';ptr=q(z);column=bytes(u.mem_read(ptr,16)).split(b'\0')[0].decode();row=y&0xffffffff;row=row if row<0x80000000 else row-0x100000000
        calls.append(['entry',name,row,column]);entry=c['entries'][min(query,len(c['entries'])-1)];state['query']+=1;wi(w,entry['value']);finish(entry['found'])
    elif a==0x140286160:wi(y,77);finish(1)
    elif a==0x140286110:wi(y,c['requested']);finish(1)
    elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);finish(actor if c['creature'] else 0)
    elif a==0x14055b890:calls.append(['placeable',y&0xffffffff]);finish(placeable if c['placeable'] else 0)
    elif a==0x140286410:state['result']=y&0xffffffff;finish(1)
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped corpse bag dependency {a:x}')
def wrapper(u,a,n,_):
    global query
    query=state['query'];return hook(u,a,n,_)
u.hook_add(UC_HOOK_CODE,wrapper)
def run(case):
    global c,calls,state
    c=case;calls=[];state={'query':0};u.mem_write(m.heap,bytes(0x100000));wq(0x1412df8f8,rules);wq(rules+0x130,tables);wq(tables+0x3f8,bodybag);wq(tables+0x100,appearance);wq(0x1412df970,app);wq(app+8,app);wq(0x1412df910,vm)
    wi(actor+0x4e8,c['lootable']);u.mem_write(actor+0x8a8,bytes([c['bag']&255]));u.mem_write(placeable+0x59c,bytes([c['bag']&255]));u.mem_write(actor+0xa74,struct.pack('<H',c['appearance']&65535));u.mem_write(placeable+0x32c,struct.pack('<H',c['appearance']&65535))
    address={'creature':0x140390230,'placeable':0x1404b3b80,'set':0x14053e2f0,'get':0x14051fa50}[c['mode']]
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,placeable if c['mode']=='placeable' else actor)
    u.emu_start(address,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    result=state.get('result',u.reg_read(UC_X86_REG_RAX)&65535)
    if c['mode']=='get' and result>=0x80000000:result-=0x100000000
    return dict(case=c,result=result,calls=calls,creatureBag=int.from_bytes(u.mem_read(actor+0x8a8,1),'little'),placeableBag=int.from_bytes(u.mem_read(placeable+0x59c,1),'little'))
entry=lambda found,value:dict(found=found,value=value)
default=dict(mode='creature',lootable=0,bag=3,appearance=17,requested=3,creature=True,placeable=False,entries=[entry(1,33)])
selectors=[run(default|dict(mode=mode,lootable=lootable,bag=bag,entries=entries)) for mode,lootable,bag,entries in itertools.product(['creature','placeable'],[0,1,2],[-1,0,3,259],[[entry(1,33)],[entry(1,-1)],[entry(1,65539)],[entry(0,999),entry(1,-2),entry(1,9)],[entry(0,111),entry(0,888),entry(0,999)],[entry(0,999),entry(0,888),entry(1,-1)]])]
setters=[run(default|dict(mode='set',requested=requested,creature=creatureFlag,placeable=placeableFlag,entries=[entry(found,333)])) for requested,creatureFlag,placeableFlag,found in itertools.product([-1,0,3,256,259,2147483647],[False,True],[False,True],[0,1])]
getters=[run(default|dict(mode='get',bag=bag,creature=creatureFlag,placeable=placeableFlag)) for bag,creatureFlag,placeableFlag in itertools.product([-1,0,3,259],[False,True],[False,True])]
out=m.root/'backups/animations/native-corpse-bag-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,selectors=selectors,setters=setters,getters=getters),indent=2));print(json.dumps(dict(output=str(out),selectors=len(selectors),setters=len(setters),getters=len(getters))))
