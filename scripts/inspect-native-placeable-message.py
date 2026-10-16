"""Original selected constructor/appearance/light-state blocks and complete
GetLightIsOn with actual BYTEasBOOL conversion. Typed GFF and active2DA query
are captured lower boundaries, including differing first/second query status.
No full LoadPlaceable/rendering/network or process modification claim.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-area-properties');g=p.g;a=p.a;w=p.w;m=p.m;u=p.u;u.hook_del(p.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
object_=a.objectBase
ranges=[(0x1404afd17,0x1404afd22),(0x1404b4f7e,0x1404b4fa1),(0x1404b52ef,0x1404b53e1)]
def hook(u,at,n,_):
 if at==0x1401a7010:
  row=u.reg_read(UC_X86_REG_RDX)&0xffffffff;key=a.rawString(u.reg_read(UC_X86_REG_R8));status=case['statuses'][min(len(queries),len(case['statuses'])-1)];queries.append([row,key,status]);m.wi(u.reg_read(UC_X86_REG_R9),0x112233);m.finish(status);return
 if any(lo<=at<hi for lo,hi in ranges):return
 p.hook(u,at,n,_)
u.hook_add(UC_HOOK_CODE,hook)

def frame():
 u.reg_write(UC_X86_REG_RSP,m.stack+0x1fa00);u.reg_write(UC_X86_REG_RBP,m.stack+0x1fb00);u.reg_write(UC_X86_REG_RBX,object_);u.reg_write(UC_X86_REG_RSI,a.array);u.reg_write(UC_X86_REG_R14,a.client);u.reg_write(UC_X86_REG_R13,0);m.wi(m.stack+0x1fa50,0)
def run(c):
 global case,queries
 case=c;g.reset({});frame();u.emu_start(0x1404afd17,0x1404afd22,count=100);m.wi(object_+0x594,c['old']);m.wq(0x1412df8f8,a.rules);m.wq(a.rules+0x130,a.rules+0x800);m.wq(a.rules+0x800+0x140,a.table);observations=[]
 for step in c['steps']:
  queries=[];p.contexts={1:step};p.reads=[];p.nextToken=[10];m.wi(a.client,1);frame();u.emu_start(0x1404b4f7e,0x1404b4fa1,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x1404b4fa1
  frame();u.emu_start(0x1404b52ef,0x1404b53e1,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x1404b53e1
  observations.append(dict(appearance=int.from_bytes(u.mem_read(object_+0x32c,2),'little'),light=m.si(object_+0x594),dirty=m.si(object_+0x598),queries=list(queries)))
 return dict(case=c,observations=observations)
if __name__=='__main__':
 rows=[]
 for old,state,appearance,statuses in itertools.product([0,1,2,-1],[None,0,1,2,256,-1],[0,65536,-1],[[0],[1],[0,1],[1,0]]):
  data=dict(Appearance=appearance)
  if state is not None:data['LightState']=state
  rows.append(run(dict(old=old,statuses=statuses,steps=[data,{}])))
 out=m.root/'backups/animations/native-placeable-message-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),executions=sum(len(row['observations'])for row in rows))))
