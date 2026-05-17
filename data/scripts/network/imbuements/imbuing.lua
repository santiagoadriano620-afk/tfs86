local apply = PacketHandler(0xD5)

function apply.onReceive(player, msg)
	local slot = msg:getByte()
	local imbuementId = msg:getU32()
	local protection = msg:getByte() ~= 0
	ImbuingWindow.apply(player, slot, imbuementId, protection)
end

apply:register()

local clear = PacketHandler(0xD6)

function clear.onReceive(player, msg)
	ImbuingWindow.clear(player, msg:getByte())
end

clear:register()

local close = PacketHandler(0xD7)

function close.onReceive(player, msg)
	ImbuingWindow.close(player)
end

close:register()
