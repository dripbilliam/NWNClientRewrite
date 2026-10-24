// Project retained read-only REA evidence into compact, address-bearing records.
// Does not open a game, change an analysis database or infer runtime performance.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';

const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const expected='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const names=[
 'rea-performance-draw-bucket-current.json',
 'rea-arelith-native-gob-scene-buckets-v1.json',
 'rea-light-selection-scene-single-pass-full.json',
 'rea-performance-object-lights-current.json',
 'rea-performance-nearest-lights-current.json',
 'rea-performance-shadow-render-current.json',
 'rea-camera-keyhole-render-scene.json',
 'rea-network-light-bsp-procedures.json',
 'rea-arelith-native-skin-render-v1.json',
];
const files=names.map(name=>'backups/animations/'+name).concat([
 'scene-render','manage-scene-bsp','bsp-collect','static-light-buckets',
 'part-renderable','process-trimesh-parts','part-outside','light-node-tile',
 'traverse-volume','light-part-trimesh','box-above-plane',
].map(name=>'runtime-logs/native-render-parity/'+name+'-dossier.json'));
const records=[];
for(const file of files){
 const bytes=await fs.readFile(path.join(workspace,file));
 const envelope=JSON.parse(bytes.toString('utf8'));
 if(envelope.isError)throw Error('Rejected error evidence: '+file);
 const evidence=envelope.structuredContent??(envelope.procedure?envelope:JSON.parse(envelope.content.find(c=>c.type==='text').text));
 if(evidence.subject?.digest?.sha256!==expected)throw Error('Native build mismatch: '+file);
 const value=evidence.raw_result?.value??evidence.normalized_result??(evidence.procedure?evidence:null);
 if(!value)throw Error('Missing evidence payload: '+file);
 const procedure=value.procedure??{address:value.procedure_address};
 const outgoing=(value.outgoing_references??value.call_edges??[]).filter(r=>r.kind?.call);
 const incoming=(value.incoming_references??[]).filter(r=>r.kind?.call);
 records.push({source:file,sourceSha256:createHash('sha256').update(bytes).digest('hex'),
  evidenceId:evidence.evidence_id,procedure,
  pseudocode:value.pseudocode??value.item?.text??null,
  incoming:incoming.map(r=>({callSite:r.source_address,caller:r.source_procedure?.address,callerName:r.source_procedure?.name})),
  outgoing:outgoing.map(r=>({callSite:r.source_address,target:r.target_address,targetName:r.target_procedure?.name??null,computed:r.kind.computed,indirect:r.kind.indirect})),
  candidates:Array.isArray(value)?value:null,
  coverage:{pseudocodeAvailable:Boolean(value.pseudocode??value.item?.text),
   unresolvedCalls:value.unresolved_calls??null,limitations:evidence.limitations??[],
   relationshipCoverage:evidence.relationship_coverage??null,facets:value.facet_availability??null}});
}
const target=path.join(workspace,'runtime-logs/native-render-parity/retained-evidence-audit.json');
await fs.mkdir(path.dirname(target),{recursive:true});
await fs.writeFile(target,JSON.stringify({version:1,build:'89.8193.37-17',sha256:expected,
 scope:'Retained static evidence only; not runtime draw counts, complete subsystem coverage or performance acceptance.',records},null,2)+'\n');
console.log(JSON.stringify({success:true,output:path.relative(workspace,target),records:records.length,
 functions:records.filter(r=>r.procedure.address).length,callEdges:records.reduce((n,r)=>n+r.outgoing.length,0)}));
