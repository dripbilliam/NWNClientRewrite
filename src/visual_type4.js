const f=Math.fround,call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native Type4 visual provider ${name} is unavailable`);return p[name](...args);};
// Complete14096a570..14096a996. Every table output is used even when the
// query returns false. The +110 gate and +108 shadow flag remain separate;
// Param6 controls the selected-view GUI registration path, not Param5.
export function startType4Visual(e,id,p){
 if(!e.proceduralB8)return;
 const object=call(p,'clientObject',e.target54);if(!object)return;
 const render=call(p,'renderObject',object);if(!render)return;
 id&=65535;
 const animation=String(call(p,'programString',id,'param1').value),speed=f(call(p,'programFloat',id,'param2').value);
 const shadow=call(p,'programInt',id,'param3').value|0,scope=call(p,'programInt',id,'param4').value|0;
 e.field110=call(p,'programInt',id,'param5').value|0;
 const gui=call(p,'programInt',id,'param6').value|0;e.scope10c=scope&255;
 const context=call(p,'view58',render),selected=call(p,'view1406ac1a0'),same=context===selected;
 if(gui&&same){const client=call(p,'controlledClient');if(client.videoF8)call(p,'registerGuiD8',client.videoF8.gui248,e.proceduralB8);}
 call(p,'programAttach14096bbb0',e);
 call(p,'playAnimation',e.proceduralB8,animation,speed,3,0);
 if(e.proceduralB8){call(p,'shadowing',e.proceduralB8,shadow!==0);e.shadow108=shadow!==0?1:0;}
 call(p,'modelSetting1a0',e.proceduralB8,same?2:4);
}

// Complete Type4 local-pose attachment14096bbb0..14096c174. Native
// creature and prefixed object offsets differ; these are local model poses,
// not global bone transforms. Missing pose output retains zero/identity.
export function attachType4Visual(e,p){
 const object=call(p,'clientObject',e.target54);if(!object)return;
 const render=call(p,'renderObject',object);if(!render||!e.proceduralB8)return;
 const parent=call(p,'modelHandle',render,255,1);if(!parent)return;
 const first=call(p,'prefixViewA0',render),second=call(p,'prefixView28',render),creature=call(p,'view58',render);
 let position=[0,0,0],quaternion=[1,0,0,0];
 const name=creature?'headconjure':first?String(first.prefix1e0)+'_head_hit':second?String(second.prefix1c8)+'hhit':null;
 if(name!==null){
  const pose=call(p,'localNodePose',parent,name,{position,quaternion});position=pose.position.map(f);quaternion=pose.quaternion.map(f);
  position[1]=f(position[1]+f(creature ? .75 : .375));position[2]=f(position[2]+f(creature ? .5 : .25));
 }
 call(p,'setLocalNodePose',e.proceduralB8,'root',position,quaternion);
 const anchor=first?String(first.prefix1e0)+'_ground':second?String(second.prefix1c8)+'grnd':'root';
 call(p,'setParent',e.proceduralB8,parent,anchor,0);
 const context=call(p,'view58',render);
 if(context&&context===call(p,'view1406ac1a0')&&context.context30)call(p,'refreshContext1407e9bc0',context.context30);
}

// Complete Type4 stop14096fe00..14096ffc5. No unconditional early return
// for a missing target: Param6/selected-view GUI cleanup still runs. The final
// unparent and scene removal keep the procedural object alive for outer clear.
export function stopType4Visual(e,id,p){
 if(!e.proceduralB8)return;
 const object=call(p,'clientObject',e.target54),render=object?call(p,'renderObject',object):null;
 if(e.attached114&&render){
  const context=call(p,'view58',render);
  if(context&&context===call(p,'view1406ac1a0')&&context.context30)call(p,'refreshContext1407e9bc0',context.context30);
 }
 const gui=call(p,'programInt',id&65535,'param6').value|0;
 if(gui&&call(p,'view1406ac1a0')){
  const selected=call(p,'view1406ac1a0');
  if((selected.id>>>0)===(e.target54>>>0)){
   const client=call(p,'controlledClient');if(client?.videoF8)call(p,'registerGuiD8',client.videoF8.gui248,null);
  }
 }
 call(p,'setParent',e.proceduralB8,0,0,0);call(p,'setScene',e.proceduralB8,0);
}
