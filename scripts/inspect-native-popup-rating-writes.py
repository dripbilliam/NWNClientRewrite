"""Bounded read-only static candidate audit for popup target stats+90.

Decode PE exception-table function ranges in client760000..880000. Retain
non-stack constant-displacement writes overlapping byte90 and exact RIP refs
to the ChallengeRating GFF label. Candidates do not identify pointer types.
Aliased pointers, bulk copies, index arithmetic and writes outside this range
remain unknown. No emulator/native instruction execution or live access.
"""
import hashlib,json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64,CS_AC_WRITE
from capstone.x86 import X86_OP_MEM,X86_REG_RSP,X86_REG_RBP,X86_REG_RIP

image=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(image).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=image);base=pe.OPTIONAL_HEADER.ImageBase
low,high=0x140760000,0x140880000
cs=Cs(CS_ARCH_X86,CS_MODE_64);cs.detail=True
writes=[];references=[];functions=0;instructions=0;decoded_bytes=0
for entry in pe.DIRECTORY_ENTRY_EXCEPTION:
    begin,end=base+entry.struct.BeginAddress,base+entry.struct.EndAddress
    if begin<low or begin>=high:continue
    functions+=1
    rows=list(cs.disasm(pe.get_data(begin-base,end-begin),begin))
    instructions+=len(rows);decoded_bytes+=sum(ins.size for ins in rows)
    for index,ins in enumerate(rows):
        for operand in ins.operands:
            if operand.type!=X86_OP_MEM:continue
            mem=operand.mem
            if mem.base==X86_REG_RIP and ins.address+ins.size+mem.disp==0x140de5940:
                references.append(dict(function=hex(begin),address=hex(ins.address),bytes=ins.bytes.hex(),assembly=ins.mnemonic+' '+ins.op_str))
            if not operand.access&CS_AC_WRITE or mem.base in [X86_REG_RSP,X86_REG_RBP,X86_REG_RIP]:continue
            if not (mem.disp<=0x90<mem.disp+operand.size):continue
            writes.append(dict(function=hex(begin),endExclusive=hex(end),address=hex(ins.address),bytes=ins.bytes.hex(),assembly=ins.mnemonic+' '+ins.op_str,displacement=mem.disp,width=operand.size,base=ins.reg_name(mem.base),index=ins.reg_name(mem.index),context=[dict(address=hex(row.address),assembly=row.mnemonic+' '+row.op_str)for row in rows[max(0,index-4):index+5]]))
out=root/'godot-client/reports/native-popup-rating-writes-static-v1.json'
assert not out.exists(),'Preserve prior evidence'
result=dict(schema='native-popup-rating-writes-static-v1',binarySha256=digest,scope=__doc__,region=[hex(low),hex(high)],functionRanges=functions,instructions=instructions,decodedBytes=decoded_bytes,candidateWrites=writes,challengeRatingLabelReferences=references,emulatorExecutions=0,liveProcessAccess=False,enginesRun=0,productionChanged=False)
out.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(dict(report=str(out),functions=functions,instructions=instructions,candidateWrites=len(writes),challengeRatingLabelReferences=len(references))))
