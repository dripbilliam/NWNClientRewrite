"""Exact JSON transport view for original qword callback observations.

Python JSON preserves the original integer. Godot JSON numbers are floating
point, so an unsigned qword such as FFFF...FFF9 cannot be safely reinterpreted
after parsing. Add its exact signed low DWORD before crossing that boundary.
The original observation/script is unchanged and hash-linked, not overwritten.
"""
from pathlib import Path
import argparse,hashlib,json
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--report',required=True);args=parser.parse_args()
source=root/'godot-client/reports/native-owned-associate-radial-original-v1.json'
original=source.read_bytes();view=json.loads(original)
assert view['success'] and (view['rootCases'],view['actionCases'],view['callbackCases'])==(48,8,68)
count=0
for group in ['roots','actions']:
 for row in view[group]:
  for entry in row['entries']:
   value=entry['argument'];assert isinstance(value,int) and 0<=value<=0xffffffffffffffff
   low=value&0xffffffff
   entry['argument32']=low-0x100000000 if low&0x80000000 else low
   count+=1
view['transportView']={'sourcePath':source.relative_to(root).as_posix(),'sourceSha256':hashlib.sha256(original).hexdigest(),'normalizerSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'entries':count,'scope':__doc__}
output=Path(args.report).resolve()
if output.exists():raise SystemExit('Refusing to overwrite prior transport view')
output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(view,indent=2)+'\n')
print(json.dumps({'success':True,'entries':count,'sourceSha256':view['transportView']['sourceSha256'],'report':str(output)}))
