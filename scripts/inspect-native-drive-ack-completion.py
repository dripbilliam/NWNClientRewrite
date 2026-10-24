"""Original8001f0 path acknowledgement and8114d0 completion in isolation.

Uses the controlled local trace's short acknowledged endpoint. Collision is an
explicit clear-line provider, not the complete installed world. Rule/model
queries, render notifications, allocation and resting-animation selection are
captured. No original live process changes or copied assets. This does not
execute the enclosing input poll/packet reader and cannot establish the native
game's end-to-end hitch duration.
"""
import sys,importlib,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-drive-preview');m=p.m;w=p.w;u=p.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(p.hook_handle)
obj,vt,model,mvt,head,points,source,area,rules,owner,table,appearance=[m.heap+n*0x1000 for n in range(60,72)]
ranges=[(0x1402303d0,0x14023040d),(0x140230920,0x1402309f5),(0x140c7d6d8,0x140c7d783),(0x1407630d0,0x1407630d5),(0x1407630b0,0x1407630c9),(0x140762600,0x140762626)]
for name in ['rea-local-drive-server-ack-v2.json','rea-network-client-path-advance.json','rea-network-client-path-step.json','rea-network-client-path-next-waypoint.json','rea-network-client-motion-correct.json']:
 d=json.loads((m.root/'backups/animations'/name).read_text())['structuredContent'];d=d.get('normalized_result')or d['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def put(a,v):u.mem_write(a,struct.pack('<3f',*v))
def vec(a):return list(struct.unpack('<3f',u.mem_read(a,12)))
def rf(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1407e6a20:queries.append(dict(start=vec(z),end=vec(k),result=1));m.finish(1);return
 if a==0x14080b0d0:
  path=[vec(z+i*12)for i in range(y&65535)];installed.append(path);m.wq(obj+0x298,points);m.wq(obj+0x2a0,points);u.mem_write(obj+0x2d0,struct.pack('<H',len(path)))
  for i,point in enumerate(path):put(points+i*12,point)
  m.finish();return
 if a==0x1407630a0:m.finish(model);return
 if a==0x1401a6c70:m.wf(k,.8);m.finish(1);return
 if a==0x1402e9a80:rf(1);return
 if a==m.stop+0x48:rf(1000);return
 if a==m.stop+0x80:m.finish();return
 if a==m.stop+0x128:put(obj+0x38,vec(y));m.finish();return
 if a in[m.stop+0x208,0x1407ff030,0x140807690,0x140765f50]:m.finish();return
 if a==0x140763220:m.finish(0);return
 if a==0x140764300:u.mem_write(obj+0x5c,struct.pack('<H',y&65535));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 p.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
capture=json.loads((m.root/'backups/animations/creation-performance-client-ack-input-v1.json').read_text())
ack=capture['acknowledgement'];before=capture['before'];last=ack['lastSequence']
rows=[]
for sequence in [0,(last-1)&255,last,(last+1)&255]:
 queries=[];installed=[];p.t.reset(dict(format=1));m.wq(obj,vt);m.wq(obj+0x30,area);m.wq(obj+0x78,model);m.wq(model,mvt)
 m.wq(mvt+0x48,m.stop+0x48);m.wq(mvt+0x80,m.stop+0x80)
 for off,fn in[(0x128,m.stop+0x128),(0x208,m.stop+0x208),(0x240,0x140804bf0)]:m.wq(vt+off,fn)
 m.wq(obj+0x138,head);m.wq(head+8,head);u.mem_write(head+0x19,b'\1');m.wq(0x1412df8f8,rules);m.wq(rules+0x130,owner);m.wq(owner+0x100,table);m.wq(obj+0x300,appearance)
 for off,value in[(0x2f0,2200),(0x2f4,4400),(0x2e0,1),(0x2dc,0)]:m.wf(obj+off,value)
 m.wi(obj+0x2f8,1);m.wi(obj+0x2d8,0);m.wi(obj+0x2cc,0);u.mem_write(obj+0x5c,struct.pack('<H',79));u.mem_write(obj+0x2d3,bytes([last]))
 for off in[0x38,0x2c0]:put(obj+off,before['position'])
 for off in[0x44,0x2a8]:put(obj+off,before['orientation'])
 prior=capture['priorPath']
 m.wq(obj+0x298,points);m.wq(obj+0x2a0,points);u.mem_write(obj+0x2d0,struct.pack('<H',len(prior)))
 for i,point in enumerate(prior):put(points+i*12,point)
 for i,point in enumerate(ack['path']):put(source+i*12,point+[0])
 put(source+0x100,ack['position']);m.wq(m.stack+0x1fe08+0x28,source+0x100);w.call(0x1408001f0,[obj,len(ack['path']),source,sequence])
 frames=[]
 for elapsed in range(8,161,8):
  m.wi(obj+0x58,8);w.call(0x1408114d0,[obj]);frames.append(dict(ms=elapsed,position=vec(obj+0x2c0),render=vec(obj+0x38),animation=struct.unpack('<H',u.mem_read(obj+0x5c,2))[0],script=m.si(obj+0x2f8),factor=m.rf(obj+0x2e0)))
 rows.append(dict(sequence=sequence,lastSequence=last,before=before['position'],priorPath=prior,acknowledged=ack['path'],queries=queries,installed=installed,frames=frames))
out=m.root/'backups/animations/native-drive-ack-completion-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
