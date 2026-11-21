import fs from 'node:fs/promises';import assert from 'node:assert/strict';import {createVaultHandoffFixture} from './vault-handoff-fixture.mjs';
const name=process.argv.find(v=>v.startsWith('--report='))?.slice(9);assert.match(name??'',/^vault-handoff-fixtures-v[0-9]+\.json$/);const output='godot-client/reports/'+name;
try{await fs.access(output);throw Error('Use a new fixture report');}catch(e){if(e.code!=='ENOENT')throw e;}
const source=Number(process.argv.find(v=>v.startsWith('--source='))?.slice(9)??17);
const fixture=await createVaultHandoffFixture(JSON.parse(await fs.readFile('godot-client/reports/handoff-server-fixtures-v1.json','utf8')),{source});await fs.writeFile(output,JSON.stringify(fixture,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,root:fixture.root,source,sharedVault:true,servers:fixture.servers.map(v=>({label:v.label,port:v.port,module:v.module}))}));
