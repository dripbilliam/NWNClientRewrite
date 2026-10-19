"""Complete move-away object/location VM commands and AI action owners,
EffectTurned constructor379, ClearAction3/44 and bounded state-script lookup.
VM pops/base effect/registry/casts/geometry/movement/list allocation/cancellation,
2DA and script execution are captured lower boundaries. Native queue scans,
float radius gates, retry/parameter ordering and cleanup execute. Tracy off;
real pathfinding, NCS, controller effects and combat are separate integrations.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,target,node,area,otherArea,app,commands,location,owner,vt,path,effect,ints,rules,tables,table,text,vm=[m.heap+n*0x2000 for n in range(18)]
entries={'objectCommand':0x1405363d0,'locationCommand':0x14050e400,'object':0x1403b3180,'location':0x1403b27f0,'turned':0x1405180b0,'clear':0x1403870b0,'control':0x1403a4643,'control7':0x1403a4717}
ranges=[(0x1405180b0,0x140518a6e),(0x140425210,0x14042521c),(0x1403870b0,0x1403877dd),(0x1403a4643,0x1403a4709),(0x1403a4717,0x1403a47db)]
for name in['command-owner','location-command','object-action','location-action']:
 body=json.loads((m.root/f'backups/animations/rea-move-away-{name}.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in body['ranges'])
def i(p):return m.si(p)&0xffffffff
def point(p):return[m.rf(p+n*4)for n in range(3)]
def setpoint(p,v):
 for n,x in enumerate(v):m.wf(p+n*4,x)
def action(p):
 count=int.from_bytes(u.mem_read(p+0x9a,2),'little');return dict(id=i(p),group=int.from_bytes(u.mem_read(p+0x98,2),'little'),types=[i(p+4+n*4)for n in range(count)],values=[m.si(p+0x38+n*8)for n in range(count)])
def putAction(p,id,group,types,values):
 u.mem_write(p,bytes(0xa0));m.wi(p,id);u.mem_write(p+0x98,struct.pack('<HH',group,len(types)));m.wi(p+0x9c,1)
 for n,(typ,value)in enumerate(zip(types,values)):m.wi(p+4+n*4,typ);m.wi(p+0x38+n*8,value)
def refresh():
 m.wq(owner,links[0][0]if links else 0);m.wq(owner+8,links[-1][0]if links else 0);m.wi(owner+16,len(links))
 for n,(ptr,data)in enumerate(links):m.wq(ptr,links[n+1][0]if n+1<len(links)else 0);m.wq(ptr+8,links[n-1][0]if n else 0);m.wq(ptr+16,data)
def append(data,front=False):
 global cursor
 ptr=m.heap+cursor;cursor+=0x100;links.insert(0 if front else len(links),(ptr,data));refresh()
def addAction(front,x,y,z,w,rsp):
 global cursor,lastGroup,nextGroup
 group=z&65535
 if group==65535:group=nextGroup;lastGroup=group;nextGroup+=1
 elif group==65534:group=lastGroup
 types=[];values=[]
 for n in range(12):
  typ=w if n==0 else i(rsp+0x20+n*16)
  if typ==0:break
  types.append(typ);values.append(m.si(m.q(rsp+0x28+n*16)))
 ptr=m.heap+cursor;cursor+=0x100;putAction(ptr,y,group,types,values);append(ptr,front)
def hook(u,a,n,_):
 global popped,output,cursor,disposed,lastGroup,nextGroup
 if a in[m.stop,0x1403a4709,0x1403a47db]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in[0x140286160,0x140286110,0x1402860c0,0x140286030]:
  popped+=1;typ={0x140286160:'object',0x140286110:'int',0x1402860c0:'float',0x140286030:'location'}[a];calls.append(['pop',typ])
  if a==0x140286030:assert y==2;m.wq(z,location)
  elif a==0x1402860c0:m.wf(y,c.get('distance',40))
  else:m.wi(y,100 if typ=='object'else c.get('run',0))
  m.finish(0 if c.get('failPop')==popped else 1)
 elif a==0x14055b850:m.finish(owner)
 elif a==0x140296470:
  calls.append(['lookup',y&0xffffffff]);found=actor if(y&0xffffffff)==99 and c.get('actorExists',True)else target if(y&0xffffffff)==100 and c.get('targetExists',True)else 0;m.wq(z,found);m.finish(0 if found else 1)
 elif a==m.stop+0x10:calls.append(['creature']);m.finish(actor if c.get('creature',True)else 0)
 elif a==0x14055b2e0:calls.append(['areaById',y&0xffffffff]);m.finish(area if c.get('areaExists',True)and(y&0xffffffff)==88 else 0)
 elif a==0x140494e80:calls.append(['area','actor'if x==actor else'target']);m.finish((area if c.get('sameArea',True)else otherArea)if x==actor else area if c.get('targetArea',True)else 0)
 elif a==0x1404953b0:calls.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x140495620:calls.append(['dying']);m.finish(c.get('dying',0))
 elif a==0x140169110:ptr=m.q(y);ptr=m.q(ptr);m.wq(y,ptr);m.finish(m.q(ptr+16)if ptr else 0)
 elif a==0x140386700:
  calls.append(['cancel',y&65535,z&65535]);links[:]=[(ptr,data)for ptr,data in links if int.from_bytes(u.mem_read(data+0x98,2),'little')!=(z&65535)];refresh();m.finish(1)
 elif a in[0x14048cb80,0x14048d3f0]:addAction(a==0x14048d3f0,x,y,z,w,rsp);m.finish()
 elif a==0x140369a40:
  calls.append(['away',point(z),point(w),m.rf(rsp+0x28),m.q(rsp+0x30)==path]);setpoint(y,c.get('away',[7.25,-8.5,9.75]));m.finish(y)
 elif a in[0x14037f940,0x14037fae0]:
  calls.append(['moveBack'if a==0x14037f940 else'moveFront',y&65535,point(z),w&0xffffffff]+[i(rsp+0x28),m.si(rsp+0x30),m.rf(rsp+0x38),m.rf(rsp+0x40)]+[m.si(rsp+off)for off in[0x48,0x50,0x58,0x60,0x68,0x70]])
  if a==0x14037f940:lastGroup=nextGroup;nextGroup+=1
  m.finish()
 elif a==0x14037fc80:calls.append(['waitFront',y&65535]);m.finish()
 elif a==0x140c10324:m.finish(effect)
 elif a==0x1404233d0:u.mem_write(x,bytes(0x120));m.wq(x,101);m.wq(x+0x48,ints);m.wi(x+0x40,8);m.wi(x+24,0x7f000000);m.finish(x)
 elif a==0x140425110:m.wi(x+24,y);m.finish()
 elif a==0x140286330:
  flags=int.from_bytes(u.mem_read(z+10,2),'little');output=dict(type=int.from_bytes(u.mem_read(z+8,2),'little'),subtype=flags&~7,durationType=flags&7,integers=[m.si(m.q(z+0x48)+j*4)for j in range(8)],creatorId=i(z+24));m.finish(c.get('push',1))
 elif a==0x140423770:m.finish()
 elif a==0x14055b810:m.finish(owner if c.get('message',True)else 0)
 elif a==0x14055f720:m.finish(0)
 elif a==m.stop+0x20:m.finish(c.get('lock',0x7f000000))
 elif a==m.stop+0x30:calls.append(['unlock',y&0xffffffff]);m.finish()
 elif a==0x140c10368:assert x==11;m.finish(text)
 elif a==0x1401a68f0:
  name=bytes(u.mem_read(m.q(z),11)).split(b'\0')[0].decode();calls.append(['table',y&0xffffffff,name]);value=c.get('script','fixture_control').encode();m.wq(w,text+0x100);m.wi(w+8,len(value));u.mem_write(text+0x100,value+b'\0');m.finish(1)
 elif a==0x140283990:calls.append(['script',bytes(u.mem_read(m.q(y),64)).split(b'\0')[0].decode(),z&0xffffffff,w&0xffffffff,m.si(rsp+0x20)]);m.wi(actor+0xec,c.get('scriptCommandable',1));m.finish()
 elif a in[0x140c10360,0x140c10370]:
  if a==0x140c10360 and x==location:disposed=True;calls.append(['disposeLocation',y&0xffffffff])
  m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unexpected move-away dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def fbits(v):return int.from_bytes(struct.pack('<f',v),'little')
def run(case):
 global c,calls,popped,output,links,cursor,disposed,lastGroup,nextGroup
 c=case;calls=[];popped=0;output=None;links=[];cursor=0x50000;disposed=False;lastGroup=42;nextGroup=17;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df910,vm);m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(vt+0x190,m.stop+0x20);m.wq(vt+0x188,m.stop+0x30);m.wi(actor+8,99);m.wi(target+8,100);m.wi(commands+8,c.get('modeFlag',1));m.wi(commands+12,99);m.wi(actor+0xec,c.get('commandable',1));m.wq(actor+0x530,path if c.get('path',True)else 0);m.wq(actor+0x100,owner);m.wi(area+0x140,88);m.wi(otherArea+0x140,89);setpoint(actor+0xa4,c.get('origin',[0,0,0]));setpoint(target+0xa4,c.get('threat',[1,0,0]));setpoint(location,c.get('threat',[1,0,0]));m.wi(location+24,88);m.wi(actor+0xc4,7);m.wi(actor+0xc8,88)
 for q in c.get('queue',[]):
  ptr=m.heap+cursor;cursor+=0x100;putAction(ptr,q[0],q[1],[3],[q[2]]);append(ptr)
 mode=c['mode'];actionId=3 if mode=='object'else 44 if mode=='location'else c.get('actionId',3);types=[3,1,2,1]if actionId==3 else[2,2,2,1,2,1];values=[100,c.get('run',0),fbits(c.get('distance',40)),c.get('retries',10)]if actionId==3 else[fbits(v)for v in c.get('threat',[1,0,0])]+[c.get('run',0),fbits(c.get('distance',40)),c.get('retries',10)];putAction(node,actionId,9,types,values);m.wi(node+0x9c,c.get('interruptible',1));m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables);m.wq(tables+0x278,table);u.mem_write(actor+0x771,bytes([c.get('state',3)&255]));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 args=[commands,379 if mode=='turned'else 23 if mode=='objectCommand'else 360,c.get('argc',3),0]if mode in['objectCommand','locationCommand','turned']else[actor,node,c.get('head',0),0]
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 if mode.startswith('control'):u.reg_write(UC_X86_REG_RBP,m.stack+0x1f000);u.reg_write(UC_X86_REG_RDI,actor);u.reg_write(UC_X86_REG_R12,0)
 try:u.emu_start(entries[mode],m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls[-8:])));raise
 assert u.reg_read(UC_X86_REG_RIP)in[m.stop,0x1403a4709,0x1403a47db]
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,queue=[action(data)for _,data in links],output=output,disposed=disposed,commandable=i(actor+0xec),stamp=[i(actor+0xc4),i(actor+0xc8)])
cases=[dict(mode=mode,argc=argc,commandable=commandable,actorExists=exists,creature=creature,targetExists=targetExists)for mode,argc,commandable,exists,creature,targetExists in itertools.product(['objectCommand','locationCommand'],[1,2,3],[0,1,2],[False,True],[False,True],[False,True])]
cases += [dict(mode=mode,argc=3,failPop=fail)for mode,fail in itertools.product(['objectCommand','locationCommand'],[1,2,3])]
cases += [dict(mode=mode,dead=dead,dying=dying,retries=retries,origin=origin,distance=distance,queue=[[3,7,100],[1,7,0],[3,8,101],[3,10,100]])for mode,dead,dying,retries,origin,distance in itertools.product(['object','location'],[0,1,2],[0,1,2],[0,1,2,10],[[0,0,0],[41,0,0],[1,0,1]],[.01,1,40])]
cases += [dict(mode='object',**args)for args in[{'targetExists':False},{'targetArea':False},{'sameArea':False}]]
cases += [dict(mode='locationCommand',**args)for args in[{'sameArea':False},{'areaExists':False},{'origin':[41,0,0]},{'distance':1},{'distance':-1}]]
cases += [dict(mode='turned',push=v)for v in[0,1]]
cases += [dict(mode='clear',actionId=id,head=head,interruptible=interruptible,lock=lock,message=message)for id,head,interruptible,lock,message in itertools.product([3,44],[0,1,2],[0,1],[0x7f000000,11],[False,True])]
cases += [dict(mode=mode,state=state,script=script,scriptCommandable=value)for mode,state,script,value in itertools.product(['control','control7'],[0,3,4,255],['fixture_control',''],[0,1,2])]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-move-away-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),modes={mode:sum(r['case']['mode']==mode for r in rows)for mode in entries})))
