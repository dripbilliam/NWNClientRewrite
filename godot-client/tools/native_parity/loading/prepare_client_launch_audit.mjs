// Read-only current-vs-frozen source audit. Does not launch, decrypt credentials,
// change settings, contact any server, or build native outputs.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2];if(!/^parity-launch-[a-z0-9-]+$/.test(label??''))throw Error('Fresh parity launch audit label required');
const folder=path.join(project,'.cache/native-presentation-parity/loading-agent',label);
if(fs.existsSync(folder))throw Error('Existing audit/capsule preserved');
const parentFile=path.join(project,'.cache/native-140fps/root/drive-envelope-fenced-v1/manifest.json');
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
if(sha(fs.readFileSync(parentFile))!=='cce71cea6e3ae8116d4747c97f1e161eed9350cd85386dc372578d9f6d4cdfc1')throw Error('Frozen measured source parent changed');
const parent=JSON.parse(fs.readFileSync(parentFile));
const priorFile=path.join(project,'.cache/native-presentation-parity/loading-agent/parity-launch-seven-fixes-v3/manifest.json');
if(sha(fs.readFileSync(priorFile))!=='9ac19296443bbef4e6115956cd3349952d8c1246ea85a1cff0ccaab6905bad59')throw Error('Immutable V3 capsule changed');
const priorCapsule={file:priorFile,sha256:sha(fs.readFileSync(priorFile)),scope:'Prior CPU/GPU/menu/local orchestration passed; actual reveal runtime inactive, not accepted as visibility parity'};
const rows=[];
for(const pin of parent.pins){
 if(!pin.relative.endsWith('.gd')&&!['project.godot','main.tscn','benchmark-options.cfg'].includes(pin.relative))continue;
 const file=path.join(project,pin.relative),frozen=path.join(parent.project,pin.relative);
 const raw=fs.readFileSync(frozen);if(sha(raw)!==pin.sha256)throw Error('Frozen source differs: '+pin.relative);
 const current=fs.existsSync(file)?fs.readFileSync(file):null;
 rows.push({relative:pin.relative,parentSha256:pin.sha256,parentBytes:raw.length,currentSha256:current?sha(current):null,currentBytes:current?.length??null,status:current===null?'frozen-only':sha(current)===pin.sha256?'identical':'different'});
}
const listed=new Set(rows.map(row=>row.relative));
function walk(directory){for(const entry of fs.readdirSync(directory,{withFileTypes:true})){const file=path.join(directory,entry.name);if(entry.isDirectory())walk(file);else if(entry.name.endsWith('.gd')){const relative=path.relative(project,file).replaceAll('\\','/');if(!listed.has(relative)){const raw=fs.readFileSync(file);rows.push({relative,currentSha256:sha(raw),currentBytes:raw.length,status:'current-only'});}}}}
walk(path.join(project,'systems'));walk(path.join(project,'tools/native_parity'));
fs.mkdirSync(folder,{recursive:true});
const report={version:2,label,created:new Date().toISOString(),parent:{file:parentFile,sha256:sha(fs.readFileSync(parentFile)),project:parent.project},priorCapsule,rows,summary:Object.fromEntries(['identical','different','frozen-only','current-only'].map(status=>[status,rows.filter(row=>row.status===status).length])),scope:'Source audit only; no renderer composition, launch, login, server action, settings change or native build'};
fs.writeFileSync(path.join(folder,'audit.json'),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({folder,summary:report.summary,different:rows.filter(row=>row.status==='different').map(row=>row.relative),frozenOnly:rows.filter(row=>row.status==='frozen-only').map(row=>row.relative)}));
