"""Complete unchanged visual selection-time attachment14096ed70..14096f6bd.
Client/model/global-pose/CString/procedural callbacks are explicit lower
providers. All native type dispatch, flags, names and live pointer reads execute.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,manager,client,render,host,viewA,viewB,vt=[m.heap+n*0x1000 for n in range(8)]
def string(ptr):
 if not ptr:return ''
 raw=bytearray()
 while u.mem_read(ptr+len(raw),1)[0]:raw.append(u.mem_read(ptr+len(raw),1)[0])
 return raw.decode('ascii')
def cs(ptr):return string(m.q(ptr))
def allocate(size):
 global allocation
 ptr=m.heap+0x80000+allocation*0x100;allocation+=1;return ptr
def writecs(ptr,value):
 data=value.encode()+b'\0';dst=allocate(len(data));u.mem_write(dst,data);m.wq(ptr,dst);m.wi(ptr+8,len(data)-1);m.wi(ptr+12,len(data))
def vector(ptr,values):
 for i,v in enumerate(values):m.wf(ptr+i*4,v)
def read(ptr,n=3):return[m.rf(ptr+i*4)for i in range(n)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140c10370:m.finish()
 elif a==0x140c10368:m.finish(allocate(x))
 elif a==0x14016ab00:writecs(y,cs(x)+cs(z));m.finish(y)
 elif a==0x1406abb60:calls.append(['client',y&0xffffffff]);m.finish(client if c['client']else 0)
 elif a==m.stop+0x10:calls.append(['render']);m.finish(render if c['render']else 0)
 elif a==m.stop+0x20:calls.append(['modelHandle',y&255,z&0xffffffff]);m.finish(host if c['host']else 0)
 elif a==m.stop+0x30:calls.append(['viewA']);m.finish(viewA if c['first']else 0)
 elif a==m.stop+0x40:calls.append(['viewB']);m.finish(viewB if c['second']else 0)
 elif a==m.stop+0x50:calls.append(['parent',names[x],9,string(z),w&0xffffffff]);m.finish()
 elif a==m.stop+0x60:
  id=names[x];calls.append(['pose',id,string(y)]);vector(z,[id+.25,id+.5,id+.75]);vector(w,[.5,.5,.5,.5]);m.finish()
 elif a==m.stop+0x70:calls.append(['setPose',names[x],string(y),read(z),read(w,4)]);m.finish()
 elif a==0x14096c340:calls.append(['programType',y&65535]);m.finish(c['type'])
 elif a in [0x14096ba80,0x14096bbb0,0x14096b630,0x140969ef0,0x14096aff0,0x1409689f0]:
  calls.append([f'programAttach{a:x}']+([]if a in[0x14096ba80,0x14096bbb0]else[y&65535]))
  if c['replace']:m.wq(effect+0xb8,models[4])
  m.finish()
 elif a==m.stop+0x80:calls.append(['renderSetting158',read(y),z&255,m.xmm(UC_X86_REG_XMM3),m.si(u.reg_read(UC_X86_REG_RSP)+0x28)]);m.finish()
 elif not 0x14096ed70<=a<0x14096f6bd:raise RuntimeError(f'Unexpected visual attachment dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,names,allocation,models
 c=case;calls=[];names={};allocation=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,manager);m.wq(manager,manager+0x100)
 for ptr in [client,render,host]:m.wq(ptr,vt)
 for off,target in [(0x18,0x10),(0x140,0x20),(0xa0,0x30),(0x28,0x40),(0x98,0x50),(0x138,0x60),(0x130,0x70),(0x158,0x80)]:m.wq(vt+off,m.stop+target)
 writecs(viewA+0x1e0,c['prefixA']);writecs(viewB+0x1c8,c['prefixB']);writecs(effect+0x38,'target_anchor');m.wi(effect+0x54,123);m.wi(effect+0x114,7);m.wi(effect+0x120,c['orient']);u.mem_write(effect+0xfa,bytes([c['phase']]));vector(effect+0x18,[1.25,-2.5,3.75])
 models=[m.heap+0x10000+i*0x1000 for i in range(5)]
 for i,ptr in enumerate(models):names[ptr]=i;m.wq(ptr,vt)
 for i in range(3):m.wq(effect+0x88+i*8,models[i]if c['models'][i]else 0);u.mem_write(effect+0xd0+i*2,[10,20,30][i].to_bytes(2,'little'))
 m.wq(effect+0xb8,models[3]if c['procedural']else 0)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect)
 try:u.emu_start(0x14096ed70,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,attached=m.si(effect+0x114),procedural=names.get(m.q(effect+0xb8)))
def profile(**kw):
 c=dict(client=1,render=1,host=1,first=0,second=0,prefixA='placeable',prefixB='door',orient=0,phase=2,type=0,models=[1,1,1],procedural=0,replace=0);c.update(kw);return c
rows=[run(profile(first=first,second=second,orient=orient,phase=phase,type=type,models=models,procedural=procedural))for first,second,orient,phase,type,models,procedural in itertools.product([0,1],[0,1],[0,1],[0,1,2,3],range(9),[[0,0,0],[1,1,1]],[0,1])]
rows.extend(run(profile(**kw))for kw in [dict(client=0),dict(render=0),dict(host=0),dict(first=1,prefixA=''),dict(second=1,prefixB='')])
rows.extend(run(profile(type=kind,procedural=proc,replace=1))for kind,proc in itertools.product([1,2,3,4,5,7],[0,1]))
out=m.root/'backups/animations/native-visual-attachment-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
