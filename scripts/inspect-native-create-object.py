"""Full original ExecuteCommandCreateObject140513be0 and CResRef byte-copy
owners. Typed VM pops/push, allocation, template/constructor/destructor,
placement, effect application and map-pin transport are captured boundaries.
This proves command orchestration and VM cleanup, not the lower loaders,
collision/AI insertion, rendering, or network serialization themselves.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
command,app,area,actor,location,vt,effect,clientlist,clientarray=[m.heap+n*0x1000 for n in range(1,10)]
kindnames={1:'creature',2:'item',32:'waypoint',64:'placeable',128:'store'}
ctors={0x14037a300:'creature',0x140462e90:'item',0x140508d60:'waypoint',0x1404af9c0:'placeable',0x1404f9a70:'store'}
loads={0x140397dd0:'creature',0x14046a7c0:'item',0x140509cf0:'waypoint',0x1404b4650:'placeable',0x1404fb960:'store'}
adds={0x140380470:'creature',0x140464bb0:'item',0x140508fa0:'waypoint',0x1404b1a40:'placeable',0x1404fa540:'store'}
ranges=[(0x140513be0,0x14051470f),(0x14018ded0,0x14018deed),(0x140190d30,0x140190dcd)]

def string(ptr,text):
 global cursor
 raw=text.encode('cp1252');target=m.heap+cursor;cursor+=(len(raw)+16)&~15;u.mem_write(target,raw+b'\0');m.wq(ptr,target if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)
 names[target]='tag' if text==c.get('tag','new tag') else 'reference'
def text(ptr):
 raw=bytearray()
 if ptr:
  while len(raw)<4096:
   byte=u.mem_read(ptr+len(raw),1)[0]
   if byte==0:break
   raw.append(byte)
 return raw.decode('cp1252')
def vector(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12)))
def writevector(ptr,values):u.mem_write(ptr,struct.pack('<3f',*values))
def identity(ptr):return m.si(ptr+8)&0xffffffff
def selected_area(ptr):return 88 if ptr else None

def hook(u,a,n,_):
 global pop_index,result
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x140286110,0x1402861b0,0x140286030]:
  index=pop_index;pop_index+=1;events.append(['pop',index,['int','string','location','int','string'][index]])
  if index==c.get('popFail',-1):m.finish(0);return
  if index in [0,3]:m.wi(y,c['type'] if index==0 else c.get('appear',0))
  elif index in [1,4]:string(y,c.get('reference','MiXeD_blueprint_LONG') if index==1 else c.get('tag','new tag'))
  else:m.wq(z,location)
  m.finish(1);return
 if a==0x140286470:result=y&0xffffffff;events.append(['push',result]);m.finish(c.get('push',1));return
 if a==0x14055b850:m.finish(app);return
 if a==0x140296470:calls.append(['lookup',y&0xffffffff]);m.wq(z,area);m.finish(c.get('lookupStatus',0));return
 if a==0x140c10324:events.append(['allocate',x]);m.finish(effect if x==0x110 else actor);return
 if a in ctors:
  kind=ctors[a];calls.append(['construct',kind]);events.append(['constructor',kind,y&0xffffffff,z&0xffffffff if kind=='creature' else None,w&0xffffffff if kind=='creature' else None]);m.wq(actor,vt);m.wq(vt,m.stop+0x20)
  base=actor+0x48 if kind=='item' else actor;m.wi(base+8,99);m.wi(base+0xa0,0x7f000000);m.wq(actor+0x530,m.heap+0x11000);m.finish(actor);return
 if a in loads:
  calls.append(['load',loads[a],text(y),text(m.q(z))]);m.wi(actor+0x3b4,c.get('trap',0));m.wi(actor+0x308,c.get('note',0));m.wi(actor+0x30c,c.get('enabled',0));m.finish(c.get('load',1));return
 if a==0x140115890:calls.append(['warning',text(m.q(rsp+0x38))]);m.finish();return
 if a==m.stop+0x20:calls.append(['destroy',99]);m.finish();return
 if a==0x14049bb40:calls.append(['position',vector(y),z&0xffffffff]);writevector(x+0xa4,vector(y));m.finish();return
 if a in [0x14049b910,0x1404b7680]:calls.append(['placeableOrientation' if a==0x1404b7680 else 'orientation',vector(y)]);writevector(x+0xb0,vector(y));m.finish();return
 if a==m.stop+0x10:calls.append(['asArea']);m.finish(0 if c.get('nonarea') else area);return
 if a==0x14036aa90:
  calls.append(['safe',selected_area(x),vector(y),m.xmm(UC_X86_REG_XMM2),m.si(rsp+0x28)]);writevector(m.q(rsp+0x30),c.get('safeOutput',[6,7,8]));m.finish(c.get('safe',1));return
 if a==0x14036a210:calls.append(['height',selected_area(x),vector(y)]);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',c.get('height',9)),'little'));m.finish();return
 if a==0x1404233d0:calls.append(['effect',y]);m.wi(effect+0x40,8);m.wq(effect+0x48,m.heap+0x12000);m.finish(effect);return
 if a==0x140425110:calls.append(['creator',y&0xffffffff]);m.wi(effect+0x18,y);m.finish();return
 if a==0x14048e350:calls.append(['apply',int.from_bytes(u.mem_read(y+8,2),'little'),m.si(y+0x18)&0xffffffff,m.si(m.q(y+0x48)),z&0xffffffff,w&0xffffffff]);m.finish(0);return
 if a in adds:
  kind=adds[a];point=[m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28)];calls.append(['add',kind,selected_area(y),point,m.si(rsp+0x30),m.si(rsp+0x38) if kind=='creature' else None]);base=actor+0x48 if kind=='item' else actor;writevector(base+0xa4,point);m.wi(base+0xa0,88 if y else 0x7f000000);m.finish();return
 if a==0x14008ae10:calls.append(['trap',selected_area(x-0x158),y&0xffffffff]);m.finish();return
 if a==0x14055b810:calls.append(['message']);m.finish(app);return
 if a==0x14055b8e0:calls.append(['clients']);m.finish(clientlist);return
 if a==0x1404ba840:
  i=(x-m.heap-0x14000)//0x100;calls.append(['clientObject',i]);m.finish(m.heap+0x18000+i*0x100 if c['clients'][i] is not None else 0);return
 if a==0x1401693c0:m.finish(y);return
 if a==0x1404dc2d0:i=(y-m.heap-0x14000)//0x100;calls.append(['mapPin',i,z&0xffffffff,vector(w),m.si(rsp+0x30)]);m.finish();return
 if a in [0x140c10360,0x140c10370]:events.append(['free',names.get(x,'null' if not x else hex(x)),y if a==0x140c10360 else None]);m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured CreateObject dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,cursor,calls,events,pop_index,result,names
 c=case;cursor=0x20000;calls=[];events=[];pop_index=0;result=None;names={location:'location'};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(command+12,77);m.wq(area,vt+0x100);m.wq(vt+0x150,m.stop+0x10);writevector(location,[1,2,3]);writevector(location+12,[.6,.8,0]);m.wi(location+24,88)
 clients=c.get('clients',[]);m.wq(clientlist,clientarray);m.wi(clientlist+8,len(clients))
 for i,areaid in enumerate(clients):m.wq(clientarray+i*8,m.heap+0x14000+i*0x100);m.wi(m.heap+0x180a0+i*0x100,areaid if areaid is not None else 0)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[command,243,c.get('argc',5)]):u.reg_write(reg,value)
 try:u.emu_start(0x140513be0,m.stop,count=30000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls,events=events)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 status=u.reg_read(UC_X86_REG_RAX)&0xffffffff;status=status-0x100000000 if status&0x80000000 else status
 return dict(case=c,status=status,result=result,calls=calls,events=events,location=vector(location))

rows=[]
for type,argc,appear,load in itertools.product(kindnames,[3,4,5],[-1,0,1,2],[0,1,2]):rows.append(run(dict(type=type,argc=argc,appear=appear,load=load)))
for safe,point,appear,nonarea in itertools.product([0,1,2],[[1,2,3],[6,7,8]],[-7,0,2],[False,True]):rows.append(run(dict(type=1,safe=safe,safeOutput=point,appear=appear,nonarea=nonarea)))
for note,enabled,clients,nonarea in itertools.product([0,1,2],[0,1,2],[[],[88],[89,None,88],[0x7f000000,88]],[False,True]):rows.append(run(dict(type=32,note=note,enabled=enabled,clients=clients,nonarea=nonarea)))
for trap,nonarea in itertools.product([0,1,2],[False,True]):rows.append(run(dict(type=64,trap=trap,nonarea=nonarea)))
for type,lookupStatus in itertools.product([0,1,2,4,8,16,32,64,128,256,-1],[0,1,2]):rows.append(run(dict(type=type,lookupStatus=lookupStatus)))
for type,reference,tag in itertools.product(kindnames,['','AbC','abcdefghijklmnopq','AbC\0ignore','\u00e9\u20acCase'],['','Tag','new\0tail']):rows.append(run(dict(type=type,reference=reference,tag=tag)))
for type,push,load in itertools.product(kindnames,[0,1],[0,1]):rows.append(run(dict(type=type,push=push,load=load)))
for popFail in range(5):rows.append(run(dict(type=1,popFail=popFail)))
out=m.root/'backups/animations/native-create-object-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
