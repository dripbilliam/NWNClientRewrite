"""Original chooser admission/dedup, race-pass branch and medium suffix branch.
Unchanged pinned instructions in Unicorn. String/allocation/Exists boundaries
are captured; widget allocation is bypassed by an already-full24-widget pool.
No actual directory, resource payload, GUI or running original process is used.
"""
from pathlib import Path
import importlib.util,json,itertools
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('mapped',root/'scripts/inspect-native-intratile-coordinator.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel,refs,source,text=m.heap+0x8000,m.heap+0x9000,m.heap+0xa000,m.heap+0xa100
mode='admission'
def string(p):return bytes(u.mem_read(p,128)).split(b'\0',1)[0]
def write(p,s):u.mem_write(p,s[:16].ljust(17,b'\0'))
def hook(u,a,n,_):
 global allocated,branch
 if a==m.stop:u.emu_stop();return
 if mode=='race':
  if a in [0x1409d2114,0x1409d2259]:branch=a==0x1409d2114;u.emu_stop();return
  if not 0x1409d20f7<=a<0x1409d2114:raise RuntimeError(hex(a))
  return
 if mode=='suffix':
  if a in [0x1409d06f4,0x1409d07a6]:branch=a==0x1409d06f4;u.emu_stop();return
  if not 0x1409d06b4<=a<0x1409d06f4:raise RuntimeError(hex(a))
  return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x14084c170:write(x,b'');m.finish(x);return
 if a==0x14084c1a0:m.finish();return
 if a in [0x14018de80,0x14018ded0]:write(x,string(y));m.finish(x);return
 if a==0x14018dea0:write(x,string(m.q(y)));m.finish(x);return
 if a==0x14018df10:m.finish(int(string(x).lower()==string(y).lower()));return
 if a==0x14018e060:write(x,string(x)+string(m.q(y)));m.finish(x);return
 if a in [0x140c10370,0x140c10410]:m.finish();return
 if a==0x140c10368:allocated+=256;m.finish(m.heap+allocated);return
 if a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a==0x14018f590:
  ref=string(y).decode('ascii');calls.append([ref,z]);index='tsmlh'.find(ref[-1:].lower());mask=tga if z==3 else dds
  m.finish(int(index>=0 and bool(mask&(1<<index))));return
 if not(0x1409d0cd0<=a<=0x1409d0f3d or 0x14084c1b0<=a<=0x14084c2e7 or 0x14084c2f0<=a<=0x14084c54a):raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
admission=[]
for tga,dds,duplicate in itertools.product(range(32),range(32),[False,True]):
 allocated=0x10000;calls=[];u.mem_write(panel,bytes(0x500));m.wq(panel+0x408,refs);m.wi(panel+0x410,int(duplicate));m.wi(panel+0x414,16);m.wi(panel+0x4c0,24);write(refs,b'portrait_' if duplicate else b'')
 write(text,b'portrait_');m.wq(source,text);m.wi(source+8,9)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,panel);u.reg_write(UC_X86_REG_RDX,source)
 u.emu_start(0x1409d0cd0,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 admission.append(dict(tgaMask=tga,ddsMask=dds,duplicate=duplicate,added=m.si(panel+0x410)-int(duplicate),calls=calls))
mode='race';race=[]
for selected,value,pass_index in itertools.product([-1,0,5,65535],[-1,0,5,65535],[0,1]):
 frame=m.heap+0xb000;rsp=m.stack+0x1f000;m.wi(frame-0x4c,selected);m.wi(rsp+0x38,value);u.reg_write(UC_X86_REG_RBP,frame);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_R12,pass_index)
 u.emu_start(0x1409d20f7,0x1409d225a,count=16)
 race.append(dict(selected=selected,value=value,passIndex=pass_index,admitted=branch))
mode='suffix';suffix=[]
for value in range(256):
 raw=b'p'+bytes([value])+b'.tga';u.mem_write(text,raw+b'\0');m.wq(source,text);m.wi(source+8,len(raw));u.reg_write(UC_X86_REG_R10,source);u.reg_write(UC_X86_REG_RSI,0)
 u.emu_start(0x1409d06b4,0x1409d07a7,count=40);suffix.append(dict(byte=value,admitted=branch))
assert [r['byte'] for r in suffix if r['admitted']]==[77,109]
out=dict(target=m.digest,scope=__doc__,entry='0x1409d0cd0',sizeCall='0x1409d0d43',existsCalls=['0x1409d0d5c','0x1409d0d79'],raceBranch='0x1409d20f7..0x1409d2114',suffixBranch='0x1409d06b4..0x1409d06f4',admission=admission,race=race,suffix=suffix)
(root/'backups/animations/native-portrait-chooser-v1.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(dict(admissionCases=len(admission),raceCases=len(race),suffixCases=len(suffix),target=m.digest)))
