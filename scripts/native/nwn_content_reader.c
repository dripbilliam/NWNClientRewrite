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
typedef struct { unsigned char hash[40]; unsigned shard; } HashLocation;
static Shard shards[4096];
static unsigned shard_count;
static HashLocation *locations;
static unsigned *hash_order;
static unsigned location_count;
static int index_state;
static HANDLE cache_change=INVALID_HANDLE_VALUE;
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
static void release_hash_index(void){
 free(hash_order);hash_order=NULL;
 free(locations);locations=NULL;
 location_count=0;index_state=0;
}
static void release_databases(void){
 release_hash_index();
 for(unsigned i=0;i<shard_count;i++){sqlite3_close(shards[i].db);shards[i].db=NULL;}
 shard_count=0;
 sqlite3_close(meta);meta=NULL;
}
static void refresh_changed_cache(void){
 if(cache_change==INVALID_HANDLE_VALUE)return;
 DWORD changed=WaitForSingleObject(cache_change,0);
 if(changed==WAIT_TIMEOUT)return;
 if(changed!=WAIT_OBJECT_0||!FindNextChangeNotification(cache_change)){
  FindCloseChangeNotification(cache_change);cache_change=INVALID_HANDLE_VALUE;
 }
 release_databases();
}
static int manifest_inventory(void){
 if(!ensure_meta())return response(1,NULL,0);
 sqlite3_stmt *q=NULL;int rc=sqlite3_prepare_v2(meta,"select m.sha1,substr(coalesce(nullif(d.module_name,''),nullif(d.description,''),m.origin_url,''),1,120) from manifests m left join manifest_metadata d on d.manifest_sha1=m.sha1 order by coalesce(m.last_used_at,0) desc,m.sha1",-1,&q,NULL);
 if(rc!=SQLITE_OK){sqlite3_finalize(q);q=NULL;rc=sqlite3_prepare_v2(meta,"select sha1,'' from manifests order by sha1",-1,&q,NULL);}
 if(rc!=SQLITE_OK)return response(2,NULL,0);
 unsigned capacity=16,count=0;unsigned char *out=malloc(4+(size_t)capacity*552);if(!out){sqlite3_finalize(q);return response(2,NULL,0);}
 while((rc=sqlite3_step(q))==SQLITE_ROW){
  const unsigned char *hash=sqlite3_column_text(q,0),*label=sqlite3_column_text(q,1);int len=sqlite3_column_bytes(q,1);
  if(count>=1024||!hash_ok(hash,(unsigned)sqlite3_column_bytes(q,0))||len<0||len>512){rc=SQLITE_ERROR;break;}
  if(count==capacity){capacity*=2;unsigned char *next=realloc(out,4+(size_t)capacity*552);if(!next){rc=SQLITE_NOMEM;break;}out=next;}
  unsigned char *row=out+4+(size_t)count*552;memset(row,0,552);memcpy(row,hash,40);if(len)memcpy(row+40,label,(size_t)len);count++;
 }
 sqlite3_finalize(q);putword(out,count);int ok=response(rc==SQLITE_DONE?0:2,out,rc==SQLITE_DONE?4+count*552:0);free(out);return ok;
}
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
  if(count>=ROW_LIMIT||length<1||length>16||type<0||type>65535||!hash_ok(sha,(unsigned)sqlite3_column_bytes(q,2))){rc=SQLITE_ERROR;break;}
  if(count==capacity){capacity*=2;unsigned char *next=realloc(out,4+(size_t)capacity*58);if(!next){rc=SQLITE_NOMEM;break;}out=next;}
  unsigned char *row=out+4+(size_t)count*58;memset(row,0,58);memcpy(row,name,(size_t)length);row[16]=(unsigned char)type;row[17]=(unsigned char)(type>>8);memcpy(row+18,sha,40);count++;
 }
 sqlite3_finalize(q);putword(out,count);int ok=response(rc==SQLITE_DONE?0:2,out,rc==SQLITE_DONE?4+count*58:0);free(out);return ok;
}
static int ensure_shards(void){
 if(!ensure_meta())return 0;
 if(!shard_count){
  sqlite3_stmt *q=NULL;if(sqlite3_prepare_v2(meta,"select id from shards order by id",-1,&q,NULL)!=SQLITE_OK)return -1;int rc;
  unsigned count=0;
  while((rc=sqlite3_step(q))==SQLITE_ROW){int id=sqlite3_column_int(q,0);if(id<1||count==4096){rc=SQLITE_ERROR;break;}shards[count++].id=id;}
  sqlite3_finalize(q);if(rc!=SQLITE_DONE)return -1;
  shard_count=count;
 }
 return 1;
}
static sqlite3 *shard_database(unsigned index){
 Shard *shard=&shards[index];
 if(!shard->db){
  char file[64];
  snprintf(file,sizeof(file),"nwsyncdata_%d.sqlite3",shard->id-1);
  shard->db=open_database(file);
 }
 return shard->db;
}
static int compare_hash_locations(const void *a,const void *b){
 unsigned left=*(const unsigned*)a,right=*(const unsigned*)b;
 int order=memcmp(locations[left].hash,locations[right].hash,40);
 if(order)return order;
 // The existing reader uses the first shard containing the hash.
 return (left>right)-(left<right);
}
static int build_hash_index(void){
 unsigned capacity=1024;
 locations=malloc(capacity*sizeof(*locations));
 if(!locations)goto failure;
 for(unsigned i=0;i<shard_count;i++){
  sqlite3 *db=shard_database(i);
  sqlite3_stmt *q=NULL;
  if(!db||sqlite3_prepare_v2(db,"select sha1 from resrefs",-1,&q,NULL)!=SQLITE_OK)goto failure;
  int rc;
  while((rc=sqlite3_step(q))==SQLITE_ROW){
   const unsigned char *hash=sqlite3_column_text(q,0);
   if(location_count==ROW_LIMIT||!hash_ok(hash,(unsigned)sqlite3_column_bytes(q,0))){rc=SQLITE_ERROR;break;}
   if(location_count==capacity){
    capacity*=2;
    HashLocation *next=realloc(locations,capacity*sizeof(*locations));
    if(!next){rc=SQLITE_NOMEM;break;}
    locations=next;
   }
   HashLocation *location=&locations[location_count++];
   memcpy(location->hash,hash,40);
   location->shard=i;
  }
  sqlite3_finalize(q);
  if(rc!=SQLITE_DONE)goto failure;
 }
 if(location_count){
  hash_order=malloc(location_count*sizeof(*hash_order));
  if(!hash_order)goto failure;
  for(unsigned i=0;i<location_count;i++)hash_order[i]=i;
  qsort(hash_order,location_count,sizeof(*hash_order),compare_hash_locations);
 }
 index_state=1;
 return 1;
failure:
 release_hash_index();
 index_state=-1;
 return 0;
}
static int inventory(void){
 int state=ensure_shards();
 if(state<1)return response(state==0?1:2,NULL,0);
 if(cache_change==INVALID_HANDLE_VALUE)release_hash_index();
 if(index_state!=1&&!build_hash_index())return response(2,NULL,0);
 unsigned size=4+location_count*40;
 unsigned char *out=malloc(size);
 if(!out)return response(2,NULL,0);
 putword(out,location_count);
 for(unsigned i=0;i<location_count;i++)memcpy(out+4+(size_t)i*40,locations[i].hash,40);
 int ok=response(0,out,size);
 free(out);
 if(cache_change==INVALID_HANDLE_VALUE)release_hash_index();
 return ok;
}
static int indexed_shard(const unsigned char *hash){
 unsigned first=0,end=location_count;
 while(first<end){
  unsigned middle=first+(end-first)/2;
  if(memcmp(locations[hash_order[middle]].hash,hash,40)<0)first=middle+1;
  else end=middle;
 }
 if(first==location_count||memcmp(locations[hash_order[first]].hash,hash,40))return -1;
 return (int)locations[hash_order[first]].shard;
}
// Return -1 for a missing row. Every other return is the protocol write result.
static int read_blob(unsigned shard,const unsigned char *hash){
 sqlite3 *db=shard_database(shard);
 sqlite3_stmt *q=NULL;
 if(!db||sqlite3_prepare_v2(db,"select data from resrefs where sha1 = ?",-1,&q,NULL)!=SQLITE_OK)return response(2,NULL,0);
 sqlite3_bind_text(q,1,(const char*)hash,40,SQLITE_TRANSIENT);
 int rc=sqlite3_step(q),result=-1;
 if(rc==SQLITE_ROW){
  int size=sqlite3_column_bytes(q,0);
  result=size>=0&&(unsigned)size<=LIMIT?response(0,sqlite3_column_blob(q,0),(unsigned)size):response(2,NULL,0);
 }else if(rc!=SQLITE_DONE)result=response(2,NULL,0);
 sqlite3_finalize(q);
 return result;
}
static int blob(const unsigned char *hash,unsigned n){
 if(!hash_ok(hash,n))return response(2,NULL,0);
 int state=ensure_shards();
 if(state<1)return response(state==0?1:2,NULL,0);
 if(cache_change!=INVALID_HANDLE_VALUE&&(index_state==1||(!index_state&&build_hash_index()))){
  int shard=indexed_shard(hash);
  if(shard<0)return response(1,NULL,0);
  int result=read_blob((unsigned)shard,hash);
  if(result>=0)return result;
  // A concurrent writer can remove an entry between indexing and demand.
  release_hash_index();
 }
 for(unsigned i=0;i<shard_count;i++){
  int result=read_blob(i,hash);
  if(result>=0)return result;
 }
 return response(1,NULL,0);
}
static int decompress(const unsigned char *p,unsigned n){
 if(n<4||word(p)>LIMIT)return response(2,NULL,0);unsigned expected=word(p);unsigned char *out=malloc(expected?expected:1);if(!out)return response(2,NULL,0);
 size_t actual=ZSTD_decompress(out,expected,p+4,n-4);int ok=ZSTD_isError(actual)||actual!=expected?response(2,NULL,0):response(0,out,expected);free(out);return ok;
}
int wmain(int argc,wchar_t **argv){
 if(argc!=2)return 1;int size=WideCharToMultiByte(CP_UTF8,0,argv[1],-1,NULL,0,NULL,NULL);root=malloc((size_t)size);if(!root)return 1;WideCharToMultiByte(CP_UTF8,0,argv[1],-1,root,size,NULL,NULL);
 cache_change=FindFirstChangeNotificationW(argv[1],FALSE,FILE_NOTIFY_CHANGE_FILE_NAME|FILE_NOTIFY_CHANGE_SIZE|FILE_NOTIFY_CHANGE_LAST_WRITE);
 _setmode(_fileno(stdin),_O_BINARY);_setmode(_fileno(stdout),_O_BINARY);
 unsigned char header[4];while(fread(header,1,4,stdin)==4){unsigned n=word(header);if(!n||n>LIMIT)break;unsigned char *p=malloc(n);if(!p)break;if(fread(p,1,n,stdin)!=n){free(p);break;}
  if(p[0]!=3)refresh_changed_cache();
  int ok=p[0]==1?manifest(p+1,n-1):p[0]==2?blob(p+1,n-1):p[0]==3?decompress(p+1,n-1):p[0]==4&&n==1?inventory():p[0]==5&&n==1?manifest_inventory():response(2,NULL,0);free(p);if(!ok)break;
 }
 if(cache_change!=INVALID_HANDLE_VALUE)FindCloseChangeNotification(cache_change);
 release_databases();free(root);return 0;
}
