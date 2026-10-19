"""Full original beam attachment96ba80, plus complete start96a110/stop96fa90
dispatchers restricted to their actual Type7 branches. Object/render/model
handles, parent/reference virtuals, string table/heap and animation are captured
lower boundaries. Preserves late B8 reads after callbacks. Not native reference
traversal, particle simulation, full native scene or original-client GPU proof.
Read-only pinned nwmain; no original game process/install mutation.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,manager,app,rules,table,target,source,tr,sr,th,sh,vt,pvt,model,replacement=[m.heap+n*0x1000 for n in range(1,16)]
asObject,handle,parent,reattach,play,scene=[m.stop+n*0x10 for n in range(1,7)]
def string(ptr):return bytes(u.mem_read(ptr,128)).split(b'\0')[0].decode('ascii')if ptr else ''
def writecs(ptr,value):
 global allocation
 if value is None:m.wq(ptr,0);m.wi(ptr+8,0);return
 dst=m.heap+0x80000+allocation*0x100;allocation+=1;u.mem_write(dst,value.encode()+b'\0');m.wq(ptr,dst);m.wi(ptr+8,len(value))
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1406abb60:
  ident=y&0xffffffff;calls.append(['object',ident]);m.finish((target if c['target']else 0)if ident==123 else(source if c['source']else 0))
 elif a==asObject:
  who='target'if x==target else'source';calls.append(['render',who]);m.finish((tr if c['targetRender']else 0)if x==target else(sr if c['sourceRender']else 0))
 elif a==handle:
  who='target'if x==tr else'source';calls.append(['handle',who,y&255,z&0xffffffff]);m.finish((th if c['targetHandle']else 0)if x==tr else(sh if c['sourceHandle']else 0))
 elif a==parent:
  calls.append(['parent',names[x],handles.get(y),string(z),w&0xffffffff])
  if c['replace']:m.wq(effect+0xb8,replacement)
  m.finish()
 elif a==reattach:calls.append(['reattach',names[x],handles.get(y),string(z)]);m.finish()
 elif a==play:calls.append(['play',names[x],string(y),struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM2)&0xffffffff))[0],w&0xffffffff,m.rf(rsp+0x28)]);m.finish(0)
 elif a==scene:calls.append(['scene',names[x],y]);m.finish()
 elif a==0x14096c340:calls.append(['type',y&65535]);m.finish(7)
 elif a==0x1401a68f0:calls.append(['string',y&65535,string(m.q(z))]);writecs(w,c['animation']);m.finish(c['found'])
 elif a==0x140c10370:m.finish()
 elif a in [0x140c10368,0x140c10324]:ptr=m.heap+0x80000+allocation*0x100;allocation+=1;m.finish(ptr)
 elif not any(lo<=a<hi for lo,hi in[(0x14096ba80,0x14096bbac),(0x14096a110,0x14096a53a),(0x14096fa90,0x14096fdbd)]):raise RuntimeError(f'Uncaptured beam dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation,names,handles
 c=case;calls=[];allocation=0;names={model:0,replacement:1};handles={0:None,th:'target',sh:'source'}
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,manager);m.wq(manager,app);m.wq(0x1412df8f8,app);m.wq(app+0x130,rules);m.wq(rules+0x270,table)
 for ptr in[target,source,tr,sr]:m.wq(ptr,vt)
 for ptr in[model,replacement]:m.wq(ptr,pvt)
 m.wq(vt+0x18,asObject);m.wq(vt+0x140,handle)
 for off,fn in[(0x98,parent),(0x150,reattach),(0x30,play),(0x90,scene)]:m.wq(pvt+off,fn)
 m.wi(effect+0x54,123);m.wi(effect+0x58,789);m.wq(effect+0xb8,model if c['model']else 0);m.wi(effect+0xd8,c['enabled']);writecs(effect+0x28,c['sourceAnchor']);writecs(effect+0x38,c['targetAnchor'])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,c['program']);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 entry={'attach':0x14096ba80,'start':0x14096a110,'stop':0x14096fa90}[c['mode']]
 try:u.emu_start(entry,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,model=names.get(m.q(effect+0xb8)))
def profile(**kw):
 c=dict(mode='attach',model=1,target=1,source=1,targetRender=1,sourceRender=1,targetHandle=1,sourceHandle=1,replace=0,enabled=1,sourceAnchor='handconjure',targetAnchor='impact',animation='cast01',found=1,program=0x10001);c.update(kw);return c
rows=[run(profile(**dict(zip(['model','target','source','targetRender','sourceRender','targetHandle','sourceHandle'],flags)),replace=replace,sourceAnchor=anchors[0],targetAnchor=anchors[1]))for flags,replace,anchors in itertools.product(itertools.product([0,1],repeat=7),[0,1],[('handconjure','impact'),(None,None),('','root'),('HEAD','monster2')])]
rows +=[run(profile(mode='start',**dict(zip(['target','source','targetRender','sourceRender','targetHandle','sourceHandle'],flags)),replace=replace,animation=animation,found=found))for flags,replace,(animation,found)in itertools.product(itertools.product([0,1],repeat=6),[0,1],[('cast01',1),('',0),('fallback_animation',0)])]
rows +=[run(profile(mode='stop',model=has,enabled=enabled,replace=replace))for has,enabled,replace in itertools.product([0,1],repeat=3)]
rows +=[run(profile(mode='start',enabled=0,model=has))for has in[0,1]]
out=m.root/'backups/animations/native-visual-beam-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
