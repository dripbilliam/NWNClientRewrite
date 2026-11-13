"""Execute unchanged original Race OK/Cancel and accepted Subrace callback.
Object lookup, original ability setters, ruleset hash/value service, biography
lookup, ExoString copying/freeing and unarmed refresh are explicit providers.
Selection/map/table fields are supplied memory fixtures; population, pixels,
full existing-BIC preservation and authoritative saving are not proved here.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel,creature,actor,rules,races,table,vtable=[m.heap+n for n in [0x1000,0x5000,0x9000,0x10000,0x20000,0x30000,0x40000]]
setters=[0x1407fa760,0x1407f9ba0,0x1407f96d0,0x1407f9e70,0x1407fab40,0x1407f9670]
def word(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def string(dest,text):
 global bump
 raw=text.encode('cp1252');ptr=m.heap+bump;bump+=max(32,len(raw)+1);u.mem_write(ptr,raw+b'\0');m.wq(dest,ptr);m.wi(dest+8,len(raw));m.wi(dest+12,len(raw)+1)
def readstring(dest):return bytes(u.mem_read(m.q(dest),m.si(dest+8))).decode('cp1252') if m.q(dest) else ''
def hook(u,a,n,_):
 global refreshes
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140800c90:m.finish(creature)
 elif a==0x140c10370 or a==m.stop+0x10:m.finish()
 elif a==0x14003d8c0:string(x,bytes(u.mem_read(y,z)).decode('cp1252') if z else '');m.finish(x)
 elif a==0x1402a1660:string(y,'Biography '+str((x-races)//0x68));m.finish(y)
 elif a==0x1402ae870:m.finish(1)
 elif a==0x1402a4130:m.finish(case['minimum'])
 elif a in setters:u.mem_write(x+0x76+setters.index(a),bytes([y&255]));m.finish()
 elif a==0x1407f7b80:refreshes+=1;m.finish()
 elif a==0x1401fc440:codes.append(y&0xffffffff);m.finish()
 elif not (0x1408e53e0<=a<=0x1408e56dd or 0x1408e7810<=a<=0x1408e7891 or 0x1408e1250<=a<0x1408e1290):raise AssertionError(f'Unmapped original Race dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,value&0xffffffffffffffff)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
def run(previous,selected,flag,minimum,points,subrace,cancel):
 global case,bump,refreshes,codes
 case=dict(previous=previous,selected=selected,flag=flag,minimum=minimum,points=points,subrace=subrace,cancel=cancel);bump=0x50000;refreshes=0;codes=[]
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,rules);m.wq(rules+0x118,races)
 m.wq(panel,vtable);m.wq(vtable,m.stop+0x10);m.wq(creature+0x3b0,actor);m.wi(panel+0xf10,123);m.wi(panel+0xf14,flag)
 m.wi(panel+0x6e8,selected);m.wi(panel+0x6f8,2);m.wq(panel+0xa78,table);m.wi(table,0);m.wi(table+4,6)
 word(actor+0x50,previous);word(actor+0xe4,999);m.wi(actor+0x108,777);u.mem_write(actor+0x10c,bytes([77]));u.mem_write(actor+0x76,bytes([19]*6));u.mem_write(actor+0x295,bytes([10]));word(actor+0x84,12)
 string(actor+0x58,'Old Subrace');string(actor+0xf8,'Old Biography')
 for index in range(8):m.wi(races+index*0x68+0x30,20+index);word(races+index*0x68+0x34,100+index);m.wi(races+index*0x68+0x54,points)
 if cancel:call(0x1408e1250,[panel])
 elif subrace is not None:
  value=m.heap+0x45000;string(value,subrace);call(0x1408e7810,[panel,value])
 else:call(0x1408e53e0,[panel])
 return dict(input=case,output=dict(race=int.from_bytes(u.mem_read(actor+0x50,2),'little'),appearance=int.from_bytes(u.mem_read(actor+0xe4,2),'little'),age=m.si(actor+0x108),points=int(u.mem_read(actor+0x10c,1)[0]),abilities=list(u.mem_read(actor+0x76,6)),subrace=readstring(actor+0x58),biography=readstring(actor+0xf8),classId=int(u.mem_read(actor+0x295,1)[0]),baseHP=int.from_bytes(u.mem_read(actor+0x84,2),'little'),refreshes=refreshes,codes=codes))
if __name__=='__main__':
 out=m.root/'backups/animations/native-creation-race-observations-v1.json';assert not out.exists(),'Preserve prior evidence'
 rows=[run(*args)for args in itertools.product([0,6],[-1,0,1,2],[0,1],[8,11,260],[30,286],[None,'New Subrace'],[False,True])]
 out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,procedures=['0x1408e53e0','0x1408e1250','0x1408e7810'],rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows))))
