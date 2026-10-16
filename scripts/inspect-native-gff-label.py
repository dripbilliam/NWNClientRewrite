"""Complete native GetFieldByLabel14019fcc0 and GetField14019fc20.
Only fixed-byte copy and security cookie are boundaries. Valid label arrays,
single/multi-field structs and field-index permutations are synthetic. Empty/
null query diagnostics and malformed/duplicate serialized labels are excluded.
"""
import importlib.util,itertools,json,struct,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
gffPtr,rootPtr,headerPtr,structPtr,fieldsPtr,labelsPtr,indicesPtr,queryPtr=[m.heap+n*0x1000 for n in range(1,9)]
def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if at==0x140c4eec0:
  raw=bytes(u.mem_read(y,z)).split(b'\0')[0];u.mem_write(x,raw.ljust(z,b'\0'));m.finish(x);return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not(0x14019fcc0<=at<0x14019fef0 or 0x14019fc20<=at<0x14019fcbf):raise AssertionError(f'Uncaptured GFF label dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def execute(address,args):
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,value)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;return u.reg_read(UC_X86_REG_RAX)
def run(labels,order,query):
 u.mem_write(m.heap,bytes(0x100000));m.wq(gffPtr+0x78,headerPtr);m.wq(gffPtr+0x88,structPtr);m.wq(gffPtr+0x98,fieldsPtr);m.wq(gffPtr+0xa8,labelsPtr);m.wq(gffPtr+0xc8,indicesPtr)
 for offset,value in [(0xc,1),(0x14,len(labels)),(0x1c,len(labels)),(0x2c,len(order)*4)]:m.wi(headerPtr+offset,value)
 u.mem_write(structPtr,struct.pack('<III',0xffffffff,order[0] if len(order)==1 else 0,len(order)))
 for i,label in enumerate(labels):
  raw=label.encode('cp1252');assert len(raw)<=16 and b'\0'not in raw;u.mem_write(labelsPtr+i*16,raw.ljust(16,b'\0'));u.mem_write(fieldsPtr+i*12,struct.pack('<III',4,i,500+i))
 for i,index in enumerate(order):m.wi(indicesPtr+i*4,index)
 u.mem_write(queryPtr,query.encode('cp1252')+b'\0');ordinal=execute(0x14019fcc0,[gffPtr,rootPtr,queryPtr])&0xffffffff
 field=execute(0x14019fc20,[gffPtr,rootPtr,ordinal]);return dict(labels=labels,order=order,query=query,ordinal=ordinal,fieldIndex=(field-fieldsPtr)//12 if field else None,value=m.si(field+8) if field else None)
labelsets=[[],['Tag'],['AnimationReplace'],['TextureReplaceLi'],['KeyRequiredFeedb'],['Material','material','Tag','AnimationReplace','TextureReplaceLi','KeyRequiredFeedb']]
queries=['Tag','tag','Tag\0tail','AnimationReplace','AnimationReplaceList','AnimationReplaceQ','TextureReplaceList','TextureReplaceLi','TextureReplaceLi_extra','KeyRequiredFeedbackMessage','KeyRequiredFeedb','Material','material','MATERIAL','missing','a'*80]
rows=[]
for labels in labelsets:
 orders=[list(range(len(labels)))]
 if len(labels)>1:orders.extend([list(reversed(orders[0])),[3,0,5,1,4,2],[1,4,2]])
 for order in orders:
  for query in queries:rows.append(run(labels,order,query))
out=m.root/'backups/animations/native-gff-label-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
