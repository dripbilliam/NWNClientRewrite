const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native beam visual provider ${name} is unavailable`);return p[name](...args);};
// Full14096ba80..14096bbab. Base attaches to SOURCE; referenced children
// attach to TARGET. Reload B8 between calls; callbacks can replace that field.
export function attachBeamVisual(e,p){
 const target=call(p,'clientObject',e.target54),targetRender=target?call(p,'renderObject',target):null;
 const source=call(p,'clientObject',e.source58),sourceRender=source?call(p,'renderObject',source):null;
 if(!targetRender||!sourceRender||!e.proceduralB8)return;
 const model=e.proceduralB8,sourceModel=call(p,'modelHandle',sourceRender,255,1);
 call(p,'setParent',model,sourceModel,String(e.sourceAnchor28??''),0);
 const current=e.proceduralB8,targetModel=call(p,'modelHandle',targetRender,255,1);
 call(p,'reattachReferences',current,targetModel,String(e.targetAnchor38??''));
}
// Original96a110 TYPE7: gated by D8, attach, read Param6 unconditionally
// (including failed-query output), then PlayAnimation(speed1,flags0,time0).
// Param2 happens to contain clip-like names in stock data; it is NOT read here.
export function startBeamVisual(e,id,p){
 if(!e.updateProgramD8)return;attachBeamVisual(e,p);
 const animation=String(call(p,'programString',id&65535,'param6').value);
 call(p,'playAnimation',e.proceduralB8,animation,1,0,0);
}
// Original96fa90 TYPE7. Unparent first, then reload B8 for scene removal.
export function stopBeamVisual(e,p){
 if(!e.updateProgramD8||!e.proceduralB8)return;
 call(p,'setParent',e.proceduralB8,0,0,0);call(p,'setScene',e.proceduralB8,0);
}
