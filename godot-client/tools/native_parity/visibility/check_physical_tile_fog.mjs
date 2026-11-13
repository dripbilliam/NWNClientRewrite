// Isolated CPU checks against the original callback/setter instruction corpus.
// No server, GPU window, engine/native build or production source mutation.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawn} from 'node:child_process';
const projectRoot=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2],action=process.argv[3];
if(!/^physical-tile-fog-[a-z0-9-]+$/.test(label??'')||!['stage','run'].includes(action))throw Error('Explicit fresh physical-tile-fog label and stage|run required');
const out=path.join(projectRoot,'.cache/native-presentation-parity/root',label),project=path.join(out,'project');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const files=[
 'tools/native_parity/visibility/physical_tile_fog.gd',
 'systems/native_render/native_tile_fog.gd',
 'tests/native_physical_tile_fog_test.gd',
 'tests/native_physical_tile_fog_oracle_test.gd',
];
const engine=path.join(projectRoot,'.cache/native-140fps/render-agent/engine-builtin-light-v2/build-1793905781252/binaries/godot.windows.template_release.x86_64.exe');
const corpus=path.join(projectRoot,'.cache/native-presentation-parity/loading-agent/native-tile-fog-callback-oracle-v1/corpus.json');
const corpusSha='47027f130bd0b089fc51e11c558791812702d5a8d6a302e541ac9456a8afd358';
if(action==='stage'){
 if(fs.existsSync(out))throw Error('Fresh isolated output required');
 const original=fs.readFileSync(corpus);if(sha(original)!==corpusSha)throw Error('Original corpus pin differs');
 if(JSON.parse(original).binary_sha256!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a')throw Error('Original subject identity differs');
 fs.mkdirSync(project,{recursive:true});const pins=[];
 for(const relative of files){const bytes=fs.readFileSync(path.join(projectRoot,relative)),dest=path.join(project,relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes,{flag:'wx'});pins.push({relative,sha256:sha(bytes)});}
 fs.writeFileSync(path.join(project,'tests/native_tile_fog_callback_oracle.json'),original,{flag:'wx'});
 fs.writeFileSync(path.join(project,'project.godot'),'config_version=5\n[application]\nconfig/name="NWNPhysicalTileFogCPU"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="NWNPhysicalTileFogCPU-'+label+'"\n[display]\nwindow/size/no_focus=true\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',{flag:'wx'});
 fs.mkdirSync(path.join(project,'.godot'));fs.writeFileSync(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n',{flag:'wx'});
 fs.writeFileSync(path.join(out,'stage.json'),JSON.stringify({version:1,projectRoot,out,project,pins,corpus,corpusSha,engine},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({staged:true,label,files:pins.length,corpusSha}));
}else{
 if(fs.existsSync(path.join(out,'run.json')))throw Error('Immutable completed receipt already exists');
 const manifest=JSON.parse(fs.readFileSync(path.join(out,'stage.json')));
 if(manifest.project!==project||manifest.projectRoot!==projectRoot||manifest.corpusSha!==corpusSha||sha(fs.readFileSync(corpus))!==corpusSha)throw Error('Staged boundary differs');
 if(sha(fs.readFileSync(engine))!=='ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a')throw Error('Reviewed CPU engine pin differs');
 const changes=()=>manifest.pins.filter(pin=>sha(fs.readFileSync(path.join(projectRoot,pin.relative)))!==pin.sha256||sha(fs.readFileSync(path.join(project,pin.relative)))!==pin.sha256).map(pin=>pin.relative);
 if(changes().length)throw Error('Sources changed before test');
 const results=[];
 for(const script of ['tests/native_physical_tile_fog_test.gd','tests/native_physical_tile_fog_oracle_test.gd']){
  const name=path.basename(script,'.gd'),log=path.join(out,name+'.engine.log');
  const child=spawn(engine,['--headless','--path',project,'--log-file',log,'--script','res://'+script],{cwd:project,windowsHide:true,stdio:['ignore','pipe','pipe']});
  let stdout='',stderr='',timedOut=false;child.stdout.on('data',b=>stdout+=b);child.stderr.on('data',b=>stderr+=b);
  const timer=setTimeout(()=>{timedOut=true;child.kill();},20000);
  const terminal=await new Promise(resolve=>{child.on('error',error=>resolve({error:String(error)}));child.on('close',(exitCode,signal)=>resolve({exitCode,signal}));});clearTimeout(timer);
  fs.writeFileSync(path.join(out,name+'.stdout.log'),stdout,{flag:'wx'});fs.writeFileSync(path.join(out,name+'.stderr.log'),stderr,{flag:'wx'});
  const engineLog=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
  const errors=(stdout+'\n'+stderr+'\n'+engineLog).split(/\r?\n/).filter(row=>/SCRIPT ERROR|Parse Error|ERROR:|WARNING:.*leak|FAIL /i.test(row));
  const match=stdout.match(/NATIVE_PHYSICAL_TILE_FOG(?:_ORACLE)? (\d+) checks (\d+) failures/);
  results.push({script,pid:child.pid,...terminal,timedOut,checks:match?Number(match[1]):null,failures:match?Number(match[2]):null,errors,success:terminal.exitCode===0&&!timedOut&&!errors.length&&match?.[2]==='0'});
 }
 const sourceChanges=changes();const receipt={version:1,scope:'Isolated native physical TileData state/endpoint-port CPU contracts plus exact original callback/setter words; no GPU/server/production activation or FPS claim',manifest:sha(fs.readFileSync(path.join(out,'stage.json'))),engineSha256:sha(fs.readFileSync(engine)),corpusSha,sourceChanges,results,checks:results.reduce((n,r)=>n+(r.checks??0),0)};
 receipt.success=!sourceChanges.length&&results.every(r=>r.success);fs.writeFileSync(path.join(out,'run.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(receipt));if(!receipt.success)process.exitCode=1;
}
