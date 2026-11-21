// One persistent worker for independent particle geometry ranges. The caller
// owns the job storage and must wait before publishing or destroying it.
namespace particle_geometry_worker {
class Worker {
 std::mutex mutex;
 std::condition_variable ready;
 std::condition_variable finished;
 std::thread thread;
 void (*operation)(void*)=nullptr;
 void* argument=nullptr;
 std::exception_ptr failure;
 bool pending=false,complete=true,stopping=false;
 void loop(){
  for(;;){
   std::unique_lock<std::mutex> lock(mutex);
   ready.wait(lock,[&]{return pending||stopping;});
   if(stopping)return;
   auto* input=argument;auto* call=operation;pending=false;
   lock.unlock();
   std::exception_ptr error;
   try{call(input);}catch(...){error=std::current_exception();}
   lock.lock();failure=error;complete=true;lock.unlock();finished.notify_one();
  }
 }
public:
 Worker():thread([this]{loop();}){}
 Worker(const Worker&)=delete;Worker& operator=(const Worker&)=delete;
 ~Worker(){{std::lock_guard<std::mutex> lock(mutex);stopping=true;}ready.notify_one();thread.join();}
 void submit(void (*call)(void*),void* input){
  std::lock_guard<std::mutex> lock(mutex);
  if(!complete||pending||stopping)throw std::runtime_error("Particle geometry worker is busy");
  operation=call;argument=input;failure=nullptr;complete=false;pending=true;ready.notify_one();
 }
 void wait(){
  std::unique_lock<std::mutex> lock(mutex);finished.wait(lock,[&]{return complete;});
  auto error=failure;lock.unlock();if(error)std::rethrow_exception(error);
 }
};
}
