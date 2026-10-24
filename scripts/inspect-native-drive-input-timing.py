"""Unchanged original6f1e40 held-key scheduling and sequence publication.

Timer, controlled-object lookup, outgoing requests and local preview are
captured lower providers. Heading transcendental functions use explicit host
math; this is a scheduling/sequence oracle, not a bit-exact trig oracle or
complete native input event-loop/OS-key-repeat test. No live process writes.
"""
import sys,importlib,json,struct,math,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-drive-preview');u=p.u;m=p.m;w=p.w
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(p.hook_handle)
vt,settings,timer=m.heap+0x90000,m.heap+0x91000,m.heap+0x92000
def xd(reg):return struct.unpack('<d',u.reg_read(reg).to_bytes(16,'little')[:8])[0]
def rd(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<d',value),'little'));m.finish()
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14016dd30:m.finish(now);return
 if a==0x1407bf980:calls.append(dict(kind='drive',heading=k&65535,sequence=u.mem_read(sp+0x28,1)[0],flags=u.mem_read(sp+0x30,1)[0]));m.finish(1);return
 if a==0x1406ea9e0:calls.append(dict(kind='preview',flags=y&255,sequenceBefore=u.mem_read(p.obj+0x2d3,1)[0]));m.finish(1);return
 if a==0x1407c03b0:calls.append(dict(kind='turn'));m.finish(1);return
 if a==0x1406d8ad0:m.finish();return
 if a==0x1406d82f0:m.finish(0);return
 if a==0x1407bf040:calls.append(dict(kind='abort'));m.finish(1);return
 if a==0x140a6f930:m.finish();return # observed GUI event copy, not an input filter
 if a==0x14016fc30:calls.append(dict(kind='queued',inputClass=y,key=z,value=k));m.finish();return
 if a==0x140cae8e0:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if a==m.stop+0x120:p.put(p.obj+0x44,p.vec(y));m.finish();return
 if a==0x140c93af8:rd(math.atan2(xd(UC_X86_REG_XMM0),xd(UC_X86_REG_XMM1)));return
 if a==0x140c87b10:rd(math.floor(xd(UC_X86_REG_XMM0)+.5));return
 if a==0x140c79d30:rd(math.cos(xd(UC_X86_REG_XMM0)));return
 if a==0x140c92d20:rd(math.sin(xd(UC_X86_REG_XMM0)));return
 if 0x1406f1e40<=a<0x1406f2829:return
 if 0x14016f880<=a<0x14016fc2f or 0x1406ed720<=a<0x1406ef758:return
 p.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for flags,dirty,lastSequence,wireAgo,previewAgo in itertools.product([3,4,8,20],[0,1],[36,255],[0,100000,499999,500000],[0,249999,250000]):
 c=dict(flags=flags,dirty=dirty,lastSequence=lastSequence,wireAgo=wireAgo,previewAgo=previewAgo);calls=[];now=10000000;p.t.reset(dict(format=1))
 m.wq(0x1412df8b8,p.owner);m.wq(p.owner+0x10,timer);m.wq(w.app,p.owner);m.wq(p.ui,settings);m.wq(p.obj,vt);m.wq(vt+0x120,m.stop+0x120)
 m.wq(p.obj+0x30,p.area);m.wi(p.area+0x118,0x80000001);u.mem_write(p.obj+0x37c,b'\2');m.wi(p.obj+0x41c,1);p.put(p.obj+0x44,[1,0,0]);p.put(p.obj+0x38,[10,20,0]);u.mem_write(p.obj+0x2d2,bytes([lastSequence]));u.mem_write(p.obj+0x2d3,bytes([lastSequence]));m.wi(p.ui+0x1b0,dirty);m.wq(p.ui+0x1a0,now-wireAgo);m.wq(p.ui+0x198,now-previewAgo)
 for off,bit in[(0x1b8,3),(0x1c8,4),(0x1cc,8),(0x1c0,16)]:m.wi(p.ui+off,int((flags&bit)==bit))
 try:w.call(0x1406f1e40,[p.ui])
 except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 rows.append(dict(case=c,calls=calls,sequence=u.mem_read(p.obj+0x2d3,1)[0],lastWire=m.q(p.ui+0x1a0),lastPreview=m.q(p.ui+0x198),dirty=m.si(p.ui+0x1b0)))
events=[];sdl=m.heap+0x93000;inputOwner=m.heap+0x94000
mapping=bytes(u.mem_read(0x1406ef758,0x73));key=next(i for i,v in enumerate(mapping)if v==0x28)
for repeat in[0,1]:
 now=10000000;calls=[];p.t.reset(dict(format=1));m.wq(0x1412df8b8,p.owner);m.wq(p.owner+0x10,timer);m.wq(w.app,p.owner);m.wq(p.ui,settings);m.wq(p.obj,vt);m.wq(vt+0x120,m.stop+0x120)
 m.wq(p.obj+0x30,p.area);m.wi(p.area+0x118,0x80000001);u.mem_write(p.obj+0x37c,b'\2');m.wi(p.obj+0x41c,1);p.put(p.obj+0x44,[1,0,0]);p.put(p.obj+0x38,[10,20,0]);u.mem_write(p.obj+0x2d2,b'\x24');u.mem_write(p.obj+0x2d3,b'\x24');m.wq(p.ui+0x1a0,now);m.wq(p.ui+0x198,now);m.wi(p.ui+0x1c8,1)
 for i in range(96):m.wi(inputOwner+0x80+i*4,0xffffffff)
 m.wi(inputOwner+0x80,20);m.wi(sdl,0x300);u.mem_write(sdl+12,bytes([1,repeat]));m.wi(sdl+16,20);m.wi(sdl+20,ord('q'))
 w.call(0x14016f880,[inputOwner,sdl]);queued=calls[:];calls=[];m.wi(m.stack+0x1fe08+0x28,0);w.call(0x1406ed720,[p.ui,key,1,0]);dirty=m.si(p.ui+0x1b0);w.call(0x1406f1e40,[p.ui]);events.append(dict(repeat=repeat,key=key,queued=queued,dirtyAfterEvent=dirty,calls=calls,sequence=u.mem_read(p.obj+0x2d3,1)[0]))
out=m.root/'backups/animations/native-drive-input-timing-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__+' Repeated SDL_KEYDOWN and existing held-key GUI events also execute original16f880/6ed720; typed queue insertion, inactive-modal lookup and GUI-copy are captured. Descriptor binding is synthetic; this is not a physical OS-repeat trace.',cases=rows,repeatedEvents=events),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),repeatedEvents=len(events),output=str(out))))
