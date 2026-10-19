"""Read-only instruction candidates for client pending attack/cast record owners.
Offsets are search evidence, not semantic confirmation or whole-function proof.
"""
import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-message-text').m
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
from capstone.x86_const import X86_OP_MEM
cs=Cs(CS_ARCH_X86,CS_MODE_64);cs.detail=True;cs.skipdata=True;rows=[]
for ins in cs.disasm(m.pe.get_data(0x7fb000,0x16000),0x1407fb000):
 if ins.id and any(op.type==X86_OP_MEM and op.mem.disp in [0x358,0x360]for op in ins.operands):rows.append(dict(address=hex(ins.address),instruction=ins.mnemonic+' '+ins.op_str))
event=m.pe.get_data(0xe47bb0,32).split(b'\0',1)[0].decode('ascii')
slots={hex(vt):hex(int.from_bytes(m.pe.get_data(vt-0x140000000+0x48,8),'little'))for vt in [0x140e6e978,0x140e755e8]}
names={hex(vt):hex(int.from_bytes(m.pe.get_data(vt-0x140000000+0x58,8),'little'))for vt in [0x140e78250,0x140e778b0]}
offsets=[i for i in range(0,0x400,8)if int.from_bytes(m.pe.get_data(0xe474e8+i,8),'little')==0x1407fbd10];assert len(offsets)==1
ai={hex(vt):hex(int.from_bytes(m.pe.get_data(vt-0x140000000+offsets[0],8),'little'))for vt in [0x140e474e8,0x140e53950,0x140e52f68]}
out=m.root/'backups/animations/native-client-attack-record-candidates.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,rows=rows,eventName=event,eventNameAddress='0x140e47bb0',lengthSlots=slots,objectNameSlots=names,aiOffset=offsets[0],ai=ai),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),eventName=event,lengthSlots=slots,objectNameSlots=names,aiOffset=offsets[0],ai=ai,output=str(out))))
