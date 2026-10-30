"""Unchanged original GL sampler and TXI field dispatch/parse instructions.
OpenGL publication, C sscanf/stricmp/firstword, unrelated font parsing and stack
cookie checking are captured boundaries. No original process, GPU, profile,
network or physical input is touched. This is not a full TXI/rendering oracle.
"""
import importlib.util,itertools,json,struct,re,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
output=Path(sys.argv[1]).resolve();assert not output.exists() and output.is_relative_to(m.root/'backups/animations')
calls=[];stubs={};slot=0
for entry in m.pe.DIRECTORY_ENTRY_IMPORT:
    for item in entry.imports:
        if item.name in [b'glTexParameteri',b'glTexParameterf',b'glGetFloatv']:
            address=m.stop+0x100+slot*0x20;slot+=1;stubs[address]=item.name.decode();m.wq(item.address,address)
assert set(stubs.values())=={'glTexParameteri','glTexParameterf','glGetFloatv'}
u.mem_write(0x14128eb00,struct.pack('<f',16.0))
def string(address):return bytes(u.mem_read(address,256)).split(b'\0')[0].decode('ascii')
def hook(u,address,size,_):
    if address==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if address in stubs:
        name=stubs[address]
        if name=='glTexParameteri':calls.append([x&0xffffffff,y&0xffffffff,z&0xffffffff])
        elif name=='glGetFloatv':u.mem_write(y,struct.pack('<f',16.0))
        m.finish();return
    if address==0x140047060:
        text=string(x);fmt=string(y)
        if fmt=='%s':
            token=text.split()[0] if text.split() else '';u.mem_write(z,token.encode()+b'\0');m.finish(1 if token else 0)
        elif fmt=='%d':
            found=re.match(r'\s*([+-]?\d+)',text);assert found,text
            u.mem_write(z,struct.pack('<I',int(found[1])&0xffffffff));m.finish(1)
        else:raise AssertionError(fmt)
        return
    if address==0x140c9a9fc:m.finish(0 if string(x).lower()==string(y).lower() else 1);return
    if address==0x1400a15d0:
        token=string(x).split()[0] if string(x).split() else '';u.mem_write(m.heap+0xc000,token.encode()+b'\0');m.finish(m.heap+0xc000);return
    if address in [0x1400ecc20,0x140c10410]:m.finish();return
    if not any(lo<=address<=hi for lo,hi in [(0x1400b8100,0x1400b825b),(0x1400ecf20,0x1400edfff),(0x1400a0c00,0x1400a0c9f),(0x1400a0250,0x1400a028f)]):
        raise AssertionError(f'Uncaptured native sampler/parser dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,*args):
    u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
    u.emu_start(address,m.stop,count=200000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
samplers=[]
for target,filtering,mipmap,clamp in itertools.product([0,1],[0,1],[0,1],range(8)):
    calls.clear();call(0x1400b8100,target,filtering,mipmap,clamp)
    samplers.append(dict(target=target,filter=bool(filtering),mipmap=bool(mipmap),clamp=clamp,calls=list(calls)))
cases=['','mipmap 0\nfilter 0\nclamp 3','FILTER TRUE\r\nMIPMAP FALSE\r\nCLAMP 2']
cases += [f'{field} {value}' for field,value in itertools.product(['filter','mipmap'],['0','1','true','false','TRUE','FALSE','2','-1','yes'])]
cases += [f'clamp {value}' for value in [*range(8),-1,32767,32768,65535,65536,'+2suffix']]
cases += ['filter 0\nfilter 2','filter 0\nfilter true','mipmap 0\nmipmap 1','  clamp\t1\n\tfilter 0','unknown 1\nfilter false','clamp 7\nclamp 2']
fields=[];instance=m.heap+0x10000;source=m.heap+0x18000
for text in cases:
    u.mem_write(instance,bytes(0x200));u.mem_write(instance+0xe4,b'\x01\x01')
    for line in text.replace('\r','\n').split('\n'):
        line=line.lstrip(' \t')
        if not line:continue
        u.mem_write(source,line.encode()+b'\0');call(0x1400ecf20,instance,source)
    fields.append(dict(text=text,filter=bool(bytes(u.mem_read(instance+0xe5,1))[0]),mipmap=bool(bytes(u.mem_read(instance+0xe4,1))[0]),clamp=struct.unpack('<h',bytes(u.mem_read(instance+0xc8,2)))[0]))
result=dict(binarySha256=m.digest,scope=__doc__,samplers=samplers,fields=fields)
output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(output=str(output),samplers=len(samplers),fields=len(fields))))
