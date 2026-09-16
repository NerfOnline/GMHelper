--[[
* GM Helper Presets tab — hardcoded built-in scripts (not saved).
]]

require('common');

local imgui = require('imgui');
local kit = require('libs.ui.kit');
local listload = require('libs.listload');
local widgets = require('libs.widgets');

local M = {};

-- Hardcoded built-ins only. Nothing here is written to settings.
M.BUILTIN = T{
};

function M.preset_search(state)
    if (state.presetSearch == nil) then
        state.presetSearch = T{ '' };
    end
    return state.presetSearch;
end

function M.draw_presets_page(state, cfg, save)
    local queryBuf = M.preset_search(state);
    local query = kit.trim_query(queryBuf[1]);
    local items = M.BUILTIN;
    local token = table.concat({
        'preset',
        query,
        tostring(#items),
        tostring(state.presetListEpoch or 0),
    }, '|');
    local cache = listload.cache(state, 'presets', token, #items);
    listload.pump(cache, function(index)
        local item = items[index];
        if (item == nil) then
            return;
        end
        local label = tostring(item.name or item.id or 'Preset');
        if (query == '' or label:lower():find(query, 1, true) ~= nil) then
            cache.rows[#cache.rows + 1] = { item = item, slot = index };
        end
    end);
    kit.draw_list_loading(cache);

    if (#items == 0 and cache.ready) then
        widgets.empty_state('Built-in presets will appear here.');
        return;
    end
    if (#cache.rows == 0 and cache.ready) then
        widgets.empty_state('No presets match.');
        return;
    end
    local numW = kit.line_num_width(#items);
    local startX = imgui.GetCursorPosX();
    for index, row in ipairs(cache.rows) do
        local item = row.item;
        local label = item.name or item.id or 'Preset';
        local y = imgui.GetCursorPosY();
        kit.draw_line_num(row.slot, numW, startX, y);
        imgui.SetCursorPos({ startX + numW, y });
        imgui.Text(tostring(label));
        if (index < #cache.rows) then
            imgui.Separator();
        end
    end
end

function M.run_line(cfg, line, save, state)
    local index = math.floor(tonumber(line) or 0);
    local item = M.BUILTIN[index];
    if (item == nil) then
        return false, 'Preset not found.';
    end
    local lines = item.lines or item.commands;
    if (type(lines) ~= 'table' or #lines == 0) then
        return false, 'Preset has no commands yet.';
    end
    local say = require('libs.say');
    for _, step in ipairs(lines) do
        local payload = tostring(step or '');
        if (payload ~= '') then
            if (payload:sub(1, 1) ~= '!') then
                payload = '!' .. payload;
            end
            local ok, err = say.send(payload);
            if (not ok) then
                return false, err or 'Could not send.';
            end
            if (save ~= nil and state ~= nil) then
                require('libs.ui.history').push_history(cfg, payload, save, state);
            end
        end
    end
    return true;
end

return M;
