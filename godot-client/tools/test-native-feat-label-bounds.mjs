import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project);
const [label,mode]=process.argv.slice(2);
if(!/^[a-z0-9-]{3,80}$/.test(label??'')||!['before','staged','integrated'].includes(mode))throw Error('Supply a unique evidence label and before/staged/integrated mode');
const directory=path.join(project,'.cache/feat-label-bounds',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Preserve previous evidence');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(root+path.sep))throw Error('Input escapes workspace');
 const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(root,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(file.endsWith('.gd'))for(const match of bytes.toString().matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']\s*\)|extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]??match[2]));
}
include(path.join(project,'tests/native_feat_label_bounds_test.gd'));include(fileURLToPath(import.meta.url));
include(path.join(project,'reports/native-label-bounds-original-v1.json'));
for(const [file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Source changed while copied');}
const copiedProject=path.join(copy,'godot-client'),layout='systems/native_data/creation_feats_layout.gd';
const before=fs.readFileSync(path.join(copiedProject,layout),'utf8'),needle='if tag=="tguilabel":entry.floating=true;entry.anchor=entry.rect.position';
if(mode==='integrated'){
 if(before.split('if tag in ["availtitle","knowntitle","remainlabel","tguilabel"]:entry.floating=true;entry.anchor=entry.rect.position').length!==2)throw Error('Integrated label hunk is missing or ambiguous');
}else if(before.split(needle).length!==2)throw Error('Expected source hunk is no longer unique');
const after=mode==='staged'?before.replace(needle,'if tag in ["availtitle","knowntitle","remainlabel","tguilabel"]:entry.floating=true;entry.anchor=entry.rect.position'):before;
fs.writeFileSync(path.join(copiedProject,layout),after);
fs.copyFileSync(path.join(project,'reports/native-label-bounds-original-v1.json'),path.join(copiedProject,'oracle.json'));
fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Feat Label Bounds"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const godot=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(godot));
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected installed runtime');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const child=spawnSync(godot,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/native_feat_label_bounds_test.gd','--','--report='+report,'--install='+path.resolve(root,'../FullDecomp/NwnRootInstall')],{windowsHide:true,timeout:35000,encoding:'utf8',maxBuffer:1024*1024});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engine=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const clean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|Unicode parsing error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engine+'\n'+child.stderr);
const changed=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const changedCopies=[...inputs].filter(([,row])=>{const bytes=fs.readFileSync(path.join(copy,row.path));const expected=row.path==='godot-client/'+layout?hash(after):row.sha256;return hash(bytes)!==expected;}).map(([,row])=>row.path);
const proof={success:child.status===0&&!child.error&&clean&&result?.success===true&&!changed.length&&!changedCopies.length,mode,checks:result?.checks??0,failures:result?.failures??[],directory,report,cleanEngine:clean,exitCode:child.status,error:child.error?.message??null,inputs:[...inputs.values()],changedInputs:changed,changedCopiedInputs:changedCopies,candidate:{path:layout,sourceSha256:hash(before),stagedSha256:hash(after),needle,replacement:'if tag in ["availtitle","knowntitle","remainlabel","tguilabel"]:entry.floating=true;entry.anchor=entry.rect.position'},engineSha256,gpu:false,serverConnections:0,nativeBuilds:0,integrated:false,scope:'Original native bounds predicate and actual Feats controls/installed-font ink. Exact single-line source change staged only inside an isolated copy; production and open user client remain unchanged.'};
if(mode==='integrated'){proof.integrated=true;proof.scope='Integrated original native bounds predicate and actual Feats controls/installed-font ink. Copied current production sources; no live-client or authoritative server validation.';}
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:proof.inputs.length,failures:proof.failures.length}));process.exitCode=proof.success?0:1;
