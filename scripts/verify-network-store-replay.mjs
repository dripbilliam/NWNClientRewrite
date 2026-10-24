import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import path from 'node:path';
import {openLocalModule} from './local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkText} from '../src/network_text.js';
import {parseTalkTable} from '../src/talk_table.js';
const install=path.resolve('../FullDecomp/NwnRootInstall'),resolver=await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),rules=await loadNetworkObjectRules(resolver),talk=parseTalkTable(await fs.readFile(path.join(install,'lang/en/data/dialog.tlk'))),world=new NetworkWorld(),diagnostics=[],text=new NetworkText({world,getResource:(...a)=>resolver.getResource(...a),talkString:async ref=>({text:talk.get(ref)??''}),diagnose:(...a)=>diagnostics.push(a)}),report=JSON.parse(await fs.readFile('backups/animations/local-network-hierarchy-parallel-v165.json','utf8')),stores=[],stock=[],incomplete=[];
for(const hex of report.wireMessages){
 const m=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},serverBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(m);
 if(m.kind==='store-open')stores.push(m);if(m.kind==='object-updates'){if(!m.complete)incomplete.push(m.unhandled);for(const r of m.records)if(r.channel==='M')stock.push(r);}
}
assert.ok(stores.length>0);assert.ok(stock.some(r=>r.operation==='A'));assert.ok(!incomplete.some(r=>/channel M/.test(r.reason)));
const pc=world.registry.get(world.localObjectId),cls=pc.replicated.stats.classes[0],table=await text.rules('classes'),expected=talk.get(Number(table.orderedRows[cls.id].Lower));assert.equal(await text.resolve({text:'<class>'},pc.id),expected);assert.deepEqual(diagnostics,[]);
const out={validation:'PASS',scope:'Replay of sealed user-driven v165 original-server messages; new client decoder, registry and installed rule token provider. No live purchase claim.',source:'local-network-hierarchy-parallel-v165.json',stores,stockRecords:stock.length,stockAdds:stock.filter(r=>r.operation==='A').length,firstClassId:cls.id,lowerClassToken:expected,unhandledRecords:incomplete};await fs.writeFile('backups/animations/network-store-replay-v1.json',JSON.stringify(out,null,2)+'\n');console.log(JSON.stringify({validation:out.validation,stores:stores.length,stockRecords:stock.length,stockAdds:out.stockAdds,lowerClassToken:expected,otherUnhandled:incomplete.length}));
