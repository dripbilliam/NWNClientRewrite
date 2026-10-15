"""Read-only RunEquip14039f960 owner comparisons for canonical owned items.
Bag/client transfer, failed repository placement/drop and allocation are not
covered. Equip gate, property/cache mutations, stacking, slots and messages
are captured helpers; validates owner ordering, mode gates and raw returns.
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
u.mem_map(heap,0x20000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
o,app,client,msg,repo,inventory,stats,rules,baseinfo=[heap+n*0x1000 for n in range(9)]
items={n:heap+0x10000+(n-99)*0x1000 for n in [99,100,101]}
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def itemid(ptr):return i(ptr+0x50)
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x14055b390:finish(client if c['client'] else 0)
    elif a==0x14055b810:finish(msg if c['message'] else 0)
    elif a==0x14055b6c0:finish(items.get(y&0xffffffff,0) if c['exists'] else 0)
    elif a==0x1403d12c0:calls.append(['gate',itemid(y),i(z),w&0xffffffff,i(rsp+0x28),i(rsp+0x30),bool(q(rsp+0x38))]);wi(z,c['resolvedSlot']);finish(c['allowed'])
    elif a==0x140468bd0:calls.append(['contains',itemid(y),z&0xffffffff]);finish(c['contains'])
    elif a==0x14046b250:calls.append(['remove',itemid(y)]);finish(1)
    elif a==0x140462bd0:finish(items.get(slots.get(y&0xffffffff),0))
    elif a==0x14029ca00:finish(baseinfo)
    elif a==0x14046ac10:calls.append(['merge',itemid(x),itemid(y)]);finish(c['merge'])
    elif a==stop+0x100:calls.append(['destroy',itemid(x),y&0xffffffff]);finish()
    elif a==0x1403a6150:
        calls.append(['unequip',itemid(y),z&0xffffffff,w&0xffffffff]);id=itemid(y)
        for slot,value in list(slots.items()):
            if value==id:del slots[slot]
        finish(1)
    elif a==0x140464200:calls.append(['stash',itemid(q(y)),z&255,w&255,i(rsp+0x28),i(rsp+0x30)]);finish(1)
    elif a==0x14046c520:calls.append(['possessor',itemid(x),y&0xffffffff,z&0xffffffff,w&0xffffffff,i(rsp+0x28)]);wi(x+0x3c8,y);finish()
    elif a==0x14038c1c0:calls.append(['equip',y&0xffffffff,itemid(z),w&0xffffffff,i(rsp+0x28),i(rsp+0x30)]);slots[y&0xffffffff]=itemid(z);finish(1)
    elif a==0x1404da5b0:calls.append(['equipped-message',z&0xffffffff,w&0xffffffff,i(rsp+0x28)]);finish()
    elif a==0x1404da660:calls.append(['cancel',z&0xffffffff,w&0xffffffff,i(rsp+0x28)]);finish()
    elif a==0x14040b900:calls.append(['feat',y&65535]);finish(c['feat899'] if y==899 else c['feat866'])
    elif a==0x140392fd0:calls.append(['size',itemid(y)]);finish(c['size'])
    elif a==0x1403d8c50:calls.append(['mode',y&255,z&0xffffffff]);u.mem_write(o+0x6ef,bytes([y&255]));finish()
    elif not 0x14039f960<=a<0x14039ffe9:raise RuntimeError(f'Unmapped RunEquip dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,slots
    c=case;calls=[];slots={int(k):v for k,v in c['slots'].items()};u.mem_write(heap,bytes(0x20000));wq(0x1412df970,app);wq(app+8,app);wq(0x1412df8f8,rules);wq(rules+0x20,baseinfo)
    wi(o+8,77);wq(o+0x950,inventory);wq(o+0x958,repo);wq(o+0xad0,stats);u.mem_write(o+0x6ef,bytes([c['mode']]));wi(client+0x48,1)
    u.mem_write(baseinfo+0x24,struct.pack('<H',c['stacking']));wi(baseinfo+0xc0,c['monk']);u.mem_write(baseinfo+0x18,bytes([c['ranged']]))
    for id,ptr in items.items():wi(ptr+0x50,id);wi(ptr+0x3c8,77);wi(ptr+0x40,8);wq(ptr,heap+0xf000)
    wq(heap+0xf000,stop+0x100)
    rsp=stack+0xff08;u.mem_write(rsp-0x300,bytes(0x380));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[o,99,c['slot'],c['playerId']]):u.reg_write(reg,value&0xffffffffffffffff)
    try:u.emu_start(0x14039f960,stop,count=5000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,mode=int.from_bytes(u.mem_read(o+0x6ef,1),'little'),slots=slots)
default=dict(exists=True,client=False,message=True,allowed=1,contains=1,slot=16,resolvedSlot=16,slots={},stacking=1,merge=0,mode=0,monk=0,ranged=0,feat899=0,feat866=0,size=0,playerId=0x7f000000)
rows=[run(default|dict(allowed=allowed,slots=slots,stacking=stacking,merge=merge,client=client,playerId=player)) for allowed,slots,stacking,merge,client,player in itertools.product([0,1,2,3,4],[{},{16:100},{16:99},{32:101},{16:100,32:101}],[1,3],[0,1],[False,True],[0x7f000000,123])]
rows += [run(default|dict(mode=mode,slots=slots,monk=monk,ranged=ranged,feat899=feat899,feat866=feat866,size=size,slot=2,resolvedSlot=2)) for mode,slots,monk,ranged,feat899,feat866,size in itertools.product([0,1,2,3,4,5,6,7,8,9,10,11,12,255],[{},{16:100},{16:100,32:101}],[0,1],[0,1],[0,1],[0,1],[-1,0])]
rows += [run(default|dict(exists=exists,message=message,client=client,contains=contains,resolvedSlot=32)) for exists,message,client,contains in itertools.product([False,True],[False,True],[False,True],[0,1,2])]
out=root/'backups/animations/native-run-equip-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
