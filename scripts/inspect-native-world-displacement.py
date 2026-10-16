"""Full BudgeCreatures14035c260, SetOpenState140423230 and area
UpdatePlayerAutomaps140372900. Original normalization140230920 executes.
Canonical lookup, sorted-X seek, safe-point/safe-location, action-point owners,
SetPosition/reordering, map update, animation and sqrt are captured lower
boundaries. Live-list reorder fixtures are synthetic, not a full path oracle.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
areaPtr,originPtr,minPtr,maxPtr,appPtr,idsPtr,targetPtr,vtPtr,clientListPtr,clientIdsPtr=[m.heap+n*0x1000 for n in range(1,11)]
objects={100+i:m.heap+0x10000+i*0x1000 for i in range(8)}
ranges=[(0x14035c260,0x14035c58c),(0x140423230,0x140423396),(0x140372900,0x1403729ac),(0x140230920,0x1402309f5)]
def vec(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12)))
def wvec(ptr,value):u.mem_write(ptr,struct.pack('<3f',*value))
def ident(ptr):return m.si(ptr+8)&0xffffffff
def ids():return[m.si(idsPtr+i*4)&0xffffffff for i in range(m.si(areaPtr+0x230))]
def writeids(values):
 m.wi(areaPtr+0x230,len(values))
 for i,value in enumerate(values):m.wi(idsPtr+i*4,value)
def nextvalue(values,index):return values[min(index,len(values)-1)]
def hook(u,a,n,_):
 global safeIndex,placeIndex
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14035e820:
  query=m.xmm(UC_X86_REG_XMM2);calls.append(['firstX',query]);index=c.get('start',next((i for i,id in enumerate(ids()) if m.rf(objects[id]+0xa4)>=query),len(ids())));m.wi(y,index);m.finish(c.get('seekResult',1));return
 if a==0x14055b3d0:
  id=y&0xffffffff;calls.append(['creature',id]);obj=objects.get(id);m.finish(obj if obj and id not in c.get('noncreatures',[101]) else 0);return
 if a==0x140372470:
  id=next(id for id,obj in objects.items() if obj+0x5300==z);result=1 if c.get('reorder') and id in moved else nextvalue(c.get('safe',[0]),safeIndex);safeIndex+=1;calls.append(['safePoint',id,vec(y),w&0xffffffff]);m.finish(result);return
 if a in [0x14055b430,0x14055b890]:
  calls.append(['door' if a==0x14055b430 else 'placeable',y&0xffffffff]);m.finish(targetPtr if c.get('target')==('door' if a==0x14055b430 else 'placeable') else 0);return
 if a in [0x140420360,0x1404b3f20]:
  calls.append(['doorPoint' if a==0x140420360 else 'placeablePoint',vec(z),w&0xffffffff if a==0x140420360 else None]);wvec(y,c.get('actionPoint',[11,11,0]));m.finish(y);return
 if a==0x14036aa90:
  pathOwner=next(id for id,obj in objects.items() if obj+0x5300==w);output=m.q(rsp+0x30);calls.append(['safeLocation',pathOwner,vec(y),m.xmm(UC_X86_REG_XMM2),m.si(rsp+0x28),vec(output)]);wvec(output,nextvalue(c.get('outputs',[[8,9,0]]),placeIndex));result=nextvalue(c.get('placed',[1]),placeIndex);placeIndex+=1;m.finish(result);return
 if a==0x14049bb40:
  id=ident(x);point=vec(y);calls.append(['position',id,point,z&0xffffffff]);wvec(x+0xa4,point);moved.add(id)
  if c.get('reorder'):
   values=ids();index=values.index(id)
   while index+1<len(values) and m.rf(objects[values[index+1]]+0xa4)<point[0]:values[index],values[index+1]=values[index+1],values[index];index+=1
   while index>0 and m.rf(objects[values[index-1]]+0xa4)>point[0]:values[index],values[index-1]=values[index-1],values[index];index-=1
   writeids(values)
  m.finish();return
 if a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish();return
 if a==0x140494e80:calls.append(['area']);m.finish(areaPtr if c.get('area',True) else 0);return
 if a==m.stop+0x10:calls.append(['animation',y&0xffffffff]);m.wi(targetPtr+0xd8,y);m.finish();return
 if a==0x140372900 and mode=='door':calls.append(['maps']);m.finish();return
 if a==0x14035c260 and mode=='door':calls.append(['budge',vec(y),vec(z),vec(w),m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30)]);m.finish();return
 if a==0x14055b8e0:calls.append(['clients']);m.finish(clientListPtr);return
 if a==0x1404ba840:
  i=(x-m.heap-0x30000)//0x100;calls.append(['clientObject',i]);m.finish(objects[100+i] if c['clients'][i] is not None else 0);return
 if a==m.stop+0x20:calls.append(['asCreature',ident(x)]);m.finish(x if u.mem_read(x+0xc,1)[0]==5 else 0);return
 if a==0x1403a7390:calls.append(['update',ident(x),y&0xffffffff]);m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured displacement dependency {a:x}: {mode}, {c}')
u.hook_add(UC_HOOK_CODE,hook)
basePositions=[[0,10,0],[3,10,0],[4,3,0],[10,10,0],[16,16,10],[17,10,0],[20,10,0],[30,30,0]]
def run(case,operation):
 global c,calls,mode,safeIndex,placeIndex,moved
 c=case;mode=operation;calls=[];safeIndex=placeIndex=0;moved=set();u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(areaPtr+0x228,idsPtr);m.wi(areaPtr+0x140,88);m.wi(areaPtr+8,c.get('flags',1));writeids(c.get('ids',[100,101,102,103,104,105,106]))
 for id,ptr in objects.items():m.wi(ptr+8,id);wvec(ptr+0xa4,c.get('positions',basePositions)[id-100]);m.wq(ptr+0x530,ptr+0x5300);m.wq(ptr,vtPtr);u.mem_write(ptr+0xc,bytes([9 if id in c.get('noncreatures',[101]) else 5]))
 origin=c.get('origin',[10,10,0]);minimum=c.get('min',[8,8,-1]);maximum=c.get('max',[12,12,1]);wvec(originPtr,origin);wvec(minPtr,minimum);wvec(maxPtr,maximum);wvec(targetPtr+0xa4,origin);wvec(targetPtr+0x4c8,minimum);wvec(targetPtr+0x4d4,maximum);m.wi(targetPtr+8,99);m.wi(targetPtr+0x498,c.get('visible',1));u.mem_write(targetPtr+0x42c,bytes([c.get('old',0)&255]));m.wq(targetPtr,vtPtr);m.wq(vtPtr+0x100,m.stop+0x10);m.wq(vtPtr+0x60,m.stop+0x20)
 clients=c.get('clients',[]);m.wq(clientListPtr,clientIdsPtr);m.wi(clientListPtr+8,len(clients))
 for i,value in enumerate(clients):m.wq(clientIdsPtr+i*8,m.heap+0x30000+i*0x100);m.wi(objects[100+i]+0xa0,value or 0)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if mode=='budge':args=[areaPtr,originPtr,minPtr,maxPtr];m.wi(rsp+0x28,c.get('targetId',99));m.wi(rsp+0x30,c.get('flag',0));entry=0x14035c260
 elif mode=='door':args=[targetPtr,c['state'],0,0];entry=0x140423230
 else:args=[areaPtr,0,0,0];entry=0x140372900
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
 try:u.emu_start(entry,m.stop,count=100000)
 except Exception:print(json.dumps(dict(mode=mode,case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(mode=mode,case=c,calls=calls,ids=ids(),positions={str(id):vec(ptr+0xa4) for id,ptr in objects.items()},state=u.mem_read(targetPtr+0x42c,1)[0],animation=m.si(targetPtr+0xd8))
rows=[]
for flag,target,safe,placed in itertools.product([0,1,2],['door','placeable','missing'],[[0],[1],[2],[0,1,0]],[[0],[1],[2],[0,1]]):rows.append(run(dict(flag=flag,target=target,safe=safe,placed=placed),'budge'))
for positions in [basePositions,[[3,3,0],[4,4,0],[5,5,0],[10,10,0],[16,16,0],[17,17,0],[18,18,0],[30,30,0]],[[10,10,0]]*8]:
 for flag,reorder,outputs in itertools.product([0,1],[False,True],[[[8,9,0]],[[30,30,0]],[[8,9,0],[15,15,0]]]):rows.append(run(dict(flag=flag,reorder=reorder,outputs=outputs,positions=positions,target='placeable'),'budge'))
for start,idsv in itertools.product([0,1,3],[[],[103],[100,103,104,105]]):rows.append(run(dict(start=start,seekResult=0,ids=idsv),'budge'))
for visible,old,state,hasArea in itertools.product([0,1,2],[0,1,2,3,7],[0,1,2,3,7,256,257,-1],[False,True]):rows.append(run(dict(visible=visible,old=old,state=state,area=hasArea),'door'))
for flags,clients,noncreatures in itertools.product([0,1,2,3,4,255],[[],[88],[89,None,88],[88,88,88]],[[],[101],[100,102]]):rows.append(run(dict(flags=flags,clients=clients,noncreatures=noncreatures),'maps'))
out=m.root/'backups/animations/native-world-displacement-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
