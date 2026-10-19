import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),directory=path.join(workspace,'backups/rea-trial');
const read=async name=>JSON.parse(await fs.readFile(path.join(directory,name),'utf8'));
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const registry=await read('registry-metadata.json'),tarball=await fs.readFile(path.join(directory,'rea-agents-6.5.0.tgz'));
assert.equal('sha512-'+crypto.createHash('sha512').update(tarball).digest('base64'),registry.dist.integrity);
const binary=await read('owned-function.json'),nwn=await read('nwn-heading.json'),doctor=await read('doctor.json'),mcp=await read('mcp-doctor.json');
assert.equal(doctor.healthy,true);assert.equal(mcp.healthy,true);assert.equal(mcp.request_flow.ok,true);assert.equal(mcp.inventory.tools.observed,mcp.inventory.tools.expected);
assert.equal(binary.subject.digest.sha256,digest(await fs.readFile(path.join(directory,'owned-arithmetic-fixture.exe'))));
assert.deepEqual(binary.normalized_result.procedure.body.ranges,[{start:'0x140001000',end:'0x140001008'}]);
assert.equal(binary.normalized_result.procedure.body.total_bytes,9);assert.equal(binary.normalized_result.assembly.length,3);
assert.match(binary.normalized_result.pseudocode,/param_1\s*\+\s*param_2\s*\*\s*2\s*\^\s*0x13579bdf/);
assert.equal(nwn.subject.digest.sha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
const expectedText=await fs.readFile(path.join(workspace,'backups/animations/map-player-heading-angle-v1.txt'),'utf8');
const parse=text=>text.trim().split(/\r?\n/).flatMap(line=>{const m=line.match(/^(?:0x)?([a-f\d]+):\s+(\w+)\s*(.*)$/i);return m?[{address:BigInt('0x'+m[1]),mnemonic:m[2].toLowerCase(),operands:m[3]}]:[];});
const expected=parse(expectedText),actual=parse(nwn.normalized_result.assembly.join('\n'));assert.equal(expected.length,17);assert.equal(actual.length,17);
const canonical=(row,next)=>{
 const alias={jz:'je',jnz:'jne'},operands=row.operands.toLowerCase().replace(/\[rip\s*\+\s*(0x[a-f\d]+)\]/g,(_s,offset)=>`[0x${(next+BigInt(offset)).toString(16)}]`).replace(/\b(?:byte|word|dword|qword|xmmword)\s+ptr\s*/g,'').replace(/0x[a-f\d]+/g,v=>BigInt(v).toString()).replace(/\s+/g,'');
 return{address:row.address.toString(16),mnemonic:alias[row.mnemonic]??row.mnemonic,operands};
};
for(let i=0;i<expected.length;i++)assert.deepEqual(canonical(actual[i],actual[i+1]?.address),canonical(expected[i],expected[i+1]?.address));
const result=nwn.normalized_result;assert.equal(result.procedure.body.total_bytes,62);assert.equal(result.procedure.body.non_contiguous,false);
assert.deepEqual(result.procedure.body.ranges,[{start:'0x14022f690',end:'0x14022f6cd'}]);
assert.ok(result.incoming_references.some(r=>r.source_address==='0x140894c88'));
for(const target of['0x140c8f29c','0x140d81990','0x140d81948'])assert.ok(result.outgoing_references.some(r=>r.target_address===target),target);
const baseline=await read('baseline.json');for(const row of baseline){try{const bytes=await fs.readFile(row.file);assert.ok(!row.absent);assert.equal(digest(bytes),row.sha256,row.file);}catch(error){if(row.absent&&error.code==='ENOENT')continue;throw error;}}
const runs=await Promise.all(['version','doctor','function-help','mcp-help','mcp-doctor','owned-function','nwn-heading'].map(name=>read(name+'.run.json')));for(const run of runs){assert.equal(run.code,0);assert.equal(run.controlsUnchanged,true);}
const report={validation:'PASS',packageVersion:registry.version,registrySha512Verified:true,ghidraVersion:nwn.provider.version,mcp:{healthy:mcp.healthy,tools:mcp.inventory.tools.observed,request:mcp.request_flow},fixture:{bytes:9,instructions:3,coldQueryMs:runs.find(r=>r.name==='owned-function').durationMs},nwn:{function:result.procedure.address,reportedName:result.procedure.name,bytes:62,instructionsCompared:17,allInstructionOperandsCompared:true,knownCallSite:'0x140894c88',references:['0x140c8f29c','0x140d81990','0x140d81948'],coldQueryMs:runs.find(r=>r.name==='nwn-heading').durationMs},protectedFileHashesUnchanged:true,limits:'Static analysis and temporary stdio MCP only. No game/fixture execution, persistent registration, existing-project annotation, whole-binary correctness or VM/sandbox security certification. Default NWN import logs analysis warnings; pseudocode types/bit casts still require interpretation.'};
await fs.writeFile(path.join(directory,'verification.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
