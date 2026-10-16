"""Complete unchanged Type4 local-pose attachment14096bbb0..14096c174.
Client/model/prefix/local-pose/context services and CString/heap are explicit
lower providers; verifies all object branches/offsets/live pointer reads.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,manager,client,render,host,first,second,creature,other,context,vt,modelvt,model,replacement=[m.heap+n*0x1000 for n in range(14)]
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
 elif a==m.stop+0x30:calls.append(['viewA']);m.finish(first if c['first']else 0)
 elif a==m.stop+0x40:calls.append(['viewB']);m.finish(second if c['second']else 0)
 elif a==m.stop+0x50:calls.append(['view58']);m.finish(creature if c['creature']else 0)
 elif a==m.stop+0x60:
  calls.append(['localNodePose',string(y),read(z),read(w,4)])
  if c['pose']:vector(z,[.25,.5,.75]);vector(w,[.5,.5,.5,.5])
  m.finish(c['pose'])
 elif a==m.stop+0x70:
  calls.append(['setLocalNodePose',names[x],string(y),read(z),read(w,4)])
  if c['replace']:m.wq(effect+0xb8,replacement)
  m.finish()
 elif a==m.stop+0x80:calls.append(['parent',names[x],9,string(z),w&0xffffffff]);m.finish()
 elif a==0x1406ac1a0:calls.append(['view1406ac1a0']);m.finish(creature if c['selected']else other)
 elif a==0x1407e9bc0:calls.append(['refreshContext1407e9bc0']);m.finish()
 elif not 0x14096bbb0<=a<0x14096c174:raise RuntimeError(f'Unexpected Type4 attachment dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation,names
 c=case;calls=[];allocation=0;names={model:0,replacement:1};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,manager);m.wq(manager,manager+0x100)
 for ptr in[client,render]:m.wq(ptr,vt)
 for ptr in[host,model,replacement]:m.wq(ptr,modelvt)
 for off,target in[(0x18,0x10),(0x140,0x20),(0xa0,0x30),(0x28,0x40),(0x58,0x50)]:m.wq(vt+off,m.stop+target)
 for off,target in[(0x148,0x60),(0x140,0x70),(0x98,0x80)]:m.wq(modelvt+off,m.stop+target)
 writecs(first+0x1e0,c['prefixA']);writecs(second+0x1c8,c['prefixB']);m.wq(creature+0x30,context if c['context']else 0);m.wi(effect+0x54,123);m.wq(effect+0xb8,model if c['procedural']else 0)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect)
 try:u.emu_start(0x14096bbb0,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,procedural=names.get(m.q(effect+0xb8)))
def profile(**kw):
 c=dict(procedural=1,client=1,render=1,host=1,first=0,second=0,creature=1,selected=1,context=1,pose=1,replace=0,prefixA='placeable',prefixB='door');c.update(kw);return c
rows=[run(profile(first=first,second=second,creature=creature,selected=selected,context=context,pose=pose,replace=replace))for first,second,creature,selected,context,pose,replace in itertools.product([0,1],repeat=7)]
rows.extend(run(profile(**kw))for kw in[dict(procedural=0),dict(client=0),dict(render=0),dict(host=0),dict(creature=0,first=1,prefixA=''),dict(creature=0,second=1,prefixB='')])
out=m.root/'backups/animations/native-visual-type4-attachment-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
