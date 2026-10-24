"""Original image-button render callback95c800, synthetic dynamic image/rect.
Image resource, dynamic-value lookups and final Nuklear button are captured
providers. Original positive-extent gate and pixel-to-uint16 casts execute.
No game launch, source asset copy or server connection.
"""
import importlib.util,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
owner,widget,context,image,region,handle=[m.heap+n*0x1000 for n in range(1,7)]
def hook(u,a,n,_):
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop:u.emu_stop();return
 if a==0x14074f6b0:m.finish(handle);return
 if a==0x140a93db0:m.finish(image);return
 if a==0x14074f390:m.finish(region);return
 if a==0x140a942c0:m.finish(256);return
 if a==0x140a93d20:m.finish(512);return
 if a==0x140a76930:outputs.append(list(struct.unpack('<HHHHHH',u.mem_read(y+8,12))));m.finish(0);return
 if 0x14095c800<=a<=0x14095c9c0:return
 raise RuntimeError(f'Unmodeled image callback dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for rect in [[0,0,0,0],[0,0,1,1],[32,64,32,32],[1.9,2.9,7.9,8.9],[-1,-2,64,32],[0,0,-1,32],[0,0,32,0],[65537,65538,65539,65540]]:
 outputs=[];u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(widget,widget);m.wq(context,context);m.wq(handle,image)
 u.mem_write(image,struct.pack('<QHHHHHHI',1234,512,256,0,0,512,256,0));u.mem_write(region,struct.pack('<ffff',*rect))
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[owner,widget,context]):u.reg_write(r,v)
 u.emu_start(0x14095c800,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;assert len(outputs)==1
 rows.append(dict(rect=rect,image=outputs[0]))
out=m.root/'backups/animations/native-nui-image-region-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
