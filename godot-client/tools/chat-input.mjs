// Raw native chat forwarding. Parsing, mode/name resolution and rendering are
// owned by Godot; this boundary must retain PLAYER_ID and identity metadata.
export async function submitNativeChat(session,scope,message){
 const input={...scope,actorId:message.actorId,channel:message.channel,text:message.text};
 for(const field of ['recipient','playerId','playerAccount'])if(message[field]!==undefined)input[field]=message[field];
 return session.chat(input);
}
