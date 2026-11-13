"""Original Class OK creation branch with remaining-point and alignment fields.
Reuses the pinned vital instruction harness, recording its additional raw fields
rather than inferring them from UI or stat labels. Original modal lifecycle,
lookup and allocation boundaries are the documented vital harness providers.
"""
import copy,importlib.util,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('vitals',Path(__file__).with_name('inspect-native-creation-vitals.py'))
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
original_snapshot=v.snapshot;original_call=v.call
def snapshot():
 result=original_snapshot()
 result.update(points=int(v.u.mem_read(v.actor+0x10c,1)[0]),goodEvil=int.from_bytes(v.u.mem_read(v.actor+0xc6,2),'little'),lawChaos=int.from_bytes(v.u.mem_read(v.actor+0xc8,2),'little'))
 return result
def call(address,args):
 if address==0x1408e36d0:v.m.wi(v.races+0x54,v.case['tables']['racialtypes']['orderedRows'][0]['AbilitiesPointBuyNumber'])
 return original_call(address,args)
v.snapshot=snapshot;v.call=call
if __name__=='__main__':
 out=v.m.root/'backups/animations/native-creation-class-commit-observations-v1.json';assert not out.exists(),'Preserve earlier evidence'
 old=json.loads((v.m.root/'backups/animations/native-creation-vitals-observations-v1.json').read_text())
 cases=[]
 for index,row in enumerate(old['rows']):
  c=copy.deepcopy(row['case']);c['tables']['racialtypes']['orderedRows'][0]['AbilitiesPointBuyNumber']=[30,286,0,255][index%4]
  for entry in c['tables']['classes']['orderedRows']:entry['PlayerClass']=1
  cases.append(c)
 c=copy.deepcopy(cases[0]);c['operations']=[dict(kind='class',id=id)for id in range(15)]
 cases.append(c)
 rows=[v.run(c)for c in cases]
 out.write_text(json.dumps(dict(binarySha256=v.m.digest,scope=__doc__,procedure='0x1408e36d0',rows=rows),indent=2))
 print(json.dumps(dict(output=str(out),cases=len(rows),operations=sum(len(r['results'])for r in rows))))

