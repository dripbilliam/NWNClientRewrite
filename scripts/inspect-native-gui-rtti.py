"""Pinned MSVC RTTI/vtable inventory for exact original GUI owner classes.

Inheritance is observed source metadata, not proof that a particular activation
path inserts a modal. Getter/virtual slots are recorded separately for review.
"""
from pathlib import Path
import argparse,hashlib,json,struct,sys
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'backups/research-python'))
import pefile,capstone
p=argparse.ArgumentParser();p.add_argument('--report',required=True);out=Path(p.parse_args().report).resolve()
if out.exists():raise SystemExit('Refusing to overwrite original evidence')
raw=(ROOT.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(raw).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=raw);base=pe.OPTIONAL_HEADER.ImageBase;cs=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64);cs.detail=True
u32=lambda a:struct.unpack_from('<I',raw,pe.get_offset_from_rva(a-base))[0]
u64=lambda a:struct.unpack_from('<Q',raw,pe.get_offset_from_rva(a-base))[0]
def typename(address):
 off=pe.get_offset_from_rva(address-base)+16;stop=raw.find(b'\0',off,off+512)
 if stop<0:raise ValueError('No bounded RTTI name')
 value=raw[off:stop].decode('ascii');assert value.startswith('.?A');return value
cols={}
for section in pe.sections:
 if section.Name.rstrip(b'\0')!=b'.rdata':continue
 data=section.get_data();origin=base+section.VirtualAddress
 for off in range(0,len(data)-24,4):
  if data[off:off+4]!=b'\x01\0\0\0' or struct.unpack_from('<I',data,off+20)[0]!=section.VirtualAddress+off:continue
  address=origin+off
  try:
   name=typename(base+u32(address+12));hierarchy=base+u32(address+16);count=u32(hierarchy+8);assert 0<count<256;array=base+u32(hierarchy+12)
   bases=[typename(base+u32(base+u32(array+4*i)))for i in range(count)]
   cols[address]={'locator':hex(address),'type':name,'objectOffset':u32(address+4),'bases':bases,'tables':[]}
  except (ValueError,AssertionError,UnicodeDecodeError,pefile.PEFormatError,struct.error):continue
 # Primary vtable[-8] stores an absolute pointer to its locator.
 for off in range(0,len(data)-8,8):
  pointer=struct.unpack_from('<Q',data,off)[0]
  if pointer in cols:cols[pointer]['tables'].append(origin+off+8)
def slot(table,offset):
 try:
  target=u64(table+offset);pos=pe.get_offset_from_rva(target-base);instructions=[]
  for i in cs.disasm(raw[pos:pos+64],target):
   instructions.append(i)
   if i.mnemonic in ['ret','jmp']:break
  constant=None
  if len(instructions)==2 and instructions[0].mnemonic=='mov' and instructions[0].op_str.startswith('eax, ') and instructions[0].operands[1].type==capstone.x86.X86_OP_IMM and instructions[1].mnemonic=='ret':constant=instructions[0].operands[1].imm&0xffffffff
  used=sum(i.size for i in instructions)
  return {'slot':offset,'target':hex(target),'instructionBytes':raw[pos:pos+used].hex(),'sha256':hashlib.sha256(raw[pos:pos+used]).hexdigest(),'assembly':[f'{i.address:#x}: {i.mnemonic} {i.op_str}'for i in instructions],'constantReturn':constant,'constantType':constant.to_bytes(4,'big').decode('ascii',errors='replace')if constant is not None else None,'boundary':'Decoded leaf prefix through first RET/JMP; not an asserted complete function body'}
 except (ValueError,pefile.PEFormatError,struct.error):return {'slot':offset,'available':False}
rows=[]
for row in cols.values():
 row['guiPanelBase']='.?AVCGuiPanel@@'in row['bases']
 row['nuiWindowBase']='.?AVWindow@Nui@@'in row['bases']
 if not row['guiPanelBase'] and not row['nuiWindowBase']:continue
 row['modalBase']='.?AVCGuiModalPanel@@'in row['bases'];row['radialBase']='.?AVCRadialMenu@@'in row['bases']
 # Nui::Window has a different C++ interface. Reading CGuiObject slot offsets
 # there would attach an invented semantic label to unrelated adjacent data.
 row['tables']=[dict({'address':hex(t)},**({'typeGetter':slot(t,0x20),'priorTop':slot(t,0x138),'radialPriorTopTarget':slot(t,0xc0)}if row['guiPanelBase']else{'guiVirtualSchemaAvailable':False}))for t in row['tables']]
 rows.append(row)
rows.sort(key=lambda r:r['type'])
result={'success':True,'binarySha256':digest,'sourceSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'locatorCount':len(cols),'guiTypes':rows,'scope':'Immutable MSVC64 RTTI class/base metadata and exact virtual-slot bytes. Not a complete runtime owner inventory, activation-path or GUI interaction proof; computed calls remain unclassified.','gpu':False,'servers':0,'nativeBuilds':0}
out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'success':True,'locators':len(cols),'guiTypes':len(rows),'modalTypes':sum(r['modalBase']for r in rows),'radialTypes':sum(r['radialBase']for r in rows),'report':str(out)}))
