"""Original door click wrapper6efca0, native senders and server walk reader.

Native gate/get-open-state, literal sequence0, canonical target and coordinates
execute intact. Run-mode selection and message-owner access are captured UI
boundaries; no native live process is changed. The existing walk oracle captures
controlled-object lookup, AI/mode and move-action insertion boundaries.
"""
import sys,importlib,itertools,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
walk=importlib.import_module('inspect-native-network-walk');t=walk.t;w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(walk.hook_handle);ranges=[]
for name in ['network-client-walk-wrapper-one','network-client-door-get-open','network-client-door-request-caller','network-client-door-request']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result']['procedure']
 ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])
controller,door,area=[m.heap+n*0x1000 for n in [22,23,24]]
def hook(u,a,n,data):
 if a==0x1406ec9d0:m.finish(current['run']);return
 if a==0x1406abf90:m.finish(w.message);return
 if any(lo<=a<hi for lo,hi in ranges):return
 walk.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for state,transition,run,enabled,modal,blocked in itertools.product(range(4),[0,1],[0,1],[0,1],[0,1],[0,1]):
 current=dict(state=state,hasTransition=transition,run=run,enabled=enabled,modal=modal,blocked=blocked);walk.sent=[];walk.calls=[];t.reset(dict(format=1));m.wi(controller+0x154,blocked);u.mem_write(controller+0x140,bytes([modal]));m.wq(controller+0x208,w.message)
 m.wq(door+0x30,area);m.wi(area+0x118,0x80000001);m.wi(door+8,0x80000002);m.wi(door+0x11c,enabled);m.wi(door+0x1c0,transition);u.mem_write(door+0x19c,bytes([state]));m.wi(door+0x5c,[22,50,51,72][state])
 for offset,value in zip([0x38,0x3c,0x40],[28.125,15.25,-.125]):m.wf(door+offset,value)
 result=w.call(0x1406efca0,[controller,door,0,0]);packets=list(walk.sent);decoded=None
 if not enabled or modal or blocked:assert result==0 and not packets
 elif state and transition:
  assert result==1 and len(packets)==1 and packets[0][:3]==bytes([112,6,1]);decoded=walk.receive(packets[0]);move=next(v for v in decoded['calls']if v[0]=='move');assert move[2]==[28.125,15.25,-.125]and move[3]==1 and move[4]==2 and move[5]==run and move[8]==0 and move[9]==0 and move[11]==0
 elif state<3:assert result==1 and len(packets)==1 and packets[0][:3]==bytes([112,6,3])
 else:assert result==1 and not packets
 rows.append(dict(case=current,result=result,packets=[p.hex()for p in packets],decoded=decoded))
output=m.root/'backups/animations/native-network-door-click-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
