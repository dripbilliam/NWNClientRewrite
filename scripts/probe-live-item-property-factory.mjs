import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseScriptApi} from '../src/ncs.js';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
import {itemPropertyFactoryOrdinals,createItemProperty} from '../src/item_property_factory.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',resolver=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),session=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)}),api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',RESOURCE_TYPE.NSS))),rows=[];
for(const spec of api.filter(s=>itemPropertyFactoryOrdinals.has(s.id)&&s.returns==='itemproperty'))for(const value of [0,1,3]){
 assert.equal(typeof session.commands[spec.name],'function');
 const p=session.items.propertyFactoryProviders(),replay=[],args=spec.args.map(()=>value),tableRef=t=>t?{name:t.name,count:t.count}:null;
 const source={...p,create:(...args)=>p.create(...args),definition:()=>{const table=p.definition();return{...table,name:'definition'};},
  int:async(t,row,column)=>{const result=await p.int(t,row,column);replay.push({kind:'int',table:t.name,row,column,...result});return result;},
  string:async(t,row,column)=>{const result=await p.string(t,row,column);replay.push({kind:'string',table:t.name,row,column,...result});return result;},
  table:async name=>{const result=await p.table(name);replay.push({kind:'table',name,result:tableRef(result)});return result;},
  cost:async id=>{const result=await p.cost(id);replay.push({kind:'cost',id,result:tableRef(result)});return result;}};
 const result=await createItemProperty(spec.id,args,session.player.id,source),bound=await session.commands[spec.name](args,{self:session.player.id});
 const observe=e=>({type:e.type,durationType:e.durationType,integers:e.integers});assert.deepEqual(observe(bound),observe(result));
 rows.push({name:spec.name,case:{ordinal:spec.id,args,creator:session.player.id,replay},...observe(result)});
}
const report={rows,constructors:rows.length/3,valid:rows.filter(r=>r.type===91).length,invalid:rows.filter(r=>r.type===0).length,limits:'Installed API arities and active ITEMPROPDEF/subtype/cost/parameter tables drive the shared constructor through real session bindings. Source query results/counts are explicit read-only input snapshots for the original command oracle; mutation/equipment/effect execution are not established.'};
await fs.writeFile('backups/animations/live-item-property-factory.json',JSON.stringify(report,null,2));console.log(JSON.stringify({constructors:report.constructors,cases:rows.length,valid:report.valid,invalid:report.invalid,limits:report.limits}));
