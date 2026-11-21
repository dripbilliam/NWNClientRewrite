extends RefCounted
signal diagnostic_event(event: Dictionary)
const FRAGMENT_CAPACITY:=948
var queues: Dictionary={"high":[],"low":[]}
var rejected:=0

static func packetize(payload: PackedByteArray,high_priority: bool=true)->Dictionary:
	if payload.is_empty() or payload.size()>FRAGMENT_CAPACITY*65535:return {"error":"Invalid native outgoing game-message size"}
	var count: int=ceili(float(payload.size())/FRAGMENT_CAPACITY)
	var frames: Array[PackedByteArray]=[]
	for index in range(count):
		var part:=payload.slice(index*FRAGMENT_CAPACITY,mini(payload.size(),(index+1)*FRAGMENT_CAPACITY))
		var frame:=PackedByteArray();frame.resize(12+part.size())
		frame[7]=(8 if high_priority else 0) | (2 if index==0 else 0)
		if index==0:frame[8]=(count >> 8) & 255;frame[9]=count & 255
		if count==1:frame[10]=(part.size() >> 8) & 255;frame[11]=part.size() & 255
		for n in range(part.size()):frame[12+n]=part[n]
		frames.append(frame)
	return {"frames":frames}

static func be16(bytes: PackedByteArray,at: int)->int:return (int(bytes[at]) << 8) | int(bytes[at+1])

func push(frame: PackedByteArray)->bool:
	if frame.size()<12:return false
	var priority: String="high" if int(frame[7]) & 8 else "low"
	queues[priority].append(frame.duplicate())
	return true

func drain()->Array[Dictionary]:
	var messages: Array[Dictionary]=[]
	for priority in ["high","low"]:
		var queue: Array=queues[priority]
		while not queue.is_empty():
			var first: PackedByteArray=queue[0]
			var count:=be16(first,8)
			if count==0:
				queue.pop_front();rejected+=1
				diagnostic_event.emit({"code":"network.message-rejected","reason":"Native message begins with a continuation frame","priority":priority})
				continue
			if queue.size()<count:break
			var frames: Array=queue.slice(0,count)
			for _index in range(count):queue.pop_front()
			if count>1:
				var bytes: PackedByteArray=frames[0].duplicate()
				for index in range(1,count):bytes.append_array(frames[index].slice(12))
				messages.append({"priority":priority,"bytes":bytes})
				continue
			var at:=0
			while first.size()-at>=12:
				var flags: int=first[at+7]
				var size:=be16(first,at+10)
				if flags & 128:
					if first.size()-at<14:reject(priority);break
					size+=int(first[at+12])*0x1000000+int(first[at+13])*0x10000
				size+=12
				if size>first.size()-at:reject(priority);break
				messages.append({"priority":priority,"bytes":first.slice(at,at+size)})
				at+=size
			if at<first.size() and first.size()-at<12:reject(priority)
		queues[priority]=queue
	return messages

func reject(priority: String)->void:
	rejected+=1
	diagnostic_event.emit({"code":"network.message-rejected","reason":"Truncated native packed message record","priority":priority})
