local component = require("component")
local internet = component.internet
local export, import = component.proxy("d8465ded-416c-489e-be3b-4e0d2a5a6804"), component.proxy("93caa913-9f38-4e30-a8c9-882256427897")
local importSide = "SOUTH"
local items, oldSlot

if not export then
	error("Need export!")
end
if not import then
	error("Need import")
end

local function request(path)
    local handle, data, chunk = internet.request(path), ""

    while true do
        chunk = handle.read(math.huge)

        if chunk then
            data = data .. chunk
        else
            break
        end
    end
     
    handle.close()
    return data
end

local function getAllItemCount(fingerprints, needed, cmp)
    local allCount, availableItems = 0, {}

    for i = 1, #fingerprints do
        local checkItem = cmp.getItemDetail(fingerprints[i])

        if checkItem then
        	local count = checkItem.basic().qty

            if needed and (count >= needed) then
                table.insert(availableItems, {fingerprint = fingerprints[i], count = needed})
                allCount = needed
                break
            end

            if needed and (count + allCount > needed) then
                table.insert(availableItems, {fingerprint = fingerprints[i], count = count - allCount})
                allCount = allCount + (count - allCount)
                break
            else
                table.insert(availableItems, {fingerprint = fingerprints[i], count = count})
                allCount = allCount + count
            end
        end
    end

    return allCount, availableItems
end

local function insert(fingerprint, count)
    local checkItem = export.getItemDetail(fingerprint)

    if checkItem then
        local item = checkItem.basic()

        if item.qty >= count then
            if count > item.max_size then
                for stack = 1, math.ceil(count / item.max_size) do
                    local stack = count > item.max_size
                    repeat
                        success = export.exportItem(fingerprint, importSide, stack and item.max_size or count, 1)
                    until success.size >= 1
                    count = stack and count - item.max_size or count
                end
            else
            	local success

            	repeat
            		success = export.exportItem(fingerprint, importSide, count, 1)
            	until success.size >= 1
            end
        end
    end
end

items = load("return " .. request("https://raw.githubusercontent.com/BrightYC/RipMarket/master/items.lua"))()

while true do 
    for item = 1, #items.market do 
    	if items.market[item].needed and import.getItemDetail({dmg=0.0,id="minecraft:wooden_hoe"}) then
    		print("Scanning " .. items.market[item].text .. "...")
    		local importCount = getAllItemCount(items.market[item].fingerprint, false, import)

    		if importCount < items.market[item].needed then
    			local needed = items.market[item].needed - importCount
    			local exportCount, fingerprints = getAllItemCount(items.market[item].fingerprint, needed, export)

    			if items.market[item].buffer and needed < items.market[item].buffer or not items.market[item].buffer then
    				print("Need item (import - " .. needed .. ") - index " .. items.market[item].text .. ", exporting...")

    				for i = 1, #fingerprints do 
    					pcall(insert, fingerprints[i].fingerprint, fingerprints[i].count)
    				end
    			else
    				print("Need item (export) - index " .. items.market[item].text .. "...")
    			end
    		end
    	end
    	os.sleep(0)
    end
end
