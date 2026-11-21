import {stageNativeActorName,validNativeActorNameState,NATIVE_ACTOR_NAME_SOURCE} from '../../src/network_actor_name_state.js';
export function actorNameFixture(){
 const id=0x80000009,A={action:'create',objectType:5,id,state:{}},D={action:'delete',objectType:5,id},P=name=>({action:'appearance',objectType:5,id,mask:0x400,state:{name}});
 const boundary=(sequence,typedOwner='present')=>({sequence,typedOwner,historyComplete:true}),empty={overrides:new Map(),customTokens:{records:[]}},fresh=()=>stageNativeActorName(null,A,boundary(1,'absent'));
 const put=(name,environment=empty)=>stageNativeActorName(fresh(),P(name),boundary(2),environment);
 const literal=put({firstName:{text:'First '},lastName:{text:' Last'}}),removed=stageNativeActorName(literal,D,boundary(3));
 const unknown=stageNativeActorName(null,P({text:'Prior publication'}),boundary(1),empty);
 const context={id:99,objectType:5,areaId:91,nativeLifetime:8,clientKnownLifetime:13,appearance:{name:{firstName:{text:'At P'},lastName:{text:''}}}};
 const known=(overrides,customTokens={records:[]},parserState={})=>({overrides:new Map(overrides),customTokens,parserState});
 const cases={
  fresh:fresh(),literal,raw:put({text:'  Raw  '}),empty:put({firstName:{text:''},lastName:{text:''}}),
  base:put({firstName:{strRef:100,gender:1},lastName:{strRef:101,gender:0}}),
  rawBase:put({firstName:{strRef:102,gender:0},lastName:{text:''}}),
  override:put({firstName:{strRef:200,gender:1},lastName:{text:' Last'}},known([[200,'<CUSTOM12>']],{records:[{id:12,bytes:new Uint8Array([67,97,102,233,32])}]})),
  absentBeforeLateOverride:put({firstName:{strRef:100,gender:0},lastName:{text:'Last'}}),
  unknownContext:put({firstName:{strRef:201,gender:0},lastName:{text:'Last'}},known([[201,'<FirstName>']])),
  nullContext:put({firstName:{strRef:201,gender:0},lastName:{text:'Last'}},known([[201,'<FirstName>']],{records:[]},{context:null})),
  nullContextCovered:put({firstName:{strRef:201,gender:0},lastName:{strRef:0,gender:0}},known([[201,'<FirstName>']],{records:[]},{context:null})),
  nested:put({firstName:{strRef:202,gender:0},lastName:{text:'Last'}},known([[202,'<Nested>']])),
  nestedCovered:put({firstName:{strRef:202,gender:0},lastName:{strRef:300,gender:0}},known([[202,'<Nested>']])),
  frozenContext:put({firstName:{strRef:201,gender:0},lastName:{text:'Last'}},known([[201,'<FirstName>']],{records:[]},{context,nativeB8:0,nativeBC:0})),
  failed:put({firstName:{strRef:999,gender:0},lastName:{text:'Last'}}),
  invalid:put({firstName:{strRef:0xffffffff,gender:1},lastName:{text:'Last'}}),
  unknownOverride:put({firstName:{strRef:100,gender:0},lastName:{text:'Last'}},{}),
  preexisting:unknown,removed,
  confirmedRedisclosure:stageNativeActorName(removed,A,boundary(4,'present')),
  ambiguousRedisclosure:stageNativeActorName(removed,A,boundary(4,'unknown')),
 };
 cases.afterAmbiguous=stageNativeActorName(cases.ambiguousRedisclosure,P({text:'New P after redisclosure'}),boundary(5),empty);
 cases.newPublication=stageNativeActorName(literal,P({text:'New P'}),boundary(3),empty);
 cases.newPending=stageNativeActorName(cases.unknownContext,P({firstName:{strRef:201,gender:0},lastName:{text:'New Last'}}),boundary(3),known([[201,'<FirstName>']]));
 const replacement=stageNativeActorName(null,A,boundary(9,'absent'));
 cases.replacement=stageNativeActorName(replacement,P({text:'Replacement owner'}),boundary(10),empty);
 for(const [name,state]of Object.entries(cases))if(!validNativeActorNameState(state))throw Error('Invalid authored helper case '+name);
 const receivedPending=put({firstName:{strRef:200,gender:1},lastName:{text:' Last'}},known([[200,'<FirstName><CUSTOM12>']],{records:[{id:12,bytes:new Uint8Array([67,97,102,233,32])}]},{context:{id:99,objectType:5,appearance:{name:{firstName:{text:'At receipt '},lastName:{text:''}}}},nativeB8:0,nativeBC:0}));
 if(!validNativeActorNameState(receivedPending))throw Error('Invalid authored received helper case');
 return{version:1,id,source:NATIVE_ACTOR_NAME_SOURCE,provenance:{method:'actual pure stageNativeActorName with explicit authored accepted-record boundary facts',nativeExecution:false,jsTextResolution:false},cases,receivedPending};
}
