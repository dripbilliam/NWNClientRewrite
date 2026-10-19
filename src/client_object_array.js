import {GameObjectArray,OBJECT_INVALID} from './game_object_array.js';
import {serverObjectIdForClient} from './client_projectile_message.js';
const f=Math.fround,native=p=>p.map((v,i)=>f(i===1?-p[2]:i===2?p[1]:v));

// Client CGameObjectArray has independent internal/external halves. Mirrors
// own their external IDs; inserting the canonical object itself would mutate
// its server ID. External at-position insertion preserves the received ID.
export class ClientObjectArray{
 constructor({objects,render,nativePose=null}){Object.assign(this,{objects,render,nativePose});this.array=new GameObjectArray({clientMode:true});this.mirrors=new Map();}
 sync(){
  const current=new Set();
  for(const canonical of this.objects()){
   if(canonical.id===OBJECT_INVALID)continue;const id=serverObjectIdForClient(canonical.id);current.add(id);
   const old=this.mirrors.get(id);if(old?.canonical===canonical)continue;
   if(old){this.array.delete(id);this.mirrors.delete(id);}
   const render=this.render,nativePose=this.nativePose,mirror={canonical,objectType:canonical.objectType,nativeField28:0, // client base ctor761914; update ownership remains separate.
    get position(){if(nativePose)return nativePose(canonical).position.map(f);if(!Array.isArray(canonical.position))throw new Error('Client object position is unavailable');return native(canonical.position);},
    get orientation(){if(nativePose)return nativePose(canonical).orientation.map(f);if(!Array.isArray(canonical.orientation))throw new Error('Client object orientation is unavailable');return native(canonical.orientation);},
    get render(){return render(canonical.id);}};
   const result=this.array.addObjectAtPos(id,mirror);if(result.status!==0)throw new Error(`Client external object insertion failed (${result.status})`);
   this.mirrors.set(id,mirror);
  }
  for(const id of this.mirrors.keys())if(!current.has(id)){this.array.delete(id);this.mirrors.delete(id);}
 }
 addInternal(object){const result=this.array.addInternalObject(object);if(result.status!==0)throw new Error(`Client internal object insertion failed (${result.status})`);return result.id;}
 remove(object){if(this.array.get(object.id)===object)this.array.delete(object.id);}
 getObject(id){return this.array.getGameObject(id);}
 get(id){return this.array.get(id);}
}
