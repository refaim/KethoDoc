---@type table<string, any>
local _G = getfenv(0)

--TODO refactor adoon: move UI to main lua file, move getters to some utility files

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

-- for auto marking globals in vscode extension
function KethoDoc:DumpGlobals()
	KethoDocData = {}
	for k in pairs(_G) do
		if type(k) == "string" and not string.find(k, "Ketho") and not string.find(k, "table: ") then
			KethoDocData[k] = true
		end
	end
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
		{'Dump Widget API'},
		{'Test Widgets'},
		{'Dump Everything'},
	}
	KethoWindow:Create(actions)
	KethoWindow:Show()
end
