"""Complete original game-derived GetTokenValue140704d40. Client context/
object/creature queries, text/name/race/class/alignment/clock/player providers,
string assignment/decimal formatting, allocation/free/memcpy/logging are captured
lowers. Original InitFromCharArray executes. This tests callback dispatch, direct
fields, gender restoration and suppression/color branches, not lower stat/name/
calendar/network import or complete UI token presentation.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
table,token,out,context,vt,creature,stats,world,app,rules,other=[m.heap+n*0x2000 for n in range(1,12)];objectCall,creatureCall=m.stop+0x80,m.stop+0x90
ranges=[(0x140704d40,0x14070581c),(0x14003d8c0,0x14003d9ab),(0x1407ef2f0,0x1407ef43c)]
def alloc(size):
 global cursor
 assert size<0x10000;ptr=m.heap+cursor;cursor+=(size+31)&~15;u.mem_write(ptr,bytes(size));return ptr
def raw(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff))if m.q(ptr)else b''
def set_string(ptr,value):
 if value[:1]==b'\0':value=b''
 p=alloc(len(value)+1);u.mem_write(p,value+b'\0');m.wq(ptr,p if value else 0);m.wi(ptr+8,len(value));m.wi(ptr+12,len(value)+1)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10368:m.finish(alloc(x));return
 if a==0x140c10370:m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if a==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if a==objectCall:m.finish(creature if c['object']else 0);return
 if a==creatureCall:m.finish(creature if c['creature']else 0);return
 if a==0x140198c60:
  calls.append(['fetch',y&0xffffffff]);set_string(z,f'R{y&0xffffffff}'.encode())
  if c['fetchGender']>=0:u.mem_write(table+0x28,bytes([c['fetchGender']]))
  m.finish(1);return
 if a==0x1401881e0:set_string(x,raw(y));m.finish(x);return
 if a==0x14016c810:set_string(x,str((y&0x7fffffff)-(y&0x80000000)).encode());m.finish(x);return
 if a in[0x1407f3f00,0x1407f67c0]:set_string(y,b'FULL'if a==0x1407f3f00 else b'SUBRACE');m.finish(y);return
 if a in[0x1402a1590,0x1402a14c0,0x140299c30,0x140299a90]:set_string(y,{0x1402a1590:b'RACE',0x1402a14c0:b'race',0x140299c30:b'CLASS',0x140299a90:b'class'}[a]);m.finish(y);return
 if a==0x1407f0f60:m.finish(3);return
 if a==0x1407f1080:m.finish(c['level']);return
 if a==0x1407ef210:set_string(y,b'align'if z else b'ALIGN');m.finish(y);return
 if a==0x1406abea0:m.finish(world);return
 if a==0x1406ac110:m.finish(other if c['player']else 0);return
 if a==0x140115890:calls.append(['warning',m.si(rsp+0x28)]);m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured game token owner{a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,cursor,calls
 c=case;cursor=0x30000;calls=[];u.mem_write(m.heap,bytes(0x20000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x110,m.heap+0x80000);m.wq(rules+0x118,m.heap+0x90000);u.mem_write(table+0x28,bytes([c['gender']]));m.wq(table+0xb0,context if c['context']else 0);m.wi(table+0xb8,c['b8']);m.wi(table+0xbc,c['bc']);m.wi(table+0xc0,123);m.wi(table+0x4c,c['suppression']);m.wq(context,vt);m.wq(vt+0x18,objectCall);m.wq(vt+0x58,creatureCall);m.wq(creature+0x3b0,stats if c['stats']else 0)
 set_string(stats+0x20,c['first'].encode());set_string(stats+0x30,c['last'].encode());set_string(stats+0xbc8,b'DEITY');m.wi(stats+0x50,2);u.mem_write(stats+0xc6,(c['good']&65535).to_bytes(2,'little'));u.mem_write(stats+0xc8,(c['law']&65535).to_bytes(2,'little'));m.wi(world+0x160,-5);m.wi(world+0x164,25);m.wi(world+0x16c,c['world']);u.mem_write(world+0x17c,bytes([6,18]));set_string(other+0x10,b'PLAYER');m.wi(token+0x18,c['action']);m.wi(token+0x2c,199)
 for i in range(4):m.wi(token+0x1c+i*4,100+i)
 set_string(out,b'seed');rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 alignment=c.get('mode')=='alignment'
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[stats,c['lower'],0]if alignment else[table,token,out]):u.reg_write(reg,v)
 u.emu_start(0x1407ef2f0 if alignment else 0x140704d40,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,value=raw(out).hex(),result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,gender=u.mem_read(table+0x28,1)[0],suppression=m.si(table+0x4c),calls=calls)
if __name__=='__main__':
 d=dict(action=0,gender=0,context=True,object=True,creature=True,stats=True,fetchGender=-1,first='FIRST',last='LAST',law=50,good=50,level=258,b8=0,bc=0,suppression=0,world=12,player=True)
 rows=[run(d|dict(action=action,gender=gender,context=context,object=object,creature=creature,stats=stats,fetchGender=fetch))for action,gender,context,object,creature,stats,fetch in itertools.product(range(27),[0,1],[False,True],[False,True],[False,True],[False,True],[-1,0])]
 rows +=[run(d|dict(action=action,first=first,last=last))for action,first,last in itertools.product([3,4],['','FIRST'],['','LAST'])]
 rows +=[run(d|dict(action=action,law=score,good=score))for action,score in itertools.product([13,14],[-1,0,30,31,69,70,100,65535])]
 rows +=[run(d|dict(action=action,b8=b8,bc=bc,suppression=s))for action,b8,bc,s in itertools.product([19,20,21,22],[0,1,2,-1],[0,1,2,-1],[0,1])]
 rows +=[run(d|dict(action=action,world=value,player=player))for action,value,player in itertools.product([17,18,23],[0,5,6,12,18,19,23,0xffffffff],[False,True])]
 rows +=[run(d|dict(mode='alignment',law=law,good=good,lower=lower))for law,good,lower in itertools.product([-1,0,30,31,50,69,70,100,65535],[-1,0,30,31,50,69,70,100,65535],[0,1])]
 target=m.root/'backups/animations/native-game-talk-token-observations.json';target.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(target),rows=len(rows))))
