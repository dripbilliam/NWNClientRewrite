extends Node
signal completed(id,result)
var maximum_workers:=4
var cache_directory:=""
var calls: Array=[]
func configure(_catalog):pass
func request(name,type,decoder):
	calls.append({"name":name,"type":type,"decoder":decoder,"workers":maximum_workers})
	return calls.size()
