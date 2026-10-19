"""Original complete SetMapPinEnabled VM command. Typed VM pop, waypoint
lookup, message/client list, controlled-object lookup and message send are
captured lower boundaries. Comparison scope is the body after successful typed
pops; the ordinary VM separately owns type/stack errors. No original assets,
live process or network changes. Raw INT state and all-client send preserved.
"""
import importlib,itertools,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
b=importlib.import_module('inspect-native-map-pin-messages');m=b.m;u=b.u;w=b.w;t=b.t
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(b.handle);waypointPtr=m.heap+0xf000;clientArray=m.heap+0x88000;clientsBase=clientArray+0x1000;listPtr=clientArray+0x100

def hook(u,a,n,_):
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140286160:m.wi(y,case['id']);m.finish(1);return
 if a==0x140286110:m.wi(y,case['enabled']);m.finish(1);return
 if a==0x14055ba00:trace.append(['waypoint',y&0xffffffff]);m.finish(waypointPtr if case['exists'] else 0);return
 if a==0x14055b810:trace.append(['message']);m.finish(w.message);return
 if a==0x14055b8e0:trace.append(['clients']);m.finish(listPtr);return
 if a==0x1404ba840:
  index=(x-clientsBase)//0x100;assert 0<=index<len(case['clients']);trace.append(['clientObject',index]);m.finish(waypointPtr if case['clients'][index] else 0);return
 if a==0x1404dc3f0:
  index=(y-clientsBase)//0x100;trace.append(['send',index,z&0xffffffff,q&0xffffffff]);m.finish(case['sendResult']);return
 if 0x140543780<=a<0x1405438ab:return
 t.hook(u,a,n,_)
handle=u.hook_add(UC_HOOK_CODE,hook)

if __name__=='__main__':
 rows=[]
 for exists,has,enabled,clients,sendResult in itertools.product([False,True],[0,1,2],[-1,0,1,2,3,-2147483648],[[],[False],[True,False,True]],[0,-1]):
  case=dict(exists=exists,has=has,enabled=enabled,clients=clients,sendResult=sendResult,id=0x80000007);trace=[];t.reset(dict(format=1));m.wi(waypointPtr+0x308,has);m.wi(waypointPtr+0x30c,123)
  m.wq(listPtr,clientArray);m.wi(listPtr+8,len(clients))
  for i in range(len(clients)):m.wq(clientArray+i*8,clientsBase+i*0x100)
  result=w.call(0x140543780,[m.heap+0x20000,0,0,0]);rows.append(dict(case=case,result=result,enabled=m.si(waypointPtr+0x30c),trace=list(trace)))
 out=m.root/'backups/animations/native-map-pin-script-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
