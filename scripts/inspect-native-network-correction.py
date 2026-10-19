"""Complete original804840 correction plus original vector math. Capture
the final position setter and virtual+150 animation record (type6), allocation
and frees. No live process changes; correction animation callback is checked
separately at7fc7d0 (type6 -> queue duration and length/duration speed).
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
obj,vt,point=[m.heap+n*0x1000 for n in range(40,43)];setter,animation=m.stop+0x128,m.stop+0x150
ranges=[(0x140804840,0x140804bec),(0x140230920,0x1402309f6),(0x1402303d0,0x14023040d),(0x14022fba0,0x14022fbfa),(0x140c7d6d8,0x140c7d783),(0x1407630d0,0x1407630d5)]
owner=json.loads((m.root/'backups/animations/rea-movement-playanimation-owner.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in owner['procedure']['body']['ranges'])
def vec(p):return list(struct.unpack('<3f',u.mem_read(p,12)))
def put(p,v):u.mem_write(p,struct.pack('<3f',*v))
def hook(u,a,n,data):
 x,y,z=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==setter:put(obj+0x38,vec(y));m.finish();return
 if a==0x140c10360:m.finish();return
 if a==animation:requests.append(dict(animation=y&65535,type=u.mem_read(z,1)[0],duration=struct.unpack('<H',u.mem_read(z+8,2))[0]));u.reg_write(UC_X86_REG_RIP,0x1407fc7d0);return
 if a==0x1407630b0:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',c['clipMs']),'little'));m.finish();return
 if a==0x1407635a0:queues.append(dict(animation=y&65535,duration=z&0xffffffff,speed=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM3)&0xffffffff))[0],record=m.q(u.reg_read(UC_X86_REG_RSP)+0x28),delay=m.si(u.reg_read(UC_X86_REG_RSP)+0x30)));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,requests,queues
 c=case;requests=[];queues=[];t.reset(dict(format=1));m.wq(obj,vt);m.wq(vt+0x128,setter);m.wq(vt+0x150,animation);m.wi(obj+0x58,c['dt']);m.wi(obj+0x2cc,c['timer']);u.mem_write(obj+0x5c,struct.pack('<H',c['animation']));put(obj+0x38,c['render']);put(obj+0x2c0,c['position']);put(obj+0x44,c['orientation']);put(point,c['position']);w.call(0x140804840,[obj,point]);return dict(case=c,render=vec(obj+0x38),timer=m.si(obj+0x2cc),requests=requests,queues=queues)
base=dict(animation=0,dt=16,timer=512,position=[10.,10.,0.],render=[9.,10.,0.],orientation=[1.,0.,0.],clipMs=1000.)
cases=[base|dict(animation=a,dt=dt,render=[10.-x,10.-y,-z])for a,dt,(x,y,z)in itertools.product([0,1,4,24],[0,16,100,512],[(0,0,0),(.1,0,0),(.19999,0,0),(.2,0,0),(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(1,1,0),(1,-1,0),(3.99,0,0),(4,0,0),(0,0,5)])]
rows=[]
for c in cases:
 try:rows.append(run(c))
 except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
out=m.root/'backups/animations/native-network-correction-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
