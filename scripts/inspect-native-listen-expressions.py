"""Read-only native expression oracle; no original files or process altered.

Execute ParseString/TestString and expression node helpers in Unicorn. Replace
only allocator/free/realloc/memmove and CExoString memory operations. ASCII
LowerCase is explicitly substituted, rejecting all other bytes. This is not a
running-game speech/event oracle.
"""
from pathlib import Path
import sys,hashlib,struct,json
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
uc=Uc(UC_ARCH_X86,UC_MODE_64)
uc.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);uc.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
uc.mem_map(heap,0x200000);uc.mem_map(stack,0x10000);uc.mem_map(stop,0x1000);uc.mem_write(stop,b'\xf4')
cursor=heap+0x1000;allocations={}
def allocate(size):
    global cursor
    assert 0<=size<0x10000
    pointer=cursor;cursor+=(max(size,1)+15)&~15
    assert cursor<heap+0x200000
    uc.mem_write(pointer,bytes(max(size,1)));allocations[pointer]=size
    return pointer
def read_q(address):return struct.unpack('<Q',uc.mem_read(address,8))[0]
def read_i(address):return struct.unpack('<i',uc.mem_read(address,4))[0]
def cstring(address):
    pointer=read_q(address);length=read_i(address+8)
    assert 0<=length<0x10000
    return bytes(uc.mem_read(pointer,length)) if pointer else b''
def set_string(address,value):
    pointer=allocate(len(value)+1);uc.mem_write(pointer,value+b'\0')
    uc.mem_write(address,struct.pack('<Qii',pointer,len(value),len(value)+1));return address
def finish(value=0):
    rsp=uc.reg_read(UC_X86_REG_RSP);uc.reg_write(UC_X86_REG_RIP,read_q(rsp));uc.reg_write(UC_X86_REG_RSP,rsp+8);uc.reg_write(UC_X86_REG_RAX,value)
substitutions=set()
associate_patterns=[]
capturing_associates=False
def hook(uc,address,size,_):
    if address==stop:uc.emu_stop();return
    a,b,c=[uc.reg_read(reg) for reg in (UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8)]
    if address in [0x140c10324,0x140c10368]:finish(allocate(a))
    elif address in [0x140c10370,0x140c10360,0x140c4f024]:finish()
    elif address==0x140c4f038:
        pointer=allocate(b)
        if a:uc.mem_write(pointer,bytes(uc.mem_read(a,min(allocations[a],b))))
        finish(pointer)
    elif address==0x140c417f0:
        if c:uc.mem_write(a,bytes(uc.mem_read(b,c)))
        finish(a)
    elif address==0x14003d8c0:finish(set_string(a,bytes(uc.mem_read(b,c)) if c else b''))
    elif address==0x14016bd70:
        value=cstring(a);assert all(byte<128 for byte in value)
        finish(set_string(b,value.lower()))
    elif address==0x14049b260 and capturing_associates:
        associate_patterns.append({'pattern':cstring(b).decode('ascii'),'id':struct.unpack('<i',struct.pack('<I',c&0xffffffff))[0]})
        uc.mem_write(b,bytes(16));finish()
    elif not (0x140440000<=address<0x140441b0c or capturing_associates and 0x1403d8160<=address<0x1403d894c):raise RuntimeError(f'Unmapped native expression dependency{address:x}')
    else:return
    substitutions.add(hex(address))
uc.hook_add(UC_HOOK_CODE,hook)
def call(address,*args):
    rsp=stack+0xff08;uc.mem_write(rsp,bytes(0x80));uc.mem_write(rsp,struct.pack('<Q',stop))
    uc.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):uc.reg_write(reg,value)
    uc.emu_start(address,stop,count=1000000);assert uc.reg_read(UC_X86_REG_RIP)==stop
    return struct.unpack('<i',struct.pack('<I',uc.reg_read(UC_X86_REG_RAX)&0xffffffff))[0]
def graph(expression):
    listing=read_q(expression+0x20)
    if not listing:return None
    todo=[read_q(listing)];seen={};nodes=[]
    while todo:
        node=todo.pop(0)
        if not node or node in seen:continue
        seen[node]=len(nodes);kind=read_i(node+4);nxt=read_q(node+0x10);branch=read_q(node+0x28) if kind==2 else 0
        nodes.append({'pointer':node,'type':kind,'literal':cstring(node+0x18).decode('ascii'),'nextPointer':nxt,'branchPointer':branch})
        todo.extend([nxt,branch])
    return [{'type':n['type'],'literal':n['literal'],'next':seen.get(n['nextPointer']),'branch':seen.get(n['branchPointer'])} for n in nodes]
patterns=['hello','hello **','**hello**','*w','*p','*a','*n','*A','**','(a|b)c','a|bc','a|b|c','(a|b)(c|d)','a**b**c','hello*','hello*x',')','(','|a','a|','()','','** **','*a**','*a*a','(**|a)**','a(**|*a)c','a()b','()*a','a||b','(a|)','|','**a**a**','*w**','*p**']
inputs=['','hello','HELLO','hello world','hi','a','b','c','ac','bc','ad','bd','abc','a12b34c',' ','\t','!','.','?','9','A','z','a b','a!','hello hello','hello\0world','aaaa','bca','abac','a   b','  ','...','a9','abcc']
observations=[]
for sensitive in [0,1]:
    for pattern in patterns:
        cursor=heap+0x1000;allocations.clear();uc.mem_write(heap,bytes(0x1000))
        expression=heap;uc.mem_write(expression+0x18,struct.pack('<i',sensitive))
        value=heap+0x100;set_string(value,pattern.encode('ascii'))
        parsed=call(0x140440970,expression,value)
        result={'caseSensitive':sensitive,'pattern':pattern,'parseResult':parsed,'nodes':graph(expression),'tests':[]}
        if parsed>=0:
            for text in inputs:
                value=heap+0x100;set_string(value,text.encode('ascii'))
                matched=call(0x1404413c0,expression,value,1)
                count=read_i(expression+0x10);items=read_q(expression+8)
                captures=[cstring(read_q(items+i*8)).decode('ascii') for i in range(count)]
                result['tests'].append({'text':text,'result':matched,'captures':captures})
        observations.append(result)
capturing_associates=True
cursor=heap+0x1000;allocations.clear();uc.mem_write(heap,bytes(0x1000))
call(0x1403d8160,heap)
output=root/'backups/animations/native-listen-expression-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'substitutions':sorted(substitutions),'limits':__doc__,'observations':observations,'associatePatterns':associate_patterns},indent=2))
print(json.dumps({'output':str(output),'patterns':len(observations),'tests':sum(len(o['tests']) for o in observations)}))
