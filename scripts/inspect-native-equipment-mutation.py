"""Read-only original EquipItem/UnequipItem and inventory-slot RemoveItem.
Synthetic PC/lock/inventory states. Property/cache/weight/possession and
module scripts/events captured; validates owner ordering and raw state, not
transitive effects, script mutations, item import or allocation failure.
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
u.mem_map(heap,0x10000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
o,item,stats,inventory,module,app,event=[heap+n*0x1000 for n in range(7)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def slot():return next((1<<n for n in range(18) if i(inventory+8+n*4)==99),0)
def index(flag):return next((n for n in range(18) if flag==1<<n),18)
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x14055b6e0:finish(module)
    elif a==0x140c10324:finish(event)
    elif a==0x1404c6490:finish(x)
    elif a==0x1404c7320:calls.append(['object',y&0xffffffff,z&0xffffffff]);finish()
    elif a==0x1404c72e0:calls.append(['integer',y&0xffffffff,z&0xffffffff]);finish()
    elif a==0x1404629b0:finish(index(y&0xffffffff))
    elif a==0x14055b960:finish(app)
    elif a==0x1405570b0:calls.append(['event',y&0xffffffff,z&0xffffffff,w&0xffffffff,i(rsp+0x28),i(rsp+0x30),i(q(rsp+0x38))&65535]);finish()
    elif a==0x14046c520:calls.append(['possessor',y&0xffffffff,z&0xffffffff,w&0xffffffff,i(rsp+0x28)]);wi(item+0x3c8,y);finish()
    elif a==0x140462b40:finish(int(slot()!=0))
    elif a==0x1403a6150 and c['mode']=='equip':calls.append(['unequip',z&0xffffffff,w&0xffffffff]);finish(c['unequipResult'])
    elif a==0x140464d50:calls.append(['apply',z&0xffffffff,w&0xffffffff]);finish()
    elif a==0x140462c50:
        calls.append(['put',y&0xffffffff]);n=index(y&0xffffffff)
        if n<18:wi(inventory+8+n*4,99)
        finish()
    elif a==0x140388220:calls.append(['armor',z&0xffffffff,w&0xffffffff]);finish()
    elif a==0x1404171e0:calls.append(['combat']);finish()
    elif a==0x1404692e0:calls.append(['weight']);finish(c['weight'])
    elif a==0x140462c10:finish(slot())
    elif a==0x140484d70:calls.append(['script',y&0xffffffff,i(module+0x370),i(module+0x374),si(module+0x37c)]);finish()
    elif a==0x14046b3e0:calls.append(['remove-properties',z&0xffffffff]);finish()
    elif a==0x140462c80:calls.append(['remove'])
    elif not any(lo<=a<hi for lo,hi in [(0x14038c1c0,0x14038c382),(0x1403a6150,0x1403a6268),(0x140462c80,0x140462cb9)]):raise RuntimeError(f'Unmapped equipment mutation dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls
    c=case;calls=[];u.mem_write(heap,bytes(0x10000));wq(0x1412df970,app);wq(app+8,app);wi(o+8,77);wi(item+0x50,99);wi(item+0x3c8,c['possessor']);wq(o+0xad0,stats);wi(stats+0xb0,c['pc']);wq(o+0x950,inventory);wi(o+0x968,c['initialWeight']);wi(o+0x97c,c.get('lock',0));wi(module+0x30,55)
    for n in range(18):wi(inventory+8+n*4,99 if n==4 and c['contains'] else 0x7f000000)
    rsp=stack+0xff08;u.mem_write(rsp-0x200,bytes(0x280));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,o)
    if c['mode']=='equip':u.reg_write(UC_X86_REG_RDX,c['slot']);u.reg_write(UC_X86_REG_R8,item);u.reg_write(UC_X86_REG_R9,c['apply']);wi(rsp+0x28,c['loading']);wi(rsp+0x30,c['event']);entry=0x14038c1c0
    else:u.reg_write(UC_X86_REG_RDX,item);u.reg_write(UC_X86_REG_R8,c['force']&0xffffffff);u.reg_write(UC_X86_REG_R9,c['event']);entry=0x1403a6150
    try:u.emu_start(entry,stop,count=4000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,weight=si(o+0x968),possessor=i(item+0x3c8),dirty=i(o+0x53c),slots=[i(inventory+8+n*4) for n in range(18)])
default=dict(mode='equip',pc=0,contains=True,possessor=77,initialWeight=20,weight=7,slot=32,apply=1,loading=0,event=1,unequipResult=1)
equip=[run(default|dict(pc=pc,contains=contains,possessor=possessor,slot=slot,apply=apply,event=event,loading=loading,unequipResult=unequip_result)) for pc,contains,possessor,slot,apply,event,loading,unequip_result in itertools.product([0,1,2],[False,True],[77,88],[16,32,3],[0,1],[0,1],[0,1],[0,1])]
unequip=[run(default|dict(mode='unequip',pc=pc,contains=contains,lock=lock,force=force,event=event)) for pc,contains,lock,force,event in itertools.product([0,1,2],[False,True],[0,1],[0,1,-1],[0,1])]
out=root/'backups/animations/native-equipment-mutation-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,equip=equip,unequip=unequip),indent=2));print(json.dumps(dict(output=str(out),equip=len(equip),unequip=len(unequip))))
