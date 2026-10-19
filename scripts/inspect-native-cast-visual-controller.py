"""Original client cast visuals98b130/98b450, cleanup98b9f0/98baa0,
timer98bb50, callback98b100 and creature driver8018d0. Actual control flow and
field accesses execute. Model allocation/virtual graph/playback, sound, strings,
spell lookup and CRT allocation are captured lower boundaries, not GPU evidence.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
controller,actor,vt,spell,rules,parts,appearance=[m.heap+n*0x1000 for n in range(1,8)]
create,attach,play,listen,source,poseFn,destroy=[m.stop+0x10+n*0x10 for n in range(7)]
ranges=[(0x14098b0a0,0x14098b0c9),(0x14098b0d0,0x14098b0f7),(0x14098b100,0x14098b12f),(0x14098b130,0x14098b44a),(0x14098b450,0x14098b9ba),(0x14098b9f0,0x14098ba9e),(0x14098baa0,0x14098bb4b),(0x14098bb50,0x14098bc97),(0x1408018d0,0x140801c00)]
def string(p):return bytes(u.mem_read(p,256)).split(b'\0')[0].decode('ascii') if p else None
def name(p):return names.get(p,'unknown') if p else None
def vector(p):return [m.rf(p+n*4)for n in range(3)]
def hook(u,a,n,_):
 global allocated,created
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1400931f0:
  index=created;created+=1;resource=string(x);category=string(y);ok=not(c.get('fail',0)&(1<<index));p=m.heap+0x20000+index*0x100 if ok else 0
  calls.append(['create',resource,category]);
  if p:m.wq(p,vt);names[p]='new'+str(index)
  m.finish(p)
 elif a==source:calls.append(['source',y&255,z&0xffffffff]);m.finish(parts if c.get('model',1)else 0)
 elif a==attach:
  calls.append(['attach',name(x),name(y),string(z),w&0xffffffff])
  if c.get('detachNull') and y==0:
   for off in range(0,0x30,8):
    if m.q(controller+off)==x:m.wq(controller+off,0)
  m.finish()
 elif a==play:calls.append(['play',name(x),string(y),u.reg_read(UC_X86_REG_XMM2)&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.finish(c.get('play',0))
 elif a==listen:assert y==0x14098b100;calls.append(['listen',name(x),string(z),name(w)]);m.finish()
 elif a==poseFn:
  calls.append(['pose',name(x),string(y)]);
  if c.get('pose',1):
   for i,v in enumerate([7,8,9]):m.wf(z+i*4,v)
  m.finish(c.get('pose',1))
 elif a==destroy:calls.append(['destroy',name(x),y&0xffffffff]);m.finish()
 elif a==0x1401d9c40:calls.append(['sound',string(y),vector(z),u.reg_read(UC_X86_REG_XMM3)&0xffffffff,m.si(rsp+0x28),m.si(rsp+0x30),m.si(rsp+0x38)]);m.finish()
 elif a==0x1402af4a0:calls.append(['spell',y&0xffffffff]);m.finish(spell if c.get('spell',1)else 0)
 elif a in [0x14018de80,0x14018ded0]:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x)
 elif a==0x140c10368:p=m.heap+0x30000+allocated*0x100;allocated+=1;m.finish(p)
 elif a==0x140c10370:m.finish()
 elif a==0x140c417f0:u.mem_write(x,string(y).encode()+b'\0');m.finish(x)
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unexpected cast visual dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def state():return dict(conjure=[name(m.q(controller+i*8))for i in range(3)],cast=[name(m.q(controller+0x18+i*8))for i in range(3)],conjureTime=m.si(controller+0x30)&0xffffffff,castTime=m.si(controller+0x34)&0xffffffff,released=m.si(controller+0x38),done=[m.si(controller+0x3c+i*4)for i in range(3)])
def run(case):
 global c,calls,names,allocated,created
 c=case;calls=[];names={actor:'actor',parts:'source',controller:'controller'};allocated=created=0;u.mem_write(m.heap,bytes(0x50000));m.wq(actor,vt);m.wq(vt+0x140,source);m.wq(vt+0x138,poseFn);m.wq(vt, destroy);m.wq(vt+0x98,attach);m.wq(vt+0x30,play);m.wq(vt+0x50,listen)
 m.wq(parts,vt)
 for i in range(6):
  p=m.heap+0x10000+i*0x100;names[p]='old'+str(i);m.wq(p,vt);m.wq(controller+i*8,(m.heap+0x10000 if c.get('alias') and i<3 else p)if c.get('slots',0)&(1<<i)else 0)
 for i,v in enumerate(c.get('timers',[0,0,0])):m.wi(controller+0x30+i*4,v)
 for i,v in enumerate(c.get('done',[0,0,0])):m.wi(controller+0x3c+i*4,v)
 refs=c.get('refs',['head','hand','ground']);texts=refs+c.get('sounds',['male','generic']);pointers=[]
 for i,t in enumerate(texts):p=m.heap+0x40000+i*0x100;u.mem_write(p,t.encode()+b'\0');pointers.append(p)
 m.wq(actor+0x3a0,controller);m.wq(actor+0x3b0,appearance);m.wq(actor+0x300,appearance);u.mem_write(appearance+0x50,struct.pack('<H',c.get('soundSet',0)&65535));u.mem_write(appearance+0xd0,bytes([c.get('female',0)]));m.wi(actor+0x36c,42);m.wi(actor+0x368,c.get('previous',0));m.wi(actor+0x374,c.get('suppress',0));m.wi(actor+0x58,c.get('elapsed',0));u.mem_write(actor+0x5c,struct.pack('<H',c.get('animation',15)&65535));
 for i,v in enumerate([1,2,3]):m.wf(actor+0x38+i*4,v)
 m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,spell)
 for off,t in zip([0x76,0x87,0x98,0xa9,0xba,0xcb],refs+['male','female','generic']):u.mem_write(spell+off,t.encode()+b'\0')
 op=c['op'];args=[controller,*pointers[:3]];extras=[actor];entry=0x14098b130
 if op=='start':entry=0x14098b450;extras=[pointers[3],pointers[4],actor]
 elif op=='tick':entry=0x14098bb50;args=[controller,c['elapsed'],0,0];extras=[]
 elif op=='clear':entry=0x14098b9f0 if c['group']=='cast'else 0x14098baa0;args=[controller,0,0,0];extras=[]
 elif op=='callback':entry=0x14098b100;args=[m.heap+0x10000+c['which']*0x100,0,controller if c.get('context',1)else 0,0];extras=[]
 elif op=='driver':entry=0x1408018d0;args=[actor,0,0,0];extras=[]
 elif op=='ctor':entry=0x14098b0a0;args=[controller,0,0,0];extras=[]
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop)
 for i,v in enumerate(extras):m.wq(rsp+0x28+i*8,v)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,v)
 u.reg_write(UC_X86_REG_RSP,rsp)
 try:u.emu_start(entry,m.stop,count=15000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,state=state(),calls=calls,previous=m.si(actor+0x368),spellId=m.si(actor+0x36c),suppress=m.si(actor+0x374))
rows=[]
for mask,fail,slots in itertools.product(range(8),range(8),[0,7,63]):rows.append(run(dict(op='release',refs=[s if mask&(1<<i)else ''for i,s in enumerate(['head','hand','ground'])],fail=fail,slots=slots)))
for mask,fail,model,pose,sounds in itertools.product(range(8),[0,1,7],[0,1],[0,1],[['',''],['male','generic']]):rows.append(run(dict(op='start',refs=[s if mask&(1<<i)else ''for i,s in enumerate(['head','hand','ground'])],fail=fail,model=model,pose=pose,sounds=sounds,done=[2,-1,1])))
for timers,elapsed,done,detach in itertools.product([[0,0,0],[1,5,0],[0,0,1],[5,5,1],[0,5,1],[0xffffffff,1,2],[1,0,1]], [0,1,4,5,6,0xffffffff],[[0,0,0],[1,0,2]],[0,1]):rows.append(run(dict(op='tick',timers=timers,elapsed=elapsed,done=done,slots=63,detachNull=detach)))
for animation,previous,released,spellOk,suppress,soundSet,female in itertools.product([1,14,15,16,17,20,21,61,89,96,249,250,253,254,261,65551],[0,1,2],[0,1],[0,1],[0,1],[-1,0,6,7],[0,1]):rows.append(run(dict(op='driver',animation=animation,previous=previous,timers=[2,3,released],spell=spellOk,suppress=suppress,soundSet=soundSet,female=female,slots=63,elapsed=2)))
for group,detach in itertools.product(['cast','conjure'],[0,1]):rows.append(run(dict(op='clear',group=group,slots=63,detachNull=detach)))
for which,context in itertools.product(range(7),[0,1]):rows.append(run(dict(op='callback',which=which,context=context,slots=63)))
rows.append(run(dict(op='callback',which=0,context=1,slots=63,alias=1)))
rows.append(run(dict(op='ctor',slots=63,timers=[1,2,3],done=[1,2,3])))
out=m.root/'backups/animations/native-cast-visual-controller-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
