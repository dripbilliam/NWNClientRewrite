"""Original lethal-damage branches and complete OnRemoveTemporaryHitpoints.
Capture allocation/base construction/SetCreator, HP getters, blood strings,
nested ApplyEffect, ambient/GUI/module/event callbacks. Original thresholds,
temporary-HP subtraction, death construction, metadata and order execute.
Earlier ordinary damage mitigation/HP/death checks are separate.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,vt,rules,tables,blood,app,module,sourceEffect=[m.heap+i*0x1000 for i in range(8)]
def snapshot(p):
 flags=int.from_bytes(u.mem_read(p+10,2),'little');return dict(id=f'{m.q(p):016x}',type=int.from_bytes(u.mem_read(p+8,2),'little'),subtype=flags&~7,durationType=flags&7,creatorId=m.si(p+24)&0xffffffff,integers=[m.si(m.q(p+0x48)+i*4)for i in range(8)])
def hook(u,a,n,_):
 global allocations,ids,dyingCalls,deadCalls
 if a in[0x140429c96,m.stop]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x30:trace.append(['asCreature']);m.finish(0 if c.get('creature')is False else actor)
 elif a==0x140495620:trace.append(['dying']);dyingCalls+=1;m.finish(c.get('dying',[0,0])[min(dyingCalls-1,1)])
 elif a==0x1404953b0:trace.append(['dead']);deadCalls+=1;m.finish(c.get('dead',[0,1])[min(deadCalls-1,1)])
 elif a==0x14039db40:trace.append(['ambient']);m.finish()
 elif a==0x14055b6e0:trace.append(['module']);m.finish(module)
 elif a==0x14055b960:m.finish(app)
 elif a==0x1404c6490:u.mem_write(x,bytes(0x48));m.finish(x)
 elif a==0x1405570b0:
  rsp=u.reg_read(UC_X86_REG_RSP);event=m.si(rsp+0x30);ptr=m.q(rsp+0x38);trace.append(['event',event,w&0xffffffff,m.si(rsp+0x28)&0xffffffff,snapshot(ptr)if event==5 else dict(type=int.from_bytes(u.mem_read(ptr,2),'little'),integers=[],objectIds=[])]);m.finish()
 elif a==0x140382920:trace.append(['closePanels',y&0xffffffff]);m.finish()
 elif a==0x140c10410:m.finish()
 elif a==m.stop+0x10:trace.append(['maximum',y&0xffffffff]);m.finish(c.get('maximum',20)&65535)
 elif a==m.stop+0x20:trace.append(['current',y&0xffffffff]);m.finish(c.get('current',-11)&65535)
 elif a==0x140c10324:allocations+=1;assert x in[0x110,0x48];m.finish(m.heap+0x10000+allocations*0x1000)
 elif a==0x1404233d0:ids+=1;m.wq(x,100+ids);m.wq(x+0x48,x+0x200);m.wi(x+0x40,8);m.wi(x+24,0x7f000000);m.finish(x)
 elif a==0x140425110:m.wi(x+24,y);m.finish()
 elif a==0x14048e350:trace.append(['apply',snapshot(y),z&0xffffffff,w&0xffffffff]);m.finish()
 elif a==0x1401a68f0:trace.append(['blood',y&0xffffffff]);value=c.get('blood','R').encode()+b'\0';u.mem_write(blood,value);m.wq(w,blood);m.wi(w+8,len(value)-1);m.finish(1)
 elif a==0x140c10370:m.finish()
 elif a==0x140c10368:assert x==10;m.finish(m.heap+0x30000)
 elif not(0x140429617<=a<0x140429907 or 0x140429c15<=a<0x140429c96 or 0x140425210<=a<0x14042521c or 0x140438d60<=a<0x1404391ae or 0x140423fc0<=a<0x140423fcb):raise AssertionError(f'Unexpected lethal construction dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,allocations,ids,dyingCalls,deadCalls
 c=case;trace=[];allocations=ids=dyingCalls=deadCalls=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables);m.wq(tables+0x100,tables);m.wq(actor,vt);m.wq(vt+0x130,m.stop+0x10);m.wq(vt+0x138,m.stop+0x20);m.wq(vt+0x60,m.stop+0x30);u.mem_write(actor+0xa74,(7).to_bytes(2,'little'));u.mem_write(actor+0x771,bytes([c.get('state',0)&255]));m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(module+0x30,444);m.wi(actor+8,99);m.wi(actor+0xe8,c.get('temporaryHP',5));m.wi(actor+0xec,3);m.wq(sourceEffect+0x48,sourceEffect+0x200);m.wi(sourceEffect+0x40,8);m.wi(sourceEffect+0x200,c.get('removeAmount',3))
 rsp=m.stack+0x1fc00;u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rsp+0x100);m.wi(rsp+0x40,c.get('creator',98));m.wi(rsp+0x60,c.get('loading',0));empty=m.heap+0x31000
 if c.get('temporary'):
  entry=0x140438d60;rsp+=8;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
  for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[app,actor,0 if c.get('nullEffect')else sourceEffect]):u.reg_write(r,v)
 elif c.get('world'):
  entry=0x140429c15;u.reg_write(UC_X86_REG_R14,actor);u.reg_write(UC_X86_REG_RDI,0)
 else:
  entry=0x140429617
  for r,v in[(UC_X86_REG_RSI,actor),(UC_X86_REG_RDI,0),(UC_X86_REG_R13,empty),(UC_X86_REG_R15,c.get('amount',10)&0xffffffff)]:u.reg_write(r,v)
 try:u.emu_start(entry,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,trace=trace,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==(m.stop if c.get('temporary')else 0x140429c96);return dict(case=c,trace=trace,**(dict(temporaryHP=m.si(actor+0xe8),commandable=m.si(actor+0xec),result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)if c.get('temporary')else{}))
cases=[dict(amount=a,maximum=m,current=hp,blood=b,state=s,loading=1,creator=0x80000042)for a,m,hp,b,s in itertools.product([-1,0,9,10,11,2147483647],[-1,19,20,65535],[-11,-10,0],['R','G','Y','W','','r','Red','R\0X','constructor','__proto__','toString'],[0,15])]
cases +=[dict(world=True,loading=loading,creator=creator)for loading,creator in itertools.product([0,1,0xffffffff],[98,0x80000042,0x7f000000])]
rows=[run(c)for c in cases];temporary=[run(dict(temporary=True,temporaryHP=hp,removeAmount=a,dying=dy,dead=dead))for hp,a,dy,dead in itertools.product([0,5,32768,65535],[0,3,-1,-2147483648],[[0,0],[0,1],[1,1],[2,1]],[[0,0],[0,1],[1,0],[2,1]])];temporary +=[run(dict(temporary=True,blood=b,state=state))for b,state in itertools.product(['R','G','Y','W','','constructor','R\0X'],[0,15])];temporary +=[run(dict(temporary=True,creature=False)),run(dict(temporary=True,nullEffect=True))];out=m.root/'backups/animations/native-lethal-damage-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,temporary=temporary),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),temporary=len(temporary))))
