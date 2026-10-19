"""Execute full native yaw7cfe60, pitch7cfdb0 and zoom7d4340 setters.
Synthetic Follow accessors are the only lower boundary. Record both actual
Follow accumulators and independent module prediction inputs, including the
original yaw/pitch impulse field alias. No live process or resource mutation.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
c=importlib.import_module('inspect-native-camera-commands');w=c.w;m=c.m;u=c.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(c.hook_handle)
ranges=[(0x1407cfe60,0x1407cff0c),(0x1407cfdb0,0x1407cfe5a),(0x1407d4340,0x1407d43c2)]
def hook(u,a,n,data):
 if any(lo<=a<hi for lo,hi in ranges):return
 c.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(flags,ops):
 c.setup(dict(flags=flags));m.wi(c.module+0x134,0);m.wi(c.module+0x280,0);m.wi(c.module+0x284,0)
 for off,value in [(0x58,1.25),(0x60,-2.5),(0x4c,3.75),(0x88,4.5),(0x8c,-5.5)]:m.wf(c.behavior+off,value)
 c.put(c.module+0x148,[100,200,300,400,500]);steps=[]
 for axis,value,impulse in ops:
  w.call(dict(yaw=0x1407cfe60,pitch=0x1407cfdb0,zoom=0x1407d4340)[axis],[c.module,0,impulse],[value]);steps.append(dict(axis=axis,value=value,impulse=impulse,follow={key:m.rf(c.behavior+off)for key,off in [('turn',0x58),('tilt',0x60),('speed',0x4c),('turnDelta',0x88),('tiltDelta',0x8c)]},prediction=c.vec(c.module+0x148,5),manual=m.si(c.module+0x134),yawEvent=m.si(c.module+0x280),zoomEvent=m.si(c.module+0x284)))
 return dict(flags=flags,steps=steps)
if __name__=='__main__':
 flags=[0,1,2,4,8,16,32,48,64,112,127,256,-1];rows=[run(flag,[(axis,value,impulse)])for flag,axis,value,impulse in itertools.product(flags,['yaw','pitch','zoom'],[-75,-.25,0,.25,75],[0,1])]
 for flag in flags:rows.append(run(flag,[('yaw',3,1),('pitch',-2,1),('yaw',0,0),('pitch',0,0),('zoom',7.5,0)]))
 out=m.root/'backups/animations/native-camera-rate-flags-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),steps=sum(len(r['steps'])for r in rows),output=str(out))))
