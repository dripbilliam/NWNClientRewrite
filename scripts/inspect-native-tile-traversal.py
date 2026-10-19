"""Complete original ClippedLineSegmentWalkable2bb580, clipping2bbf60,
intersection2bf510, vertex geometry2bf060 and plane height22de80. Meshes are
supplied through a memory-only Node pipe; installed asset arrays are not saved.
Location, Vector construction, allocator/free and memory-copy boundaries are
captured. Native face scans, edge traversal, float operations and limit execute.
"""
import importlib,json,subprocess,struct,hashlib
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
surface,tile,vertices,faces,adjacency,normals,constants,out=[m.heap+n*0x10000 for n in range(8)]
ranges=[(0x1402bb580,0x1402bc3c1),(0x1402bf060,0x1402bf137),(0x1402bf510,0x1402bf96a),(0x14022de80,0x14022deba)]
def hook(u,a,n,_):
 global limited
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1402c55a0:m.wi(y,c['tile'][0]);m.wi(z,c['tile'][1]);m.finish()
 elif a==0x140047300:u.mem_write(x,bytes(12));m.finish(x)
 elif a==0x140c10370:m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a==0x140c10368:m.finish(m.heap+0x90000)
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==0x1402bb930:
  if len(trace)<520:trace.append(u.reg_read(UC_X86_REG_R15D))
 elif a==0x1402bbdf4:limited=True
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unexpected tile dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,mesh,floatbits):
 global c,trace,limited
 c=case;trace=[];limited=False;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wi(surface+0x54,len(mesh['vertices']));m.wi(surface+0x64,len(mesh['faces']))
 for offset,ptr in[(0xd0,vertices),(0x78,faces),(0xb0,adjacency),(0xa8,normals),(0xa0,constants)]:m.wq(surface+offset,ptr)
 for ptr,key,integer in[(vertices,'vertices',False),(faces,'faces',True),(adjacency,'adjacency',True),(normals,'normals',False)]:
  for i,row in enumerate(mesh[key]):
   for j,v in enumerate(row):m.wi(ptr+i*12+j*4,v if integer else floatbits[key][i][j])
 for i,v in enumerate(floatbits['constants']):m.wi(constants+i*4,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,surface);u.reg_write(UC_X86_REG_RDX,tile)
 for reg,v in zip([UC_X86_REG_XMM2,UC_X86_REG_XMM3],c['from']):u.reg_write(reg,int.from_bytes(struct.pack('<f',v),'little'))
 for i,v in enumerate(c['to']):m.wf(rsp+0x28+i*8,v)
 for i in range(6):m.wq(rsp+0x38+i*8,out+i*4);m.wi(out+i*4,0)
 try:u.emu_start(0x1402bb580,m.stop,count=3000000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_EAX),output=[m.rf(out+i*4)for i in range(6)],bits=[m.si(out+i*4)&0xffffffff for i in range(6)],trace=trace,limited=limited)
data=json.loads(subprocess.check_output(['node','scripts/tile-traversal-cases.mjs'],cwd=m.root))
rows=[run(c,data['meshes'][c['mesh']],data['meshFloatBits'][c['mesh']])for c in data['cases']]
outpath=m.root/'backups/animations/native-tile-traversal-observations.json';outpath.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n')
print(json.dumps(dict(rows=len(rows),nativeLimited=sum(r['limited']for r in rows),jsLimited=sum(r['case']['javascriptWarnings']for r in rows),statusMismatches=sum(r['result']!=r['case']['javascript']['status']for r in rows),bitMismatches=sum(any(j is not None and j!=b for j,b in zip(r['case']['javascriptBits'],r['bits']))for r in rows))))
