import {NetworkLobby} from '../src/network_lobby.js';
const data=await window.lobbyFixture.data(),requests=[];let lobby;
const frontend={id:'fixture',button:document.querySelector('#multiplayer-button'),form:document.querySelector('#fixture-form'),dialog:document.querySelector('#fixture-dialog'),status:document.createElement('p'),world:{players:new Map()},text:{raw:async value=>value?.text??(value?.strRef!==undefined?window.lobbyFixture.talk(value.strRef):'')},
 bridge:{getResource:(_id,...args)=>window.lobbyFixture.resource(...args),lobbyResource:(...args)=>window.lobbyFixture.resource(...args),serverList:()=>window.lobbyFixture.servers(),previewServerCharacter:async(_id,request)=>{requests.push({action:'preview',...request});lobby.receive({kind:'server-character-preview',...request,preview:data.preview});},playServerCharacter:async(_id,request)=>{requests.push({action:'play',...request});},disconnect:async()=>{},exitApplication:async()=>{}},disconnect:async()=>{lobby.close();}};
lobby=window.testLobby=new NetworkLobby(frontend);window.fixtureRequests=requests;
window.showLobbyCharacters=async()=>{lobby.characterScreen({localVaultAllowed:false,serverInfo:data.serverInfo});await lobby.bindSession('fixture');lobby.receive({kind:'server-character-list',characters:data.characters,generation:1});await lobby.selectCharacter(data.characters[0]);await lobby.drawRecord();await lobby.decorate(null);};
window.showLobbyBrowser=async()=>{lobby.filter='arelith';await lobby.showBrowser('Internet');};
window.showLobbyMain=async()=>{lobby.showMain();await lobby.baseAssets();await new Promise(resolve=>setTimeout(resolve,150));};
window.lobbyFixtureReady=true;
