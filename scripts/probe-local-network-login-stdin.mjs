import {NetworkLoginIdentity} from '../electron/network_login_identity.mjs';
import {probeLocalNetworkLogin} from './probe-local-network-login.mjs';

// Private automation entry point. Accept one bounded JSON request on a pipe;
// never accept credentials in argv/environment or echo the request on failure.
if(process.stdin.isTTY)throw new Error('Native login probe requires a private input pipe');
let size=0;const chunks=[];
for await(const chunk of process.stdin){size+=chunk.length;if(size>16384)throw new Error('Native login input is too large');chunks.push(chunk);}
const input=Buffer.concat(chunks);let identity;
try{
 const request=JSON.parse(input.toString('utf8'));
 identity=new NetworkLoginIdentity(request.credentials);delete request.credentials;
 const report=await probeLocalNetworkLogin(identity,request.options);console.log(JSON.stringify(report));if(!report.loginAccepted)process.exitCode=2;
}catch{
 console.log(JSON.stringify({failure:'Private native login probe failed'}));process.exitCode=1;
}finally{input.fill(0);for(const chunk of chunks)chunk.fill(0);identity?.dispose();}
