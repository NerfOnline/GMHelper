--[[
* GM Helper Presets tab — hardcoded built-in command sequences with delay.
]]

require('common');

local imgui = require('imgui');
local kit = require('libs.ui.kit');
local listload = require('libs.listload');
local lookup = require('libs.lookup');
local theme = require('libs.theme');
local widgets = require('libs.widgets');

local M = {};

-- Hardcoded built-ins only. Nothing here is written to settings.
M.BUILTIN = T{
    T{
        id = 'judges-armor',
        name = "Judge's Armor Set",
        commands = T{
            '!additem 16622',
            '!additem 17644',
            '!additem 12332',
            '!additem 17174',
            '!additem 17326 99',
            '!additem 17326',
            '!additem 19325',
            '!additem 17004',
            '!additem 17406',
            '!additem 12523',
            '!additem 13074',
            '!additem 13358 2',
            '!additem 12551',
            '!additem 12679',
            '!additem 13505 2',
            '!additem 13606',
            '!additem 13215',
            '!additem 12807',
            '!additem 12935',
        },
    },
};

function M.find(id)
    if (id == nil or id == '') then
        return nil;
    end
    for _, item in ipairs(M.BUILTIN) do
        if (item.id == id) then
            return item;
        end
    end
    return nil;
end

function M.preset_search(state)
    if (state.presetSearch == nil) then
        state.presetSearch = T{ '' };
    end
    return state.presetSearch;
end

function M.command_delay(cfg)
    local delay = tonumber(cfg and cfg.commandDelay) or 1.5;
    if (delay < 0.5) then
        delay = 0.5;
    elseif (delay > 5) then
        delay = 5;
    end
    return delay;
end

local function normalize_payload(step)
    local payload = tostring(step or '');
    if (payload == '') then
        return '';
    end
    if (payload:sub(1, 1) ~= '!') then
        payload = '!' .. payload;
    end
    return payload;
end

local function parse_additem(step)
    local payload = normalize_payload(step);
    local id, qty = payload:match('^!additem%s+(%d+)%s*(%d*)');
    if (id == nil) then
        return nil, nil;
    end
    local amount = tonumber(qty);
    if (amount == nil or amount < 1) then
        amount = 1;
    end
    return tonumber(id), amount;
end

local function title_item_name(raw)
    local name = tostring(raw or '');
    local lower = name:lower();
    if (lower:sub(1, 7) == 'judges ') then
        local rest = name:sub(8);
        rest = rest:gsub('(%a)([%w_\']*)', function(first, restChars)
            return first:upper() .. restChars:lower();
        end);
        return "Judge's " .. rest;
    end
    return (name:gsub('(%a)([%w_\']*)', function(first, restChars)
        return first:upper() .. restChars:lower();
    end));
end

local function item_name_by_id(itemId)
    lookup.ensure('items');
    lookup.focus({ 'items' });
    if (not lookup.ready('items')) then
        return nil;
    end
    if (M._itemById == nil or M._itemByIdCount ~= #lookup.rows('items')) then
        M._itemById = {};
        local rows = lookup.rows('items');
        M._itemByIdCount = #rows;
        for _, row in ipairs(rows) do
            if (row.id ~= nil) then
                M._itemById[row.id] = row.name;
            end
        end
    end
    return M._itemById[itemId];
end

function M.tooltip_lines(preset)
    if (preset == nil) then
        return '';
    end
    if (preset._tooltipCache ~= nil and lookup.ready('items')) then
        return preset._tooltipCache;
    end
    local order = {};
    local totals = {};
    for _, step in ipairs(preset.commands or {}) do
        local itemId, amount = parse_additem(step);
        if (itemId ~= nil) then
            if (totals[itemId] == nil) then
                order[#order + 1] = itemId;
                totals[itemId] = 0;
            end
            totals[itemId] = totals[itemId] + amount;
        end
    end
    local lines = {};
    local pending = false;
    for _, itemId in ipairs(order) do
        local raw = item_name_by_id(itemId);
        if (raw == nil) then
            pending = true;
            lines[#lines + 1] = ('Item %d'):format(itemId);
        else
            local label = title_item_name(raw);
            local qty = totals[itemId] or 1;
            if (qty > 1) then
                lines[#lines + 1] = ('%s x%d'):format(label, qty);
            else
                lines[#lines + 1] = label;
            end
        end
    end
    local text = table.concat(lines, '\n');
    if (not pending and text ~= '') then
        preset._tooltipCache = text;
    end
    return text;
end

function M.is_running(state, presetId)
    local run = state and state.presetRun;
    return run ~= nil and run.presetId == presetId;
end

function M.stop(state)
    state.presetRun = nil;
end

local function send_step(cfg, payload, save, state)
    local say = require('libs.say');
    local ok, err = say.send(payload);
    if (not ok) then
        return false, err or 'Could not send.';
    end
    if (save ~= nil and state ~= nil) then
        require('libs.ui.history').push_history(cfg, payload, save, state);
    end
    return true;
end

function M.start(cfg, preset, save, state)
    if (preset == nil) then
        return false, 'Preset not found.';
    end
    local commands = {};
    for _, step in ipairs(preset.commands or {}) do
        local payload = normalize_payload(step);
        if (payload ~= '') then
            commands[#commands + 1] = payload;
        end
    end
    if (#commands == 0) then
        return false, 'Preset has no commands yet.';
    end
    local ok, err = send_step(cfg, commands[1], save, state);
    if (not ok) then
        return false, err;
    end
    if (#commands == 1) then
        state.presetRun = nil;
        return true;
    end
    state.presetRun = {
        presetId = preset.id,
        commands = commands,
        nextIndex = 2,
        done = 1,
        total = #commands,
        nextAt = os.clock() + M.command_delay(cfg),
    };
    state.scriptRun = nil;
    return true;
end

function M.tick(state, cfg, save)
    local run = state and state.presetRun;
    if (run == nil) then
        return;
    end
    if (run.nextIndex == nil or run.nextIndex > (run.total or 0)) then
        state.presetRun = nil;
        return;
    end
    local now = os.clock();
    if (now < (run.nextAt or 0)) then
        return;
    end
    local payload = run.commands[run.nextIndex];
    local ok = send_step(cfg, payload, save, state);
    if (not ok) then
        state.presetRun = nil;
        return;
    end
    run.done = (run.done or 0) + 1;
    run.nextIndex = run.nextIndex + 1;
    if (run.nextIndex > run.total) then
        state.presetRun = nil;
        return;
    end
    run.nextAt = now + M.command_delay(cfg);
end

function M.draw_preset_row(state, cfg, save, preset, slot, numW, showSeparator, uniqueKey, mode, onRemove)
    if (preset == nil) then
        return;
    end
    local rowId = tostring(uniqueKey or preset.id or slot);
    local originX = imgui.GetCursorPosX();
    local startY = imgui.GetCursorPosY();
    local totalW = kit.remaining_width();
    if (totalW < 1) then
        totalW = 1;
    end
    local textH, controlH, lineH = kit.row_metrics();
    local nameY = startY + math.max(0, (lineH - textH) * 0.5);
    local buttonY = startY + math.max(0, (lineH - controlH) * 0.5);
    local favW = widgets.icon_button_size();
    local execW = kit.px(kit.EXEC_W);
    local gap = kit.px(kit.GAP);
    local pair = execW + gap + favW;
    local nameX = originX + (numW or 0);
    local contentW = math.max(1, totalW - (numW or 0));
    local running = M.is_running(state, preset.id);
    local run = running and state.presetRun or nil;

    if (numW ~= nil and numW > 0 and slot ~= nil) then
        kit.draw_line_num(slot, numW, originX, nameY, textH);
    end

    local label = tostring(preset.name or preset.id or 'Preset');
    local nameW = kit.text_px(label);
    imgui.SetCursorPos({ nameX, nameY });
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text);
    imgui.Text(label);
    imgui.PopStyleColor();
    local tip = M.tooltip_lines(preset);
    if (tip ~= nil and tip ~= '') then
        kit.hover_tip(tip);
    end
    if (mode == 'favorite' and slot ~= nil) then
        require('libs.ui.favorites').note_fav_item_menu(state, state.favTab, slot);
    end

    local actionsX = nameX + contentW - pair;
    if (running and run ~= nil) then
        local inset = kit.px(30);
        local progX = nameX + nameW + gap + inset;
        local progressW = math.max(1, actionsX - gap - inset - progX);
        local progressH = math.max(1, controlH * 0.5);
        local progY = startY + (lineH - progressH) * 0.5;
        local done = math.max(0, tonumber(run.done) or 0);
        local total = math.max(1, tonumber(run.total) or 1);
        local frac = done / total;
        if (frac < 0) then
            frac = 0;
        elseif (frac > 1) then
            frac = 1;
        end
        imgui.SetCursorPos({ progX, progY });
        local overlay = ('%d/%d'):format(done, total);
        if (imgui.ProgressBar ~= nil) then
            pcall(imgui.ProgressBar, frac, { progressW, progressH }, overlay);
        else
            imgui.PushStyleColor(ImGuiCol_Text, theme.colors.muted);
            imgui.Text(overlay);
            imgui.PopStyleColor();
        end
    end

    imgui.SetCursorPos({ actionsX, buttonY });
    if (running) then
        if (widgets.button('Stop', 'presetstop' .. rowId, execW, 'primary')) then
            M.stop(state);
        end
    else
        if (widgets.execute('presetrun' .. rowId)) then
            M.start(cfg, preset, save, state);
        end
    end

    imgui.SetCursorPos({ actionsX + execW + gap, buttonY });
    if (mode == 'favorite') then
        if (widgets.remove('presetrm' .. rowId) and onRemove ~= nil) then
            onRemove();
        end
    else
        local favs = require('libs.ui.favorites');
        local favorited = favs.command_is_favorited(cfg, preset.id);
        if (widgets.favorite('presetfav' .. rowId, favorited)) then
            favs.ensure_favorite_tabs(cfg);
            local tab = favs.favorite_tab(cfg, state.favTab);
            state.favPick = {
                commandId = preset.id,
                tabId = tab.id,
                values = {},
                kind = 'preset',
            };
            state.favPickRequest = true;
        end
    end

    imgui.SetCursorPos({ originX, startY + lineH });
    kit.submit_space(0);
    if (showSeparator) then
        imgui.Separator();
    end
end

function M.draw_presets_page(state, cfg, save)
    lookup.ensure('items');
    lookup.focus({ 'items' });
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
    local listSpace = kit.begin_command_list_spacing();
    for index, row in ipairs(cache.rows) do
        M.draw_preset_row(state, cfg, save, row.item, row.slot, numW, index < #cache.rows, tostring(row.slot));
    end
    kit.end_command_list_spacing(listSpace);
end

function M.run_line(cfg, line, save, state)
    local index = math.floor(tonumber(line) or 0);
    local item = M.BUILTIN[index];
    if (item == nil) then
        return false, 'Preset not found.';
    end
    return M.start(cfg, item, save, state);
end

return M;
