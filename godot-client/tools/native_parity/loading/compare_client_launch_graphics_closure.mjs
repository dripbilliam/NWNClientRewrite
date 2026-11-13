// Compare actual literal graphical-fixture dependency bytes between capsules.
// Fixture roots are reviewed current test entries; all dependencies are capsule-only.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),[beforeLabel,afterLabel]=process.argv.slice(2);
if(![beforeLabel,afterLabel].every(label=>/^parity-launch-[a-z0-9-]+$/.test(label??'')))throw Error('Two exact capsule labels required');
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
const open=label=>{const file=path.join(source,'.cache/native-presentation-parity/loading-agent',label,'manifest.json'),raw=fs.readFileSync(file);return {file,sha256:sha(raw),value:JSON.parse(raw)};};
const before=open(beforeLabel),after=open(afterLabel),results=[];
for(const [kind,entry,extra] of [
 ['highlight','tests/native_parity_highlight_registry_actor_render_test.gd',['systems/native_render/native_surface_state.gd','systems/native_render/model_point_light.gd']],
 ['dialogue','tests/native_parity_conversation_pixels_test.gd',[]],
]){
 const queue=[entry,...extra],seen=new Set(),pins=[],missing=[];
 while(queue.length){
  const relative=queue.shift();if(seen.has(relative))continue;seen.add(relative);
  const current=relative===entry,from=path.join(current?source:after.value.project,relative),old=path.join(current?source:before.value.project,relative);
  if(!fs.existsSync(from)||!fs.existsSync(old)){missing.push(relative);continue;}
  const raw=fs.readFileSync(from),oldRaw=fs.readFileSync(old);pins.push({relative,sha256:sha(raw),beforeSha256:sha(oldRaw),same:sha(raw)===sha(oldRaw),fixture:current});
  if(relative.endsWith('.gd'))for(const match of raw.toString('utf8').matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']\s*\)|extends\s+["']res:\/\/([^"']+)["']/g))queue.push(match[1]??match[2]);
 }
 results.push({kind,entry,success:!missing.length&&pins.every(pin=>pin.same),files:pins.length,missing,changed:pins.filter(pin=>!pin.same),pins});
}
console.log(JSON.stringify({success:results.every(row=>row.success),before:{file:before.file,sha256:before.sha256},after:{file:after.file,sha256:after.sha256},engineUnchanged:before.value.engine.sha256===after.value.engine.sha256,nativeBinaryUnchanged:before.value.nativeBinary.sha256===after.value.nativeBinary.sha256,results},null,2));
