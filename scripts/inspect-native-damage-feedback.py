"""Bounded original CC3 receiver14077115e..14077260d to common tail77a4cd.
Original read loops, damage-group accumulation, colors, names/tokens/templates,
debug branch and floating-output selection execute. Scalar readers, 2DA cells,
names, TLK/parser, strings/CRT and GUI/floating final services are captured lower
providers. Vector resize executes original instructions. Synthetic memory only.
"""
import importlib.util,itertools,json,re,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
message,app,owner,table,rules,twodas,types,groups,options,actor,player,gui=[m.heap+n*0x1000 for n in range(1,13)]
resize=json.loads((m.root/'backups/animations/rea-cc-damage-display-order-owner.json').read_text())['structuredContent']['raw_result']['value']['procedure']['body']['ranges']
resize=[(int(b['start'],16),int(b['end'],16)+1)for b in resize]
def si(v):return (v&0xffffffff)-(0x100000000 if v&0x80000000 else 0)
def alloc(n):
 global cursor
 p=m.heap+cursor;cursor+=(n+31)&~15;assert cursor<0xff000;u.mem_write(p,bytes(n));return p
def cstr(p):return bytes(u.mem_read(p,4096)).split(b'\0')[0].decode('latin1')if p else ''
def text(p):
 n=m.si(p+8)&0xffffffff;q=m.q(p);assert n<65536;return bytes(u.mem_read(q,n)).decode('latin1')if q else ''
def put(p,s):
 b=s.encode('latin1');q=alloc(len(b)+1);u.mem_write(q,b+b'\0');m.wq(p,q);m.wi(p+8,len(b));m.wi(p+12,len(b)+1);return p
def cell(which,row,column):
 if which=='types':
  if row>=case['typeRows']or column!='DamageTypeGroup':return None
  if case['ruleProfile']==2 and row%4==0:return None
  return (row//3 if case['ruleProfile']==0 else row*2+1)%case['groupRows']
 if row>=case['groupRows']:return None
 if column=='FeedbackStrref':return 5000+row
 if column not in ['ColorR','ColorG','ColorB']:return None
 if case['ruleProfile']==2 and (row%2==0 and column=='ColorG' or row%3==0 and column=='ColorB'):return None
 return {'ColorR':(row*41)%256,'ColorG':255-row,'ColorB':-1 if row==0 else 256+row}[column]

def hook(u,a,n,_):
 global objIndex,damageIndex,expectWord,overflowCount
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14077a4cd:u.emu_stop();return
 if a==0x1409737c0:v=0x80000063+objIndex;objIndex+=1;calls.append(['object',v]);m.finish(v);return
 if a==0x1407c4ab0:calls.append(['build',y,z,w]);m.finish(case['newBuild']);return
 if a==0x1402d9600:
  if damageIndex<count:v=int(damage[damageIndex]>=0);expectWord=damageIndex;damageIndex+=1
  else:v=case['debug']
  calls.append(['bool',v]);m.finish(v);return
 if a==0x1402da450:v=damage[expectWord]&0x3fff;calls.append(['word',y,v]);m.finish(v);return
 if a==0x1402d9460:overflowCount+=1;v=int(case.get('failAt',0)==overflowCount);calls.append(['overflow',v]);m.finish(v);return
 if a==0x1401a7010:
  column=text(z);which='types'if x==types else 'groups';value=cell(which,y,column);calls.append(['cell',which,y,column,value]);
  if value is not None:m.wi(w,value)
  m.finish(int(value is not None));return
 if a==0x1406abfc0:
  available=(case['names']>>(int(y&0xffffffff==0x80000064)))&1;put(z,'Source'if y&0xffffffff==0x80000063 else'Target');calls.append(['name',y&0xffffffff,bool(available)]);m.finish(available);return
 if a==0x1406ac1a0:calls.append(['player']);m.finish(player if case['player']else 0);return
 if a==0x140198c60:
  ref=y&0xffffffff;put(z,'P'+str(ref)+json.dumps(tokens,sort_keys=True)if w else'T'+str(ref));calls.append(['parse'if w else'tlk',ref]);m.finish(1);return
 if a==0x14019a5d0:v=text(z);tokens[y&0xffffffff]=v;calls.append(['token',y&0xffffffff,v]);m.finish();return
 if a==0x14016c810:put(x,str(si(y)));calls.append(['number',si(y)]);m.finish(x);return
 if a==0x140704cc0:m.finish(0);return
 if a in [0x1406ca3f0,0x1400f4e30]:put(x,'');m.finish(x);return
 if a==0x14003d8c0:
  length=z&0xffffffff;value=cstr(y)if length==0xffffffff else bytes(u.mem_read(y,length)).decode('latin1')if y else'';put(x,value);m.finish(x);return
 if a in [0x140044840,0x1401881e0,0x14019e620,0x140260650]:put(x,text(y));m.finish(x);return
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
 if a in [0x140c10368,0x140c10324]:m.finish(alloc(x));return
 if a==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if a==0x14018ded0:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x);return
 if a in [0x140c10370,0x1407b9a70]:m.finish();return
 if a==0x1406abbc0:m.finish(gui);return
 if a==0x1406f68d0:outputs.append(dict(raw=text(y),flags=z));m.finish();return
 if a==0x1406ab9b0:m.finish(options);return
 if a==0x1406abb60:calls.append(['target-object',y&0xffffffff]);m.finish(actor if case['target']else 0);return
 if a==0x140766a70:floating.append(dict(raw=text(y),rgb=list(struct.unpack('<fff',u.mem_read(z,12))),font=text(w),flags=m.si(sp+0x28),objectId=m.si(x+8)&0xffffffff));m.finish(1);return
 if a==0x1402d97d0:put(y,'Debug');calls.append(['debug',z]);m.finish(y);return
 if 0x14077115e<=a<=0x14077260d or any(lo<=a<hi for lo,hi in resize):return
 raise RuntimeError(f'Unmodeled damage lower {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
patterns=[[-1]*32,[0]+[-1]*31,[-1,7]+[-1]*30,[2,3,-1,5,-1,-1,-1,11,-1,-1,-1,-1,13]+[-1]*18+[17],list(range(32)),[16383 if i%2 else-1 for i in range(32)]]
rows=[]
for newBuild,pattern,names,playerMode,floatMode,ruleProfile,debug in itertools.product([0,1],range(len(patterns)),range(4),[0,1,2],[0,1,2],range(3),[0,1]):
 case=dict(newBuild=newBuild,pattern=pattern,names=names,player=playerMode,floatMode=floatMode,ruleProfile=ruleProfile,debug=debug,typeRows=13 if ruleProfile==0 or not newBuild else 32,groupRows=10 if ruleProfile==0 else 7,target=1)
 count=32 if newBuild else 13;damage=patterns[pattern];calls=[];outputs=[];floating=[];tokens={1:'old1',2:'old2'};cursor=0x30000;objIndex=damageIndex=overflowCount=0;expectWord=0
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app,owner);m.wq(0x1412df968,table);m.wq(0x1412df8f0,table);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,twodas);m.wq(twodas+0x3a0,types);m.wq(twodas+0x3a8,groups);m.wi(types+0x50,case['typeRows']);m.wi(player+8,0x80000063 if playerMode==1 else 0x80000064);m.wi(actor+8,0x80000064);m.wi(options+0x28,int(floatMode!=0));m.wi(options+0x2c,int(floatMode==1));put(options+0x30,'<c\xfe\x01\x01>')
 sp=m.stack+0x1ce00;bp=sp+0x100;m.wq(sp+0x50,message)
 for reg,val in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RBP,bp),(UC_X86_REG_R15,message),(UC_X86_REG_R14,0),(UC_X86_REG_RBX,0),(UC_X86_REG_RSI,0x140000000)]:u.reg_write(reg,val)
 error=None
 try:u.emu_start(0x14077115e,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x14077a4cd
 except Exception as e:error=str(e)
 rows.append(dict(case=case,damage=damage[:count],calls=calls,outputs=outputs,floating=floating,tokens=tokens,error=error,rip=hex(u.reg_read(UC_X86_REG_RIP))))
 if len(rows)%256==0:print(json.dumps(dict(progress=len(rows))),flush=True)
 if error:break
out=m.root/'backups/animations/native-client-damage-feedback-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),completed=sum(r['error']is None for r in rows),errors=sorted({r['error']for r in rows if r['error']}),lastRip=rows[-1]['rip'],output=str(out))))
