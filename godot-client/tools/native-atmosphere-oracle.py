"""Execute original day/night setters and complete color-transition1407e90b0.
Synthetic colors, empty tile/object lists, module/settings lookup, render/sky/
shadow/weather setters and stack-cookie are explicit lower boundaries. Original
vector math executes. No texture/sky/weather/GPU parity or live mutation claim.
"""
import sys,importlib,struct,json,itertools
from pathlib import Path
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'scripts'))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
area,module,vt,settings,app=[m.heap+n*0x1000 for n in range(5)]
calls=[]
def vec(p):return list(struct.unpack('<fff',u.mem_read(p,12)))
def put(p,v):u.mem_write(p,struct.pack('<'+'f'*len(v),*v))
def hook(u,a,n,data):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1406abea0:m.finish(module);return
 if a==0x1406ab9b0:m.finish(settings);return
 if a in [m.stop+0x28,m.stop+0x40,m.stop+0x48]:calls.append(dict(kind={0x28:'fog',0x40:'diffuse',0x48:'ambient'}[a-m.stop],value=vec(z),argument=y&0xffffffff));m.finish(1);return
 if a==0x1407e5d10:calls.append(dict(kind='direction',value=vec(y),argument=z&0xffffffff));m.finish();return
 if a==0x1400a5050:calls.append(dict(kind='tile',value=vec(x)));m.finish();return
 if a in [0x14007dd10,0x1407e9bc0,0x1407e9cb0,0x1408783d0,0x140c10410]:m.finish();return
 if 0x1407e90b0<=a<0x1407e9bc0 or 0x1407e5330<=a<0x1407e57f0 or 0x14022b150<=a<0x14022b1b0:return
 raise RuntimeError('Unexpected original atmosphere dependency '+hex(a))
u.hook_add(UC_HOOK_CODE,hook)
colors={'moonAmbient':[.1,.2,.3],'moonDiffuse':[.4,.5,.6],'moonFog':[.7,.8,.9],'sunAmbient':[.9,.8,.7],'sunDiffuse':[.6,.5,.4],'sunFog':[.3,.2,.1]}
rows=[]
cases=[dict(mode=mode,elapsed=elapsed,duration=duration,shadow=shadow,cycle=1,isNight=mode=='dawn') for mode,elapsed,duration,shadow in itertools.product(['dusk','dawn'],[-.25,0,.125,.4,.5,.6,.999,1,1.5],[1,30],[0,50,100])]
cases += [dict(mode='fixed',elapsed=0,duration=30,shadow=50,cycle=cycle,isNight=night) for cycle,night in itertools.product([0,1],[0,1])]
for c in cases:
 calls=[];u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(area,vt);m.wq(0x1412df970,app);m.wq(app,app)
 for offset in [0x28,0x40,0x48]:m.wq(vt+offset,m.stop+offset)
 for key,offset in [('moonAmbient',0x164),('moonDiffuse',0x170),('moonFog',0x17c),('sunAmbient',0x1c8),('sunDiffuse',0x1d4),('sunFog',0x1e0)]:put(area+offset,colors[key])
 put(area+0xac,[.1,.2,.9]);put(area+0xcc,[-.3,.4,.8]);u.mem_write(area+0xa4,bytes([25]));u.mem_write(area+0xc4,bytes([75]));u.mem_write(area+0x104,bytes([c['shadow']]));m.wi(area+0xd8,c['cycle']);m.wi(area+0xdc,int(c['isNight']));m.wf(module+0x174,c['elapsed']*c['duration']);m.wf(module+0x178,c['duration'])
 if c['mode']=='dawn':m.wi(area+0x2ac,1)
 if c['mode']=='dusk':m.wi(area+0x2b0,1)
 entry=0x1407e90b0 if c['mode']!='fixed' else 0x1407e55f0 if c['isNight'] else 0x1407e5390
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,area);u.emu_start(entry,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 for row in calls:row['bits']=[struct.pack('<f',v).hex() for v in row['value']]
 rows.append(dict(case=c,calls=calls,shadowBits=bytes(u.mem_read(0x14128ec14,4)).hex(),flags={'dawn':m.si(area+0x2ac),'dusk':m.si(area+0x2b0),'isNight':m.si(area+0xdc)}))
out=Path(sys.argv[1]);assert not out.exists();out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,colors=colors,amounts={'moon':25,'sun':75},rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
