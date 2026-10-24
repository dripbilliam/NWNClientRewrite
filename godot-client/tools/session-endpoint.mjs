import {parseAllowedServer,ServerEndpointPolicy} from './server-endpoint.mjs';
// Extra endpoints are opt-in for this process only; transfers obey this policy.
export function sessionEndpointOptions(argv){
 const allowed=argv.filter(v=>v.startsWith('--allow-server=')).map(v=>parseAllowedServer(v.slice(15)));
 const raw=argv.find(v=>v.startsWith('--join-server='));
 const publicServers=argv.includes('--public-servers');
 const policy=new ServerEndpointPolicy({allowed,allowAny:publicServers,internet:publicServers});
 const startup=raw?policy.require(parseAllowedServer(raw.slice(14))):null;
 const name=argv.find(v=>v.startsWith('--player-name='))?.slice(14)??'ReplacementTest';
 if(!name.trim()||name.length>64||/[\x00-\x1f]/.test(name))throw Error('Invalid player name');
 if((startup||publicServers)&&argv.some(v=>v==='--auto-play'||v.includes('smoke')||v==='--nwsync-cancel'))throw Error('Public server startup cannot upload test characters');
 return{policy,startup,name,publicServers};
}
