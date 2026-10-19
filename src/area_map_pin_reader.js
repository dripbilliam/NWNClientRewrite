import {readLocalizedClient} from './native_message_text.js';

// LoadArea1407dd55c..1407dd7ee: the complete two pin loops, BEFORE the
// following profiling/sound sections and eventual whole-area error checks.
// This is a verified bounded section, not a complete LoadArea port. It appends
// as it reads; it does not borrow the standalone Created message's guards.
export async function readAreaMapPins(message,area,p){
 const count=message.readInt(32);
 if(count>1_000_000)throw new Error('Native initial waypoint-note count is unsupported');
 for(let i=0;i<count;i++){
  const pin=await p.construct();pin.nativeReference188=message.readObjectIdClient();
  const point=[message.readFloat(1,32),message.readFloat(1,32),message.readFloat(1,32)];await p.position(pin,point);
  pin.nativeEnabled170=message.readBool();await p.text(pin,await readLocalizedClient(message,p));pin.nativeType18c=0;await p.append(area,pin);
 }
 const users=message.readInt(32);
 if(users>1_000_000)throw new Error('Native initial player-pin count is unsupported');
 for(let i=0;i<users;i++){
  const pin=await p.construct();pin.nativeReference188=message.readInt(32)>>>0;
  await p.text(pin,message.readCExoString(32));
  const point=[message.readFloat(1,32),message.readFloat(1,32),message.readFloat(1,32)];await p.position(pin,point);
  pin.nativeEnabled170=1;pin.nativeType18c=1;await p.append(area,pin);
 }
}
