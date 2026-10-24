"""Original6ea9e0 local drive preview, original quaternion/vector math.

Capture only controlled-object lookup, local path installation and animation
selection. Separate free/partial-line7fdeb0 runs capture collision queries.
No live process changes, copied assets or claim about complete collision world.
"""
import sys,importlib,json,struct,itertools,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
obj,ui,point,owner,area,appearance=[m.heap+n*0x1000 for n in range(40,46)]
ranges=[(0x140047300,0x14004730c),(0x14022a000,0x140232000),(0x140c7a2b0,0x140c7a9a8),(0x140c7ac70,0x140c7b16f),(0x140c7d6d8,0x140c7d783)]
for name in ['ui-local','prediction-install']:
 d=json.loads((m.root/f'backups/animations/rea-arelith-drive-{name}-v1.json').read_text())['structuredContent']['normalized_result']
 ranges.extend((int(x['start'],16),int(x['end'],16)+1)for x in d['procedure']['body']['ranges'])
def vec(p):return list(struct.unpack('<3f',u.mem_read(p,12)))
def put(p,v):u.mem_write(p,struct.pack('<3f',*v))
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406ac1a0:m.finish(obj);return
 if a==0x1406abea0:m.finish(owner);return
 if a==0x1407630d0:m.finish(0);return
 if a==0x140764300:animations.append(y&65535);m.finish();return
 if a==0x1407fdeb0 and mode=='preview':paths.append(dict(target=vec(y),run=z&255,mode=k&255));m.finish(1);return
 if a==0x1407e6a20:
  start,end=vec(z),vec(k);clear=fixture_line(c,start,end);queries.append(dict(start=start,end=end,clear=clear));m.finish(int(clear));return
 if a==0x1406f1bc0:refresh.append(struct.unpack('<f',u.reg_read(UC_X86_REG_XMM1).to_bytes(16,'little')[:4])[0]);m.finish();return
 if a==0x14080b0d0:paths.append(dict(count=y&65535,points=[vec(z+i*12)for i in range(y&65535)]));m.finish();return
 if a==0x140c10368:
  p=m.heap+w.cursor;w.cursor+=x+32;u.mem_write(p,bytes(x));m.finish(p);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
hook_handle=u.hook_add(UC_HOOK_CODE,hook)

def fixture_line(case,start,end):
 # Deliberately captured collision predicate: the original path installer,
 # candidate vectors, search order, factor and installation execute unchanged.
 for plane in case.get('planes',[]):
  if sum((end[i]-plane['origin'][i])*plane['normal'][i] for i in range(3))>plane.get('offset',0):return False
 return end[0]<=case.get('wall',1e9)
def run(case,kind='preview'):
 global c,mode,paths,animations,queries,refresh
 c=case;mode=kind;paths=[];animations=[];queries=[];refresh=[];t.reset(dict(format=1));u.reg_write(UC_X86_REG_MXCSR,0x1f80);m.wq(w.app,owner);m.wq(owner+8,ui)
 put(obj+0x44,c.get('orientation',[1.,0.,0.]));put(obj+0x2c0,c['position']);put(obj+0x38,c.get('render',c['position']));m.wi(obj+0x2cc,c.get('correction',0));m.wf(obj+0x2f0,c.get('walkRate',2200));m.wf(obj+0x2f4,c.get('runRate',4400));u.mem_write(obj+0x37c,b'\2');u.mem_write(ui+0x140,b'\2')
 m.wq(owner+0xf8,area);m.wi(obj+0x41c,1);m.wq(obj+0x300,appearance)
 if kind in ['preview','full-preview']:
  try:result=w.call(0x1406ea9e0,[ui,c['flags']])
  except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 else:
  put(point,c['target'])
  try:result=w.call(0x1407fdeb0,[obj,point,1,2])
  except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 return dict(case=c,result=result,paths=paths,animations=animations,targetOrientation=vec(obj+0x2a8),queries=queries,refresh=refresh,script=m.si(obj+0x2f8),factor=m.rf(obj+0x2e0),newPath=m.si(obj+0x2d8))
if __name__=='__main__':
 rows=[]
 for flags,orientation,rate in itertools.product([1,2,3,4,8,5,9,7,11,17,33,19,35,20,40],[[1.,0.,0.],[0.,1.,0.],[.70710677,.70710677,0.]],[1600.,4400.]):
  rows.append(run(dict(flags=flags,orientation=orientation,position=[10.,20.,1.],walkRate=rate,runRate=rate*2)))
 partials=[]
 for wall in [100.,12.,11.,10.5]:partials.append(run(dict(position=[10.,20.,1.],target=[14.,20.,1.],wall=wall),'install'))
 out=m.root/'backups/animations/native-drive-preview-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows,partialLines=partials),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),partialLines=len(partials),output=str(out))))
