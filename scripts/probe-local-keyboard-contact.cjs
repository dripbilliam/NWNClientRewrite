// Reproduce the recorded local Prelude contact using ordinary walk/turn inputs.
// Coordinates belong solely to this QA scenario, never production movement.
module.exports=async(window,session,keyboardOptions={})=>{
 if(session.world.areaId===undefined)throw Error('Local contact area unavailable');
 const duration=keyboardOptions.contactDurationMs??1800;if(!Number.isInteger(duration)||duration<1800||duration>5000)throw Error('Invalid bounded contact duration');
 const sleep=ms=>new Promise(r=>setTimeout(r,ms)),target=[10.40,4.87,0],heading=[.9245460629463196,.3810702860355377],context=()=>({areaId:session.world.areaId,areaGeneration:session.areaGeneration,actorId:session.world.localObjectId}),actor=()=>session.world.registry.get(session.world.localObjectId);
 const origin=context();await session.walkTo({...origin,position:target,run:false});const end=Date.now()+20000;
 while(Math.hypot(actor().replicated.position[0]-target[0],actor().replicated.position[1]-target[1])>.04||!([0,1].includes(actor().replicated.animation)&&actor().replicated.path?.length===0)){if(Date.now()>end)throw Error('Ordinary local contact approach did not settle');if(session.world.areaId!==origin.areaId||session.areaGeneration!==origin.areaGeneration)throw Error('Contact test area changed');await sleep(100);}
 const headingObservations=[];await session.keyboardMove({...origin,operation:'turn',position:heading});const turnEnd=Date.now()+5000;
 for(;;){const raw=actor().replicated.orientation,angle=raw?.yaw*Math.PI/180,v=Array.isArray(raw)?raw:raw?.vector??[-Math.sin(angle),Math.cos(angle)];headingObservations.push({at:Date.now(),orientation:structuredClone(raw),position:actor().replicated.position?.slice(),animation:actor().replicated.animation,control:actor().replicated.field8D4});if(Math.hypot(v[0]-heading[0],v[1]-heading[1])<.003)break;if(Date.now()>turnEnd)throw Object.assign(Error('Local contact heading was not acknowledged'),{details:{heading,headingObservations}});await sleep(100);}await sleep(1200);
 const before=structuredClone({position:actor().replicated.position,orientation:actor().replicated.orientation}),keyboard=await require('./probe-smooth-keyboard.cjs')(window,session,{...keyboardOptions,steps:[['KeyQ',duration],['KeyE',duration]]});
 return{scope:'Prior local contact position, ordinary server walk and orientation request followed by renderer key input',target,heading,headingObservations,before,keyboard};
};
