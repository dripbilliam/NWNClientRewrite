// CNWSExpression ParseString140440970 / TestString1404413c0.
// Native tokens are not regular-expression syntax. Class tokens consume one
// or more characters; ** consumes zero or more, with shortest-first backtracking.
const node=(type,literal='')=>({type,literal,next:null,branch:null});
const append=(list,n)=>{
  if(!list.head){list.head=list.current=list.tail=n;return;}
  if(list.current===list.tail)list.tail=n;
  n.next=list.current.next;list.current.next=n;list.current=n;
};
const fold=value=>{
  if([...value].some(c=>c.charCodeAt(0)>127))throw new Error('Native listening locale/non-ASCII case folding is unavailable');
  return value.replace(/[A-Z]/g,c=>String.fromCharCode(c.charCodeAt(0)+32));
};
export class ListenExpression{
  constructor(id=0){this.id=id|0;this.caseSensitive=0;this.pattern='';this.head=null;this.matches=[];}
  parse(value){
    let text=String(value);
    if(this.caseSensitive===0)text=fold(text);
    if(text===this.pattern)return 1; // ctor's empty cached pattern has no graph.
    this.head=null;
    const lists=[{head:null,current:null,tail:null}];let literal='';
    const flush=()=>{if(literal){append(lists.at(-1),node(0,literal));literal='';}};
    for(let i=0;i<text.length;i++){
      const c=text[i],list=lists.at(-1);
      if(c==='('){flush();lists.push({head:null,current:null,tail:null});}
      else if(c===')'){
        flush();if(lists.length===1)return -1000;
        const child=lists.pop(),parent=lists.at(-1);
        if(!parent.head){parent.head=child.head;parent.tail=child.tail;}
        else{
          if(!child.tail)return -1005;
          child.tail.next=parent.current.next;
          if(parent.current===parent.tail)parent.tail=child.tail;
          parent.current.next=child.head;
        }
        parent.current=child.tail;
      }else if(c==='*'){
        flush();if(++i>=text.length)return -1003;
        const type={'*':1,w:4,p:5,a:6,n:7,A:8}[text[i]];
        if(type===undefined)return -1004;
        append(list,node(type));
      }else if(c==='|'){
        flush();if(!list.head)return -1002;
        const join=node(3);append(list,join);
        const split=node(2);split.branch=list.head;split.next=join;
        list.head=list.current=split;
      }else literal+=c;
    }
    flush();if(lists.length!==1)return -1001;
    const list=lists[0],end=node(9);
    if(list.tail)list.tail.next=end;else append(list,end);
    this.head=list.head;this.pattern=text;return 0;
  }
  graph(){
    if(!this.head)return null;
    const seen=new Map(),nodes=[],queue=[this.head];
    while(queue.length){const n=queue.shift();if(!n||seen.has(n))continue;seen.set(n,nodes.length);nodes.push(n);queue.push(n.next,n.branch);}
    return nodes.map(n=>({type:n.type,literal:n.literal,next:seen.get(n.next)??null,branch:seen.get(n.branch)??null}));
  }
  test(value,save=1){
    const original=String(value),text=this.caseSensitive===0?fold(original):original;
    if(!this.head)return 0;
    const allowed=(type,c)=>type===1||type===4&&c===' '||type===5&&['!','.','?'].includes(c)||
      type===6&&c>='a'&&c<='z'||type===7&&c>='0'&&c<='9'||type===8&&(c>='a'&&c<='z'||c>='0'&&c<='9');
    // The native matcher keeps a physical backtracking stack and mutable node
    // visit counts, rather than ordinary regex recursion. In particular, a
    // repeated class at end-of-input aborts the whole search. Preserve that
    // behavior even when another alternation could otherwise match.
    const states=new Map(),state=n=>{if(!states.has(n))states.set(n,{visits:0,end:0});return states.get(n);};
    const sentinel=node(3),stack=[sentinel];let n=this.head,position=0,index=0,steps=0;
    const remove=i=>{if(i>=0&&i<stack.length)stack.splice(i,1);};
    const advance=()=>{n=n.next;if(n)state(n).visits=0;};
    const backtrack=()=>{
      while(true){
        n=stack[index];if(!n)throw new Error('Native expression backtracking storage is unavailable');
        position=state(n).end;
        if(index<=0)return false;
        remove(index);index--;
        if(n.type!==0)return true;
      }
    };
    while(n){
      if(++steps>1000000)throw new Error('Native listening expression search exceeds the supported host allocation limit');
      const saved=index,s=state(n);s.visits++;
      if(n.type===9){
        if(position===text.length){
          if(save!==0){let previous=0;this.matches=[original];for(const frame of stack.slice(1)){if(frame.type===2)continue;const end=state(frame).end;this.matches.push(original.slice(previous,end));previous=end;}}
          return 1;
        }
        if(!backtrack())return 0;continue;
      }
      if(n.type===3){advance();continue;}
      if(n.type===0){
        stack.push(n);index++;
        if([...n.literal].some((c,i)=>(text[position+i]??'\0')!==c)){if(!backtrack())return 0;continue;}
        position+=n.literal.length;s.end=position;advance();continue;
      }
      if(n.type===1){
        stack.push(n);index++;
        if(position===text.length&&s.visits>1)return 0;
        if(s.visits>1)position++;
        s.end=position;advance();continue;
      }
      if(n.type===2){
        s.end=position;stack.push(n);index++;
        if(s.visits===1){advance();continue;}
        if(s.visits===2){n=n.branch;if(n)state(n).visits=0;continue;}
        remove(index);index=saved;if(!backtrack())return 0;continue;
      }
      if(position===text.length)return 0;
      stack.push(n);index++;
      if(!allowed(n.type,text[position]??'\0')){remove(index);index=saved;if(!backtrack())return 0;continue;}
      position++;s.end=position;advance();
    }
    // Native failures retain the previous saved capture list.
    return 0;
  }
}

// CNWSObject+1d8/+1e0/+1e4: physical expression pointer slots. Updating an
// existing pattern number keeps its slot and owner; append grows16, then doubles.
export class ListenExpressions{
  constructor(){this.entries=[];this.count=0;this.capacity=0;}
  set(pattern,id){
    id|=0;let expression=this.entries.slice(0,this.count).find(e=>e.id===id);
    if(!expression){if(this.count===this.capacity){this.capacity=this.capacity===0?16:this.capacity*2;this.entries.length=this.capacity;}
      expression=new ListenExpression(id);this.entries[this.count++]=expression;}
    return expression.parse(pattern);
  }
}
