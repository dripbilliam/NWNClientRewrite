"""Read-only bounded pointer-flow inventory for CAppManager->client+24.
Starts from provider-established global references, follows direct register
copies/loads in96-byte windows and at most one direct call with proven client
this. No stack-spill/CFG/computed-call inference; results require source review.
"""
from pathlib import Path
import sys,json,hashlib,bisect
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64,CS_AC_WRITE
from capstone.x86_const import X86_OP_REG,X86_OP_MEM,X86_OP_IMM
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase;image=pe.get_memory_mapped_image();md=Cs(CS_ARCH_X86,CS_MODE_64);md.detail=True
source=json.loads((root/'godot-client/reports/native-level-up-app-reference-input-v1.json').read_text());assert source['binarySha256']==digest
global_address=int(source['address'],16);writes=[];calls={};seen=set()
aliases={'eax':'rax','ax':'rax','al':'rax','edx':'rdx','ecx':'rcx','edi':'rdi','esi':'rsi','ebx':'rbx','ebp':'rbp','esp':'rsp'}
def reg_name(r):
    name=md.reg_name(r);return aliases.get(name,name[:-1]if name.startswith('r')and name.endswith(('d','w','b'))else name)
def scan(address,initial=None,origin=None,depth=0):
    key=(address,depth)
    if key in seen or not base<=address<base+len(image):return
    seen.add(key);tags=dict(initial or {});context=[]
    for instruction in list(md.disasm(image[address-base:address-base+96],address))[:28]:
        ops=instruction.operands;context.append(dict(address=hex(instruction.address),mnemonic=instruction.mnemonic,operands=instruction.op_str))
        for at,op in enumerate(ops):
            if op.type!=X86_OP_MEM or not op.mem.base or op.mem.index:continue
            value=tags.get(reg_name(op.mem.base));value=(value[0],value[1]+op.mem.disp)if value else None
            if value==('client',0x24)and op.access&CS_AC_WRITE:writes.append(dict(source=hex(origin or address),address=hex(instruction.address),depth=depth,instructions=list(context)))
        if instruction.mnemonic=='mov'and len(ops)==2 and ops[0].type==X86_OP_REG:
            target=reg_name(ops[0].reg);value=None
            if ops[0].size==8 and ops[1].type==X86_OP_REG and ops[1].size==8:value=tags.get(reg_name(ops[1].reg))
            elif ops[0].size==8 and ops[1].type==X86_OP_MEM:
                mem=ops[1].mem
                if md.reg_name(mem.base)=='rip'and instruction.address+instruction.size+mem.disp==global_address:value=('manager',0)
                elif mem.base and not mem.index and tags.get(reg_name(mem.base))==('manager',0)and mem.disp==0:value=('client',0)
            if value:tags[target]=value
            else:tags.pop(target,None)
        elif instruction.mnemonic=='lea'and len(ops)==2 and ops[0].type==X86_OP_REG and ops[1].type==X86_OP_MEM:
            mem=ops[1].mem;target=reg_name(ops[0].reg);value=tags.get(reg_name(mem.base))if ops[0].size==8 and mem.base and not mem.index else None
            if value:tags[target]=(value[0],value[1]+mem.disp)
            else:tags.pop(target,None)
        elif instruction.mnemonic=='call':
            if tags.get('rcx')==('client',0)and len(ops)==1 and ops[0].type==X86_OP_IMM:
                target=ops[0].imm;calls.setdefault(target,[]).append(hex(instruction.address))
                if depth==0:scan(target,{'rcx':('client',0)},origin or address,1)
            for name in ['rax','rcx','rdx','r8','r9','r10','r11']:tags.pop(name,None)
        else:
            for op in ops:
                if op.type==X86_OP_REG and op.access&CS_AC_WRITE:tags.pop(reg_name(op.reg),None)
        if instruction.mnemonic.startswith('ret')or instruction.mnemonic=='jmp':break
for address in source['references']:scan(int(address,16))
out=root/'godot-client/reports/native-level-up-app-flag-inventory-v1.json';assert not out.exists(),'Preserve evidence'
out.write_text(json.dumps(dict(binarySha256=digest,scope=__doc__,inputEvidence=source['evidenceId'],references=len(source['references']),windows=len(seen),writes=writes,clientCallTargets=[dict(address=hex(k),calls=v)for k,v in calls.items()]),indent=2)+'\n');print(json.dumps(dict(output=str(out),references=len(source['references']),windows=len(seen),writes=len(writes),addresses=sorted(set(w['address']for w in writes)))))
