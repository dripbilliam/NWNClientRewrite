import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {parseGff} from '../src/gff.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-store-templates-v1.json',report={stores:[]};
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,resources=[...s.resolver.key.resources.values()].filter(r=>r.resourceType===2051);report.availableTemplates=resources.length;assert.ok(resources.length,'Installed UTM resources are required');
 for(const resource of resources){
  const data=parseGff(await s.resolver.getResource(resource.resref,2051),'UTM ').root,o=s.register('store',`runtime:utm:${s.registry.nextObjectId[0]}`,{tag:'',authored:{},deferTagLookup:true}),id=o.id;
  assert.equal(await s.worldTemplates.load('store',o,resource.resref,`InstalledUTM_${id}`),1);assert.equal(o.templateResRef,resource.resref);assert.equal(o.areaId,OBJECT_INVALID);assert.equal(s.registry.get(id),o);assert.equal(s.commands.GetObjectByTag([o.tag]),id);
  assert.equal(o.nativeStoreFields[0x380],data.MarkDown??0);assert.equal(o.nativeStoreFields[0x384],data.MarkUp??0);
  const panels=[];
  for(const [panel,repo]of o.nativeStoreRepositories.entries()){
   const items=[];
   for(const childId of repo.ids()){
    const item=s.registry.get(childId);assert.equal(item.objectType,6);assert.equal(item.nativeItemFromGffLoaded,true);assert.equal(item.identified,1);assert.equal(item.possessorId,id);const price=await s.items.price(item,0,1,0,0);assert.ok(Number.isInteger(price)&&price>=0&&price<=0xffffffff);
    const info=s.items.baseInfo(item);assert.equal(panel,info.storePanel>=5?4:info.storePanel);items.push({id:childId,baseItem:item.baseItem,template:item.templateResRef,priority:info.storePanelSort,price,infinite:item.nativeInfinite444});
   }
   panels.push(items);
  }
  const children=o.nativeStoreRepositories.flatMap(repo=>[...repo.ids()]),tree=[];const collect=id=>{tree.push(id);for(const child of s.registry.get(id)?.nativeRepository?.ids()??[])collect(child);};children.forEach(collect);
  const next=s.registry.nextObjectId[0];await s.lifecycle.destroy(o);assert.equal(s.registry.get(id),undefined);assert.equal(s.registry.nextObjectId[0],next);for(const childId of tree)assert.equal(s.registry.get(childId),undefined);assert.equal(o.nativeStoreName360,null);assert.equal(o.nativeStoreBuyArrays[0x398],null);
  report.stores.push({id,resource:resource.resref,panels,children:children.length,deleted:tree.length,nextId:next});
 }
 report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);assert.ok(report.stores.some(s=>s.children>0),'Installed templates must exercise actual stock');report.validation='PASS';
 report.limits='Installed UTM template/data/variable/UUID providers with active baseitems, item property/price tables and canonical repositories; original resources read-only; recursive destruction and allocator checked. Startup/AI disabled. No store GUI/trade, GIT store-import parity, arbitrary saved effects/actions, CreateObject243 binding or campaign completion claim.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,availableTemplates:report.availableTemplates,stores:report.stores.map(s=>({id:s.id,resource:s.resource,children:s.children,deleted:s.deleted})),failure:report.failure}));if(report.failure)process.exitCode=1;
