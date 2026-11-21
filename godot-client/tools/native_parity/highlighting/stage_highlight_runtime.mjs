// Package the reviewed standalone kernel into a private project. Never build
// or replace the particle/pose library, engine or any running client.
import fs from 'node:fs';import path from 'node:path';import {createHash} from 'node:crypto';import {fileURLToPath} from 'node:url';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const sha=b=>createHash('sha256').update(b).digest('hex');
export function stageHighlightRuntime(project){
 project=path.resolve(project);const allowed=path.join(source,'.cache');
 if(!project.startsWith(allowed+path.sep)||!fs.existsSync(path.join(project,'project.godot')))throw Error('Existing isolated project required');
 const buildFile=path.join(source,'.cache/native-presentation-parity/particles-agent/highlight-kernel-build-v2/build.json'),build=JSON.parse(fs.readFileSync(buildFile));
 if(build.exit_code!==0||build.source_changed.length)throw Error('Native build was not accepted');
 const expected={binary:'db712eb564554c053222706183dd2d25e2c153aeddc3febac385b51e86130921',descriptor:'13ed447ab4b7ed2d37fc96ac002fa4da0111fce4953dee583107b589c3c15b4b'};
 for(const pin of build.sources)if(sha(fs.readFileSync(pin.source))!==pin.sha256||sha(fs.readFileSync(pin.file))!==pin.sha256)throw Error('Reviewed native source changed');
 const pins=[];
 for(const [kind,relative] of [['binary','.cache/highlight-kernel/nwn-highlight-geometry.dll'],['descriptor','native/highlight_geometry.gdextension']]){
  const raw=fs.readFileSync(build[kind]);if(sha(raw)!==expected[kind])throw Error('Standalone highlight artifact differs');
  const destination=path.join(project,relative);fs.mkdirSync(path.dirname(destination),{recursive:true});
  if(fs.existsSync(destination)){if(sha(fs.readFileSync(destination))!==expected[kind])throw Error('Different existing highlight artifact retained');}
  else fs.writeFileSync(destination,raw,{flag:'wx'});
  pins.push({relative,sha256:expected[kind],bytes:raw.length});
 }
 return{version:1,buildFile,buildSha256:sha(fs.readFileSync(buildFile)),pins,shared_native_builds:0};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))console.log(JSON.stringify(stageHighlightRuntime(process.argv[2])));
