const validConnection=value=>Number.isSafeInteger(value)&&value>=0;
// Older native base entries can finish without the session wrapper's optional
// connection field. The admitted replay scope is still authoritative. Never
// produce an unscoped acknowledgment or acknowledge a different connection.
export function replayFinishAcknowledgment(message,admittedConnection){
 if(message?.kind!=='finished'||!validConnection(admittedConnection))throw Error('Invalid replay finish boundary');
 const connection=message.connection??admittedConnection;
 if(!validConnection(connection)||connection!==admittedConnection)throw Error('Replay finish connection differs');
 return {kind:'finish-ack',connection};
}
