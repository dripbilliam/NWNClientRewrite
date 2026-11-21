import fs from 'node:fs/promises';
import {prepareVisualDefinition} from './visual-definition.mjs';
const table=(orderedRows,defaultValue='')=>({orderedRows,defaultValue,columns:[...new Set(orderedRows.flatMap(Object.keys))]});
const out=[];
for(const type of [5,9,10])for(const size of [0,1,3,4,5])for(const instant of [0,1])for(const geometry of [true,false])for(const quality of [0,1]){
 const visuals=table([{Imp_Root_M_Node:geometry?'medium':'',Imp_Root_L_Node:geometry?'large':'',Imp_Root_H_Node:geometry?'huge':'',Imp_HeadCon_Node:'headfx',Imp_Impact_Node:'impactfx',LowQuality:'cheap',OrientWithObject:'1',ProgFX_Impact:'0',ProgFX_Duration:'1',ProgFX_Cessation:'2',ShakeType:'2',ShakeDuration:'.5',ShakeDelay:'0',SoundImpact:'sound'}]);
 const programs=table([{Type:'4',param7:'lightfx',param2:'1.5'},{Type:'7',param1:'beamfx',param6:'duration'},{Type:'12',param2:'failedfx'}]),appearance=table([{SIZECATEGORY:String(size)}]);
 const actor={id:1,objectType:type,appearance:{appearance:0}},source={id:2,objectType:5,appearance:{appearance:0}},objects=new Map([[1,actor],[2,source]]);
 const hosts={1:{type,loadedName:type===9?'plc_chest':'door_test',parts:['root','impact','head','handconjure','chest_impact','door_testimpc']},2:{type:5,loadedName:'human',parts:['root','impact','handconjure']}},settings={quality64:quality,violence40:2};
 const record={visualId:0,sourceId:2,bodyPart:0,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]},delivery:{instant,sourcePart:0,targetPart:0,point:[.123456789,0,0]}};
 const expected=await prepareVisualDefinition({actorId:1,record,objects,modelFor:id=>hosts[id],tables:{visuals,programs,appearance},settings,resource:async name=>({authoredResource:name})});
 expected.state.models88=expected.state.models88.map(model=>model?{id:model.id,resource:model.resource}:null);
 out.push({label:[type,size,instant,geometry,quality].join(':'),actor,record,hosts,settings,tables:{visualeffects:visuals,progfx:programs,appearance},expected:{state:expected.state,programs:expected.programs,visual:expected.visual,hosts:expected.hosts,resources:Object.keys(expected.resources).sort()}});
}
await fs.writeFile('godot-client/reports/native-visual-definition-oracle-v1.json',JSON.stringify(out)+'\n',{flag:'wx'});
console.log(JSON.stringify({cases:out.length,scope:'Authored inputs evaluated by retained reviewed loader; no original asset payloads'}));
