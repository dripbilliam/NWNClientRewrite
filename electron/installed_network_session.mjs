import {NetworkPeer} from './network_peer.mjs';
import {NetworkGameSession} from './network_game_session.mjs';
import {NetworkLoginIdentity} from './network_login_identity.mjs';
import {installedNetworkBuild} from './installed_network_build.mjs';
import {installedNetworkResources} from './installed_network_resources.mjs';
import {queryNetworkServer} from './server_browser.mjs';

export async function createInstalledNetworkSession(request){
 let identity,build,peer,resources;
 try{
  identity=request.loginIdentity??new NetworkLoginIdentity(request.credentials);delete request.loginIdentity;for(const key of ['cdKey','password','communityPassword'])if(request.credentials)request.credentials[key]='';delete request.credentials;
  resources=installedNetworkResources({install:request.install,modsDirectory:request.modsDirectory,disabledMods:request.disabledMods,userDirectory:request.userDirectory,cacheDirectory:request.cacheDirectory,reuseInstalledNWSync:request.reuseInstalledNWSync??true,onDiagnostic:request.onDiagnostic});
  const language=await resources.languageId();build=await installedNetworkBuild(request.install);
  peer=new NetworkPeer({onDiagnostic:request.onDiagnostic});
  let serverInfo=null;if(request.host){try{serverInfo=await queryNetworkServer({host:request.host,port:request.port});}catch{request.onDiagnostic?.({code:'network.server-info-unavailable',reason:'Public server vault policy could not be queried'});}}
  const localVaultAllowed=serverInfo?Boolean(serverInfo.allowLocalVaultCharacters):request.host?null:true;
  const session=new NetworkGameSession({peer,identity,build,resources,language,serverInfo,localVaultAllowed,onDiagnostic:request.onDiagnostic,persistCharacter:request.persistCharacter,loginWaypoint:request.loginWaypoint??'',
   preparePortal:portal=>createInstalledNetworkSession({...request,host:portal.host,port:portal.port,loginIdentity:identity.forPortal(portal.password),loginWaypoint:portal.waypoint||(portal.seamless?'*PAUL_WAS_HERE*':'')}),
   openModule:async(...args)=>{const resolver=await resources.openModule(...args);return request.sceneCapture?request.sceneCapture.wrapResolver(request.sceneCapture.contextFor(session),resolver):resolver;}});
  if(request.sceneCapture){const read=session.getTalkTable;session.getTalkTable=async function(custom){const bytes=await read.call(this,custom);try{request.sceneCapture.resource(request.sceneCapture.contextFor(this),custom?'__talk_custom':'__talk_main',2018,bytes);}catch{}return bytes;};}
  return{session,metadata:{connectionType:16,build:build.build,language,name:request.name,legacyPublicKey:'',platformId:build.platformId,platformIdentifier:crypto=>build.platformIdentifier(crypto)}};
 }catch{delete request.credentials;if(peer)await peer.disconnect();resources?.close();identity?.dispose();build?.dispose();throw new Error('Installed multiplayer session is unavailable');}
}
