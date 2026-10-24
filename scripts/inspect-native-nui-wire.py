"""Unchanged native NUI event/bind queue writers and CNWMessage framing.
Synthetic queue/JSON ownership; to_ubjson is a captured boundary supplying
bytes independently produced by the unchanged native serializer oracle.
Cleanup, allocation, application/build query and final transport are captured.
No live process changes or original asset copies.
"""
import importlib,json,struct
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[]
for name in ['rea-nui-client-event-writer-v1.json','rea-nui-client-bind-writer-v1.json','rea-nui-write-json-v1.json','rea-nui-write-type-v1.json']:
 d=json.loads((m.root/'backups/animations'/name).read_text())['structuredContent']['raw_result']['value']
 for proc in [d['procedure'],*d['callees']]:
  if proc['address']in ['0x1407c2da0','0x1407c2f80','0x1407c9d80','0x1407c9dc0','0x1402db680','0x1402dbc20']:
   ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in proc['body']['ranges'])
oracle=json.loads((m.root/'backups/animations/native-nui-ubjson-v1.json').read_text())['cases'];queue=m.heap+0x3000;mapping=queue+0x100;records=queue+0x1000;jsonBytes=queue+0x4000;manager=queue+0x5000;vtable=manager+0x100;getNet=manager+0x200
def hook(u,a,n,_):
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1407c25c0:
  sp=u.reg_read(UC_X86_REG_RSP);size=m.si(sp+0x28)&0xffffffff;ptr=u.reg_read(UC_X86_REG_R9);packets.append(bytes([112,y&255,z&255])+bytes(u.mem_read(ptr,size))[3:]);m.finish(1);return
 if a==getNet:m.finish(manager);return
 if a==0x140237b50:m.finish(int(indexed));return
 if a==0x140288920:m.finish();return
 if a==0x140c10360:m.finish();return
 if a==0x1402e8880:
  # RCX return vector, RDX synthetic JSON; original framing consumes the vector.
  key=m.q(y+8);wire=bytes.fromhex(oracle[key]['wire']);dest=jsonBytes+key*0x400;u.mem_write(dest,wire);m.wq(x,dest);m.wq(x+8,dest+len(wire));m.wq(x+16,dest+len(wire));m.finish(x);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,_)
u.hook_add(UC_HOOK_CODE,hook)
def string(ptr,text):
 raw=text.encode('cp1252');assert len(raw)<16;u.mem_write(ptr,raw+b'\0');m.wq(ptr+16,len(raw));m.wq(ptr+24,15)
def run(kind,entries,hasIndex=True):
 global packets,indexed
 indexed=hasIndex;packets=[];t.reset({'format':1});m.wq(w.app,manager);m.wq(manager,vtable);m.wq(vtable+0x38,getNet);m.wq(queue,queue+0x300);m.wq(queue+0x300,queue);m.wq(queue+8,mapping);m.wq(queue+0x10,8);m.wq(queue+0x18,0);m.wq(queue+0x20,len(entries))
 for i,e in enumerate(entries):
  ptr=records+i*0x100;m.wq(mapping+i*8,ptr);m.wi(ptr+4,e['token']);string(ptr+8,e['type']if kind=='events'else e['bind'])
  if kind=='events':string(ptr+0x28,e['element']);m.wi(ptr+0x48,e['index']);j=ptr+0x50
  else:j=ptr+0x28;m.wi(ptr+0x38,e['index'])
  m.wq(j+8,e['oracle'])
 try:w.call(0x1407c2f80 if kind=='events'else 0x1407c2da0,[w.message,queue])
 except Exception as e:raise RuntimeError(f'{kind} count={len(entries)} indexed={indexed} RIP={u.reg_read(UC_X86_REG_RIP):x}')from e
 assert m.q(queue+0x20)==0
 assert len(packets)==bool(entries)
 return dict(kind=kind,indexed=hasIndex,entries=[dict(**{k:v for k,v in e.items()if k!='oracle'},value=oracle[e['oracle']]['value'])for e in entries],packet=packets[0].hex()if packets else None)
cases=[]
for kind in ['events','binds']:
 for indexed in [False,True]:
  for count in [0,1,3]:
   entries=[dict(token=3+i,type=['open','click','mouseup'][i],element=['_window_','row_button','image'][i],bind=['title','checks','count'][i],index=[-1,4,0][i],oracle=[0,1,29][i])for i in range(count)]
   cases.append(run(kind,entries,indexed))
out=m.root/'backups/animations/native-nui-wire-v1.json';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=cases),indent=2)+'\n');print(json.dumps(dict(success=True,cases=len(cases))))
