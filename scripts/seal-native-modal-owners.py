"""Seal the exact accepted modal668 snapshot and preserved rejected evidence."""
from pathlib import Path
import datetime, difflib, hashlib, json, zipfile

ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'godot-client'
receipt_path=PROJECT/'reports/native-modal-owners-v1-receipt.json'
receipt=json.loads(receipt_path.read_text(encoding='utf-8-sig'))
assert receipt['success'] and len(receipt['results'])==8
assert sum(int(r['checks']) for r in receipt['results'])==646 and receipt['protocolTests']==22
assert all(r['success'] and r['cleanEngine'] and r['exitCode']==0 and not r['timedOut'] for r in receipt['results'])
run=Path(receipt['directory']).resolve()
assert run.is_relative_to(PROJECT/'.cache/modal-owner-tests')
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
target=PROJECT/'.cache/modal-owner-checkpoints'/f'{stamp}-sealed668'
assert not target.exists()
target.mkdir(parents=True)
files={}
sha=lambda value:hashlib.sha256(value).hexdigest()
def add(name,data):
    assert name not in files and not Path(name).is_absolute() and '..' not in Path(name).parts
    files[name]=data
for row in receipt['inputs']:
    current=(PROJECT/row['path']).resolve();copied=(run/'project'/row['path']).resolve()
    assert current.is_relative_to(ROOT) and copied.is_relative_to(run)
    data=copied.read_bytes()
    assert sha(data)==row['sha256'] and sha(current.read_bytes())==row['sha256'],row['path']
    add('accepted-inputs/'+current.relative_to(ROOT).as_posix(),data)
add('accepted-run/project.godot',(run/'project/project.godot').read_bytes())
for child in run.iterdir():
    if child.is_file():add('accepted-run/'+child.name,child.read_bytes())
for name in ['NATIVE-MODAL-OWNERS.md','NATIVE-MODAL-OWNERS-PLAN.md','NATIVE-MODAL-ORDER.md']:
    add('documentation/'+name,(PROJECT/name).read_bytes())
reports=['native-modal-owner-boundaries-v1.json','native-radial-superseded-original-v1.json','native-radial-superseded-original-v2.json','native-gui-modal-rtti-v2.json','native-modal-activation-research-v1.json','native-modal-activation-callers-v2.json','native-topmodal-close-original-v1.json']
for name in reports:add('original-evidence/'+name,(PROJECT/'reports'/name).read_bytes())
for name in ['inspect-native-modal-owner-boundaries.py','inspect-native-radial-superseded.py','inspect-native-radial-superseded-v2.py','inspect-native-gui-rtti.py','inspect-native-modal-activations.py','seal-native-modal-owners.py']:
    add('research-scripts/'+name,(ROOT/'scripts'/name).read_bytes())
before=ROOT/'.cache/modal-owner-tests/20261102-195159-before'
patch=[];changes=[];uncovered=[]
for path in before.rglob('*'):
    if not path.is_file():continue
    rel=path.relative_to(before).as_posix();data=path.read_bytes();add('before/'+rel,data)
    if rel.startswith('godot-client/'):
        relative=Path(rel).relative_to('godot-client').as_posix()
        copied=run/'project'/relative
        if copied.exists():
            accepted=copied.read_bytes();coverage='668_pinned_input'
        else:
            # Preserve a caller outside this fixture's actual preload closure
            # without inventing bootstrap acceptance from owner tests.
            assert relative=='native_session_world.gd'
            accepted=(ROOT/rel).read_bytes();coverage='setup_hook_outside_668_preload_closure'
            uncovered.append({'path':rel,'sha256':sha(accepted),'reason':coverage})
            add('uncovered-current/'+rel,accepted)
        if data!=accepted:
            changes.append({'path':rel,'beforeSha256':sha(data),'stagedSha256':sha(accepted),'coverage':coverage})
            patch.extend(difflib.unified_diff(data.decode('utf-8-sig').splitlines(True),accepted.decode('utf-8-sig').splitlines(True),fromfile='before/'+rel,tofile='accepted/'+rel))
add('shared-owner-only.patch',''.join(patch).encode())
for name in ['20261103-010307-3711aefb','20261103-010601-1462dd6e']:
    rejected=PROJECT/'.cache/modal-owner-tests'/name
    for child in rejected.iterdir():
        if child.is_file():add('preserved-rejections/'+name+'/'+child.name,child.read_bytes())
    add('preserved-rejections/'+name+'/native_modal_owner_input_test.gd',(rejected/'project/tests/native_modal_owner_input_test.gd').read_bytes())
diagnostic=PROJECT/'.cache/modal-owner-diagnostics/20261103-010734-03f3e1a9'
for child in diagnostic.iterdir():
    if child.is_file():add('preserved-hit-diagnostic/'+child.name,child.read_bytes())
add('preserved-hit-diagnostic/native_modal_owner_input_test.gd',(diagnostic/'project/tests/native_modal_owner_input_test.gd').read_bytes())
add('preserved-hit-diagnostic/runner.ps1',(PROJECT/'tools/test-native-modal-owner-diagnostic.ps1').read_bytes())
manifest={'scope':'Exact accepted modal668 input snapshot plus owner-only dirty backups/diff, static original witnesses and preserved rejected/diagnostic receipts. Not blanket current-main/full modal coverage/pixels/live-client/server acceptance.',
          'receipt':str(receipt_path.relative_to(ROOT)),'nativeChecks':646,'protocolChecks':22,'sharedChanges':changes,'uncoveredSharedHooks':uncovered,'inputs':[{'entry':name,'sha256':sha(data),'bytes':len(data)}for name,data in sorted(files.items())]}
manifest_data=(json.dumps(manifest,indent=2)+'\n').encode();add('manifest.json',manifest_data)
archive=target/'native-modal-owners-v1.zip'
with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for name,data in sorted(files.items()):z.writestr(name,data)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None and len(z.infolist())==len(files)
    for name,data in files.items():assert sha(z.read(name))==sha(data)
result={'success':True,'archive':str(archive.relative_to(ROOT)),'sha256':sha(archive.read_bytes()),'bytes':archive.stat().st_size,'entries':len(files),'sharedChanges':changes,'nativeChecks':646,'protocolChecks':22}
(target/'manifest.json').write_bytes(manifest_data)
(target/'checkpoint.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
