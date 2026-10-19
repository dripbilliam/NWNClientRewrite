"""Execute original camera receiver77a7f0 for modes/store/restore/height/locks/
limits/flags with original CNWMessage writer/readers and synthetic camera state.
App lookup, camera virtual accessors, settings-mode application and finite
sprintf/command parsing are explicit boundaries. No live process mutation or
installed asset copies. Script location interpolation/attachment are excluded.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
module,camera,behavior,settings,vt,bvt=[m.heap+i*0x1000 for i in range(40,46)]
ranges=[(0x14077a7f0,0x14077b267),(0x1407cfd30,0x1407cfdb0),(0x1407cf350,0x1407cf4ec),(0x1407cf9d0,0x1407cf9f7),(0x1407cc5f0,0x1407cc72c)]
def put(a,v):u.mem_write(a,struct.pack('<'+'f'*len(v),*v))
def vec(a,n=3):return list(struct.unpack('<'+'f'*n,u.mem_read(a,n*4)))
def rf(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
def text(a):return bytes(u.mem_read(a,128)).split(b'\0')[0].decode('ascii')
commands=[]
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406abea0:m.finish(module);return
 if a==0x1406ab9b0:m.finish(settings);return
 if a==0x1406f49a0:u.mem_write(settings+0x1d,bytes([y&255]));m.finish();return
 if a==m.stop+0xe8:m.finish(behavior);return
 if a==m.stop+0x40:m.finish(behavior);return
 if a in [m.stop+0xb0,m.stop+0xb8,m.stop+0xc0]:rf(m.rf(behavior+{m.stop+0xb0:0x54,m.stop+0xb8:0x5c,m.stop+0xc0:0x48}[a]));return
 if a==0x140047000:
  value=struct.unpack('<d',(z&0xffffffffffffffff).to_bytes(8,'little'))[0];line=text(y)%value;u.mem_write(x,line.encode()+b'\0');m.finish(len(line));return
 if a==m.stop+0xa8:
  line=text(y);commands.append(line);name,value=line.split();m.wf(behavior+dict(yaw=0x54,dist=0x48,pitch=0x5c)[name],float(value));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
hook_handle=u.hook_add(UC_HOOK_CODE,hook)
def setup(c):
 t.reset(dict(format=1));m.wq(module+0xe8,camera);m.wq(camera,vt);m.wq(behavior,bvt);m.wq(vt+0xe8,m.stop+0xe8);m.wq(bvt+0x40,m.stop+0x40)
 for off in [0xb0,0xb8,0xc0,0xa8]:m.wq(vt+off,m.stop+off)
 put(behavior+0x3c,[0,0,c.get('height',1.25)]);m.wf(behavior+0x48,c.get('distance',20));m.wf(behavior+0x54,c.get('yaw',35));m.wf(behavior+0x5c,c.get('pitch',50));put(behavior+0x64,[0,0,360,1,1,89,1,1,25]);put(module+0x118,[0,0,1.25]);put(module+0x2ac,[-1,-1,-1,-1]);put(settings+0x124,[1,89,1,25]);u.mem_write(module+0x29c,b'\xff');u.mem_write(settings+0x1d,bytes([c.get('mode',1)]));m.wi(module+0x2bc,c.get('flags',0))
 for a in [0x141427100,0x141427104,0x141427108]:m.wi(a,0)
 put(0x1412973d0,[1,25,1,89])
def state():
 return dict(mode=u.mem_read(settings+0x1d,1)[0],height=vec(behavior+0x3c),distance=m.rf(behavior+0x48),yaw=m.rf(behavior+0x54),pitch=m.rf(behavior+0x5c),clamps=vec(behavior+0x64,9),limits=vec(module+0x2ac,4),flags=m.si(module+0x2bc),saved=dict(mode=u.mem_read(module+0x29c,1)[0],values=vec(module+0x2a0)),locks=[m.si(a)for a in [0x141427100,0x141427104,0x141427108]],commands=list(commands))
def receive(minor,ops):
 global commands
 commands=[];w.call(0x1402d54a0,[w.message,0,0xffffffff,1])
 for kind,value in ops:
  if kind=='float':w.call(w.addresses[kind],[w.message,0,0,32],[value,1])
  else:w.call(w.addresses[kind],[w.message,int(value),32 if kind=='int' else 8,1])
 snap=w.snapshot();data=bytes.fromhex(snap['hex'])[3:] if snap['hex'] else b'';packet=t.r.packet;u.mem_write(packet,data or b'\0');m.wi(m.stack+0x1fe30,1);w.call(0x1402da7b0,[w.message,packet,len(data),0xffffffff]);w.call(0x14077a7f0,[w.message,minor]);overflow=bool(w.call(t.r.addresses['overflow']));underflow=bool(w.call(t.r.addresses['underflow']));return dict(minor=minor,ops=ops,body=data.hex(),state=state(),diagnostics=list(t.r.diagnostics),overflow=overflow,underflow=underflow)
if __name__=='__main__':
 rows=[]
 for minor,value in itertools.product([5,6,7,8,12],[-2,0,1,2,12.5]):
  c=dict(distance=12.75,yaw=35.125,pitch=42.5);setup(c);ops=[['float' if minor==5 else 'int' if minor==12 else 'bool',value]];rows.append(dict(case=c,steps=[receive(minor,ops)]))
 for values in [[2,18,10,75],[-1,-1,-1,-1],[30,2,90,1]]:
  c={};setup(c);rows.append(dict(case=c,steps=[receive(9,[['float',v]for v in values]),receive(6,[['bool',1]]),receive(6,[['bool',0]]),receive(7,[['bool',1]]),receive(7,[['bool',0]])]))
 for mode,distance,yaw,pitch in itertools.product(range(3),[0,12.25],[0,35.125], [0,42.5]):
  c=dict(mode=mode,distance=distance,yaw=yaw,pitch=pitch);setup(c);first=receive(3,[]);m.wf(behavior+0x48,7);m.wf(behavior+0x54,-20);m.wf(behavior+0x5c,30);second=receive(4,[]);rows.append(dict(case=c,steps=[first,second,receive(4,[])]))
 out=m.root/'backups/animations/native-camera-command-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
