"""Original CC14 branch777be0..777f2f, stopped at common cleanup77a4d0.
Original arithmetic, colors, branches and token order execute; scalar reads,
names/controlled object, TLK/parser, strings and final GUI are synthetic lower
services. No gameplay/transport or full original GUI claim.
"""
import importlib.util,itertools,json,re
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);message,app,owner,table,gui,player=[m.heap+n*0x1000 for n in range(1,7)]
def si(v):return (v&0xffffffff)-(0x100000000 if v&0x80000000 else 0)
def cstr(p):return bytes(u.mem_read(p,4096)).split(b'\0')[0].decode('latin1')if p else''
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8)&0xffffffff)).decode('latin1')if m.q(p)else''
def put(p,s):
 global cursor
 b=s.encode('latin1');q=m.heap+cursor;cursor+=(len(b)+32)&~15;assert cursor<0xff000;u.mem_write(q,b+b'\0');m.wq(p,q);m.wi(p+8,len(b));m.wi(p+12,len(b)+1);return p
def hook(u,a,n,_):
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14077a4d0:u.emu_stop();return
 if a==0x1409737c0:calls.append(['object']);m.finish(case['sourceId']);return
 if a==0x1402d9630:assert y==5 and z==1;calls.append(['byte',y,z]);m.finish(case['roll']);return
 if a==0x1402d98d0:assert y==8;calls.append(['char',y]);m.finish(case['modifier']);return
 if a==0x1402d9460:calls.append(['overflow']);m.finish(case.get('overflow',0));return
 if a==0x1406abfc0:calls.append(['name',y&0xffffffff]);put(z,'Source');m.finish(case['names']);return
 if a==0x1406ac1a0:calls.append(['player']);m.finish(player if case['player']else 0);return
 if a==0x14076b6c0:calls.append(['tlk',y&0xffffffff]);put(z,'T'+str(y&0xffffffff));m.finish(1);return
 if a==0x14019a5d0:v=text(z);tokens[y&0xffffffff]=v;calls.append(['token',y&0xffffffff,v]);m.finish();return
 if a==0x1406d7700:calls.append(['parse',y&0xffffffff]);put(z,'P'+str(y&0xffffffff)+json.dumps(tokens,sort_keys=True));m.finish(1);return
 if a==0x14016c810:put(x,str(si(y)));m.finish(x);return
 if a==0x14015d5e0:m.finish(m.q(x));return
 if a==0x140260670:put(x,cstr(y));m.finish(x);return
 if a==0x1400f4e30:put(x,'');m.finish(x);return
 if a in [0x14003d4e0,0x140c10370]:m.finish();return
 if a in [0x140238190,0x14019e620,0x1401881e0]:put(x,cstr(y)if a==0x140238190 else text(y));m.finish(x);return
 if a==0x14016ab00:put(y,text(x)+text(z));m.finish(y);return
 if a==0x14016afb0:
  fmt=cstr(y);values=[z,w]+[m.q(sp+0x28+i*8)for i in range(4)];idx=0
  def replace(match):
   nonlocal idx
   if match[0]=='%%':return'%'
   value=values[idx];idx+=1;return cstr(value)if match[0]=='%s'else str(si(value))
  put(x,re.sub(r'%%|%[sdi]',replace,fmt));m.finish(x);return
 if a==0x14018ded0:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x);return
 if a==0x1406abbc0:m.finish(gui);return
 if a==0x1406f68d0:outputs.append(dict(raw=text(y),flags=z));m.finish();return
 if 0x140777be0<=a<0x140777f2f:return
 raise RuntimeError(f'Unmodeled initiative lower {a:x}')
u.hook_add(UC_HOOK_CODE,hook);rows=[]
profiles=[dict(sourceId=source,names=names,player=playerMode,roll=roll,modifier=modifier,overflow=0)for source,names,playerMode,roll,modifier in itertools.product([0x80000063,0xfffffffe],[0,1],[0,1,2],[0,20,31],[-128,-3,0,127])]
profiles.extend(dict(sourceId=0x80000063,names=names,player=playerMode,roll=20,modifier=-3,overflow=1)for names,playerMode in itertools.product([0,1],[0,1,2]))
for case in profiles:
 calls=[];outputs=[];tokens={0:'old0',1:'old1'};cursor=0x30000;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app,owner);m.wq(0x1412df968,table);m.wq(0x1412df8f0,table);m.wi(player+8,case['sourceId']if case['player']==1 else 0x80000012)
 sp=m.stack+0x1ce00;bp=sp+0x100
 for reg,value in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RBP,bp),(UC_X86_REG_R15,message),(UC_X86_REG_R14,0),(UC_X86_REG_RBX,0),(UC_X86_REG_RSI,0x140000000)]:u.reg_write(reg,value)
 u.emu_start(0x140777be0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x14077a4d0
 rows.append(dict(case=case,calls=calls,outputs=outputs,tokens=tokens))
out=m.root/'backups/animations/native-client-initiative-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
