"""Original AnimateEvents04fce0 and Gob::DoEvent050d50 over exact installed
event arrays captured by the native Godot MDL/inheritance diagnostic. Only the
existing explicit wildcard listeners, allocation and ASCII comparator remain
captured boundaries. No original loader, animation clock, combat callback,
audio or renderer is substituted for an acceptance claim.
"""
from pathlib import Path
import sys,json,hashlib
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'scripts'))
source=root/'scripts/inspect-native-model-events.py'
namespace={'__name__':'native_installed_event_fixture','__file__':str(source)}
# Exclude that script's matrix/output writer. Its imported coordinator has an
# explicit __main__ guard; importing it does not regenerate another corpus.
exec(compile(source.read_text().split('sets=[',1)[0],str(source),'exec'),namespace)
receipt_path=root/'godot-client/reports/native-combat-installed-events-v1-receipt.json'
receipt=json.loads(receipt_path.read_text());assert receipt['success']
report_path=Path(receipt['report']).resolve()
assert report_path.is_relative_to((root/'godot-client/.cache/combat-installed-events').resolve())
report=json.loads(report_path.read_text());rows=[]
for item in report['observations']:
    events=item['physical']['events'];length=item['physical']['length']
    case=dict(fromTime=0,toTime=length,flags=0,events=events,direct=0,data=0,destroy=0)
    actual=namespace['run'](case)
    expected=[['listener',event['name'],listener] for event in events if 0<event['time']<=length for listener in [2,1]]
    assert actual['calls']==expected,(item['model'],item['clip'],actual['calls'],expected)
    assert actual['activeHandles']==0
    rows.append(dict(model=item['model'],clip=item['clip'],owner=item['owner'],ownerSha256=item['ownerSha256'],physicalEvents=events,nativeCalls=actual['calls'],activeHandles=actual['activeHandles']))
result=dict(success=True,binarySha256=namespace['m'].digest,scope=__doc__,sourceHarnessSha256=hashlib.sha256(source.read_bytes()).hexdigest(),nativeInputReceiptSha256=hashlib.sha256(receipt_path.read_bytes()).hexdigest(),nativeInputReportSha256=hashlib.sha256(report_path.read_bytes()).hexdigest(),cases=len(rows),rows=rows)
output=root/'godot-client/reports/native-combat-installed-events-original-v1.json'
output.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(dict(success=True,cases=len(rows),output=str(output),binarySha256=result['binarySha256'])))
