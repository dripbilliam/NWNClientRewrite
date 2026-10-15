"""Read-only ExecuteCommandEquipItem/UnequipItem. Original slot validation,
casts and request arguments execute; VM pops, lookups and Add*Actions captured.
FLOAT pow uses exact powers of2 for the18 accepted integral indices only.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
command,vm,actor,item,app,objects,vtable=[m.heap+n*0x1000 for n in range(7)]
def hook(u,a,n,_):
    global popped
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140286160:wi(y,123 if c['mode']=='equip' and c['count']==3 and popped==0 else 99);popped+=1;finish(1)
    elif a==0x140286110:wi(y,c['slot']);finish(1)
    elif a==0x140c7c810:
        slot=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM1)&0xffffffff))[0];u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',2**slot),'little'));finish()
    elif a==0x14055b850:finish(objects)
    elif a==0x140296470:
        ptr=actor if y==77 else item;wq(z,ptr);finish(int.from_bytes(u.mem_read(0x140dc2a78,1),'little'))
    elif a==m.stop+0x100:calls.append(['creature',77]);finish(actor if c['selfExists'] else 0)
    elif a==m.stop+0x108:calls.append(['item',99]);finish(item if c['itemExists'] else 0)
    elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);finish(actor if c['selfExists'] else 0)
    elif a==0x14055b6c0:calls.append(['item',y&0xffffffff]);finish(item if c['itemExists'] else 0)
    elif a==0x14037eb50:calls.append(['equip',77,99,z&0xffffffff,w&0xffffffff,si(rsp+0x28),si(rsp+0x30)&0xffffffff]);finish()
    elif a==0x140380bd0:calls.append(['unequip',77,99,z&0xffffffff,w&255,si(rsp+0x28)&255,si(rsp+0x30),si(rsp+0x38),si(rsp+0x40)&0xffffffff]);finish()
    elif not (0x14051ca60<=a<0x14051cbb6 or 0x14054a590<=a<0x14054a627):raise RuntimeError(f'Unmapped script equipment dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,popped
    c=case;calls=[];popped=0;u.mem_write(m.heap,bytes(0x100000));wq(0x1412df910,vm);wq(0x1412df970,app);wq(app+8,app);wi(command+8,1);wi(command+12,77);wq(actor,vtable);wq(item,vtable);wq(vtable+0x60,m.stop+0x100);wq(vtable+0x70,m.stop+0x108)
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[command,0,c['count']]):u.reg_write(reg,v)
    u.emu_start(0x14051ca60 if c['mode']=='equip' else 0x14054a590,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;assert u.reg_read(UC_X86_REG_RAX)==0
    return dict(case=c,calls=calls)
rows=[run(dict(mode='equip',slot=slot,count=count,selfExists=selfExists,itemExists=itemExists)) for slot,count,selfExists,itemExists in itertools.product([-2147483648,-1,*range(20),2147483647],[2,3],[False,True],[False,True])]
rows += [run(dict(mode='unequip',slot=0,count=1,selfExists=selfExists,itemExists=itemExists)) for selfExists,itemExists in itertools.product([False,True],[False,True])]
out=m.root/'backups/animations/native-script-equipment-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
