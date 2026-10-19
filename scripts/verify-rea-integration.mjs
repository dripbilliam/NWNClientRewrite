import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {reaResearchTools} from './rea-tool-policy.mjs';
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),directory=path.join(workspace,'backups/animations'),require=createRequire(path.join(workspace,'tooling/rea/package.json')),{parse}=await import(pathToFileURL(require.resolve('smol-toml')).href);
const read=async name=>JSON.parse(await fs.readFile(path.join(directory,name),'utf8')),config=parse(await fs.readFile(path.join(workspace,'.codex/config.toml'),'utf8')).mcp_servers.rea_nwn;
assert.deepEqual(config.enabled_tools,[...reaResearchTools]);assert.equal(config.tool_timeout_sec,1200);assert.equal(config.startup_timeout_sec,30);assert.deepEqual(config.args,[path.join(workspace,'scripts/rea-mcp.mjs')]);
const loaded=await read('rea-integration-codex-get-v2.json');assert.equal(loaded.name,'rea_nwn');assert.equal(loaded.enabled,true);assert.deepEqual(loaded.transport.args,config.args);assert.deepEqual(loaded.enabled_tools,[...reaResearchTools]);
const paging={};
if(reaResearchTools.includes('inspect_analysis_view')){
 const source=await read('rea-client-safe-projectile-receiver-paged-source.json');assert.equal(source.isError,true);
 const limit=JSON.parse(source.content[0].text).error.details.reported_limits;assert.equal(limit.boundary,'mcp-response');assert.ok(limit.response_bytes_at_least>limit.result_budget_bytes);
 for(const [facet,file]of[['pseudocode','rea-client-safe-projectile-pseudocode-complete.json'],['assembly','rea-client-safe-projectile-assembly-complete.json']]){
  const response=await read(file),view=response.structuredContent.normalized_result;assert.ok(!response.isError);assert.equal(view.parent_evidence_id,limit.evidence_id);assert.equal(view.procedure_address,'0x1407ac670');assert.equal(view.artifact.sha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
  assert.equal(view.coverage.exhausted,true);assert.equal(view.coverage.next_offset,null);assert.equal(view.coverage.examined,view.coverage.total);assert.equal(facet==='pseudocode'?view.item.text.length:view.item.length,view.coverage.total);
  if(facet==='assembly'){assert.ok(view.item[0].startsWith('0x1407ac670:'));assert.equal(view.item.at(-1),'0x1407ae8c4: RET');}
  paging[facet]={total:view.coverage.total,exhausted:true};
 }
}
const pkg=JSON.parse(await fs.readFile(path.join(workspace,'tooling/rea/package.json'))),lock=JSON.parse(await fs.readFile(path.join(workspace,'tooling/rea/package-lock.json')));assert.equal(pkg.dependencies['rea-agents'],'6.5.0');assert.equal(lock.packages['node_modules/rea-agents'].version,'6.5.0');
const expected=new Map();for(const file of['resumed-spell-command-bodies-v1.txt','resumed-vector-normalize-bodies-v1.txt']){
 let active;for(const line of(await fs.readFile(path.join(directory,file),'utf8')).split(/\r?\n/)){const header=line.match(/^FUNCTION REQUESTED ([\da-f]+)/i);if(header){active=[];expected.set('0x'+header[1],active);continue;}const ins=line.match(/^([\da-f]+):\s+(\w+)/i);if(ins&&active)active.push([BigInt('0x'+ins[1]).toString(16),ins[2].toLowerCase()]);}
}
const alias={jz:'je',jnz:'jne',cmovz:'cmove',cmovnz:'cmovne'},commands=[];
for(const name of['location-access-dossier','vector-normalize-dossier','print-string-dossier']){
 const mcp=await read('rea-'+name+'.json');assert.ok(!mcp.isError);const evidence=mcp.structuredContent;assert.equal(evidence.subject.digest.sha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(evidence.provider.id,'ghidra');assert.equal(evidence.provider.version,'12.1.4');
 const result=evidence.normalized_result,actual=result.assembly.map(line=>{const m=line.match(/^0x([\da-f]+):\s+(\w+)/i);return[m[1].toLowerCase(),m[2].toLowerCase()];}),canonical=rows=>rows.map(([address,mnemonic])=>[address,alias[mnemonic]??mnemonic]);
 assert.deepEqual(canonical(actual),canonical(expected.get(result.procedure.address)));commands.push({name:result.procedure.name,address:result.procedure.address,bytes:result.procedure.body.total_bytes,instructions:actual.length});
}
const logs=(await fs.readFile(path.join(workspace,'runtime-logs/rea-session-stderr.txt'),'utf8')).trim().split('\n').flatMap(line=>{try{return[JSON.parse(line)]}catch{return[]}}),cold=logs.filter(r=>r.status==='ok'&&r.tool==='search_procedures').sort((a,b)=>b.durationMs-a.durationMs)[0],warm=logs.filter(r=>r.status==='ok'&&r.tool==='analyze_function');assert.ok(cold.durationMs>60000);assert.ok(warm.length>=3);
const baseline=JSON.parse(await fs.readFile(path.join(workspace,'backups/rea-trial/baseline.json')));for(const row of baseline){try{const bytes=await fs.readFile(row.file);assert.ok(!row.absent);assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),row.sha256);}catch(error){if(row.absent&&error.code==='ENOENT')continue;throw error;}}
const report={validation:'PASS',scope:'project',server:'rea_nwn',tools:reaResearchTools.length,packageVersion:'6.5.0',codexRegistrationReadback:true,protectedInputsAndGlobalConfigUnchanged:true,commands,paging,firstPersistentQueryMs:cold.durationMs,warmQueryMs:warm.slice(0,3).map(r=>r.durationMs),limits:'Current agent uses the persistent shell MCP client; registered native tools require client reload to appear in its own catalog. Instruction addresses/mnemonics/body lengths and complete retained native view coverage are checked here; full semantics are independently tested by original-code oracles. The earlier SDK1-style timeout call failed and was corrected for SDK2.'};
await fs.writeFile(path.join(directory,'rea-integration-verification.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
