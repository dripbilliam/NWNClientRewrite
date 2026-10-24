"""Whole original procedural projectile start96a9a0..96afff in isolated memory.
Original branch/order and duration magnitude/log/float arithmetic execute.
CResRef conversion, table/client/render/model lookup, allocation/constructor,
model load/pose and final projectile setters/path are captured lower services.
No game process, original files, server objects or game RNG are modified.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,manager,app,rules,table,target,source,targetRender,sourceRender,vt,model,pvt,client,video,scene,sourceModel=[m.heap+n*0x1000 for n in range(1,17)]
def vector(a):return list(struct.unpack('<3f',u.mem_read(a,12)))
def cstr(a):return bytes(u.mem_read(a,256)).split(b'\0')[0].decode('latin1')if a else''
def cs(a):return cstr(m.q(a))
def put(a,s):
 p=alloc(len(s)+1);u.mem_write(p,s.encode('latin1')+b'\0');m.wq(a,p);m.wi(a+8,len(s));m.wi(a+12,len(s)+1)
def alloc(n):
 global cursor
 p=m.heap+cursor;cursor+=(n+31)&~15;assert cursor<0xf0000;return p
def floating(v):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',v),'little'));m.finish()
def hook(u,a,n,_):
 global projectile
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10370:m.finish();return
 if a in[0x140c10324,0x140c10368]:m.finish(alloc(x));return
 if a in[0x1401a68f0,0x1401a7010]:
  column=cs(z);value=case['values'].get(column);calls.append(['string'if a==0x1401a68f0 else'integer',y&65535,column,value])
  if value is not None:
   if a==0x1401a68f0:put(w,value)
   else:m.wi(w,value)
  m.finish(int(value is not None));return
 if a==0x1406abb60:
  isTarget=y&0xffffffff==123;exists=case['target']if isTarget else case['source'];calls.append(['client',y&0xffffffff]);m.finish((target if isTarget else source)if exists else 0);return
 if a==m.stop+0x10:
  isTarget=x==target;calls.append(['render',123 if isTarget else 456]);m.finish((targetRender if isTarget else sourceRender)if(case['targetRender']if isTarget else case['sourceRender'])else 0);return
 if a==0x1409832a0:
  projectile=x;m.wq(x,pvt);m.wi(x+0x174,0x7f000000);calls.append(['construct']);m.finish(x);return
 if a==0x1409876a0:calls.append(['configureSpell',y&0xffffffff]);m.finish();return
 if a==m.stop+0x20:calls.append(['loadModel',cstr(y),z&255,w]);m.finish(case['load']);return
 if a==m.stop+0x30:calls.append(['model']);m.finish(sourceModel if case['sourceModel']else 0);return
 if a==m.stop+0x40:
  calls.append(['nodePose',cstr(y)]);u.mem_write(z,struct.pack('<3f',*case['hand']));m.finish(case['pose']);return
 if a==m.stop+0x50:u.mem_write(x+0x38,struct.pack('<3f',*vector(y)));calls.append(['position',vector(y)]);m.finish();return
 if a==m.stop+0x60:u.mem_write(x+0x44,struct.pack('<3f',*vector(y)));calls.append(['orientation',vector(y)]);m.finish();return
 if a==0x1406abea0:calls.append(['controlledClient']);m.finish(client if case['client']else 0);return
 if a==m.stop+0x70:calls.append(['scene']);m.finish();return
 if a==0x140985510:calls.append(['stage',y&0xffffffff]);m.finish(1);return
 if a==0x1409873d0:m.wi(x+0x174,y);calls.append(['target',y&0xffffffff,cs(z)]);m.finish();return
 if a==0x1409873c0:calls.append(['time',y&0xffffffff]);m.wi(x+0x194,y);m.wi(x+0x21c,y);m.finish();return
 if a==0x140987770:calls.append(['path',y&0xffffffff]);m.finish();return
 if a==m.stop+0x80:calls.append(['destroy']);m.finish();return
 if a==0x14018dea0:
  raw=cs(y).encode('latin1')[:16];u.mem_write(x,raw+bytes(17-len(raw)));m.finish(x);return
 if a==0x140c7d6d8:floating(math.sqrt(m.xmm(UC_X86_REG_XMM0)));return
 if a==0x140cb5b64:u.reg_write(UC_X86_REG_XMM0,u.reg_read(UC_X86_REG_XMM1));m.finish();return
 if 0x14096a9a0<=a<0x14096aff0 or 0x140762900<=a<=0x14076298d or 0x1402303d0<=a<0x14023040d or 0x140c946b0<=a<0x140c94aa6:return
 raise RuntimeError(f'Uncaptured Type10 lower {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
base=dict(target=1,source=1,targetRender=1,sourceRender=1,sourceModel=1,pose=1,load=1,client=1,video=1,fromPoint=[1,2,3],toPoint=[4,6,7],hand=[2,3,4],orientation=[0,1,0],point=[0,0,0],values=dict(param1='AuthoredModelLongName',param2=340,param3=2,param4=4,param5='log'))
profiles=[]
for flags in range(512):profiles.append(base|{name:flags>>i&1 for i,name in enumerate(['target','source','targetRender','sourceRender','sourceModel','pose','load','client','video'])})
for mode,distance,point,missing in itertools.product(['log','linear2','linear','LOG','log\0suffix',''],[0,.01,.5,1,2,10,100],[[0,0,0],[8,9,10]],[0,1]):
 profiles.append(base|dict(fromPoint=[0,0,0],toPoint=[distance,0,0],hand=[0,0,1],point=point,values=dict(param1='projectile',param2=None if missing else -1,param3=None if missing else 258,param4=None if missing else 7,param5=mode)))
rows=[]
for case in profiles:
 calls=[];cursor=0x30000;projectile=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,manager);m.wq(manager,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,table);m.wq(table+0x270,table);m.wi(0x1415d8224,0)
 for ptr in[target,source,sourceRender,sourceModel]:m.wq(ptr,vt)
 for off,targetHook in[(0x18,0x10),(0x140,0x30),(0x138,0x40)]:m.wq(vt+off,m.stop+targetHook)
 for off,targetHook in[(0xf0,0x20),(0x128,0x50),(0x120,0x60),(0x138,0x70),(0,0x80)]:m.wq(pvt+off,m.stop+targetHook)
 m.wq(client+0xf8,video if case['video']else 0);m.wq(video+0x248,scene);m.wi(targetRender+8,123);m.wi(sourceRender+8,456);m.wi(effect+0x54,123);m.wi(effect+0x58,456)
 for address,values in[(sourceRender+0x38,case['fromPoint']),(targetRender+0x38,case['toPoint']),(sourceRender+0x44,case['orientation']),(effect+0x48,case['point'])]:u.mem_write(address,struct.pack('<3f',*values))
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,900)
 error=None
 try:u.emu_start(0x14096a9a0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 except Exception as e:error=str(e)
 rows.append(dict(case=case,calls=calls,endpoint=vector(projectile+0x188)if projectile else None,facing=u.mem_read(projectile+0x239,1)[0]if projectile else None,error=error,rip=hex(u.reg_read(UC_X86_REG_RIP))))
 if len(rows)%256==0:print(json.dumps(dict(progress=len(rows))),flush=True)
 if error:break
out=m.root/'backups/animations/native-visual-type10-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,comparisonStrings=[cstr(0x140e0f5e4),cstr(0x140e70c80)],rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(out),rows=len(rows),errors=[r['error']for r in rows if r['error']])))
