"""Complete original8114d0 gait-rate selection with its path/correction
helpers. Capture model+80 speed/flags/phase, model lengths/transitions, rules
distance, visual scale, height, facing and final animation notifications.
No original process changes. Previous animation0 isolates the no-blend branch.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
obj,vt,model,mvt,head,points,rules,owner,table,appearance=[m.heap+n*0x1000 for n in range(40,50)]
ranges=[(0x1402303d0,0x14023040d),(0x140230920,0x1402309f5),(0x140c7d6d8,0x140c7d783),(0x1407630d0,0x1407630d5),(0x1407630b0,0x1407630c9),(0x140762600,0x140762626)]
for name in ['path-advance','path-step','path-next-waypoint','motion-correct']:
 d=json.loads((m.root/f'backups/animations/rea-network-client-{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def vec(p):return list(struct.unpack('<3f',u.mem_read(p,12)))
def put(p,v):u.mem_write(p,struct.pack('<3f',*v))
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def rf(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1407630a0:m.finish(model);return
 if a==0x1401a6c70:m.wf(k,c['distance']);m.finish(1);return
 if a==0x1402e9a80:rf(c['scale']);return
 if a==m.stop+0x48:rf(c['clipMs']);return
 if a==m.stop+0x80:draws.append(dict(animation=y&65535,speed=xmm(UC_X86_REG_XMM2),flags=k,phase=m.rf(u.reg_read(UC_X86_REG_RSP)+0x28)));m.finish();return
 if a==m.stop+0x128:put(obj+0x38,vec(y));m.finish();return
 if a in [m.stop+0x208,0x1407ff030,0x140807690,0x140765f50]:m.finish();return
 if a==0x140763220:m.finish(0);return
 if a==0x140764300:u.mem_write(obj+0x5c,struct.pack('<H',y&65535));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,draws
 c=case;draws=[];t.reset(dict(format=1));m.wq(obj,vt);m.wq(model,mvt);m.wq(mvt+0x48,m.stop+0x48);m.wq(mvt+0x80,m.stop+0x80)
 for off,fn in [(0x128,m.stop+0x128),(0x208,m.stop+0x208),(0x240,0x140804bf0)]:m.wq(vt+off,fn)
 m.wq(obj+0x78,model);m.wq(obj+0x138,head);m.wq(head+8,head);u.mem_write(head+0x19,b'\x01');m.wq(0x1412df8f8,rules);m.wq(rules+0x130,owner);m.wq(owner+0x100,table);m.wq(obj+0x300,appearance)
 u.mem_write(obj+0x5c,struct.pack('<H',c['animation']));m.wi(obj+0x58,c['dt']);m.wf(obj+0x2f0,c['rate']);m.wf(obj+0x2f4,c['rate']);m.wi(obj+0x2f8,c['script']);m.wf(obj+0x2e0,c['factor']);m.wf(obj+0x2dc,c['acceleration']);m.wi(obj+0x2d8,1)
 put(obj+0x38,[1,2,0]);put(obj+0x2c0,[1,2,0]);put(obj+0x44,[1,0,0]);m.wq(obj+0x298,points);m.wq(obj+0x2a0,points);u.mem_write(obj+0x2d0,struct.pack('<H',1));put(points,[30,2,0])
 w.call(0x1408114d0,[obj]);return dict(case=c,draws=draws,position=vec(obj+0x2c0),acceleration=m.rf(obj+0x2dc))
base=dict(animation=4,dt=16,rate=4400.,script=0,factor=1.,scale=1.,distance=2.,clipMs=1000.,acceleration=.5)
cases=[base|dict(animation=a,script=script,factor=factor,scale=scale,clipMs=length,acceleration=acc,distance=distance)for a,script,factor,scale,length,acc,distance in itertools.product([2,3,4,78,79,84,85,86,87],[0,1],[.5,1.,2.],[.5,1.,2.],[600.,1000.,1500.],[0.,.5,1.],[1.5,2.])]
rows=[]
for c in cases:
 try:rows.append(run(c))
 except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
out=m.root/'backups/animations/native-network-gait-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
