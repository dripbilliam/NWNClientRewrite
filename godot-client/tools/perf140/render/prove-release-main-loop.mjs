import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const id=process.argv[2]??'release-main-loop-v1';
if(!/^[a-z0-9-]+$/.test(id))throw Error('Fresh private stage required');
const stage=path.join(project,'.cache/native-140fps/render-agent',id);
if(fs.existsSync(stage))throw Error('Existing proof preserved');
fs.mkdirSync(stage,{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const debug=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),release=path.join(project,'.tools/windows_release_x86_64.exe');
if(hash(fs.readFileSync(release))!=='d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562')throw Error('Verified release drift');
const packScript=`extends SceneTree
func _initialize() -> void:
\tvar args := OS.get_cmdline_user_args()
\tvar spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
\tvar packer := PCKPacker.new()
\tvar error := packer.pck_start(spec.output)
\tfor row in spec.files:
\t\tif error != OK: break
\t\terror = packer.add_file("res://" + row.relative, row.file)
\tif error == OK: error = packer.flush()
\tquit(0 if error == OK else 1)
`;
fs.writeFileSync(path.join(stage,'pack.gd'),packScript);
const pins=[],cases=[];
const environmentWarnings=/ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates \(platform\/windows\/os_windows\.cpp:2582\)/g;
for(const mode of ['ignored-script','configured-loop','node-bootstrap']){
 const folder=path.join(stage,mode);fs.mkdirSync(folder);fs.mkdirSync(path.join(folder,'.godot'));
 const trace=path.join(folder,'witness.jsonl').replaceAll('\\','/');
 const mark=`func mark(value: String) -> void:
\tvar writer := FileAccess.open(${JSON.stringify(trace)}, FileAccess.READ_WRITE if FileAccess.file_exists(${JSON.stringify(trace)}) else FileAccess.WRITE)
\tif writer == null: push_error("Absolute witness open failed"); return
\twriter.seek_end()
\twriter.store_line(JSON.stringify({"kind": value}))
\twriter.close()
`;
 const base=`extends SceneTree
var frames := 0
var ran := false
${mark}
func _initialize() -> void:
\tmark("base_initialize")
\tcall_deferred("run")
func run() -> void:
\tmark("base_run")
\tran = true
func _process(_delta: float) -> bool:
\tframes += 1
\tif ran and frames >= 3:
\t\tmark("loop_normal_quit")
\t\tquit(0)
\telif frames >= 30:
\t\tmark("loop_incomplete")
\t\tquit(2)
\treturn false
`;
 const entry='class_name Perf140ReleaseProbe\nextends "res://base.gd"\n\nfunc run() -> void:\n\tmark("child_run")\n\tran = true\n';
 const fallback=`extends Node
var frames := 0
${mark}
func _ready() -> void: mark("fallback_ready")
func _process(_delta: float) -> void:
\tframes += 1
\tif frames >= 3:
\t\tmark("fallback_normal_quit")
\t\tget_tree().quit()
`;
 const configured=mode==='configured-loop',bootstrap=mode==='node-bootstrap';
 const config=`config_version=5\n[application]\nconfig/name="Private release loop proof ${mode}"\nrun/main_scene="res://${configured?'empty':bootstrap?'bootstrap':'fallback'}.tscn"\n${configured?'run/main_loop_type="Perf140ReleaseProbe"\n':''}[display]\nwindow/size/no_focus=true\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n`;
 const cache='list=[{"base":"SceneTree","class":"Perf140ReleaseProbe","icon":"","is_abstract":false,"is_tool":false,"language":"GDScript","path":"res://entry.gd"}]\n';
 const bootstrapScript=`extends Node
${mark}
func _ready() -> void:
\tvar tree := get_tree()
\tvar identity := tree.get_instance_id()
\tmark("bootstrap_before_assignment")
\ttree.set_script(preload("res://entry.gd"))
\tmark("bootstrap_after_assignment")
\tvar proof := FileAccess.open(${JSON.stringify(path.join(folder,'bootstrap-state.json').replaceAll('\\','/'))},FileAccess.WRITE)
\tproof.store_string(JSON.stringify({"same_id": identity == tree.get_instance_id(), "initialize_present":tree.has_method("_initialize"), "run_present":tree.has_method("run"), "assigned_script":tree.get_script().resource_path}))
\tproof.close()
\ttree.call("_initialize")
\tmark("bootstrap_after_initialize")
\ttree.current_scene = null
\tqueue_free()
`;
 const data={'project.godot':config,'base.gd':base,'entry.gd':entry,'fallback.gd':fallback,'fallback.tscn':'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://fallback.gd" id="1"]\n[node name="Fallback" type="Node"]\nscript=ExtResource("1")\n','empty.tscn':'[gd_scene format=3]\n[node name="Empty" type="Node"]\n','bootstrap.gd':bootstrapScript,'bootstrap.tscn':'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://bootstrap.gd" id="1"]\n[node name="Bootstrap" type="Node"]\nscript=ExtResource("1")\n','.godot/global_script_class_cache.cfg':cache};
 for(const [relative,bytes]of Object.entries(data)){fs.writeFileSync(path.join(folder,relative),bytes);pins.push({relative:`${mode}/${relative}`,sha256:hash(bytes)});}
 fs.copyFileSync(release,path.join(folder,'probe.exe'));
 const spec={output:path.join(folder,'probe.pck'),files:Object.keys(data).map(relative=>({relative,file:path.join(folder,relative)}))};
 fs.writeFileSync(path.join(folder,'pack-spec.json'),JSON.stringify(spec));
 const pack=spawnSync(debug,['--headless','--path',folder,'--log-file',path.join(folder,'pack.engine.log'),'--script',path.join(stage,'pack.gd'),'--',path.join(folder,'pack-spec.json')],{encoding:'utf8',windowsHide:true,timeout:15000});
 fs.writeFileSync(path.join(folder,'pack.stdout.log'),pack.stdout??'');fs.writeFileSync(path.join(folder,'pack.stderr.log'),pack.stderr??'');
 if(pack.status!==0||pack.error||/ERROR:|SCRIPT ERROR/.test((pack.stderr??'').replace(environmentWarnings,'')))throw Error(`Pack failed ${mode}: ${pack.stderr}`);
 const args=['--headless','--log-file',path.join(folder,'run.engine.log')];if(mode==='ignored-script')args.push('--script','res://entry.gd');
 const outcome=spawnSync(path.join(folder,'probe.exe'),args,{cwd:folder,encoding:'utf8',windowsHide:true,timeout:15000});
 fs.writeFileSync(path.join(folder,'run.stdout.log'),outcome.stdout??'');fs.writeFileSync(path.join(folder,'run.stderr.log'),outcome.stderr??'');
 const witness=fs.existsSync(trace)?fs.readFileSync(trace,'utf8').trim().split(/\r?\n/).map(line=>JSON.parse(line).kind):[];
 const expected=configured?['base_initialize','child_run','loop_normal_quit']:bootstrap?['bootstrap_before_assignment','bootstrap_after_assignment','base_initialize','bootstrap_after_initialize','child_run','loop_normal_quit']:['fallback_ready','fallback_normal_quit'];
 const errors=(outcome.stderr??'')+(fs.existsSync(path.join(folder,'run.engine.log'))?fs.readFileSync(path.join(folder,'run.engine.log'),'utf8'):'');
 const clean=!/ERROR:|Error: Can't run project|SCRIPT ERROR|leaked|still in use/.test(errors.replace(environmentWarnings,''));
 const success=outcome.status===0&&!outcome.error&&clean&&JSON.stringify(witness)===JSON.stringify(expected);
 const bootstrapState=bootstrap&&fs.existsSync(path.join(folder,'bootstrap-state.json'))?JSON.parse(fs.readFileSync(path.join(folder,'bootstrap-state.json'))):null;
 cases.push({mode,success,exitCode:outcome.status,error:outcome.error?.message??null,clean,args,witness,expected,bootstrapState,absoluteFileAccessProof:trace,graphical:false,extensions:0,serverConnections:0});
 for(const relative of ['probe.exe','probe.pck'])pins.push({relative:`${mode}/${relative}`,sha256:hash(fs.readFileSync(path.join(folder,relative)))});
}
const sourceUnchanged=pins.every(pin=>hash(fs.readFileSync(path.join(stage,pin.relative)))===pin.sha256);
const receipt={version:1,stage,success:sourceUnchanged&&cases.every(row=>row.success),sourceUnchanged,pins,cases,graphical:false,extensions:0,serverConnections:0};
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify({...receipt,pins:pins.length},null,2));if(!receipt.success)process.exitCode=1;
