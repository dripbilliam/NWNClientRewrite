"""Read-only native RunUnequip, pending equipment conversion and eligibility.
Original owners execute unchanged; inventory, repository fit/acquisition, item
mutation, client and disposal helpers are captured. Not full item/effect parity.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
actor,app,client,gui,msg,repo,inventory,other,bag,otherRepo,round,wrapper,listOwner,nodes,actions,baseInfo=[m.heap+n*0x4000 for n in range(16)]
items={n:m.heap+0x60000+(n-99)*0x1000 for n in [99,100,101]}
ranges=[(0x14039fff0,0x1403a059f),(0x14039be00,0x14039bf7d),(0x1403d22b0,0x1403d240a)]
def itemid(ptr):return si(ptr+0x50)&0xffffffff
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x14055b390:calls.append(['client',y&0xffffffff]);finish(client if c.get('client') else 0)
    elif a==0x14055b810:calls.append(['message']);finish(msg if c.get('message') else 0)
    elif a==0x14055b6c0:
        id=y&0xffffffff;calls.append(['item',id]);finish((items.get(id,0) if c.get('exists',True) else 0) if id!=88 else bag if c.get('bag') else 0)
    elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);finish(other if c.get('other') else 0)
    elif a==0x140462b40:calls.append(['inEquipment',itemid(y)]);finish(c['inEquipment'])
    elif a==0x1403d22b0:calls.append(['gate',itemid(y)]);finish(c['gate'])
    elif a==0x140462bd0:calls.append(['slot',y&0xffffffff]);finish(items.get(slots.get(y&0xffffffff),0))
    elif a==0x14029ca00:calls.append(['base',y&0xffffffff]);finish(baseInfo)
    elif a==0x1403a6150:
        id=itemid(y);calls.append(['unequip',id,z&0xffffffff,w&0xffffffff])
        for slot,value in list(slots.items()):
            if value==id:del slots[slot]
        finish(c.get('unequipResult',1))
    elif a==0x14038c1c0:calls.append(['equip',y&0xffffffff,itemid(z),w&0xffffffff,si(rsp+0x28),si(rsp+0x30)]);slots[y&0xffffffff]=itemid(z);finish()
    elif a==0x140464200 or a==0x1403cff30:
        id=itemid(q(y));kind='add' if a==0x140464200 else 'acquire'
        if kind=='add':calls.append([kind,'self' if x==repo else 'destination',id,z&255,w&255,si(rsp+0x28),si(rsp+0x30)])
        else:calls.append([kind,id,z&0xffffffff,w&0xffffffff,si(rsp+0x28)&255,si(rsp+0x30)&255,si(rsp+0x38),si(rsp+0x40)])
        ptr=items[c.get('replacedId',99)];wq(y,ptr);u.mem_write(ptr+0x3d8,bytes([9,13]));finish(c['placed'])
    elif a==0x1403d7490:calls.append(['removeItem',itemid(y),z&0xffffffff,w&0xffffffff,si(rsp+0x28),si(rsp+0x30)]);finish()
    elif a==0x140494e80:calls.append(['area']);finish(app)
    elif a==0x140464bb0:calls.append(['drop',itemid(x)]);finish()
    elif a==0x14046c520:calls.append(['possessor',itemid(x),y&0xffffffff,z&0xffffffff,w&0xffffffff,si(rsp+0x28)]);wi(x+0x3c8,y);finish()
    elif a==0x1404656a0:calls.append(['page',y&255,z&255]);finish(c['page'])
    elif a==0x1404daa40:calls.append(['select',z&255]);finish()
    elif a==0x1404beb40:calls.append(['setPanel',z&255]);u.mem_write(gui+0xc,bytes([z&255]));finish()
    elif a==0x1404daae0:calls.append(['unequipped',z&0xffffffff,w&0xffffffff]);finish()
    elif a==0x1404da5b0:calls.append(['equipped',z&0xffffffff,w&0xffffffff,si(rsp+0x28)]);finish()
    elif a==0x1404dab80:calls.append(['cancel',z&0xffffffff,w&0xffffffff]);finish()
    elif a==0x140375de0:calls.append(['pending']);finish(c['pending'])
    elif a==0x1401690b0:finish(actions+(y-nodes)//32*0x100)
    elif a==0x140169180:
        index=(q(y)-nodes)//32;at=links.index(index)-1;previous=links[at] if at>=0 else -1
        calls.append(['previous',index]);wq(y,nodes+previous*32 if previous>=0 else 0);finish(actions+previous*0x100 if previous>=0 else 0)
    elif a==0x1401691f0:index=(y-nodes)//32;calls.append(['remove',index]);links.remove(index);finish()
    elif a==0x140374270:calls.append(['dispose',(x-actions)//0x100]);finish()
    elif a==0x140c10360:finish()
    elif a==0x14037eb50:calls.append(['addEquip',itemid(y),z&0xffffffff,w&0xffffffff,si(rsp+0x28),si(rsp+0x30)]);finish(c['requestResult'])
    elif a==0x140380bd0:calls.append(['addUnequip',itemid(y),z&0xffffffff,w&255,si(rsp+0x28)&255,si(rsp+0x30),si(rsp+0x38),si(rsp+0x40)]);finish(c['requestResult'])
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped unequip dependency {a:x}')
hookHandle=u.hook_add(UC_HOOK_CODE,hook)
def invoke(address,args):
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,v&0xffffffffffffffff)
    for n,v in enumerate(args[4:]):wi(rsp+0x28+n*8,v)
    try:u.emu_start(address,m.stop,count=20000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==m.stop;return u.reg_read(UC_X86_REG_RAX)&0xffffffff
def setup(case):
    global c,calls,slots
    c=case;calls=[];slots={int(k):v for k,v in c.get('slots',{16:99,32:101}).items()};u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,app);wq(app+8,app)
    wi(actor+8,77);wq(actor+0x950,inventory);wq(actor+0x958,repo if c.get('repo',True) else 0);wq(other+0x958,otherRepo);wq(bag+0x3d0,otherRepo);wi(bag+0x50,88);wi(bag+0x3c8,c.get('bagOwner',77));wq(client+0x98,gui);wq(client+0xa0,gui);wq(gui,listOwner);wi(gui+8,c.get('guiOpen',1));u.mem_write(gui+0xc,bytes([0]));wi(client+0x48,1)
    for id,ptr in items.items():wi(ptr+0x50,id);wi(ptr+0x3c8,c.get('owner',77));wi(ptr+0x40,id);u.mem_write(ptr+0x3d8,bytes([1,2]))
def run(case):
    setup(case);result=invoke(0x14039fff0,[actor,99,c['destination'],255,254,c['flag'],c['playerId']])
    return dict(case=c,result=result,calls=calls,slots=slots,panel=int.from_bytes(u.mem_read(gui+0xc,1),'little'))
default=dict(exists=True,inEquipment=1,owner=77,repo=True,client=True,message=True,gate=1,placed=1,destination=0x7f000000,flag=2,playerId=0x7f000000,guiOpen=1,page=3,bag=False,other=False,replacedId=99)
rows=[run(default|dict(gate=gate,placed=placed,client=clientFlag,message=message,destination=destination,bag=destination==88,other=destination==89,playerId=player,replacedId=replaced)) for gate,placed,clientFlag,message,destination,player,replaced in itertools.product([0,1,2,3],[0,1,2],[False,True],[False,True],[0x7f000000,77,88,89,90],[0x7f000000,123],[99,100])]
rows += [run(default|dict(exists=exists,inEquipment=equipment,owner=owner,repo=repoFlag,gate=gate)) for exists,equipment,owner,repoFlag,gate in itertools.product([False,True],[0,1,2],[77,78],[False,True],[1,2])]
def pending(case):
    global links
    setup(case);links=list(range(len(c['actions'])));wq(actor+0x880,round);wq(round+0x2f70,wrapper);wq(wrapper,listOwner);wq(listOwner+8,nodes+(links[-1])*32 if links else 0)
    for n,row in enumerate(c['actions']):
        ptr=actions+n*0x100;u.mem_write(ptr+0x10,bytes([row['type']]));wi(ptr+0x14,row['target']);wi(ptr+0x1c,16);wi(ptr+0x20,88);u.mem_write(ptr+0x24,bytes([255,254]))
    invoke(0x14039be00,[actor]);return dict(case=c,calls=calls,remaining=links)
action=lambda type,id:dict(type=type,target=id)
pendingRows=[pending(dict(pending=due,exists=exists,requestResult=result,actions=actionsList)) for due,exists,result,actionsList in itertools.product([0,1],[False,True],[0,1],[[],[action(6,99)],[action(7,99)],[action(6,99),action(1,77),action(7,100),action(7,999),action(6,101)]])]
# Eligibility runs the actual native gate separately, with only lookups captured.
u.hook_del(hookHandle)
def eligibilityHook(u,a,n,_):
    if a==0x1403d22b0:return
    return hook(u,a,n,_)
u.hook_add(UC_HOOK_CODE,eligibilityHook)
def eligibility(case):
    setup(case);wi(actor+0x97c,c['lock']);wq(0x1412df8f8,app);wq(app+0x20,baseInfo);u.mem_write(baseInfo+9,bytes([c['weaponType']]))
    for field,v in zip([0x868,0x86c,0x870],c['locks']):wi(actor+field,v)
    result=invoke(0x1403d22b0,[actor,items[99]])&255
    return dict(case=c,result=result,calls=calls,selected=[si(listOwner+0x10)&0xffffffff,si(listOwner+0x14)&0xffffffff])
eligibilityRows=[eligibility(dict(lock=lock,client=clientFlag,weaponType=weaponType,locks=locks,slots=slotsMap)) for lock,clientFlag,weaponType,locks,slotsMap in itertools.product([0,1,2],[False,True],[0,1,255],[[0,0,0],[1,1,1],[2,2,2]],[{},{16:99},{16:99,32:101},{16:100,32:101},{2048:99},{8192:99},{4096:99}])]
out=m.root/'backups/animations/native-unequip-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,pending=pendingRows,eligibility=eligibilityRows),indent=2));print(json.dumps(dict(output=str(out),runUnequip=len(rows),pending=len(pendingRows),eligibility=len(eligibilityRows))))
