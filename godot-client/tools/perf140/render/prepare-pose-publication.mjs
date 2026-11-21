import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const id = process.argv[2];
if (!/^[a-z0-9-]+$/i.test(id ?? '')) throw Error('Fresh private candidate identifier required');
const stage = path.join(project, '.cache/native-140fps/render-agent', id);
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
if (process.argv.includes('--finalize')) {
  const file = path.join(stage, 'manifest.json');
  const receipt = JSON.parse(fs.readFileSync(file));
  const proofFile = path.join(stage, 'build.json');
  const proof = JSON.parse(fs.readFileSync(proofFile));
  if (!proof.success || proof.changedGuards.length || receipt.builds !== 0) throw Error('Private build does not pass finalization');
  for (const pin of receipt.pins) {
    const sha = hash(fs.readFileSync(path.join(receipt.project, pin.relative)));
    if (!['.cache/native-kernel/nwn-particle-kernel.dll', '.cache/native-kernel/build-manifest.json'].includes(pin.relative) && pin.sha256 !== sha) throw Error('Unexpected private build mutation: ' + pin.relative);
    pin.sha256 = sha;
  }
  receipt.builds = 1;
  receipt.build = {proofFile, binarySha256: proof.binarySha256};
  fs.writeFileSync(file, JSON.stringify(receipt, null, 2));
  console.log(JSON.stringify({finalized: true, stage}));
  process.exit(0);
}
if (fs.existsSync(stage)) throw Error('Existing evidence must be preserved');
const baselineManifest = path.join(project, '.cache/native-140fps/root/common-v1/manifest.json');
const baseline = JSON.parse(fs.readFileSync(baselineManifest));
const destination = path.join(stage, 'project');
fs.mkdirSync(destination, {recursive: true});
const pins = [], inputs = [], edits = [];
for (const pin of baseline.pins) {
  const bytes = fs.readFileSync(path.join(baseline.project, pin.relative));
  if (hash(bytes) !== pin.sha256) throw Error('Witness input changed: ' + pin.relative);
  const target = path.join(destination, pin.relative);
  fs.mkdirSync(path.dirname(target), {recursive: true});
  fs.writeFileSync(target, bytes, {flag: 'wx'});
  pins.push({...pin});
}
function install(relative, bytes, source) {
  if (typeof bytes === 'string') bytes = Buffer.from(bytes);
  const target = path.join(destination, relative);
  fs.mkdirSync(path.dirname(target), {recursive: true});
  fs.writeFileSync(target, bytes);
  let pin = pins.find(value => value.relative === relative);
  if (!pin) { pin = {relative}; pins.push(pin); }
  pin.sha256 = hash(bytes);
  edits.push({relative, source, sha256: pin.sha256});
}
function own(relative, target = relative) {
  const bytes = fs.readFileSync(path.join(project, relative));
  inputs.push({relative, sha256: hash(bytes)});
  install(target, bytes, relative);
}
const guarded = process.argv.includes('--guarded');
const delayed = guarded || process.argv.includes('--delayed');
own(guarded ? 'tools/perf140/render/model_pose_storage_publication_guarded_candidate.hpp' : delayed ? 'tools/perf140/render/model_pose_storage_publication_delayed_candidate.hpp' : 'tools/perf140/render/model_pose_storage_publication_candidate.hpp', 'native/model_pose_storage.hpp');
const testPath = 'tests/native_perf140_render_pose_publication_test.gd';
if (delayed) {
  const bytes = fs.readFileSync(path.join(project, testPath));
  inputs.push({relative: testPath, sha256: hash(bytes)});
  let content = bytes.toString('utf8');
  for (const [from, to] of [['maxi(0, frame - 1)', 'maxi(0, frame - 2)'], ['if frame < 2:', 'if frame < 3:']]) {
    if (content.split(from).length !== 2) throw Error('Delayed warm-gate fixture boundary changed: ' + from);
    content = content.replace(from, to);
  }
  const marker = '\tvar before_manual := stats(value)';
  if (content.split(marker).length !== 2) throw Error('Delayed changing-input fixture boundary changed');
  const probe = '\tfor frame in 16:\n\t\twrite(value, 16, [100.0 + frame, -2.0, 0.3])\n\t\tvar before := stats(value)\n\t\tpublish(value, "Always-changing source " + str(frame))\n\t\tcheck(stats(value).publication_getters == before.publication_getters, "Changed source adds no cache getters")\n\t\tcheck(stats(value).publication_setter_writes == before.publication_setter_writes + 3, "Changed source retains all original setters")\n';
  content = content.replace(marker, probe + marker);
  if (guarded) {
    const codeMarker = 'func _initialize() -> void:';
    if (content.split(codeMarker).length !== 2) throw Error('Guarded script callback fixture boundary changed');
    const callbacks = String.raw`func unchanged_callback_lifetime() -> void:
	var scripted := owner(true)
	for frame in 6:
		publish(scripted, "Script callback warm " + str(frame))
	check(int(stats(scripted).publication_skips) == 0 and int(stats(scripted).publication_script_blocks) > 0, "Script notification callback blocks every warm reuse")
	scripted.target.calls = 0
	scripted.target.close_at = 1
	var closed: Dictionary = scripted.context.call("dispatch", 2, {"manual": {}, "profile": false, "scope": null})
	check(bool(closed.get("closed", false)) and not closed.has("error"), "Script closes owner on unchanged warmed publication")
	check(scripted.target.calls == 1 and int(stats(scripted).parts) == 0, "Unchanged script close stops after original first setter")
	scripted.target.close_at = 0
	dispose(scripted)
	var late := owner()
	for frame in 6:
		publish(late, "Before script attachment " + str(frame))
	check(int(stats(late).publication_skips) > 0, "Plain constructed Part really reuses before script attachment")
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar owner_context: RefCounted\nvar calls := 0\nfunc _notification(what: int) -> void:\n\tif what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and owner_context != null:\n\t\tcalls += 1\n\t\towner_context.call(\"dispatch\", 8, {})\n"
	check(script.reload() == OK, "Known local script fixture compiles")
	late.target.set_script(script)
	late.target.set("owner_context", late.context)
	late.target.set_notify_local_transform(true)
	var late_closed: Dictionary = late.context.call("dispatch", 2, {"manual": {}, "profile": false, "scope": null})
	check(bool(late_closed.get("closed", false)) and not late_closed.has("error"), "Live method query catches attachment without matrix/source change")
	check(int(late.target.get("calls")) == 1, "Attached script receives the original first setter callback")
	late.target.set("owner_context", null)
	dispose(late)

`;
    content = content.replace(codeMarker, callbacks + codeMarker);
    const callMarker = '\t\tcallback_lifetime()';
    if (content.split(callMarker).length !== 2) throw Error('Guarded script callback invocation boundary changed');
    content = content.replace(callMarker, callMarker + '\n\t\tunchanged_callback_lifetime()');
  }
  install(testPath, content, 'Original dedicated test with conservative third-publication warm boundary plus changing-input zero-getter checks; other assertions retained');
} else own(testPath);
own('tests/native_perf140_render_pose_publication_resources_test.gd');
if (guarded) {
  const entryPath = 'native/particle_kernel.cpp';
  const originalEntry = fs.readFileSync(path.join(destination, entryPath), 'utf8');
  const marker = ' if(!visual_selection::bind(address))return false;';
  if (originalEntry.split(marker).length !== 2) throw Error('Pinned native bootstrap bind boundary changed');
  install(entryPath, originalEntry.replace(marker, marker + '\n if(!model_pose_storage::bind(address))return false;'), 'One private ABI initialization line for the pinned non-invoking Object script-method query');
}
const originalProject = fs.readFileSync(path.join(destination, 'project.godot'), 'utf8');
install('project.godot', originalProject.replace(/\[autoload\][\s\S]*?(?=\n\[|$)/, ''), 'Private headless component capsule: no application autoloads/session initialization');
// Keep the common witness particle+resource extensions. Resource fixtures mount
// only the installed original local files; they never initialize a session.
const receipt = {version: 1, id, delayed, guarded, project: destination, baselineManifest, baselineManifestSha256: hash(fs.readFileSync(baselineManifest)), baselineProject: baseline.project, pins, inputs, edits, builds: 0, enginesStarted: 0, gpu: false, serverConnections: 0, scope: 'Retained original-setter publication only. No shared source, native outputs, application autoloads, commands or visual-policy edits.'};
fs.writeFileSync(path.join(stage, 'manifest.json'), JSON.stringify(receipt, null, 2), {flag: 'wx'});
console.log(JSON.stringify({prepared: true, stage, project: destination, pins: pins.length}, null, 2));
