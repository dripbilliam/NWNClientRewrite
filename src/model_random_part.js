const f=Math.fround;
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native random model part provider ${n} is unavailable`);return p[n](...args);};
// Part08f560/08f740 and Gob08f680. Geometry area is the stored native FLOAT,
// not recomputed from animated/scaled renderer triangles. Child order and
// strict '<' at a boundary determine which physical part is selected.
export function nativePartArea(part,p){let area=call(p,'area',part);for(const child of call(p,'children',part))area=f(area+nativePartArea(child,p));return area;}
export function selectNativeRandomPart(part,remaining,p){const area=call(p,'area',part);if(remaining.value<area)return part;remaining.value=f(remaining.value-area);for(const child of call(p,'children',part)){const result=selectNativeRandomPart(child,remaining,p);if(result)return result;}return null;}
export function nativeRandomModelPart(model,p){
 let area=model.partArea;if(area===undefined||area===-1){area=nativePartArea(call(p,'root',model),p);model.partArea=area;}
 if(area===0)return null;
 const draw=call(p,'random');if(!Number.isInteger(draw)||draw<0||draw>32767)throw new Error('Native model-part CRT draw is unavailable');
 const remaining={value:f(f(f(draw%10000)*f(area))/10000)},root=call(p,'root',model);if(!root){model.partArea=0;return null;}
 return call(p,'name',selectNativeRandomPart(root,remaining,p)??root);
}

// Adapter for the existing physical hierarchy. A wrapper is not a native Part;
// descend through it without adding a weight. Attached models retain their
// actual stored areas and physical order. ASCII area postprocessing is separate.
export function randomSceneModelPart(model,random){
 const children=part=>part.children.flatMap(child=>child.userData.mdlNode?[child]:children(child)),roots=children(model.root);if(roots.length!==1)throw new Error('Native random-part model requires one physical root');
 const result=nativeRandomModelPart(model,{root:()=>roots[0],children,area:part=>{const node=part.userData.nativeModelPart;if(!node)throw new Error('Native model-part metadata is unavailable');if(node.type!=='trimesh')return 0;if(typeof node.area!=='number')throw new Error('Native model triangle area is unavailable for '+node.name);return node.area;},name:part=>part.userData.mdlNode,random:()=>random.next()});
 return result;
}
