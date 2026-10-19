"""Complete five native on-hit spell request owners and Knock payload ctor.
Spell lookup/active script copy, allocation/free, virtual casts, GetArea,
GetAttack and payload-list append are captured lower boundaries. This proves
request construction/gates/order, not execution of spell scripts or combat.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,target,app,rules,spell,payload,string,area,round_,attack,vt,door,placeable=[m.heap+i*0x1000 for i in range(13)]
owners={}
for name in ['dispel-item','lesser-dispel','greater-dispel','disjunction','knock']:
 d=json.loads((m.root/f'backups/animations/rea-onhit-{name}-owner.json').read_text())['structuredContent']['normalized_result']['procedure']['body']
 owners[name]=[(int(r['start'],16),int(r['end'],16)+1)for r in d['ranges']]
ctor=json.loads((m.root/'backups/animations/rea-onhit-spell-payload-ctor.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ctor=[(int(r['start'],16),int(r['end'],16)+1)for r in ctor['ranges']]
def snapshot(y):return dict(spellId=m.si(y),featId=int.from_bytes(u.mem_read(y+4,2),'little'),casterId=m.si(y+8)&0xffffffff,targetId=m.si(y+12)&0xffffffff,itemId=m.si(y+16)&0xffffffff,position=[m.rf(y+20+i*4)for i in range(3)],script='test_impact',areaId=m.si(y+48)&0xffffffff,casterLevel=m.si(y+52))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x10:trace.append(['door']);m.finish(door if c.get('door',True)else 0)
 elif a==m.stop+0x20:trace.append(['placeable']);m.finish(placeable if c.get('placeable',False)else 0)
 elif a==0x1402af4a0:trace.append(['spell',y&0xffffffff]);m.finish(spell if c.get('validSpell',True)else 0)
 elif a==0x140c10324:trace.append(['allocate',x]);m.finish(payload if c.get('allocate',True)else 0)
 elif a==0x14003d8c0:trace.append(['copyScript','test_impact']);m.wq(x,string);m.wi(x+8,11);m.finish(x)
 elif a==0x140494e80:trace.append(['area']);m.finish(area if c.get('area',True)else 0)
 elif a==0x140375e40:trace.append(['attack',y&0xffffffff]);m.finish(attack)
 elif a==0x1403de410:trace.append(['append',x-attack,snapshot(y)]);m.finish()
 elif a==0x140c10370:m.finish()
 elif not any(lo<=a<hi for lo,hi in owners[c['owner']]+ctor):raise AssertionError(f'Unmapped engine spell dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace
 c=case;trace=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,app);m.wq(app+0xd0,rules)
 m.wi(actor+8,0x80000042);m.wi(target+8,91);u.mem_write(target+12,bytes([c.get('type',10)&255]));m.wi(area+0x140,c.get('areaId',55));m.wq(actor+0x880,round_);u.mem_write(round_+0x2f2c,bytes([c.get('attack',0)&255]));m.wq(target,vt);m.wq(vt+0x30,m.stop+0x10);m.wq(vt+0x98,m.stop+0x20);m.wi(door+0x424,c.get('doorLocked',1));m.wi(placeable+0x378,c.get('placeableLocked',1))
 for i,v in enumerate(c.get('position',[-4.5,5.25,-6.75])):m.wf(target+0xa4+i*4,v)
 m.wq(spell+0x58,string);m.wi(spell+0x60,11);u.mem_write(string,b'test_impact\0');rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,target,c.get('itemId',123)&0xffffffff]):u.reg_write(reg,value)
 try:u.emu_start(owners[c['owner']][0][0],m.stop,count=50000)
 except Exception:print(json.dumps(dict(case=c,trace=trace,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop;return dict(case=c,trace=trace)
cases=[dict(owner=o,validSpell=v,allocate=a,area=ar,attack=at,itemId=0x80000042)for o,v,a,ar,at in itertools.product(owners,[False,True],[False,True],[False,True],[0,255,256])]
cases +=[dict(owner='knock',type=t,door=d,placeable=p,doorLocked=dl,placeableLocked=pl)for t,d,p,dl,pl in itertools.product([5,9,10,266],[False,True],[False,True],[0,1,-1,256],[0,1,-1,256])]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-onhit-engine-spell-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,owners={n:[[hex(a),hex(b)]for a,b in v]for n,v in owners.items()},rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
