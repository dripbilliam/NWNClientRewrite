import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native possession ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p?.[name]!=='function')throw new Error(`Native possession provider ${name} is unavailable`);return p[name];};

// SetPossessor14046c520..14046cddc. Canonical item owner changes separately
// from repository insertion and equipment membership. Bags resolve one parent
// level to a creature; placeables retain their own disturbance-event ownership.
export async function setItemPossessor(item,newId,scriptEvents,feedback,quantity,p){
  newId=integer(newId,'new owner ID')>>>0;const oldId=integer(item.possessorId,'old owner ID')>>>0;
  if(oldId===newId)return;
  scriptEvents=integer(scriptEvents,'script-event flag');feedback=integer(feedback,'feedback flag');quantity=integer(quantity,'quantity');
  const module=required(p,'module')();if(!module)throw new Error('Native SetPossessor dereferences an unavailable module');
  const aliases=id=>{
    const object=id===OBJECT_INVALID?null:required(p,'objectById')(id);
    if(object?.objectType===5)return{creature:id,placeable:OBJECT_INVALID};
    if(object?.objectType===9)return{creature:OBJECT_INVALID,placeable:id};
    if(object?.objectType===6){
      const parentId=integer(object.possessorId,'bag owner ID')>>>0,parent=required(p,'objectById')(parentId);
      if(parent?.objectType===5)return{creature:parentId,placeable:OBJECT_INVALID};
    }
    return{creature:OBJECT_INVALID,placeable:OBJECT_INVALID};
  };
  const old=aliases(oldId),next=aliases(newId);
  let newCreature=next.creature,oldCreature=old.creature;
  const event=(source,target,type,objects,integers=[])=>required(p,'event')(source,target,type,objects,integers);
  const contents=()=>{
    const repository=required(p,'repository')(item);return repository&&repository.length!==0?[...repository.ids()]:[];
  };
  if(oldCreature!==newCreature){
    if(oldCreature!==OBJECT_INVALID){
      if(scriptEvents===1){
        await event(oldCreature,module.id,20,[item.id]);
        for(const id of contents())await event(oldCreature,module.id,20,[id]);
      }
      const creature=required(p,'objectById')(oldCreature);
      if(creature?.objectType===5){
        if(feedback===1)await required(p,'feedback')(creature,51,{objects:[item.id],integers:[integer(item.identified,'identified')]});
        if(required(p,'quickbar')(creature)!==null)await required(p,'removeQuickbarItem')(creature,item.id);
      }
    }
    if(newCreature!==OBJECT_INVALID){
      const creature=required(p,'objectById')(newCreature);
      if(creature?.objectType===5&&integer(required(p,'statsPC')(creature),'stats PC')!==0){item.droppable=1;item.pickpocketable=1;}
      if(scriptEvents===1){
        await event(item.id,module.id,19,[item.id,item.possessorId,newCreature],[quantity]);
        for(const id of contents())await event(item.id,module.id,19,[id,item.possessorId,newCreature],[quantity]);
      }
      if(feedback===1&&creature?.objectType===5)await required(p,'feedback')(creature,50,{objects:[item.id],integers:[integer(item.identified,'identified')]});
    }
  }
  if(old.placeable!==OBJECT_INVALID){
    const placeable=required(p,'objectById')(old.placeable);
    if(placeable?.objectType===9&&integer(placeable.nativeField504,'old placeable veto')===0){
      // Native reuses its new-creature local for a placeable destination.
      if(newCreature===OBJECT_INVALID&&next.placeable!==OBJECT_INVALID)newCreature=next.placeable;
      if(newCreature!==OBJECT_INVALID&&scriptEvents===1)await event(newCreature,old.placeable,27,[item.id],[1]);
    }
  }
  if(next.placeable!==OBJECT_INVALID){
    const placeable=required(p,'objectById')(next.placeable);
    if(placeable?.objectType===9&&integer(placeable.nativeField504,'new placeable veto')===0){
      if(oldCreature===OBJECT_INVALID&&old.placeable!==OBJECT_INVALID)oldCreature=old.placeable;
      if(oldCreature!==OBJECT_INVALID&&scriptEvents===1)await event(oldCreature,next.placeable,27,[item.id],[0]);
    }
  }
  item.possessorId=newId;
}
