import {NetworkPeer} from './network_peer.mjs';
import {NetworkGameSession} from './network_game_session.mjs';
import {NetworkLoginIdentity} from './network_login_identity.mjs';
import {installedNetworkBuild} from './installed_network_build.mjs';
import {installedNetworkResources} from './installed_network_resources.mjs';
import {openLocalModule} from '../scripts/local-module.mjs';

export async function createInstalledNetworkSession(request){
 let identity,build,peer;
 try{
  identity=new NetworkLoginIdentity(request.credentials);for(const key of ['cdKey','password','communityPassword'])if(request.credentials)request.credentials[key]='';delete request.credentials;
  const resources=installedNetworkResources({install:request.install,userDirectory:request.userDirectory});
  const language=await resources.languageId();build=await installedNetworkBuild(request.install);
  peer=new NetworkPeer({onDiagnostic:request.onDiagnostic});
  const session=new NetworkGameSession({peer,identity,build,resources,language,onDiagnostic:request.onDiagnostic,
   openModule:module=>openLocalModule(request.install,module,request.userDirectory?request.userDirectory+'/hak':null)});
  return{session,metadata:{connectionType:16,build:build.build,language,name:request.name,legacyPublicKey:'',platformId:build.platformId,platformIdentifier:crypto=>build.platformIdentifier(crypto)}};
 }catch{delete request.credentials;if(peer)await peer.disconnect();identity?.dispose();build?.dispose();throw new Error('Installed multiplayer session is unavailable');}
}
