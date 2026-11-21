'use strict';
// Read-only current-image validation and compact retained Ghidra index. Never
// opens an analysis producer, changes the original image, or executes it.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../../..'),workspace=path.dirname(project),label=process.argv[2];if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh catalog label required');
const output=path.join(project,'.cache/native-render-gap/original','retained-'+label);if(fs.existsSync(output))throw Error('Earlier catalog preserved');
const original='C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall/bin/win32/nwmain.exe',image=fs.readFileSync(original),sha=b=>crypto.createHash('sha256').update(b).digest('hex'),imageSha=sha(image);
if(imageSha!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a')throw Error('Exact original image differs');
const pe=image.readUInt32LE(0x3c),opt=pe+24,base=Number(image.readBigUInt64LE(opt+24)),table=opt+image.readUInt16LE(pe+20),sections=[];
for(let i=0;i<image.readUInt16LE(pe+6);i++){const p=table+i*40;sections.push({name:image.subarray(p,p+8).toString('ascii').replace(/\0.*$/,''),rva:image.readUInt32LE(p+12),raw:image.readUInt32LE(p+20),bytes:image.readUInt32LE(p+16)});}
const sourceRoot=path.join(workspace,'backups/animations'),renderRoot=path.join(project,'tools/perf140/render/evidence'),rx=/(scene|render|frame|bucket|visibility|bound|cull|skin|swap|flush|main|draw|rig|light|emitter|mesh|wind|movement)/i;
const files=fs.readdirSync(sourceRoot).filter(n=>/^rea-.*\.json$/.test(n)&&rx.test(n)).map(n=>path.join(sourceRoot,n));
for(const n of ['native-emitter-bucket-v1.json','native-skin-bones-v1.json','native-particle-draw-v1.json','native-light-selection-observations.json','native-light-limit-observations-v1.json','native-light-limit-focus-observations-v1.json','native-particle-frame-observations.json'])if(fs.existsSync(path.join(sourceRoot,n)))files.push(path.join(sourceRoot,n));
for(const n of fs.readdirSync(renderRoot).filter(n=>n.endsWith('.json')))files.push(path.join(renderRoot,n));
const rows=[],errors=[],sourcePins=[];
function collect(value,at,envelope){
 if(!value||typeof value!=='object')return;
 if(value.normalized_result?.view?.facet==='pseudocode'&&typeof value.normalized_result.item?.text==='string'){
  const n=value.normalized_result,address=n.procedure_address,text=n.item.text,name=text.match(/(?:__thiscall|__cdecl)\s+([A-Za-z_:0-9~]+)\s*\(/)?.[1]??address;
  const synthetic={subject:value.subject,procedure:{address,name,body:{available:false,provenance:'Retained pseudocode page lacks complete function-body AddressSet'}},pseudocode:text,relationship_coverage:n.coverage,evidence_id:value.evidence_id,limitations:[...(value.limitations??[]),'Retained pseudocode view has no assembly/caller/callee dossier; missing edges are unknown.']};collect(synthetic,at+'.normalized_result.item',synthetic);return;
 }
 if(value.normalized_result?.procedure){collect(value.normalized_result,at+'.normalized_result',value);return;}
 if(value.procedure&&typeof value.pseudocode==='string'){
  const e=envelope??value,n=value,subject=e.subject??value.subject,digest=subject?.digest?.sha256??subject?.sha256??e.binarySha256??value.original?.sha256;
  const body=n.procedure.body,code=[];
  if(body?.available)for(const range of body.ranges??[]){const first=parseInt(range.start,16),last=parseInt(range.end,16),rva=first-base,len=last-first+1,s=sections.find(s=>rva>=s.rva&&rva+len<=s.rva+s.bytes);if(!s||len<=0||len>1024*1024){errors.push({source:at,error:'Body is not bounded source-backed PE data'});continue;}const offset=s.raw+rva-s.rva;code.push({...range,section:s.name,fileOffset:offset,bytes:len,sha256:sha(image.subarray(offset,offset+len))});}
  rows.push({source:at.split('#')[0],jsonPath:at.split('#')[1],subjectSha256:digest??null,exactSubject:digest===imageSha,evidenceId:e.evidence_id??value.evidence_id??null,procedure:n.procedure,bodyCode:code,pseudocode:n.pseudocode,assembly:n.assembly??null,callees:n.callees??[],callers:n.callers??[],unresolvedCalls:n.unresolved_calls??[],coverage:e.relationship_coverage??value.relationship_coverage??null,limitations:e.limitations??n.limitations??[]});return;
 }
 if(Array.isArray(value)){value.forEach((v,i)=>collect(v,at+'['+i+']',envelope));return;}
 if(value.structuredContent){collect(value.structuredContent,at+'.structuredContent',envelope);return;}
 if(value.result){collect(value.result,at+'.result',envelope);return;}
 if(value.raw_result?.value){collect(value.raw_result.value,at+'.raw_result.value',value);return;}
 if(Array.isArray(value.rows)){value.rows.forEach((v,i)=>collect(v,at+'.rows['+i+']',value));return;}
 if(Array.isArray(value.cases)){value.cases.forEach((v,i)=>collect(v,at+'.cases['+i+']',value));return;}
 if(value.content)for(const c of value.content)if(c.type==='text'&&typeof c.text==='string'&&/^[\s]*[\[{]/.test(c.text)){try{collect(JSON.parse(c.text),at+'.content.text',envelope);}catch{}}
}
for(const file of files){const stat=fs.statSync(file);if(stat.size>24*1024*1024){errors.push({file,error:'Retained file exceeds24MiB catalog bound'});continue;}const bytes=fs.readFileSync(file);sourcePins.push({file,bytes:bytes.length,sha256:sha(bytes)});try{collect(JSON.parse(bytes),file+'#root',null);}catch(e){errors.push({file,error:e.message});}}
const anchors=['0x1400c7ae0','0x1400c38f0','0x1400d9330','0x1407fcd70','0x1408114d0'],byAddress=new Map();
for(const row of rows){const address=row.procedure.address;let list=byAddress.get(address);if(!list)byAddress.set(address,list=[]);list.push(row);}
const choose=list=>[...list].sort((a,b)=>Number(b.exactSubject)-Number(a.exactSubject)||Number(!!b.procedure.body?.available)-Number(!!a.procedure.body?.available)||b.pseudocode.length-a.pseudocode.length)[0];
const selected=new Map([...byAddress].map(([address,list])=>[address,choose(list)]));
const required=new Set([...anchors,...selected.keys()]);
for(let depth=0;depth<2;depth++)for(const address of [...required]){const row=selected.get(address);if(!row)continue;for(const c of row.callers)if(selected.has(c.address))required.add(c.address);}
fs.mkdirSync(output,{recursive:true});fs.mkdirSync(path.join(output,'bodies'));
for(const address of required){const r=selected.get(address);if(!r)continue;fs.writeFileSync(path.join(output,'bodies',address+'.json'),JSON.stringify(r,null,2)+'\n',{flag:'wx'});}
const summary=r=>({address:r.procedure.address,name:r.procedure.name,body:r.procedure.body,source:r.source,jsonPath:r.jsonPath,exactSubject:r.exactSubject,evidenceId:r.evidenceId,code:r.bodyCode,pseudocodeUtf16:r.pseudocode.length,assemblyRows:r.assembly?.length??0,callees:r.callees.map(c=>({address:c.address,name:c.name})),callers:r.callers.map(c=>({address:c.address,name:c.name})),unresolvedCalls:r.unresolvedCalls,coverage:r.coverage});
const result={version:1,original:{file:original,sha256:imageSha,imageBase:'0x'+base.toString(16)},sourcePins,records:rows.length,functions:[...selected.values()].map(summary),duplicateAddresses:[...byAddress].filter(([,l])=>l.length>1).map(([address,list])=>({address,variants:list.map(r=>({source:r.source,exactSubject:r.exactSubject,pseudocodeUtf16:r.pseudocode.length}))})),anchors:anchors.map(address=>selected.has(address)?summary(selected.get(address)):{address,missing:true}),bodyExports:[...required].filter(a=>selected.has(a)),errors,scope:'Compact retained Ghidra body/call graph index with exact current original-image identity and fresh source-backed PE range hashes. Pseudocode remains historical provider interpretation, not source, dynamic scheduling or measured runtime cost. Missing/unresolved/indirect edges remain explicit. No deep analysis, original execution or writes.'};
fs.writeFileSync(path.join(output,'catalog.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,sources:sourcePins.length,records:rows.length,functions:selected.size,exactFunctions:[...selected.values()].filter(r=>r.exactSubject).length,bodyExports:result.bodyExports.length,errors:errors.length},null,2));
