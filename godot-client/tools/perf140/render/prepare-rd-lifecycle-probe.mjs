import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const id = process.argv[2] ?? 'rd-lifecycle-probe-v1';
if (!/^[a-z0-9-]+$/i.test(id)) throw Error('Fresh private probe identifier required');
const stage = path.join(project, '.cache/native-140fps/render-agent', id);
if (fs.existsSync(stage)) throw Error('Existing probe evidence preserved');
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const source = 'tests/native_perf140_render_rd_lifecycle_probe.gd';
const script = fs.readFileSync(path.join(project, source));
const pins = [];
for (const [name, mode] of [['safe', 1], ['separate', 2]]) {
  const target = path.join(stage, name);
  fs.mkdirSync(target, {recursive: true});
  const config = `config_version=5\n\n[application]\nconfig/name="RD lifecycle ${name}"\n\n[display]\nwindow/size/viewport_width=400\nwindow/size/viewport_height=240\nwindow/size/window_width_override=400\nwindow/size/window_height_override=240\nwindow/size/no_focus=true\n\n[rendering]\nrenderer/rendering_method="forward_plus"\nrenderer/rendering_method.mobile="forward_plus"\ndriver/threads/thread_model=${mode}\n`;
  // CLI explicitly selects Forward+/Vulkan. Keeping the setting separate from
  // project import prevents any application/global autoload or extension.
  for (const [file, bytes] of [['project.godot', Buffer.from(config)], ['probe.gd', script], ['.godot/global_script_class_cache.cfg', Buffer.from('list=[]\n')]]) {
    fs.mkdirSync(path.dirname(path.join(target, file)), {recursive: true});
    fs.writeFileSync(path.join(target, file), bytes, {flag: 'wx'});
    pins.push({relative: `${name}/${file}`, sha256: hash(bytes)});
  }
}
const receipt = {version: 1, id, stage, source, sourceSha256: hash(script), pins, applicationExtensions: 0, autoloads: 0, serverConnections: 0, engineStarts: 0, scope: 'A blank Vulkan window, scheduler observations and normal SceneTree.quit after three frames. No direct RenderingDevice reference or resource is created by the probe.'};
fs.writeFileSync(path.join(stage, 'manifest.json'), JSON.stringify(receipt, null, 2), {flag: 'wx'});
console.log(JSON.stringify(receipt, null, 2));
