"""Complete original shared constructor on installed API arities and captured
active-data query results/table counts. The 2DA queries are explicit replay
boundaries, while original selector/validation/control/cleanup executes. No
item mutation/equipment, client scene or complete spell readiness claim.
"""
import importlib,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
a=importlib.import_module('inspect-native-item-property-factory');m=a.m
source=json.loads((m.root/'backups/animations/live-item-property-factory.json').read_text());rows=[]
for row in source['rows']:
 for entry in row['case']['replay']:
  result=entry.get('result')
  if result and result['name'] not in a.tables:
   ptr=m.heap+0x90000+len(a.tables)*0x100;a.tables[result['name']]=ptr;a.names[ptr]=result['name']
for row in source['rows']:
 result=a.run(row['case'])
 assert {k:result[k] for k in ['type','durationType','integers']}=={k:row[k] for k in ['type','durationType','integers']},(row['name'],row['case']['args'],result)
 assert result['result']==0
 rows.append(dict(name=row['name'],**result))
out=m.root/'backups/animations/native-live-item-property-factory-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
