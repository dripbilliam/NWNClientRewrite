const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native visual detach provider ${name} is unavailable`);return p[name](...args);};
// Complete14096c180..14096c281. Clears scene membership and parents; this
// is NOT the placement/attach owner1409702e0. Type4 also refreshes a matching
// context before its procedural model leaves the scene; its type is unresolved.
export function detachVisualModels(e,p){
  e.attached114=0;
  for(let i=0;i<3;i++)if(e.models88[i]){
    call(p,'setParent',e.models88[i],0,0,0);call(p,'setScene',e.models88[i],0);
  }
  if(!e.proceduralB8)return;
  if((e.programType10d&255)===4){
    const object=call(p,'clientObject',e.target54),render=object?call(p,'renderObject',object):null;
    const context=render?call(p,'view58',render):null;
    if(context&&context===call(p,'view1406ac1a0')&&context.context30)call(p,'refreshContext1407e9bc0',context.context30);
  }
  call(p,'setParent',e.proceduralB8,0,0,0);call(p,'setScene',e.proceduralB8,0);
}
