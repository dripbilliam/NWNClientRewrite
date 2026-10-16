"""Complete original turning resistance77/88 apply/remove/query and script
constructor owners. Original FNV and Get/SetInteger execute. Lower base effect
allocation/creator/VM/object/dead/ruleset providers captured; no turning AI claim.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,stats,vt,effect,pool,commands=[m.heap+n*0x2000 for n in range(6)]
ranges=[(0x140434b20,0x140434bd6),(0x1404394e0,0x1404394e6),(0x140396290,0x14039633e),(0x14051c650,0x14051c763),(0x1402ae870,0x1402ae899),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c)]
def allocate(size):
 global cursor
 result=m.heap+cursor;cursor+=(size+15)&~15;return result
def snapshot(e):return dict(id=f'{m.q(e):016x}',type=int.from_bytes(u.mem_read(e+8,2),'little'),subtype=int.from_bytes(u.mem_read(e+10,2),'little')&~7,creatorId=m.si(e+24)&0xffffffff,integers=[m.si(m.q(e+0x48)+n*4)for n in range(8)])
def hook(u,a,n,_):
 global output
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==m.stop+0x10:calls.append(['creature']);m.finish(actor if c.get('creature',True)else 0)
 elif a==0x1404953b0:calls.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x1402a4130:
  h=0xcbf29ce484222325
  for b in b'TURN_RESISTANCE_AFFECTS_PCS':h=((h^b)*0x100000001b3)&0xffffffffffffffff
  assert y==h;calls.append(['rule','TURN_RESISTANCE_AFFECTS_PCS',z]);m.finish(c.get('rule',0))
 elif a==0x140286110:calls.append(['pop']);m.wi(y,c.get('value',0));m.finish(c.get('pop',1))
 elif a==0x140286330:output=snapshot(z);calls.append(['push']);m.finish(c.get('push',1))
 elif a==0x140c10324:m.finish(allocate(x))
 elif a==0x1404233d0:
  m.wq(x,101);m.wq(x+0x48,allocate(32));m.wi(x+24,0x7f000000);m.finish(x)
 elif a==0x140425110:calls.append(['creator',y&0xffffffff]);m.wi(x+24,y);m.finish()
 elif a in [0x140423770,0x140c10360]:m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected turn-resistance owner dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor,output
 c=case;calls=[];cursor=0x10000;output=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);m.wi(stats+0xb0,c.get('pc',0));u.mem_write(effect+10,struct.pack('<H',c.get('durationType',2)|8));m.wi(commands+12,99)
 m.wq(actor+0x150,pool);values=c.get('effects',[]);m.wi(actor+0x158,len(values))
 for n,(type_,amount)in enumerate(values):
  e=allocate(0x110);m.wq(pool+n*8,e);u.mem_write(e+8,struct.pack('<H',type_));m.wq(e+0x48,allocate(32));m.wi(m.q(e+0x48),amount)
 mode=c['mode'];entry={'apply':0x140434b20,'remove':0x1404394e0,'query':0x140396290,'constructor':0x14051c650}[mode];args=[0,actor if c.get('object',True)else 0,effect,c.get('loading',0)]if mode=='apply'else[actor]if mode=='query'else[commands,c.get('ordinal',553),1]if mode=='constructor'else[0,actor,effect]
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(r,v&0xffffffffffffffff)
 u.emu_start(entry,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return dict(case=c,calls=calls,result=(result^0x80000000)-0x80000000,output=output)
rows=[]
for exists,creature,loading,dead,duration,pc,rule in itertools.product([False,True],[False,True],[0,1],[0,1],range(5),[0,1],[0,1,-1]):rows.append(run(dict(mode='apply',object=exists,creature=creature,loading=loading,dead=dead,durationType=duration,pc=pc,rule=rule)))
for values in [[],[(77,5)],[(88,5)],[(77,-3),(88,-7),(78,999)],[(77,2147483647),(77,5),(88,-2147483648)],[(76,3),(77,9),(78,100),(88,4),(89,5)]]:rows.append(run(dict(mode='query',effects=values)))
for ordinal,value in itertools.product([552,553],[-2147483648,-1,0,5,2147483647]):rows.append(run(dict(mode='constructor',ordinal=ordinal,value=value)))
rows.append(run(dict(mode='constructor',pop=0)));rows.append(run(dict(mode='constructor',push=0)));rows.append(run(dict(mode='remove')))
out=m.root/'backups/animations/native-turn-resistance-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
