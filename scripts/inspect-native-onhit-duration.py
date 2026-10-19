"""Complete original eleven duration on-hit payload builders. The original
clearing copy constructor, SetInteger, SetLinked and UpdateLinked also execute.
Base allocation/constructor/creator, attack lookup, append and destructor are
captured. Payload trees, metadata, order and allocation-failure cleanup are
observed; actual effect application and property admission are separate checks.
"""
import importlib,itertools,json
from native_effect_copy_fixture import NativeEffectCopyFixture
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,target,round_,attack=[m.heap+n*0x1000 for n in range(4)];copy=NativeEffectCopyFixture(m)
owners={}
for name in['slow','sleep','stun','hold','confusion','daze','doom','fear','silence','deafness','blindness']:
 body=json.loads((m.root/f'backups/animations/rea-onhit-{name}-owner.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];owners[name]=[(int(r['start'],16),int(r['end'],16)+1)for r in body['ranges']]
def snapshot(p):
 flags=int.from_bytes(u.mem_read(p+10,2),'little');return dict(id=f'{m.q(p):016x}',type=int.from_bytes(u.mem_read(p+8,2),'little'),subtype=flags&~7,durationType=flags&7,duration=m.rf(p+12),creatorId=m.si(p+24)&0xffffffff,spellId=m.si(p+28),casterLevel=m.si(p+40),exposed=m.si(p+32),showIcon=m.si(p+36),integers=[m.si(m.q(p+0x48)+i*4)for i in range(8)],linkLeft=snapshot(m.q(p+0x30))if m.q(p+0x30)else None,linkRight=snapshot(m.q(p+0x38))if m.q(p+0x38)else None)
def hook(u,a,n,_):
 global allocations,ids
 if a==m.stop:u.emu_stop();return
 if copy.handle(a):return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140c10324:
  allocations+=1;p=m.heap+0x10000+allocations*0x1000;names[p]=allocations;m.finish(0 if allocations==c.get('fail',0)else p)
 elif a==0x1404233d0:
  ids+=1;copy.prepare(x);m.wq(x,100+ids);m.wq(x+0x48,x+0x200);m.wi(x+32,1);m.wi(x+36,1);m.wi(x+28,-1);m.wi(x+40,-1);m.wi(x+24,0x7f000000);m.finish(x)
 elif a==0x140425110:m.wi(x+24,y);m.wi(x+28,c.get('spell',-1));m.wi(x+40,c.get('casterLevel',-1));m.finish()
 elif a==0x140375e40:trace.append(['attack',y&0xffffffff]);m.finish(attack)
 elif a==0x14037cde0:trace.append(['append',x-attack,snapshot(y)]);m.finish()
 elif a==0x14003d8c0:m.wq(x,0);m.wi(x+8,0);m.finish(x)
 elif a==0x140423770:trace.append(['destroy',names.get(x,0)]);m.finish()
 elif a==0x140c10360:trace.append(['free',names.get(x,0)]);m.finish()
 elif not any(lo<=a<hi for lo,hi in owners[c['owner']]+[(0x140425210,0x14042521c),(0x140425220,0x14042522f),(0x140425370,0x1404255ee)]):raise AssertionError(f'Unmapped onhit duration boundary {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,allocations,ids,names
 c=case;trace=[];allocations=ids=0;names={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(actor+8,c.get('creator',99));m.wq(actor+0x880,round_);u.mem_write(round_+0x2f2c,bytes([c.get('attack',0)&255]));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,target,c['rounds']&0xffffffff]):u.reg_write(reg,v)
 try:u.emu_start(owners[c['owner']][0][0],m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,trace=trace,allocations=allocations)
cases=[dict(owner=owner,rounds=r,creator=id,attack=index,spell=70,casterLevel=8)for owner,r,id,index in itertools.product(owners,[-2147483648,-1,0,1,3,16777217,2147483647],[99,0x80000042],[0,49,50,255])]
rows=[run(c)for c in cases]
for owner in owners:
 count=next(r['allocations']for r in rows if r['case']['owner']==owner)
 for n in range(1,count+1):rows.append(run(dict(owner=owner,rounds=3,fail=n)))
out=m.root/'backups/animations/native-onhit-duration-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,owners={name:[[hex(lo),hex(hi)]for lo,hi in ranges]for name,ranges in owners.items()},rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),copies=copy.executions,counts={name:sum(r['case']['owner']==name for r in rows)for name in owners})))
