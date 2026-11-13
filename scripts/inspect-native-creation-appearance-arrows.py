"""Unchanged native Appearance body/head arrows. Original branch/WORD/BYTE
operations execute; rule getter, actor lookup, head-resource Exists and model
refresh are explicit captured boundaries. No network or installed file writes.
"""
from pathlib import Path
import hashlib,json,struct,sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_RAX,UC_X86_REG_RSP,UC_X86_REG_RIP
binary=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(binary).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=binary);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
panel,actor,appearance,stack,stop=0x200000000,0x200010000,0x200020000,0x300000000,0x400000000
u.mem_map(panel,0x30000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
entries={'bodyNext':0x1408e0eb0,'bodyPrevious':0x1408e0f50,'headNext':0x1408e2ce0,'headPrevious':0x1408e2d30}
ranges=[(0x1408e0eb0,0x1408e0f48),(0x1408e0f50,0x1408e0ff2),(0x1408e2ce0,0x1408e2d2a),(0x1408e2d30,0x1408e2de0)]
def finish(value=0):
 rsp=u.reg_read(UC_X86_REG_RSP);ret=struct.unpack('<Q',u.mem_read(rsp,8))[0];u.reg_write(UC_X86_REG_RAX,value&0xffffffffffffffff);u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RIP,ret)
def hook(_u,address,_size,_data):
 if address==stop:u.emu_stop();return
 if address==0x1402ae870:calls.append({'kind':'hash'});finish(1);return
 if address==0x1402a4130:
  assert u.reg_read(UC_X86_REG_R8)&0xffffffff==5
  calls.append({'kind':'rule','default':5});finish(case['mask']);return
 if address==0x140800c90:finish(actor);return
 if address==0x14097b080:
  assert u.reg_read(UC_X86_REG_RCX)==appearance and u.reg_read(UC_X86_REG_RDX)==panel+0x167c
  head=struct.unpack('<H',u.mem_read(panel+0x174a,2))[0];calls.append({'kind':'headExists','id':head});finish(int(head in case['exists']));return
 if address==0x1408efc10:calls.append({'kind':'refresh'});finish();return
 assert any(lo<=address<=hi for lo,hi in ranges),hex(address)
u.hook_add(UC_HOOK_CODE,hook)
def run(kind,values):
 global case,calls
 case=values;calls=[];u.mem_write(panel,bytes(0x2000));u.mem_write(actor+0x300,struct.pack('<Q',appearance));u.mem_write(panel+0x1678,struct.pack('<I',23));u.mem_write(panel+0x174d,bytes([values.get('phenotype',0)]));u.mem_write(panel+0x174a,struct.pack('<H',values.get('head',1)))
 rsp=stack+0x1f008;u.mem_write(rsp,struct.pack('<Q',stop));u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,panel)
 u.emu_start(entries[kind],stop,count=100000)
 assert u.reg_read(UC_X86_REG_RIP)==stop
 return {'input':{'operation':kind,**values},'phenotype':u.mem_read(panel+0x174d,1)[0],'head':struct.unpack('<H',u.mem_read(panel+0x174a,2))[0],'calls':calls}
rows=[]
for mask in [0,1,5,0x80000000,0xaaaaaaaa,0xffffffff]:
 for current in range(32):
  for kind in ['bodyNext','bodyPrevious']:rows.append(run(kind,{'phenotype':current,'mask':mask}))
for exists in [[],[1],[1,2,3],[1,2,4],[0,1,2,255,256,257],list(range(1,301))]:
 for current in [0,1,2,3,255,256,257,65535]:
  for kind in ['headNext','headPrevious']:rows.append(run(kind,{'head':current,'exists':exists}))
result={'success':True,'binarySha256':digest,'scriptSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'cases':len(rows),'sourceEntries':{key:hex(value)for key,value in entries.items()},'scope':__doc__,'rows':rows}
output=root/'godot-client/reports/native-creation-appearance-arrows-original-v1.json';output.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'success':True,'cases':len(rows),'report':str(output),'network':False,'gpu':False}))
