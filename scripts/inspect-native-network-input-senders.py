"""Read-only instruction candidates for native lowercase-p input senders.

Use REA's complete analyzed function-body ranges for callers of 1407c25c0.
An immediate DL/EDX=6 before a transport call is a candidate only: follow with
the full function dossier and original-code scalar-writer oracle.
"""
import hashlib,json,struct,argparse
from pathlib import Path
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
root=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser();parser.add_argument('--major',type=int,default=6);major=parser.parse_args().major
assert 0<=major<=255
data=(root/'../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=struct.unpack_from('<I',data,0x3c)[0];num=struct.unpack_from('<H',data,pe+6)[0];opt=struct.unpack_from('<H',data,pe+20)[0]
sections=[struct.unpack_from('<IIII',data,pe+24+opt+i*40+8)for i in range(num)]
def read(a,size):
 rva=a-0x140000000
 off=next(raw+rva-va for vs,va,n,raw in sections if va<=rva and rva+size<=va+max(vs,n))
 return data[off:off+size]
d=json.loads((root/'backups/animations/rea-network-client-envelope-sender.json').read_text())['structuredContent']['normalized_result']
cs=Cs(CS_ARCH_X86,CS_MODE_64);found=[]
for proc in d['callers']:
 for body in proc['body']['ranges']:
  start,end=int(body['start'],16),int(body['end'],16)
  ins=list(cs.disasm(read(start,end-start+1),start))
  for i,v in enumerate(ins):
   if v.mnemonic!='call' or v.op_str!='0x1407c25c0':continue
   before=ins[max(0,i-18):i]
   if any(x.mnemonic=='mov' and x.op_str in [f'{reg}, {value}'for reg in ['edx','dl']for value in [str(major),hex(major)]] for x in before):
    found.append(dict(procedure=proc['address'],call=hex(v.address),setup=[dict(address=hex(x.address),instruction=x.mnemonic+' '+x.op_str)for x in before]))
report=dict(target=digest,major=major,scope='Instruction candidates; not a complete input protocol or semantic proof',candidates=found)
name='native-network-input-sender-candidates.json'if major==6 else f'native-network-sender-candidates-{major}.json'
(root/'backups/animations'/name).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(candidates=len(found),procedures=[x['procedure']for x in found])))
