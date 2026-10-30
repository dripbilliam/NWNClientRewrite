"""Read-only area-loading order evidence for the pinned original NWN client.
Executes only the unchanged grid index and loop-control instruction slices.
Tile I/O/model creation, status UI, timers, connection and other loop body work
are deliberately skipped boundaries, not emulated game behavior. The retained
whole-loader assembly/pseudocode supplies surrounding order and failure paths.
No running game, executable, assets or existing Ghidra database is modified.
"""
import hashlib, json, struct, sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data); base=pe.OPTIONAL_HEADER.ImageBase
decoder=Cs(CS_ARCH_X86,CS_MODE_64)
checks=[
 (0x1407dcf1c,'cmp','dword ptr [rdi + 0x10], r14d'),
 (0x1407dcf30,'mov','r12d, r14d'),
 (0x1407dcf38,'mov','edx, dword ptr [rdi + 0xc]'),
 (0x1407dcf50,'mov','r13d, ebx'),
 (0x1407dcf53,'imul','r13d, edx'),
 (0x1407dcf57,'add','r13d, r12d'),
 (0x1407dcfeb,'call','0x1400451c0'),
 (0x1407dd03b,'call','0x1402376a0'),
 (0x1407dd0c2,'call','0x140850110'),
 (0x1407dd119,'call','0x14084ef10'),
 (0x1407dd351,'inc','r12d'),
 (0x1407dd368,'jl','0x1407dcf50'),
 (0x1407dd36e,'inc','ebx'),
 (0x1407dd373,'cmp','ebx, dword ptr [rdi + 0x10]'),
 (0x1407dd384,'jmp','0x1407dcf30')]
instructions=[]
for address,mnemonic,operand in checks:
 i=next(decoder.disasm(pe.get_data(address-base,16),address))
 assert (i.mnemonic,i.op_str)==(mnemonic,operand),(hex(address),i.mnemonic,i.op_str)
 instructions.append({'address':hex(address),'instruction':i.mnemonic+' '+i.op_str})
u=Uc(UC_ARCH_X86,UC_MODE_64)
u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
area,stack=0x200000000,0x300000000
u.mem_map(area,0x1000);u.mem_map(stack,0x20000)
rows=[]; seen=[]
def hook(u,address,size,_):
 if address==0x1407dcf5a:
  seen.append({'x':u.reg_read(UC_X86_REG_R12D),'y':u.reg_read(UC_X86_REG_EBX),'index':u.reg_read(UC_X86_REG_R13D)})
  # All resource/presentation/network work deliberately outside this oracle.
  u.reg_write(UC_X86_REG_RIP,0x1407dd351)
 elif address==0x1407dd438:u.emu_stop()
 elif not (0x1407dcf16<=address<=0x1407dcf5a or 0x1407dd351<=address<=0x1407dd388):
  raise AssertionError('Unexpected original instruction '+hex(address))
u.hook_add(UC_HOOK_CODE,hook)
for width,height in [(1,1),(2,3),(3,2),(8,6),(32,24),(64,1)]:
 seen=[];u.mem_write(area+12,struct.pack('<ii',width,height))
 u.reg_write(UC_X86_REG_RDI,area);u.reg_write(UC_X86_REG_RSP,stack+0x10000);u.reg_write(UC_X86_REG_RBP,stack+0x11000);u.reg_write(UC_X86_REG_R14,0)
 u.emu_start(0x1407dcf16,0x1407dd438,count=100000)
 expected=[{'x':x,'y':y,'index':y*width+x}for y in range(height)for x in range(width)]
 assert seen==expected and u.reg_read(UC_X86_REG_RIP)==0x1407dd438
 rows.append({'width':width,'height':height,'observed':seen})
output=root/'backups/animations/native-player-stream-order-v1.json'
assert not output.exists()
output.write_text(json.dumps({'binarySha256':digest,'scope':__doc__,'instructionChecks':instructions,'cases':rows,'findings':{'terrainOrder':'y outer loop, x inner loop, index=y*width+x','playerDistanceUsedByGridControl':False,'fullLoaderOrSchedulerEmulated':False}},indent=2)+'\n')
print(json.dumps({'checks':len(instructions),'gridCases':len(rows),'tiles':sum(len(x['observed'])for x in rows),'output':str(output)}))
