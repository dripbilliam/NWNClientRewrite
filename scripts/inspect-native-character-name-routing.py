"""Execute unchanged original CNWNameGen::GetRandomName140235000 routing.

Captured boundaries are active racialtypes string reads, name-table load/result,
name generation, CExoString allocation/copy/concatenation, CRT rand and release.
The complete original routing/cache lifetime body runs unchanged. This proves
resource selection and caching, not probability generation, UI, server or pixels.
"""
import importlib.util, json, hashlib
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
owner,result=m.heap+0x1000,m.heap+0x2000
allocation=0;case={};calls=[]
def allocate(size):
 global allocation
 value=m.heap+0x10000+allocation;allocation+=(max(size,1)+15)&~15
 assert allocation<0x80000
 return value
def text(pointer):
 value=bytearray()
 while pointer and u.mem_read(pointer,1)[0]:value.extend(u.mem_read(pointer,1));pointer+=1
 return value.decode('latin1')
def string(pointer,value):
 data=value.encode('latin1');address=allocate(len(data)+1);u.mem_write(address,data+b'\0');m.wq(pointer,address);m.wi(pointer+8,len(data));m.wi(pointer+12,len(data)+1)
def hook(_u,address,_n,_):
 if address==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if address==0x140c10368:m.finish(allocate(x))
 elif address in [0x140c10370,0x140c10410,0x1401a65a0]:m.finish()
 elif address==0x14018ded0:u.mem_write(x,text(y).lower().encode('latin1')[:16].ljust(17,b'\0'));m.finish(x)
 elif address==0x1401a62b0:calls.append(['table',text(y)]);m.finish(x)
 elif address==0x1401a73a0:m.finish(int(case['tableLoaded']))
 elif address==0x1401a68f0:
  key=text(m.q(z));value=case['a' if key=='NameGenTableA' else 'b'];calls.append(['cell',y,key]);string(w,value);m.finish(int(bool(value)))
 elif address==0x14003d8c0:string(x,bytes(u.mem_read(y,z)).decode('latin1') if z else '');m.finish(x)
 elif address==0x14016ab00:string(y,text(m.q(x))+text(m.q(z)));m.finish(y)
 elif address==0x140c7ed00:calls.append(['rand',case['sample']]);m.finish(case['sample'])
 elif address==0x140236090:calls.append(['load',text(m.q(y))]);m.finish(int(case['loadSucceeded']))
 elif address==0x1402359b0:calls.append(['generate']);string(y,'CapturedName');m.finish(y)
 elif address==0x1401912c0:calls.append(['release']);m.finish()
 elif not 0x140235000<=address<=0x1402359ad:raise AssertionError(f'Uncaptured routing dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(value):
 global allocation,case,calls
 allocation=0;case=value;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wi(owner+0x28,int(value['cached']));u.mem_write(owner+0x2c,int(value['cacheRace']).to_bytes(2,'little'));u.mem_write(owner+0x2e,bytes([value['cacheType']]))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[owner,result,value['race'],value['kind']]):u.reg_write(r,v)
 try:u.emu_start(0x140235000,m.stop,count=20000)
 except Exception:print(json.dumps({'case':value,'rip':hex(u.reg_read(UC_X86_REG_RIP)),'calls':calls}));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return {'input':value,'calls':calls,'name':text(m.q(result)),'cacheRace':int.from_bytes(u.mem_read(owner+0x2c,2),'little'),'cacheType':u.mem_read(owner+0x2e,1)[0]}
if __name__=='__main__':
 base={'cached':False,'cacheRace':0,'cacheType':0,'tableLoaded':True,'loadSucceeded':True,'sample':0,'a':'','b':''}
 rows=[run(base|{'race':race,'kind':kind,'a':a,'b':b,'sample':sample}) for race in [0,1,2,3,4,5,6,7,300,65534,65535] for kind in [0,1,2,3,255] for a,b in [('', ''),('ActiveA',''),('','ActiveB'),('ActiveA','ActiveB')] for sample in [0,1]]
 rows += [run(base|value) for value in [
  {'race':300,'kind':1,'a':'ActiveA','tableLoaded':False},
  {'race':2,'kind':0,'a':'ActiveA','tableLoaded':False},
  {'race':300,'kind':1,'a':'ActiveA','loadSucceeded':False},
  {'race':300,'kind':1,'cached':True,'cacheRace':300,'cacheType':1},
  {'race':300,'kind':1,'cached':True,'cacheRace':300,'cacheType':0,'a':'Changed'},
  {'race':300,'kind':1,'cached':True,'cacheRace':301,'cacheType':1,'a':'Changed'}]]
 output=m.root/'godot-client/reports/native-character-name-routing-original-v1.json'
 assert not output.exists(),'Prior evidence preserved'
 output.write_text(json.dumps({'success':True,'binarySha256':m.digest,'scriptSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'scope':__doc__,'rows':rows},indent=2)+'\n')
 print(json.dumps({'success':True,'cases':len(rows),'output':str(output),'gpu':False,'serverConnections':0}))
