--[[
* GM Helper pages: category lists, favorites, and history.
]]

require('common');

local imgui = require('imgui');
local commands = require('data.commands');
local listload = require('libs.listload');
local say = require('libs.say');
local store = require('libs.store');
local theme = require('libs.theme');
local widgets = require('libs.widgets');

local ui = {};
local modalActive = false;

function ui.modal_open()
    return modalActive;
end

local GROUPS = {
    { id = 'Player', label = 'Player' },
    { id = 'Combat', label = 'Combat' },
    { id = 'Items', label = 'Items' },
    { id = 'Progression', label = 'Progress' },
    { id = 'World', label = 'World' },
    { id = 'Entities', label = 'Entity' },
    { id = 'Other', label = 'Other' },
};
local SECTIONS = {
    { id = 'commands', label = 'Commands' },
    { id = 'favorites', label = 'Favorites' },
    { id = 'presets', label = 'Presets' },
    { id = 'history', label = 'History' },
    { id = 'settings', label = 'Settings' },
};
local labels = {};
local EXEC_W = 88;
local GAP = 8;
local LINE_H = 28;
local LIST_GAP_Y = 4;
local TITLE_PAD_X = 12;
local TITLE_PAD_Y = 8;
local TITLE_GLYPH = 16;
local ROUND = 0;
local PAD = 16;
local NO_RESIZE = ImGuiWindowFlags_NoResize or 2;
local scale = 1;
local fontScaled = false;

local function vec_x(value)
    if (value == nil) then
        return 0;
    end
    if (type(value) == 'table' or type(value) == 'userdata') then
        return value.x or value[1] or 0;
    end
    return value;
end

local function remaining_width()
    if (imgui.GetContentRegionAvail ~= nil) then
        local avail, second = imgui.GetContentRegionAvail();
        if (type(avail) == 'number') then
            return avail;
        end
        local width = vec_x(avail);
        if (width == 0 and type(second) == 'number') then
            return second;
        end
        return width;
    end
    if (imgui.GetWindowWidth ~= nil) then
        return math.max(0, imgui.GetWindowWidth() - imgui.GetCursorPosX() - 16);
    end
    return 0;
end

local function remaining_height()
    if (imgui.GetContentRegionAvail ~= nil) then
        local avail, second = imgui.GetContentRegionAvail();
        if (type(avail) == 'number') then
            return second or 0;
        end
        return avail.y or avail[2] or 0;
    end
    if (imgui.GetWindowHeight ~= nil) then
        return math.max(0, imgui.GetWindowHeight() - imgui.GetCursorPosY() - 16);
    end
    return 0;
end

local function submit_space(height)
    if (imgui.Dummy == nil) then
        return;
    end
    local size = { 0, height or 0 };
    if (not pcall(imgui.Dummy, size)) then
        pcall(imgui.Dummy, size[1], size[2]);
    end
end

local function align_right(width)
    local remaining = remaining_width();
    if (remaining > width) then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + remaining - width);
    end
end

local function bag_for(store, command)
    local bag = store[command.id];
    if (bag == nil) then
        bag = {};
        store[command.id] = bag;
    end
    for _, field in ipairs(command.fields) do
        if (bag[field.key] == nil) then
            bag[field.key] = T{ '' };
        end
    end
    return bag;
end

local function clear_bag(bag, command)
    if (bag == nil or command == nil) then
        return;
    end
    for _, field in ipairs(command.fields or {}) do
        if (bag[field.key] == nil) then
            bag[field.key] = T{ '' };
        else
            bag[field.key][1] = '';
        end
    end
end

local function snapshot_bag(bag, command)
    local values = {};
    for _, field in ipairs(command.fields or {}) do
        local text = '';
        if (bag ~= nil and bag[field.key] ~= nil and bag[field.key][1] ~= nil) then
            text = tostring(bag[field.key][1]);
        end
        values[field.key] = T{ text };
    end
    return values;
end

local function bag_for_entry(entry, command)
    if (entry.values == nil) then
        entry.values = {};
    end
    for _, field in ipairs(command.fields or {}) do
        local cur = entry.values[field.key];
        if (cur == nil) then
            entry.values[field.key] = T{ '' };
        elseif (type(cur) == 'string') then
            entry.values[field.key] = T{ cur };
        elseif (type(cur) ~= 'table') then
            entry.values[field.key] = T{ '' };
        elseif (cur[1] == nil) then
            cur[1] = '';
        end
    end
    return entry.values;
end

local SAMPLE_PLAYERS = { 'Nerf', 'Kupipi', 'Trion', 'Zeid', 'Lion', 'Prishe', 'Nashmeira', 'Lilith' };
local SAMPLE_WORDS = {
    player = SAMPLE_PLAYERS,
    target = SAMPLE_PLAYERS,
    target_player = SAMPLE_PLAYERS,
    linkshell_name = { 'Phoenix', 'Valefor', 'Carbuncle', 'Diabolos' },
    currency_type = { 'gil', 'bayld', 'plaudits', 'mweya_plasm' },
    light_type = { 'pearl', 'azure', 'ruby', 'amber' },
    animationid = { '0', '12', '48', '90' },
};

local function hash_id(text)
    text = tostring(text or '');
    local h = 2166136261;
    for index = 1, #text do
        h = (h * 16777619 + text:byte(index)) % 2147483647;
    end
    return h;
end

local function pick_sample(list, salt)
    if (list == nil or #list == 0) then
        return nil;
    end
    return list[(salt % #list) + 1];
end

local function sample_field_value(field, salt)
    local key = tostring(field.key or ''):lower();
    local label = tostring(field.label or ''):lower();
    local named = SAMPLE_WORDS[key] or SAMPLE_WORDS[key:gsub('_player$', 'player')];
    if (named ~= nil) then
        return pick_sample(named, salt);
    end
    if (field.kind == 'lookup') then
        local cat = field.lookup or '';
        if (cat == 'jobs') then
            return tostring(1 + (salt % 22));
        end
        if (cat == 'zones') then
            return tostring(100 + (salt % 50));
        end
        if (cat == 'spells' or cat == 'skills' or cat == 'effects' or cat == 'titles') then
            return tostring(10 + (salt % 200));
        end
        if (cat == 'items' or cat == 'keyitems') then
            return tostring(4000 + (salt % 5000));
        end
        if (cat == 'mobs' or cat == 'npcs') then
            return tostring(17000000 + (salt % 900000));
        end
        if (cat == 'missions' or cat == 'quests') then
            return tostring(salt % 40);
        end
        return tostring(100 + (salt % 900));
    end
    if (field.kind == 'number' or key:find('id', 1, true) or key:find('level', 1, true) or key:find('amount', 1, true) or key:find('qty', 1, true) or key:find('quantity', 1, true) or key:find('points', 1, true) or key:find('minutes', 1, true) or key:find('offset', 1, true) or key:find('power', 1, true) or key:find('duration', 1, true) or key:find('slot', 1, true) or key:find('master', 1, true) or key:find('log', 1, true) or label:find('level', 1, true)) then
        if (key:find('level', 1, true) or label:find('level', 1, true)) then
            return tostring(30 + (salt % 70));
        end
        if (key:find('master', 1, true)) then
            return tostring(salt % 2);
        end
        if (key:find('slot', 1, true)) then
            return tostring(salt % 3);
        end
        if (key:find('minutes', 1, true)) then
            return tostring(15 + (salt % 120));
        end
        if (key:find('quantity', 1, true) or key:find('amount', 1, true) or key:find('points', 1, true)) then
            return tostring(1 + (salt % 99));
        end
        if (key:find('log', 1, true)) then
            return tostring(salt % 10);
        end
        return tostring(1 + (salt % 99));
    end
    if (key:find('player', 1, true) or key:find('target', 1, true) or label:find('player', 1, true)) then
        return pick_sample(SAMPLE_PLAYERS, salt);
    end
    return pick_sample({ 'alpha', 'bravo', 'test', 'demo', 'sample' }, salt) or 'test';
end

local function command_example(command)
    if (command == nil) then
        return '';
    end
    local parts = { '!' .. command.id };
    local salt = hash_id(command.id);
    for index, field in ipairs(command.fields or {}) do
        parts[#parts + 1] = sample_field_value(field, salt + index * 17);
    end
    return table.concat(parts, ' ');
end

local function matches_query(command, query)
    if (query == '') then
        return true;
    end
    local hay = ('!%s %s %s'):format(command.id, command.desc or '', command.usage or ''):lower();
    return hay:find(query, 1, true) ~= nil;
end

local function hover_tip(desc, example)
    if ((desc == nil or desc == '') and (example == nil or example == '')) then
        return;
    end
    if (imgui.IsItemHovered == nil or not imgui.IsItemHovered()) then
        return;
    end
    local lines = {};
    if (desc ~= nil and desc ~= '') then
        lines[#lines + 1] = desc;
    end
    if (example ~= nil and example ~= '') then
        lines[#lines + 1] = 'Example: ' .. example;
    end
    local text = table.concat(lines, '\n');
    if (imgui.BeginTooltip ~= nil and imgui.EndTooltip ~= nil) then
        imgui.BeginTooltip();
        if (imgui.PushTextWrapPos ~= nil) then
            imgui.PushTextWrapPos(imgui.GetFontSize ~= nil and (imgui.GetFontSize() * 28) or 420);
        end
        if (imgui.TextUnformatted ~= nil) then
            imgui.TextUnformatted(text);
        else
            imgui.Text(text);
        end
        if (imgui.PopTextWrapPos ~= nil) then
            imgui.PopTextWrapPos();
        end
        imgui.EndTooltip();
    elseif (imgui.SetTooltip ~= nil) then
        imgui.SetTooltip(text);
    end
end

local function px(value)
    return math.floor(value * scale + 0.5);
end

local fontBase = nil;

local function clamp_scale(value)
    value = tonumber(value) or 1;
    if (value < 0.1) then
        value = 0.1;
    elseif (value > 3) then
        value = 3;
    end
    return math.floor(value * 100 + 0.5) / 100;
end

local function push_font()
    if (imgui.PushFont ~= nil and imgui.GetFont ~= nil) then
        if (fontBase == nil and imgui.GetFontSize ~= nil) then
            local size = imgui.GetFontSize();
            if (type(size) == 'number' and size > 0) then
                fontBase = size;
            end
        end
        local font = imgui.GetFont();
        if (font ~= nil and fontBase ~= nil) then
            local ok = pcall(imgui.PushFont, font, fontBase * scale);
            if (ok) then
                return true;
            end
        end
    end
    if (imgui.SetWindowFontScale ~= nil) then
        local ok = pcall(imgui.SetWindowFontScale, scale);
        return ok == true;
    end
    return false;
end

local function pop_font(pushed)
    if (pushed and imgui.PopFont ~= nil) then
        pcall(imgui.PopFont);
    end
end

local function text_width(text)
    if (imgui.CalcTextSize ~= nil) then
        local size, second = imgui.CalcTextSize(text);
        if (type(size) == 'number') then
            return size;
        end
        return vec_x(size) ~= 0 and vec_x(size) or vec_x(second);
    end
    return #tostring(text or '') * 7;
end

local function text_px(text)
    local width = text_width(text);
    if (not fontScaled) then
        width = width * scale;
    end
    return width;
end

local function text_height()
    local height = 13;
    if (imgui.CalcTextSize ~= nil) then
        local size, second = imgui.CalcTextSize('Ag');
        if (type(size) == 'number') then
            height = second or 13;
        else
            height = size.y or size[2] or 13;
        end
    end
    if (not fontScaled) then
        height = height * scale;
    end
    return height;
end

local function row_metrics()
    local textH = text_height();
    local controlH = textH + px(6) * 2;
    local lineH = math.max(px(LINE_H), controlH);
    return textH, controlH, lineH;
end

local function fill_target_keys(fields)
    local keys = {};
    for _, field in ipairs(fields or {}) do
        if (field.fills ~= nil) then
            for key in pairs(field.fills) do
                keys[key] = true;
            end
        end
    end
    return keys;
end

local function draw_field(command, field, bag, rowId, maxWidth)
    if (field.kind == 'lookup') then
        widgets.lookup(rowId .. field.key, field, bag, labels, maxWidth);
    else
        local width = math.min(widgets.input_width(field), math.max(1, maxWidth or widgets.input_width(field)));
        widgets.placeholder(rowId .. field.key, bag[field.key], field.placeholder, width);
    end
end

local function rect_visible(width, height)
    if (imgui.IsRectVisible == nil) then
        return true;
    end
    local ok, visible = pcall(imgui.IsRectVisible, {
        math.max(1, width or 1),
        math.max(1, height or 1),
    });
    return not ok or visible ~= false;
end

local function pack_field_rows(fields, fieldLeft, fieldRight, hiddenKeys)
    local rows = {};
    local line = {};
    local x = fieldLeft;
    local available = math.max(1, fieldRight - fieldLeft);
    for _, field in ipairs(fields) do
        if (hiddenKeys == nil or not hiddenKeys[field.key]) then
            local naturalW = widgets.field_width(field);
            local width = math.min(naturalW, available);
            if (#line > 0 and x + width > fieldRight) then
                rows[#rows + 1] = line;
                line = {};
                x = fieldLeft;
            end
            width = math.min(naturalW, math.max(1, fieldRight - x));
            line[#line + 1] = { field = field, x = x, width = width };
            x = x + width + px(GAP);
        end
    end
    if (#line > 0) then
        rows[#rows + 1] = line;
    end
    return rows;
end

local function draw_field_rows(rows, startY, lineH, controlH, command, bag, rowId)
    for index, fieldRow in ipairs(rows) do
        local fieldY = startY + (index - 1) * lineH + math.max(0, (lineH - controlH) * 0.5);
        for _, item in ipairs(fieldRow) do
            imgui.SetCursorPos({ item.x, fieldY });
            draw_field(command, item.field, bag, rowId, item.width);
        end
    end
end

local function widest_field(fields, hiddenKeys)
    local widest = 0;
    for _, field in ipairs(fields or {}) do
        if (hiddenKeys == nil or not hiddenKeys[field.key]) then
            widest = math.max(widest, widgets.field_width(field));
        end
    end
    return widest;
end

local function draw_command(command, bag, mode, onFavorite, onRemove, onExecute, errorText, nameCol, showSeparator, uniqueKey, favorited)
    if (showSeparator == nil) then
        showSeparator = true;
    end
    local rowId = mode .. tostring(uniqueKey or command.id);
    local startX = imgui.GetCursorPosX();
    local startY = imgui.GetCursorPosY();
    local contentW = remaining_width();
    if (contentW < 1) then
        contentW = 1;
    end
    local favW = widgets.icon_button_size();
    local pair = px(EXEC_W) + px(GAP) + favW;
    local textH, controlH, lineH = row_metrics();

    local required = {};
    local optional = {};
    for _, field in ipairs(command.fields or {}) do
        if (field.optional) then
            optional[#optional + 1] = field;
        else
            required[#required + 1] = field;
        end
    end

    local hiddenKeys = fill_target_keys(command.fields);
    local wideFieldLeft = startX + (nameCol or 0);
    local wideFieldRight = startX + contentW - pair - px(GAP);
    local wideFieldW = math.max(0, wideFieldRight - wideFieldLeft);
    local largestField = math.max(widest_field(required, hiddenKeys), widest_field(optional, hiddenKeys));
    local compact = largestField > wideFieldW or wideFieldW < px(120);
    local fieldLeft = compact and startX or wideFieldLeft;
    local fieldRight = compact and (startX + contentW) or wideFieldRight;
    local fieldsStartY = startY;
    local headerH = 0;
    local actionsRow = 0;
    if (compact) then
        if (text_px('!' .. command.id) + px(GAP) + pair > contentW) then
            actionsRow = 1;
        end
        headerH = lineH * (actionsRow + 1) + px(4);
        fieldsStartY = startY + headerH;
    end

    local requiredRows = pack_field_rows(required, fieldLeft, fieldRight, hiddenKeys);
    local optionalRows = {};
    local optionalFieldLeft = fieldLeft;
    if (#optional > 0) then
        if (compact) then
            optionalFieldLeft = startX + text_px('Optional') + px(12);
        end
        optionalRows = pack_field_rows(optional, optionalFieldLeft, fieldRight, hiddenKeys);
    end

    local requiredH = #requiredRows * lineH;
    if (not compact) then
        requiredH = math.max(lineH, requiredH);
    end
    local optionalH = #optionalRows * lineH;
    local blockH = headerH + requiredH + optionalH;
    local nameY = startY + math.max(0, ((compact and lineH or requiredH) - textH) * 0.5);
    local buttonY = startY + actionsRow * lineH
        + math.max(0, ((compact and lineH or requiredH) - controlH) * 0.5);

    local visibleH = blockH;
    if (errorText ~= nil and errorText ~= '') then
        visibleH = visibleH + lineH;
    end
    if (not rect_visible(contentW, visibleH)) then
        imgui.SetCursorPos({ startX, startY + blockH });
        submit_space(0);
        if (errorText ~= nil and errorText ~= '') then
            imgui.Text(errorText);
        end
        if (showSeparator) then
            imgui.Separator();
        end
        return;
    end

    imgui.SetCursorPos({ startX, nameY });
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.royal);
    imgui.Text('!');
    imgui.PopStyleColor();
    imgui.SameLine(0, 0);
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text);
    imgui.Text(command.id);
    imgui.PopStyleColor();
    hover_tip(command.desc, command_example(command));

    imgui.SetCursorPos({ startX + contentW - pair, buttonY });
    if (widgets.execute(rowId)) then
        onExecute();
    end
    imgui.SetCursorPos({ startX + contentW - favW, buttonY });
    if (mode == 'favorite') then
        if (widgets.remove(rowId)) then
            onRemove();
        end
    else
        if (widgets.favorite(rowId, favorited == true)) then
            onFavorite();
        end
    end

    draw_field_rows(requiredRows, fieldsStartY, lineH, controlH, command, bag, rowId);

    if (#optionalRows > 0) then
        local optStartY = fieldsStartY + requiredH;
        local optLabelY = optStartY + math.max(0, (lineH - textH) * 0.5);
        imgui.SetCursorPos({ startX, optLabelY });
        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.muted);
        imgui.Text('Optional');
        imgui.PopStyleColor();
        draw_field_rows(optionalRows, optStartY, lineH, controlH, command, bag, rowId);
    end

    imgui.SetCursorPos({ startX, startY + blockH });
    submit_space(0);

    if (errorText ~= nil and errorText ~= '') then
        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.remove);
        imgui.Text(errorText);
        imgui.PopStyleColor();
    end

    if (showSeparator) then
        imgui.PushStyleColor(ImGuiCol_Separator, theme.colors.borderSoft);
        imgui.Separator();
        imgui.PopStyleColor();
    end
end

local function begin_command_list_spacing()
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_ItemSpacing ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { px(GAP), px(LIST_GAP_Y) });
        return 1;
    end
    return 0;
end

local function end_command_list_spacing(pushed)
    if (pushed > 0 and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar(pushed);
    end
end

local tabDrag = { kind = nil, from = nil, moved = false };

local function bump_list(state, key)
    if (state == nil) then
        return;
    end
    listload.invalidate(state, key);
    if (key == 'favorites' or key == nil) then
        state.favListEpoch = (state.favListEpoch or 0) + 1;
    end
    if (key == 'history' or key == nil) then
        state.histListEpoch = (state.histListEpoch or 0) + 1;
    end
    if (key == 'presets' or key == nil) then
        state.presetListEpoch = (state.presetListEpoch or 0) + 1;
    end
end

local function history_max(cfg)
    return store.history_max();
end

local function trim_history(cfg)
    local max = history_max(cfg);
    while (#cfg.history > max) do
        table.remove(cfg.history);
    end
end

local function draw_list_loading(cache)
    local label = listload.label(cache);
    if (label == nil) then
        return;
    end
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.muted);
    imgui.Text(label);
    imgui.PopStyleColor();
end

local function ensure_favorite_tabs(cfg)
    if (type(cfg.favoriteTabs) ~= 'table' or #cfg.favoriteTabs == 0) then
        cfg.favoriteTabs = T{
            T{ id = 'default', name = 'Default', commands = T{} },
        };
    end
    cfg.nextFavId = cfg.nextFavId or 1;
    for _, tab in ipairs(cfg.favoriteTabs) do
        if (type(tab.commands) ~= 'table') then
            tab.commands = {};
        end
        for index, raw in ipairs(tab.commands) do
            if (type(raw) == 'string') then
                tab.commands[index] = { id = raw, values = {} };
            elseif (type(raw) == 'table') then
                if (raw.id == nil and type(raw[1]) == 'string') then
                    tab.commands[index] = { id = raw[1], values = {} };
                elseif (raw.values == nil) then
                    raw.values = {};
                end
            end
        end
    end
end

local function ensure_group_order(cfg)
    if (type(cfg.groupOrder) ~= 'table') then
        cfg.groupOrder = {};
    end
    local seen = {};
    local order = {};
    for _, id in ipairs(cfg.groupOrder) do
        for _, group in ipairs(GROUPS) do
            if (group.id == id and not seen[id]) then
                order[#order + 1] = id;
                seen[id] = true;
            end
        end
    end
    for _, group in ipairs(GROUPS) do
        if (not seen[group.id]) then
            order[#order + 1] = group.id;
        end
    end
    cfg.groupOrder = order;
end

local function ordered_groups(cfg)
    ensure_group_order(cfg);
    local byId = {};
    for _, group in ipairs(GROUPS) do
        byId[group.id] = group;
    end
    local list = {};
    for _, id in ipairs(cfg.groupOrder) do
        if (byId[id] ~= nil) then
            list[#list + 1] = byId[id];
        end
    end
    return list;
end

local function move_item(list, from, to)
    if (from == to or list[from] == nil or list[to] == nil) then
        return;
    end
    local item = table.remove(list, from);
    table.insert(list, to, item);
end

local function favorite_tab(cfg, id)
    ensure_favorite_tabs(cfg);
    for _, tab in ipairs(cfg.favoriteTabs) do
        if (tab.id == id) then
            return tab;
        end
    end
    return cfg.favoriteTabs[1];
end

local function fav_entry_id(entry)
    if (type(entry) == 'string') then
        return entry;
    end
    if (type(entry) == 'table') then
        return entry.id;
    end
    return nil;
end

local function command_is_favorited(cfg, commandId)
    if (commandId == nil or commandId == '') then
        return false;
    end
    ensure_favorite_tabs(cfg);
    for _, tab in ipairs(cfg.favoriteTabs) do
        for _, entry in ipairs(tab.commands or {}) do
            if (fav_entry_id(entry) == commandId) then
                return true;
            end
        end
    end
    return false;
end

local function add_favorite_to(cfg, tabId, commandId, values, save, state)
    local tab = favorite_tab(cfg, tabId);
    if (tab == nil or commandId == nil or commandId == '') then
        return;
    end
    if (tab.commands == nil) then
        tab.commands = {};
    end
    tab.commands[#tab.commands + 1] = {
        id = commandId,
        values = values or {},
    };
    bump_list(state, 'favorites');
    save();
end

local function remove_favorite_at(cfg, tabId, slot, save, state)
    local tab = favorite_tab(cfg, tabId);
    if (tab == nil or tab.commands == nil or slot == nil) then
        return;
    end
    if (tab.commands[slot] == nil) then
        return;
    end
    table.remove(tab.commands, slot);
    bump_list(state, 'favorites');
    save();
end

local function selected_fav_tab(state, cfg)
    ensure_favorite_tabs(cfg);
    local tab = favorite_tab(cfg, state.favTab);
    state.favTab = tab.id;
    return tab;
end

local HISTORY_DATE_SEPS = { '/', '-', '.' };

local HISTORY_DATE_ORDERS = {
    { order = 'mdy', label = 'MM%sDD%sYYYY' },
    { order = 'dmy', label = 'DD%sMM%sYYYY' },
    { order = 'ymd', label = 'YYYY%sMM%sDD' },
};

local HISTORY_TIME_FORMATS = {
    { id = '%H:%M:%S', label = 'HH:MM:SS (24H)' },
    { id = '%H:%M', label = 'HH:MM (24H)' },
    { id = '%I:%M:%S %p', label = 'HH:MM:SS (AM/PM)' },
    { id = '%I:%M %p', label = 'HH:MM (AM/PM)' },
};

local function history_date_sep(cfg)
    local sep = cfg.historyDateSep;
    if (sep == '/' or sep == '-' or sep == '.') then
        return sep;
    end
    return '/';
end

local function history_date_order_from_format(format)
    if (type(format) ~= 'string') then
        return 'mdy';
    end
    if (format:sub(1, 2) == '%m') then
        return 'mdy';
    end
    if (format:sub(1, 2) == '%d') then
        return 'dmy';
    end
    if (format:sub(1, 2) == '%Y') then
        return 'ymd';
    end
    return 'mdy';
end

local function history_date_order(cfg)
    local order = cfg.historyDateOrder;
    if (order == 'mdy' or order == 'dmy' or order == 'ymd') then
        return order;
    end
    return history_date_order_from_format(cfg.historyDateFormat);
end

local function history_date_format_for(order, sep)
    if (order == 'dmy') then
        return '%d' .. sep .. '%m' .. sep .. '%Y';
    end
    if (order == 'ymd') then
        return '%Y' .. sep .. '%m' .. sep .. '%d';
    end
    return '%m' .. sep .. '%d' .. sep .. '%Y';
end

local function history_date_formats(sep)
    local list = {};
    for _, option in ipairs(HISTORY_DATE_ORDERS) do
        list[#list + 1] = {
            id = option.order,
            label = option.label:format(sep, sep),
            order = option.order,
        };
    end
    return list;
end

local function history_format_label(list, id)
    for _, option in ipairs(list) do
        if (option.id == id) then
            return option.label;
        end
    end
    return list[1] and list[1].label or tostring(id or '');
end

local function ensure_history_formats(cfg)
    local sep = history_date_sep(cfg);
    local order = history_date_order(cfg);
    cfg.historyDateSep = sep;
    cfg.historyDateOrder = order;
    cfg.historyDateFormat = history_date_format_for(order, sep);
    local timeOk = false;
    for _, option in ipairs(HISTORY_TIME_FORMATS) do
        if (option.id == cfg.historyTimeFormat) then
            timeOk = true;
            break;
        end
    end
    if (not timeOk) then
        cfg.historyTimeFormat = '%H:%M:%S';
    end
end

local function history_entry_stamp(entry)
    if (entry == nil) then
        return nil;
    end
    local stamp = entry.stamp;
    if (type(stamp) == 'string') then
        stamp = tonumber(stamp);
    end
    if (type(stamp) == 'number') then
        return stamp;
    end
    return nil;
end

local function history_apply_ampm(hour, ampm)
    hour = tonumber(hour) or 0;
    if (ampm == nil or ampm == '') then
        return hour;
    end
    ampm = tostring(ampm):upper();
    if (ampm == 'PM' and hour < 12) then
        return hour + 12;
    end
    if (ampm == 'AM' and hour == 12) then
        return 0;
    end
    return hour;
end

local function history_to_stamp(year, month, day, hour, min, sec)
    year, month, day = tonumber(year), tonumber(month), tonumber(day);
    hour, min, sec = tonumber(hour) or 0, tonumber(min) or 0, tonumber(sec) or 0;
    if (year == nil or month == nil or day == nil) then
        return nil;
    end
    if (year < 100) then
        year = year + 2000;
    end
    local ok, stamp = pcall(os.time, {
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec,
    });
    if (ok and type(stamp) == 'number') then
        return stamp;
    end
    return nil;
end

local function parse_history_time(text)
    if (type(text) ~= 'string' or text == '') then
        return nil;
    end
    text = (text:gsub('^%s+', ''):gsub('%s+$', ''));
    text = text:gsub('%[', ''):gsub('%]', '');

    local year, month, day, hour, min, sec, ampm;

    year, month, day, hour, min, sec = text:match('^(%d%d%d%d)[/.-](%d%d)[/.-](%d%d)%s+(%d%d):(%d%d):(%d%d)$');
    if (year ~= nil) then
        return history_to_stamp(year, month, day, hour, min, sec);
    end
    year, month, day, hour, min = text:match('^(%d%d%d%d)[/.-](%d%d)[/.-](%d%d)%s+(%d%d):(%d%d)$');
    if (year ~= nil) then
        return history_to_stamp(year, month, day, hour, min, 0);
    end

    month, day, year, hour, min, sec, ampm = text:match('^(%d%d)[/.-](%d%d)[/.-](%d%d%d%d)%s+(%d%d):(%d%d):(%d%d)%s*([AaPp][Mm])$');
    if (month ~= nil) then
        return history_to_stamp(year, month, day, history_apply_ampm(hour, ampm), min, sec);
    end
    month, day, year, hour, min, ampm = text:match('^(%d%d)[/.-](%d%d)[/.-](%d%d%d%d)%s+(%d%d):(%d%d)%s*([AaPp][Mm])$');
    if (month ~= nil) then
        return history_to_stamp(year, month, day, history_apply_ampm(hour, ampm), min, 0);
    end
    month, day, year, hour, min, sec = text:match('^(%d%d)[/.-](%d%d)[/.-](%d%d%d%d)%s+(%d%d):(%d%d):(%d%d)$');
    if (month ~= nil) then
        local a, b = tonumber(month), tonumber(day);
        if (a ~= nil and a > 12 and b ~= nil and b <= 12) then
            return history_to_stamp(year, day, month, hour, min, sec);
        end
        return history_to_stamp(year, month, day, hour, min, sec);
    end
    month, day, year, hour, min = text:match('^(%d%d)[/.-](%d%d)[/.-](%d%d%d%d)%s+(%d%d):(%d%d)$');
    if (month ~= nil) then
        local a, b = tonumber(month), tonumber(day);
        if (a ~= nil and a > 12 and b ~= nil and b <= 12) then
            return history_to_stamp(year, day, month, hour, min, 0);
        end
        return history_to_stamp(year, month, day, hour, min, 0);
    end

    return nil;
end

local function format_history_stamp(cfg, stamp)
    ensure_history_formats(cfg);
    local dateFmt = history_date_format_for(history_date_order(cfg), history_date_sep(cfg));
    local timeFmt = cfg.historyTimeFormat or '%H:%M:%S';
    local okDate, dateText = pcall(os.date, dateFmt, stamp);
    local okTime, timeText = pcall(os.date, timeFmt, stamp);
    if (okDate and okTime and type(dateText) == 'string' and type(timeText) == 'string') then
        return dateText .. ' [' .. timeText .. ']';
    end
    return os.date('%m/%d/%Y', stamp) .. ' [' .. os.date('%H:%M:%S', stamp) .. ']';
end

local function ensure_history_stamps(cfg)
    if (type(cfg.history) ~= 'table') then
        return;
    end
    for _, entry in ipairs(cfg.history) do
        if (entry ~= nil) then
            local stamp = history_entry_stamp(entry);
            if (stamp == nil) then
                stamp = parse_history_time(entry.time);
            end
            if (stamp ~= nil) then
                entry.stamp = stamp;
            end
        end
    end
end

local function reformat_history(cfg, save, state)
    ensure_history_formats(cfg);
    ensure_history_stamps(cfg);
    for _, entry in ipairs(cfg.history or {}) do
        local stamp = history_entry_stamp(entry);
        if (stamp ~= nil) then
            entry.stamp = stamp;
            entry.time = format_history_stamp(cfg, stamp);
        end
    end
    bump_list(state, 'history');
    if (save ~= nil) then
        save();
    end
end

local function push_history(cfg, payload, save, state)
    if (type(cfg.history) ~= 'table') then
        cfg.history = {};
    end
    local stamp = os.time();
    table.insert(cfg.history, 1, {
        stamp = stamp,
        time = format_history_stamp(cfg, stamp),
        command = payload,
    });
    trim_history(cfg);
    bump_list(state, 'history');
    save();
end

local function run_payload(cfg, payload, save, errors, errorKey, state)
    local ok, err = say.send(payload);
    if (not ok) then
        errors[errorKey] = err or 'Could not send.';
        if (state ~= nil) then
            if (state.errorTimes == nil) then
                state.errorTimes = {};
            end
            state.errorTimes[errorKey] = os.time();
        end
        return false;
    end
    errors[errorKey] = nil;
    if (state ~= nil and state.errorTimes ~= nil) then
        state.errorTimes[errorKey] = nil;
    end
    push_history(cfg, payload, save, state);
    return true;
end

local function run_command(cfg, command, bag, save, errors, errorKey, state)
    local payload, err = say.build(command, bag);
    if (payload == nil) then
        errors[errorKey] = err;
        if (state ~= nil) then
            if (state.errorTimes == nil) then
                state.errorTimes = {};
            end
            state.errorTimes[errorKey] = os.time();
        end
        return false;
    end
    if (run_payload(cfg, payload, save, errors, errorKey, state)) then
        clear_bag(bag, command);
        if (save ~= nil) then
            save();
        end
        return true;
    end
    return false;
end

local function expire_errors(state)
    if (state == nil or state.errors == nil or state.errorTimes == nil) then
        return;
    end
    local now = os.time();
    for key, stamped in pairs(state.errorTimes) do
        if (type(stamped) == 'number' and (now - stamped) >= 5) then
            state.errors[key] = nil;
            state.errorTimes[key] = nil;
        end
    end
end

local function command_by_id(id)
    for _, command in ipairs(commands) do
        if (command.id == id) then
            return command;
        end
    end
    return nil;
end

local function name_column(list)
    local widest = 0;
    for _, command in ipairs(list) do
        local width = text_px('!' .. command.id);
        if (width > widest) then
            widest = width;
        end
    end
    return widest + px(12);
end

local WELCOME_COMBO_W = 295;

local function draw_tier_combo(cfg, save, comboId, fixedW, centerPreview)
    local id = comboId or '##tier';
    local tierLabel = 'Tier ' .. tostring(cfg.tier or 5);
    local tierLabels = {};
    for tier = 1, 5 do
        tierLabels[tier] = 'Tier ' .. tier;
    end
    local flags = ImGuiComboFlags_PopupAlignLeft;
    local opened, centered, listW = widgets.begin_labels_combo(id, tierLabel, tierLabels, flags, fixedW, centerPreview);
    if (opened) then
        for tier = 1, 5 do
            if (widgets.labels_combo_option('tier' .. tier .. id, 'Tier ' .. tier, cfg.tier == tier, listW)) then
                cfg.tier = tier;
                save();
            end
        end
        widgets.end_labels_combo(opened, centered);
    end
end

local function draw_tier(cfg, save)
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label('Tier');
    imgui.SameLine();
    draw_tier_combo(cfg, save, '##tier');
end

local function push_sized_font(extraPx)
    extraPx = extraPx or 0;
    if (imgui.PushFont ~= nil and imgui.GetFont ~= nil) then
        if (fontBase == nil and imgui.GetFontSize ~= nil) then
            local size = imgui.GetFontSize();
            if (type(size) == 'number' and size > 0) then
                fontBase = size;
            end
        end
        local font = imgui.GetFont();
        if (font ~= nil and fontBase ~= nil) then
            local ok = pcall(imgui.PushFont, font, fontBase * scale + extraPx);
            if (ok) then
                return true;
            end
        end
    end
    return false;
end

local function welcome_wrap_lines(text, wrapW)
    local lines = {};
    local current = '';
    for word in tostring(text or ''):gmatch('%S+') do
        local trial = current == '' and word or (current .. ' ' .. word);
        if (current ~= '' and text_px(trial) > wrapW) then
            lines[#lines + 1] = current;
            current = word;
        else
            current = trial;
        end
    end
    if (current ~= '') then
        lines[#lines + 1] = current;
    end
    if (#lines == 0) then
        lines[1] = '';
    end
    return lines;
end

local function welcome_centered_text(text, startX, contentW, color)
    local lines = welcome_wrap_lines(text, contentW);
    if (color ~= nil) then
        imgui.PushStyleColor(ImGuiCol_Text, color);
    end
    for _, line in ipairs(lines) do
        local width = text_px(line);
        imgui.SetCursorPosX(startX + math.max(0, (contentW - width) * 0.5));
        imgui.Text(line);
    end
    if (color ~= nil) then
        imgui.PopStyleColor();
    end
    return #lines;
end

local function draw_welcome(cfg, save)
    local availW = remaining_width();
    local availH = remaining_height();
    local contentW = math.min(px(460), math.max(px(280), availW - px(40)));
    local tierLabels = {};
    for tier = 1, 5 do
        tierLabels[tier] = 'Tier ' .. tier;
    end
    local comboW = px(WELCOME_COMBO_W);
    local buttonW = px(120);
    local gap = px(GAP);
    local originX = imgui.GetCursorPosX();
    local originY = imgui.GetCursorPosY();
    local startX = originX + math.max(0, (availW - contentW) * 0.5);

    local bodyFont = push_sized_font(2);
    local titleFont = push_sized_font(6);
    local title = 'Welcome to GM Helper!';
    local titleH = text_height();
    local titleW = text_px(title);
    pop_font(titleFont);

    local bodyH = text_height();
    local tierLines = welcome_wrap_lines(
        'Before using, please make sure to select your GM Tier as you will only have access to specific commands.',
        contentW
    );
    local warnLines = welcome_wrap_lines(
        'Remember that commands will affect what you currently have targeted unless you specify the target name, which is an optional argument.',
        contentW
    );
    local _, controlH = row_metrics();
    local blockH = titleH + gap
        + (#tierLines * bodyH) + gap
        + controlH + gap
        + (#warnLines * bodyH) + gap * 2
        + controlH;
    pop_font(bodyFont);

    local startY = originY + math.max(0, (availH - blockH) * 0.5);
    imgui.SetCursorPos({ startX, startY });

    titleFont = push_sized_font(6);
    imgui.SetCursorPosX(startX + math.max(0, (contentW - titleW) * 0.5));
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text);
    imgui.Text(title);
    imgui.PopStyleColor();
    pop_font(titleFont);
    imgui.Spacing();

    bodyFont = push_sized_font(2);
    welcome_centered_text(
        'Before using, please make sure to select your GM Tier as you will only have access to specific commands.',
        startX,
        contentW,
        theme.colors.text
    );
    imgui.Spacing();

    imgui.SetCursorPosX(startX + math.max(0, (contentW - comboW) * 0.5));
    draw_tier_combo(cfg, save, '##welcometier', WELCOME_COMBO_W, true);
    imgui.Spacing();

    welcome_centered_text(
        'Remember that commands will affect what you currently have targeted unless you specify the target name, which is an optional argument.',
        startX,
        contentW,
        theme.colors.peach
    );
    imgui.Spacing();
    imgui.Spacing();

    imgui.SetCursorPosX(startX + math.max(0, (contentW - buttonW) * 0.5));
    if (widgets.button('Accept', 'welcome', buttonW, 'primary')) then
        cfg.welcomeAccepted = true;
        save();
    end
    pop_font(bodyFont);
end

local function draw_search_bar(id, buffer)
    local width = remaining_width();
    if (width < px(160)) then
        width = px(160);
    end
    widgets.placeholder(id, buffer, 'Search', width, 'left');
end

local function draw_page_search(state)
    draw_search_bar('cmdsearch', state.search);
end

local function fav_search(state, tabId)
    if (state.favSearch == nil) then
        state.favSearch = {};
    end
    if (state.favSearch[tabId] == nil) then
        state.favSearch[tabId] = { '' };
    end
    return state.favSearch[tabId];
end

local function draw_category_page(state, cfg, save, category, query)
    local pageCommands = {};
    for _, command in ipairs(commands) do
        if (command.category == category and command.minTier <= (cfg.tier or 5)) then
            pageCommands[#pageCommands + 1] = command;
        end
    end
    local matched = {};
    for _, command in ipairs(pageCommands) do
        if (matches_query(command, query)) then
            matched[#matched + 1] = command;
        end
    end
    local nameCol = name_column(matched);
    local listSpace = begin_command_list_spacing();
    for index, command in ipairs(matched) do
        local bag = bag_for(state.values, command);
        draw_command(command, bag, 'cmd', function()
            ensure_favorite_tabs(cfg);
            local tab = favorite_tab(cfg, state.favTab);
            state.favPick = {
                commandId = command.id,
                tabId = tab.id,
                values = snapshot_bag(bag, command),
            };
            state.favPickRequest = true;
        end, nil, function()
            run_command(cfg, command, bag, save, state.errors, command.id, state);
        end, state.errors[command.id], nameCol, index < #matched, command.id, command_is_favorited(cfg, command.id));
    end
    end_command_list_spacing(listSpace);
    if (#matched == 0) then
        if (query ~= '') then
            widgets.empty_state('No commands match.');
        else
            widgets.empty_state('No commands are assigned to this tier yet.');
        end
    end
end

function trim_query(value)
    if (value == nil) then
        return '';
    end
    return (tostring(value):gsub('^%s+', ''):gsub('%s+$', '')):lower();
end

local function draw_favorites_page(state, cfg, save)
    local tab = selected_fav_tab(state, cfg);
    local queryBuf = fav_search(state, tab.id);
    local query = trim_query(queryBuf[1]);
    local ids = tab.commands or {};
    local token = table.concat({
        'fav',
        tostring(tab.id),
        query,
        tostring(#ids),
        tostring(state.favListEpoch or 0),
    }, '|');
    local cache = listload.cache(state, 'favorites', token, #ids);
    listload.pump(cache, function(index)
        local entry = ids[index];
        local commandId = fav_entry_id(entry);
        local command = command_by_id(commandId);
        if (command ~= nil and matches_query(command, query)) then
            cache.rows[#cache.rows + 1] = {
                command = command,
                entry = entry,
                slot = index,
            };
        end
    end);
    draw_list_loading(cache);
    if (#ids == 0) then
        widgets.empty_state('Favorite a command to pin it here. Current field values are kept when you favorite.');
        return;
    end
    if (#cache.rows == 0 and cache.ready) then
        widgets.empty_state('No commands match.');
        return;
    end
    local nameCommands = {};
    for _, row in ipairs(cache.rows) do
        nameCommands[#nameCommands + 1] = row.command;
    end
    local nameCol = name_column(nameCommands);
    local listSpace = begin_command_list_spacing();
    for index, row in ipairs(cache.rows) do
        local command = row.command;
        local bag = bag_for_entry(row.entry, command);
        local errKey = 'fav' .. tostring(tab.id) .. '_' .. tostring(row.slot);
        draw_command(command, bag, 'favorite', nil, function()
            remove_favorite_at(cfg, tab.id, row.slot, save, state);
        end, function()
            run_command(cfg, command, bag, save, state.errors, errKey, state);
        end, state.errors[errKey], nameCol, index < #cache.rows, tostring(tab.id) .. '_' .. tostring(row.slot));
    end
    end_command_list_spacing(listSpace);
end

local function draw_presets_page(state, cfg, save)
    local items = cfg.presets or {};
    local token = table.concat({
        'preset',
        tostring(#items),
        tostring(state.presetListEpoch or 0),
        trim_query(state.search[1]),
    }, '|');
    local cache = listload.cache(state, 'presets', token, #items);
    listload.pump(cache, function(index)
        local item = items[index];
        if (item ~= nil) then
            cache.rows[#cache.rows + 1] = item;
        end
    end);
    draw_list_loading(cache);
    if (#items == 0 and cache.ready) then
        widgets.empty_state('No presets yet.');
        return;
    end
    for index, item in ipairs(cache.rows) do
        local label = item.name or item.id or 'Preset';
        imgui.Text(tostring(label));
        if (index < #cache.rows) then
            imgui.Separator();
        end
    end
end

local function draw_history_page(state, cfg, save, query)
    if (type(cfg.history) ~= 'table') then
        cfg.history = {};
    end
    trim_history(cfg);
    local entries = cfg.history;
    local token = table.concat({
        'hist',
        query,
        tostring(#entries),
        tostring(state.histListEpoch or 0),
        tostring(cfg.historyDateFormat or ''),
        tostring(cfg.historyTimeFormat or ''),
    }, '|');
    local cache = listload.cache(state, 'history', token, #entries);
    local stampDirty = false;
    listload.pump(cache, function(index)
        local entry = entries[index];
        if (entry == nil) then
            return;
        end
        local stamp = history_entry_stamp(entry);
        if (stamp == nil) then
            stamp = parse_history_time(entry.time);
            if (stamp ~= nil) then
                entry.stamp = stamp;
            end
        end
        if (stamp ~= nil) then
            local formatted = format_history_stamp(cfg, stamp);
            if (entry.time ~= formatted) then
                entry.time = formatted;
                stampDirty = true;
            end
        end
        local command = entry.command or '';
        if (query == '' or command:lower():find(query, 1, true) ~= nil) then
            cache.rows[#cache.rows + 1] = { index = index, entry = entry };
        end
    end);
    if (stampDirty and cache.ready) then
        save();
    end
    draw_list_loading(cache);
    if (#entries == 0 and cache.ready) then
        widgets.empty_state('Executed commands will show up here.');
        return;
    end
    local removeAt = nil;
    for rowIndex, row in ipairs(cache.rows) do
        local index = row.index;
        local entry = row.entry;
        local command = entry.command or '';
        local textH, controlH, lineH = row_metrics();
        local rowX = imgui.GetCursorPosX();
        local rowY = imgui.GetCursorPosY();
        local rowW = remaining_width();
        local execW = px(88);
        local iconW = widgets.icon_button_size();
        local gap = px(GAP);
        local when = entry.time or '';
        local textY = rowY + math.max(0, (lineH - textH) * 0.5);
        local buttonY = rowY + math.max(0, (lineH - controlH) * 0.5);
        imgui.SetCursorPos({ rowX, textY });
        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.muted);
        imgui.Text(when);
        imgui.PopStyleColor();
        local cursorX = rowX + text_px(when) + gap;
        imgui.SetCursorPos({ cursorX, textY });
        imgui.Text(command);
        local right = rowX + rowW;
        imgui.SetCursorPos({ right - iconW - gap - execW, buttonY });
        if (widgets.execute('hist' .. index .. tostring(entry.stamp or entry.time or ''))) then
            run_payload(cfg, entry.command, save, state.errors, 'hist' .. index, state);
        end
        imgui.SetCursorPos({ right - iconW, buttonY });
        if (widgets.remove('hist' .. index .. tostring(entry.stamp or entry.time or ''))) then
            removeAt = index;
        end
        if (state.errors['hist' .. index] ~= nil) then
            imgui.SetCursorPos({ rowX, textY + textH + px(2) });
            imgui.PushStyleColor(ImGuiCol_Text, theme.colors.remove);
            imgui.Text(state.errors['hist' .. index]);
            imgui.PopStyleColor();
        end
        imgui.SetCursorPos({ rowX, rowY + lineH });
        submit_space(0);
        if (rowIndex < #cache.rows) then
            imgui.Separator();
        end
    end
    if (removeAt ~= nil) then
        table.remove(cfg.history, removeAt);
        bump_list(state, 'history');
        save();
    end
    if (#cache.rows == 0 and cache.ready and #entries > 0) then
        widgets.empty_state('No commands match.');
    end
end

local function sync_nav(state)
    if (state.section ~= 'commands' and state.section ~= 'favorites' and state.section ~= 'presets' and state.section ~= 'history' and state.section ~= 'settings') then
        if (state.page == 'favorites' or state.page == 'presets' or state.page == 'history' or state.page == 'settings') then
            state.section = state.page;
            state.page = 'Player';
        else
            state.section = 'commands';
        end
    end
    for _, group in ipairs(GROUPS) do
        if (state.page == group.id) then
            return;
        end
    end
    state.page = 'Player';
end

local function vec2(value, other)
    if (type(value) == 'table' or type(value) == 'userdata') then
        return value.x or value[1] or 0, value.y or value[2] or 0;
    end
    if (type(value) == 'number') then
        return value, other or 0;
    end
    return 0, 0;
end

local function last_item_rect()
    local x1, y1, x2, y2 = 0, 0, 16, 16;
    if (imgui.GetItemRectMin ~= nil) then
        local a, b = imgui.GetItemRectMin();
        x1, y1 = vec2(a, b);
    end
    if (imgui.GetItemRectMax ~= nil) then
        local a, b = imgui.GetItemRectMax();
        local mx, my = vec2(a, b);
        if (mx > x1) then
            x2, y2 = mx, my;
        end
    end
    return x1, y1, x2, y2;
end

local function symbol_hit(id)
    local pushed = 0;
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_FrameBorderSize ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 0);
        pushed = pushed + 1;
    end
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_FramePadding ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 0 });
        pushed = pushed + 1;
    end
    imgui.PushStyleColor(ImGuiCol_Button, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.colors.accentMuted);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.colors.accentSoft);
    imgui.PushStyleColor(ImGuiCol_Border, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.clear);
    local clicked = imgui.Button('##' .. id, { px(TITLE_GLYPH), px(TITLE_GLYPH) });
    imgui.PopStyleColor(5);
    if (pushed > 0 and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar(pushed);
    end
    return clicked;
end

local function paint_symbol(kind, collapsed)
    local draw = imgui.GetWindowDrawList();
    if (draw == nil) then
        return;
    end
    local x1, y1, x2, y2 = last_item_rect();
    local cx = (x1 + x2) * 0.5;
    local cy = (y1 + y2) * 0.5;
    local symbolColor = theme.colors.peach;
    if (imgui.IsItemHovered ~= nil and imgui.IsItemHovered()) then
        symbolColor = theme.colors.text;
    end
    local col = theme.col32(symbolColor);
    local box = px(4);
    local thick = math.max(1, scale * 1.5);
    local function stroke()
        if (kind == 'chevron' and draw.AddTriangleFilled ~= nil) then
            local shift = box / 3;
            if (collapsed) then
                draw:AddTriangleFilled(
                    { cx - box + shift, cy - box },
                    { cx - box + shift, cy + box },
                    { cx + box + shift, cy },
                    col
                );
            else
                draw:AddTriangleFilled(
                    { cx - box, cy - box + shift },
                    { cx + box, cy - box + shift },
                    { cx, cy + box + shift },
                    col
                );
            end
        elseif (kind == 'close' and draw.AddLine ~= nil) then
            draw:AddLine({ cx - box, cy - box }, { cx + box, cy + box }, col, thick);
            draw:AddLine({ cx + box, cy - box }, { cx - box, cy + box }, col, thick);
        end
    end
    pcall(stroke);
end

local ROUND_TOP = ImDrawFlags_RoundCornersTop or 48;
local ROUND_BOTTOM = ImDrawFlags_RoundCornersBottom or 192;
local ROUND_ALL = ImDrawFlags_RoundCornersAll or 240;
local NO_MOVE = ImGuiWindowFlags_NoMove or 4;
local NO_SCROLL = ImGuiWindowFlags_NoScrollbar or 8;
local NO_SCROLL_MOUSE = ImGuiWindowFlags_NoScrollWithMouse or 16;
local NO_BACKGROUND = ImGuiWindowFlags_NoBackground or 128;
local NO_FRONT = ImGuiWindowFlags_NoBringToFrontOnFocus or 8192;
local NO_DOCK = ImGuiWindowFlags_NoDocking or 524288;

local function bor_flags(...)
    local value = 0;
    for index = 1, select('#', ...) do
        local flag = select(index, ...);
        if (type(flag) == 'number') then
            value = bit.bor(value, flag);
        end
    end
    return value;
end

local function window_pos()
    if (imgui.GetWindowPos == nil) then
        return 0, 0;
    end
    return vec2(imgui.GetWindowPos());
end

local function title_metrics()
    local glyph = px(TITLE_GLYPH);
    local padX = px(TITLE_PAD_X);
    local padY = px(TITLE_PAD_Y);
    return glyph, padX, padY, glyph + padY * 2;
end

local function push_styles(list)
    local count = 0;
    if (imgui.PushStyleVar == nil) then
        return 0;
    end
    for _, item in ipairs(list) do
        if (item[1] ~= nil) then
            imgui.PushStyleVar(item[1], item[2]);
            count = count + 1;
        end
    end
    return count;
end

local function pop_styles(count)
    if (count > 0 and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar(count);
    end
end

local function paint_panel(rounding, corners, fillColor, edgeColor)
    if (imgui.GetWindowDrawList == nil or imgui.GetWindowWidth == nil or imgui.GetWindowHeight == nil) then
        return;
    end
    local draw = imgui.GetWindowDrawList();
    if (draw == nil or draw.AddRectFilled == nil) then
        return;
    end
    local x, y = window_pos();
    local w = imgui.GetWindowWidth();
    local h = imgui.GetWindowHeight();
    if (w <= 0 or h <= 0) then
        return;
    end
    local min = { x, y };
    local max = { x + w, y + h };
    local fill = theme.col32(fillColor or theme.colors.abyss);
    local edge = theme.col32(edgeColor or theme.colors.border);
    if (not pcall(draw.AddRectFilled, draw, min, max, fill, rounding, corners)) then
        pcall(draw.AddRectFilled, draw, min, max, fill, 0);
    end
    if (draw.AddRect ~= nil) then
        if (not pcall(draw.AddRect, draw, min, max, edge, rounding, corners, 1)) then
            pcall(draw.AddRect, draw, min, max, edge, 0, 0, 1);
        end
    end
end

local function window_hovered()
    if (imgui.IsWindowHovered == nil) then
        return false;
    end
    local flags = ImGuiHoveredFlags_ChildWindows or 0;
    if (ImGuiHoveredFlags_AllowWhenBlockedByActiveItem ~= nil) then
        flags = bit.bor(flags, ImGuiHoveredFlags_AllowWhenBlockedByActiveItem);
    end
    local ok, hovered = pcall(imgui.IsWindowHovered, flags);
    if (not ok) then
        ok, hovered = pcall(imgui.IsWindowHovered);
    end
    return ok and hovered == true;
end

local function window_focused()
    if (imgui.IsWindowFocused == nil) then
        return false;
    end
    local flags = ImGuiFocusedFlags_RootAndChildWindows;
    if (flags ~= nil) then
        local ok, focused = pcall(imgui.IsWindowFocused, flags);
        if (ok) then
            return focused == true;
        end
    end
    local ok, focused = pcall(imgui.IsWindowFocused);
    return ok and focused == true;
end

local function title_chrome(panelFocused)
    if (window_hovered()) then
        return theme.colors.glass, theme.colors.borderStrong;
    end
    if (window_focused() or panelFocused) then
        return theme.colors.glass, theme.colors.accentSoft;
    end
    return theme.colors.glass, theme.colors.borderSoft;
end

-- Title bar is its own window. Collapse only hides the body, so this row never changes size.
local function draw_title(state)
    local glyph = px(TITLE_GLYPH);
    local startX = imgui.GetCursorPosX();
    local rowY = imgui.GetCursorPosY();
    local contentW = remaining_width();
    local textH = 13;
    if (imgui.CalcTextSize ~= nil) then
        local size, second = imgui.CalcTextSize('GM Helper');
        if (type(size) == 'number') then
            textH = second or 13;
        else
            textH = size.y or size[2] or 13;
        end
    end
    if (not fontScaled) then
        textH = textH * scale;
    end

    local textY = rowY + math.max(0, (glyph - textH) * 0.5);
    imgui.SetCursorPos({ startX, rowY });
    if (symbol_hit('collapse')) then
        state.collapsed = not state.collapsed;
    end
    paint_symbol('chevron', state.collapsed);

    local label = 'GM HELPER';
    imgui.SetCursorPos({ startX + glyph + px(8), textY });
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text);
    imgui.Text(label);
    imgui.PopStyleColor();

    imgui.SetCursorPos({ startX + glyph + px(8) + text_px(label) + px(6), textY });
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.peach);
    imgui.Text('v' .. addon.version);
    imgui.PopStyleColor();

    imgui.SetCursorPos({ startX + contentW - glyph, rowY });
    if (symbol_hit('close')) then
        state.visible = false;
    end
    paint_symbol('close', false);
    submit_space(0);
end

local function tab_radius(height)
    return 0;
end

local function paint_selected_tab(radius)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    if (draw == nil or draw.AddRectFilled == nil) then
        return;
    end
    local x1, y1, x2, y2 = last_item_rect();
    local fill = theme.col32(theme.colors.glass);
    if (not pcall(draw.AddRectFilled, draw, { x1, y1 }, { x2, y2 }, fill, radius, ROUND_TOP)) then
        pcall(draw.AddRectFilled, draw, { x1, y1 }, { x2, y2 }, fill, 0);
    end
end

local function paint_nav_highlight(selected, radius, strength)
    local x1, y1, x2, y2 = last_item_rect();
    local panel = selected and theme.colors.glass or theme.colors.abyss;
    theme.paint_tab_highlight(x1, y1, x2, y2, math.max(2, px(2)), panel, radius, strength);
end

local function paint_nav_label(label, color)
    local draw = imgui.GetWindowDrawList();
    local x1, y1, x2, y2 = last_item_rect();
    local tw, th = text_width(label), 13;
    if (imgui.CalcTextSize ~= nil) then
        local size, second = imgui.CalcTextSize(label);
        if (type(size) == 'number') then
            tw, th = size, second or 13;
        else
            tw = size.x or size[1] or tw;
            th = size.y or size[2] or 13;
        end
    end
    if (draw == nil or draw.AddText == nil) then
        return;
    end
    pcall(draw.AddText, draw, {
        x1 + math.max(0, ((x2 - x1) - tw) * 0.5),
        y1 + math.max(0, ((y2 - y1) - th) * 0.5),
    }, theme.col32(color or theme.colors.text), label);
end

local function paint_section_underline(label, strength)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    if (draw == nil or draw.AddRectFilled == nil) then
        return;
    end
    local x1, y1, x2, y2 = last_item_rect();
    local tw = text_px(label);
    local cx = (x1 + x2) * 0.5;
    local lineW = math.max(px(16), tw);
    local thick = math.max(2, px(2));
    local lineY = y2 - thick - px(2);
    local royal = theme.colors.royal;
    pcall(draw.AddRectFilled, draw, {
        cx - lineW * 0.5,
        lineY,
    }, {
        cx + lineW * 0.5,
        lineY + thick,
    }, theme.col32({
        royal[1],
        royal[2],
        royal[3],
        (royal[4] or 1) * (strength or 1),
    }));
end

local function nav_button(label, id, selected, width)
    local pushed = 0;
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_FrameBorderSize ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 0);
        pushed = pushed + 1;
    end
    imgui.PushStyleColor(ImGuiCol_Button, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_Border, theme.colors.clear);
    local clicked = imgui.Button('##' .. id, { width, px(30) });
    local radius = tab_radius(px(30));
    local hovered = imgui.IsItemHovered ~= nil and imgui.IsItemHovered();
    if (selected) then
        paint_selected_tab(radius);
        paint_nav_highlight(true, radius, 1);
    elseif (hovered) then
        paint_nav_highlight(false, radius, 0.75);
    end
    local color = theme.colors.muted;
    if (selected or hovered) then
        color = theme.colors.text;
    end
    paint_nav_label(label, color);
    imgui.PopStyleColor(4);
    if (pushed > 0 and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar(pushed);
    end
    return clicked;
end

local function letter_tab_width()
    return math.ceil(text_px(string.rep('M', 10)));
end

local function section_tab(label, id, selected, width)
    local pushed = 0;
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_FrameBorderSize ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 0);
        pushed = pushed + 1;
    end
    imgui.PushStyleColor(ImGuiCol_Button, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_Border, theme.colors.clear);
    local clicked = imgui.Button('##' .. id, { width, px(32) });
    local hovered = imgui.IsItemHovered ~= nil and imgui.IsItemHovered();
    local color = theme.colors.muted;
    if (selected) then
        color = theme.colors.text;
    elseif (hovered) then
        color = theme.colors.secondary;
    end
    paint_nav_label(label, color);
    if (selected) then
        paint_section_underline(label, 1);
    elseif (hovered) then
        paint_section_underline(label, 0.75);
    end
    imgui.PopStyleColor(4);
    if (pushed > 0 and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar(pushed);
    end
    return clicked;
end

local function begin_settings_section(title)
    widgets.section_heading(title);
end

local function begin_dimmed()
    local dimmed = false;
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_Alpha ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_Alpha, 0.45);
        dimmed = true;
    end
    if (imgui.BeginDisabled ~= nil) then
        pcall(imgui.BeginDisabled, true);
    end
    return dimmed;
end

local function end_dimmed(dimmed)
    if (imgui.EndDisabled ~= nil) then
        pcall(imgui.EndDisabled);
    end
    if (dimmed and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar();
    end
end

local function draw_format_combo(label, id, current, options, onPick)
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label(label);
    imgui.SameLine();
    local labels = {};
    for _, option in ipairs(options) do
        labels[#labels + 1] = option.label;
    end
    local shown = history_format_label(options, current);
    local flags = ImGuiComboFlags_PopupAlignLeft;
    local opened, centered, listW = widgets.begin_labels_combo('##' .. id, shown, labels, flags);
    if (opened) then
        for index, option in ipairs(options) do
            if (widgets.labels_combo_option(id .. index, option.label, option.id == current, listW)) then
                onPick(option.id);
            end
        end
        widgets.end_labels_combo(opened, centered);
    end
end

local function draw_settings_page(state, cfg, save)
    begin_settings_section('General');
    draw_tier(cfg, save);
    imgui.Spacing();
    local scaleDim = begin_dimmed();
    if (state.scaleBuf == nil) then
        state.scaleBuf = T{ cfg.scale or 1 };
    end
    state.scaleBuf[1] = cfg.scale or 1;
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label('Scale');
    imgui.SameLine();
    imgui.SetNextItemWidth(px(220));
    if (imgui.SliderFloat ~= nil) then
        local ok = pcall(imgui.SliderFloat, '##scale', state.scaleBuf, 0.1, 3, '%.2f');
        if (not ok) then
            pcall(imgui.SliderFloat, '##scale', state.scaleBuf, 0.1, 3);
        end
    end
    state.scaleDragging = false;
    imgui.SameLine();
    imgui.Text(('%d%%'):format(math.floor((cfg.scale or 1) * 100 + 0.5)));
    imgui.Spacing();
    widgets.helper_text('Scales the window and text together.');
    end_dimmed(scaleDim);

    imgui.Spacing();
    imgui.Spacing();
    begin_settings_section('Presets');
    local presetDim = begin_dimmed();
    if (state.commandDelayBuf == nil) then
        state.commandDelayBuf = T{ cfg.commandDelay or 1.5 };
    end
    state.commandDelayBuf[1] = cfg.commandDelay or 1.5;
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label('Command Delay');
    imgui.SameLine();
    imgui.SetNextItemWidth(px(220));
    if (imgui.SliderFloat ~= nil) then
        local ok = pcall(imgui.SliderFloat, '##commanddelay', state.commandDelayBuf, 0.5, 5, '%.1f');
        if (not ok) then
            pcall(imgui.SliderFloat, '##commanddelay', state.commandDelayBuf, 0.5, 5);
        end
    end
    imgui.SameLine();
    imgui.Text(('%.1fs'):format(cfg.commandDelay or 1.5));
    imgui.Spacing();
    widgets.helper_text('Seconds between preset commands. Not wired up yet.');
    end_dimmed(presetDim);

    imgui.Spacing();
    imgui.Spacing();
    begin_settings_section('History');
    ensure_history_formats(cfg);
    local dateFormats = history_date_formats(history_date_sep(cfg));
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label('Date');
    imgui.SameLine();
    local dateLabels = {};
    for _, option in ipairs(dateFormats) do
        dateLabels[#dateLabels + 1] = option.label;
    end
    local dateShown = history_format_label(dateFormats, history_date_order(cfg));
    local dateFlags = ImGuiComboFlags_PopupAlignLeft;
    local dateOpened, dateCentered, dateListW = widgets.begin_labels_combo('##historydate', dateShown, dateLabels, dateFlags);
    if (dateOpened) then
        for index, option in ipairs(dateFormats) do
            if (widgets.labels_combo_option('historydate' .. index, option.label, option.order == history_date_order(cfg), dateListW)) then
                cfg.historyDateOrder = option.order;
                cfg.historyDateFormat = history_date_format_for(option.order, history_date_sep(cfg));
                reformat_history(cfg, save, state);
            end
        end
        widgets.end_labels_combo(dateOpened, dateCentered);
    end
    imgui.SameLine();
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label('Separator');
    imgui.SameLine();
    local sep = history_date_sep(cfg);
    local sepFlags = ImGuiComboFlags_PopupAlignLeft;
    local sepOpened, sepCentered, sepListW = widgets.begin_labels_combo('##historydatesep', sep, HISTORY_DATE_SEPS, sepFlags);
    if (sepOpened) then
        for index, option in ipairs(HISTORY_DATE_SEPS) do
            if (widgets.labels_combo_option('historydatesep' .. index, option, option == sep, sepListW)) then
                cfg.historyDateSep = option;
                cfg.historyDateFormat = history_date_format_for(history_date_order(cfg), option);
                reformat_history(cfg, save, state);
            end
        end
        widgets.end_labels_combo(sepOpened, sepCentered);
    end
    imgui.Spacing();
    draw_format_combo('Time', 'historytime', cfg.historyTimeFormat, HISTORY_TIME_FORMATS, function(id)
        cfg.historyTimeFormat = id;
        reformat_history(cfg, save, state);
    end);
    imgui.Spacing();
    if (state.historyMaxBuf == nil) then
        state.historyMaxBuf = T{ history_max(cfg) };
    end
    state.historyMaxBuf[1] = history_max(cfg);
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label('Max Entries');
    imgui.SameLine();
    imgui.SetNextItemWidth(px(220));
    local maxChanged = false;
    if (imgui.SliderInt ~= nil) then
        local ok, changed = pcall(imgui.SliderInt, '##historymax', state.historyMaxBuf, 200, 10000);
        if (ok) then
            maxChanged = changed == true;
        else
            maxChanged = imgui.SliderInt('##historymax', state.historyMaxBuf, 200, 10000) == true;
        end
    elseif (imgui.SliderFloat ~= nil) then
        local ok, changed = pcall(imgui.SliderFloat, '##historymax', state.historyMaxBuf, 200, 10000, '%.0f');
        if (ok) then
            maxChanged = changed == true;
        end
    end
    local snapped = math.floor(((tonumber(state.historyMaxBuf[1]) or 1000) / 100) + 0.5) * 100;
    if (snapped < 200) then
        snapped = 200;
    elseif (snapped > 10000) then
        snapped = 10000;
    end
    if (snapped ~= state.historyMaxBuf[1]) then
        state.historyMaxBuf[1] = snapped;
        maxChanged = true;
    end
    if (maxChanged and cfg.historyMax ~= snapped) then
        cfg.historyMax = snapped;
        trim_history(cfg);
        bump_list(state, 'history');
        save();
    end
    imgui.SameLine();
    imgui.Text(tostring(snapped));
    imgui.Spacing();
    widgets.helper_text('Formats timestamps and how many History entries to keep.');
end

local function draw_section_tabs(state)
    local startX = imgui.GetCursorPosX();
    local avail = remaining_width();
    local count = #SECTIONS;
    local slot = math.floor(avail / math.max(1, count));
    local extra = avail - slot * count;
    for index, section in ipairs(SECTIONS) do
        if (index > 1) then
            imgui.SameLine(0, 0);
        end
        local width = slot;
        if (index <= extra) then
            width = width + 1;
        end
        if (section_tab(section.label, 'section' .. section.id, state.section == section.id, width)) then
            state.section = section.id;
        end
    end
    if (imgui.SetCursorPos ~= nil) then
        imgui.SetCursorPosX(startX);
    end
end

local function note_tab_drag(kind, index)
    if (imgui.IsItemActive == nil or imgui.IsMouseDragging == nil) then
        return;
    end
    if (imgui.IsItemActive() and imgui.IsMouseDragging(0, px(4))) then
        tabDrag.kind = kind;
        if (tabDrag.from == nil) then
            tabDrag.from = index;
        end
        tabDrag.moved = true;
    end
end

local function accept_tab_drop(kind, index, list)
    if (tabDrag.kind ~= kind or tabDrag.from == nil or tabDrag.from == index) then
        return;
    end
    if (imgui.IsItemHovered == nil or imgui.IsMouseDragging == nil) then
        return;
    end
    if (imgui.IsItemHovered() and imgui.IsMouseDragging(0, 0)) then
        move_item(list, tabDrag.from, index);
        tabDrag.from = index;
        tabDrag.moved = true;
    end
end

local function finish_tab_drag(save)
    if (imgui.IsMouseReleased == nil or not imgui.IsMouseReleased(0)) then
        return;
    end
    if (tabDrag.moved and save ~= nil) then
        save();
    end
    tabDrag.kind = nil;
    tabDrag.from = nil;
    tabDrag.moved = false;
end

local function seed_rename(state, tab)
    if (state.favRenameId ~= tab.id or state.favRename == nil) then
        state.favRenameId = tab.id;
        state.favRename = { tab.name or '' };
    end
end

local function apply_rename(tab, state, save)
    local shown = tostring((state.favRename and state.favRename[1]) or '');
    shown = (shown:gsub('^%s+', ''):gsub('%s+$', ''));
    if (shown == '') then
        return false;
    end
    tab.name = shown;
    save();
    return true;
end

local function menu_hit(label, enabled, width)
    if (width ~= nil and imgui.Selectable ~= nil) then
        if (enabled == false and imgui.BeginDisabled ~= nil) then
            pcall(imgui.BeginDisabled, true);
        end
        local picked = imgui.Selectable(label, false, 0, { width, 0 });
        if (enabled == false and imgui.EndDisabled ~= nil) then
            pcall(imgui.EndDisabled);
        end
        return picked == true or (picked ~= nil and picked ~= false and enabled ~= false);
    end
    if (imgui.MenuItem == nil) then
        if (enabled == false or imgui.Selectable == nil) then
            return false;
        end
        local picked = imgui.Selectable(label);
        return picked == true or (picked ~= nil and picked ~= false);
    end
    local hit = false;
    if (enabled == false) then
        local ok, result = pcall(imgui.MenuItem, label, nil, false, false);
        hit = ok and result == true;
    else
        local ok, result = pcall(imgui.MenuItem, label);
        if (not ok) then
            ok, result = pcall(imgui.MenuItem, label, nil, false, true);
        end
        hit = ok and (result == true or (result ~= nil and result ~= false));
    end
    return hit;
end

local function mouse_clicked(button)
    if (imgui.IsMouseClicked == nil) then
        return false;
    end
    local ok, clicked = pcall(imgui.IsMouseClicked, button or 0);
    return ok and clicked == true;
end

local function mouse_released(button)
    if (imgui.IsMouseReleased == nil) then
        return false;
    end
    local ok, released = pcall(imgui.IsMouseReleased, button or 0);
    return ok and released == true;
end

local function mouse_held(button)
    if (imgui.IsMouseDown == nil) then
        return false;
    end
    local ok, down = pcall(imgui.IsMouseDown, button or 0);
    return ok and down == true;
end

local function mouse_pos()
    if (imgui.GetMousePos ~= nil) then
        local a, b;
        local ok = pcall(function()
            a, b = imgui.GetMousePos();
        end);
        if (ok and a ~= nil) then
            return vec2(a, b);
        end
    end
    local io = imgui.GetIO ~= nil and imgui.GetIO() or nil;
    if (io ~= nil and io.MousePos ~= nil) then
        return vec2(io.MousePos);
    end
    return 0, 0;
end

-- Custom resize of the title+body shell. ImGui body resize can't grow up/left
-- because the body is pinned under a separate title bar.
local shellResize = nil;
local RESIZE_GRIP = 6;

local function update_shell_resize(cfg, titleX, titleY, width, bodyH, barH)
    local grip = px(RESIZE_GRIP);
    local totalH = bodyH + barH - 1;
    local x1, y1 = titleX, titleY;
    local x2, y2 = titleX + width, titleY + totalH;
    local mx, my = mouse_pos();
    local minW, minH = 320, 240;

    if (widgets.combo_open()) then
        shellResize = nil;
        return titleX, titleY, false;
    end

    local function on_edge(value, edge)
        return math.abs(value - edge) <= grip;
    end

    if (shellResize == nil and mouse_clicked(0) and not ui.modal_open()) then
        local hitL = on_edge(mx, x1) and my >= (y1 - grip) and my <= (y2 + grip);
        local hitR = on_edge(mx, x2) and my >= (y1 - grip) and my <= (y2 + grip);
        local hitT = on_edge(my, y1) and mx >= (x1 - grip) and mx <= (x2 + grip);
        local hitB = on_edge(my, y2) and mx >= (x1 - grip) and mx <= (x2 + grip);
        if (hitL or hitR or hitT or hitB) then
            shellResize = {
                L = hitL,
                R = hitR,
                T = hitT,
                B = hitB,
                mx = mx,
                my = my,
                x = titleX,
                y = titleY,
                w = cfg.windowW or 700,
                h = cfg.windowH or 550,
            };
        end
    end

    if (shellResize == nil) then
        return titleX, titleY, false;
    end

    if (mouse_held(0)) then
        local dx = mx - shellResize.mx;
        local dy = my - shellResize.my;
        local w = shellResize.w;
        local h = shellResize.h;
        local x = shellResize.x;
        local y = shellResize.y;
        local right = shellResize.x + shellResize.w * scale;
        local bottom = shellResize.y + shellResize.h * scale;

        if (shellResize.R) then
            w = math.max(minW, shellResize.w + dx / scale);
        end
        if (shellResize.B) then
            h = math.max(minH, shellResize.h + dy / scale);
        end
        if (shellResize.L) then
            w = math.max(minW, shellResize.w - dx / scale);
            x = right - w * scale;
        end
        if (shellResize.T) then
            h = math.max(minH, shellResize.h - dy / scale);
            y = bottom - h * scale;
        end

        cfg.windowW = math.floor(w + 0.5);
        cfg.windowH = math.floor(h + 0.5);
        cfg.windowX = math.floor(x + 0.5);
        cfg.windowY = math.floor(y + 0.5);
        return cfg.windowX, cfg.windowY, true;
    end

    if (mouse_released(0)) then
        shellResize = nil;
    end
    return titleX, titleY, false;
end

local function note_fav_menu(state, tab)
    if (imgui.IsItemClicked == nil) then
        return;
    end
    local ok, clicked = pcall(imgui.IsItemClicked, 1);
    if (not ok or clicked ~= true) then
        return;
    end
    local mx, my = mouse_pos();
    state.favMenuId = tab.id;
    state.favMenuPos = { mx, my };
    state.favMenuRequest = true;
end

local function fav_tab_menu(state, cfg)
    if (state.favMenuId == nil or imgui.BeginPopup == nil) then
        return;
    end
    local tab = favorite_tab(cfg, state.favMenuId);
    if (tab == nil or tab.id ~= state.favMenuId) then
        state.favMenuRequest = false;
        state.favMenuId = nil;
        return;
    end
    if (state.favMenuRequest) then
        if (mouse_held(1) or mouse_held(0)) then
            return;
        end
        if (imgui.OpenPopup ~= nil) then
            imgui.OpenPopup('###gmhelper_favmenu');
        end
        state.favMenuRequest = false;
    end
    local pos = state.favMenuPos or { 0, 0 };
    local cond = ImGuiCond_Always or 1;
    if (imgui.SetNextWindowDockID ~= nil) then
        pcall(imgui.SetNextWindowDockID, 0, cond);
    end
    -- Top-left of the menu at the cursor so it opens toward the bottom-right.
    if (not pcall(imgui.SetNextWindowPos, pos, cond, { 0, 0 })) then
        pcall(imgui.SetNextWindowPos, pos, cond);
    end
    local opened = false;
    local ok, result = pcall(imgui.BeginPopup, '###gmhelper_favmenu');
    opened = ok and (result == true or (result ~= nil and result ~= false));
    if (not opened) then
        return;
    end
    local itemW = px(84);
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_SelectableTextAlign ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_SelectableTextAlign, { 0.5, 0.5 });
    end
    if (menu_hit('Rename', true, itemW)) then
        state.favRenameId = tab.id;
        state.favRename = { tab.name or '' };
        state.favRenameRequest = true;
        state.favMenuId = nil;
        if (imgui.CloseCurrentPopup ~= nil) then
            imgui.CloseCurrentPopup();
        end
    end
    if (menu_hit('Delete', #cfg.favoriteTabs > 1, itemW)) then
        state.favDeleteId = tab.id;
        state.favDeleteName = tab.name or 'this tab';
        state.favDeleteRequest = true;
        state.favMenuId = nil;
        if (imgui.CloseCurrentPopup ~= nil) then
            imgui.CloseCurrentPopup();
        end
    end
    if (imgui.PopStyleVar ~= nil and ImGuiStyleVar_SelectableTextAlign ~= nil) then
        imgui.PopStyleVar();
    end
    imgui.EndPopup();
end

local function next_fav_name(cfg)
    local used = {};
    for _, tab in ipairs(cfg.favoriteTabs) do
        used[tab.name] = true;
    end
    local number = #cfg.favoriteTabs + 1;
    local name = 'Tab ' .. tostring(number);
    while (used[name]) do
        number = number + 1;
        name = 'Tab ' .. tostring(number);
    end
    return name;
end

local function add_fav_tab(state, cfg, save)
    cfg.nextFavId = (cfg.nextFavId or 1) + 1;
    local tab = T{
        id = 'tab' .. tostring(cfg.nextFavId),
        name = next_fav_name(cfg),
        commands = T{},
    };
    cfg.favoriteTabs[#cfg.favoriteTabs + 1] = tab;
    state.favTab = tab.id;
    save();
end

local function draw_group_tabs(state, cfg)
    ensure_group_order(cfg);
    local startX = imgui.GetCursorPosX();
    local startY = imgui.GetCursorPosY();
    local indent = px(ROUND);
    local groups = ordered_groups(cfg);
    local usable = math.max(1, remaining_width() - indent * 2);
    local ideal = math.max(px(56), letter_tab_width());
    local perRow = math.max(1, math.min(#groups, math.floor(usable / ideal)));
    local width = math.floor(usable / perRow);
    local rowH = px(30);
    for index, group in ipairs(groups) do
        local column = (index - 1) % perRow;
        local row = math.floor((index - 1) / perRow);
        if (column == 0 and imgui.SetCursorPos ~= nil) then
            imgui.SetCursorPos({ startX + indent, startY + row * rowH });
        elseif (index > 1) then
            imgui.SameLine(0, 0);
        end
        local clicked = nav_button(group.label, 'nav' .. group.id, state.page == group.id, width);
        note_tab_drag('group', index);
        accept_tab_drop('group', index, cfg.groupOrder);
        if (clicked and not tabDrag.moved) then
            state.page = group.id;
            state.section = 'commands';
        end
    end
    if (imgui.SetCursorPos ~= nil) then
        local rows = math.max(1, math.ceil(#groups / perRow));
        imgui.SetCursorPos({ startX, startY + rows * rowH - px(GAP) });
        submit_space(0);
    end
end

local function draw_fav_tabs(state, cfg, save)
    ensure_favorite_tabs(cfg);
    local startX = imgui.GetCursorPosX();
    local startY = imgui.GetCursorPosY();
    local indent = px(ROUND);
    if (imgui.SetCursorPosX ~= nil) then
        imgui.SetCursorPosX(startX + indent);
    end
    local usable = math.max(1, remaining_width() - indent);
    local right = startX + indent + usable;
    local cursorX = startX + indent;
    local row = 0;
    local rowH = px(30);
    local current = selected_fav_tab(state, cfg);
    for index, tab in ipairs(cfg.favoriteTabs) do
        local width = math.max(px(48), math.ceil(text_px(tab.name or '') + px(20)));
        if (cursorX > startX + indent and cursorX + width > right and imgui.SetCursorPos ~= nil) then
            row = row + 1;
            cursorX = startX + indent;
            imgui.SetCursorPos({ cursorX, startY + row * rowH });
        elseif (index > 1) then
            imgui.SameLine(0, 0);
        end
        local clicked = nav_button(tab.name or 'Tab', 'favtab' .. tab.id, current.id == tab.id, width);
        cursorX = cursorX + width;
        note_tab_drag('fav', index);
        accept_tab_drop('fav', index, cfg.favoriteTabs);
        note_fav_menu(state, tab);
        if (clicked and not tabDrag.moved) then
            state.favTab = tab.id;
            state.section = 'favorites';
        end
    end
    local addW = px(30);
    if (cursorX > startX + indent and cursorX + addW > right and imgui.SetCursorPos ~= nil) then
        row = row + 1;
        cursorX = startX + indent;
        imgui.SetCursorPos({ cursorX, startY + row * rowH });
    else
        imgui.SameLine(0, 0);
    end
    if (nav_button('+', 'favtabadd', false, px(30)) and not tabDrag.moved) then
        add_fav_tab(state, cfg, save);
    end
    if (tabDrag.kind == 'fav' and tabDrag.from ~= nil and imgui.IsItemHovered ~= nil and imgui.IsItemHovered() and imgui.IsMouseDragging ~= nil and imgui.IsMouseDragging(0, 0)) then
        local last = #cfg.favoriteTabs;
        if (tabDrag.from ~= last) then
            move_item(cfg.favoriteTabs, tabDrag.from, last);
            tabDrag.from = last;
            tabDrag.moved = true;
        end
    end
    if (imgui.SetCursorPos ~= nil) then
        imgui.SetCursorPos({ startX, startY + (row + 1) * rowH - px(GAP) });
        submit_space(0);
    end
    fav_tab_menu(state, cfg);
end

local function paint_menu_label(label)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    local x1, y1, x2, y2 = last_item_rect();
    if (draw == nil or draw.AddText == nil) then
        return;
    end
    local tw, th = text_width(label), 13;
    if (imgui.CalcTextSize ~= nil) then
        local size, second = imgui.CalcTextSize(label);
        if (type(size) == 'number') then
            th = second or 13;
        else
            th = size.y or size[2] or 13;
        end
    end
    pcall(draw.AddText, draw, {
        x1 + math.max(0, ((x2 - x1) - tw) * 0.5),
        y1 + math.max(0, ((y2 - y1) - th) * 0.5),
    }, theme.col32(theme.colors.text), label);
end

local function screen_size()
    local width, height = 1280, 720;
    if (imgui.GetIO == nil) then
        return width, height;
    end
    local ok, io = pcall(imgui.GetIO);
    if (not ok or io == nil or io.DisplaySize == nil) then
        return width, height;
    end
    local size = io.DisplaySize;
    width = size.x or size[1] or width;
    height = size.y or size[2] or height;
    return width, height;
end

local function center_next_window()
    local width, height = screen_size();
    local cond = ImGuiCond_Appearing or 8;
    if (not pcall(imgui.SetNextWindowPos, { width * 0.5, height * 0.5 }, cond, { 0.5, 0.5 })) then
        pcall(imgui.SetNextWindowPos, { width * 0.5, height * 0.5 }, cond);
    end
end

local function favorite_picker(cfg, choiceId)
    ensure_favorite_tabs(cfg);
    local shown = favorite_tab(cfg, choiceId).name or 'Default';
    local tabLabels = {};
    for _, tab in ipairs(cfg.favoriteTabs) do
        tabLabels[#tabLabels + 1] = tab.name or 'Tab';
    end
    local flags = ImGuiComboFlags_PopupAlignLeft;
    local opened, centered, listW = widgets.begin_labels_combo('##favpicktab', shown, tabLabels, flags, 'fill');
    local picked = choiceId;
    if (opened) then
        for _, tab in ipairs(cfg.favoriteTabs) do
            if (widgets.labels_combo_option('favpick' .. tab.id, tab.name or 'Tab', tab.id == picked, listW)) then
                picked = tab.id;
            end
        end
        widgets.end_labels_combo(opened, centered);
    end
    return picked;
end

local function center_buttons(widths)
    local gap = px(GAP);
    local total = 0;
    for index, width in ipairs(widths) do
        total = total + width;
        if (index > 1) then
            total = total + gap;
        end
    end
    local avail = remaining_width();
    if (avail > total and imgui.SetCursorPosX ~= nil) then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + (avail - total) * 0.5);
    end
end

local function modal_button_width()
    local available = math.max(1, remaining_width() - px(GAP));
    return math.max(1, math.min(px(110), math.floor(available * 0.5)));
end

local function claim_modal_capture()
    modalActive = true;
    if (imgui.SetNextFrameWantCaptureMouse ~= nil) then
        pcall(imgui.SetNextFrameWantCaptureMouse, true);
    end
    if (imgui.SetNextFrameWantCaptureKeyboard ~= nil) then
        pcall(imgui.SetNextFrameWantCaptureKeyboard, true);
    end
end

local modalHeights = {};
local modalBodyStyles = 0;
local modalBodyFont = false;
local NO_SAVED = ImGuiWindowFlags_NoSavedSettings or 256;

local function draw_modal_title_label(label)
    local glyph = px(TITLE_GLYPH);
    local rowY = imgui.GetCursorPosY();
    local startX = imgui.GetCursorPosX();
    local textH = 13;
    if (imgui.CalcTextSize ~= nil) then
        local size, second = imgui.CalcTextSize(label or '');
        if (type(size) == 'number') then
            textH = second or 13;
        else
            textH = size.y or size[2] or 13;
        end
    end
    if (not fontScaled) then
        textH = textH * scale;
    end
    local textY = rowY + math.max(0, (glyph - textH) * 0.5);
    imgui.SetCursorPos({ startX, textY });
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text);
    imgui.Text(label or '');
    imgui.PopStyleColor();
    submit_space(0);
end

local function paint_modal_dim(sw, sh)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    if (draw ~= nil and draw.AddRectFilled ~= nil) then
        local x, y = window_pos();
        pcall(draw.AddRectFilled, draw, { x, y }, { x + sw, y + sh }, theme.col32({ 0.02, 0.01, 0.01, 0.55 }));
    end
    if (imgui.InvisibleButton ~= nil) then
        imgui.InvisibleButton('##gmhelper_modal_dim', { sw, sh });
    else
        submit_space(sh);
    end
end

-- Title + body are separate windows, same chrome as the main GM Helper frame.
local function begin_modal(id, title, request)
    if (request and mouse_held(0)) then
        return false;
    end
    claim_modal_capture();

    local sw, sh = screen_size();
    local _, padX, padY, barH = title_metrics();
    local pad = px(PAD);
    local maxContentW = math.max(1, sw - pad * 2 - px(32));
    local contentW = math.min(px(320), maxContentW);
    local modalW = contentW + pad * 2;
    local bodyH = modalHeights[id] or px(120);
    local totalH = barH + bodyH - 1;
    local left = math.floor((sw - modalW) * 0.5);
    local top = math.floor((sh - totalH) * 0.5);
    local rounding = px(ROUND);
    local cond = ImGuiCond_Always or 1;
    local open = { true };

    if (imgui.SetNextWindowDockID ~= nil) then
        pcall(imgui.SetNextWindowDockID, 0, cond);
    end
    imgui.SetNextWindowPos({ 0, 0 }, cond);
    imgui.SetNextWindowSize({ sw, sh }, cond);
    imgui.SetNextWindowBgAlpha(0);
    local dimFlags = bor_flags(
        ImGuiWindowFlags_NoTitleBar,
        NO_RESIZE,
        NO_MOVE,
        NO_SCROLL,
        NO_SCROLL_MOUSE,
        NO_BACKGROUND,
        NO_SAVED,
        NO_DOCK,
        ImGuiWindowFlags_NoFocusOnAppearing or 4096
    );
    if (imgui.Begin('###gmhelper_modal_dim_' .. id, open, dimFlags)) then
        paint_modal_dim(sw, sh);
    end
    imgui.End();

    if (imgui.SetNextWindowDockID ~= nil) then
        pcall(imgui.SetNextWindowDockID, 0, cond);
    end
    imgui.SetNextWindowPos({ left, top }, cond);
    imgui.SetNextWindowSize({ modalW, barH }, cond);
    imgui.SetNextWindowBgAlpha(0);
    local titleStyles = push_styles({
        { ImGuiStyleVar_WindowPadding, { padX, padY } },
        { ImGuiStyleVar_WindowRounding, 0 },
        { ImGuiStyleVar_WindowBorderSize, 0 },
    });
    local titleFlags = bor_flags(
        ImGuiWindowFlags_NoTitleBar,
        NO_RESIZE,
        NO_MOVE,
        NO_SCROLL,
        NO_SCROLL_MOUSE,
        NO_BACKGROUND,
        NO_SAVED,
        NO_DOCK
    );
    if (imgui.Begin('###gmhelper_modal_title_' .. id, open, titleFlags)) then
        local titleFont = push_font();
        fontScaled = titleFont;
        paint_panel(rounding, ROUND_TOP, theme.colors.glass, theme.colors.accentSoft);
        draw_modal_title_label(title);
        pop_font(titleFont);
    end
    imgui.End();
    pop_styles(titleStyles);

    if (imgui.SetNextWindowDockID ~= nil) then
        pcall(imgui.SetNextWindowDockID, 0, cond);
    end
    imgui.SetNextWindowPos({ left, top + barH - 1 }, cond);
    -- Width is fixed; height hugs content (stored height is only for centering).
    if (imgui.SetNextWindowSizeConstraints ~= nil) then
        pcall(imgui.SetNextWindowSizeConstraints, { modalW, 0 }, { modalW, sh });
    end
    imgui.SetNextWindowSize({ modalW, 0 }, cond);
    imgui.SetNextWindowBgAlpha(0);
    modalBodyStyles = push_styles({
        { ImGuiStyleVar_WindowPadding, { pad, pad } },
        { ImGuiStyleVar_WindowRounding, 0 },
        { ImGuiStyleVar_WindowBorderSize, 0 },
        { ImGuiStyleVar_ItemSpacing, { px(GAP), px(GAP) } },
    });
    local bodyFlags = bor_flags(
        ImGuiWindowFlags_NoTitleBar,
        NO_RESIZE,
        NO_MOVE,
        NO_SCROLL,
        NO_SCROLL_MOUSE,
        NO_BACKGROUND,
        NO_SAVED,
        NO_DOCK,
        ImGuiWindowFlags_AlwaysAutoResize or 64
    );
    local opened = false;
    if (imgui.Begin('###gmhelper_modal_body_' .. id, open, bodyFlags)) then
        opened = true;
        modalBodyFont = push_font();
        fontScaled = modalBodyFont;
        paint_panel(rounding, ROUND_BOTTOM, theme.colors.glass, theme.colors.border);
    else
        imgui.End();
        pop_styles(modalBodyStyles);
        modalBodyStyles = 0;
    end
    return opened;
end

local function end_modal(id)
    if (imgui.GetWindowHeight ~= nil) then
        local height = imgui.GetWindowHeight();
        if (type(height) == 'number' and height > 0) then
            modalHeights[id] = height;
        end
    end
    pop_font(modalBodyFont);
    modalBodyFont = false;
    imgui.End();
    pop_styles(modalBodyStyles);
    modalBodyStyles = 0;
end

local function delete_fav_tab(state, cfg, save, tabId)
    if (#cfg.favoriteTabs <= 1) then
        return;
    end
    local nextTabs = {};
    for _, saved in ipairs(cfg.favoriteTabs) do
        if (saved.id ~= tabId) then
            nextTabs[#nextTabs + 1] = saved;
        end
    end
    cfg.favoriteTabs = nextTabs;
    if (state.favTab == tabId) then
        state.favTab = nextTabs[1] and nextTabs[1].id or nil;
    end
    bump_list(state, 'favorites');
    save();
end

local function draw_fav_modal(state, cfg, save)
    if (state.favPick == nil) then
        return;
    end
    if (state.favPickRequest and mouse_held(0)) then
        return;
    end
    local request = state.favPickRequest == true;
    if (not begin_modal('favpick', 'Favorite', request)) then
        return;
    end
    state.favPickRequest = false;
    widgets.helper_text('Choose a favorites tab for this command.', theme.colors.text);
    imgui.Spacing();
    state.favPick.tabId = favorite_picker(cfg, state.favPick.tabId);
    imgui.Spacing();
    local buttonW = modal_button_width();
    center_buttons({ buttonW, buttonW });
    if (widgets.button('Confirm', 'favpickconfirm', buttonW, 'primary')) then
        add_favorite_to(
            cfg,
            state.favPick.tabId,
            state.favPick.commandId,
            state.favPick.values,
            save,
            state
        );
        state.favTab = state.favPick.tabId;
        state.favPick = nil;
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'favpickcancel', buttonW, 'secondary')) then
        state.favPick = nil;
    end
    end_modal('favpick');
end

local function draw_rename_modal(state, cfg, save)
    if (state.favRenameRequest ~= true and state.favRenameId == nil) then
        return;
    end
    local tab = favorite_tab(cfg, state.favRenameId);
    if (tab == nil) then
        state.favRenameRequest = false;
        state.favRenameId = nil;
        return;
    end
    if (state.favRenameRequest and mouse_held(0)) then
        return;
    end
    local request = state.favRenameRequest == true;
    if (not begin_modal('favrename', 'Rename Tab', request)) then
        return;
    end
    state.favRenameRequest = false;
    widgets.helper_text('Rename this favorites tab.', theme.colors.text);
    imgui.Spacing();
    imgui.SetNextItemWidth(-1);
    local enterFlags = ImGuiInputTextFlags_EnterReturnsTrue or 64;
    local result = nil;
    local ok, changed = pcall(imgui.InputText, '##favrenamefield', state.favRename, 64, enterFlags);
    if (ok) then
        result = changed;
    else
        result = imgui.InputText('##favrenamefield', state.favRename, 64);
    end
    if (type(result) == 'string') then
        state.favRename[1] = result;
        result = false;
    end
    imgui.Spacing();
    local buttonW = modal_button_width();
    center_buttons({ buttonW, buttonW });
    if (widgets.button('Confirm', 'favrenameconfirm', buttonW, 'primary') or result == true) then
        if (apply_rename(tab, state, save)) then
            state.favRenameId = nil;
            state.favRenameRequest = false;
        end
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'favrenamecancel', buttonW, 'secondary')) then
        state.favRenameId = nil;
        state.favRenameRequest = false;
    end
    end_modal('favrename');
end

local function draw_delete_modal(state, cfg, save)
    if (state.favDeleteRequest ~= true and state.favDeleteId == nil) then
        return;
    end
    if (#cfg.favoriteTabs <= 1) then
        state.favDeleteRequest = false;
        state.favDeleteId = nil;
        return;
    end
    if (state.favDeleteRequest and mouse_held(0)) then
        return;
    end
    local request = state.favDeleteRequest == true;
    if (not begin_modal('favdelete', 'Delete Tab', request)) then
        return;
    end
    state.favDeleteRequest = false;
    local name = state.favDeleteName or 'this tab';
    imgui.Text('Delete "' .. name .. '"?');
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.peach);
    local warn = 'Commands in this tab will be removed from favorites.';
    if (imgui.TextWrapped ~= nil) then
        imgui.TextWrapped(warn);
    elseif (imgui.PushTextWrapPos ~= nil) then
        local wrapX = imgui.GetCursorPosX() + remaining_width();
        imgui.PushTextWrapPos(wrapX);
        imgui.Text(warn);
        imgui.PopTextWrapPos();
    else
        imgui.Text('Commands in this tab will be');
        imgui.Text('removed from favorites.');
    end
    imgui.PopStyleColor();
    imgui.Spacing();
    local buttonW = modal_button_width();
    center_buttons({ buttonW, buttonW });
    if (widgets.button('Delete', 'favdeleteconfirm', buttonW, 'danger')) then
        delete_fav_tab(state, cfg, save, state.favDeleteId);
        state.favDeleteId = nil;
        state.favDeleteRequest = false;
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'favdeletecancel', buttonW, 'secondary')) then
        state.favDeleteId = nil;
        state.favDeleteRequest = false;
    end
    end_modal('favdelete');
end

local function draw_modals(state, cfg, save)
    draw_fav_modal(state, cfg, save);
    draw_rename_modal(state, cfg, save);
    draw_delete_modal(state, cfg, save);
end

local function draw_tabs(state, cfg, save)
    sync_nav(state);
    ensure_favorite_tabs(cfg);
    ensure_group_order(cfg);
    local lift = px(PAD) - px(GAP) - 1;
    if (lift > 0 and imgui.SetCursorPosY ~= nil and imgui.GetCursorPosY ~= nil) then
        imgui.SetCursorPosY(imgui.GetCursorPosY() - lift);
    end
    draw_section_tabs(state);
    if (state.section == 'commands' or state.section == 'favorites' or state.section == 'history') then
        if (state.section == 'favorites') then
            local tab = selected_fav_tab(state, cfg);
            draw_search_bar('favsearch' .. tab.id, fav_search(state, tab.id));
        else
            draw_page_search(state);
        end
    end
    if (state.section == 'commands') then
        draw_group_tabs(state, cfg);
    elseif (state.section == 'favorites') then
        draw_fav_tabs(state, cfg, save);
    end
    finish_tab_drag(save);
end

function ui.draw(state, cfg, save)
    scale = clamp_scale(cfg.scale);
    sync_nav(state);
    modalActive = false;
    local section = state.section;
    local page = state.page;
    local pad = px(PAD);
    local _, padX, padY, barH = title_metrics();
    local totalW = tonumber(cfg.windowW) or 700;
    local totalH = tonumber(cfg.windowH) or 550;
    if (totalW < 320) then
        totalW = 320;
    end
    if (totalH < 240) then
        totalH = 240;
    end
    local width = math.floor(totalW * scale + 0.5);
    -- Total height includes the title bar.
    local bodyH = math.max(px(120), math.floor(totalH * scale + 0.5) - barH + 1);
    local scaleChanged = state.drawnScale ~= scale;
    state.drawnScale = scale;
    local condAlways = ImGuiCond_Always or 1;
    local rounding = px(ROUND);
    theme.push();

    local sw, sh = screen_size();
    local totalDrawnH = bodyH + barH - 1;
    local titleX = state.pendingWindowX or cfg.windowX;
    local titleY = state.pendingWindowY or cfg.windowY;
    local placeOnce = state.applyWindowPos ~= false;
    if (titleX == nil or titleY == nil) then
        titleX = math.floor((sw - width) * 0.5);
        titleY = math.floor((sh - totalDrawnH) * 0.5);
        cfg.windowX = titleX;
        cfg.windowY = titleY;
        placeOnce = true;
    else
        titleX = math.floor(titleX + 0.5);
        titleY = math.floor(titleY + 0.5);
    end
    local resizing = false;
    local dragging = false;
    titleX, titleY, resizing = update_shell_resize(cfg, titleX, titleY, width, bodyH, barH);
    if (resizing) then
        totalW = cfg.windowW or totalW;
        totalH = cfg.windowH or totalH;
        width = math.floor(totalW * scale + 0.5);
        bodyH = math.max(px(120), math.floor(totalH * scale + 0.5) - barH + 1);
        placeOnce = true;
        state.applyWindowSize = true;
        state.geomDirty = true;
    end
    local open = { true };
    local titleFlags = bor_flags(ImGuiWindowFlags_NoTitleBar, NO_RESIZE, NO_SCROLL, NO_SCROLL_MOUSE, NO_BACKGROUND, NO_DOCK);
    if (resizing) then
        titleFlags = bit.bor(titleFlags, NO_MOVE);
    end

    -- Let ImGui move the title natively, then anchor the body to its current position.
    if (imgui.SetNextWindowDockID ~= nil) then
        pcall(imgui.SetNextWindowDockID, 0, condAlways);
    end
    if (placeOnce or resizing) then
        imgui.SetNextWindowPos({ titleX, titleY }, condAlways);
    end
    if (placeOnce) then
        state.applyWindowPos = false;
    end
    imgui.SetNextWindowSize({ width, barH }, condAlways);
    imgui.SetNextWindowBgAlpha(0);
    local titleStyles = push_styles({
        { ImGuiStyleVar_WindowPadding, { padX, padY } },
        { ImGuiStyleVar_WindowRounding, 0 },
        { ImGuiStyleVar_WindowBorderSize, 0 },
    });
    local titleFont = false;
    if (imgui.Begin('###gmhelper_title', open, titleFlags)) then
        titleFont = push_font();
        fontScaled = titleFont;
        widgets.configure(scale, fontScaled);
        widgets.sync_widths(commands);

        if (not resizing and imgui.GetWindowPos ~= nil) then
            local nextX, nextY = window_pos();
            nextX = math.floor(nextX + 0.5);
            nextY = math.floor(nextY + 0.5);
            if (nextX ~= titleX or nextY ~= titleY) then
                titleX = nextX;
                titleY = nextY;
                state.pendingWindowX = nextX;
                state.pendingWindowY = nextY;
                state.geomDirty = true;
                state.shellDragging = mouse_held(0);
            elseif (not mouse_held(0)) then
                state.shellDragging = false;
            end
        else
            state.shellDragging = false;
        end
        dragging = state.shellDragging == true;

        local fill, edge = title_chrome(state.panelFocused);
        paint_panel(rounding, state.collapsed and ROUND_ALL or ROUND_TOP, fill, edge);
        draw_title(state);
        state.panelFocused = window_focused() or dragging or resizing;
        pop_font(titleFont);
    end
    imgui.End();
    pop_styles(titleStyles);

    if (not state.collapsed and state.visible ~= false) then
        if (imgui.SetNextWindowDockID ~= nil) then
            pcall(imgui.SetNextWindowDockID, 0, condAlways);
        end
        imgui.SetNextWindowPos({ titleX, titleY + barH - 1 }, condAlways);
        if (state.applyWindowSize ~= false or scaleChanged or resizing) then
            imgui.SetNextWindowSize({ width, bodyH }, condAlways);
            if (not scaleChanged and not resizing) then
                state.applyWindowSize = false;
            end
        end
        imgui.SetNextWindowBgAlpha(0);
        local bodyStyles = push_styles({
            { ImGuiStyleVar_WindowPadding, { pad, pad } },
            { ImGuiStyleVar_WindowRounding, 0 },
            { ImGuiStyleVar_WindowBorderSize, 0 },
            { ImGuiStyleVar_FramePadding, { px(10), px(6) } },
            { ImGuiStyleVar_ItemSpacing, { px(GAP), px(GAP) } },
            { ImGuiStyleVar_ItemInnerSpacing, { px(6), px(4) } },
        });
        local bodyFlags = bor_flags(ImGuiWindowFlags_NoTitleBar, NO_RESIZE, NO_MOVE, NO_SCROLL, NO_SCROLL_MOUSE, NO_BACKGROUND, NO_FRONT, NO_DOCK);
        local bodyFont = false;
        if (imgui.Begin('###gmhelper_body', open, bodyFlags)) then
            bodyFont = push_font();
            fontScaled = bodyFont;
            widgets.configure(scale, fontScaled);
            paint_panel(rounding, ROUND_BOTTOM);
            if (scaleChanged or resizing) then
                state.skipSizeSample = true;
            elseif (not state.skipSizeSample and imgui.GetWindowWidth ~= nil and imgui.GetWindowHeight ~= nil and scale > 0) then
                local sampledW = imgui.GetWindowWidth();
                local sampledH = imgui.GetWindowHeight();
                if (sampledW > 0 and sampledH > 0) then
                    local nextW = math.floor(sampledW / scale + 0.5);
                    local nextH = math.floor((sampledH + barH - 1) / scale + 0.5);
                    if (nextW ~= cfg.windowW or nextH ~= cfg.windowH) then
                        cfg.windowW = nextW;
                        cfg.windowH = nextH;
                        state.geomDirty = true;
                    end
                end
            else
                state.skipSizeSample = false;
            end
            if (window_focused()) then
                state.panelFocused = true;
            end
            if (cfg.welcomeAccepted ~= true) then
                draw_welcome(cfg, save);
            else
                expire_errors(state);
                draw_tabs(state, cfg, save);
                local query = trim_query(state.search[1]);
                widgets.begin_child('page', { 0, 0 }, false);
                widgets.apply_load_scroll('page');
                widgets.apply_font();
                if (section == 'favorites') then
                    draw_favorites_page(state, cfg, save);
                elseif (section == 'presets') then
                    draw_presets_page(state, cfg, save);
                elseif (section == 'history') then
                    draw_history_page(state, cfg, save, query);
                elseif (section == 'settings') then
                    draw_settings_page(state, cfg, save);
                else
                    draw_category_page(state, cfg, save, page, query);
                end
                imgui.EndChild();
            end
            pop_font(bodyFont);
        end
        imgui.End();
        pop_styles(bodyStyles);
    end
    if (state.geomDirty and imgui.IsMouseReleased ~= nil and imgui.IsMouseReleased(0)) then
        state.geomDirty = false;
        if (state.pendingWindowX ~= nil and state.pendingWindowY ~= nil) then
            cfg.windowX = state.pendingWindowX;
            cfg.windowY = state.pendingWindowY;
            state.pendingWindowX = nil;
            state.pendingWindowY = nil;
        end
        save();
    end
    draw_modals(state, cfg, save);
    theme.pop();
end

return ui;
