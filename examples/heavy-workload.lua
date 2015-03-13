local dpdk		= require "dpdk"
local memory	= require "memory"
local device	= require "device"

function master(...)
	local port1, port2, cores  = tonumberall(...)
	local dev1 = device.config(port1, 1, cores)
	local dev2 = device.config(port2, 1, cores)
	dev1:wait()
	dev2:wait()
	for i = 0, cores - 1 do
		dpdk.launchLua("loadSlave", (i % 2 == 0 and dev1 or dev2):getTxQueue(i))
	end
	dpdk.waitForSlaves()
end

function loadSlave(queue)
	printf("Starting task for %s", queue)
	local mem = memory.createMemPool(function(buf)
		buf:getUDPPacket():fill({
			pktLength = 60
		})
	end)
	local lastPrint = dpdk.getTime()
	local totalSent = 0
	local lastTotal = 0
	local lastSent = 0
	local bufs = mem:bufArray(63)
	while dpdk.running() do
		bufs:alloc(60)
		for _, buf in ipairs(bufs) do
			local pkt = buf:getUDPPacket()
			-- TODO: figure out if using a custom random number generator is faster
			-- 'good random' isn't needed here, a simple xorshift would be sufficient (and could run on 64bit datatypes)
			pkt.payload.uint32[0] = math.random() * 2^32
			pkt.payload.uint32[1] = math.random() * 2^32
			pkt.payload.uint32[2] = math.random() * 2^32
			pkt.payload.uint32[3] = math.random() * 2^32
			pkt.udp.src = math.random() * 2^16
			pkt.udp.dst = math.random() * 2^16
			pkt.ip.src.uint32 = math.random() * 2^32
			pkt.ip.dst.uint32 = math.random() * 2^32
		end
		bufs:offloadIPChecksums()
		totalSent = totalSent + queue:send(bufs)
		local time = dpdk.getTime()
		if time - lastPrint > 1 then
			local mpps = (totalSent - lastTotal) / (time - lastPrint) / 10^6
			printf("%s Sent %d packets, current rate %.2f Mpps, %.2f MBit/s, %.2f MBit/s wire rate", queue, totalSent, mpps, mpps * 64 * 8, mpps * 84 * 8)
			lastTotal = totalSent
			lastPrint = time
		end
	end
	printf("%s Sent %d packets", queue, totalSent)
end

