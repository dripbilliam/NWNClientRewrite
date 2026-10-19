"""Complete original pin presentation140893860..140893ab9 and bounded
SET map-image branch1402c7580..1402c7615 with actual ReadINI1402cc370,
CResRef initialization/setter/copy. Pin position/model/view virtuals and GUI
attachment are captured lower owners. No full native map-window/render/INI file
parser, live process or original asset-copy claim. Captured GUI attachment's
flag mutation is explicit fixture behavior, not a port of its event machinery.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');m=t.m;u=t.u;w=t.w
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
mapPtr,pinPtr,modelPtr,viewPtr,tilesPtr,positionPtr,originPtr,tablePtr=[m.heap+i for i in [0x40000,0x41000,0x42000,0x43000,0x44000,0x45000,0x45100,0x46000]]
positionCall,originCall,transformCall=[m.stop+i for i in [0x100,0x110,0x120]]
ranges=[(0x140893860,0x140893aba),(0x140894ba6,0x140894c74),(0x1402c7580,0x1402c7615),(0x1402cc370,0x1402cc4f8),(0x1402c60d0,0x1402c60d9),(0x14018de80,0x14018de91)]
def vector(ptr):return[m.rf(ptr+i*4)for i in range(3)]
def hook(u,a,n,_):
 global positionReads
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==positionCall:
  point=case['positions'][min(positionReads,len(case['positions'])-1)];positionReads+=1;trace.append(['position',point]);
  for i,value in enumerate(point):m.wf(positionPtr+i*4,value)
  m.finish(positionPtr);return
 if a==originCall:trace.append(['viewOrigin']);m.finish(originPtr);return
 if a==transformCall:trace.append(['transform',vector(z),[m.rf(q+i*4)for i in range(4)]]);m.finish();return
 if a==0x1401fafa0:
  trace.append(['attach']);
  if case['attachSetsFlag']:m.wi(pinPtr+0xe8,1)
  m.finish(case['attachResult']);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,_)
handle=u.hook_add(UC_HOOK_CODE,hook)

def pin(c):
 global case,trace,positionReads
 case=c;trace=[];positionReads=0;t.reset(dict(format=1));m.wq(pinPtr,tablePtr);m.wq(tablePtr+0x100,positionCall);m.wq(pinPtr+0x10,modelPtr);m.wq(modelPtr,tablePtr+0x200);m.wq(tablePtr+0x200+0x130,transformCall);m.wq(viewPtr,tablePtr+0x400);m.wq(tablePtr+0x400+0xc0,originCall)
 m.wq(mapPtr+0x110,viewPtr);m.wi(mapPtr+0x4e0,c['width']);m.wi(mapPtr+0x4e4,c['height']);m.wi(mapPtr+0x514,c['zoom']);m.wq(mapPtr+0x508,tilesPtr);m.wi(pinPtr+0xe8,c['attached'])
 for i in range(max(1,c['width']*c['height'])):m.wi(tilesPtr+i*4,c['tileState'])
 for i,value in enumerate(c['origin']):m.wf(originPtr+i*4,value)
 result=w.call(0x140893860,[mapPtr,pinPtr,c['force'],0]);return dict(case=c,result=result,attached=m.si(pinPtr+0xe8),trace=list(trace))

def image(c):
 global trace
 trace=[];t.reset(dict(format=1));tileSetPtr=mapPtr;iniPtr=pinPtr;sectionPtr=modelPtr;keyPtr=viewPtr;tileDataPtr=tilesPtr;sectionName=positionPtr;keyName=positionPtr+0x100;valuePtr=positionPtr+0x200
 m.wq(tileSetPtr+8,iniPtr);m.wq(tileSetPtr+0x60,tileDataPtr);m.wq(iniPtr+0x68,sectionPtr);m.wi(iniPtr+0x70,0 if c.get('missingSection')else 1)
 u.mem_write(sectionName,b'TILE0\0');u.mem_write(keyName,b'ImageMap2D\0');m.wq(sectionPtr,sectionName);m.wi(sectionPtr+8,5);m.wq(sectionPtr+0x10,keyPtr);m.wi(sectionPtr+0x18,0 if c.get('missingKey')else 1);m.wq(keyPtr,keyName);m.wi(keyPtr+8,10)
 if c['hex']is None:m.wq(keyPtr+0x10,0)
 else:u.mem_write(valuePtr,bytes.fromhex(c['hex'])+b'\0');m.wq(keyPtr+0x10,valuePtr)
 frame=m.stack+0x1fc00;u.mem_write(frame+0x98,b'TILE0\0');u.mem_write(frame+0xc0,b'previous_value\0');u.reg_write(UC_X86_REG_RSP,m.stack+0x1fa00);u.reg_write(UC_X86_REG_RBP,frame);u.reg_write(UC_X86_REG_RDI,tileSetPtr);u.reg_write(UC_X86_REG_R12,0)
 u.emu_start(0x1402c7580,0x1402c7615,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x1402c7615
 return dict(case=c,resrefHex=bytes(u.mem_read(tileDataPtr+0x21,17)).hex())

def player(c):
 t.reset(dict(format=1));m.wi(mapPtr+0x4e0,c['width']);m.wi(mapPtr+0x4e4,c['height']);m.wi(mapPtr+0x514,c['zoom'])
 for i,value in enumerate(c['point']):m.wf(pinPtr+0x38+i*4,value)
 frame=m.stack+0x1fc00;u.reg_write(UC_X86_REG_RSP,m.stack+0x1fa00);u.reg_write(UC_X86_REG_RBP,frame);u.reg_write(UC_X86_REG_RDI,mapPtr);u.reg_write(UC_X86_REG_RAX,pinPtr)
 u.emu_start(0x140894ba6,0x140894c74,count=10000);assert u.reg_read(UC_X86_REG_RIP)==0x140894c74
 return dict(case=c,position=vector(frame-0x49))

if __name__=='__main__':
 pins=[];images=[];players=[]
 for point,force,attached,state,zoom,origin in itertools.product([[-20,4,0],[-.5,4,0],[0,0,0],[5.125,15.75,3],[19.999,19.999,-2],[20,20,0]],[0,1,-1],[0,1],[0,1,2],[0,16,32],[[0,0,0],[1.25,-2.5,3]]):
  pins.append(pin(dict(positions=[point],force=force,attached=attached,tileState=state,zoom=zoom,origin=origin,width=2,height=2,attachSetsFlag=True,attachResult=0)))
 for width,height,attachSetsFlag in itertools.product([-1,0,8],[0,2],[False,True]):pins.append(pin(dict(positions=[[4,5,6],[14,15,16]],force=0,attached=0,tileState=1,zoom=-32,origin=[1,2,3],width=width,height=height,attachSetsFlag=attachSetsFlag,attachResult=1)))
 for raw,missingSection,missingKey in itertools.product([None,'','0041','4d695f437573746f6d','4142004344','41'*16,'42'*17,'80ff41'],[False,True],[False,True]):images.append(image(dict(hex=raw,missingSection=missingSection,missingKey=missingKey)))
 for point,zoom,width in itertools.product([[0,0,-100],[5.125,15.75,3],[-.5,4,-2],[19.999,19.999,0]],[0,16,32,-32],[0,2,8]):players.append(player(dict(point=point,zoom=zoom,width=width,height=2)))
 out=m.root/'backups/animations/native-map-presentation-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,pins=pins,images=images,players=players),indent=2));print(json.dumps(dict(output=str(out),pins=len(pins),images=len(images),players=len(players))))
