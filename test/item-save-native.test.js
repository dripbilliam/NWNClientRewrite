import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {saveNativeItem,saveItemProperties} from '../src/item_save.js';
import {gffField,gffRecord,writeGff} from '../src/gff_writer.js';
import {parseGff,getGffStructType,getGffFieldTypes} from '../src/gff.js';
import {objectTemplateResRef} from '../src/create_object.js';
const observations=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-save-observations.json',import.meta.url)));
const fields={0x40:'baseItem',0x360:'identified',0x454:'stackSize',0x458:'stolen',0x468:'hidden',0x448:'droppable',0x44c:'pickpocketable',0x450:'cursed',0x388:'charges',0x144:'plot',0x398:'dirty',0x390:'unidentifiedPrice',0x394:'addCost',0x38c:'basePrice',0x2ac:'useable',0x3d8:'x',0x3d9:'y'};
const strings={0x68:'tag',0x78:'template',0x410:'descriptionOverride',0x400:'identifiedOverride',0x430:'display'},localized={0x3f0:'description',0x3e0:'identifiedDescription',0x420:'name'};
function fixture(input){
 const c=structuredClone(input),calls=[],ids=new WeakMap();for(const [id,item]of Object.entries(c.items)){ids.set(item,id);item.nodes=item.repository?.map(value=>({value}))??null;item.nodes?.forEach((n,i)=>{n.next=item.nodes[i+1]??null;});}
 const p={scalar:(item,offset)=>item[fields[offset]],writeScalar:(item,offset,value)=>{item[fields[offset]]=value;},string:(item,offset)=>item[strings[offset]],localized:(item,offset)=>item[localized[offset]],resref:objectTemplateResRef,
  properties:(item,active)=>active?item.active:item.passive,appearance:(item,kind,i)=>item[kind][i],partColor:(item,ch,part)=>{calls.push(['partColor',ids.get(item),ch,part]);return item.partColors[ch][part];},
  baseInfo:item=>{calls.push(['base',item.baseItem>>>0]);return c.bases[item.baseItem];},calculateBaseCosts:item=>{calls.push(['calculate',ids.get(item)]);Object.assign(item,item.calculated);},
  repository:item=>item.nodes===null?null:item,head:repo=>repo.nodes[0]??null,next:(_repo,node)=>node.next,value:(_repo,node)=>node.value,
  item:id=>{calls.push(['item',id]);return c.items[id]??null;},float:(item,offset)=>[...item.position,...item.orientation][(offset-0xec)/4],
 };
 for(const [name,label]of [['objectState','StateSaved'],['visualTransform','TransformSaved'],['materialOverrides','MaterialSaved'],['textureOverrides','TextureSaved'],['animationOverrides','AnimationSaved'],['miscVisuals','MiscSaved'],['uuid','UUIDSaved']])p[name]=(item,root)=>{
  calls.push([name,ids.get(item)]);root.fields[label]=gffField(5,Number(ids.get(item)));
  if(name==='objectState'&&item.moveOnState){item.x=91;item.y=92;}
 };
 p.itemProperties=(item,root)=>saveItemProperties(item,p,root);return{c,p,calls};
}
test('whole native item/property save matches fields, physical struct IDs, lower calls and dirty-price state',async()=>{
 assert.equal(observations.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const {case:input,output,calls:expected,state}of observations.cases){
  const {c,p,calls}=fixture(input),item=c.items[101],actual=c.propertiesOnly?saveItemProperties(item,p):await saveNativeItem(item,c.flag,p);
  assert.deepEqual(actual,output,c.name);assert.deepEqual(calls,expected,c.name);
  const actualState=Object.fromEntries(Object.entries(c.items).map(([id,item])=>[id,Object.fromEntries(Object.entries(fields).filter(([offset])=>Number(offset)!==0x3d8&&Number(offset)!==0x3d9).map(([_offset,key])=>[key,item[key]|0]))]));
  assert.deepEqual(actualState,state,c.name);
 }
});
test('recursive item save retains skipped node ordinals, byte coordinates and pre-recursion snapshots',async()=>{
 const {c,p}=fixture(observations.cases.find(x=>x.case.name==='recursive-0').case),root=parseGff(writeGff('UTI ',await saveNativeItem(c.items[101],0,p)),'UTI ').root;
 assert.equal(root.ItemList.length,2);assert.deepEqual(root.ItemList.map(getGffStructType),[2,3]);
 assert.equal(root.ItemList[0].Repos_PosX,4);assert.equal(c.items[102].x,91);assert.equal(getGffFieldTypes(root.ItemList[0]).Repos_PosX,0);
 assert.equal(root.TemplateResRef,'MiXeD_Template_T');assert.equal(getGffFieldTypes(root).BaseItem,5);
 assert.deepEqual(root.PropertiesList.map(getGffStructType),[0,2]);assert.equal(root.PropertiesList[0].Useable,1);
});
test('unsupported lower owners cannot silently produce successful item serialization',async()=>{
 const {c,p}=fixture(observations.cases[0].case);p.objectState=undefined;await assert.rejects(saveNativeItem(c.items[101],0,p),/objectState/);
});
test('cyclic runtime repositories are diagnosed rather than overflowing recursive saves',async()=>{
 const {c,p}=fixture(observations.cases[0].case);c.bases[1].container=1;c.items[101].nodes=[{value:101,next:null}];
 await assert.rejects(saveNativeItem(c.items[101],0,p),/repository recursion contains a cycle/);
});
