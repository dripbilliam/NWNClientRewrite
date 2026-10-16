const f=Math.fround;
// CNWSObject::SetOrientation14049b910..14049b925 is a raw three-FLOAT copy.
export function setCommonOrientation(object,vector,p){p.write(object,vector.map(f));}

// CNWSPlaceable::SetOrientation1404b7680..1404b7786. Old/new vectors are
// not normalized. COMISS/JBE skips replacement for equal/greater dots or NaN.
export async function setPlaceableOrientation(object,vector,p){
 const previous=(await p.orientation(object)).map(f);await p.write(object,vector.map(f));
 if(!await p.area(object))return;
 const current=(await p.orientation(object)).map(f),dot=f(f(f(previous[1]*current[1])+f(previous[0]*current[0]))+f(previous[2]*current[2]));
 if(!(p.threshold>dot))return;
 const mesh=await p.mesh((await p.appearance(object))&65535);if(!mesh)return;
 await p.replace(await p.area(object),await p.slot(object),object.id,current,await p.position(object),mesh);
 await p.points(object);
}
