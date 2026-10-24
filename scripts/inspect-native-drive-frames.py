"""Original held-input6f1e40 -> preview6ea9e0/7fdeb0/install80b0d0,
followed by original motion8114d0/811fc0/804bf0/correction804840/facing807690.
Synthetic flat world and collision plane answers; timer, outgoing messages,
object/model lookup, animation notifications, scale/rules and height are captured.
This is an isolated local frame composition, not original app/network execution.
No live process writes or asset copies.
"""
import sys,importlib,json,struct,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-drive-preview');w=p.w;m=p.m;u=p.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(p.hook_handle)
vt,settings,timer,model,mvt,head,rules,rulesOwner,table=[m.heap+n*0x1000 for n in range(100,109)]
ranges=p.ranges+[(0x1406f1e40,0x1406f2829),(0x1406f1bc0,0x1406f1c17),(0x14080b0d0,0x14080b20d),(0x140807690,0x140807943),(0x1407630d0,0x1407630d5),(0x1407630b0,0x1407630c9),(0x140762600,0x140762626),(0x140c79d30,0x140c7a2aa),(0x140c92d20,0x140c93360)]
for name in ['path-advance','path-step','path-next-waypoint','motion-correct']:
 d=json.loads((m.root/f'backups/animations/rea-network-client-{name}.json').read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def xd(reg):return struct.unpack('<d',u.reg_read(reg).to_bytes(16,'little')[:8])[0]
def rd(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<d',value),'little'));m.finish()
def rf(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14016dd30:m.finish(now);return
 if a==0x1407bf980:events.append(dict(kind='wire',position=[m.rf(y),m.rf(y+4)],flags=u.mem_read(sp+0x30,1)[0]));m.finish(1);return
 if a==0x1407c03b0:events.append(dict(kind='turn'));m.finish(1);return
 if a==0x1407bf040:events.append(dict(kind='stop'));m.finish(1);return
 if a==0x1406d8ad0:m.finish();return
 if a==0x1406ea9e0:events.append(dict(kind='preview',flags=y&255))
 if a==0x1406f1bc0:events.append(dict(kind='refresh',fraction=struct.unpack('<f',u.reg_read(UC_X86_REG_XMM1).to_bytes(16,'little')[:4])[0]))
 if a==0x14080b0d0:events.append(dict(kind='install',path=[p.vec(z+i*12)for i in range(y&65535)]))
 if a==0x1407e6a20:
  start,end=p.vec(z),p.vec(k);clear=all(sum((end[i]-plane['origin'][i])*plane['normal'][i]for i in range(3))<=plane['offset'] for plane in case.get('planes',[]));events.append(dict(kind='query',start=start,end=end,clear=clear));m.finish(int(clear));return
 if a==0x1407630a0:m.finish(model);return
 if a==0x1401a6c70:m.wf(k,2.);m.finish(1);return
 if a==0x1402e9a80:rf(1.);return
 if a==m.stop+0x48:rf(1000.);return
 if a in[m.stop+0x80,m.stop+0x208]:m.finish();return
 if a==m.stop+0x128:p.put(p.obj+0x38,p.vec(y));m.finish();return
 if a==m.stop+0x120:p.put(p.obj+0x44,p.vec(y));m.finish();return
 if a==m.stop+0x150:events.append(dict(kind='facing-animation',animation=y&65535));m.finish();return
 if a==0x1407ff030:m.finish();return
 if a==0x140763220:m.finish(0);return
 if a==0x140765f50:m.finish();return
 if a==0x140761d80:u.mem_write(p.obj+0x5c,struct.pack('<H',0));m.finish();return
 if a==0x140764300:u.mem_write(p.obj+0x5c,struct.pack('<H',y&65535));m.finish();return
 if a==0x140c93af8:rd(math.atan2(xd(UC_X86_REG_XMM0),xd(UC_X86_REG_XMM1)));return
 if a==0x140c87b10:rd(math.floor(xd(UC_X86_REG_XMM0)+.5));return
 if a==0x140cae8e0:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if any(lo<=a<hi for lo,hi in ranges):return
 p.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global case,events,now
 case=c;p.t.reset(dict(format=1));u.reg_write(UC_X86_REG_MXCSR,0x1f80);m.wq(w.app,p.owner);m.wq(p.owner+8,p.ui);m.wq(0x1412df8b8,p.owner);m.wq(p.owner+0x10,timer);m.wq(p.ui,settings);u.mem_write(p.ui+0x140,b'\2');m.wq(p.owner+0xf8,p.area)
 m.wq(p.obj,vt);m.wq(p.obj+0x78,model);m.wq(model,mvt);u.mem_write(model+0xde,b'\1');m.wq(mvt+0x48,m.stop+0x48);m.wq(mvt+0x80,m.stop+0x80)
 for off in[0x120,0x128,0x150,0x208]:m.wq(vt+off,m.stop+off)
 m.wq(vt+0x240,0x140804bf0);m.wq(p.obj+0x138,head);m.wq(head+8,head);u.mem_write(head+0x19,b'\1');m.wq(0x1412df8f8,rules);m.wq(rules+0x130,rulesOwner);m.wq(rulesOwner+0x100,table);m.wq(p.obj+0x300,p.appearance)
 m.wq(p.obj+0x30,p.area);m.wi(p.area+0x118,0x80000001);m.wi(p.obj+0x41c,1);u.mem_write(p.obj+0x37c,b'\2');p.put(p.obj+0x38,c['position']);p.put(p.obj+0x2c0,c['position']);p.put(p.obj+0x44,c['orientation']);p.put(p.obj+0x2a8,c['orientation']);m.wf(p.obj+0x2f0,2200.);m.wf(p.obj+0x2f4,4400.)
 for off,bit in[(0x1b8,3),(0x1c8,4),(0x1cc,8),(0x1c0,16),(0x1c4,32)]:m.wi(p.ui+off,int((c['flags']&bit)==bit))
 rows=[];nextRepeat=500
 for frame in range(90):
  elapsed=frame*16;now=10000000+elapsed*1000;events=[];dirty=frame==0 or c['repeat']and elapsed>=nextRepeat
  if frame and dirty:nextRepeat+=33
  m.wi(p.ui+0x1b0,int(dirty));m.wi(p.obj+0x58,16);w.call(0x1406f1e40,[p.ui]);count=struct.unpack('<H',u.mem_read(p.obj+0x2d0,2))[0];animation=struct.unpack('<H',u.mem_read(p.obj+0x5c,2))[0]
  if count and animation in[2,3,4,78,79,84,85,86,87]:w.call(0x1408114d0,[p.obj])
  rows.append(dict(elapsedMs=elapsed,dirty=dirty,events=events,position=p.vec(p.obj+0x2c0),render=p.vec(p.obj+0x38),orientation=p.vec(p.obj+0x44),animation=struct.unpack('<H',u.mem_read(p.obj+0x5c,2))[0],script=m.si(p.obj+0x2f8),lastWire=m.q(p.ui+0x1a0),lastPreview=m.q(p.ui+0x198)))
 return dict(case=c,frames=rows)
cases=[dict(flags=flags,position=[10.,20.,0.],orientation=[1.,0.,0.],repeat=repeat,planes=planes)for flags in[3,4,8,20,40,19,35]for repeat in[False,True]for planes in[[],[dict(origin=[10.,20.,0.],normal=[0.,1.,0.],offset=.4)]]]
rows=[]
for c in cases:
 try:rows.append(run(c))
 except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
out=dict(target=m.digest,scope=__doc__,cases=rows);(m.root/'backups/animations/native-drive-frames-v1.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(dict(cases=len(rows),frames=sum(len(r['frames'])for r in rows))))
