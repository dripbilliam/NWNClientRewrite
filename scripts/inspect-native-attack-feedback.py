"""Original CC5/6 receiver branches772612..774fb5, stopped at common tail77a4cd.
Read-only installed nwmain in isolated Unicorn memory. Original branch and
string formatting instructions execute; wire scalar readers, names, tokens,
TLK/parser, feat lookup and final GUI/floating services are explicit synthetic
boundaries. Factored profiles are finite coverage, not whole-combat proof.
"""
import importlib.util,itertools,json,re,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
message,app,owner,table,rules,options,actor,player,gui,feat=[m.heap+n*0x1000 for n in range(1,11)]
def si(v):return (v&0xffffffff)-(0x100000000 if v&0x80000000 else 0)
def alloc(n):
 global cursor
 p=m.heap+cursor;cursor+=(n+31)&~15;assert cursor<0xff000;u.mem_write(p,bytes(n));return p
def cstr(p):return bytes(u.mem_read(p,4096)).split(b'\0')[0].decode('latin1')if p else ''
def text(p):
 n=m.si(p+8)&0xffffffff;q=m.q(p);assert n<65536;return bytes(u.mem_read(q,n)).decode('latin1')if q else ''
def put(p,s):
 b=s.encode('latin1');q=alloc(len(b)+1);u.mem_write(q,b+b'\0');m.wq(p,q);m.wi(p+8,len(b));m.wi(p+12,len(b)+1);return p
def hook(u,a,n,_):
 global objIndex,scalarIndex,overflowCount
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14077a4cd:u.emu_stop();return
 if a==0x1409737c0:v=0x80000063+objIndex;objIndex+=1;calls.append(['object',v]);m.finish(v);return
 if a in [0x1402d98d0,0x1402d9630,0x1402da450,0x1402d9600]:
  kind={0x1402d98d0:'char',0x1402d9630:'byte',0x1402da450:'word',0x1402d9600:'bool'}[a]
  expected,bits,v=scalars[scalarIndex];scalarIndex+=1;assert kind==expected,(kind,expected,scalarIndex)
  if bits:assert y==bits,(y,bits,scalarIndex)
  calls.append([kind,bits,v]);m.finish(v);return
 if a==0x1402d9460:overflowCount+=1;v=int(case.get('failAt',0)==overflowCount);calls.append(['overflow',v]);m.finish(v);return
 if a==0x1406abfc0:
  available=(case['names']>>(int(y&0xffffffff==0x80000064)))&1;put(z,'Source'if y&0xffffffff==0x80000063 else'Target');calls.append(['name',y&0xffffffff,bool(available)]);m.finish(available);return
 if a==0x1406ac1a0:calls.append(['player']);m.finish(player if case['player']else 0);return
 if a in [0x140198c60,0x1406d7700]:
  ref=y&0xffffffff;parsed=bool(w)if a==0x140198c60 else True
  put(z,'P'+str(ref)+json.dumps(tokens,sort_keys=True)if parsed else'T'+str(ref));calls.append(['parse'if parsed else'tlk',ref]);m.finish(1);return
 if a==0x14019a5d0:v=text(z);tokens[y&0xffffffff]=v;calls.append(['token',y&0xffffffff,v]);m.finish();return
 if a==0x14016c810:put(x,str(si(y)));calls.append(['number',si(y)]);m.finish(x);return
 if a in [0x1406ca3f0,0x1400f4e30]:put(x,'');m.finish(x);return
 if a in [0x14003d8c0,0x140238190]:
  length=z&0xffffffff;value=cstr(y)if a==0x140238190 or length==0xffffffff else bytes(u.mem_read(y,length)).decode('latin1')if y else'';put(x,value);m.finish(x);return
 if a in [0x140044840,0x1401881e0,0x14019e620,0x140260650]:put(x,text(y));m.finish(x);return
 if a==0x140260680:m.finish(int(text(x)==cstr(y)));return
 if a==0x14016ab00:put(y,text(x)+text(z));m.finish(y);return
 if a==0x14016afb0:
  fmt=cstr(y);values=[z,w]+[m.q(sp+0x28+i*8)for i in range(6)];idx=0
  def replace(match):
   nonlocal idx
   code=match.group(0)
   if code=='%%':return'%'
   value=values[idx];idx+=1
   if code=='%s':return cstr(value)
   if code in ['%d','%i']:return str(si(value))
   if code=='%u':return str(value&0xffffffff)
   raise RuntimeError('Unmodeled format '+fmt)
  put(x,re.sub(r'%%|%[sdiu]',replace,fmt));m.finish(x);return
 if a==0x14018ded0:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x);return
 if a in [0x140c10370,0x1407b9a70]:m.finish();return
 if a==0x1406abbc0:m.finish(gui);return
 if a==0x1406f68d0:outputs.append(dict(raw=text(y),flags=z));m.finish();return
 if a==0x1406ab9b0:m.finish(options);return
 if a==0x1406ab9e0:calls.append(['target-creature',y&0xffffffff]);m.wi(actor+8,y);m.finish(actor if case['target']else 0);return
 if a==0x140766a70:floating.append(dict(raw=text(y),rgb=list(struct.unpack('<fff',u.mem_read(z,12))),font=text(w),flags=m.si(sp+0x28),objectId=m.si(x+8)&0xffffffff));m.finish(1);return
 if a==0x1402d97d0:put(y,'Debug');calls.append(['debug',z]);m.finish(y);return
 if a==0x140115890:calls.append(['warning',cstr(m.q(sp+0x38))]);m.finish();return
 if a==0x1402a3bd0:calls.append(['feat',y&0xffff]);m.finish(feat if case['featAvailable']else 0);return
 if 0x140772612<=a<0x140774fba:return
 raise RuntimeError(f'Unmodeled attack lower {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
default=dict(minor=5,modifier=3,roll=12,result=1,combatMode=0,offhand=0,sneakAttack=0,deathAttack=0,specialMinus534=0,coupDeGrace=0,threatened=0,confirmation=17,concealmentChance=50,attackType=15,debug=0,names=3,player=1,floating=1,target=1,featAvailable=1)
profiles=[]
for minor,result,combatMode in itertools.product([5,6],range(16),range(16)):profiles.append(default|dict(minor=minor,result=result,combatMode=combatMode))
for minor,flags,numeric in itertools.product([5,6],range(64),range(4)):
 profiles.append(default|dict(minor=minor,**{k:(flags>>i)&1 for i,k in enumerate(['offhand','sneakAttack','deathAttack','specialMinus534','coupDeGrace','threatened'])},modifier=[-128,-3,0,127][numeric],roll=[0,1,20,31][numeric],confirmation=[0,1,20,31][numeric],result=[3,8,9,10][numeric],concealmentChance=[0,1,100,127][numeric],debug=numeric%2))
for minor,names,playerMode,floatMode,target in itertools.product([5,6],range(4),range(3),[0,1],[0,1]):profiles.append(default|dict(minor=minor,names=names,player=playerMode,floating=floatMode,target=target,sneakAttack=1,deathAttack=1,coupDeGrace=1,specialMinus534=1,result=3))
for minor,mode,flags in itertools.product([5,6],[1,4,9,12],range(64)):
 profiles.append(default|dict(minor=minor,combatMode=mode,**{k:(flags>>i)&1 for i,k in enumerate(['offhand','sneakAttack','deathAttack','specialMinus534','coupDeGrace','threatened'])}))
for attackType,available in itertools.product([0,1,867,868,0xfde8,0xfde9,0xfdea,0xfdeb,65535],[0,1]):profiles.append(default|dict(minor=6,attackType=attackType,featAvailable=available))
rows=[]
for case in profiles:
 calls=[];outputs=[];floating=[];tokens={1:'old1',2:'old2'};cursor=0x30000;objIndex=scalarIndex=overflowCount=0
 scalars=[('char',8,case['modifier']),('byte',5,case['roll']),('byte',4,case['result'])]
 if case['minor']==6:scalars.append(('word',16,case['attackType']))
 scalars += [('byte',4,case['combatMode'])]+[('bool',0,case[k])for k in ['offhand','sneakAttack','deathAttack']]
 if case['minor']==5:scalars += [('bool',0,case[k])for k in ['specialMinus534','coupDeGrace']]
 scalars.append(('bool',0,case['threatened']))
 if case['threatened']:scalars.append(('byte',5,case['confirmation']))
 if case['result']in [8,9]:scalars.append(('byte',7,case['concealmentChance']))
 scalars.append(('bool',0,case['debug']))
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app,owner);m.wq(0x1412df968,table);m.wq(0x1412df8f0,table);m.wq(0x1412df8f8,rules);m.wi(feat,5001);m.wi(player+8,0x80000063 if case['player']==1 else 0x80000064);m.wi(actor+8,0x80000064);m.wi(options+0x28,case['floating'])
 sp=m.stack+0x1ce00;bp=sp+0x100
 for reg,val in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RBP,bp),(UC_X86_REG_R15,message),(UC_X86_REG_R14,0),(UC_X86_REG_RBX,0),(UC_X86_REG_RSI,0x140000000)]:u.reg_write(reg,val)
 error=None
 try:u.emu_start(0x140772612 if case['minor']==5 else 0x140773d98,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x14077a4cd;assert scalarIndex==len(scalars)
 except Exception as e:error=str(e)
 rows.append(dict(case=case,calls=calls,outputs=outputs,floating=floating,tokens=tokens,error=error,rip=hex(u.reg_read(UC_X86_REG_RIP))))
 if len(rows)%256==0:print(json.dumps(dict(progress=len(rows))),flush=True)
 if error:break
out=m.root/'backups/animations/native-client-attack-feedback-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),completed=sum(r['error']is None for r in rows),errors=sorted({r['error']for r in rows if r['error']}),lastRip=rows[-1]['rip'],output=str(out))))
