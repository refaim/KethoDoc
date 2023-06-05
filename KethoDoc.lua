---@type table<string, any>
local _G = getfenv(0)

--TODO refactor addon: move UI to main lua file, move getters to some utility files

KethoDoc = {}

---@return string[]
local function get_global_namespace_functions()
	---@type string[]
	local lua_modules = { 'builtin', 'coroutine', 'debug', 'global', 'io', 'math', 'os', 'string', 'table' }
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
					tinsert(functions, format('%s.%s', global_name, name_in_module))
				end
			end
		end
	end
	return functions
end

---@return table<string, string>
local function get_global_frames()
	---@type table<string, string>
	local name_to_type = {}
	for name, value in pairs(_G) do
		if type(value) == 'table' and value.GetParent ~= nil then
			local parent = value:GetParent()
			if parent == nil or parent == UIParent or parent == WorldFrame then
				name_to_type[name] = value:GetObjectType()
			end
		end
	end
	return name_to_type
end

local function get_global_constants()
	---@type table<string, boolean|number|string>
	local name_to_value = {}

	---@type table<string, boolean>
	local const_types_set = { ['boolean'] = true, ['number'] = true, ['string'] = true }

	--TODO move to global vars dumper, calculate diff between two sets
	---@type table<string, boolean>
	local vars_to_exclude = {
		['BUFF_ALPHA_VALUE'] = true,
		['CURSOR_OLD_X'] = true,
		['CURSOR_OLD_Y'] = true,
		['_'] = true,
	}

	for name, value in pairs(_G) do
		local type_matches = const_types_set[type(value)] ~= nil
		local name_matches = strfind(name, '^[%u%d_]+$') or strfind(name, '^VOICEMACRO')
		if type_matches and name_matches and vars_to_exclude[name] == nil then
			--TODO return value AND type
			name_to_value[name] = value
		end
	end
	return name_to_value
end

-----@param t table
--local function getassocn(t)
--	local n = 0
--	for k, v in pairs(t) do
--		n = n + 1
--	end
--	return n
--end

local function get_widget_api()
	--TODO zalepa
	local function print(v)
		DEFAULT_CHAT_FRAME:AddMessage(tostring(v))
	end

	---@type table<string, any>
	local widget_class_to_instance = {
		['Font'] = CreateFont(),
		['FontString'] = CreateFrame('Frame'):CreateFontString(),
		['Texture'] = CreateFrame('Frame'):CreateTexture(),
	}
	-- TODO use multiple simple const data arrays or one complex const data array for widget stuff?
	for _, widget_class in ipairs(KETHO_DOC_FRAME_WIDGET_CLASSES) do
		widget_class_to_instance[widget_class] = CreateFrame(widget_class, 'KethoWidget' .. widget_class)
	end

	---@shape WidgetInfo
	---@field class string
	---@field methods string[]
	---@field script_types string[]

	---@shape WidgetMetaTable
	---@field __index fun(t, field):any

	local used_script_types_set = Set:new()
	local used_framexml_methods_set = Set:new()

	---@type table<string, WidgetInfo>
	local widget_class_to_info = {}
	for widget_class, widget in pairs(widget_class_to_instance) do
		local methods = {}
		---@type WidgetMetaTable
		local metatable = getmetatable(widget)
		for _, method_name in ipairs(KETHO_DOC_FRAMEXML_METHODS) do
			local field = metatable.__index(widget, method_name)
			if type(field) == 'function' then
				tinsert(methods, method_name)
			elseif field ~= nil then
				-- TODO temporary branch
				print(format('%s: %s', method_name, type(field)))
			end
		end

		--TODO zalepa
		print(getn(methods))

		---@type string[]
		local script_types = {}
		for _, script_type in ipairs(KETHO_DOC_SCRIPT_TYPES) do
			if widget:HasScript(script_type) then
				tinsert(script_types, script_type)
			end
		end

		widget_class_to_info[widget_class] = {
			['class'] = widget_class,
			['methods'] = methods,
			['script_types'] = script_types,
		}
	end

	-- TODO check that each class has all methods from parent classes
	-- TODO remove parent methods from widgets

	-- TODO compose list of not used methods
	-- TODO compose list of not used script types

	return {}

	--if not self.WidgetClasses then
	--	self:SetupWidgets()
	--end
	--eb:Show()
	--eb:InsertLine("local WidgetAPI = {")
	--for _, objectName in pairs(self.WidgetOrder) do
	--	local object = self.WidgetClasses[objectName]
	--	if object.meta_object then -- sanity check for Classic
	--		eb:InsertLine("\t"..objectName.." = {")
	--		local inheritsTable = {}
	--		for _, v in pairs(object.inherits) do
	--			tinsert(inheritsTable, format('"%s"', v)) -- stringify
	--		end
	--		eb:InsertLine(format("\t\tinherits = {%s},", table.concat(inheritsTable, ", ")))
	--
	--		if object.unique_handlers then
	--			local handlers = self:SortTable(object.unique_handlers(), "key")
	--			if next(handlers) then
	--				eb:InsertLine("\t\thandlers = {")
	--				for _, tbl in pairs(handlers) do
	--					eb:InsertLine('\t\t\t"'..tbl.key..'",')
	--				end
	--				eb:InsertLine("\t\t},")
	--			end
	--		end
	--		if object.unique_methods and not object.mixin then
	--			eb:InsertLine("\t\tmethods = {")
	--			local methods = self:SortTable(object.unique_methods(), "key")
	--			for _, tbl in pairs(methods) do
	--				eb:InsertLine('\t\t\t"'..tbl.key..'",')
	--			end
	--			eb:InsertLine("\t\t},")
	--		end
	--		if object.intrinsic then
	--			eb:InsertLine(format('\t\tmixin = "%s",', object.mixin))
	--			eb:InsertLine("\t\tintrinsic = true,")
	--		end
	--		eb:InsertLine("\t},")
	--	end
	--end
	--eb:InsertLine("}\n\nreturn WidgetAPI")
end

---@param t table
---@return boolean
local function is_linear(t)
	return t[1] ~= nil
end

---@param data any
---@return string
local function convert_to_text(data)
	---@type string[]
	local strings = {}

	if type(data) == 'string' then
		tinsert(strings, --[[---@type string]] data)
	elseif type(data) == 'table' then
		if is_linear(data) then
			strings = data
		else
			for k, v in pairs(data) do
				tinsert(strings, format('%s=%s', k, gsub(tostring(v), '\n', '\\n')))
			end
		end
	end

	---@type string[]
	local filtered_strings = {}
	for _, s in ipairs(strings) do
		if not strfind(s, 'KETHO') and not strfind(s, 'Ketho') then
			tinsert(filtered_strings, s)
		end
	end
	sort(filtered_strings)

	return table.concat(filtered_strings, '\n')
end

SLASH_KETHODOC1 = '/kd'
SlashCmdList['KETHODOC'] = function()
	---@param get fun():string
	local function make_callback(get)
		return (function() return convert_to_text(get()) end)
	end

	---@type Action[]
	local actions = {
		{'Dump Global Functions', make_callback(get_global_namespace_functions)},
		{'Dump Global Frames', make_callback(get_global_frames)},
		{'Dump Other Global Vars'}, --TODO probably smth like (_G - funcs - consts - lua_modules)
		{'Dump Global Constants', make_callback(get_global_constants)},
		{'Dump Widget API', make_callback(get_widget_api)},
		{'Dump Everything'},
	}
	KethoWindow:Create(actions)
	KethoWindow:Show()
end
