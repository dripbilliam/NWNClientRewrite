// A destination's long-lived diagnostics must not retain the source-owner
// predicate after preparation finishes. The predicate itself closes over the
// origin session/world, so keeping it would retain the entire portal chain.
export function preparationDiagnosticScope({preparing,current,connection}){
 let session=null;
 return{
  allows(){return preparing?Boolean(preparing()):Boolean(session&&!session.closed&&current(session,connection));},
  complete(value){session=value;preparing=null;},
  cancel(){session=null;preparing=null;}
 };
}
