"""Original CC8 branch7760c1..7766bd of770c80 (verified dispatch table77a5ac,
index7). Native scalar read order, overflow guards, lookup/admission, template,
custom-token, color, output and cleanup branches execute unchanged. Outer common
dispatcher/profiling is excluded. Scalar readers, names/spell/baseitem/TLK,
format/parser and GUI output are captured lower services, not raw wire or GPU.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
message,spell,player,app,tlk,rules,widget,baseitem=[m.heap+n*0x1000 for n in range(1,9)]
def s(p):return bytes(u.mem_read(p,256)).split(b'\0')[0].decode('latin1')if p else ''
def get(p):return strings.get(p,'')
def parse(ref):
 if ref==0xf721:return 'Item('+tokens.get(0,'')+')'
 if ref==0x28f2:return tokens.get(0,'')+' '+tokens.get(1,'')+' '+tokens.get(2,'')
 return 'Alt('+tokens.get(0,'')+')'
def hook(u,a,n,_):
 global readBool,overflow,allocated
 if a in [m.stop,0x14077a4cd]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x1406ca3f0,0x1400f4e30]:strings[x]='';m.finish(x)
 elif a in [0x14003d4e0,0x1401695e0]:m.finish()
 elif a==0x1409737c0:calls.append(['object']);m.finish(c.get('sourceId',0x80000063))
 elif a==0x1402d9bc0:calls.append(['dword',y]);m.finish(c.get('spellId',37))
 elif a==0x1402d9600:
  values=[c.get('identified',1),c.get('casting',1),c.get('hasItem',0),c.get('localized',1)];calls.append(['bool']);m.finish(values[readBool]);readBool+=1
 elif a==0x1402d9630:calls.append(['byte',y,z]);m.finish(c.get('baseItem',8))
 elif a==0x1402d9460:overflow+=1;calls.append(['overflow']);m.finish(int(c.get('fail',0)==overflow))
 elif a==0x1409735f0:calls.append(['localized',z,w]);strings[y]='ItemLoc';m.finish(y)
 elif a==0x1402d97d0:calls.append(['string',z]);strings[y]='ItemOverride';m.finish(y)
 elif a==0x14076b750:calls.append(['spell',y&0xffffffff]);m.finish(spell if c.get('spell',1)else 0)
 elif a==0x1406abfc0:calls.append(['name',y&0xffffffff]);strings[z]='Caster';m.finish(c.get('name',1))
 elif a==0x1406ac1a0:calls.append(['player']);m.finish(player if c.get('player',1)else 0)
 elif a==0x14015d5e0:
  p=m.heap+0x20000+allocated*0x100;allocated+=1;u.mem_write(p,get(x).encode('latin1')+b'\0');m.finish(p)
 elif a==0x14016afb0:assert s(y)=='%s%s%s';strings[x]=s(z)+s(w)+s(m.q(rsp+0x28));m.finish(x)
 elif a==0x14076b6c0:calls.append(['tlk',y&0xffffffff]);strings[z]='T'+str(y&0xffffffff);m.finish()
 elif a==0x14019a5d0:calls.append(['token',y&0xffffffff,get(z)]);tokens[y&0xffffffff]=get(z);m.finish()
 elif a==0x1406d7700:calls.append(['parse',y&0xffffffff]);assert w==0 and m.si(rsp+0x28)==0 and m.si(rsp+0x30)==0;strings[z]=parse(y&0xffffffff);m.finish()
 elif a==0x140238190:strings[x]=s(y);m.finish(x)
 elif a==0x14016ab00:strings[y]=get(x)+get(z);m.finish(y)
 elif a in [0x1401881e0,0x140260650]:strings[x]=get(y);m.finish(x)
 elif a==0x14076b6d0:calls.append(['baseItem',y&0xffffffff]);m.finish(baseitem)
 elif a==0x14029de50:strings[y]='Base';m.finish(y)
 elif a==0x1406abbc0:m.finish(widget)
 elif a==0x14018ded0:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x)
 elif a==0x14019e620:strings[x]=get(y);m.finish(x)
 elif a==0x1406f68d0:calls.append(['display',get(y),z&0xffffffff,w&0xffffffff,m.si(rsp+0x28),s(m.q(rsp+0x30))]);m.finish()
 elif not 0x1407760c1<=a<=0x1407766bd:raise AssertionError(f'Unexpected CC8 lower {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,strings,tokens,readBool,overflow,allocated
 c=case;calls=[];strings={};tokens={1:'old1',2:'old2'};readBool=overflow=allocated=0;u.mem_write(m.heap,bytes(0x50000));rsp=m.stack+0x1ce00;rbp=rsp+0x100;u.mem_write(rsp,bytes(0x3000))
 m.wq(0x1412df970,app);m.wq(app,app);m.wq(0x1412df968,tlk);m.wq(0x1412df8f8,rules);m.wq(0x1412df8f0,rules);m.wi(player+8,c.get('playerId',c.get('sourceId',0x80000063)));m.wi(spell+0x190,c.get('alt',0));m.wi(spell+0x10,123)
 u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rbp);u.reg_write(UC_X86_REG_R15,message);u.reg_write(UC_X86_REG_R14,0)
 try:u.emu_start(0x1407760c1,m.stop,count=3000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==0x14077a4cd
 return dict(case=c,calls=calls,tokens=tokens)
rows=[run(dict(identified=identified,casting=casting,hasItem=item,localized=localized,spell=spellOk,alt=alt,name=name,player=hasPlayer,playerId=playerId,fail=fail))for identified,casting,item,localized,spellOk,alt,name,hasPlayer,playerId,fail in itertools.product([0,1],[0,1],[0,1],[0,1],[0,1],[0,456],[0,1],[0,1],[0x80000063,0x80000064],[0,1,2])]
out=m.root/'backups/animations/native-client-spell-message-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
