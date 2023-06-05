-- Author: Evandro Leopoldino Gonçalves (https://github.com/EvandroLG)
-- Copied from https://github.com/EvandroLG/set-lua and slightly modified by Roman Kharitonov (rkharito@yandex.ru)
-- License: MIT (see LICENSE file)

local function to_array(hash)
    local output = {}
    for key in pairs(hash) do
        table.insert(output, key)
    end
    return output
end

---
--- Set lets you store unique values of any type
---@shape Set<T>
---@field items table<T, boolean> items presented in set
---@field size number current length
Set = {}

---
---@param list? T[]
---@return Set<T>
function Set:new(list)
    ---@type table<T, boolean>
    local items = {}
    local size = 0
    for _, value in ipairs(list or {}) do
        items[value] = true
        size = size + 1
    end

    local set = {}
    setmetatable(set, self)
    set.items = items
    set.size = size
    return --[[---@type Set<T>]] set
end

---
--- Appends value to the Set object
---@param value T
---@return void
function Set:insert(value)
    if not self.items[value] then
        self.items[value] = true
        self.size = self.size + 1
    end
end

---
--- Checks if value is present in the Set object or not
---@param value T
---@return boolean
function Set:has(value)
    return self.items[value] == true
end

---
--- Removes all items from the Set object
---@return void
function Set:clear()
    self.items = {}
    self.size = 0
end

---
--- Removes item from the Set object and returns a boolean value asserting wheater item was removed or not
---@param value T
---@return boolean
function Set:delete(value)
    if self.items[value] ~= nil then
        self.items[value] = nil
        self.size = self.size - 1
        return true
    end

    return false
end

---
--- Calls function once for each item present in the Set object without preserve insertion order
---@param callback fun(value:T):void
---@return void
function Set:each(callback)
    for key in pairs(self.items) do
        callback(key)
    end
end

---
--- Returns true whether all items pass the test provided by the callback function
---@param callback fun(value:T):boolean
---@return boolean
function Set:every(callback)
    for key in pairs(self.items) do
        if not callback(key) then
            return false
        end
    end

    return true
end

---
--- Returns a new Set that contains all items from the original Set and all items from the specified Sets
---@param others Set<T>[]
---@return Set<T>
function Set:union(others)
    local result = Set:new(to_array(self.items))

    for _, set in ipairs(others) do
        set:each(function(value)
            result:insert(value)
        end)
    end

    return result
end

---
--- Returns a new Set that contains all elements that are common in all Sets
---@param others Set<T>[]
---@return Set<T>
function Set:intersection(others)
    local result = Set:new()

    self:each(function(value)
        local is_common = true

        for _, set in ipairs(others) do
            if not set:has(value) then
                is_common = false
                break
            end
        end

        if is_common then
            result:insert(value)
        end
    end)

    return result
end

---
--- Returns a new Set that contains the items that only exist in the original Set
---@param others Set<T>[]
---@return Set<T>
function Set:difference(others)
    local result = Set:new()

    self:each(function(value)
        local is_common = false

        for _, set in ipairs(others) do
            if set:has(value) then
                is_common = true
                break
            end
        end

        if not is_common then
            result:insert(value)
        end
    end)

    return result
end

---
--- Returns a symmetric difference of two Sets
---@param other Set<T>
---@return Set<T>
function Set:symmetric_difference(other)
    local difference = Set:new(to_array(self.items))

    other:each(function(value)
        if difference:has(value) then
            difference:delete(value)
        else
            difference:insert(value)
        end
    end)

    return difference
end

---
--- Returns true if set has all items present in the subset
---@param subset Set<T>
---@return boolean
function Set:is_superset(subset)
    return self:every(function(value)
        return subset:has(value)
    end)
end
