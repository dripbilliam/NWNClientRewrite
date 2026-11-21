import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),id=process.argv[2];if(!/^[a-z0-9-]+$/.test(id??''))throw Error('Private label required');
const directory=path.join(project,'.cache/native-140fps/render-agent',id),input=path.join(directory,'runtime-descriptor.json'),descriptor=JSON.parse(fs.readFileSync(input));
const common=JSON.parse(fs.readFileSync(descriptor.commonBaseline.file));
for(const relative of ['native_live_world.gd','native_session_world.gd']){
 const before=fs.readFileSync(path.join(common.project,relative),'utf8'),after=fs.readFileSync(path.join(descriptor.project,relative),'utf8');
 let expected=relative==='native_live_world.gd'?before.replace('\treport.perf140_view_end=perf140_witness()\n','').replace(/\nfunc perf140_witness\(\) -> Dictionary:[\s\S]*$/,''):before.replace('\t\t\treport.performance_window.view_begin=perf140_witness()\n','');
 if(expected.trimEnd()!==after.trimEnd())throw Error('Entry differences include more than known inherited witness removal: '+relative);
}
const entries=descriptor.runtimeChanges.filter(row=>['native_live_world.gd','native_session_world.gd'].includes(row.relative));
const result={...descriptor,runtimeChanges:descriptor.runtimeChanges.filter(row=>!entries.includes(row)),omittedInheritedEntryDifferences:entries.map(row=>({...row,reason:'Only removes root benchmark view witnesses; no required particle/pose/lease integration. Preserve root current entry, UI, monitor and profiling hooks.'})),entryReviewExact:true,unreviewedDescriptor:{file:input,sha256:crypto.createHash('sha256').update(fs.readFileSync(input)).digest('hex')}};
const output=path.join(directory,'runtime-descriptor-reviewed.json');if(fs.existsSync(output))throw Error('Existing review preserved');fs.writeFileSync(output,JSON.stringify(result,null,2));console.log(JSON.stringify({output,sha256:crypto.createHash('sha256').update(fs.readFileSync(output)).digest('hex'),runtimeChanges:result.runtimeChanges.length,entryReviewExact:true}));
