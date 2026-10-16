const f=Math.fround,call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native visual attachment provider ${name} is unavailable`);return p[name](...args);};
// Complete14096ed70..14096f6bd (trailing bytes are its dispatch table).
// This is the selection-time attachment owner, distinct from initial placement
//1409702e0: modelHandle takes(255,0), missing handles return early, metadata
// is not reapplied and the current procedural type selects its own lower path.
export function attachVisualModels(e,p){
 const object=call(p,'clientObject',e.target54);if(!object)return;
 const render=call(p,'renderObject',object);if(!render)return;
 const parent=call(p,'modelHandle',render,255,0);if(!parent)return;
 e.attached114=1;
 const first=call(p,'prefixViewA0',render),second=call(p,'prefixView28',render);
 const firstSuffix=['_ground','_impact','_head_hit'],secondSuffix=['grnd','impc','hhit'],fallback=['root','impact','head'];
 for(let i=0;i<3;i++)if(e.models88[i]){
  const anchor=first?String(first.prefix1e0)+firstSuffix[i]:second?String(second.prefix1c8)+secondSuffix[i]:fallback[i];
  call(p,'setParent',e.models88[i],parent,anchor,e.orient120?0:3);
  if(!e.orient120){const pose=call(p,'nodePose',e.models88[i],'root');call(p,'setNodePose',e.models88[i],'root',pose.position.map(f),[1,0,0,0]);}
 }
 const phase=e.programPhaseFa&255,id=phase>=1&&phase<=3?e.programsD0[phase-1]&65535:65535;
 const previous=e.proceduralB8,type=call(p,'programType',e,id)&255;
 if(type===7){call(p,'programAttach14096ba80',e);return;}
 if(type===4){call(p,'programAttach14096bbb0',e);return;}
 const dispatch={1:'programAttach14096b630',2:'programAttach140969ef0',3:'programAttach14096aff0',5:'programAttach1409689f0'};
 if(dispatch[type])call(p,dispatch[type],e,id);
 else if(type===6)call(p,'renderSetting158',render,e.vector18.map(f),3,0,1);
 // The test is deliberately on the OLD pointer; the dereference is on the
 // current field. A lower callback may replace it with another model.
 if(previous)call(p,'setParent',e.proceduralB8,parent,String(e.targetAnchor38??''),0);
}
