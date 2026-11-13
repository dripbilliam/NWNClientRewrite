extends RefCounted
# PRIVATE report-only metadata. Never polls tasks, pumps jobs or retains owners.
static func sample(service: Node)->Dictionary:
	if not is_instance_valid(service):return {"available":false}
	for property in service.get_property_list():
		if str(property.name)=="worker_capacity_stats":
			var counters: Dictionary=service.get("worker_capacity_stats")
			return {"available":true,"owner_instance_id":service.get_instance_id(),"maximum_workers":int(service.get("maximum_workers")),"running":service.get("running").size(),"pending":service.get("pending").size(),"counters":counters.duplicate(true),"scope":"Service-lifetime cumulative dispatch counters; retained-wave/running are current metadata. Deduplicate repeated owner IDs before summing waves. No task polling or scheduling in report."}
	return {"available":false,"owner_instance_id":service.get_instance_id(),"maximum_workers":int(service.get("maximum_workers"))}
