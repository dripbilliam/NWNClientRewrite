"""Original6f1e40 input position sampling with distinct rendered/predicted poses.
Timer, lookup, preview/send and trig boundaries are captured. The coordinator
order is separate static evidence, not executed by this input-field oracle.
"""
import sys,importlib,json,struct,math,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-drive-preview');w=p.w;m=p.m;u=p.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(p.hook_handle);vt,settings,timer=m.heap+0x90000,m.heap+0x91000,m.heap+0x92000
def xd(reg):return struct.unpack('<d',u.reg_read(reg).to_bytes(16,'little')[:8])[0]
def rd(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<d',value),'little'));m.finish()
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x14016dd30:m.finish(10000000);return
 if a==0x1407bf980:calls.append(dict(kind='drive',position=[m.rf(y),m.rf(y+4)],heading=k&65535));m.finish(1);return
 if a==0x1406ea9e0:calls.append(dict(kind='preview',flags=y&255));m.finish(1);return
 if a==0x1407c03b0:calls.append(dict(kind='turn'));m.finish(1);return
 if a in[0x1406d8ad0,0x1407bf040]:m.finish();return
 if a==m.stop+0x120:p.put(p.obj+0x44,p.vec(y));m.finish();return
 if a==0x140c93af8:rd(math.atan2(xd(UC_X86_REG_XMM0),xd(UC_X86_REG_XMM1)));return
 if a==0x140c87b10:rd(math.floor(xd(UC_X86_REG_XMM0)+.5));return
 if a==0x140c79d30:rd(math.cos(xd(UC_X86_REG_XMM0)));return
 if a==0x140c92d20:rd(math.sin(xd(UC_X86_REG_XMM0)));return
 if 0x1406f1e40<=a<0x1406f2829:return
 p.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for flags,render,predicted in itertools.product([3,4,8,20],[[10,20,0],[1.5,-7.25,0]],[[10.4,20.5,0],[6.5,4.25,0]]):
 p.t.reset(dict(format=1));calls=[];u.mem_write(p.ui,bytes(0x400));u.mem_write(p.obj,bytes(0x500))
 m.wq(0x1412df8b8,p.owner);m.wq(p.owner+0x10,timer);m.wq(w.app,p.owner);m.wq(p.ui,settings);m.wq(p.obj,vt);m.wq(vt+0x120,m.stop+0x120)
 m.wq(p.obj+0x30,p.area);m.wi(p.area+0x118,0x80000001);u.mem_write(p.obj+0x37c,b'\2');m.wi(p.obj+0x41c,1);p.put(p.obj+0x44,[1,0,0]);p.put(p.obj+0x38,render);p.put(p.obj+0x2c0,predicted);m.wi(p.ui+0x1b0,1);m.wq(p.ui+0x1a0,0);m.wq(p.ui+0x198,0)
 for off,bit in[(0x1b8,3),(0x1c8,4),(0x1cc,8),(0x1c0,16)]:m.wi(p.ui+off,int((flags&bit)==bit))
 w.call(0x1406f1e40,[p.ui]);rows.append(dict(flags=flags,render=render,predicted=predicted,calls=calls))
out=dict(target=m.digest,scope=__doc__,cases=rows)
(m.root/'backups/animations/native-frame-input-origin-v1.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
