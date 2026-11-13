"""Seal exact713 accepted inputs, modal-only follow-up diffs and failures."""
from pathlib import Path
import datetime,difflib,hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[1];PROJECT=ROOT/'godot-client'
receipt_path=PROJECT/'reports/native-modal-owners-v2-receipt.json'
r=json.loads(receipt_path.read_text(encoding='utf-8-sig'));assert r['success'] and not r['diagnosticOnly']
assert len(r['results'])==10 and sum(int(x['checks'])for x in r['results'])==691 and r['protocolTests']==22
assert all(x['success']and x['exitCode']==0 and x['cleanEngine']and not x['timedOut']for x in r['results'])
run=Path(r['directory']).resolve();assert run.is_relative_to(PROJECT/'.cache/modal-owner-followup-tests')
previous=PROJECT/'.cache/modal-owner-tests/20261103-011035-c0e63886/project'
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
target=PROJECT/'.cache/modal-owner-checkpoints'/f'{stamp}-sealed713';assert not target.exists();target.mkdir(parents=True)
sha=lambda data:hashlib.sha256(data).hexdigest()
files={};changed=[]
def add(name,data):
    assert name not in files and not Path(name).is_absolute()and'..'not in Path(name).parts
    files[name]=data
owned=['systems/native_data/modal_lease.gd','systems/native_modal_surfaces.gd','systems/native_gold_transfer.gd','systems/native_map_note_editor.gd']
for entry in r['inputs']:
    current=(PROJECT/entry['path']).resolve();copied=(run/'project'/entry['path']).resolve()
    assert current.is_relative_to(ROOT)and copied.is_relative_to(run)
    data=copied.read_bytes();assert sha(data)==entry['sha256'],entry['path']
    now=sha(current.read_bytes())
    if now!=entry['sha256']:changed.append({'path':entry['path'],'acceptedSha256':entry['sha256'],'currentSha256':now})
    if entry['path']in owned:assert now==entry['sha256'],'Owned modal source changed before seal'
    add('accepted-inputs/'+current.relative_to(ROOT).as_posix(),data)
for path in run.iterdir():
    if path.is_file():add('accepted-run/'+path.name,path.read_bytes())
add('accepted-run/project.godot',(run/'project/project.godot').read_bytes())
patch=[];changes=[]
for relative in owned:
    before=(previous/relative).read_bytes();after=(run/'project'/relative).read_bytes()
    add('before668/godot-client/'+relative,before)
    changes.append({'path':'godot-client/'+relative,'beforeSha256':sha(before),'acceptedSha256':sha(after)})
    patch.extend(difflib.unified_diff(before.decode().splitlines(True),after.decode().splitlines(True),fromfile='sealed668/'+relative,tofile='accepted713/'+relative))
add('modal-followup-only.patch',''.join(patch).encode())
for name in ['NATIVE-MODAL-OWNERS.md','NATIVE-MODAL-OWNERS-PLAN.md','NATIVE-MODAL-ORDER.md']:
    add('documentation/'+name,(PROJECT/name).read_bytes())
for name in ['20261103-015515-e858bcd2','20261103-021723-d1ab778f','20261103-022340-98c9ed7b']:
    folder=PROJECT/'.cache/modal-owner-followup-tests'/name
    for path in folder.iterdir():
        if path.is_file():add('preserved-amount-evidence/'+name+'/'+path.name,path.read_bytes())
    add('preserved-amount-evidence/'+name+'/fixture.gd',(folder/'project/tests/native_modal_amount_map_input_test.gd').read_bytes())
geometry=PROJECT/'.cache/modal-surface-geometry-tests'
for folder in sorted(geometry.iterdir()):
    if not folder.is_dir()or not(folder/'runner.json').exists():continue
    for path in folder.iterdir():
        if path.is_file():add('preserved-geometry-evidence/'+folder.name+'/'+path.name,path.read_bytes())
    for path in (folder/'project').rglob('*.gd'):
        add('preserved-geometry-evidence/'+folder.name+'/project/'+path.relative_to(folder/'project').as_posix(),path.read_bytes())
for relative in ['.cache/modal-surface-geometry-tests/20261103-012054-23a27b9d-before-fix','.cache/modal-surface-geometry-tests/20261103-021256-22e2b61e-before-focus-fix','.cache/modal-owner-followup-tests/before-exact-panel-owner','.cache/modal-owner-followup-tests/20261103-021723-d1ab778f-before-late-move-fix']:
    folder=ROOT/relative
    for path in folder.rglob('*'):
        if path.is_file():add('dirty-before/'+folder.name+'/'+path.relative_to(folder).as_posix(),path.read_bytes())
root_rejection=PROJECT/'.cache/domains-binding-tests/20261103-012656-53523546'
for path in root_rejection.iterdir():
    if path.is_file():add('preserved-root-configure-rejection/'+path.name,path.read_bytes())
add('sealer.py',Path(__file__).read_bytes())
manifest={'scope':'Exact713 pinned snapshot; four modal-only follow-up diffs, original668 historical reference and preserved geometry/focus/amount/configure failures. No blanket latest-main, original pixels, live user-client or complete modal53/2 coverage claim.',
          'nativeChecks':691,'protocolChecks':22,'sharedChanges':changes,'currentUnrelatedDifferences':changed,
          'previous668ArchiveSha256':'151a2ac9f30712c458efc8a921c0b4780a0467c3410e604000f340cf356a8866',
          'bootstrap':'native_session_world setup caller is outside713 preload closure; historical668 archive preserves its separate source/diff',
          'entries':[{'path':name,'bytes':len(data),'sha256':sha(data)}for name,data in sorted(files.items())]}
data=(json.dumps(manifest,indent=2)+'\n').encode();add('manifest.json',data)
archive=target/'native-modal-owners-v2.zip'
with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6)as z:
    for name,data in sorted(files.items()):z.writestr(name,data)
with zipfile.ZipFile(archive)as z:
    assert z.testzip()is None and len(z.infolist())==len(files)
    for name,data in files.items():assert sha(z.read(name))==sha(data)
(target/'manifest.json').write_bytes(files['manifest.json'])
result={'success':True,'archive':str(archive.relative_to(ROOT)),'sha256':sha(archive.read_bytes()),'bytes':archive.stat().st_size,'entries':len(files),'checks':713,'currentUnrelatedDifferences':changed,'sharedChanges':changes}
(target/'checkpoint.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
