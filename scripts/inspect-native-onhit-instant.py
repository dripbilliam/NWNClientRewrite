"""Original permanent/instant on-hit owners and GetCanSlayAlignment. Execute
complete owners, SetInteger and FNV. Base effect constructor, allocation,
SetCreator, target cast/stats, active cost/rules and attack append are captured.
No admission, effect application or whole combat acceptance is implied.
"""
import importlib,itertools,json
from native_effect_copy_fixture import NativeEffectCopyFixture
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,target,round_,attack,prop,stats,vtable,rules,tables,cost=[m.heap+n*0x1000 for n in range(10)]
copy=NativeEffectCopyFixture(m)
owners={}
for name in ['poison','disease','ability-damage','level-drain','slay-racial','slay-alignment-group','slay-alignment','vorpal','dispel-property','can-slay','wounding','vampiric']:
 d=json.loads((m.root/f'backups/animations/rea-onhit-{name}-owner.json').read_text())['structuredContent']['normalized_result']['procedure']['body']
 owners[name]=[(int(r['start'],16),int(r['end'],16)+1)for r in d['ranges']]
def snapshot(p):
 flags=int.from_bytes(u.mem_read(p+10,2),'little')
 return dict(id=f'{m.q(p):016x}',type=int.from_bytes(u.mem_read(p+8,2),'little'),subtype=flags&~7,durationType=flags&7,duration=m.rf(p+12),creatorId=m.si(p+24)&0xffffffff,spellId=m.si(p+28),casterLevel=m.si(p+40),exposed=m.si(p+32),showIcon=m.si(p+36),integers=[m.si(m.q(p+0x48)+i*4)for i in range(8)])
def hook(u,a,n,_):
 global allocations,ids
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x100:trace.append(['creature']);m.finish(target if c.get('creature',True)else 0)
 elif a==0x140c10324:
  assert x==0x110;allocations+=1;m.finish(0 if allocations==c.get('fail',0)else m.heap+0x10000+allocations*0x1000)
 elif a==0x1404233d0:
  ids+=1;copy.prepare(x);m.wq(x,100+ids);m.wq(x+0x48,x+0x200);m.wi(x+32,1);m.wi(x+36,1);m.wi(x+28,-1);m.wi(x+40,-1);m.wi(x+24,0x7f000000);m.finish(x)
 elif a==0x140425110:
  m.wi(x+24,y);m.wi(x+28,c.get('spell',-1));m.wi(x+40,c.get('casterLevel',-1))
  if 'mutateAttack'in c:u.mem_write(round_+0x2f2c,bytes([c['mutateAttack']&255]))
  m.finish()
 elif a==0x140375e40:trace.append(['attack',y&0xffffffff]);m.finish(attack)
 elif a==0x14037cde0:trace.append(['append',x-attack,snapshot(y)]);m.finish()
 elif a==0x140406a20:trace.append(['alignment','lawChaos']);m.finish(c.get('lawChaos',1))
 elif a==0x1404069f0:trace.append(['alignment','goodEvil']);m.finish(c.get('goodEvil',1))
 elif a==0x1402b38a0:trace.append(['costTable',y&255]);m.finish(cost)
 elif a==0x1401a7010:
  column=bytes(u.mem_read(m.q(z),16)).split(b'\0')[0].decode();found=c.get('costFound',True);value=c.get('dc',17)
  trace.append(['table',y&0xffffffff,column,int(found),value if found else None])
  if found:m.wi(w,value)
  m.finish(int(found))
 elif a==0x1402a4130:trace.append(['rulesDC',f'{y:016x}',z&0xffffffff]);m.finish(c.get('rulesDC',20))
 elif a==0x140c10370:m.finish()
 elif a==0x140c10368:assert x==6;m.finish(m.heap+0x30000)
 elif not any(lo<=a<hi for lo,hi in owners[c['owner']]+owners['can-slay']+[(0x140425210,0x14042521c),(0x1402ae870,0x1402ae899),(0x1403767a0,0x140376a38)]):raise AssertionError(f'Unmapped instant onhit dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,allocations,ids
 c=case;trace=[];allocations=ids=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(target,vtable);m.wq(vtable+0x60,m.stop+0x100);m.wq(target+0xad0,stats);u.mem_write(stats+0xd20,(c.get('race',1)&65535).to_bytes(2,'little'))
 m.wi(actor+8,c.get('creator',99));m.wq(actor+0x880,round_);u.mem_write(round_+0x2f2c,bytes([c.get('attack',0)&255]))
 for i in range(32):u.mem_write(attack+0x16+i*2,(c.get('damage',[3,-1,7,0]+[-1]*28)[i]&65535).to_bytes(2,'little'))
 m.wi(prop,c.get('type',48)&65535);u.mem_write(prop+6,(c.get('cost',4)&65535).to_bytes(2,'little'));u.mem_write(prop+9,bytes([c.get('param',3)&255]))
 m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,target,prop]):u.reg_write(reg,v)
 try:u.emu_start(owners[c['owner']][0][0],m.stop,count=50000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,trace=trace,allocations=allocations,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff if c['owner']=='can-slay'else None)
cases=[dict(owner=owner,type=t,param=p,creator=0x80000042,attack=255,spell=70,casterLevel=8)for owner,t,p in itertools.product(owners,[48,72],[0,1,3,5,8,9,255,256,-1])]
cases +=[dict(owner=owner,**v)for owner in owners for v in[dict(fail=1),dict(fail=2),dict(costFound=False,rulesDC=37),dict(cost=65539,dc=-1),dict(attack=2,mutateAttack=7),dict(creature=False)]]
cases +=[dict(owner=owner,param=p,lawChaos=l,goodEvil=g,race=257)for owner,p,l,g in itertools.product(['can-slay','slay-alignment','slay-alignment-group'],range(10),[1,2,3],[1,4,5])]
cases +=[dict(owner='slay-racial',param=p,race=r,fail=f)for p,r,f in itertools.product([1,255],[1,255,257],[0,1,2])]
cases +=[dict(owner='vampiric',cost=cost,damage=[amount]*32)for cost,amount in itertools.product([0,1,65535,65536],[-32769,-1,0,32767,65535])]
rows=[run(c)for c in cases]
out=m.root/'backups/animations/native-onhit-instant-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,owners={name:[[hex(lo),hex(hi)]for lo,hi in ranges]for name,ranges in owners.items()},rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
