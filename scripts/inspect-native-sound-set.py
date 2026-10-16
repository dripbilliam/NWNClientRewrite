"""Original CSoundSet::GetStrres1407d7ba0 and its actor demand/release
wrapper140801730, including real CResRef copy helpers. Resource data/demand,
string allocation, TLK fetch and warning are captured lower boundaries. Uses
synthetic SSF/TLK content, not proprietary resources or native audio playback.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,ssf,resource,blob,out,tlk,scratch=[m.heap+n*0x1000 for n in range(1,8)]
def string(ptr,text):
 u.mem_write(scratch,text.encode('ascii')+b'\0');m.wq(ptr,scratch);m.wi(ptr+8,len(text));m.wi(ptr+12,len(text)+1)
def readText(ptr):
 p=m.q(ptr);return bytes(u.mem_read(p,m.si(ptr+8))).split(b'\0')[0].decode('ascii') if p else ''
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x14018fc70:calls.append(['data']);m.finish(blob)
 elif a==0x14018f300:calls.append(['demand']);m.finish(blob if c.get('demand',True) else 0)
 elif a==0x1401912c0:calls.append(['release']);m.finish()
 elif a==0x14003d8c0:
  data=bytes(u.mem_read(y,z&0xffffffff));p=scratch+0x100;u.mem_write(p,data+b'\0');m.wq(x,p);m.wi(x+8,z);m.wi(x+12,z+1);m.finish(x)
 elif a==0x140198c60:
  calls.append(['tlk',y&0xffffffff,u.mem_read(tlk+0x28,1)[0],w]);string(z,'spoken caption');u.mem_write(z+0x10,b'tlk_voice\0'+bytes(7));m.finish(1)
 elif a==0x140115890:calls.append(['warning']);m.finish()
 elif a==0x140c10370:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1407d7ba0,0x1407d7cae),(0x140801730,0x1408017b9),(0x14018dea0,0x14018decc),(0x140190d30,0x140190dcd)]):raise AssertionError(f'Uncaptured SSF dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df968,tlk);u.mem_write(tlk+0x28,b'\x01');m.wq(ssf+8,resource);m.wq(actor+0x400,ssf if c.get('set',True) else 0);u.mem_write(actor+0x3b8,struct.pack('<H',c.get('setId',7)&65535))
 u.mem_write(blob,b'SSF V1.0');m.wi(blob+8,3);m.wi(blob+12,40);m.wi(blob+40,52);m.wi(blob+44,0);m.wi(blob+48,72)
 for off in [52,72]:u.mem_write(blob+off,c['resRef'].encode('ascii').ljust(16,b'\0'));m.wi(blob+off+16,c['strRef'])
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in [(UC_X86_REG_RCX,actor if c['operation']=='wrapper' else ssf),(UC_X86_REG_RDX,c['id']&65535),(UC_X86_REG_R8,out)]:u.reg_write(reg,v)
 u.emu_start(0x140801730 if c['operation']=='wrapper' else 0x1407d7ba0,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,text=readText(out),resRef=bytes(u.mem_read(out+0x10,17)).split(b'\0')[0].decode('ascii'),result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
rows=[run(dict(operation='entry',id=id,resRef=ref,strRef=sr)) for id,ref,sr in itertools.product([-1,0,1,2,3,65536],['','voice_cue','UPPER','abcdefghijklmnop'],[0xffffffff,42])]
rows += [run(dict(operation='wrapper',id=id,resRef='voice_cue',strRef=42,set=setExists,demand=demand,setId=setId)) for id,setExists,demand,setId in itertools.product([0,1,3],[False,True],[False,True],[7,65535])]
outpath=m.root/'backups/animations/native-sound-set-observations.json';outpath.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(outpath))))
