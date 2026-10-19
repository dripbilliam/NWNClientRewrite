"""Complete original faction leader4ae310, VM GetFactionLeader524190 and
GetChallengeRating520cd0. Raw float/PC/member selection, query ordering and
stack error paths execute. VM, GetFaction/NPC/possessed/creature lookup are
captured boundaries. No full party/faction/network or creation lifecycle proof.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);faction,ids,app,server,manager,commands=[m.heap+n*0x2000 for n in range(6)]
entries={'leader':0x1404ae310,'command':0x140524190,'rating':0x140520cd0};ranges=[]
for name in['faction-leader-owner','faction-leader-command','challenge-rating-command-owner']:
 body=json.loads((m.root/f'backups/animations/rea-{name}.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in body['ranges'])
def hook(u,a,n,_):
 global output
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140357ca0:calls.append(['npc',y&0xffffffff]);m.finish(c.get('npc',1))
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(objects.get(y&0xffffffff,0))
 elif a==0x1403d54d0:calls.append(['possessed',m.si(x+8)&0xffffffff]);m.finish(c.get('possessed',0))
 elif a==0x140286160:calls.append(['pop']);m.wi(y,c.get('targetId',11));m.finish(c.get('pop',1))
 elif a==0x1403d51d0:calls.append(['faction']);m.finish(faction if c.get('faction',True)else 0)
 elif a==0x140286470:output=y&0xffffffff;calls.append(['pushObject',output]);m.finish(c.get('push',1))
 elif a==0x1402863b0:output=u.reg_read(UC_X86_REG_XMM1)&0xffffffff;calls.append(['pushFloat',output]);m.finish(c.get('push',1))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unknown faction leader dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,output,objects
 c=case;calls=[];output=None;objects={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,server);m.wq(server+8,server if c.get('server',True)else 0);m.wq(server+0x100b0,manager if c.get('manager',True)else 0);m.wq(faction,ids);m.wi(faction+8,len(c.get('members',[11,22,99,33])));m.wi(faction+16,7)
 for n,id in enumerate(c.get('members',[11,22,99,33])):m.wi(ids+n*4,id)
 for n,id in enumerate([11,22,33]):
  if c.get('missing')==id:continue
  ptr=m.heap+0x30000+n*0x3000;stats=ptr+0x1000;objects[id]=ptr;m.wi(ptr+8,id);m.wi(ptr+0x89c,c.get('pc',[0,0,0])[n]);m.wq(ptr+0xad0,0 if c.get('noStats')==id else stats);m.wf(stats+0xd0,c.get('ratings',[1,2,2])[n])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,faction if c['mode']=='leader'else commands)
 try:u.emu_start(entries[c['mode']],m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,calls=calls)
cases=[dict(mode='leader',npc=npc,server=server,manager=manager,pc=pc,ratings=ratings,possessed=possessed)for npc,server,manager,pc,ratings,possessed in itertools.product([0,1,2],[False,True],[False,True],[[0,0,0],[0,1,0],[2,0,0]],[[0,0,0],[1,2,2],[-1,0,.25],[3,2,1]],[0,1,2])]
cases += [dict(mode='leader',npc=npc,missing=missing,noStats=noStats,members=members)for npc,missing,noStats,members in itertools.product([0,1],[11,22,99],[11,22,None],[[],[99],[11,22,33],[33,22,11]])]
cases += [dict(mode=mode,npc=npc,targetId=id,pop=pop,push=push,faction=faction,noStats=stats)for mode,npc,id,pop,push,faction,stats in itertools.product(['command','rating'],[0,1],[11,99],[0,1],[0,1],[False,True],[None,11])]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-faction-leader-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
