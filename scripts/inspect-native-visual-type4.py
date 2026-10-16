"""Complete unchanged Type4 start14096a570..14096a996 and stop14096fe00..
14096ffc5. Explicit
table/client/view/GUI/animation/shadow/model-setting and attachment responses;
verifies owner state/order and live procedural-pointer reads, not lower rendering.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,manager,app,rules,client,render,context,other,controlled,video,gui,vt,model,replacement=[m.heap+n*0x1000 for n in range(14)]
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
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10370:m.finish()
 elif a==0x140c10368:m.finish(allocate(x))
 elif a in [0x1401a68f0,0x1401a6c70,0x1401a7010]:
  column=cs(z);calls.append([{0x1401a68f0:'string',0x1401a6c70:'float',0x1401a7010:'integer'}[a],y&65535,column]);value=c['values'][column]
  if a==0x1401a68f0:ptr=allocate(len(value)+1);u.mem_write(ptr,value.encode()+b'\0');m.wq(w,ptr);m.wi(w+8,len(value))
  elif a==0x1401a6c70:m.wf(w,value)
  else:m.wi(w,value)
  m.finish(c['found'])
 elif a==0x1406abb60:calls.append(['client',y&0xffffffff]);m.finish(client if c['client']else 0)
 elif a==m.stop+0x10:calls.append(['render']);m.finish(render if c['render']else 0)
 elif a==m.stop+0x20:calls.append(['view58']);m.finish(context if c['creature']else 0)
 elif a==0x1406ac1a0:calls.append(['view1406ac1a0']);m.finish([0,context,other][c['selected']])
 elif a==0x1406abea0:calls.append(['controlledClient']);m.finish(controlled)
 elif a==m.stop+0x30:calls.append(['registerGuiD8',names.get(y)]);m.finish()
 elif a==0x14096bbb0:
  calls.append(['programAttach14096bbb0'])
  if c['replace']:m.wq(effect+0xb8,replacement)
  m.finish()
 elif a==m.stop+0x40:calls.append(['playAnimation',names[x],string(y),m.xmm(UC_X86_REG_XMM2),w&0xffffffff,m.rf(rsp+0x28)]);m.finish()
 elif a in [0x1400c57d0,0x1400c57b0]:calls.append(['shadowing',names[x],a==0x1400c57d0]);m.finish()
 elif a==m.stop+0x50:calls.append(['modelSetting1a0',names[x],y&0xffffffff]);m.finish()
 elif a==m.stop+0x60:
  calls.append(['parent',names[x],y,z,w])
  if c['replace']:m.wq(effect+0xb8,replacement)
  m.finish()
 elif a==m.stop+0x70:calls.append(['scene',names[x],y]);m.finish()
 elif a==0x1407e9bc0:calls.append(['refreshContext1407e9bc0']);m.finish()
 elif not(0x14096a570<=a<0x14096a996 or 0x14096fe00<=a<0x14096ffc5):raise RuntimeError(f'Unexpected Type4 lifecycle dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation,names
 c=case;calls=[];allocation=0;names={model:0,replacement:1};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,manager);m.wq(manager,manager+0x100);m.wq(0x1412df8f8,app);m.wq(app+0x130,rules);m.wq(rules+0x270,rules+0x500)
 for ptr in[client,render,gui,model,replacement]:m.wq(ptr,vt)
 for off,target in[(0x18,0x10),(0x58,0x20),(0xd8,0x30),(0x30,0x40),(0x1a0,0x50),(0x98,0x60),(0x90,0x70)]:m.wq(vt+off,m.stop+target)
 m.wq(controlled+0xf8,video if c['video']else 0);m.wq(video+0x248,gui);m.wi(effect+0x54,123);m.wq(effect+0xb8,model if c['procedural']else 0);m.wi(effect+0x110,7);m.wi(effect+0x108,9);u.mem_write(effect+0x10c,b'\x08')
 m.wi(effect+0x114,c['attached']);m.wq(context+0x30,app if c['context']else 0);m.wi(context+8,123);m.wi(other+8,789)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,302)
 try:u.emu_start(0x14096fe00 if c['mode']=='stop'else 0x14096a570,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,field110=m.si(effect+0x110),scope=u.mem_read(effect+0x10c,1)[0],shadow=m.si(effect+0x108),procedural=names.get(m.q(effect+0xb8)))
def profile(**kw):
 c=dict(mode='start',attached=0,context=0,procedural=1,client=1,render=1,creature=1,selected=1,video=1,replace=0,found=1,values=dict(param1='White_15m',param2=1,param3=1,param4=20,param5=0,param6=0));c.update(kw);return c
rows=[run(profile(creature=creature,selected=selected,video=video,replace=replace,found=found,values=dict(param1='White_15m',param2=speed,param3=shadow,param4=276,param5=-7,param6=gui)))for creature,selected,video,replace,found,speed,shadow,gui in itertools.product([0,1],range(3),[0,1],[0,1],[0,1],[1,-.31],[0,1],[0,1])]
rows.extend(run(profile(**kw))for kw in [dict(procedural=0),dict(client=0),dict(render=0),dict(values=dict(param1='',param2=0,param3=-1,param4=-1,param5=0,param6=-1))])
rows.extend(run(profile(mode='stop',procedural=proc,client=client,render=render,creature=creature,selected=selected,video=video,attached=attached,context=context,values=dict(param6=gui)))for proc,client,render,creature,selected,video,attached,context,gui in itertools.product([0,1],[0,1],[0,1],[0,1],range(3),[0,1],[0,1],[0,1],[0,1]))
rows.extend(run(profile(mode='stop',replace=replace,found=0,attached=1,context=1,values=dict(param6=1)))for replace in[0,1])
out=m.root/'backups/animations/native-visual-type4-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
