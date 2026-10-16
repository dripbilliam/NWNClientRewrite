const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native visual placement provider ${name} is unavailable`);return p[name](...args);};
const f=Math.fround;
// Complete1409702e0..140970e19. Name-prefix views retain their native virtual
// offsets until their concrete types are independently verified. Parent/model
// transforms and metadata/scene application are explicit lower services.
export function placeVisualModels(e,force,p){
  if((force|0)===0&&e.updateProgramD8)return 1;
  const registry=call(p,'gameObjectRegistry');if(!registry)return 0;
  const lookup=call(p,'gameObject',registry,e.target54);if(!lookup.success)return 0;
  const render=call(p,'renderObject',lookup.value);
  if(!render)throw new Error('Native visual source render object is unavailable');
  const parent=call(p,'modelHandle',render,255,1),first=call(p,'prefixViewA0',render),second=call(p,'prefixView28',render);
  const firstSuffix=['_ground','_impact','_head_hit'],secondSuffix=['grnd','impc','hhit'],fallback=['root','impact','head'];
  for(let i=0;i<3;i++)if(e.models88[i]){
    const anchor=first?String(first.prefix1e0)+firstSuffix[i]:second?String(second.prefix1c8)+secondSuffix[i]:fallback[i];
    call(p,'setParent',e.models88[i],parent,anchor,e.orient120?0:3);
    if(!e.orient120){
      const pose=call(p,'nodePose',e.models88[i],'root');
      call(p,'setNodePose',e.models88[i],'root',pose.position.map(f),[1,0,0,0]);
    }
  }
  if(e.proceduralB8){
    const view=call(p,'prefixViewA0',render),anchor=view?String(view.prefix1e0)+'_ground':second?String(second.prefix1c8)+'grnd':'root';
    call(p,'setParent',e.proceduralB8,parent,anchor,0);
  }
  e.updateProgramD8=1;e.attached114=1;
  const phase=e.programPhaseFa&255,program=phase>=1&&phase<=3?e.programsD0[phase-1]&65535:65535;
  call(p,'startProgram',e,program);
  if(e.proceduralB8)call(p,'applyModelState',e,render,e.proceduralB8);
  for(let i=0;i<3;i++)if(e.models88[i])call(p,'applyModelState',e,render,e.models88[i]);
  for(let i=0;i<3;i++)if(e.extraModelsA0[i])call(p,'applyModelState',e,render,e.extraModelsA0[i]);
  return 1;
}
