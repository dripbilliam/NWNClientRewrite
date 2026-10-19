import {GameCamera} from '../src/game_camera.js';
import {NetworkFrontend} from '../src/network_frontend.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {PerspectiveCamera,Vector3,Group,Mesh,MeshBasicMaterial,PlaneGeometry,Scene,WebGLRenderer,SphereGeometry,DoubleSide,Color} from 'three';
import {cameraQuaternion} from '../src/game_camera.js';
import {NetworkPlayerCamera} from '../src/network_camera.js';
import {parse2da} from '../src/area.js';
window.runCameraCommandFixture=async fixture=>{
 let current,applied=0;const frontend=new NetworkFrontend({bridge:{subscribe:()=>()=>{},disconnect:async()=>{}},canEnter:()=>{},onEnter:()=>{},onExit:()=>{},onState:()=>{},onCamera:message=>{if(!current.applyCommand(message))throw new Error('Camera command was rejected');applied++;}});
 frontend.receive({kind:'state',sessionId:'camera-fixture',state:{phase:'connecting'}});const canonical=JSON.stringify(frontend.world.snapshot());
 for(const row of fixture.rows){if(row.steps[0].minor===12)continue;const c=row.case,mode=c.mode??1;current=new GameCamera();current.reset({mode,height:mode===1?1.75:1.25,yaw:c.yaw??35});current.distance=c.distance??20;current.pitch=c.pitch??50;
  for(const [i,step]of row.steps.entries()){
   if(i===1&&row.steps[0].minor===3)Object.assign(current,{distance:7,yaw:-20,pitch:30});
   const bytes=Uint8Array.from([80,16,step.minor,...step.body.match(/../g)?.map(v=>parseInt(v,16))??[]]);
   frontend.receive({kind:'message',sessionId:'camera-fixture',message:decodeServerGameMessage(bytes)});await frontend.queue;
   for(const key of ['mode','yaw','distance','pitch'])if(current[key]!==step.state[key])throw new Error('Camera queue mismatch: '+key);
   if(JSON.stringify(current.offset)!==JSON.stringify(step.state.height))throw new Error('Height mismatch');
  }
 }
 const before=applied;frontend.receive({kind:'message',sessionId:'stale',message:{kind:'camera-height',height:999}});await frontend.queue;
 if(applied!==before||JSON.stringify(frontend.world.snapshot())!==canonical)throw new Error('Stale camera event or canonical state mutation');
 const errors=runtimeDiagnostics.records.filter(r=>r.severity==='error');if(errors.length)throw new Error('Camera frontend errors: '+JSON.stringify(errors.map(r=>r.code)));
 return{applied,staleIgnored:true,canonicalUnchanged:true,runtimeErrors:errors.length,limits:'Isolated native packet/DOM routing fixture, no live network or server-command acceptance claim.'};
};
window.runCameraCollisionFixture=async fixture=>{
 const reports=[],p=new NetworkPlayerCamera({report:(...a)=>reports.push(a)}),id=0xffffffff,area=0x80000001,world={localObjectId:id,areaId:area,registry:new Map()},wrapper=new Group(),position=[2,3,.5];wrapper.position.set(position[0],position[2],-position[1]);world.registry.set(id,{id,areaId:area,objectType:5,appearance:{appearance:0},replicated:{position,orientation:[0,1,0],animation:0}});
 const root=new Group(),tile=new Group();tile.userData.nativeStaticTile=true;root.add(tile);const presentation={root,objects:new Map([[id,{wrapper,models:[{}]}]]),tables:{appearance:parse2da('2DA V2.0\n\nHEIGHT\n0 1.75\n')},motion:{objects:new Map()}},camera=new PerspectiveCamera(45,4/3,.1,500),controls={target:new Vector3()},canonical=JSON.stringify([...world.registry.values()]),results=[];
 const nativeFlags=fixture.rows.find(r=>r.steps[0].minor===12&&r.steps[0].ops[0][1]===1).steps[0],message=decodeServerGameMessage(Uint8Array.from([80,16,12,...nativeFlags.body.match(/../g).map(v=>parseInt(v,16))]));
 const wall=new Mesh(new PlaneGeometry(10,10),new MeshBasicMaterial({color:0xd95142,side:DoubleSide}));wall.userData.nativeModelMesh=true;tile.add(wall);wall.position.x=1000;
 for(const mode of [0,1,2]){
  p.reset();presentation.cameraQuery=null;p.controller.setMode(mode);p.update(world,presentation,camera,controls,1,{keyholeActive:true});p.receive(message,world,presentation);const original=p.controller.distance,focus=controls.target.clone(),mid=camera.position.clone().lerp(focus,.5);wall.position.copy(mid);wall.lookAt(focus);
  p.update(world,presentation,camera,controls,.016,{keyholeActive:true});const shortened=p.controller.distance;if(!(shortened<original&&shortened>1))throw new Error('Native collision failed to shorten mode '+mode);
  wall.position.x+=1000;for(let i=0;i<320;i++)p.update(world,presentation,camera,controls,.016,{keyholeActive:true});if(Math.abs(p.controller.distance-original)>.00003)throw new Error('Native collision failed to recover mode '+mode);
  results.push({mode,shortened,recovered:p.controller.distance,saved:mode===2?p.controller.collisionState.stiff.distance:p.controller.collisionState.primary.distance});
 }
 if(JSON.stringify([...world.registry.values()])!==canonical||reports.length)throw new Error('Collision changed canonical state or emitted diagnostics');
 // Render the current PC anchor and floor through the production camera after
 // its native collision/recovery sequence. No installed assets are copied.
 const scene=new Scene();scene.background=new Color(0x1b242a);scene.add(root);const sphere=new Mesh(new SphereGeometry(.6,16,12),new MeshBasicMaterial({color:0x55cf9b}));sphere.position.copy(wrapper.position);sphere.position.y+=.8;scene.add(sphere);const floor=new Mesh(new PlaneGeometry(50,50),new MeshBasicMaterial({color:0x687681,side:DoubleSide}));floor.rotation.x=-Math.PI/2;floor.position.copy(wrapper.position);scene.add(floor);
 const renderer=new WebGLRenderer({antialias:true,preserveDrawingBuffer:true});renderer.setSize(640,480);Object.assign(renderer.domElement.style,{position:'fixed',left:'0',top:'0',zIndex:'10000'});document.body.append(renderer.domElement);renderer.render(scene,camera);window.collisionFixtureRenderer=renderer;
 return{modes:results,nativeFlagPacket:true,canonicalUnchanged:true,rendered:true,limits:'Isolated native-body/controller/static scene fixture; not live server/original-client collision acceptance.'};
};
window.runCameraLocationFixture=async fixture=>{
 let current,applied=0;const frontend=new NetworkFrontend({bridge:{subscribe:()=>()=>{},disconnect:async()=>{}},canEnter:()=>{},onEnter:()=>{},onExit:()=>{},onState:()=>{},onCamera:message=>{if(!current.applyCommand(message))throw new Error('Location command rejected');applied++;}});
 frontend.receive({kind:'state',sessionId:'location-fixture',state:{phase:'connecting'}});const canonical=JSON.stringify(frontend.world.snapshot());
 for(const row of fixture.packets){current=new GameCamera();Object.assign(current,row.case);const bytes=Uint8Array.from([80,16,1,...row.body.match(/../g).map(v=>parseInt(v,16))]);frontend.receive({kind:'message',sessionId:'location-fixture',message:decodeServerGameMessage(bytes)});await frontend.queue;
  if(JSON.stringify(Object.values(current.scriptLocation))!==JSON.stringify(row.observation.target))throw new Error('Location target mismatch');for(const key of ['yaw','pitch','distance'])if(current[key]!==row.observation[key])throw new Error('Location snap mismatch');
 }
 const row=fixture.packets.find(r=>r.ops[0][1]===15&&r.observation.target[3]===45);current=new GameCamera();Object.assign(current,row.case);current.quaternion=cameraQuaternion(current.yaw,current.pitch);current.focus=[0,0,current.height];
 frontend.receive({kind:'message',sessionId:'location-fixture',message:decodeServerGameMessage(Uint8Array.from([80,16,1,...row.body.match(/../g).map(v=>parseInt(v,16))]))});await frontend.queue;
 const camera=new PerspectiveCamera(),controls={target:new Vector3()};let frames=0;do{current.update({position:[0,0,0]},1/60,camera,controls);frames++;}while(current.scriptLocation.rate&&frames<10000);
 if(current.scriptLocation.rate||Math.abs(current.distance-row.observation.target[0])>.0001||Math.abs(current.yaw-row.observation.target[1])>.0001||Math.abs(current.pitch-row.observation.target[2])>.0001)throw new Error('Scripted camera did not reach native endpoint');
 if(camera.getWorldDirection(new Vector3()).distanceTo(controls.target.clone().sub(camera.position).normalize())>.0001)throw new Error('Scripted camera lost its follow anchor');
 if(JSON.stringify(frontend.world.snapshot())!==canonical)throw new Error('Location presentation mutated canonical state');
 return{packets:applied,frames,endpoint:current.scriptLocation,canonicalUnchanged:true,limits:'Isolated packet/frontend/Three camera fixture; no live server reception claim.'};
};
window.runCameraAttachmentFixture=async fixture=>{
 const reports=[],p=new NetworkPlayerCamera({report:(...args)=>reports.push(args)}),self=0xffffffff,target=0x80000008,area=0x80000001;
 let frontend;const presentation={objects:new Map(),tables:{appearance:parse2da('2DA V2.0\n\nHEIGHT\n0 1.75\n')},motion:{objects:new Map()}};
 frontend=new NetworkFrontend({bridge:{subscribe:()=>()=>{},disconnect:async()=>{}},canEnter:()=>{},onEnter:()=>{},onExit:()=>{},onState:()=>{},onCamera:message=>p.receive(message,frontend.world,presentation)});
 frontend.receive({kind:'state',sessionId:'attachment-fixture',state:{phase:'connecting'}});const world=frontend.world;world.localObjectId=self;world.areaId=area;
 for(const [id,position]of [[self,[2,3,0]],[target,[10,12,0]]]){const object={id,areaId:area,objectType:5,appearance:{appearance:0},replicated:{position,orientation:[0,1,0],animation:0}};if(world.registry.addObjectAtPos(id,object).status!==0)throw new Error('Fixture object registration failed');const wrapper=new Group();wrapper.position.set(position[0],position[2],-position[1]);presentation.objects.set(id,{wrapper});}
 const camera=new PerspectiveCamera(),controls={target:new Vector3()};p.update(world,presentation,camera,controls,.016);const before=JSON.stringify([...world.registry.objects.values()]);
 const row=fixture.packets.find(r=>r.targetId===target&&!r.findClear),bytes=Uint8Array.from([80,16,10,...row.body.match(/../g).map(v=>parseInt(v,16))]);frontend.receive({kind:'message',sessionId:'attachment-fixture',message:decodeServerGameMessage(bytes)});await frontend.queue;p.update(world,presentation,camera,controls,.016);
 if(p.targetId!==target||p.controlledId!==self)throw new Error('Attachment/control mismatch');presentation.objects.get(target).wrapper.position.x+=1;p.update(world,presentation,camera,controls,.016);if(p.anchor[0]!==11)throw new Error('Rendered attachment motion was not followed');
 if(JSON.stringify([...world.registry.objects.values()])!==before)throw new Error('Attachment changed canonical state');world.registry.get(target).replicationRemoved=true;presentation.objects.delete(target);p.update(world,presentation,camera,controls,.016);if(p.targetId!==self||p.attachmentId!==null||world.localObjectId!==self)throw new Error('Attachment did not revert');
 if(reports.length)throw new Error('Unexpected attachment diagnostic');return{nativePacket:true,renderMotionFollowed:true,canonicalUnchanged:true,reverted:true,controlledId:world.localObjectId,limits:'Isolated native-body/frontend/render-camera fixture; no live server attachment acceptance claim.'};
};
window.runCameraClearViewFixture=async fixture=>{
 const reports=[],p=new NetworkPlayerCamera({report:(...a)=>reports.push(a)}),self=0xffffffff,target=0x80000008,area=0x80000001;
 const presentation={root:new Group(),objects:new Map(),tables:{appearance:parse2da('2DA V2.0\n\nHEIGHT\n0 1.75\n')},motion:{objects:new Map()}};let frontend;
 frontend=new NetworkFrontend({bridge:{subscribe:()=>()=>{},disconnect:async()=>{}},canEnter:()=>{},onEnter:()=>{},onExit:()=>{},onState:()=>{},onCamera:m=>p.receive(m,frontend.world,presentation)});frontend.receive({kind:'state',sessionId:'clear-view-fixture',state:{phase:'connecting'}});const world=frontend.world;world.localObjectId=self;world.areaId=area;
 for(const [id,position,orientation]of [[self,[2,3,0],[-1,0,0]],[target,[10,12,0],[0,1,0]]]){const object={id,areaId:area,objectType:5,appearance:{appearance:0},replicated:{position,orientation,animation:0}};world.registry.addObjectAtPos(id,object);const wrapper=new Group();wrapper.position.set(position[0],position[2],-position[1]);presentation.objects.set(id,{wrapper});}
 const camera=new PerspectiveCamera(),controls={target:new Vector3()};p.update(world,presentation,camera,controls,1);const canonical=JSON.stringify([...world.registry.objects.values()]);
 const row=fixture.packets.find(r=>r.targetId===target&&r.findClear);frontend.receive({kind:'message',sessionId:'clear-view-fixture',message:decodeServerGameMessage(Uint8Array.from([80,16,10,...row.body.match(/../g).map(v=>parseInt(v,16))]))});await frontend.queue;
 const tile=new Group(),wall=new Mesh(new PlaneGeometry(2,2),new MeshBasicMaterial()),pitch=50*Math.PI/180;tile.userData.nativeStaticTile=true;wall.userData.nativeModelMesh=true;tile.add(wall);presentation.root.add(tile);
 wall.position.set(10,1.25+10*Math.cos(pitch),-(12-10*Math.sin(pitch)));wall.lookAt(new Vector3(10,1.25+20*Math.cos(pitch),-(12-20*Math.sin(pitch))));p.update(world,presentation,camera,controls,1);
 if(p.controller.yaw!==180||!p.controller.clearViewResult.selected||p.controller.clearViewResult.queries!==2||p.controller.findClearView)throw new Error('Static wall did not select native opposite angle');
 p.update(world,presentation,camera,controls,.016);if(JSON.stringify([...world.registry.objects.values()])!==canonical||world.localObjectId!==self||reports.length)throw new Error('Clear-view changed canonical state or reported errors');
 wall.geometry.dispose();wall.material.dispose();return{nativePacket:true,staticWallAvoided:true,queries:p.controller.clearViewResult.queries,oneShotCleared:true,canonicalUnchanged:true,limits:'Native search order with renderer geometry adapter; no exact BSP edge or live original comparison claim.'};
};
