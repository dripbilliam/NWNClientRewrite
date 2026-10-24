import {intEntry} from './combat_stats.js';
import {nativeStringEntry} from './spell_metadata.js';
import {nativeItemResourceRef} from './item_model.js';
export const itemIconDescriptor=(item,gender=0)=>({kind:'item',gender,appearance:{baseItem:item.baseItem,parts:item.parts,colors:item.colors,partColors:item.partColors,properties:item.properties}});

// CNWCItem::UpdateIcons14083f6f0 and CGuiIcon subclasses. Selection uses the
// active server tables; no character/module-specific icon names are embedded.
export function itemIconPlan(item,tables,{gender=0}={}){
 const b=tables.baseitems,type=intEntry(b,item.baseItem,'ModelType').value,width=intEntry(b,item.baseItem,'InvSlotWidth').value,height=intEntry(b,item.baseItem,'InvSlotHeight').value;
 if(!(width>0&&height>0&&width<=10&&height<=10))throw Error('Native item icon dimensions are unavailable');
 const text=name=>nativeStringEntry(b,item.baseItem,name).value,schema={modelType:type,itemClass:text('ItemClass'),genderSpecific:Boolean(intEntry(b,item.baseItem,'GenderSpecific').value)},variant=gender===1?70:77;
 const fallback=text('DefaultIcon'),colors=item.colors??[],palette=[0,0,colors[4]??0,colors[5]??0,colors[2]??0,colors[3]??0,colors[0]??0,colors[1]??0,0,0];
 const name=(part,id)=>nativeItemResourceRef(schema,part,id,variant,true).toLowerCase();
 if(type===3){
  const parts=[6,7,8,14,15,18],paletteParts=[6,7,8,15,14,18],robe=item.parts[18]??0;
  const palettes=paletteParts.map(index=>{const p=[...palette];for(const[c,channel]of [6,7,4,5,2,3].entries()){const value=item.partColors?.[index]?.[c];if(value!==undefined&&value!==255)p[channel]=value;}return p;});
  return{kind:'armor',width:2,height:3,palettes,layers:parts.map((index,i)=>{
   const hide=['HIDEPELVIS','HIDECHEST','HIDEBELT','HIDESHOR','HIDESHOL'][i];
   // The native table uses these exact named columns, independent of CAPart order.
   const h=i<5?intEntry(tables.parts_robe,robe,hide):null;
   if(i===5&&robe<3||i<5&&robe>=3&&(!h.found||h.value!==0))return null;
   const part=tables.capart?.rows.get(index)?.MDLNAME;if(!part||part==='****')throw Error('Native armor icon part name is unavailable');
   return{primary:('ip'+String.fromCharCode(variant).toLowerCase()+'_'+part+String(item.parts[index]??0).padStart(3,'0')).toLowerCase().slice(0,16),type:6};
  }),fallback:'ipm_chest001'};
 }
 if(![0,1,2].includes(type))throw Error('Native item icon model type is unavailable');
 let id=item.parts[0];if(type===1&&item.baseItem===80){const icon=intEntry(tables.cloakmodel,id,'ICON');if(icon.found)id=icon.value;}
 let primary=name(0,id);
 if(type===0&&item.baseItem===75){const prop=item.properties?.find(p=>p.type===15),spell=prop&&nativeStringEntry(tables.iprp_spells,prop.subtype,'Icon');if(spell?.found&&spell.value)primary=spell.value;}
 return{kind:type===1?'layered':type===2?'composite':'flat',width,height,layers:Array.from({length:type===2?3:1},(_,part)=>({primary:type===2?name(part,item.parts[part]):primary,fallback,type:type===1?6:3,palette:type===1?palette:null}))};
}

// Armor load compacts only existing PLTs before selecting its six-layer model.
// All other icon types admit their native DefaultIcon only after Exists fails.
export async function selectItemIcon(plan,exists){
 const layers=[];
 for(const layer of plan.layers){if(!layer)continue;let name=layer.primary;if(!await exists(name,layer.type)){if(plan.kind==='armor')continue;name=layer.fallback;if(!name||name==='****'||!await exists(name,layer.type))throw Error('Native item icon '+layer.primary+' and its default are unavailable');}
  layers.push({...layer,name,palette:plan.kind==='armor'?plan.palettes[layers.length]:layer.palette});
 }
 if(!layers.length&&plan.kind==='armor')layers.push({name:plan.fallback,type:6,palette:plan.palettes[0]});
 const model=plan.kind==='armor'?'gui_icon_armr'+layers.length+'l':`gui_icon_${plan.width}x${plan.height}l${plan.kind==='composite'?'c':''}`;
 return{...plan,layers,model};
}
