"""Original client7e6a20 traversal and call/float ordering. Tile lookup,
synthetic clipping, polygon/creature queries and endpoint walkability are captured
lower boundaries. The unchanged controller instructions execute in isolation.
No original assets or transport payloads are saved; no live process changes.
"""
import sys,importlib,json,struct,itertools,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-drive-preview');m=p.m;u=p.u;w=p.w
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(p.hook_handle)
tiles=m.heap+0x60000
f=lambda v:struct.unpack('<f',struct.pack('<f',v))[0]
def xmm(n):return struct.unpack('<f',u.reg_read([UC_X86_REG_XMM0,UC_X86_REG_XMM1,UC_X86_REG_XMM2,UC_X86_REG_XMM3][n]).to_bytes(16,'little')[:4])[0]
def clip(x,y):
 lo=[f(x*10),f(y*10)];hi=[f(v+10)for v in lo];a=c['from'];b=c['to']
 def endpoint(entry):
  q=a if entry else b
  if all(lo[i]<=q[i]<=hi[i]for i in range(2)):return q[:2]
  if a[0]!=b[0]:
   ex=hi[0]if((b[0]<a[0])if entry else(a[0]<b[0]))else lo[0];ey=f(f(f(f(b[1]-a[1])/f(b[0]-a[0]))*f(ex-a[0]))+a[1])
   if lo[1]<=ey<=hi[1]:return[ex,ey]
  if a[1]!=b[1]:
   ey=hi[1]if((b[1]<a[1])if entry else(a[1]<b[1]))else lo[1];ex=f(f(f(f(b[0]-a[0])/f(b[1]-a[1]))*f(ey-a[1]))+a[0])
   if lo[0]<=ex<=hi[0]:return[ex,ey]
  return None
 start,end=endpoint(True),endpoint(False)
 return dict(status=1 if start is not None and end is not None else 0,entry=start,exit=end,minHeight=f(x*.5),maxHeight=f(y*.25+1))
def hook(u,a,n,data):
 rsp=u.reg_read(UC_X86_REG_RSP);x=u.reg_read(UC_X86_REG_RCX)
 def stage(name,args):
  result=c.get('failureResult',0)if c.get('failure')==name else 1;trace.append(dict(kind=name,args=args,result=result));m.finish(result)
 if a==0x1407db200:
  center=p.vec(u.reg_read(UC_X86_REG_RDX));tx=int(math.floor(center[0]/10));ty=int(math.floor(center[1]/10));valid=0<=tx<4 and 0<=ty<4 and c.get('failure')!='tile';trace.append(dict(kind='tile',args=[tx,ty],result=valid));m.finish(tiles+(ty*4+tx)*0x100 if valid else 0);return
 if a==0x14084e350:
  index=(x-tiles)//0x100;tx=index%4;ty=index//4;value=clip(tx,ty);clippings[f'{tx}:{ty}']=value
  trace.append(dict(kind='clip',args=[tx,ty],result=c.get('failureResult',0)if c.get('failure')=='clip'else value['status']))
  values=(value['entry']or[0,0])+(value['exit']or[0,0])+[value['minHeight'],value['maxHeight']]
  for i,v in enumerate(values):m.wf(m.q(rsp+0x30+i*8),v)
  m.finish(trace[-1]['result']);return
 if a in[0x14084f1f0,0x140297bd0]:
  args=[xmm(1),xmm(2),xmm(3)]+[m.rf(rsp+off)for off in[0x28,0x30,0x38,0x40]]+[m.si(rsp+0x48)]
  stage('tilePoly'if a==0x14084f1f0 else'worldPoly',args);return
 if a==0x1406ab940:m.finish(p.owner);return
 if a==0x140767740:stage('creatures',[xmm(1),xmm(2),xmm(3),m.rf(rsp+0x28),m.si(rsp+0x30),m.rf(rsp+0x38)]);return
 if a==0x1407e7210 and not c.get('edgeOnly'):stage('extension',[p.vec(u.reg_read(UC_X86_REG_R8)),p.vec(u.reg_read(UC_X86_REG_R9)),m.rf(rsp+0x28)]);return
 if 0x1407e6a20<=a<0x1407e6f76 or c.get('edgeOnly')and 0x1407e7210<=a<0x1407e750e:return
 p.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,clippings
 c=case;trace=[];clippings={};p.t.reset(dict(format=1));p.put(p.point,c['from']);p.put(p.point+0x40,c['to']);m.wi(p.obj+8,123)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[p.area,p.obj,p.point,p.point+0x40]):u.reg_write(reg,v)
 m.wf(rsp+0x28,c['radius']);m.wf(rsp+0x30,c['height']);m.wi(rsp+0x38,c['creatures']);u.emu_start(0x1407e7210 if c.get('edgeOnly')else 0x1407e6a20,m.stop,count=1000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_EAX),trace=trace,clippings=clippings)
lines=[([5,5,0],[25,5,0]),([25,25,0],[5,5,0]),([5,25,0],[25,5,0]),([5,5,0],[5,25,0]),([25,5,0],[5,25,0]),([5,5,0],[5,5,0]),([5,5,0],[19.75,4.25,0]),([-1,5,0],[5,5,0])]
cases=[dict(zip(['from','to'],line),radius=radius,height=height,creatures=creatures,failure=failure,failureResult=code)for line,radius,height,creatures,(failure,code)in itertools.product(lines,[0,.5],[1,2.5],[0,1],[(None,0),('tile',0),('clip',0),('tilePoly',0),('worldPoly',0),('creatures',0),('extension',0),('worldPoly',2)])]
rows=[run(c)for c in cases];edges=[run(dict(zip(['from','to'],line),edgeOnly=True,radius=.5,height=1,creatures=0,failure=failure,failureResult=code))for line,(failure,code)in itertools.product(lines,[(None,0),('tile',0),('clip',0),('clip',2)])]
out=m.root/'backups/animations/native-client-drive-line-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows,edges=edges),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),edges=len(edges),output=str(out))))
