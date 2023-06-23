local moongen = require "moongen"
local memory = require "memory"
local device = require "device"
local stats  = require "stats"
local timer = require "timer"

function master(rxPort)
	rxQueues = 1
	local rxDev = device.config{port = rxPort,
	rxQueues = rxQueues,
	txQueues = 1	
	}
	device.waitForLinks()
	for _, pkt_sz in ipairs({64, 128, 256, 512, 1024, 1518}) do
	-- for _, pkt_sz in ipairs({1518}) do
		print("Packet size: " .. pkt_sz)
		moongen.startTask("receive", rxDev:getRxQueue(0))
		moongen.waitForTasks()
		moongen.sleepMillis(1000)
		-- os.execute("sleep " .. tonumber(2))
	end
end

function receive(queue)
	local bufs = memory.bufArray()
	-- local ctr = stats:newPktRxCounter(queue, "plain")
	local started = false
	local runtime = timer:new(120)
	while runtime:running() and moongen.running() do
		local rx = queue:recv(bufs)
		for i = 1, rx do
			-- local pkt = bufs[i]:getUdp4Packet()
			local buf = bufs[i]
			local srcIp = buf:getUdp4Packet().ip4:getSrc()
			local dstPort = buf:getUdp4Packet().udp:getDstPort()
			if not started and dstPort == 1234 then
				runtime:reset(60)
				-- runtime:reset(120)
				ctr = stats:newPktRxCounter(queue, "plain")
				started = true
			end
			if srcIp == 167837697 then
				ctr:countPacket(buf)
			end
		end
		if started then
			ctr:update()
		end
		bufs:free(rx)
	end
	if started then
		ctr:finalize()
	end
end
