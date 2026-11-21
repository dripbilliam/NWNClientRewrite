// Protocol-only UI resynchronization. The original server/session still owns
// offered replies, dialogue state and every transmitted choice.
export async function submitNativeDialogReply(session,request,emit){
 try{return await session.replyDialog(request);}
 catch(error){
  if(error.message!=='Native dialog reply is stale or unavailable')throw error;
  const current=session.dialog;
  if(!current)emit({kind:'dialog-close'});
  else{
   const {replies,...entry}=structuredClone(current);emit(entry);
   if(replies)emit(replies);
  }
  return {sent:false,resynchronized:true};
 }
}
