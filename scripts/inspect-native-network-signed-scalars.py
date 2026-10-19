"""Original CHAR/SHORT writers and readers, full and reduced widths.

Allocation/copy boundaries use the existing synthetic A5 heap fixture. No live
process mutation. Native ReadSigned negative-zero normalization executes intact.
"""
import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
ranges=[]
for name in ['read-char','read-short','write-char','write-short']:
 d=json.loads((m.root/'backups/animations'/('rea-network-'+name+'.json')).read_text())['structuredContent']['normalized_result']
 ranges.extend((int(x['start'],16),int(x['end'],16)+1)for x in d['procedure']['body']['ranges'])
def hook(u,a,n,data):
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for format in [0,1]:
 for kind,writer,reader,bitsList in [('char',0x1402dacb0,0x1402d98d0,[1,2,5,7,8]),('short',0x1402db790,0x1402da110,[1,2,9,15,16])]:
  for bits in bitsList:
   for value in [0,1,-1,127,-128,255,-32768,32767]:
    t.reset(dict(format=format));w.call(writer,[w.message,value,bits]);packet=bytes.fromhex(w.snapshot()['hex']);u.mem_write(t.inputBase,packet[3:]);m.wi(m.stack+0x1fe08+0x28,1)
    assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
    nativeReturn=w.call(reader,[w.message,bits]);width=8 if kind=='char'else 16;native=nativeReturn&((1<<width)-1);native=native-(1<<width)if native&(1<<(width-1))else native
    rows.append(dict(format=format,kind=kind,bits=bits,value=value,packet=packet.hex(),nativeReturn=nativeReturn,read=native))
output=m.root/'backups/animations/native-network-signed-scalars-observations.json'
output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n')
print(json.dumps(dict(cases=len(rows),output=str(output))))
