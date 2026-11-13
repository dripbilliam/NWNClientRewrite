"""Execute original shared skill allocator instructions after first level.
The current class, total level, active loaded rule records and existing point
WORD are explicit inputs. This verifies budget/cap/cost arithmetic, not the
entire level-up GUI, snapshot import, server admission or save lifecycle.
No live process, rendering or server connection is used.
"""
import copy, hashlib, importlib.util, json
from pathlib import Path

spec=importlib.util.spec_from_file_location('skills',Path(__file__).with_name('inspect-native-creation-skills.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)

if __name__=='__main__':
 source=s.m.root/'backups/animations/native-creation-skills-observations-v1.json'
 assert hashlib.sha256(source.read_bytes()).hexdigest()=='5c608eb2b37493295b6f3be7706f64a267d2ef68f0a0dd42ceca3db2969b0aca'
 out=s.m.root/'backups/animations/native-level-up-skills-observations-v1.json'
 assert not out.exists(),'Preserve previous evidence'
 cases=[]
 for at,row in enumerate(json.loads(source.read_text())['rows']):
  c=copy.deepcopy(row['case']);c['vital']['source']['level']=[2,3,10,20,40,60][at%6]
  c['unspent']=[0,1,17,32767,65535,-32768][at//6%6]
  cases.append(c)
 rows=[s.run(c)for c in cases]
 out.write_text(json.dumps(dict(binarySha256=s.m.digest,scope=__doc__,parentSha256=hashlib.sha256(source.read_bytes()).hexdigest(),procedures=[hex(a)for a,b in s.extra],rows=rows),indent=2))
 print(json.dumps(dict(output=str(out),sha256=hashlib.sha256(out.read_bytes()).hexdigest(),cases=len(rows),operations=sum(len(r['results'])for r in rows))))
