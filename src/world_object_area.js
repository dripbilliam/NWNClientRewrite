// Item RemoveFromArea14046b1d0 / waypoint14050a470. Both clear position
// even without an old area. Item's +48 world subobject is the same canonical
// JavaScript record; it does not allocate a second object ID.
export async function removeGroundObjectFromArea(object,p){
 if(p.area(object))await p.removeObject(p.area(object),object.id);
 await p.setArea(object,null);await p.position(object,[0,0,0]);
}

// Item AddToArea140464bb0 and waypoint140508fa0 use that removal sequence
// unconditionally, then write raw XYZ before AddObjectToArea.
export async function addGroundObjectToArea(object,area,x,y,z,flag,p){
 await p.removeGround(object);
 if(!area)return;
 await p.setArea(object,area);await p.position(object,[x,y,z].map(Math.fround));
 await p.addObject(p.area(object),object.id,flag);
}

// Store AddToArea1404fa540. Unlike items/waypoints, the null destination
// leaves its previous position intact while clearing canonical area ownership.
export async function addStoreToArea(object,area,x,y,z,flag,p){
 if(p.area(object))await p.removeObject(p.area(object),object.id);
 await p.setArea(object,null);
 if(!area)return;
 await p.setArea(object,area);await p.position(object,[x,y,z].map(Math.fround));
 await p.addObject(p.area(object),object.id,flag);
}

// Placeable RemoveFromArea1404b6930. Slot removal precedes spatial and trap
// membership; a missing old area leaves the stored collision slot unchanged.
export async function removePlaceableFromArea(object,p){
 if(p.area(object)){
  if(object.nativeCollisionSlot>=0){await p.removeStatic(p.area(object),object.nativeCollisionSlot);object.nativeCollisionSlot=-1;}
  await p.removeObject(p.area(object),object.id);
  await p.removeTrap(p.area(object),object.id);
 }
 await p.setArea(object,null);await p.position(object,[0,0,0]);
}

// Placeable AddToArea1404b1a40. The bounding/action-point calculation and
// area displacement owner14035c260 remain explicit providers. Empty meshes
// still admit spatial objects; they do not allocate a static collision slot.
export async function addPlaceableToArea(object,area,x,y,z,flag,p){
 await p.removePlaceable(object);
 if(!area)return;
 await p.setArea(object,area);await p.position(object,[x,y,z].map(Math.fround));
 const mesh=await p.walkMesh(object);
 if(mesh&&mesh.vertices.length>0)object.nativeCollisionSlot=await p.addStatic(area,object.id,p.orientation(object),p.nativePosition(object),mesh);
 await p.addObject(area,object.id,flag);await p.computeBoundingBox(object);
 if(object.nativeCollisionSlot>=0){
  const bounds=await p.staticBounds(area,object.nativeCollisionSlot);
  await p.displaceObjects(area,p.nativePosition(object),bounds[0],bounds[1],object.id,0);
 }
}
