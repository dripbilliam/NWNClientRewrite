"""Complete original nominal melee/ranged damage owners and controlled actual
GetDamageBonus calls. Original FNV-1a executes; equipment/base/property/feat,
ruleset lookup and unrelated strike stages are captured lower boundaries.
No debug formatting, target bonuses, random damage or encounter parity claim.
"""
import importlib,itertools,json,struct
from native_rule_fixture import ruleset_value
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,stats,inventory,round,attack,property,rules=[m.heap+n*0x2000 for n in range(7)]
ranges=[(0x1404047c0,0x140404a99),(0x1404061f0,0x14040681e),(0x1403fd4b0,0x1403fee15),(0x1402ae870,0x1402ae899)]
def signed(n):return(n+2**31)%2**32-2**31
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140462bd0:calls.append(['equipped',y&0xffffffff]);m.finish(slots.get(y&0xffffffff,0))
 elif a==0x14029ca00:calls.append(['base',y&0xffffffff]);m.finish(bases.get(y&0xffffffff,0))
 elif a==0x14040b900:calls.append(['feat',y&65535]);m.finish(int((y&65535) in c.get('feats',[])))
 elif a==0x140468f20:
  calls.append(['property',z&65535,w&65535]);present=c.get('mighty') is not None;m.wq(y,property if present else 0);m.finish(int(present))
 elif a==0x1402a4130:
  default=signed(z);value=ruleset_value(c.get('rules',{}),y,default);calls.append(['ruleInt',f'{y:016x}',default,value]);m.finish(value)
 elif a==0x1402a40d0:
  default=m.xmm(UC_X86_REG_XMM2);value=ruleset_value(c.get('rules',{}),y,default);calls.append(['ruleFloat',f'{y:016x}',default,value]);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
 elif a==0x140375e40:m.finish(attack)
 elif a==0x1403760a0:m.finish(slots.get(c.get('selectedSlot',16),0))
 elif a in [0x140401020,0x140413030]:m.finish(0)
 elif a==0x140c10370:m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unexpected nominal damage dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,slots,bases
 c=case;calls=[];slots={};bases={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(stats+0x30,actor);m.wq(actor+0x950,inventory);m.wq(actor+0x880,round);m.wi(actor+0x718,c.get('size',3));u.mem_write(stats+0xd39,bytes([c.get('strength',3)&255]));m.wq(0x1412df8f8,rules);m.wq(rules+0x20,rules);m.wi(0x14141e818,0)
 for i,(slot,item) in enumerate(c.get('items',{}).items()):
  slot=int(slot);ptr=m.heap+0x20000+i*0x2000;base=ptr+0x400;slots[slot]=ptr;bases[item['id']]=base;m.wi(ptr+0x40,item['id']);u.mem_write(base+8,bytes([item.get('wield',0)&255]));u.mem_write(base+0x18,bytes([item.get('ranged',0)&255,item.get('size',3)&255]));u.mem_write(base+0xb4,struct.pack('<HH',item.get('specialization',100)&65535,item.get('epicSpecialization',101)&65535))
 if c.get('mighty') is not None:u.mem_write(property,struct.pack('<HHHH',45,0,0,c['mighty']&65535))
 m.wi(attack+0x5c,c.get('ranged',1));u.mem_write(attack+0x56,b'\1');u.mem_write(attack+0x78,b'\1')
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 args=[stats,c.get('offhand',0),c.get('natural',255)] if c['mode']=='melee' else [stats] if c['mode']=='ranged' else [stats,0,c.get('offhand',0)]
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(r,v&0xffffffffffffffff)
 u.emu_start(dict(melee=0x1404047c0,ranged=0x1404061f0,strike=0x1403fd4b0)[c['mode']],m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=signed(u.reg_read(UC_X86_REG_RAX)&0xffffffff),calls=calls)
rows=[]
meleeLayouts=[{}, {'16':dict(id=22)}, {'16':dict(id=22,size=4)}, {'16':dict(id=22,wield=8,size=4)}, {'16':dict(id=22,ranged=1)}, {'16':dict(id=22),'32':dict(id=30)}, {'32':dict(id=14,ranged=0)}, {'16384':dict(id=69,size=4),'32768':dict(id=70),'65536':dict(id=71,ranged=1)}]
for items,strength,offhand,natural in itertools.product(meleeLayouts,[0,1,3,127,128,255],[0,1,2],[255,0,1,2,3,256]):rows.append(run(dict(mode='melee',items=items,strength=strength,offhand=offhand,natural=natural,feats=[100,101,138,668])))
for id,wield,strength,mighty in itertools.product([6,7,8,11,22,59,61],[0,11],[0,1,7,127,128,255],[None,0,2,10,65535]):
 for mode in ['ranged','strike']:rows.append(run(dict(mode=mode,items={'16':dict(id=id,ranged=1,wield=wield)},strength=strength,mighty=mighty)))
for tier in range(21):
 feats=([444+tier if tier<=5 else 1039+tier] if tier else [])+[100,101]
 for mode in ['ranged','strike']:rows.append(run(dict(mode=mode,items={'16':dict(id=8,ranged=1)},strength=7,mighty=3,feats=feats)))
for mode,items in itertools.product(['melee','ranged','strike'],[{}, {'16':dict(id=22,size=4)}, {'16':dict(id=8,ranged=1)}]):rows.append(run(dict(mode=mode,items=items,strength=7,feats=[100,101,138,668],rules={'TWO_HANDED_WEAPON_STRENGTH_MODIFIER':2.25,'OFFHAND_WEAPON_STRENGTH_MODIFIER':.75,'WEAPON_SPECIALIZATION_BONUS':9,'EPIC_WEAPON_SPECIALIZATION_BONUS':13})))
for mode,offhand,multiplier in itertools.product(['melee','strike'],[0,1],[-1e9,-2.25,0,1e9]):rows.append(run(dict(mode=mode,offhand=offhand,ranged=0,items={'16':dict(id=22,size=4)},strength=127,rules={'TWO_HANDED_WEAPON_STRENGTH_MODIFIER':multiplier,'OFFHAND_WEAPON_STRENGTH_MODIFIER':multiplier})))
out=m.root/'backups/animations/native-nominal-damage-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
