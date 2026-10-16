"""Unchanged VM42114054b060 and quick-chat sender1404df1c0. VM reads,
canonical/client/cast queries, player-list storage and packet write/transport
are captured boundaries. Native float range, endpoint snapshot, word narrowing,
bitwise result and early termination execute. No wire serialization claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,app,server,message,command,vm,playerList,pointers,area,otherArea,vtable=[m.heap+n*0x1000 for n in range(1,12)]
players=[m.heap+0x20000+n*0x1000 for n in range(3)];viewers=[m.heap+0x30000+n*0x1000 for n in range(3)]
def hook(u,a,n,_):
 global built,sendIndex
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140286110:m.wi(y,c.get('code',7));m.finish(1)
 elif a==0x140286160:m.wi(y,c.get('target',0x7f000000));m.finish(1)
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(actor if c.get('exists',True) else 0)
 elif a==0x14055b810:calls.append(['message']);m.finish(message if c.get('message',True) else 0)
 elif a==0x1404df1c0 and c['operation']=='command':calls.append(['quickChat',y&0xffffffff,z&65535]);m.finish(1)
 elif a==0x14055b850:calls.append(['objectArray']);m.finish(server)
 elif a==0x140296470:calls.append(['object',y&0xffffffff]);m.wq(z,actor);m.finish(0 if c.get('exists',True) else 1)
 elif a==m.stop+0x10:calls.append(['asCreature']);m.finish(actor if c.get('creature',True) else 0)
 elif a==0x140494e80:
  calls.append(['area',99 if x==actor else viewers.index(x)+100]);which=c.get('area',1) if x==actor else c.get('viewers',[{}]*3)[viewers.index(x)].get('area',1);m.finish(area if which==1 else otherArea if which==2 else 0)
 elif a==0x14055b8e0:calls.append(['players']);m.finish(playerList)
 elif a==0x1404ba840:
  index=players.index(x);calls.append(['clientObject',index]);m.finish(0 if c.get('viewers',[{}]*3)[index].get('missing') else viewers[index])
 elif a==0x1402d54a0:built=[];m.finish()
 elif a==0x1404763e0:built.append(['objectId',y&0xffffffff]);m.finish()
 elif a==0x1402dbcd0:built.append(['word',y&65535]);m.finish()
 elif a==0x1402d5880:
  index=len([v for v in calls if v[0]=='send']);calls.append(['packet',list(built)]);m.finish(c.get('build',1))
 elif a==0x1404dc490:
  calls.append(['send',y&0xffffffff,z&255,w&255]);m.finish(c.get('results',[1,1,1])[sendIndex]);sendIndex+=1
 elif not any(lo<=a<hi for lo,hi in [(0x14054b060,0x14054b0ff),(0x1404df1c0,0x1404df411)]):raise AssertionError(f'Uncaptured quick-chat dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,built,sendIndex
 c=case;calls=[];built=[];sendIndex=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,server);m.wq(0x1412df910,vm);m.wi(command+0xc,99);m.wi(actor+8,99);m.wq(actor,vtable);m.wq(vtable+0x60,m.stop+0x10)
 m.wq(playerList,pointers);m.wi(playerList+8,len(c.get('viewers',[{}]*3)))
 for i,p in enumerate(players):
  m.wq(pointers+i*8,p);m.wi(p+0x48,1000+i);m.wi(viewers[i]+8,100+i)
  for n,v in enumerate(c.get('viewers',[{}]*3)[i].get('position',[1,0,0]) if i<len(c.get('viewers',[{}]*3)) else [0,0,0]):m.wf(viewers[i]+0xa4+n*4,v)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes(0x700));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 u.reg_write(UC_X86_REG_RCX,command if c['operation']=='command' else message);u.reg_write(UC_X86_REG_RDX,421 if c['operation']=='command' else 99);u.reg_write(UC_X86_REG_R8,2 if c['operation']=='command' else c.get('code',7))
 u.emu_start(0x14054b060 if c['operation']=='command' else 0x1404df1c0,m.stop,count=15000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
rows=[run(dict(operation='command',code=code,target=target,exists=exists,message=message)) for code,target,exists,message in itertools.product([-1,0,7,65535,65536],[99,100,0x7f000000],[False,True],[False,True])]
rows += [run(dict(operation='send',code=code,exists=exists,creature=creature,area=areaId,viewers=viewers,build=build,results=results)) for code,exists,creature,areaId,viewers,build,results in itertools.product([7,65537],[False,True],[False,True],[0,1],[[],[{}, {}, {}],[dict(position=[20,0,0]),dict(position=[20.00001,0,0]),dict(position=[0,0,20])],[dict(missing=True),dict(area=2),dict(area=0)]],[0,1],[[1,1,1],[0,1,1],[2,1,1],[3,0,1]])]
out=m.root/'backups/animations/native-quick-chat-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
