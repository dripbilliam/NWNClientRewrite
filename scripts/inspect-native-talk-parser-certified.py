"""Supplemental unchanged ParseStr cases. Original parser/hash/string routines
execute; heap/copy/compare and named callbacks are authored lower boundaries.
Retained context/flags vary but these callbacks do not simulate game providers.
No UI, game process, server or native writer is executed.
"""
import importlib,sys,json,hashlib,itertools,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(Path(__file__).resolve().parent))
label=sys.argv[1] if len(sys.argv)>1 else ''
assert re.fullmatch('[a-z0-9-]{3,80}',label)
directory=root/'godot-client/.cache/native-talk-parse'/label
assert not directory.exists(),'Preserve prior evidence'
directory.mkdir(parents=True)
prior=root/'backups/animations/native-talk-token-parser-observations.json'
prior_hash=hashlib.sha256(prior.read_bytes()).hexdigest()
p=importlib.import_module('inspect-native-talk-token-parser')
execute=p.execute
current_state={}
def patched_execute(start,args):
    if start==0x140199e20:
        p.m.wi(p.table+0x4c,current_state['suppression'])
        p.m.wi(p.table+0xb8,current_state['b8']);p.m.wi(p.table+0xbc,current_state['bc'])
        p.m.wq(p.table+0xb0,current_state['context'])
        p.u.mem_write(p.table+0x28,bytes([current_state['gender']]))
    return execute(start,args)
p.execute=patched_execute
rgb=b'<c\xff\x01\x01>'
texts=[b'plain',b'<<',b'<<NAME>',b'<<<CUSTOM42>',rgb+b'tag</c>',b'<'+rgb+b'tag<</c>',b'<CUSTOM42>',b'<NAME>',b'a<HIDE>hidden<CUSTOM42><NAME><SHOW>tail',b'<UNKNOWN>',b'<CUSTOM4294967338>',b'<<c\x01\xfe\x01>escaped<</c>']
states=[dict(suppression=s,b8=b8,bc=bc,context=context,gender=gender) for s,b8,bc,context,gender in [(77,0,0,0,0),(-1,1,1,p.m.heap+0x9000,1),(0,2,-1,p.m.heap+0x8000,0),(1,-1,2,0,1)]]
replacements=[b'VALUE',rgb+b'generated</c>',b'<CUSTOM10>']
rows=[]
for raw,named,replacement,state in itertools.product(texts,[False,True],replacements,states):
    current_state=state
    case=dict(input=raw.hex(),tokens=[dict(id=10,value=b'ten'.hex()),dict(id=42,value=replacement.hex())],named=named,namedValue=replacement.hex())
    row=p.run(case);row['retainedState']=state;rows.append(row)
checks=[]
for row in rows:
    raw=bytes.fromhex(row['case']['input']);result=bytes.fromhex(row['value'])
    if raw==rgb+b'tag</c>':checks.append(result==b'<UNRECOGNIZED TOKEN>tag<UNRECOGNIZED TOKEN>' and not row['calls'])
    if raw==b'<'+rgb+b'tag<</c>':checks.append(result==rgb+b'tag</c>' and not row['calls'])
    if raw==b'<CUSTOM42>':checks.append(result==bytes.fromhex(row['case']['tokens'][1]['value']) and not row['calls'])
    if raw==b'<NAME>' and row['case']['named']:checks.append(result==bytes.fromhex(row['case']['namedValue']) and row['calls']==[0])
unchanged=prior_hash==hashlib.sha256(prior.read_bytes()).hexdigest()
record=dict(schema='native-talk-parser-certified-original-v1',success=all(checks)and unchanged,binarySha256=p.m.digest,limits=__doc__,rows=rows,checks=len(checks),failedChecks=sum(not value for value in checks),priorCorpus=dict(path=str(prior.relative_to(root)),sha256=prior_hash,unchanged=unchanged),instructionsModified=False,engine=False,serverConnections=0)
out=directory/'result.json';out.write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(dict(output=str(out),rows=len(rows),checks=len(checks),failedChecks=record['failedChecks'],priorCorpusUnchanged=unchanged,success=record['success'])))
sys.exit(0 if record['success'] else 1)
