---@type table<string, any>
local _G = getfenv(0)

KethoDoc = {}

---@return string[]
local function getGlobalNamespaceFunctions()
	---@type string[]
	local lua_modules = {'builtin', 'coroutine', 'debug', 'global', 'io', 'math', 'os', 'string', 'table'}
	---@type table<string, boolean>
	local lua_modules_by_name = {}
	for _, name in ipairs(lua_modules) do
		lua_modules_by_name[name] = true
	end

	local functions = {}
	for global_name, global_value in pairs(_G) do
		if type(global_value) == 'function' then
			tinsert(functions, global_name)
		elseif type(global_value) == 'table' and lua_modules_by_name[global_name] ~= nil then
			for name_in_module, value_in_module in pairs(global_value) do
				if type(value_in_module) == 'function' then
					tinsert(functions, global_name .. '.' .. name_in_module)
				end
			end
		end
	end
	return functions
end

---@return table<string, string>
local function getGlobalFrames()
	---@type table<string, string>
	local name_to_type = {}
	for k, v in pairs(_G) do
		if type(v) == 'table' and v.GetParent ~= nil and strfind(k, '^Ketho') == nil then
			local parent = v:GetParent()
			if parent == nil or parent == UIParent or parent == WorldFrame then
				name_to_type[k] = v:GetObjectType()
			end
		end
	end
	return name_to_type
end

function KethoDoc:DumpWidgetAPI()
	if not self.WidgetClasses then
		self:SetupWidgets()
	end
	eb:Show()
	eb:InsertLine("local WidgetAPI = {")
	for _, objectName in pairs(self.WidgetOrder) do
		local object = self.WidgetClasses[objectName]
		if object.meta_object then -- sanity check for Classic
			eb:InsertLine("\t"..objectName.." = {")
			local inheritsTable = {}
			for _, v in pairs(object.inherits) do
				tinsert(inheritsTable, format('"%s"', v)) -- stringify
			end
			eb:InsertLine(format("\t\tinherits = {%s},", table.concat(inheritsTable, ", ")))

			if object.unique_handlers then
				local handlers = self:SortTable(object.unique_handlers(), "key")
				if next(handlers) then
					eb:InsertLine("\t\thandlers = {")
					for _, tbl in pairs(handlers) do
						eb:InsertLine('\t\t\t"'..tbl.key..'",')
					end
					eb:InsertLine("\t\t},")
				end
			end
			if object.unique_methods and not object.mixin then
				eb:InsertLine("\t\tmethods = {")
				local methods = self:SortTable(object.unique_methods(), "key")
				for _, tbl in pairs(methods) do
					eb:InsertLine('\t\t\t"'..tbl.key..'",')
				end
				eb:InsertLine("\t\t},")
			end
			if object.intrinsic then
				eb:InsertLine(format('\t\tmixin = "%s",', object.mixin))
				eb:InsertLine("\t\tintrinsic = true,")
			end
			eb:InsertLine("\t},")
		end
	end
	eb:InsertLine("}\n\nreturn WidgetAPI")
end

function KethoDoc:DumpEvents()
	APIDocumentation_LoadUI()
	eb:Show()
	eb:InsertLine("local Events = {")
	sort(APIDocumentation.systems, function(a, b)
		return (a.Namespace or a.Name) < (b.Namespace or b.Name)
	end)
	for _, system in pairs(APIDocumentation.systems) do
		if getn(system.Events) > 0 then -- skip systems with no events
			eb:InsertLine("\t"..(system.Namespace or system.Name).." = {")
			for _, event in pairs(system.Events) do
				eb:InsertLine(format('\t\t"%s",', event.LiteralName))
			end
			eb:InsertLine("\t},")
		end
	end
	eb:InsertLine("}\n\nreturn Events")
end

function KethoDoc:DumpCVars()
	local cvarTbl, commandTbl = {}, {}
	local test_cvarTbl, test_commandTbl = {}, {}
	local cvarFs = '\t\t["%s"] = {"%s", %d, %s, %s, "%s"},'
	local commandFs = '\t\t["%s"] = {%d, "%s"},'

	for _, v in pairs(C_Console.GetAllCommands()) do
		if v.commandType == Enum.ConsoleCommandType.Cvar then
			-- these just keep switching between false/nil
			if not string.find(v.command, "^CACHE") and v.command ~= "KethoDoc" then
				local _, defaultValue, server, character = GetCVarInfo(v.command)
				-- every time they change the category they seem to lose the help text
				local cvarCache = self.cvar_cache.var[v.command]
				if cvarCache then
					-- the category resets back to 5 seemingly randomly
					if v.category == 5 then
						v.category = cvarCache[2]
					end
				end
				local helpString = ""
				if v.help and getn(v.help) > 0 then
					helpString = v.help
				elseif cvarCache and cvarCache[5] then
					helpString = cvarCache[5]
				end
				helpString = helpString:gsub('"', '\\"')
				local tbl = self.cvar_test[v.command] and test_cvarTbl or cvarTbl
				tinsert(tbl, cvarFs:format(v.command, defaultValue or "", v.category, tostring(server), tostring(character), helpString))
			end
		elseif v.commandType == Enum.ConsoleCommandType.Command then
			local tbl = self.cvar_test[v.command] and test_commandTbl or commandTbl
			local helpString = v.help and getn(v.help > 0) and v.help:gsub('"', '\\"') or ""
			tinsert(tbl, commandFs:format(v.command, v.category, helpString))
		end
	end
	for _, tbl in pairs({cvarTbl, commandTbl, test_cvarTbl, test_commandTbl}) do
		sort(tbl, self.SortCaseInsensitive)
	end
	eb:Show()
	eb:InsertLine("local CVars = {")
	eb:InsertLine("\tvar = {")
	eb:InsertLine("\t\t-- var = default, category, account, character, help")
	for _, cvar in pairs(cvarTbl) do
		eb:InsertLine(cvar)
	end
	eb:InsertLine("\t},")

	eb:InsertLine("\tcommand = {")
	eb:InsertLine("\t\t-- command = category, help")
	for _, command in pairs(commandTbl) do
		eb:InsertLine(command)
	end
	eb:InsertLine("\t},\n}\n")

	if getn(test_cvarTbl) > 0 then
		eb:InsertLine("local PTR = {")
		eb:InsertLine("\tvar = {")
		for _, cvar in pairs(test_cvarTbl) do
			eb:InsertLine(cvar)
		end
		eb:InsertLine("\t},")
		eb:InsertLine("\tcommand = {")
		for _, command in pairs(test_commandTbl) do
			eb:InsertLine(command)
		end
		eb:InsertLine("\t},\n}")
	else
		eb:InsertLine("local PTR = {}")
	end

	eb:InsertLine("\nreturn {CVars, PTR}")
end

local EnumTypo = { -- ACCOUNT -> ACCCOUNT (3 Cs)
	LE_FRAME_TUTORIAL_ACCOUNT_CLUB_FINDER_NEW_COMMUNITY_JOINED = "LE_FRAME_TUTORIAL_ACCCOUNT_CLUB_FINDER_NEW_COMMUNITY_JOINED",
}

local function SortEnum(a, b)
	if a.value ~= b.value then
		return a.value < b.value
	else
		return a.name < b.name
	end
end

-- pretty dumb way without even using bitwise op
local function IsBitEnum(tbl, name)
	local t = tInvert(tbl)
	if name == "Damageclass" then
		return true
	end
	for i = 1, 3 do
		if not t[2^i] then
			return false
		end
	end
	if t[3] or t[5] or t[7] then
		return false
	end
	return true
end

-- kind of messy; need to refactor this
function KethoDoc:DumpLuaEnums(showGameErr)
	self.EnumGroups = {}
	for _, v in pairs(self.EnumGroupsIndexed) do
		self.EnumGroups[v[1]] = v[2]
	end
	-- Enum table
	eb:Show()
	eb:InsertLine("Enum = {")
	local enums = {}
	for name in pairs(Enum) do
		if not string.find(name, "Meta$") then
			tinsert(enums, name)
		end
	end
	sort(enums)

	for _, name in pairs(enums) do
		local TableEnum = {}
		eb:InsertLine("\t"..name.." = {")
		for enumType, enumValue in pairs(Enum[name]) do
			tinsert(TableEnum, {name = enumType, value = enumValue})
		end
		sort(TableEnum, SortEnum)
		local numberFormat = IsBitEnum(Enum[name], name) and "0x%X" or "%u"
		for _, enum in pairs(TableEnum) do
			if type(enum.value) == "string" then -- 64 bit enum
				numberFormat = '"%s"'
			elseif enum.value < 0 then
				numberFormat = "%d"
			end
			eb:InsertLine(format("\t\t%s = %s,", enum.name, format(numberFormat, enum.value)))
		end
		eb:InsertLine("\t},")
	end
	eb:InsertLine("}")
	self:DumpConstants()

	-- check if a NUM_LE still exists
	-- for _, NUM_LE in pairs(self.EnumGroups) do
	-- 	if type(NUM_LE) == "string" and not _G[NUM_LE] then
	-- 		print("Removed: ", NUM_LE)
	-- 	end
	-- end
	local EnumGroup, EnumGroupSorted = {}, {}
	local EnumUngrouped = {}
	-- LE_* globals
	for enumType, enumValue in pairs(_G) do
		if type(enumType) == "string" and string.find(enumType, "^LE_") and (showGameErr or not string.find(enumType, "GAME_ERR")) then
			-- group enums together
			local found
			for _, group in pairs(self.EnumGroupsIndexed) do
				local enumType2 = EnumTypo[enumType] or enumType -- hack
				if string.find(enumType2, "^"..group[1]) then
					EnumGroup[group[1]] = EnumGroup[group[1]] or {}
					tinsert(EnumGroup[group[1]], {name = enumType, value = enumValue})
					found = true
					break
				end
			end
			if not found then
				tinsert(EnumUngrouped, {name = enumType, value = enumValue})
			end
		end
	end
	-- sort groups by name
	for groupName in pairs(EnumGroup) do
		tinsert(EnumGroupSorted, groupName)
	end
	sort(EnumGroupSorted)
	-- sort values in groups
	for _, group in pairs(EnumGroup) do
		sort(group, SortEnum)
	end
	-- print group enums
	for _, group in pairs(EnumGroupSorted) do
		eb:InsertLine("")
		local numEnum = self.EnumGroups[group]
		local groupEnum = _G[numEnum]
		if groupEnum then
			eb:InsertLine(format("%s = %d", numEnum, groupEnum))
		end
		for _, tbl in pairs(EnumGroup[group]) do
			eb:InsertLine(format("%s = %d", tbl.name, tbl.value))
		end
	end
	-- print any NUM_LE_* globals not belonging to a group
	local NumLuaEnum, NumEnumCache = {}, {}
	for enum, value in pairs(_G) do
		if type(enum) == "string" and string.find(enum, "^NUM_LE_") then
			NumLuaEnum[enum] = value
		end
	end
	for _, numEnum in pairs(self.EnumGroups) do
		NumEnumCache[numEnum] = true
	end
	for numEnum in pairs(NumLuaEnum) do
		if not NumEnumCache[numEnum] then
			eb:InsertLine(format("%s = %d", numEnum, _G[numEnum]))
		end
	end
	-- not yet categorized enums
	if getn(EnumUngrouped) > 0 then
		eb:InsertLine("\n-- to be categorized")
		sort(EnumUngrouped, SortEnum)
		for _, enum in pairs(EnumUngrouped) do
			eb:InsertLine(format("%s = %d", enum.name, enum.value))
		end
	end
end

function KethoDoc:DumpConstants()
	if Constants then
		eb:InsertLine("\nConstants = {")
		for _, t1 in pairs(self:SortTable(Constants, "key")) do
			eb:InsertLine(format("\t%s = {", t1.key))
			for _, t2 in pairs(self:SortTable(t1.value, "value")) do
				eb:InsertLine(format("\t\t%s = %s,", t2.key, t2.value))
			end
			eb:InsertLine("\t},")
		end
		eb:InsertLine("}")
	end
end

function KethoDoc:GetFrameXML()
	local _, t = self:GetAPI()
	for namespace, v in pairs(_G) do
		if type(namespace) == "string" and type(v) == "table" and string.find(namespace, "Util$") then
			for funcname, v2 in pairs(v) do
				if type(v2) == "function" then
					local name = format("%s.%s", namespace, funcname)
					t[name] = true
				end
			end
		end
	end
	return t
end

function KethoDoc:DumpFrameXML()
	self:DumpLodTable("FrameXML", self:GetFrameXML())
end

function KethoDoc:DumpLodTable(label, tbl)
	eb:Show()
	eb:InsertLine(format("local %s = {", label))
	for _, tbl in pairs(self:SortTable(tbl, "key")) do
		eb:InsertLine(format('\t"%s",', tbl.key))
	end
end

-- TODO
-- for auto marking globals in vscode extension
function KethoDoc:DumpGlobals()
	KethoDocData = {}
	for k in pairs(_G) do
		if type(k) == "string" and not string.find(k, "Ketho") and not string.find(k, "table: ") then
			KethoDocData[k] = true
		end
	end
end

SLASH_KETHODOC1 = '/kd'
SlashCmdList['KETHODOC'] = function()
	---@type Action[]
	local actions = {
		{'Dump Global Functions', getGlobalNamespaceFunctions},
		{'Dump Global Frames', getGlobalFrames},
		{'Dump Widget API'},
		{'Dump Events API'},
		{'Dump CVars API'},
		{'Dump Lua Enums'},
		{'Dump Frame XML'},
		{'Test Widgets'},
		{'Dump Everything'},
	}
	KethoWindow:Create(actions)
	KethoWindow:Show()
end
