// LoadFromTemplate owners: placeable1404b4650..1404b48f1,
// store1404fb960..1404fbbe8, waypoint140509cf0..140509f73.
// Resource, data-loader and script-variable owners are explicit boundaries.
// Allocation failures/native C++ exception unwinding are not emulated here.
const templates={
 placeable:{type:2044,signature:'UTP ',warning:"CNWSPlaceable::LoadFromTemplate(): Placeable template %s.utp doesn't exist"},
 store:{type:2051,signature:'UTM ',warning:"Store template %s doesn't exist.\n"},
 waypoint:{type:2058,signature:'UTW ',warning:"Waypoint template %s doesn't exist.\n"},
};

export async function loadWorldObjectTemplate(kind,object,reference,newTag,p){
 const spec=templates[kind];if(!spec)throw new Error(`Native world template kind ${kind} is unavailable`);
 if(typeof reference!=='string')throw new Error('Native world template reference is unavailable');
 // These owners consume a C string. The caller owns CResRef's16-byte limit.
 const name=reference.split('\0')[0],resource=await p.resource(spec.type,spec.signature,name);
 if((resource.loaded|0)===0){
  await p.release(resource,1);
  await p.warning(spec.warning.replace('%s',()=>name));
  return 0;
 }
 const root=await p.root(resource);
 if(kind==='placeable')await p.setTemplate(object,name);
 // The data-loader result is deliberately ignored by all three originals.
 if(kind==='waypoint')await p.loadData(kind,object,resource,root,newTag);
 else await p.loadData(kind,object,resource,root,0,newTag);
 if(kind!=='placeable')await p.setTemplate(object,name);
 await p.loadVariables(object,resource,root);
 await p.release(resource,1);
 return 1;
}
