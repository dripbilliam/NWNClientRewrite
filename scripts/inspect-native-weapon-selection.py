"""Read-only original melee/ranged/ammunition selection bodies, build89.
Synthetic unmerged linked repositories/equipment. Equip/unequip, gates,
damage/elemental/attack-modifier, attack hand/monk/relative size and final
queued equip helpers captured. Validates candidate order, ties, restore,
ammo delegation and return/recursion; not transitive effects, RNG or equip AI.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x100000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
o,stats,inventory,repo,internal,app,target,vt=[heap+n*0x1000 for n in range(8)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def iid(p):return i(p+0x50) if p else None
def refresh():
    wq(internal,nodes[stock[0]] if stock else 0)
    for n,id in enumerate(stock):wq(nodes[id]+8,nodes[stock[n+1]] if n+1<len(stock) else 0)
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x14055b4c0:finish(target if c['target'] and y&0xffffffff!=0x7f000000 else 0)
    elif a in [stop+0x100,stop+0x108]:finish(target)
    elif a==0x140462bd0:finish(items.get(slots.get(y&0xffffffff),0))
    elif a==0x14029ca00:finish(bases.get(y&0xffffffff,0))
    elif a==0x1403a6150:
        id=iid(y);calls.append(['unequip',id,z&0xffffffff,w&0xffffffff]);slot=next((s for s in sorted(slots) if slots[s]==id),None)
        if slot is not None:del slots[slot]
        finish(1)
    elif a==0x14038c1c0:calls.append(['equip',y&0xffffffff,iid(z),w&0xffffffff,i(rsp+0x28),i(rsp+0x30)]);slots[y&0xffffffff]=iid(z);finish(1)
    elif a==0x140464200:
        id=iid(q(y));calls.append(['stash',id,z&255,w&255,i(rsp+0x28),i(rsp+0x30)])
        if id not in stock:stock.insert(0,id);refresh()
        finish(1)
    elif a==0x14046b250:
        id=iid(y);calls.append(['remove',id])
        if id in stock:stock.remove(id);refresh()
        finish(1)
    elif a==0x1404693e0:finish(items.get(node_ids[y],0))
    elif a==0x140169110:wq(y,q(q(y)+8));finish()
    elif a==0x1403d12c0:calls.append(['gate',iid(y),i(z)]);finish(c['gate'])
    elif a==0x140392fd0:finish(0)
    elif a==0x140376a40:finish(1)
    elif a==0x140396370:finish(c['monk'])
    elif a==0x1403fee20:
        hand=32 if z&0xffffffff else 16;id=slots.get(hand);value=descriptors[id]['damage'] if id else 1
        calls.append(['damage',bool(y),z&0xffffffff]);finish(value)
    elif a==0x1403e2430:calls.append(['elemental',bool(y),z&0xffffffff]);finish()
    elif a==0x1403f5d20:
        id=slots.get(16);calls.append(['attack',bool(y)]);finish(descriptors[id]['attack'] if id else 0)
    elif a==0x14037eb50:calls.append(['queue',iid(y),z&0xffffffff,w&0xffffffff,i(rsp+0x28),i(rsp+0x30)]);finish(1)
    elif a==0x140115890:calls.append(['warning']);finish()
    elif not any(lo<=a<hi for lo,hi in [(0x14038c390,0x14038c767),(0x14038c770,0x14038cc50),(0x14038cc50,0x14038d01a)]):raise RuntimeError(f'Unmapped weapon selection dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
descriptors={150:dict(base=3,damage=5,attack=3),153:dict(base=8,damage=5,attack=3),151:dict(base=27,damage=2,attack=0),
    200:dict(base=3,damage=8,attack=4),201:dict(base=8,damage=4,attack=9),202:dict(base=27,damage=2,attack=0),203:dict(base=27,damage=12,attack=0),204:dict(base=25,damage=10,attack=0),205:dict(base=20,damage=10,attack=0),206:dict(base=31,damage=7,attack=8),207:dict(base=6,damage=4,attack=7),208:dict(base=61,damage=4,attack=7),209:dict(base=3,damage=5,attack=3)}
base_data={3:dict(weaponType=1,ranged=0,weaponWield=0),8:dict(weaponType=1,ranged=27,weaponWield=0),27:dict(weaponType=0,ranged=0,weaponWield=0),25:dict(weaponType=0,ranged=0,weaponWield=0),20:dict(weaponType=0,ranged=0,weaponWield=0),31:dict(weaponType=1,ranged=1,weaponWield=10),6:dict(weaponType=1,ranged=25,weaponWield=0),61:dict(weaponType=1,ranged=20,weaponWield=0)}
def run(case):
    global c,calls,slots,stock,items,nodes,node_ids,bases
    c=case;calls=[];slots={};stock=c['stock'].copy();items={};nodes={};node_ids={};bases={};u.mem_write(heap,bytes(0x100000));wq(0x1412df970,app);wq(app+8,app);wq(0x1412df8f8,app);wq(app+0x20,app)
    wi(o+8,99);wq(o+0xad0,stats);wq(o+0x950,inventory);wq(o+0x958,repo if c['repo'] else 0);wq(repo+0x10,internal);wq(target,vt);wq(vt+0x20,stop+0x100);wq(vt+0x60,stop+0x108)
    for n,(id,d) in enumerate(descriptors.items()):
        p=heap+0x20000+n*0x1000;items[id]=p;wi(p+0x50,id);wi(p+0x40,d['base']);nodes[id]=heap+0x40000+n*0x100;node_ids[nodes[id]]=id
    nodes[999]=heap+0x48000;node_ids[nodes[999]]=999
    for n,(id,b) in enumerate(base_data.items()):
        p=heap+0x50000+n*0x100;bases[id]=p;u.mem_write(p+8,bytes([b['weaponWield']]));u.mem_write(p+9,bytes([b['weaponType']]));u.mem_write(p+0x18,bytes([b['ranged']]))
    if c['old'] is not None:slots[16]=c['old']
    if c['ammo']:slots[2048]=151
    refresh();rsp=stack+0xff08;u.mem_write(rsp-0x200,bytes(0x280));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,o);u.reg_write(UC_X86_REG_RDX,11 if c['target'] else 0x7f000000);u.reg_write(UC_X86_REG_R8,c['offhand'] if c['mode']=='melee' else items[c['launcher']] if c['mode']=='ammo' else 0);u.reg_write(UC_X86_REG_R9,0)
    entry={'melee':0x14038c770,'ranged':0x14038cc50,'ammo':0x14038c390}[c['mode']]
    try:u.emu_start(entry,stop,count=20000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,stock=stock,slots=slots)
default=dict(mode='melee',repo=True,old=150,gate=1,monk=0,offhand=0,ammo=False,target=True,stock=[200,201,202,203,204,205,209,999],launcher=201)
observations=[]
for mode,repo_flag,old,gate,monk,offhand,target_flag in itertools.product(['melee','ranged'],[False,True],[None,150,153],[0,1,2,3],[0,1],[0,1],[False,True]):observations.append(run(default|dict(mode=mode,repo=repo_flag,old=old,gate=gate,monk=monk,offhand=offhand,target=target_flag)))
for repo_flag,old,gate,launcher,ammo,target_flag in itertools.product([False,True],[None,150,153],[0,1,2,3],[201,206,207,208,200],[False,True],[False,True]):observations.append(run(default|dict(mode='ammo',repo=repo_flag,old=old,gate=gate,launcher=launcher,ammo=ammo,target=target_flag)))
out=root/'backups/animations/native-weapon-selection-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,descriptors=descriptors,bases=base_data,observations=observations),indent=2));print(json.dumps(dict(output=str(out),observations=len(observations))))
