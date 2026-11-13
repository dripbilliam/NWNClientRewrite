import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const id = process.argv[2] ?? 'rd-lifecycle-release-pack-v1';
if (!/^[a-z0-9-]+$/.test(id)) throw Error('Fresh private probe identifier required');
const stage = path.join(project, '.cache/native-140fps/render-agent', id);
if (fs.existsSync(stage)) throw Error('Existing probe evidence preserved');
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const release = path.join(project, '.tools/windows_release_x86_64.exe');
const releaseHash = digest(fs.readFileSync(release));
if (releaseHash !== 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562') throw Error('Verified release runtime drifted');
const debug = path.join(project, '.tools/Godot_v4.7.2-stable_win64.exe');
const source = fs.readFileSync(path.join(project, 'tests/native_perf140_render_rd_lifecycle_probe.gd'), 'utf8');
const script = source.replace('extends SceneTree', 'extends Node').replace('func _initialize()', 'func _ready()').replace('func _process(_delta: float) -> bool:', 'func _process(_delta: float) -> void:').replaceAll('\t\tquit(', '\t\tget_tree().quit(').replace('\n\treturn false', '');
const scene = '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://probe_node.gd" id="1"]\n\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n';
fs.mkdirSync(stage, {recursive:true});
const packScript = `extends SceneTree
func _initialize() -> void:
\tvar args := OS.get_cmdline_user_args()
\tif args.size() != 1:
\t\tquit(2)
\t\treturn
\tvar folder := args[0]
\tvar packer := PCKPacker.new()
\tvar result := packer.pck_start(folder.path_join("probe.pck"))
\tif result == OK:
\t\tfor name in ["project.godot", "probe.tscn", "probe_node.gd", ".godot/global_script_class_cache.cfg"]:
\t\t\tresult = packer.add_file("res://" + name, folder.path_join(name))
\t\t\tif result != OK:
\t\t\t\tbreak
\tif result == OK:
\t\tresult = packer.flush()
\tprint("NATIVE_RD_PACK " + JSON.stringify({"error": result, "folder": folder}))
\tquit(0 if result == OK else 1)
`;
fs.writeFileSync(path.join(stage, 'pack.gd'), packScript, {flag:'wx'});
const pins = [];
for (const [mode, number] of [['safe',1], ['separate',2]]) {
  const folder = path.join(stage, mode);
  fs.mkdirSync(folder);
  fs.mkdirSync(path.join(folder,'.godot'));
  fs.writeFileSync(path.join(folder,'.godot/global_script_class_cache.cfg'),'list=[]\n',{flag:'wx'});
  const config = `config_version=5\n\n[application]\nconfig/name="RD lifecycle packed ${mode}"\nrun/main_scene="res://probe.tscn"\n\n[display]\nwindow/size/viewport_width=400\nwindow/size/viewport_height=240\nwindow/size/window_width_override=400\nwindow/size/window_height_override=240\nwindow/size/no_focus=true\n\n[rendering]\nrenderer/rendering_method="forward_plus"\nrenderer/rendering_method.mobile="forward_plus"\ndriver/threads/thread_model=${number}\n`;
  for (const [file, bytes] of [['project.godot',config], ['probe.tscn',scene], ['probe_node.gd',script]]) fs.writeFileSync(path.join(folder,file),bytes,{flag:'wx'});
  fs.copyFileSync(release, path.join(folder,'probe.exe'),fs.constants.COPYFILE_EXCL);
  const run = spawnSync(debug, ['--headless','--path',folder,'--log-file',path.join(stage,`pack-${mode}.engine.log`),'--script',path.join(stage,'pack.gd'),'--',folder], {encoding:'utf8',timeout:30000,windowsHide:true});
  fs.writeFileSync(path.join(stage,`pack-${mode}.stdout.log`),run.stdout??'');
  fs.writeFileSync(path.join(stage,`pack-${mode}.stderr.log`),run.stderr??'');
  const checkedErrors = (run.stderr??'').replace(/ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates \(platform\/windows\/os_windows\.cpp:2582\)/g,'');
  if(run.status!==0 || run.error || /SCRIPT ERROR|ERROR:/.test(checkedErrors) || !fs.existsSync(path.join(folder,'probe.pck'))) throw Error(`PCK build failed for ${mode}: ${run.stderr??run.error}`);
  for(const file of ['project.godot','probe.tscn','probe_node.gd','.godot/global_script_class_cache.cfg','probe.exe','probe.pck']) pins.push({relative:`${mode}/${file}`,sha256:digest(fs.readFileSync(path.join(folder,file)))});
}
pins.push({relative:'pack.gd',sha256:digest(packScript)});
const receipt = {version:1,id,stage,pins,releaseSource:release,releaseSha256:releaseHash,debugPacker:debug,debugPackerSha256:digest(fs.readFileSync(debug)),applicationExtensions:0,autoloads:0,serverConnections:0,graphicalStarts:0,launchMode:'Sibling probe.pck discovered from probe.exe basename, no --path or --main-pack override.',scope:'A blank Vulkan window, scheduler observations and normal SceneTree.quit after three frames; no direct RenderingDevice resource.'};
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(receipt,null,2),{flag:'wx'});
console.log(JSON.stringify({stage,pins:pins.length,releaseSha256:releaseHash,graphicalStarts:0}));
