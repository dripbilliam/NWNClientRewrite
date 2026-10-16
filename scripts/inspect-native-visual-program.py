"""Complete native LoadProgram14096c8e0, Clear140971960, resource cleanup
1409719c0 and Update dispatcher140972090. Type/table/model/client, lower Type5/6
updates, CString/heap and virtual callbacks are synthetic explicit providers.
Verifies owner results/order/state/aliases/live reads, not lower renderer.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,manager,app,rules,client,render,vt=[m.heap+n*0x1000 for n in range(7)]
def string(ptr):
 if not ptr:return ''
 raw=bytearray()
 while u.mem_read(ptr+len(raw),1)[0]:raw.append(u.mem_read(ptr+len(raw),1)[0])
 return raw.decode('ascii')
def cs(ptr):return string(m.q(ptr))
def allocate(size):
 global allocation
 ptr=m.heap+0x80000+allocation*0x100;allocation+=1;return ptr
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140c10370:m.finish()
 elif a==0x140c10368:m.finish(allocate(x))
 elif a==0x14096c340:calls.append(['programType',y&65535]);m.finish(c['type'])
 elif a==0x1406abb60:calls.append(['client',y&0xffffffff]);m.finish(client if c['client']else 0)
 elif a==m.stop+0x10:calls.append(['render']);m.finish(render if c['render']else 0)
 elif a in[0x1401a68f0,0x1401a6c70]:
  column=cs(z);calls.append(['string'if a==0x1401a68f0 else'float',y&65535,column])
  if a==0x1401a68f0:
   value=c['string'];ptr=allocate(len(value)+1);u.mem_write(ptr,value.encode()+b'\0');m.wq(w,ptr);m.wi(w+8,len(value))
  else:m.wf(w,c['float'])
  m.finish(c['found'])
 elif a==0x1400931f0:calls.append(['load',string(x),string(y),z&0xffffffff]);m.finish(models[7]if c['load']else 0)
 elif a==m.stop+0x20:
  calls.append(['parent',names[x],y,z,w])
  if c['mutate']=='parent':m.wq(effect+0xb8,models[7])
  m.finish()
 elif a==m.stop+0x30:
  calls.append(['scene',names[x],y])
  if c['mutate']=='scene':m.wq(effect+0xb8,0)
  m.finish()
 elif a==m.stop+0x40:
  calls.append(['destroy',names[x],y&0xffffffff])
  if c['mutate']=='destroy'and x==models[0]:m.wq(effect+0xa0,0)
  m.finish()
 elif a==m.stop+0x50:
  calls.append(['setting',names[x],y&0xffffffff])
  if c['mutate']=='setting':m.wq(effect+0xb8,0)
  m.finish()
 elif a in[0x140971e10,0x1409720e0]:calls.append([f'update{a:x}',y&0xffffffff]);m.finish()
 elif not any(lo<=a<hi for lo,hi in[(0x14096c8e0,0x14096ccb0),(0x140971960,0x1409719bf),(0x1409719c0,0x140971a76),(0x140972090,0x1409720db)]):raise RuntimeError(f'Unexpected program dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation,models,names
 c=case;calls=[];allocation=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,manager);m.wq(manager,manager+0x100);m.wq(0x1412df8f8,app);m.wq(app+0x130,rules);m.wq(rules+0x270,rules+0x500)
 for ptr in[client,render]:m.wq(ptr,vt)
 for off,target in[(0x18,0x10),(0x98,0x20),(0x90,0x30),(0,0x40),(0x1a0,0x50)]:m.wq(vt+off,m.stop+target)
 models=[m.heap+0x10000+i*0x1000 for i in range(8)];names={ptr:i for i,ptr in enumerate(models)}
 for ptr in models:m.wq(ptr,vt)
 m.wi(effect+0x54,123);m.wf(effect+0x104,9.25);m.wq(effect+0xb8,models[6]if c['old']else 0)
 for i in range(3):m.wq(effect+0x88+i*8,models[i]if c['models']else 0);m.wq(effect+0xa0+i*8,(models[i]if c['alias']else models[i+3])if c['extra']else 0)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,c['id']);u.reg_write(UC_X86_REG_R8,c['delta']);address={'load':0x14096c8e0,'clear':0x140971960,'cleanup':0x1409719c0,'update':0x140972090}[c['mode']]
 try:u.emu_start(address,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=(u.reg_read(UC_X86_REG_RAX)&0xffffffff)if c['mode']=='load'else None,procedural=names.get(m.q(effect+0xb8)),field104=m.rf(effect+0x104),models=[names.get(m.q(effect+0x88+i*8))for i in range(3)],extra=[names.get(m.q(effect+0xa0+i*8))for i in range(3)])
def profile(**kw):
 c=dict(mode='load',type=4,id=302,delta=100,client=1,render=1,old=0,load=1,found=1,string='custom_model',float=.75,mutate='',models=0,extra=0,alias=0);c.update(kw);return c
rows=[run(profile(type=type,client=client,render=render,old=old,load=load,found=found,string=text))for type,client,render,old,load,found,text in itertools.product([0,1,4,5,6,7,12,13],[0,1],[0,1],[0,1],[0,1],[0,1],['','custom_model'])]
rows.extend(run(profile(mode=mode,old=old,models=models,extra=extra,alias=alias,mutate=mutate))for mode,old,models,extra,alias,mutate in itertools.product(['clear','cleanup'],[0,1],[0,1],[0,1],[0,1],['','parent','scene','destroy']))
rows.extend(run(profile(mode='update',type=type,id=id,delta=delta))for type,id,delta in itertools.product(range(15),[302,65535],[0,100,0xffffffff]))
rows.extend(run(profile(type=7,mutate='setting'))for _ in range(1))
out=m.root/'backups/animations/native-visual-program-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
