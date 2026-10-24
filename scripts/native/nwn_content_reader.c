// Read-only access to the original NWSync SQLite cache and bounded Zstandard
// decompression. No game code is loaded. SQLite is public domain; Zstd BSD.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <wchar.h>
#include <io.h>
#include <fcntl.h>
#include <windows.h>
#include "sqlite3.h"
#include "zstd.h"
#define LIMIT (256u*1024u*1024u)
#define ROW_LIMIT 1000000u
static sqlite3 *meta;
typedef struct { int id; sqlite3 *db; } Shard;
static Shard shards[4096];
static unsigned shard_count;
static char *root;
static uint32_t word(const unsigned char *p){return (uint32_t)p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;}
static void putword(unsigned char *p,uint32_t n){p[0]=(unsigned char)n;p[1]=(unsigned char)(n>>8);p[2]=(unsigned char)(n>>16);p[3]=(unsigned char)(n>>24);}
static int hash_ok(const unsigned char *s,unsigned n){if(n!=40)return 0;for(unsigned i=0;i<n;i++)if(!((s[i]>='0'&&s[i]<='9')||(s[i]>='a'&&s[i]<='f')))return 0;return 1;}
static int response(unsigned status,const void *data,unsigned size){unsigned char h[5];putword(h,size+1);h[4]=(unsigned char)status;return fwrite(h,1,5,stdout)==5&&(!size||fwrite(data,1,size,stdout)==size)&&fflush(stdout)==0;}
static sqlite3 *open_database(const char *name){
 size_t len=strlen(root)+strlen(name)+2;char *file=malloc(len);sqlite3 *db=NULL;if(!file)return NULL;
 snprintf(file,len,"%s/%s",root,name);int rc=sqlite3_open_v2(file,&db,SQLITE_OPEN_READONLY|SQLITE_OPEN_NOMUTEX,NULL);free(file);
 if(rc!=SQLITE_OK){sqlite3_close(db);return NULL;}sqlite3_busy_timeout(db,1000);sqlite3_limit(db,SQLITE_LIMIT_LENGTH,LIMIT);return db;
}
static int ensure_meta(void){if(!meta)meta=open_database("nwsyncmeta.sqlite3");return meta!=NULL;}
static int manifest(const unsigned char *hash,unsigned n){
 if(!hash_ok(hash,n))return response(2,NULL,0);if(!ensure_meta())return response(1,NULL,0);
 sqlite3_stmt *q=NULL;int rc=sqlite3_prepare_v2(meta,"select count(sha1) from manifests where sha1 = ?",-1,&q,NULL);
 if(rc!=SQLITE_OK)return response(2,NULL,0);sqlite3_bind_text(q,1,(const char*)hash,40,SQLITE_TRANSIENT);rc=sqlite3_step(q);int exists=rc==SQLITE_ROW&&sqlite3_column_int(q,0)>0;sqlite3_finalize(q);
 if(rc!=SQLITE_ROW)return response(2,NULL,0);if(!exists)return response(1,NULL,0);
 rc=sqlite3_prepare_v2(meta,"select resref, restype, resref_sha1 from manifest_resrefs where manifest_sha1 = ?",-1,&q,NULL);
 if(rc!=SQLITE_OK)return response(2,NULL,0);sqlite3_bind_text(q,1,(const char*)hash,40,SQLITE_TRANSIENT);
 unsigned count=0,capacity=1024;unsigned char *out=malloc(4+(size_t)capacity*58);if(!out){sqlite3_finalize(q);return response(2,NULL,0);}
 while((rc=sqlite3_step(q))==SQLITE_ROW){
  const unsigned char *name=sqlite3_column_text(q,0),*sha=sqlite3_column_text(q,2);int length=sqlite3_column_bytes(q,0),type=sqlite3_column_int(q,1);
  if(count>=ROW_LIMIT||length<1||length>16||type<1||type>65535||!hash_ok(sha,(unsigned)sqlite3_column_bytes(q,2))){rc=SQLITE_ERROR;break;}
  if(count==capacity){capacity*=2;unsigned char *next=realloc(out,4+(size_t)capacity*58);if(!next){rc=SQLITE_NOMEM;break;}out=next;}
  unsigned char *row=out+4+(size_t)count*58;memset(row,0,58);memcpy(row,name,(size_t)length);row[16]=(unsigned char)type;row[17]=(unsigned char)(type>>8);memcpy(row+18,sha,40);count++;
 }
 sqlite3_finalize(q);putword(out,count);int ok=response(rc==SQLITE_DONE?0:2,out,rc==SQLITE_DONE?4+count*58:0);free(out);return ok;
}
static int ensure_shards(void){
 if(!ensure_meta())return 0;
 if(!shard_count){
  sqlite3_stmt *q=NULL;if(sqlite3_prepare_v2(meta,"select id from shards order by id",-1,&q,NULL)!=SQLITE_OK)return -1;int rc;
  while((rc=sqlite3_step(q))==SQLITE_ROW){int id=sqlite3_column_int(q,0);if(id<1||shard_count==4096){rc=SQLITE_ERROR;break;}shards[shard_count++].id=id;}
  sqlite3_finalize(q);if(rc!=SQLITE_DONE)return -1;
 }
 return 1;
}
static int inventory(void){
 int state=ensure_shards();if(state<1)return response(state==0?1:2,NULL,0);
 unsigned capacity=1024,count=0;unsigned char *out=malloc(4+(size_t)capacity*40);if(!out)return response(2,NULL,0);int error=0;
 for(unsigned i=0;i<shard_count&&!error;i++){
  Shard *s=&shards[i];if(!s->db){char file[64];snprintf(file,sizeof(file),"nwsyncdata_%d.sqlite3",s->id-1);s->db=open_database(file);if(!s->db){error=1;break;}}
  sqlite3_stmt *q=NULL;if(sqlite3_prepare_v2(s->db,"select sha1 from resrefs",-1,&q,NULL)!=SQLITE_OK){error=1;break;}int rc;
  while((rc=sqlite3_step(q))==SQLITE_ROW){const unsigned char *hash=sqlite3_column_text(q,0);if(count>=ROW_LIMIT||!hash_ok(hash,(unsigned)sqlite3_column_bytes(q,0))){error=1;break;}
   if(count==capacity){capacity*=2;unsigned char *next=realloc(out,4+(size_t)capacity*40);if(!next){error=1;break;}out=next;}memcpy(out+4+(size_t)count*40,hash,40);count++;
  }
  if(rc!=SQLITE_DONE)error=1;sqlite3_finalize(q);
 }
 putword(out,count);int ok=response(error?2:0,out,error?0:4+count*40);free(out);return ok;
}
static int blob(const unsigned char *hash,unsigned n){
 if(!hash_ok(hash,n))return response(2,NULL,0);int state=ensure_shards();if(state<1)return response(state==0?1:2,NULL,0);
 for(unsigned i=0;i<shard_count;i++){
  Shard *s=&shards[i];if(!s->db){char file[64];snprintf(file,sizeof(file),"nwsyncdata_%d.sqlite3",s->id-1);s->db=open_database(file);if(!s->db)return response(2,NULL,0);}
  sqlite3_stmt *q=NULL;if(sqlite3_prepare_v2(s->db,"select data from resrefs where sha1 = ?",-1,&q,NULL)!=SQLITE_OK)return response(2,NULL,0);
  sqlite3_bind_text(q,1,(const char*)hash,40,SQLITE_TRANSIENT);int rc=sqlite3_step(q);
  if(rc==SQLITE_ROW){int size=sqlite3_column_bytes(q,0);int ok=size>=0&&(unsigned)size<=LIMIT?response(0,sqlite3_column_blob(q,0),(unsigned)size):response(2,NULL,0);sqlite3_finalize(q);return ok;}
  sqlite3_finalize(q);if(rc!=SQLITE_DONE)return response(2,NULL,0);
 }
 return response(1,NULL,0);
}
static int decompress(const unsigned char *p,unsigned n){
 if(n<4||word(p)>LIMIT)return response(2,NULL,0);unsigned expected=word(p);unsigned char *out=malloc(expected?expected:1);if(!out)return response(2,NULL,0);
 size_t actual=ZSTD_decompress(out,expected,p+4,n-4);int ok=ZSTD_isError(actual)||actual!=expected?response(2,NULL,0):response(0,out,expected);free(out);return ok;
}
int wmain(int argc,wchar_t **argv){
 if(argc!=2)return 1;int size=WideCharToMultiByte(CP_UTF8,0,argv[1],-1,NULL,0,NULL,NULL);root=malloc((size_t)size);if(!root)return 1;WideCharToMultiByte(CP_UTF8,0,argv[1],-1,root,size,NULL,NULL);
 _setmode(_fileno(stdin),_O_BINARY);_setmode(_fileno(stdout),_O_BINARY);
 unsigned char header[4];while(fread(header,1,4,stdin)==4){unsigned n=word(header);if(!n||n>LIMIT)break;unsigned char *p=malloc(n);if(!p)break;if(fread(p,1,n,stdin)!=n){free(p);break;}
  int ok=p[0]==1?manifest(p+1,n-1):p[0]==2?blob(p+1,n-1):p[0]==3?decompress(p+1,n-1):p[0]==4&&n==1?inventory():response(2,NULL,0);free(p);if(!ok)break;
 }
 for(unsigned i=0;i<shard_count;i++)sqlite3_close(shards[i].db);sqlite3_close(meta);free(root);return 0;
}
