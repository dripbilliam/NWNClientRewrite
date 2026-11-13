// A deliberately small diagnostic projection. Error messages/cause objects can
// contain caller data; only known labels and standard error codes are admitted.
const stages=new Set(['validate-options','resolve-address','bind-socket','application-identity','platform-identity','login-context','key-exchange','send-key-exchange','await-admission','session-connect']);
const names=new Set(['Error','TypeError','RangeError','SyntaxError','AggregateError']);
const reasons=new Map([
 ['Concurrent native crypto operations are unavailable','crypto-concurrent'],
 ['Native network crypto helper is closed','crypto-closed'],
 ['Native network crypto helper is unavailable','crypto-unavailable'],
 ['Native network crypto helper stopped','crypto-stopped'],
 ['Native network crypto helper input failed','crypto-input-failed'],
 ['Native network crypto helper timed out','crypto-timeout'],
 ['Native network cryptographic authentication failed','crypto-authentication'],
 ['Invalid native application identity output','application-identity-invalid'],
 ['Invalid native platform identity output','platform-identity-invalid'],
 ['Invalid native network connection settings','invalid-options'],
 ['Native network login timed out','server-timeout']
]);
export function networkConnectionFailure(error,stage){
 const code=typeof error?.code==='string'&&/^(?:ERR_[A-Z0-9_]{1,64}|E[A-Z0-9_]{1,24})$/.test(error.code)?error.code:null;
 return {stage:stages.has(stage)?stage:'session-connect',name:names.has(error?.name)?error.name:'Error',code,reason:reasons.get(error?.message)??'connection-failed'};
}
export function networkConnectionFailureText(failure){
 const stage=stages.has(failure?.stage)?failure.stage:'session-connect';
 const detail=failure?.code??(failure?.reason&&failure.reason!=='connection-failed'?failure.reason:null);
 return 'Native game session connection failed ('+stage+(detail?': '+detail:'')+')';
}
