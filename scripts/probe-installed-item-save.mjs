import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {parseGff,getGffStructType} from '../src/gff.js';
import {gffField as f,gffRecord as record,writeGff} from '../src/gff_writer.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {intEntry} from '../src/combat_stats.js';
import {createObjectAction,setActionParameter} from '../src/object_actions.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-item-save-v1.json',report={},start=runtimeDiagnostics.records.length;
async function invoke(s,name,args){const id=s.vm.api.findIndex(r=>r.name===name),spec=s.vm.api[id],stack={stack:[]};assert.ok(id>=0);for(let i=args.length-1;i>=0;i--)s.vm.push(stack,spec.args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,id>>>8,id&255,args.length,0x20,0],13);return s.vm.run(parseNcs(ncs,'item_save_'+name),s.player.id,{situation:{pc:13,bp:0,stack:stack.stack}});}
const decode=tree=>parseGff(writeGff('UTI ',tree),'UTI ').root;
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
 const permanent=(await invoke(s,'ItemPropertyEnhancementBonus',[1])).stack[0].value;
 const allowed=base=>{if(!base||base.modelType!==2||base.weaponType===0)return false;const table=s.characterRules.itemprops,cell=table.orderedCells?.[permanent.integers[0]]?.[base.basePropColumn];return intEntry({defaultValue:table.defaultValue,orderedRows:cell===undefined?[]:[{cell}]},0,'cell').value!==0;};
 let item=[...s.registry.objects.values()].find(o=>o.objectType===6&&o.nativeItemLoaded&&allowed(s.items.baseInfo(o)));
 if(!item)for(const resource of s.resolver.key.resources.values()){
  if(resource.resourceType!==2025)continue;const data=parseGff(await s.resolver.getResource(resource.resref,2025),'UTI ').root,base=s.items.baseInfo({baseItem:data.BaseItem});
  if(!allowed(base))continue;
  const id=await s.createItem(resource.resref,s.player.id,1,'');item=s.registry.get(id);if(item){report.fixtureResource=resource.resref;break;}
 }
 assert.ok(item?.nativeItemLoaded);const ids=[...s.registry.objects.keys()],next=[...s.registry.nextObjectId],authored=JSON.stringify(item.authored);
 report.selected={itemId:item.id,baseItem:item.baseItem,propertyType:permanent.integers[0]};const baseline=decode(s.items.saveProperties(item));
 await invoke(s,'AddItemProperty',[2,permanent,item.id,0]);const lasting=decode(s.items.saveProperties(item));assert.equal(lasting.PropertiesList.length,baseline.PropertiesList.length+1);
 const temporary=(await invoke(s,'ItemPropertyEnhancementBonus',[2])).stack[0].value;await invoke(s,'AddItemProperty',[1,temporary,item.id,60]);
 const saved=decode(s.items.saveProperties(item));assert.deepEqual(saved,lasting);
 const wholeWithProperties=decode(await s.items.save(item));assert.deepEqual(wholeWithProperties.PropertiesList,saved.PropertiesList);
 assert.ok(wholeWithProperties.EffectList?.length);assert.ok(wholeWithProperties.EffectList.every(e=>(e.SubType&7)===1));
 assert.ok(wholeWithProperties.EffectList.some(e=>e.Id===BigInt(`0x${temporary.id}`)));
 const expected=[...item.activeProperties.map((p,i)=>({p,i})),...item.passiveProperties.map((p,i)=>({p,i:i+item.activeProperties.length}))].filter(({p})=>(p.durationType&255)===2);
 assert.deepEqual(saved.PropertiesList.map(getGffStructType),expected.map(e=>e.i));
 for(let i=0;i<expected.length;i++){assert.equal(saved.PropertiesList[i].PropertyName,expected[i].p.type&65535);assert.equal(saved.PropertiesList[i].Useable,expected[i].p.remaining&255);}
 report.properties={itemId:item.id,baseline:baseline.PropertiesList.length,saved:saved.PropertiesList.length,temporaryOmitted:true,permanentEffectId:String(permanent.id),temporaryEffectId:String(temporary.id)};
 await invoke(s,'RemoveItemProperty',[item.id,temporary]);await invoke(s,'RemoveItemProperty',[item.id,permanent]);await s.scheduler.pump();assert.deepEqual(decode(s.items.saveProperties(item)),baseline);report.properties.cleanup=true;
 const curve=record({TimerType:f(5,0),ValueTo:f(8,2),ValueFrom:f(8,1),LerpType:f(5,1),LerpDuration:f(8,2),LerpProgress:f(8,0),BehaviorFlags:f(5,0),RepeatsRemaining:f(5,0)},0);
 const fixture=decode(record({VisTransformList:f(15,[record({Scope:f(5,0),ScaleX:f(14,curve)},6)]),Material:f(14,record({ShaderParams:f(15,[record({Type:f(0,1),Int:f(5,7),Material:f(10,'material'),Param:f(10,'parameter')},0)])},7)),TextureReplace:f(14,record({TextureReplaceLi:f(15,[record({OldTexture:f(11,'OldCase'),NewTexture:f(11,'NewCase')},0)])},9)),AnimationReplace:f(14,record({AnimationReplace:f(15,[record({OldAnimation:f(11,'walk'),NewAnimation:f(11,'run')},0)])},11)),MiscVisuals:f(14,record({MouseCursor:f(5,7),VisibleDistance:f(8,65),TextBubbleText:f(10,'bubble')},8))}));
 for(const owner of [0x140497bb0,0x140496ea0,0x140497990,0x1404969c0,0x1404972b0])await s.objectVisuals.loadOwner(item,fixture,owner);
 if(!item.nativeUUID.value)assert.equal(await s.uuids.tryAssign(item,'12345678-1234-1234-1234-123456789abc'),1);
 const visual=decode(await s.objectVisuals.save(item));assert.equal(visual.UUID,item.nativeUUID.value);assert.equal(visual.Material.ShaderParams[0].Int,7);assert.equal(visual.TextureReplace.TextureReplaceLi[0].OldTexture,'OldCase');assert.equal(visual.AnimationReplace.AnimationReplace[0].NewAnimation,'run');assert.equal(visual.MiscVisuals.MouseCursor,7);assert.equal(visual.MiscVisuals.TextBubbleText,'bubble');
 const scale=visual.VisTransformList[0].ScaleX;assert.equal(scale.ValueTo,2);assert.equal(scale.ValueFrom,1);assert.ok(scale.LerpProgress>=0&&scale.LerpProgress<=1);
 await invoke(s,'SetLocalInt',[item.id,'save-probe',17]);await invoke(s,'SetLocalFloat',[item.id,'save-probe',1.25]);
 await invoke(s,'SetLocalString',[item.id,'save-text','local\0tail']);await invoke(s,'SetLocalObject',[item.id,'save-object',s.player.id]);
 const location=(await invoke(s,'GetLocation',[s.player.id])).stack[0].value;await invoke(s,'SetLocalLocation',[item.id,'save-location',location]);
 const whole=decode(await s.items.save(item));assert.deepEqual(whole.PropertiesList,baseline.PropertiesList);assert.deepEqual(whole.ActionList,[]);
 assert.deepEqual({...whole.Transition},{TargetTag:'',TargetObjectId:0x7f000000});assert.equal(whole.UUID,visual.UUID);assert.equal(whole.Material.ShaderParams[0].Int,7);
 assert.equal(whole.Useable,item.nativeUseable264);assert.equal(whole.BaseItem,item.baseItem);assert.equal(whole.Tag,item.tag);
 const vars=whole.VarTable;assert.deepEqual(vars.filter(v=>v.Name==='save-probe').map(v=>[v.Type,v.Value]),[[2,1.25],[1,17]]);
 assert.equal(vars.find(v=>v.Name==='save-text').Value,'local\0tail');assert.equal(vars.find(v=>v.Name==='save-object').Value,s.player.id);
 const local=vars.find(v=>v.Name==='save-location');assert.equal(local.Type,5);assert.equal(local.Value.Area,location.areaId);assert.equal(local.Value.PositionX,location.position[0]);
 const originalTransition=structuredClone(item.nativeTransition288);s.objectState.transitionLoad(item,whole);assert.deepEqual(item.nativeTransition288,originalTransition);
 report.wholeItem={nativeState:true,temporaryEffectIds:wholeWithProperties.EffectList.map(e=>String(e.Id)),permanentProperties:true,localTypes:vars.map(v=>v.Type),transition:true,visualOwners:true};
 const action=createObjectAction(19,0xabcd);setActionParameter(action,0,3,s.player.id);setActionParameter(action,1,2,0x3fa00000);const link=item.objectActionState.list.insert(action);
 const queued=decode(await s.items.save(item));assert.equal(queued.ActionList[0].GroupActionId,0xabcd);assert.equal(queued.ActionList[0].Paramaters[0].Value,s.player.id);assert.equal(queued.ActionList[0].Paramaters[1].Value,1.25);item.objectActionState.list.remove(link);report.wholeItem.queuedPrimitiveActions=true;
 const opaque=createObjectAction(37,0);setActionParameter(opaque,0,5,{pc:13,stack:[]});const opaqueLink=item.objectActionState.list.insert(opaque);
 await assert.rejects(s.items.save(item),/script-situation serialization state is unavailable/);item.objectActionState.list.remove(opaqueLink);report.wholeItem.unsupportedVmStateDiagnosed=true;
 assert.deepEqual([...s.registry.objects.keys()],ids);assert.deepEqual(s.registry.nextObjectId,next);assert.equal(JSON.stringify(item.authored),authored);
 report.visuals={typedFixtureLoadedThroughNativeOwners:true,curvesSaved:true,progress:scale.LerpProgress,material:true,textures:true,animations:true,misc:true,uuid:visual.UUID,identitiesUnchanged:true};
 const restored=s.register('item','probe:saved-item-restored',{authored:{},deferTagLookup:true}),effectCursor=s.effects.nextId;
 assert.equal(await s.items.loadFromGff(restored,wholeWithProperties,{loading:1}),1);
 assert.equal(s.effects.nextId,effectCursor+BigInt(wholeWithProperties.PropertiesList.length));
 const temporarySaved=wholeWithProperties.EffectList.find(e=>e.Id===BigInt(`0x${temporary.id}`)),restoredEffect=restored.effects.find(e=>e.id===temporary.id);assert.ok(restoredEffect);
 assert.equal(restoredEffect.expiryDay,temporarySaved.ExpireDay);assert.equal(restoredEffect.expiryTime,temporarySaved.ExpireTime);assert.notEqual(restoredEffect.propertyId,'0000000000000000');
 assert.equal([...restored.activeProperties,...restored.passiveProperties].filter(p=>p.durationType===1).length,1);
 await s.effects.updateObject(restored,{day:restoredEffect.expiryDay,time:restoredEffect.expiryTime});assert.ok(restored.effects.some(e=>e.id===temporary.id));
 await s.effects.updateObject(restored,{day:restoredEffect.expiryDay,time:restoredEffect.expiryTime+1});assert.ok(!restored.effects.some(e=>e.id===temporary.id));
 assert.equal([...restored.activeProperties,...restored.passiveProperties].filter(p=>p.durationType===1).length,0);
 assert.equal([...restored.activeProperties,...restored.passiveProperties].filter(p=>p.durationType===2).length,wholeWithProperties.PropertiesList.length);
 report.restore={canonicalItemId:restored.id,temporaryEffectId:restoredEffect.id,expiryPreserved:true,loadedEffectDoesNotAllocateId:true,temporaryPropertyReapplied:true,strictExpiryAndRemoval:true,permanentPropertiesRemain:true};
 const existing=createObjectAction(49,12),existingLink=restored.objectActionState.list.insert(existing),objectIds=[...s.registry.objects.keys()],allocator=s.effects.nextId;
 await s.objectState.load(restored,queued);const actions=[...restored.objectActionState.list];assert.equal(actions.length,2);assert.equal(actions[0],existing);assert.equal(actions[1].actionId,19);assert.equal(actions[1].groupId,0xabcd);assert.equal(actions[1].parameterData[0],s.player.id);assert.equal(actions[1].parameterData[1],0x3fa00000);
 const savedQueue=decode(await s.items.save(restored));assert.equal(savedQueue.ActionList.length,2);assert.equal(savedQueue.ActionList[1].Paramaters[1].Value,1.25);assert.deepEqual([...s.registry.objects.keys()],objectIds);assert.equal(s.effects.nextId,allocator);restored.objectActionState.list.remove(existingLink);restored.objectActionState.list.shift();
 report.restore.queuedActions={appended:true,priorNodeIdentity:true,objectAndFloatBits:true,resaved:true,noIdentityAllocation:true};report.ok=true;
}catch(error){report.ok=false;report.error=error.stack;process.exitCode=1;}
finally{report.diagnostics=runtimeDiagnostics.records.slice(start);await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));}
