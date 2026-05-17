local SUPPLY_STASH_ITEM_ID = ITEM_SUPPLY_STASH or 28750

local OPCODE_SUPPLY_STASH_REQUEST = 0x28
local OPCODE_SUPPLY_STASH_SEND = 0x29

local ACTION_OPEN = 1
local ACTION_STOW_ALL = 2
local ACTION_WITHDRAW = 3

local SUPPLY_STASH_MAX_UNIQUE_ITEMS = 1000
local SUPPLY_STASH_MAX_WITHDRAW = 100000
local SUPPLY_STASH_MAX_WITHDRAW_NON_STACKABLE = 100
local SUPPLY_STACK_SIZE = 100
local SUPPLY_STASH_DEPOT_BOX_FIRST = 1
local SUPPLY_STASH_DEPOT_BOX_LAST = 15
local SUPPLY_STASH_DETAILS_MARKER = 0x5353

local CATEGORY_ARMORS = 1
local CATEGORY_AMULETS = 2
local CATEGORY_BOOTS = 3
local CATEGORY_FOOD = 6
local CATEGORY_HELMETS = 7
local CATEGORY_LEGS = 8
local CATEGORY_OTHERS = 9
local CATEGORY_POTIONS = 10
local CATEGORY_RINGS = 11
local CATEGORY_RUNES = 12
local CATEGORY_SHIELDS = 13
local CATEGORY_TOOLS = 14
local CATEGORY_VALUABLES = 15
local CATEGORY_AMMUNITION = 16
local CATEGORY_AXES = 17
local CATEGORY_CLUBS = 18
local CATEGORY_DISTANCE = 19
local CATEGORY_SWORDS = 20
local CATEGORY_WANDS = 21
local CATEGORY_CREATURE_PRODUCTS = 24
local CATEGORY_FISTS = 25

local blockedItems = {}
for _, itemId in ipairs({
	_G.ITEM_GOLD_COIN,
	_G.ITEM_PLATINUM_COIN,
	_G.ITEM_CRYSTAL_COIN,
	_G.ITEM_GOLD_NUGGET,
	ITEM_MARKET,
	SUPPLY_STASH_ITEM_ID,
	ITEM_INBOX,
	ITEM_STORE_INBOX,
	ITEM_DEPOT
}) do
	if itemId then
		blockedItems[itemId] = true
	end
end

local function supportsCustomNetwork(player)
	return player and player.isUsingOtClient and player:isUsingOtClient()
end

local function ensureTables()
	db.query([[
		CREATE TABLE IF NOT EXISTS `player_supplystash` (
			`player_id` INT NOT NULL,
			`itemtype` SMALLINT UNSIGNED NOT NULL,
			`amount` INT UNSIGNED NOT NULL DEFAULT 0,
			PRIMARY KEY (`player_id`, `itemtype`),
			CONSTRAINT `player_supplystash_player_fk`
				FOREIGN KEY (`player_id`) REFERENCES `players` (`id`)
				ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8;
	]])
end

local function getItemType(itemId)
	itemId = tonumber(itemId) or 0
	if itemId <= 0 then
		return nil
	end

	local itemType = ItemType(itemId)
	if not itemType or itemType:getId() == 0 then
		return nil
	end
	return itemType
end

local function getCategoryFromName(name)
	name = (name or ""):lower()
	if name == "" then
		return CATEGORY_OTHERS
	end

	if name:find("sword", 1, true) or name:find("blade", 1, true) or name:find("sabre", 1, true) or name:find("katana", 1, true) then
		return CATEGORY_SWORDS
	elseif name:find("fist", 1, true) or name:find("claw", 1, true) or name:find("knuckle", 1, true) then
		return CATEGORY_FISTS
	elseif name:find("axe", 1, true) or name:find("hatchet", 1, true) then
		return CATEGORY_AXES
	elseif name:find("club", 1, true) or name:find("mace", 1, true) or name:find("hammer", 1, true) then
		return CATEGORY_CLUBS
	elseif name:find("bow", 1, true) or name:find("crossbow", 1, true) or name:find("spear", 1, true) then
		return CATEGORY_DISTANCE
	elseif name:find("wand", 1, true) or name:find("rod", 1, true) then
		return CATEGORY_WANDS
	elseif name:find("arrow", 1, true) or name:find("bolt", 1, true) then
		return CATEGORY_AMMUNITION
	elseif name:find("helmet", 1, true) or name:find("hat", 1, true) then
		return CATEGORY_HELMETS
	elseif name:find("armor", 1, true) or name:find("mail", 1, true) or name:find("plate", 1, true) then
		return CATEGORY_ARMORS
	elseif name:find("legs", 1, true) then
		return CATEGORY_LEGS
	elseif name:find("boots", 1, true) then
		return CATEGORY_BOOTS
	elseif name:find("shield", 1, true) then
		return CATEGORY_SHIELDS
	elseif name:find("amulet", 1, true) or name:find("necklace", 1, true) then
		return CATEGORY_AMULETS
	elseif name:find("potion", 1, true) or name:find("fluid", 1, true) then
		return CATEGORY_POTIONS
	elseif name:find("rune", 1, true) then
		return CATEGORY_RUNES
	elseif name:find("ring", 1, true) then
		return CATEGORY_RINGS
	elseif name:find("food", 1, true) or name:find("ham", 1, true) or name:find("meat", 1, true) or name:find("fish", 1, true) or name:find("bread", 1, true) then
		return CATEGORY_FOOD
	elseif name:find("rope", 1, true) or name:find("shovel", 1, true) or name:find("pick", 1, true) or name:find("machete", 1, true) then
		return CATEGORY_TOOLS
	elseif name:find("gem", 1, true) or name:find("crystal", 1, true) or name:find("pearl", 1, true) then
		return CATEGORY_VALUABLES
	end
	return CATEGORY_OTHERS
end

local function getSupplyItemCategory(itemType)
	local weaponType = itemType:getWeaponType()
	if weaponType == WEAPON_SWORD then
		return CATEGORY_SWORDS
	elseif weaponType == WEAPON_CLUB then
		return CATEGORY_CLUBS
	elseif weaponType == WEAPON_AXE then
		return CATEGORY_AXES
	elseif weaponType == WEAPON_DISTANCE then
		return CATEGORY_DISTANCE
	elseif weaponType == WEAPON_WAND then
		return CATEGORY_WANDS
	elseif weaponType == WEAPON_AMMO then
		return CATEGORY_AMMUNITION
	elseif weaponType == WEAPON_FIST then
		return CATEGORY_FISTS
	elseif weaponType == WEAPON_SHIELD then
		return CATEGORY_SHIELDS
	end

	if itemType:isRune() then
		return CATEGORY_RUNES
	elseif itemType:isHelmet() then
		return CATEGORY_HELMETS
	elseif itemType:isArmor() then
		return CATEGORY_ARMORS
	elseif itemType:isLegs() then
		return CATEGORY_LEGS
	elseif itemType:isBoots() then
		return CATEGORY_BOOTS
	elseif itemType:isNecklace() then
		return CATEGORY_AMULETS
	elseif itemType:isRing() then
		return CATEGORY_RINGS
	elseif itemType:getWorth() > 0 then
		return CATEGORY_VALUABLES
	end

	return getCategoryFromName(itemType:getName())
end

local function isSupplyItem(itemId)
	itemId = tonumber(itemId) or 0
	if itemId <= 0 or itemId > 0xFFFF or blockedItems[itemId] then
		return false
	end

	local itemType = getItemType(itemId)
	if not itemType then
		return false
	end

	local name = itemType:getName()
	if not name or name == "" then
		return false
	end

	if itemType:isCorpse() or itemType:isDoor() or itemType:isContainer() or itemType:isFluidContainer()
		or itemType:isMagicField() or itemType:isGroundTile() then
		return false
	end

	if CustomMarket and CustomMarket.isMarketCatalogItem then
		return CustomMarket.isMarketCatalogItem(itemId)
	end

	return itemType:isMovable() and itemType:isPickupable()
end

local function hasAnyAttribute(item, attributes)
	for _, attribute in ipairs(attributes) do
		if attribute and item:hasAttribute(attribute) then
			return true
		end
	end
	return false
end

local restrictedInstanceAttributes = {
	ITEM_ATTRIBUTE_ACTIONID,
	ITEM_ATTRIBUTE_UNIQUEID,
	ITEM_ATTRIBUTE_DESCRIPTION,
	ITEM_ATTRIBUTE_TEXT,
	ITEM_ATTRIBUTE_DATE,
	ITEM_ATTRIBUTE_WRITER,
	ITEM_ATTRIBUTE_NAME,
	ITEM_ATTRIBUTE_ARTICLE,
	ITEM_ATTRIBUTE_PLURALNAME,
	ITEM_ATTRIBUTE_WEIGHT,
	ITEM_ATTRIBUTE_ATTACK,
	ITEM_ATTRIBUTE_DEFENSE,
	ITEM_ATTRIBUTE_EXTRADEFENSE,
	ITEM_ATTRIBUTE_ARMOR,
	ITEM_ATTRIBUTE_HITCHANCE,
	ITEM_ATTRIBUTE_SHOOTRANGE,
	ITEM_ATTRIBUTE_OWNER,
	ITEM_ATTRIBUTE_CORPSEOWNER,
	ITEM_ATTRIBUTE_FLUIDTYPE,
	ITEM_ATTRIBUTE_DOORID,
	ITEM_ATTRIBUTE_WRAPID,
	ITEM_ATTRIBUTE_STOREITEM,
	ITEM_ATTRIBUTE_ATTACK_SPEED,
	ITEM_ATTRIBUTE_CLASSIFICATION,
	ITEM_ATTRIBUTE_REWARDID
}

local function isPristineSupplyItem(item)
	if not item or item:isContainer() then
		return false
	end

	local itemId = item:getId()
	if blockedItems[itemId] then
		return false
	end

	local itemType = getItemType(itemId)
	if not itemType or not isSupplyItem(itemId) then
		return false
	end

	if item.isStoreItem and item:isStoreItem() then
		return false
	end

	if item.hasImbuements and item:hasImbuements() then
		return false
	end

	if item.getTier and (tonumber(item:getTier()) or 0) > 0 then
		return false
	end

	if hasAnyAttribute(item, restrictedInstanceAttributes) then
		return false
	end

	if item:hasAttribute(ITEM_ATTRIBUTE_DURATION_TIMESTAMP) or item:hasAttribute(ITEM_ATTRIBUTE_DECAYSTATE) then
		return false
	end

	if item:hasAttribute(ITEM_ATTRIBUTE_DURATION) then
		local duration = tonumber(item:getAttribute(ITEM_ATTRIBUTE_DURATION)) or 0
		local maxDuration = math.max(tonumber(itemType:getDurationMin()) or 0, tonumber(itemType:getDurationMax()) or 0)
		if maxDuration <= 0 or duration < maxDuration then
			return false
		end
	end

	if item:hasAttribute(ITEM_ATTRIBUTE_CHARGES) then
		local charges = tonumber(item:getCharges()) or 0
		local maxCharges = tonumber(itemType:getCharges()) or 0
		if maxCharges <= 0 or charges < maxCharges then
			return false
		end
	end

	return true
end

local function getSupplyItemAmount(item)
	local itemType = getItemType(item:getId())
	if itemType and itemType:isStackable() then
		return math.max(1, tonumber(item:getCount()) or 0)
	end
	return 1
end

local function normalizeDepotId(depotId)
	depotId = tonumber(depotId) or 0
	if depotId < 0 then
		return 0
	end
	if depotId > 0xFFFF then
		return 0xFFFF
	end
	return depotId
end

local function getPlayerLastDepotId(player)
	if player.getLastDepotId then
		local ok, depotId = pcall(function()
			return player:getLastDepotId()
		end)
		if ok then
			return normalizeDepotId(depotId)
		end
	end
	return 0
end

local function getDepotBoxes(player)
	local boxes = {}
	local depotId = getPlayerLastDepotId(player)
	for boxIndex = SUPPLY_STASH_DEPOT_BOX_FIRST, SUPPLY_STASH_DEPOT_BOX_LAST do
		local box = player:getDepotBox(depotId, boxIndex)
		if box then
			boxes[#boxes + 1] = box
		end
	end
	return boxes
end

local function getRows(player)
	local rows = {}
	local resultId = db.storeQuery(
		"SELECT `itemtype`, `amount` FROM `player_supplystash` WHERE `player_id` = " ..
		player:getGuid() .. " AND `amount` > 0 ORDER BY `itemtype` ASC"
	)

	if resultId then
		repeat
			local itemId = result.getDataInt(resultId, "itemtype")
			local amount = result.getDataLong and result.getDataLong(resultId, "amount") or result.getDataInt(resultId, "amount")
			if isSupplyItem(itemId) and amount > 0 then
				rows[#rows + 1] = {itemId = itemId, amount = math.min(amount, 0xFFFFFFFF)}
			end
		until not result.next(resultId)
		result.free(resultId)
	end

	return rows
end

local function sendStash(player)
	if not supportsCustomNetwork(player) then
		return false
	end

	local rows = getRows(player)
	local freeSlots = math.max(0, SUPPLY_STASH_MAX_UNIQUE_ITEMS - #rows)

	local msg = NetworkMessage(player)
	msg:addByte(OPCODE_SUPPLY_STASH_SEND)
	msg:addU16(math.min(#rows, 0xFFFF))
	local rowCount = math.min(#rows, 0xFFFF)
	for i = 1, rowCount do
		msg:addU16(rows[i].itemId)
		msg:addU32(rows[i].amount)
	end
	msg:addU16(math.min(freeSlots, 0xFFFF))
	msg:addU16(SUPPLY_STASH_DETAILS_MARKER)
	msg:addU16(rowCount)
	for i = 1, rowCount do
		local itemType = getItemType(rows[i].itemId)
		msg:addU16(rows[i].itemId)
		msg:addString(itemType and itemType:getName() or "")
		msg:addU16(itemType and getSupplyItemCategory(itemType) or CATEGORY_OTHERS)
		msg:addByte(itemType and itemType:isStackable() and 1 or 0)
	end
	return msg:sendToPlayer(player)
end

local function getStoredAmount(player, itemId)
	local amount = 0
	local resultId = db.storeQuery(
		"SELECT `amount` FROM `player_supplystash` WHERE `player_id` = " ..
		player:getGuid() .. " AND `itemtype` = " .. itemId .. " LIMIT 1"
	)
	if resultId then
		amount = result.getDataLong and result.getDataLong(resultId, "amount") or result.getDataInt(resultId, "amount")
		result.free(resultId)
	end
	return amount
end

local function addStoredAmount(player, itemId, amount)
	return db.query(string.format(
		"INSERT INTO `player_supplystash` (`player_id`, `itemtype`, `amount`) VALUES (%d, %d, %d) " ..
		"ON DUPLICATE KEY UPDATE `amount` = `amount` + VALUES(`amount`)",
		player:getGuid(), itemId, amount
	))
end

local function removeStoredAmount(player, itemId, amount)
	return db.query(string.format(
		"UPDATE `player_supplystash` SET `amount` = `amount` - %d WHERE `player_id` = %d AND `itemtype` = %d AND `amount` >= %d",
		amount, player:getGuid(), itemId, amount
	))
end

local function cleanupEmptyRows(player)
	db.query("DELETE FROM `player_supplystash` WHERE `player_id` = " .. player:getGuid() .. " AND `amount` = 0")
end

local function collectSupplyItems(container, list)
	for _, item in ipairs(container:getItems(false)) do
		if item:isContainer() then
			collectSupplyItems(item, list)
		elseif isPristineSupplyItem(item) then
			list[#list + 1] = item
		end
	end
end

local function collectPlayerInventory(player, list)
	for slot = CONST_SLOT_HEAD, CONST_SLOT_AMMO do
		local item = player:getSlotItem(slot)
		if item then
			if item:isContainer() then
				collectSupplyItems(item, list)
			elseif isPristineSupplyItem(item) then
				local itemType = getItemType(item:getId())
				if itemType and itemType:isStackable() then
					list[#list + 1] = item
				end
			end
		end
	end
end

local function collectDepotItems(player, list)
	for _, box in ipairs(getDepotBoxes(player)) do
		collectSupplyItems(box, list)
	end
end

local function canAddUniqueTypes(player, amounts)
	local rows = getRows(player)
	local storedTypes = {}
	for _, row in ipairs(rows) do
		storedTypes[row.itemId] = true
	end

	local newTypes = 0
	for itemId in pairs(amounts) do
		if not storedTypes[itemId] then
			newTypes = newTypes + 1
		end
	end
	return #rows + newTypes <= SUPPLY_STASH_MAX_UNIQUE_ITEMS
end

local function stowAll(player)
	local items = {}
	collectDepotItems(player, items)

	if #items == 0 then
		player:sendCancelMessage("Put stashable items in Depot Locker boxes 1 to 15.")
		sendStash(player)
		return true
	end

	local amounts = {}
	for _, item in ipairs(items) do
		local itemId = item:getId()
		amounts[itemId] = (amounts[itemId] or 0) + getSupplyItemAmount(item)
	end

	if not canAddUniqueTypes(player, amounts) then
		player:sendCancelMessage("Your supply stash does not have enough free slots.")
		sendStash(player)
		return true
	end

	local addedAmounts = {}
	for itemId, amount in pairs(amounts) do
		if not addStoredAmount(player, itemId, amount) then
			for addedItemId, addedAmount in pairs(addedAmounts) do
				removeStoredAmount(player, addedItemId, addedAmount)
			end
			cleanupEmptyRows(player)
			player:sendCancelMessage("Could not store these items in your supply stash.")
			sendStash(player)
			return true
		end
		addedAmounts[itemId] = amount
	end

	local remainingAmounts = {}
	for itemId, amount in pairs(amounts) do
		remainingAmounts[itemId] = amount
	end

	for _, item in ipairs(items) do
		local itemId = item:getId()
		local amount = getSupplyItemAmount(item)
		if not item:remove() then
			for remainingItemId, remainingAmount in pairs(remainingAmounts) do
				if remainingAmount > 0 then
					removeStoredAmount(player, remainingItemId, remainingAmount)
				end
			end
			cleanupEmptyRows(player)
			player:sendCancelMessage("Could not remove one of the items from its source.")
			sendStash(player)
			return true
		end
		remainingAmounts[itemId] = (remainingAmounts[itemId] or 0) - amount
	end

	player:sendTextMessage(MESSAGE_STATUS_SMALL, "Supplies stowed.")
	sendStash(player)
	return true
end

local function canCarry(player, itemType, amount)
	local weight = itemType:getWeight(amount)
	return player:getFreeCapacity() >= weight
end

local function deliverToPlayer(player, itemId, amount)
	local itemType = getItemType(itemId)
	if not itemType then
		return false, "This item does not exist."
	end
	if not canCarry(player, itemType, amount) then
		return false, "You do not have enough capacity."
	end

	local createdItems = {}
	local remaining = amount
	local stackSize = itemType:isStackable() and math.max(1, itemType:getStackSize()) or 1
	while remaining > 0 do
		local count = itemType:isStackable() and math.min(remaining, stackSize, SUPPLY_STACK_SIZE) or 1
		local item = Game.createItem(itemId, count)
		if not item then
			for _, created in ipairs(createdItems) do
				created:remove()
			end
			return false, "Could not create item."
		end

		createdItems[#createdItems + 1] = item
		local ret = player:addItemEx(item, false)
		if ret ~= RETURNVALUE_NOERROR then
			for _, created in ipairs(createdItems) do
				created:remove()
			end
			return false, "You do not have enough room."
		end
		remaining = remaining - count
	end

	return true
end

local function withdraw(player, itemId, amount)
	itemId = tonumber(itemId) or 0
	amount = math.floor(tonumber(amount) or 0)

	if amount <= 0 or amount > SUPPLY_STASH_MAX_WITHDRAW then
		player:sendCancelMessage("Invalid amount.")
		sendStash(player)
		return true
	end
	if not isSupplyItem(itemId) then
		player:sendCancelMessage("This item cannot be withdrawn from the supply stash.")
		sendStash(player)
		return true
	end

	local itemType = getItemType(itemId)
	if itemType and not itemType:isStackable() and amount > SUPPLY_STASH_MAX_WITHDRAW_NON_STACKABLE then
		player:sendCancelMessage("You can withdraw at most 100 of this item at once.")
		sendStash(player)
		return true
	end

	if getStoredAmount(player, itemId) < amount then
		player:sendCancelMessage("You do not have enough items in your supply stash.")
		sendStash(player)
		return true
	end

	local delivered, reason = deliverToPlayer(player, itemId, amount)
	if not delivered then
		player:sendCancelMessage(reason)
		sendStash(player)
		return true
	end

	removeStoredAmount(player, itemId, amount)
	db.query("DELETE FROM `player_supplystash` WHERE `amount` = 0")
	sendStash(player)
	return true
end

local handler = PacketHandler(OPCODE_SUPPLY_STASH_REQUEST)

function handler.onReceive(player, msg)
	ensureTables()

	local action = msg:getByte()
	if not supportsCustomNetwork(player) then
		player:sendCancelMessage("The supply stash is only available on OTClient.")
		return true
	end

	if action == ACTION_OPEN then
		sendStash(player)
	elseif action == ACTION_STOW_ALL then
		stowAll(player)
	elseif action == ACTION_WITHDRAW then
		local itemId = msg:getU16()
		local amount = msg:getU32()
		withdraw(player, itemId, amount)
	else
		player:sendCancelMessage("Invalid supply stash action.")
	end
	return true
end

handler:register()

CustomSupplyStash = {
	open = function(player)
		if not supportsCustomNetwork(player) then
			return false
		end

		ensureTables()
		return sendStash(player)
	end,
	stowAll = stowAll,
	withdraw = withdraw
}

ensureTables()
