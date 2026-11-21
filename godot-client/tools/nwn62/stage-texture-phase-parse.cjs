'use strict';
// Isolated GDScript parse project, limited to systems source and the probe overlay.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const scope = path.join(root, '.cache/nwn62/texture-phase-probe-a');
const project = path.join(scope, 'parse-project-b');
const overlay = path.join(scope, 'resource_pool.gd');
const manifest = JSON.parse(fs.readFileSync(path.join(scope, 'manifest.json')));
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
assert(manifest.private && !manifest.accepted && manifest.issue === 'NWN-62');
assert.equal(sha(overlay), manifest.overlaySha256);
assert.equal(sha(path.join(root, manifest.source)), manifest.sourceSha256);
assert(!fs.existsSync(project), 'Parse project already exists');
const rows = [];
let totalBytes = 0;
function copyDir(relative) {
  for (const entry of fs.readdirSync(path.join(root, relative), {withFileTypes: true})) {
    const child = path.join(relative, entry.name);
    if (entry.isSymbolicLink()) continue;
    if (entry.isDirectory()) copyDir(child);
    else if (entry.isFile() && /\.(gd|gdshader|gdshaderinc|tscn|tres)$/.test(entry.name)) {
      const bytes = fs.readFileSync(path.join(root, child));
      totalBytes += bytes.length;
      assert(totalBytes <= 16 * 1024 * 1024 && rows.length < 2000, 'Parse source bound exceeded');
      const dest = path.join(project, child);
      fs.mkdirSync(path.dirname(dest), {recursive: true});
      fs.writeFileSync(dest, bytes, {flag: 'wx'});
      rows.push({file: child.replaceAll('\\', '/'), sha256: crypto.createHash('sha256').update(bytes).digest('hex')});
    }
  }
}
fs.mkdirSync(project, {recursive: true});
copyDir('systems');
copyDir('tools');
fs.copyFileSync(overlay, path.join(project, 'systems/native_render/resource_pool.gd'));
fs.writeFileSync(path.join(project, 'project.godot'), 'config_version=5\n[application]\nconfig/name="NWN62TexturePhaseParse"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', {flag: 'wx'});
fs.mkdirSync(path.join(project, '.godot'), {recursive: true});
fs.writeFileSync(path.join(project, '.godot/global_script_class_cache.cfg'), 'list=[]\n', {flag: 'wx'});
const receipt = {issue: 'NWN-62', private: true, project, sourceSha256: manifest.sourceSha256, overlaySha256: manifest.overlaySha256, copied: rows.length, bytes: totalBytes, scope: 'Source parse only; no accepted project, native libraries, assets or FPS'};
fs.writeFileSync(path.join(scope, 'parse-receipt-b.json'), JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify(receipt, null, 2));
