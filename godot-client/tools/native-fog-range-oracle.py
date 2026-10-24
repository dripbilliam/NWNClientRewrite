"""Execute original fog-range block1407d0197..1407d029b in isolated Unicorn.
Camera distance/settings access and scene/camera setters are explicit stubs.
This is a bounded numeric block, not complete module update or GPU fog parity.
Original binary/processes/Ghidra stay read-only; no network or art copies.
"""
import sys,importlib,struct,json,itertools
from pathlib import Path
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'scripts'))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
module,camera,area,scene,vt,svt,settings,app=[m.heap+n*0x1000 for n in range(8)]
result={};case={}
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def hook(u,a,n,data):
 if a==0x1407d02e5:u.emu_stop();return
 if a==m.stop+0xc0:
  u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',case['distance']),'little'));m.finish();return
 if a==m.stop+0x88:result['start']=xmm(UC_X86_REG_XMM1);result['end']=xmm(UC_X86_REG_XMM2);m.finish();return
 if a==m.stop+0x80:result['near']=xmm(UC_X86_REG_XMM1);result['far']=xmm(UC_X86_REG_XMM2);m.finish();return
 if a==0x1406ab9b0:m.finish(settings);return
 if 0x1407d0197<=a<0x1407d029d:return
 raise RuntimeError('Unexpected native fog dependency '+hex(a))
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for near,clip,distance,amount,skybox,show_sky in itertools.product([.1,1,45],[0,.1,10,45,120],[0,1,20,100],[0,1,25,100,255],[0,1],[0,1]):
 case=dict(near=near,clip=clip,distance=distance,amount=amount,skybox=skybox,showSky=show_sky);result={}
 u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x10000
 m.wq(module+0xf8,area);m.wq(module+0xe8,camera);m.wq(area+0x248,scene);m.wf(area+0x108,clip);m.wf(area+0x310,amount);u.mem_write(area+0xe0,bytes([skybox]));m.wi(settings+0x68,show_sky)
 m.wq(camera,vt);m.wq(vt+0xc0,m.stop+0xc0);m.wq(vt+0x80,m.stop+0x80);m.wq(scene,svt);m.wq(svt+0x88,m.stop+0x88);m.wq(0x1412df970,app);m.wq(app,app)
 m.wf(rsp+0x24,near);m.wf(rsp+0x30,200);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rsp+0x100);u.reg_write(UC_X86_REG_RSI,module)
 u.emu_start(0x1407d0197,0x1407d02e5,count=300);assert u.reg_read(UC_X86_REG_RIP)==0x1407d02e5 and len(result)==4
 rows.append(dict(case=case,expected=result,expectedBits={key:struct.pack('<f',value).hex() for key,value in result.items()}))
out=Path(sys.argv[1]);assert not out.exists();out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,block=['0x1407d0197','0x1407d029b'],constants={hex(a):m.rf(a) for a in [0x140d81924,0x140d8216c,0x140e45110,0x140d82174,0x140d8f7dc]},rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
