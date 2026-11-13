"""Seal scoped108 source and54 original protocol proofs without credentials."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot-client'
read = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))
sha = lambda data: hashlib.sha256(data).hexdigest()
access = read(PROJECT / 'reports/native-record-target-access-v1-receipt.json')
server = read(PROJECT / 'reports/native-associate-record-gui-server-v1-receipt.json')
assert access['success'] and access['native']['checks'] == 23 and access['nodeChecks'] == 85
assert access['native']['cleanEngine'] and not access['native']['timedOut'] and access['native']['exitCode'] == 0
assert server['success'] and server['checks'] == 54 and server['serverCleaned'] and server['sessionClosed']
assert server['nativeOutputsPreserved'] and server['protectedProcessesPreserved']
assert server['protectedProfile']['unchanged'] and server['protectedProfile']['publicIdentityPreflight']['distinct']
run_access, run_server = Path(access['directory']).resolve(), Path(server['directory']).resolve()
assert run_access.is_relative_to(PROJECT / '.cache/associate-record-access-tests')
assert run_server.is_relative_to(PROJECT / '.cache/associate-record-gui-server-tests')
probe = read(run_server / 'probe.json')
assert probe['success'] and len(probe['guiWire']) == 8 and len(probe['receivedTokens']) == len(probe['receivedTlk']) == 4
before = PROJECT / '.cache/associate-record-access-tests/20261103-045100-before'
entries, pins, changes = {}, {}, []


def add(name, data):
    assert name not in entries and not Path(name).is_absolute() and '..' not in Path(name).parts
    assert not name.lower().endswith(('.dpapi', '.bic')) and '/logs/' not in name.lower()
    entries[name] = data


for row in access['inputs']:
    path = (ROOT / row['path']).resolve()
    assert path.is_relative_to(ROOT)
    pins[path] = row['sha256']
for row in server['sourceInputs']:
    path = (PROJECT / row['path']).resolve()
    assert path.is_relative_to(ROOT)
    assert path not in pins or pins[path] == row['sha256'], 'Source changed between accepted proof scopes'
    pins[path] = row['sha256']
for row in probe['sources']:
    path = (ROOT / row['path']).resolve()
    assert path.is_relative_to(ROOT) and (path not in pins or pins[path] == row['sha256'])
    pins[path] = row['sha256']
for path, digest in sorted(pins.items()):
    data = path.read_bytes()
    assert sha(data) == digest, 'Accepted uncopied JS input changed: ' + str(path.relative_to(ROOT))
    add('accepted-inputs/' + path.relative_to(ROOT).as_posix(), data)
for row in access['inputs']:
    if row['path'].endswith('.gd'):
        copied = run_access / 'project' / Path(row['path']).relative_to('godot-client')
        assert sha(copied.read_bytes()) == row['sha256']
for name in ['runner.json', 'adapter.json', 'adapter.engine.log', 'adapter.stdout.log', 'adapter.stderr.log', 'node.tap', 'node.stderr.log']:
    add('source108/' + name, (run_access / name).read_bytes())
for name in ['runner.json', 'probe.json', 'public-participant-verification.json']:
    add('original54/' + name, (run_server / name).read_bytes())
add('original54/fixture.json', (run_server / 'server/fixture.json').read_bytes())
module = (run_server / 'server/modules/AssocRecordGui.mod').read_bytes()
assert sha(module) == read(run_server / 'server/fixture.json')['sha256']
add('authored-module/AssocRecordGui.mod', module)
patch = []
for relative, filename in [('electron/network_game_session.mjs', 'network_game_session.mjs'),
                           ('godot-client/systems/native_gui_panel_access.gd', 'native_gui_panel_access.gd')]:
    old, new = (before / filename).read_bytes(), (ROOT / relative).read_bytes()
    if relative.startswith('electron/'):
        old_text, new_text = old.decode().replace('\r\n', '\n'), new.decode().replace('\r\n', '\n')
        imported = "import {nativeRecordTarget,nativeRecordFeatPresent} from '../src/network_record_target.js';\n"
        def outside_hud(text):
            first, last = text.index(' async hudPanel('), text.index(' async playerAttitude(', text.index(' async hudPanel('))
            return text[:first]+text[last:]
        assert outside_hud(new_text.replace(imported, '', 1)) == outside_hud(old_text), 'Session changes escaped approved import/hudPanel reservation'
    add('dirty-before/' + relative, old)
    changes.append({'path': relative, 'beforeSha256': sha(old), 'acceptedSha256': sha(new)})
    patch.extend(difflib.unified_diff(old.decode().splitlines(True), new.decode().splitlines(True), fromfile='dirty-before/'+relative, tofile='accepted/'+relative))
add('record-access-only.patch', ''.join(patch).encode())
add('dirty-before/before.json', (before / 'before.json').read_bytes())
for relative in ['godot-client/NATIVE-RECORD-TARGET-ACCESS.md', 'godot-client/reports/native-associate-record-input-v1-receipt.json',
                 'godot-client/reports/native-server-key-auth-research-v1.json', 'godot-client/reports/native-server-auth-methods-v1.json',
                 'godot-client/reports/native-server-auth-reasons-v1.json', 'scripts/inspect-native-server-key-auth.py',
                 'scripts/inspect-native-server-auth-methods.py', 'scripts/record-native-server-auth-reasons.py',
                 'godot-client/tests/audit_associate_record_auth.mjs']:
    add('evidence/' + relative, (ROOT / relative).read_bytes())
for folder in ['20261103-052543-0c687cf9', '20261103-052842-1d9f845d', '20261103-053458-5f41cfd2']:
    previous = PROJECT / '.cache/associate-record-gui-server-tests' / folder
    for name in ['runner.json', 'probe.json', 'sanitized-auth-classification.json', 'auth-config-audit.json']:
        if (previous / name).is_file():
            add('preserved-rejections/' + folder + '/' + name, (previous / name).read_bytes())
add('sealer.py', Path(__file__).read_bytes())
manifest = {'scope': 'Independent scoped108 native-adapter/Session source proof and54 original-server protocol proof. Companion native-controls proof is separately referenced; no composed live full-UI acceptance. Credential files, BICs and raw server logs are excluded; authorized public identity hashes remain metadata.',
            'sourceChecks': 108, 'originalProtocolChecks': 54, 'currentSourceInputs': len(pins), 'sharedChanges': changes,
            'entries': [{'path': name, 'bytes': len(data), 'sha256': sha(data)} for name, data in sorted(entries.items())]}
add('manifest.json', (json.dumps(manifest, indent=2)+'\n').encode())
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
destination = PROJECT / '.cache/record-target-access-checkpoints' / (stamp+'-sealed108-plus54')
destination.mkdir(parents=True, exist_ok=False)
archive = destination / 'native-record-target-access-v1.zip'
with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name, data in sorted(entries.items()): z.writestr(name, data)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None and len(z.infolist()) == len(entries)
    for name, data in entries.items(): assert sha(z.read(name)) == sha(data)
(destination / 'manifest.json').write_bytes(entries['manifest.json'])
result = {'success': True, 'archive': str(archive.relative_to(ROOT)), 'sha256': sha(archive.read_bytes()), 'entries': len(entries), 'bytes': archive.stat().st_size, 'currentSourceInputs': len(pins), 'sourceChecks': 108, 'originalProtocolChecks': 54, 'sharedChanges': changes}
(destination / 'checkpoint.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
print(json.dumps(result, indent=2))
