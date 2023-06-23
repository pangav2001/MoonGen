local device = require "device"
local moongen = require "moongen"
local memory = require "memory"
local stats  = require "stats"
local timer = require "timer"
local counters = {}
function master(txNum)
	txQueues = 3
	local txDev = device.config{port = txNum,
	rxQueues = 1,
	txQueues = txQueues,
	}
	device.waitForLinks()
	-- local table = {64, 128, 256, 512, 1024, 1518}
	for _, pkt_sz in ipairs({64, 128, 256, 512, 1024, 1518}) do
	-- for _, pkt_sz in ipairs({1518}) do
		print("Packet size: " .. pkt_sz)
		counters = {}
		-- os.execute("sleep " .. tonumber(1))
		for i = 0, txQueues - 1 do
			moongen.startTask("send", txDev:getTxQueue(i), pkt_sz)
		end
		moongen.waitForTasks()
		moongen.sleepMillis(1000)
	end
end

function send(queue, pkt_sz)
	--  queue:setRate(100) -- hardware rate in Mbit/s
	local mem = memory.createMemPool(function(buf)
		buf:getUdp4Packet():fill{
		pktLength = 42,
		ethSrc = "90:E2:BA:F7:30:1D", -- device mac
		-- ethDst = "FF:FF:FF:FF:FF:FF",
		ethDst = "90:e2:ba:f7:32:69",
		-- ethDst = "90:E2:BA:F7:31:CD",
		-- ipSrc will be randomized
		ip4Src = "10.1.0.1",
		ip4Dst = "146.178.131.213",
		-- 146.179.131.222
		udpSrc = 4321,
		udpDst = 1234,
		-- payload = \x00 (mempool initialization)
		}
	end)
	local bufs = mem:bufArray()
	-- local txCtr = stats:newDevTxCounter(queue, "plain")
	local txCtr = counters[queue]
	-- create counters dynamically
	if not txCtr then
		txCtr = stats:newPktTxCounter(queue, "plain")
		counters[queue] = txCtr
	end
	local runtime = timer:new(60)
	-- local runtime = timer:new(120)
	while runtime:running() and moongen.running() do
		bufs:alloc(pkt_sz - 4)
		for _, buf in ipairs(bufs) do
			local pkt = buf:getUdpPacket()
			-- select a randomized source IP address
			-- pkt.ip4.src:set(
			-- 	parseIPAddress("10.0.42.0") + math.random(255))
			-- pkt.ip4.src:set(parseIPAddress("10.1.0.1"))
			txCtr:countPacket(buf)
		end
		bufs:offloadUdpChecksums() -- hardware checksums
		queue:send(bufs)
		txCtr:update()
	end
	txCtr:finalize()
end

