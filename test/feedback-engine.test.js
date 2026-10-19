import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {GameUi} from '../src/game_ui.js';
import {GameText} from '../src/talk_table.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {requestCameraMode} from '../src/camera_modes.js';
import {parse2da} from '../src/area.js';
import {loadNamedTalkTokens} from '../src/game_talk_tokens.js';
function fixture(){
  const messages=[],sounds=[],scripts=[],camera=[];
  const session=new ModuleSession({}, {onMessage:m=>messages.push(m),onSound:s=>sounds.push(s),onCameraMode:(actor,mode)=>camera.push({actor:actor.id,mode})});
  const area=session.register('area','area',{}),other=session.register('area','other',{});
  const owner=session.register('door','door',{areaId:area.id,position:[0,0,0],authored:{Conversation:'one'}});
  const player=session.register('player','player',{isPC:true,areaId:area.id,position:[20,0,0],stats:{},authored:{Gender:1},name:'Token Target'});session.player=player;
  session.program=async n=>n;session.vm={run:async(name,self,options)=>{scripts.push({name,self,options});return {stack:[{type:3,value:name==='false'?0:1}]};}};
  session.conversation.oneLinerResources.set('one',{StartingList:[{Index:0,Active:'named'},{Index:1,Active:'true'},{Index:2,Active:'false'},{Index:3,Active:'true'},{Index:4,Active:'later'}],EntryList:[
    {Speaker:'Other',Text:'Named'}, {Text:'Replies',RepliesList:[{Index:0}]}, {Text:'False'},
    {Text:'Selected',Script:'action',Sound:'voice'}, {Text:'Later'}]});
  return {session,area,other,owner,player,messages,sounds,scripts,camera};
}
test('one-liners select native eligible starts, preserve owner/budget and send before action without opening a modal',async()=>{
  const {session,owner,player,messages,sounds,scripts}=fixture(),frame={self:owner.id,budget:{remaining:100},depth:2};
  await session.commands.SpeakOneLinerConversation(['',player.id],frame);
  assert.deepEqual(scripts.map(s=>s.name),['true','false','true','action']);
  assert.ok(scripts.every(s=>s.self===owner.id&&s.options.budget===frame.budget&&s.options.depth===3));
  assert.equal(messages[0].text,'Selected');assert.equal(messages[0].id,owner.id);assert.equal(messages[0].tokenTargetId,player.id);assert.equal(messages[0].gender,1);
  assert.equal(sounds[0].resRef,'voice');assert.equal(session.conversation.state,null);assert.equal(owner.dialogOwnerId,undefined);
});
test('one-liner recipients include exact 20m 3D boundary, exclude other areas and still run actions',async()=>{
  const {session,owner,player,other,messages,sounds,scripts}=fixture();
  for(const [position,areaId,visible]of [[[20,0,0],owner.areaId,true],[[20,0.01,0],owner.areaId,false],[[0,0,0],other.id,false]]){
    player.position=position;player.areaId=areaId;messages.length=0;sounds.length=0;
    await session.commands.SpeakOneLinerConversation([], {self:owner.id});
    assert.equal(messages.length,Number(visible));assert.equal(sounds.length,Number(visible));assert.equal(scripts.at(-1).name,'action');
  }
});
test('one-liners do not alter an active conversation, PCs, actions or journal when no eligible entry exists',async()=>{
  const {session,owner,player,scripts,messages}=fixture(),state={ownerId:player.id};session.conversation.state=state;
  session.conversation.oneLinerResources.set('none',{StartingList:[{Index:0}],EntryList:[{Speaker:'Other'}]});
  await session.commands.SpeakOneLinerConversation(['none'],{self:owner.id});
  assert.equal(session.conversation.state,state);assert.equal(scripts.length,0);assert.equal(messages.length,0);
  await session.commands.SpeakOneLinerConversation(['one'],{self:session.registry.get(owner.areaId).id});assert.equal(messages.length,0);
});
test('one-liner text uses supplied target and gender without substituting the local PC for an absent target',()=>{
  const {session,player}=fixture(),ui={session,text:new GameText()},resolve=(value,target,gender)=>GameUi.prototype.dialogueText.call(ui,value,target,gender);
  session.talkTable.namedTokens=loadNamedTalkTokens(parse2da('2DA V2.0\n\nToken Action Default A B C D\n0 FullName 2 -1 -1 -1 -1 -1'));
  const text={strRef:0xffffffff,entries:[{languageId:0,text:'Mr <FullName>'},{languageId:1,text:'Ms <FullName>'}]};
  assert.equal(resolve(text,player,1),'Ms Token Target');assert.equal(resolve(text,null,0),'Mr ');
});
test('camera mode requests route to controlling clients, narrow to a byte, and ignore unknown modes',()=>{
  const {session,owner,player,camera}=fixture();
  session.commands.SetCameraMode([player.id,1]);session.commands.SetCameraMode([owner.id,0]);session.commands.SetCameraMode([OBJECT_INVALID,2]);
  session.commands.SetCameraMode([player.id,3]);session.commands.SetCameraMode([player.id,258]);
  assert.deepEqual(camera,[{actor:player.id,mode:1},{actor:player.id,mode:2}]);assert.equal(player.scriptCameraMode,2);
  const client={object:player};let sent;requestCameraMode(player.id,-256,{client:()=>client,apply:(_o,m)=>sent=m});assert.equal(sent,0);
});
