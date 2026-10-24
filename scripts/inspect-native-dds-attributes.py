"""Read-only original CResDDS header admission/attribute methods.
Synthetic legacy and standard DXT1/DXT5 headers; no decompression or GL draw.
"""
from pathlib import Path
import importlib.util,json,struct,itertools
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('mapped',root/'scripts/inspect-native-intratile-coordinator.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);obj,header,out=m.heap+0x8000,m.heap+0x9000,m.heap+0xa000
ranges=[]
for file in['rea-ui-dds-service-v1.json','rea-ui-dds-native-attrib-v1.json']:
 report=json.loads((root/'backups/animations'/file).read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16))for r in report['procedure']['body']['ranges'])
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if not any(start<=a<=end for start,end in ranges):raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
def run(address,args):
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 for i,value in enumerate(args[4:]):m.wq(rsp+0x28+i*8,value)
 u.emu_start(address,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)&0xffffffff
cases=[]
for standard,width,height,marker in itertools.product([False,True],[1,2,3,4,7,64,209,512],[1,3,4,17,100,273],[3,4]):
 u.mem_write(obj,bytes(0x80));u.mem_write(header,bytes(128));u.mem_write(out,bytes(64));m.wq(obj+0x20,header)
 size=((width+3)//4)*((height+3)//4)*(8 if marker==3 else 16)
 if standard:
  for off,val in[(0,0x20534444),(12,height),(16,width),(84,0x31545844 if marker==3 else 0x35545844)]:m.wi(header+off,val)
 else:
  for off,val in[(0,width),(4,height),(8,marker),(12,size)]:m.wi(header+off,val)
  m.wf(header+16,1.0 if marker==3 else .5)
 admitted=run(0x1400f9d10,[obj]);result=run(0x1400f9b90,[obj,out,out+4,out+8,out+12,out+16]);assert admitted==1 and result==1
 value=dict(width=m.si(out),height=m.si(out+4),marker=u.mem_read(out+8,1)[0],topMipSize=m.si(out+12),alpha=m.rf(out+16))
 assert value==dict(width=width,height=height,marker=marker,topMipSize=size,alpha=1.0 if marker==3 else .5)
 cases.append(dict(standard=standard,**value,payloadOffset=m.q(obj+0x68)-header))
output=dict(target=m.digest,scope=__doc__,cases=cases)
(root/'backups/animations/native-dds-attributes-v1.json').write_text(json.dumps(output,indent=2)+'\n')
print(json.dumps(dict(cases=len(cases),target=m.digest)))
