// Isolated current-source parsing/functional staging. No engine/process/server
// is launched here; shared .godot, native outputs and preferences are untouched.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const allowed=path.join(source,'.cache/native-presentation-parity/root');
const output=path.resolve(process.argv[2]??'');
const rel=path.relative(allowed,output);
if(!process.argv[2]||!rel||rel.startsWith('..')||path.isAbsolute(rel)||fs.existsSync(output))throw Error('Fresh root-owned private staging directory required');
const project=path.join(output,'project'),pins=[];
const sha=b=>createHash('sha256').update(b).digest('hex');
const textExtensions=new Set(['.gd','.gdshader','.gdshaderinc','.tscn','.tres','.uid']);
const excluded=new Set(['.cache','.godot','.git','node_modules','reports','native','backups']);
let total=0;
function copy(relative){
 const bytes=fs.readFileSync(path.join(source,relative));total+=bytes.length;
 if(pins.length>=4096||total>32*1024*1024)throw Error('Source staging bound exceeded');
 const target=path.join(project,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});
 pins.push({relative:relative.replaceAll('\\','/'),sha256:sha(bytes),bytes:bytes.length});
}
function walk(directory,relative=''){
 for(const entry of fs.readdirSync(directory,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))){
  const next=path.join(relative,entry.name);
  if(entry.isSymbolicLink())continue;
  if(entry.isDirectory()){if(!excluded.has(entry.name))walk(path.join(directory,entry.name),next);}
  else if(entry.isFile()&&textExtensions.has(path.extname(entry.name)))copy(next);
 }
}
fs.mkdirSync(project,{recursive:true});walk(source);
fs.writeFileSync(path.join(project,'project.godot'),`config_version=5\n[application]\nconfig/name="NWNParitySourceCheck"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="NWNParitySourceCheck-${path.basename(output)}"\n[display]\nwindow/size/no_focus=true\nwindow/size/initial_screen=2\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n`,{flag:'wx'});
fs.mkdirSync(path.join(project,'.godot'));fs.writeFileSync(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n',{flag:'wx'});
const changed=pins.filter(p=>sha(fs.readFileSync(path.join(source,p.relative)))!==p.sha256).map(p=>p.relative);
const receipt={version:1,source,project,pins,bytes:total,changed,scope:'Current text-source snapshot only; no native libraries, imported caches, engine execution or functional acceptance'};
fs.writeFileSync(path.join(output,'source-manifest.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({project,files:pins.length,bytes:total,changed}));
if(changed.length)process.exitCode=1;
