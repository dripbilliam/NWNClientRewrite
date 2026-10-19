// CNWCMessage camera receiver77a7f0. Scalar tags/bit streams are owned by
// NativeMessageReader; these commands affect presentation, never world state.
export function readNetworkCamera(reader,minor){
 if(minor===1){const mask=reader.readByte(),command={kind:'camera-location',mask};if(mask&1)command.yawRadians=reader.readFloat(1,32);if(mask&2)command.distance=reader.readFloat(1,32);if(mask&4)command.pitch=reader.readFloat(1,32);if(mask&8)command.transition=reader.readInt(32);return command;}
 if(minor===2)return{kind:'camera-mode',mode:reader.readByte()};
 if(minor===3)return{kind:'camera-store'};
 if(minor===4)return{kind:'camera-restore'};
 if(minor===5)return{kind:'camera-height',height:reader.readFloat(1,32)};
 if(minor>=6&&minor<=8)return{kind:'camera-lock',axis:['pitch','distance','yaw'][minor-6],locked:Boolean(reader.readBool())};
 if(minor===9)return{kind:'camera-limits',limits:{minPitch:reader.readFloat(1,32),maxPitch:reader.readFloat(1,32),minDist:reader.readFloat(1,32),maxDist:reader.readFloat(1,32)}};
 if(minor===10)return{kind:'camera-attach',objectId:reader.readObjectIdClient(),findClearView:Boolean(reader.readBool())};
 if(minor===12)return{kind:'camera-flags',flags:reader.readInt(32)};
 throw new Error('Unsupported native camera command');
}
