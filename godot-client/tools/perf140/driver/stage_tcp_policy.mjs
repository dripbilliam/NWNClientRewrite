// Private two-ended loopback transport probe; never changes NWN UDP delivery.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {stage,hash} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const root=path.join(project,'.cache/native-140fps/root');
const parentFile=path.join(root,'combined-loading-fenced-v1/manifest.json');
const parent=JSON.parse(fs.readFileSync(parentFile));
const label='combined-tcp-probe-v1',folder=path.join(root,label+'-draft');
if(fs.existsSync(folder))throw Error('Prior transport probe is preserved');fs.mkdirSync(folder);
const relative='native_live_world.gd';let text=fs.readFileSync(path.join(parent.project,relative),'utf8');
const before='\t\tif not authenticated: authenticated=true; send({"kind":"hello","token":ticket.token}); ticket.clear()';
if(text.split(before).length!==2)throw Error('Native handshake boundary differs');
const after='\t\tif not authenticated:\n\t\t\tvar loopback_probe: bool=args.get("offline-replay","")=="true" and args.get("tcp-no-delay","")=="true"\n\t\t\tif loopback_probe: peer.set_no_delay(true)\n\t\t\treport.loopback_tcp_policy={"native_no_delay_applied":loopback_probe,"host":str(peer.get_connected_host()),"port":peer.get_connected_port(),"before_hello":true,"scope":"Private offline loopback transport probe; NWN game protocol unchanged"}\n\t\t\tauthenticated=true; send({"kind":"hello","token":ticket.token}); ticket.clear()';
text=text.replace(before,after);const from=path.join(folder,relative);fs.writeFileSync(from,text);
console.log(JSON.stringify(stage(project,parentFile,label,[{relative,from,before:parent.pins.find(p=>p.relative===relative).sha256,after:hash(Buffer.from(text))}])));
