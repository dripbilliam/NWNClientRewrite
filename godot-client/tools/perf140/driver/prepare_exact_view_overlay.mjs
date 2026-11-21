// Small source-only overlay. No full project copy, native build or engine start.
// Use stage_library only later, with a reviewed manifest in a CPU test window.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {hash} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [parentFileArg,parentSha,label]=process.argv.slice(2);
if(!/^[a-f0-9]{64}$/.test(parentSha??'')||!/^exact-view-source-[a-z0-9-]+$/.test(label??''))throw Error('Explicit parent SHA and fresh exact-view-source label required');
const parentFile=path.resolve(parentFileArg??'');
const bytes=fs.readFileSync(parentFile);if(hash(bytes)!==parentSha)throw Error('Reviewed source manifest differs');
const parent=JSON.parse(bytes),source=path.join(parent.project,'native_live_world.gd');
const original=fs.readFileSync(source);if(hash(original)!==parent.pins.find(p=>p.relative==='native_live_world.gd')?.sha256)throw Error('Pinned live entry differs');
const text=original.toString(),marker='func perf140_witness() -> Dictionary:';
if(text.split(marker).length!==2)throw Error('Actual view witness boundary differs');
const [prefix,body]=text.split(marker),needle='\treturn value';
if(body.split(needle).length!==2)throw Error('Actual view witness return differs');
// The base intentionally has no admitted connection. The existing virtual
// accessor returns null there and the actual owner in the session subclass.
const addition='\tvalue.exact_view=preload("res://tools/perf140/driver/exact_view_witness.gd").capture(camera,controller,world,native_text_connection())\n';
const output=prefix+marker+body.replace(needle,addition+needle);
const helper='tools/perf140/driver/exact_view_witness.gd',helperSource=path.join(project,helper),helperBytes=fs.readFileSync(helperSource);
if(parent.pins.some(p=>p.relative===helper))throw Error('Existing exact witness preserved');
const folder=path.join(project,'.cache/native-140fps/root',label);if(fs.existsSync(folder))throw Error('Existing source overlay preserved');
fs.mkdirSync(folder,{recursive:true});const override=path.join(folder,'native_live_world.gd');fs.writeFileSync(override,output,{flag:'wx'});
const frozenHelper=path.join(folder,'exact_view_witness.gd');fs.writeFileSync(frozenHelper,helperBytes,{flag:'wx'});
const changes=[{relative:'native_live_world.gd',from:override,before:hash(original),after:hash(Buffer.from(output))},{relative:helper,from:frozenHelper,before:null,after:hash(helperBytes)}];
const report={version:1,parent:{file:parentFile,sha256:parentSha},changes,scope:'Cold begin/end witness only; no camera selector, per-frame work, movement or public connection. No new performance or runtime acceptance.',sourceOnly:true,nativeBuilds:0,engineStarts:0,testsRun:false};
const file=path.join(folder,'overlay.json');fs.writeFileSync(file,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({file,sha256:hash(fs.readFileSync(file)),changes:changes.map(c=>c.relative),sourceOnly:true}));
