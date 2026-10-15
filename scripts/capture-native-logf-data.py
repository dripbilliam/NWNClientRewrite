"""Extract only scalar constants/table values referenced by original logf.
Verified original image/hash and instruction ranges are supplied by the shared
read-only emulator loader. No proprietary code or game assets are copied.
"""
import importlib.util,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
from capstone.x86 import X86_OP_MEM,X86_REG_RIP
decoder=Cs(CS_ARCH_X86,CS_MODE_64);decoder.detail=True
constants={};tables={}
for ins in decoder.disasm(m.pe.get_data(0xc946b0,0x3f6),0x140c946b0):
    for op in ins.operands:
        if op.type!=X86_OP_MEM or op.mem.base!=X86_REG_RIP:continue
        addr=ins.address+ins.size+op.mem.disp
        if ins.mnemonic=='lea':
            tables[hex(addr)]=list(struct.unpack('<129f',m.pe.get_data(addr-m.base,129*4)))
        elif addr!=0x1415d8224:
            raw=m.pe.get_data(addr-m.base,4);value=struct.unpack('<f',raw)[0];constants[hex(addr)]=dict(u32=struct.unpack('<I',raw)[0],f32=value if math.isfinite(value) else None)
out=m.root/'backups/animations/native-logf-constants.json';out.write_text(json.dumps(dict(binarySha256=m.digest,constants=constants,tables=tables),indent=2,allow_nan=False)+'\n')
source=m.root/'src/native_log_table.js';source.write_text('// Numeric reduction tables read from verified original logf140c946b0.\n// See scripts/capture-native-logf-data.py; no executable/asset bytes.\nexport const nativeLogTable = '+json.dumps(dict(inverse=tables['0x140edb150'],tail=tables['0x140edaf40'],head=tables['0x140edad30']),separators=(',',':'),allow_nan=False)+';\n')
print(json.dumps(dict(output=str(out),constants=constants,tables={key:len(value) for key,value in tables.items()}),indent=2))
