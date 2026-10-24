import {RendererCompiledPass} from './renderer_compiled_pass.js';
import {compileRendererPackets} from './renderer_packet_executor.js';

// Private backend experiment: warmed Three programs/resources are retained,
// while a generated packet program owns main-pass GL submission. Preparation,
// animation, fresh culling/sorting and shadow ownership remain unchanged.
export class RendererPacketPass extends RendererCompiledPass {
 constructor(renderer){super(renderer);this.packets=new WeakMap();}
 executeCommands(plan,generation,gl){
  let packet=this.packets.get(plan);if(!packet){for(const command of plan.commands)if(command.draw&&command.indexed)command.draw.indexBytes=this.renderer.nwnDrawAPI.attributes.get(command.draw.geometry.index)?.bytesPerElement;packet=compileRendererPackets(plan);this.packets.set(plan,packet);}
  packet.execute(this,generation,gl,this.stats);Object.assign(this.stats,{packetBlocks:packet.blocks,packetCodeBytes:packet.codeBytes,packetCommands:packet.commands});
 }
}
