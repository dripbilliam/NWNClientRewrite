const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const root = path.resolve(__dirname, '..');
const source = 'systems/native_render/native_client_support_scene.gd';
const output = '.cache/nwn63/support-diagnostic-a/native_client_support_scene.gd';
const expected = '853831ed4675bbbba09056cd3bd4013eca058fc0f0848769928531d3a3cbd5fc';
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const bytes = fs.readFileSync(path.join(root, source));
if (hash(bytes) !== expected) throw new Error('NWN-63 adapter source changed; review before regenerating');
let body = bytes.toString('utf8');
function once(before, after) {
  const first = body.indexOf(before);
  if (first < 0 || body.indexOf(before, first + before.length) >= 0) throw new Error(`missing/nonunique anchor: ${before.slice(0, 60)}`);
  body = body.slice(0, first) + after + body.slice(first + before.length);
}
once('extends RefCounted\n', 'extends RefCounted\nconst Profile=preload("res://systems/native_render/frame_profile.gd")\n');
once('var _busy:=false\n', 'var _busy:=false\nvar _diagnostic_query_began:=0\n');
once('func _checked_world(revision: int=-1) -> Node:\n',
  'func _checked_world(revision: int=-1) -> Node:\n' +
  '\tvar began:=Profile.begin()\n' +
  '\tvar result:=_checked_world_unprofiled(revision)\n' +
  '\tProfile.finish("client_support_validation",began)\n' +
  '\tProfile.count("count_client_support_validations",1)\n' +
  '\treturn result\n' +
  'func _checked_world_unprofiled(revision: int=-1) -> Node:\n');
once('func _trace(start: Vector3,end: Vector3) -> Dictionary:\n',
  'func _trace(start: Vector3,end: Vector3) -> Dictionary:\n' +
  '\tvar began:=Profile.begin()\n' +
  '\tvar result:=_trace_unprofiled(start,end)\n' +
  '\tProfile.finish("client_support_ray",began)\n' +
  '\tProfile.count("count_client_support_rays",1)\n' +
  '\treturn result\n' +
  'func _trace_unprofiled(start: Vector3,end: Vector3) -> Dictionary:\n');
once('\tvar hit: Dictionary=SceneHit.trace(owner,[start.x,start.y,start.z],[end.x,end.y,end.z],true,true)\n',
  '\tvar scene_began:=Profile.begin()\n' +
  '\tvar hit: Dictionary=SceneHit.trace(owner,[start.x,start.y,start.z],[end.x,end.y,end.z],true,true)\n' +
  '\tProfile.finish("client_support_scene_trace",scene_began)\n');
once('\t_busy=true\n\tvar owner:=_checked_world()\n',
  '\t_busy=true\n' +
  '\t_diagnostic_query_began=Profile.begin()\n' +
  '\tProfile.count("count_client_support_queries",1)\n' +
  '\tvar owner:=_checked_world()\n');
once('\t\t_stats.unavailable+=1; _stats.last_branch=""; _stats.last_reason=str(result.get("reason","Client support unavailable"))\n\treturn result\n',
  '\t\t_stats.unavailable+=1; _stats.last_branch=""; _stats.last_reason=str(result.get("reason","Client support unavailable"))\n' +
  '\tProfile.finish("client_support_query",_diagnostic_query_began)\n' +
  '\t_diagnostic_query_began=0\n' +
  '\treturn result\n');
const destination = path.join(root, output);
fs.mkdirSync(path.dirname(destination), { recursive: true });
fs.writeFileSync(destination, body);
const receipt = {
  scope: 'Private FrameProfile diagnostic overlay only; not an accepted project or FPS result',
  source, sourceSha256: expected, overlay: output, overlaySha256: hash(body),
  frameProfileSha256: hash(fs.readFileSync(path.join(root, 'systems/native_render/frame_profile.gd'))),
  projectileSceneSha256: hash(fs.readFileSync(path.join(root, 'systems/native_render/projectile_scene.gd'))),
  labels: ['client_support_query', 'client_support_validation', 'client_support_ray', 'client_support_scene_trace', 'count_client_support_queries', 'count_client_support_validations', 'count_client_support_rays'],
};
fs.writeFileSync(path.join(path.dirname(destination), 'receipt.json'), JSON.stringify(receipt, null, 2));
process.stdout.write(JSON.stringify(receipt) + '\n');
