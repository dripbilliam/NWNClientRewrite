'use strict';
// CreationCheck evidence only. Never clone entity storage or resolve a new
// entity by an old ID after await; retain the canonical object and its owner.
const positive=value=>Number.isSafeInteger(value)&&value>0;
function capture(session,connection){
 const world=session?.world,actor=world?.registry?.get(world.localObjectId);
 if(!session||session.closed||!session.peer||session.peer.closed||!world||!actor||actor.objectType!==5||actor.id!==world.localObjectId||actor.areaId!==world.areaId||actor.replicationRemoved||actor.destroyed||!positive(connection)||!positive(session.areaGeneration))throw Error('Canonical creation HP owner is unavailable');
 const actorLifetime=world.entityDisclosures.token(actor);
 if(!positive(actorLifetime))throw Error('Canonical creation HP lifetime is unavailable');
 return {session,peer:session.peer,world,actor,scope:{connection,generation:session.areaGeneration,areaId:world.areaId,actorId:actor.id,actorLifetime}};
}
function current(owner,session,connection){
 const world=session?.world,scope=owner?.scope,actor=owner?.actor;
 return Boolean(scope&&positive(scope.actorLifetime)&&session===owner.session&&!session.closed&&session.peer===owner.peer&&!owner.peer.closed&&world===owner.world&&connection===scope.connection&&session.areaGeneration===scope.generation&&world.areaId===scope.areaId&&world.localObjectId===scope.actorId&&world.registry.get(scope.actorId)===actor&&actor.id===scope.actorId&&actor.objectType===5&&actor.areaId===scope.areaId&&!actor.replicationRemoved&&!actor.destroyed&&world.entityDisclosures.token(actor)===scope.actorLifetime);
}
function assertCurrent(owner,session,connection){if(!current(owner,session,connection))throw Error('Creation export owner retired before completion');}
function witness(owner,callbackSession,currentSession,connection,postAdmissionRequested){
 const valid=callbackSession===owner?.session&&current(owner,currentSession,connection);
 const hp=valid?owner.actor.replicated?.hitPoints:null;
 return {at:Date.now(),...owner?.scope,currentScope:valid,postAdmissionRequested:postAdmissionRequested===true,current:hp?.current??null,maximum:hp?.maximum??null,temporary:hp?.fieldE8??null,source:'Canonical original-server S/HP short disclosure at the independent character-export callback; never read from the exported BIC'};
}
module.exports={capture,current,assertCurrent,witness};
