// Uses the original playerAttitude packet sender. Native controls hold private
// row handles; a reused player ID or changed controlled actor invalidates them.
export class PlayerListService{
 constructor({actions,onRequest=()=>{}}){Object.assign(this,{actions,onRequest});this.serial=0;this.reset();}
 reset(){this.opened=false;this.view=null;this.signature=null;this.epoch=(this.epoch??0)+1;}
 async open(){this.opened=true;await this.refresh(true);}
 close(){this.reset();this.actions.emit({kind:'players-closed'});}
 current(viewId){const v=this.view;if(!this.opened||!v||v.id!==viewId||v.scope.world!==this.actions.session.world||!this.actions.owned(v.scope))throw Error('Player list is no longer available');return v;}
 async refresh(force=false){if(!this.opened)return;const s={...this.actions.capture(),world:this.actions.session.world};if(!this.actions.owned(s))return;const players=[...s.world.players.values()],signature=JSON.stringify([s.actorId,s.areaId,s.areaGeneration,s.world.tlkOverrideVersion,s.world.customTokens,players]);if(!force&&this.signature===signature&&this.view?.scope.actor===s.actor&&players.every((p,i)=>p===this.view.players[i]))return;const epoch=++this.epoch,targets=players.map(p=>p.objectId);
  const rows=await Promise.all(players.map(async(p,entryId)=>{const resolve=v=>this.actions.text.resolve(v??{text:''},p.objectId),label=p.character?(await Promise.all([p.character.firstName,p.character.lastName].map(resolve))).filter(Boolean).join(' '):p.name;return{entryId,label:label||p.name||'Player',account:p.name??'',dm:Boolean(p.isDM),self:p.objectId===s.actorId};}));
  if(!this.opened||epoch!==this.epoch||s.world!==this.actions.session.world||!this.actions.owned(s)||players.some((p,i)=>s.world.players.get(p.playerId)!==p||p.objectId!==targets[i]))return;this.signature=signature;this.view={id:++this.serial,scope:s,players,targets,rows};this.actions.emit({kind:'players-view',viewId:this.view.id,rows});
 }
 async attitude({viewId,entryId,likes}){const v=this.current(viewId),p=v.players[entryId];if(!Number.isInteger(entryId)||typeof likes!=='boolean'||!p||v.scope.world.players.get(p.playerId)!==p||p.objectId!==v.targets[entryId]||p.objectId===v.scope.actorId||v.rows[entryId].self)throw Error('Player attitude target is stale');const s=v.scope;await this.actions.session.playerAttitude({areaId:s.areaId,areaGeneration:s.areaGeneration,actorId:s.actorId,playerId:p.playerId,likes});this.onRequest({operation:'attitude',playerId:p.playerId,targetId:p.objectId,likes});}
}
