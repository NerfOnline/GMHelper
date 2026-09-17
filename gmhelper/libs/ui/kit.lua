--[[
* GM Helper UI shared helpers.
]]

require('common');

local imgui = require('imgui');
local commands = require('data.commands');
local listload = require('libs.listload');
local say = require('libs.say');
local store = require('libs.store');
local tell = require('libs.tell');
local theme = require('libs.theme');
local widgets = require('libs.widgets');

local kit = {};

kit.GROUPS = {
    { id = 'Player', label = 'Player' },
    { id = 'Combat', label = 'Combat' },
    { id = 'Items', label = 'Items' },
    { id = 'Progression', label = 'Progress' },
    { id = 'World', label = 'World' },
    { id = 'Entities', label = 'Entity' },
    { id = 'Other', label = 'Other' },
};

kit.modalActive = false;

kit.labels = {};

kit.EXEC_W = 88;

kit.GAP = 8;

kit.LINE_H = 28;

kit.LIST_GAP_Y = 4;

kit.TITLE_PAD_X = 12;

kit.TITLE_PAD_Y = 8;

kit.TITLE_GLYPH = 16;

kit.ROUND = 0;

kit.PAD = 16;

kit.NO_RESIZE = ImGuiWindowFlags_NoResize or 2;

kit.scale = 1;

kit.fontScaled = false;

function kit.vec_x(value)
    if (value == nil) then
        return 0;
    end
    if (type(value) == 'table' or type(value) == 'userdata') then
        return value.x or value[1] or 0;
    end
    return value;
end

function kit.remaining_width()
    if (kit._ghostRemainW ~= nil) then
        return kit._ghostRemainW;
    end
    if (imgui.GetContentRegionAvail ~= nil) then
        local avail, second = imgui.GetContentRegionAvail();
        if (type(avail) == 'number') then
            return avail;
        end
        local width = kit.vec_x(avail);
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

function kit.remaining_height()
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

function kit.submit_space(height)
    if (imgui.Dummy == nil) then
        return;
    end
    local size = { 0, height or 0 };
    if (not pcall(imgui.Dummy, size)) then
        pcall(imgui.Dummy, size[1], size[2]);
    end
end

function kit.align_right(width)
    local remaining = kit.remaining_width();
    if (remaining > width) then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + remaining - width);
    end
end

function kit.bag_for(store, command)
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

function kit.clear_bag(bag, command)
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

function kit.snapshot_bag(bag, command)
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

function kit.bag_for_entry(entry, command)
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

kit.SAMPLE_PLAYERS = { 'Nerf', 'Kupipi', 'Trion', 'Zeid', 'Lion', 'Prishe', 'Nashmeira', 'Lilith' };

kit.SAMPLE_WORDS = {
    player = kit.SAMPLE_PLAYERS,
    target = kit.SAMPLE_PLAYERS,
    target_player = kit.SAMPLE_PLAYERS,
    linkshell_name = { 'Phoenix', 'Valefor', 'Carbuncle', 'Diabolos' },
    currency_type = { 'gil', 'bayld', 'plaudits', 'mweya_plasm' },
    light_type = { 'pearl', 'azure', 'ruby', 'amber' },
    animationid = { '0', '12', '48', '90' },
};

function kit.hash_id(text)
    text = tostring(text or '');
    local h = 2166136261;
    for index = 1, #text do
        h = (h * 16777619 + text:byte(index)) % 2147483647;
    end
    return h;
end

function kit.pick_sample(list, salt)
    if (list == nil or #list == 0) then
        return nil;
    end
    return list[(salt % #list) + 1];
end

function kit.sample_field_value(field, salt)
    if (field ~= nil and field.example ~= nil and tostring(field.example) ~= '') then
        return tostring(field.example);
    end
    local key = tostring(field.key or ''):lower();
    local label = tostring(field.label or ''):lower();
    local named = kit.SAMPLE_WORDS[key] or kit.SAMPLE_WORDS[key:gsub('_player$', 'player')];
    if (named ~= nil) then
        return kit.pick_sample(named, salt);
    end
    if (key == 'color' or label == 'color') then
        return kit.pick_sample({ 'yellow', 'black', 'blue', 'red', 'green' }, salt);
    end
    if (key == 'head' or key == 'tail' or key == 'feet') then
        return key;
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
        if (cat == 'weather') then
            return tostring(salt % 20);
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
        if (key:find('minutes', 1, true) or key:find('offset', 1, true)) then
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
        return kit.pick_sample(kit.SAMPLE_PLAYERS, salt);
    end
    return kit.pick_sample({ 'alpha', 'bravo', 'test', 'demo', 'sample' }, salt) or 'test';
end

function kit.command_example(command)
    if (command == nil) then
        return '';
    end
    -- Prefer curated examples for well-known commands.
    if (command.id == 'chocobo') then
        return '!chocobo black head feet tail';
    end
    if (command.id == 'additem') then
        return '!additem 16555 1 512 5';
    end
    if (command.id == 'changejob') then
        return '!changejob WAR 75 1';
    end
    if (command.id == 'addeffect') then
        return '!addeffect refresh 5 60';
    end
    if (command.id == 'addcurrency') then
        return '!addcurrency bayld 1000';
    end
    local parts = { '!' .. command.id };
    local salt = kit.hash_id(command.id);
    for index, field in ipairs(command.fields or {}) do
        local key = tostring(field.key or '');
        local skipAug = field.optional
            and (field.example == nil or field.example == '')
            and (key:find('aug', 1, true) or key:find('^v%d') or key == 'trial');
        if (not skipAug) then
            parts[#parts + 1] = kit.sample_field_value(field, salt + index * 17);
        end
    end
    return table.concat(parts, ' ');
end

function kit.matches_query(command, query)
    if (query == '') then
        return true;
    end
    local hay = ('!%s %s %s'):format(command.id, command.desc or '', command.usage or ''):lower();
    return hay:find(query, 1, true) ~= nil;
end

function kit.hover_tip(desc, example)
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
        if (example:sub(1, 8) == 'Example:') then
            lines[#lines + 1] = example;
        else
            lines[#lines + 1] = 'Example: ' .. example;
        end
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

function kit.field_help_text(field)
    if (field == nil) then
        return '';
    end
    local help = '';
    if (field.help ~= nil and tostring(field.help) ~= '') then
        help = tostring(field.help);
    else
        local key = tostring(field.key or ''):lower();
        local label = tostring(field.label or field.key or 'value');
        if (field.kind == 'lookup') then
            local cat = tostring(field.lookup or 'entry');
            help = ('Select a %s from the list, or type its ID.'):format(cat:gsub('s$', ''));
        elseif (key == 'color') then
            help = 'Color name expected by this command (not a hex code), unless the command docs say otherwise.';
        elseif (key == 'master_0_1' or label:find('master', 1, true)) then
            help = 'Set to 1 to master the job; 0 or omit to skip.';
        elseif (key:find('aug', 1, true) == 1) then
            help = 'Augmentation ID number. Pair with the matching V# potency field.';
        elseif (key:match('^v%d$')) then
            help = 'Augmentation potency/value for the paired Aug field.';
        elseif (key == 'trial' or key == 'trialid') then
            help = 'Trial weapon trial ID number. Omit or 0 if none.';
        elseif (field.kind == 'number') then
            help = 'Numeric value for ' .. label .. '.';
        else
            help = 'Text value for ' .. label .. '.';
        end
    end
    if (tell.is_player_field(field) and help:find('Type Tell', 1, true) == nil) then
        help = help .. ' Type Tell to fill the last tell target (/tell, /t, or /r).';
    end
    return help;
end

function kit.field_example_text(command, field)
    if (field ~= nil and field.example ~= nil and tostring(field.example) ~= '') then
        return tostring(field.example);
    end
    local salt = kit.hash_id(tostring((command and command.id) or '') .. tostring(field and field.key or ''));
    return kit.sample_field_value(field, salt);
end

function kit.field_hover_tip(command, field)
    kit.hover_tip(kit.field_help_text(field), kit.field_example_text(command, field));
end

function kit.px(value)
    return math.floor(value * kit.scale + 0.5);
end

kit.fontBase = nil;

function kit.clamp_scale(value)
    value = tonumber(value) or 1;
    if (value < 0.1) then
        value = 0.1;
    elseif (value > 3) then
        value = 3;
    end
    return math.floor(value * 100 + 0.5) / 100;
end

function kit.push_font()
    if (imgui.PushFont ~= nil and imgui.GetFont ~= nil) then
        if (kit.fontBase == nil and imgui.GetFontSize ~= nil) then
            local size = imgui.GetFontSize();
            if (type(size) == 'number' and size > 0) then
                kit.fontBase = size;
            end
        end
        local font = imgui.GetFont();
        if (font ~= nil and kit.fontBase ~= nil) then
            local ok = pcall(imgui.PushFont, font, kit.fontBase * kit.scale);
            if (ok) then
                return true;
            end
        end
    end
    if (imgui.SetWindowFontScale ~= nil) then
        local ok = pcall(imgui.SetWindowFontScale, kit.scale);
        return ok == true;
    end
    return false;
end

function kit.pop_font(pushed)
    if (pushed and imgui.PopFont ~= nil) then
        pcall(imgui.PopFont);
    end
end

function kit.text_width(text)
    if (imgui.CalcTextSize ~= nil) then
        local size, second = imgui.CalcTextSize(text);
        if (type(size) == 'number') then
            return size;
        end
        return kit.vec_x(size) ~= 0 and kit.vec_x(size) or kit.vec_x(second);
    end
    return #tostring(text or '') * 7;
end

function kit.text_px(text)
    local width = kit.text_width(text);
    if (not kit.fontScaled) then
        width = width * kit.scale;
    end
    return width;
end

function kit.text_height()
    local height = 13;
    if (imgui.CalcTextSize ~= nil) then
        local size, second = imgui.CalcTextSize('Ag');
        if (type(size) == 'number') then
            height = second or 13;
        else
            height = size.y or size[2] or 13;
        end
    end
    if (not kit.fontScaled) then
        height = height * kit.scale;
    end
    return height;
end

function kit.row_metrics()
    local textH = kit.text_height();
    local controlH = textH + kit.px(6) * 2;
    local lineH = math.max(kit.px(kit.LINE_H), controlH);
    return textH, controlH, lineH;
end

function kit.begin_command_list_spacing()
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_ItemSpacing ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { kit.px(kit.GAP), kit.px(kit.LIST_GAP_Y) });
        return 1;
    end
    return 0;
end

function kit.end_command_list_spacing(pushed)
    if (pushed > 0 and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar(pushed);
    end
end

kit.tabDrag = { kind = nil, from = nil, moved = false };
kit.rowDrag = {
    kind = nil,
    from = nil,
    to = nil,
    label = nil,
    lineNum = nil,
    cmdText = nil,
    numW = nil,
    rowH = nil,
    list = nil,
    state = nil,
    listKey = nil,
    active = false,
    insertY = nil,
    insertX1 = nil,
    insertX2 = nil,
};

function kit.row_grab_width()
    return kit.px(16);
end

function kit.item_rect_min()
    if (imgui.GetItemRectMin == nil) then
        return nil, nil;
    end
    local a, b;
    local ok = pcall(function()
        a, b = imgui.GetItemRectMin();
    end);
    if (ok and a ~= nil) then
        return kit.vec2(a, b);
    end
    return nil, nil;
end

function kit.item_rect_max()
    if (imgui.GetItemRectMax == nil) then
        return nil, nil;
    end
    local a, b;
    local ok = pcall(function()
        a, b = imgui.GetItemRectMax();
    end);
    if (ok and a ~= nil) then
        return kit.vec2(a, b);
    end
    return nil, nil;
end

function kit.cursor_screen_pos()
    if (imgui.GetCursorScreenPos == nil) then
        return nil, nil;
    end
    local a, b;
    local ok = pcall(function()
        a, b = imgui.GetCursorScreenPos();
    end);
    if (ok and a ~= nil) then
        return kit.vec2(a, b);
    end
    return nil, nil;
end

function kit.draw_grab_bars(x1, centerY, x2)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    if (draw == nil or draw.AddRectFilled == nil or centerY == nil) then
        return;
    end
    local w = x2 - x1;
    local barW = math.min(kit.px(10), math.max(kit.px(6), w - kit.px(4)));
    local barH = 1;
    local gap = kit.px(4);
    local gx = x1 + (w - barW) * 0.5;
    local col = theme.col32(theme.colors.muted);
    for offset = -1, 1 do
        local ly = centerY + offset * gap - barH * 0.5;
        pcall(draw.AddRectFilled, draw, { gx, ly }, { gx + barW, ly + barH }, col);
    end
end

function kit.bump_list(state, key)
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
    if (key == 'scripts' or key == nil) then
        state.scriptListEpoch = (state.scriptListEpoch or 0) + 1;
    end
    if (key == 'presets' or key == nil) then
        state.presetListEpoch = (state.presetListEpoch or 0) + 1;
    end
end

function kit.history_max(cfg)
    return store.history_max();
end

function kit.trim_history(cfg)
    local max = kit.history_max(cfg);
    while (#cfg.history > max) do
        table.remove(cfg.history);
    end
end

function kit.draw_list_loading(cache)
    local label = listload.label(cache);
    if (label == nil) then
        return;
    end
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.muted);
    imgui.Text(label);
    imgui.PopStyleColor();
end

function kit.move_item(list, from, to)
    if (from == to or list[from] == nil or list[to] == nil) then
        return;
    end
    local item = table.remove(list, from);
    table.insert(list, to, item);
end

kit.lineNumFontSize = 20;

function kit.ensure_line_num_font()
    if (kit.lineNumFont ~= nil) then
        return true;
    end
    if (kit.lineNumFontFailed == true) then
        return false;
    end
    if (imgui.AddFontFromFileTTF == nil) then
        kit.lineNumFontFailed = true;
        return false;
    end
    local root = os.getenv('SystemRoot') or os.getenv('WINDIR') or 'C:\\Windows';
    root = tostring(root):gsub('[/\\]+$', '');
    local path = root .. '\\Fonts\\ariblk.ttf';
    local size = kit.lineNumFontSize or 20;
    local ok, font = pcall(imgui.AddFontFromFileTTF, path, size);
    if (ok and font ~= nil and font ~= false) then
        kit.lineNumFont = font;
        return true;
    end
    kit.lineNumFontFailed = true;
    return false;
end

function kit.push_line_num_font()
    if (not kit.ensure_line_num_font()) then
        return false;
    end
    local size = (kit.lineNumFontSize or 20) * (kit.scale or 1);
    local ok = pcall(imgui.PushFont, kit.lineNumFont, size);
    if (ok) then
        return true;
    end
    ok = pcall(imgui.PushFont, kit.lineNumFont);
    return ok == true;
end

function kit.line_num_width(maxN)
    local digits = #tostring(math.max(1, math.floor(tonumber(maxN) or 1)));
    local sample = string.rep('0', digits);
    local pushed = kit.push_line_num_font();
    local width = kit.text_px(sample);
    kit.pop_font(pushed);
    return width + kit.px(16);
end

function kit.draw_line_num(n, colW, x, y, refH)
    if (n == nil or colW == nil or colW <= 0) then
        return;
    end
    local label = tostring(math.floor(tonumber(n) or 0));
    local pushed = kit.push_line_num_font();
    local tw = kit.text_px(label);
    local numH = kit.text_height();
    local gap = kit.px(10);
    local drawX = x + math.max(0, colW - tw - gap);
    local drawY = y;
    if (y ~= nil and refH ~= nil and numH > 0) then
        drawY = y + (refH - numH) * 0.5 - kit.px(1);
    end
    if (drawY ~= nil) then
        imgui.SetCursorPos({ drawX, drawY });
    else
        imgui.SetCursorPosX(drawX);
    end
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.muted);
    imgui.Text(label);
    imgui.PopStyleColor();
    kit.pop_font(pushed);
end

function kit.run_payload(cfg, payload, save, errors, errorKey, state)
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
    require('libs.ui.history').push_history(cfg, payload, save, state);
    return true;
end

function kit.run_command(cfg, command, bag, save, errors, errorKey, state)
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
    return kit.run_payload(cfg, payload, save, errors, errorKey, state);
end

function kit.expire_errors(state)
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

function kit.command_by_id(id)
    for _, command in ipairs(commands) do
        if (command.id == id) then
            return command;
        end
    end
    return nil;
end

function kit.name_column(list)
    local widest = 0;
    for _, command in ipairs(list) do
        local width = kit.text_px('!' .. command.id);
        if (width > widest) then
            widest = width;
        end
    end
    return widest + kit.px(12);
end

kit.WELCOME_COMBO_W = 295;

function kit.draw_tier_combo(cfg, save, comboId, fixedW, centerPreview)
    local id = comboId or '##tier';
    local tierLabel = 'Tier ' .. tostring(cfg.tier or 5);
    local tierLabels = {};
    for tier = 1, 5 do
        tierLabels[tier] = 'Tier ' .. tier;
    end
    local flags = ImGuiComboFlags_PopupAlignLeft;
    local opened, centered, listW, centerOpts = widgets.begin_labels_combo(id, tierLabel, tierLabels, flags, fixedW, centerPreview);
    if (opened) then
        for tier = 1, 5 do
            if (widgets.labels_combo_option('tier' .. tier .. id, 'Tier ' .. tier, cfg.tier == tier, listW, centerOpts)) then
                cfg.tier = tier;
                save();
            end
        end
        widgets.end_labels_combo(opened, centered);
    end
end

function kit.draw_tier(cfg, save)
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label('Tier');
    imgui.SameLine();
    kit.draw_tier_combo(cfg, save, '##tier');
end

function kit.push_sized_font(extraPx)
    extraPx = extraPx or 0;
    if (imgui.PushFont ~= nil and imgui.GetFont ~= nil) then
        if (kit.fontBase == nil and imgui.GetFontSize ~= nil) then
            local size = imgui.GetFontSize();
            if (type(size) == 'number' and size > 0) then
                kit.fontBase = size;
            end
        end
        local font = imgui.GetFont();
        if (font ~= nil and kit.fontBase ~= nil) then
            local ok = pcall(imgui.PushFont, font, kit.fontBase * kit.scale + extraPx);
            if (ok) then
                return true;
            end
        end
    end
    return false;
end

function kit.welcome_wrap_lines(text, wrapW)
    local lines = {};
    local current = '';
    for word in tostring(text or ''):gmatch('%S+') do
        local trial = current == '' and word or (current .. ' ' .. word);
        if (current ~= '' and kit.text_px(trial) > wrapW) then
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

function kit.welcome_centered_text(text, startX, contentW, color)
    local lines = kit.welcome_wrap_lines(text, contentW);
    if (color ~= nil) then
        imgui.PushStyleColor(ImGuiCol_Text, color);
    end
    for _, line in ipairs(lines) do
        local width = kit.text_px(line);
        imgui.SetCursorPosX(startX + math.max(0, (contentW - width) * 0.5));
        imgui.Text(line);
    end
    if (color ~= nil) then
        imgui.PopStyleColor();
    end
    return #lines;
end

function kit.draw_welcome(cfg, save)
    local availW = kit.remaining_width();
    local availH = kit.remaining_height();
    local contentW = math.min(kit.px(460), math.max(kit.px(280), availW - kit.px(40)));
    local tierLabels = {};
    for tier = 1, 5 do
        tierLabels[tier] = 'Tier ' .. tier;
    end
    local comboW = kit.px(kit.WELCOME_COMBO_W);
    local buttonW = kit.px(120);
    local gap = kit.px(kit.GAP);
    local originX = imgui.GetCursorPosX();
    local originY = imgui.GetCursorPosY();
    local startX = originX + math.max(0, (availW - contentW) * 0.5);

    local bodyFont = kit.push_sized_font(2);
    local titleFont = kit.push_sized_font(6);
    local title = 'Welcome to GM Helper!';
    local titleH = kit.text_height();
    local titleW = kit.text_px(title);
    kit.pop_font(titleFont);

    local bodyH = kit.text_height();
    local tierLines = kit.welcome_wrap_lines(
        'Before using, please make sure to select your GM Tier as you will only have access to specific commands.',
        contentW
    );
    local warnLines = kit.welcome_wrap_lines(
        'Remember that commands will affect what you currently have targeted unless you specify the target name, which is an optional argument.',
        contentW
    );
    local _, controlH = kit.row_metrics();
    local blockH = titleH + gap
        + (#tierLines * bodyH) + gap
        + controlH + gap
        + (#warnLines * bodyH) + gap * 2
        + controlH;
    kit.pop_font(bodyFont);

    local startY = originY + math.max(0, (availH - blockH) * 0.5);
    imgui.SetCursorPos({ startX, startY });

    titleFont = kit.push_sized_font(6);
    imgui.SetCursorPosX(startX + math.max(0, (contentW - titleW) * 0.5));
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text);
    imgui.Text(title);
    imgui.PopStyleColor();
    kit.pop_font(titleFont);
    imgui.Spacing();

    bodyFont = kit.push_sized_font(2);
    kit.welcome_centered_text(
        'Before using, please make sure to select your GM Tier as you will only have access to specific commands.',
        startX,
        contentW,
        theme.colors.text
    );
    imgui.Spacing();

    imgui.SetCursorPosX(startX + math.max(0, (contentW - comboW) * 0.5));
    kit.draw_tier_combo(cfg, save, '##welcometier', kit.WELCOME_COMBO_W, true);
    imgui.Spacing();

    kit.welcome_centered_text(
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
    kit.pop_font(bodyFont);
end

function kit.draw_search_bar(id, buffer)
    local width = kit.remaining_width();
    if (width < kit.px(160)) then
        width = kit.px(160);
    end
    widgets.placeholder(id, buffer, 'Search', width, 'left');
end

function kit.trim_query(value)
    if (value == nil) then
        return '';
    end
    return (tostring(value):gsub('^%s+', ''):gsub('%s+$', '')):lower();
end

function kit.sync_nav(state)
    if (state.section ~= 'commands' and state.section ~= 'favorites' and state.section ~= 'scripts' and state.section ~= 'presets' and state.section ~= 'history' and state.section ~= 'settings') then
        if (state.page == 'favorites' or state.page == 'scripts' or state.page == 'presets' or state.page == 'history' or state.page == 'settings') then
            state.section = state.page;
            state.page = 'Player';
        else
            state.section = 'commands';
        end
    end
    for _, group in ipairs(kit.GROUPS) do
        if (state.page == group.id) then
            return;
        end
    end
    state.page = 'Player';
end

function kit.vec2(value, other)
    if (type(value) == 'table' or type(value) == 'userdata') then
        return value.x or value[1] or 0, value.y or value[2] or 0;
    end
    if (type(value) == 'number') then
        return value, other or 0;
    end
    return 0, 0;
end

function kit.last_item_rect()
    local x1, y1, x2, y2 = 0, 0, 16, 16;
    if (imgui.GetItemRectMin ~= nil) then
        local a, b = imgui.GetItemRectMin();
        x1, y1 = kit.vec2(a, b);
    end
    if (imgui.GetItemRectMax ~= nil) then
        local a, b = imgui.GetItemRectMax();
        local mx, my = kit.vec2(a, b);
        if (mx > x1) then
            x2, y2 = mx, my;
        end
    end
    return x1, y1, x2, y2;
end

function kit.symbol_hit(id)
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
    local clicked = imgui.Button('##' .. id, { kit.px(kit.TITLE_GLYPH), kit.px(kit.TITLE_GLYPH) });
    imgui.PopStyleColor(5);
    if (pushed > 0 and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar(pushed);
    end
    return clicked;
end

function kit.paint_symbol(kind, collapsed)
    local draw = imgui.GetWindowDrawList();
    if (draw == nil) then
        return;
    end
    local x1, y1, x2, y2 = kit.last_item_rect();
    local cx = (x1 + x2) * 0.5;
    local cy = (y1 + y2) * 0.5;
    local symbolColor = theme.colors.peach;
    if (imgui.IsItemHovered ~= nil and imgui.IsItemHovered()) then
        symbolColor = theme.colors.text;
    end
    local col = theme.col32(symbolColor);
    local box = kit.px(4);
    local thick = math.max(1, kit.scale * 1.5);
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

kit.ROUND_TOP = ImDrawFlags_RoundCornersTop or 48;

kit.ROUND_BOTTOM = ImDrawFlags_RoundCornersBottom or 192;

kit.ROUND_ALL = ImDrawFlags_RoundCornersAll or 240;

kit.NO_MOVE = ImGuiWindowFlags_NoMove or 4;

kit.NO_SCROLL = ImGuiWindowFlags_NoScrollbar or 8;

kit.NO_SCROLL_MOUSE = ImGuiWindowFlags_NoScrollWithMouse or 16;

kit.NO_BACKGROUND = ImGuiWindowFlags_NoBackground or 128;

kit.NO_FRONT = ImGuiWindowFlags_NoBringToFrontOnFocus or 8192;

kit.NO_DOCK = ImGuiWindowFlags_NoDocking or 524288;

function kit.bor_flags(...)
    local value = 0;
    for index = 1, select('#', ...) do
        local flag = select(index, ...);
        if (type(flag) == 'number') then
            value = bit.bor(value, flag);
        end
    end
    return value;
end

function kit.window_pos()
    if (imgui.GetWindowPos == nil) then
        return 0, 0;
    end
    return kit.vec2(imgui.GetWindowPos());
end

function kit.title_metrics()
    local glyph = kit.px(kit.TITLE_GLYPH);
    local padX = kit.px(kit.TITLE_PAD_X);
    local padY = kit.px(kit.TITLE_PAD_Y);
    return glyph, padX, padY, glyph + padY * 2;
end

function kit.push_styles(list)
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

function kit.pop_styles(count)
    if (count > 0 and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar(count);
    end
end

function kit.paint_panel(rounding, corners, fillColor, edgeColor)
    if (imgui.GetWindowDrawList == nil or imgui.GetWindowWidth == nil or imgui.GetWindowHeight == nil) then
        return;
    end
    local draw = imgui.GetWindowDrawList();
    if (draw == nil or draw.AddRectFilled == nil) then
        return;
    end
    local x, y = kit.window_pos();
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

function kit.window_hovered()
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

function kit.window_focused()
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

function kit.title_chrome(panelFocused)
    if (kit.window_hovered()) then
        return theme.colors.glass, theme.colors.borderStrong;
    end
    if (kit.window_focused() or panelFocused) then
        return theme.colors.glass, theme.colors.accentSoft;
    end
    return theme.colors.glass, theme.colors.borderSoft;
end

-- Title bar is its own window. Collapse only hides the body, so this row never changes size.

function kit.draw_title(state)
    local glyph = kit.px(kit.TITLE_GLYPH);
    local startX = imgui.GetCursorPosX();
    local rowY = imgui.GetCursorPosY();
    local contentW = kit.remaining_width();
    local textH = 13;
    if (imgui.CalcTextSize ~= nil) then
        local size, second = imgui.CalcTextSize('GM Helper');
        if (type(size) == 'number') then
            textH = second or 13;
        else
            textH = size.y or size[2] or 13;
        end
    end
    if (not kit.fontScaled) then
        textH = textH * kit.scale;
    end

    local textY = rowY + math.max(0, (glyph - textH) * 0.5);
    imgui.SetCursorPos({ startX, rowY });
    if (kit.symbol_hit('collapse')) then
        state.collapsed = not state.collapsed;
    end
    kit.paint_symbol('chevron', state.collapsed);

    local label = 'GM HELPER';
    imgui.SetCursorPos({ startX + glyph + kit.px(8), textY });
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text);
    imgui.Text(label);
    imgui.PopStyleColor();

    imgui.SetCursorPos({ startX + glyph + kit.px(8) + kit.text_px(label) + kit.px(6), textY });
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.peach);
    imgui.Text('v' .. addon.version);
    imgui.PopStyleColor();

    imgui.SetCursorPos({ startX + contentW - glyph, rowY });
    if (kit.symbol_hit('close')) then
        state.visible = false;
    end
    kit.paint_symbol('close', false);
    kit.submit_space(0);
end

function kit.tab_radius(height)
    return 0;
end

function kit.paint_selected_tab(radius)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    if (draw == nil or draw.AddRectFilled == nil) then
        return;
    end
    local x1, y1, x2, y2 = kit.last_item_rect();
    local fill = theme.col32(theme.colors.glass);
    if (not pcall(draw.AddRectFilled, draw, { x1, y1 }, { x2, y2 }, fill, radius, kit.ROUND_TOP)) then
        pcall(draw.AddRectFilled, draw, { x1, y1 }, { x2, y2 }, fill, 0);
    end
end

function kit.paint_nav_highlight(selected, radius, strength)
    local x1, y1, x2, y2 = kit.last_item_rect();
    local panel = selected and theme.colors.glass or theme.colors.abyss;
    theme.paint_tab_highlight(x1, y1, x2, y2, math.max(2, kit.px(2)), panel, radius, strength);
end

function kit.paint_nav_label(label, color)
    local draw = imgui.GetWindowDrawList();
    local x1, y1, x2, y2 = kit.last_item_rect();
    local tw, th = kit.text_width(label), 13;
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

function kit.paint_section_underline(label, strength)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    if (draw == nil or draw.AddRectFilled == nil) then
        return;
    end
    local x1, y1, x2, y2 = kit.last_item_rect();
    local tw = kit.text_px(label);
    local cx = (x1 + x2) * 0.5;
    local lineW = math.max(kit.px(16), tw);
    local thick = math.max(2, kit.px(2));
    local lineY = y2 - thick - kit.px(2);
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

function kit.nav_button(label, id, selected, width)
    local pushed = 0;
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_FrameBorderSize ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 0);
        pushed = pushed + 1;
    end
    imgui.PushStyleColor(ImGuiCol_Button, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_Border, theme.colors.clear);
    local clicked = imgui.Button('##' .. id, { width, kit.px(30) });
    local radius = kit.tab_radius(kit.px(30));
    local hovered = imgui.IsItemHovered ~= nil and imgui.IsItemHovered();
    if (selected) then
        kit.paint_selected_tab(radius);
        kit.paint_nav_highlight(true, radius, 1);
    elseif (hovered) then
        kit.paint_nav_highlight(false, radius, 0.75);
    end
    local color = theme.colors.muted;
    if (selected or hovered) then
        color = theme.colors.text;
    end
    kit.paint_nav_label(label, color);
    imgui.PopStyleColor(4);
    if (pushed > 0 and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar(pushed);
    end
    return clicked;
end

function kit.letter_tab_width()
    return math.ceil(kit.text_px(string.rep('M', 10)));
end

function kit.section_tab(label, id, selected, width)
    local pushed = 0;
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_FrameBorderSize ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 0);
        pushed = pushed + 1;
    end
    imgui.PushStyleColor(ImGuiCol_Button, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_Border, theme.colors.clear);
    local clicked = imgui.Button('##' .. id, { width, kit.px(32) });
    local hovered = imgui.IsItemHovered ~= nil and imgui.IsItemHovered();
    local color = theme.colors.muted;
    if (selected) then
        color = theme.colors.text;
    elseif (hovered) then
        color = theme.colors.secondary;
    end
    kit.paint_nav_label(label, color);
    if (selected) then
        kit.paint_section_underline(label, 1);
    elseif (hovered) then
        kit.paint_section_underline(label, 0.75);
    end
    imgui.PopStyleColor(4);
    if (pushed > 0 and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar(pushed);
    end
    return clicked;
end

function kit.item_hovered_for_drop()
    if (imgui.IsItemHovered == nil) then
        return false;
    end
    local flags = ImGuiHoveredFlags_AllowWhenBlockedByActiveItem;
    if (flags ~= nil) then
        local ok, hovered = pcall(imgui.IsItemHovered, flags);
        if (ok) then
            return hovered == true;
        end
    end
    local ok, hovered = pcall(imgui.IsItemHovered);
    return ok and hovered == true;
end

function kit.clear_row_drag()
    kit.rowDrag.kind = nil;
    kit.rowDrag.from = nil;
    kit.rowDrag.to = nil;
    kit.rowDrag.toVis = nil;
    kit.rowDrag.label = nil;
    kit.rowDrag.lineNum = nil;
    kit.rowDrag.cmdText = nil;
    kit.rowDrag.numW = nil;
    kit.rowDrag.rowH = nil;
    kit.rowDrag.ghost = nil;
    kit.rowDrag.hotX = nil;
    kit.rowDrag.hotY = nil;
    kit.rowDrag.list = nil;
    kit.rowDrag.state = nil;
    kit.rowDrag.listKey = nil;
    kit.rowDrag.sourceRows = nil;
    kit.rowDrag.liveRows = nil;
    kit.rowDrag.hitBands = nil;
    kit.rowDrag.heights = nil;
    -- Keep heightMap across drags so the next pickup has measured row sizes.
    kit.rowDrag.active = false;
    kit.rowDrag.insertY = nil;
    kit.rowDrag.insertX1 = nil;
    kit.rowDrag.insertX2 = nil;
end

function kit.row_vis_for_slot(rows, slot)
    if (rows == nil or slot == nil) then
        return nil;
    end
    for index, row in ipairs(rows) do
        if (row.slot == slot) then
            return index;
        end
    end
    return nil;
end

--[[
* Build a visual row list with a hole at visual index `toVis` and the dragged slot removed.
* `toVis` is a layout index (1..n), not a list slot — that lets the hole return to its origin.
]]
function kit.row_drag_layout(rows, fromSlot, toVis)
    if (rows == nil or fromSlot == nil) then
        return rows or {};
    end
    local fromVis = kit.row_vis_for_slot(rows, fromSlot);
    if (fromVis == nil) then
        return rows;
    end
    local holeVis = toVis;
    if (holeVis == nil) then
        holeVis = fromVis;
    end
    if (holeVis < 1) then
        holeVis = 1;
    elseif (holeVis > #rows) then
        holeVis = #rows;
    end
    local others = {};
    for index, row in ipairs(rows) do
        if (index ~= fromVis) then
            others[#others + 1] = row;
        end
    end
    local out = {};
    local oi = 1;
    for vis = 1, #rows do
        if (vis == holeVis) then
            out[#out + 1] = {
                hole = true,
                slot = fromSlot,
                height = kit.rowDrag.rowH or kit.px(28),
            };
        else
            out[#out + 1] = others[oi];
            oi = oi + 1;
        end
    end
    return out;
end

--[[
* Reorder `list` so the visible `sourceRows` match hole-at-toVis layout.
* Works with filtered views: only the participating slots are rewritten.
]]
function kit.apply_row_drag_reorder(list, sourceRows, fromSlot, toVis)
    if (list == nil or sourceRows == nil or fromSlot == nil or toVis == nil) then
        return false;
    end
    local fromVis = kit.row_vis_for_slot(sourceRows, fromSlot);
    if (fromVis == nil or fromVis == toVis) then
        return false;
    end
    local holeVis = toVis;
    if (holeVis < 1) then
        holeVis = 1;
    elseif (holeVis > #sourceRows) then
        holeVis = #sourceRows;
    end
    if (fromVis == holeVis) then
        return false;
    end
    local others = {};
    for index, row in ipairs(sourceRows) do
        if (index ~= fromVis) then
            others[#others + 1] = row.slot;
        end
    end
    local order = {};
    local oi = 1;
    for vis = 1, #sourceRows do
        if (vis == holeVis) then
            order[#order + 1] = fromSlot;
        else
            order[#order + 1] = others[oi];
            oi = oi + 1;
        end
    end
    local positions = {};
    for _, row in ipairs(sourceRows) do
        positions[#positions + 1] = row.slot;
    end
    table.sort(positions);
    local snapshot = {};
    for i = 1, #list do
        snapshot[i] = list[i];
    end
    for i, pos in ipairs(positions) do
        list[pos] = snapshot[order[i]];
    end
    return true;
end

function kit.note_row_drag(kind, index, list, state, listKey, label, meta)
    if (imgui.IsItemActive == nil or imgui.IsMouseDragging == nil) then
        return;
    end
    if (imgui.IsItemActive() and imgui.IsMouseDragging(0, kit.px(4))) then
        if (kit.rowDrag.active ~= true or kit.rowDrag.kind ~= kind or kit.rowDrag.from == nil) then
            local mx, my = kit.mouse_pos();
            local info = meta or {};
            local sourceRows = kit.rowDrag.liveRows;
            local fromVis = kit.row_vis_for_slot(sourceRows, index) or info.fromVis or index;
            kit.rowDrag.kind = kind;
            kit.rowDrag.from = index;
            kit.rowDrag.to = index;
            kit.rowDrag.toVis = fromVis;
            kit.rowDrag.sourceRows = sourceRows;
            if (kit.rowDrag.heightMap ~= nil) then
                local snap = {};
                for slot, height in pairs(kit.rowDrag.heightMap) do
                    snap[slot] = height;
                end
                kit.rowDrag.heights = snap;
            end
            kit.rowDrag.label = label;
            kit.rowDrag.lineNum = info.lineNum or index;
            kit.rowDrag.cmdText = info.cmdText or label;
            kit.rowDrag.numW = info.numW;
            kit.rowDrag.rowH = info.rowH;
            kit.rowDrag.ghost = info;
            kit.rowDrag.hotX = mx - (info.rowSX or mx);
            kit.rowDrag.hotY = my - (info.rowSY or my);
            kit.rowDrag.list = list;
            kit.rowDrag.state = state;
            kit.rowDrag.listKey = listKey;
            kit.rowDrag.active = true;
        end
    end
end

function kit.note_row_drop_target(kind, visIndex)
    if (kit.rowDrag.active ~= true or kit.rowDrag.kind ~= kind) then
        return;
    end
    if (visIndex == nil or not kit.item_hovered_for_drop()) then
        return;
    end
    kit.rowDrag.toVis = visIndex;
    kit.rowDrag.to = visIndex;
end

function kit.note_row_height(slot, height)
    if (slot == nil or height == nil or height <= 0) then
        return;
    end
    if (kit.rowDrag.heightMap == nil) then
        kit.rowDrag.heightMap = {};
    end
    kit.rowDrag.heightMap[slot] = height;
end

--[[
* Drop index from mouse Y vs frozen source-row heights (ignores the live hole).
* Avoids flicker when a short dragged row sits over a taller command.
]]
function kit.resolve_row_drag_from_heights(kind, listTopY, sepH)
    if (kit.rowDrag.active ~= true or kit.rowDrag.kind ~= kind) then
        return;
    end
    local sourceRows = kit.rowDrag.sourceRows or kit.rowDrag.liveRows;
    local fromSlot = kit.rowDrag.from;
    if (sourceRows == nil or fromSlot == nil or listTopY == nil) then
        return;
    end
    local _, my = kit.mouse_pos();
    if (my == nil) then
        return;
    end
    local heights = kit.rowDrag.heights or kit.rowDrag.heightMap or {};
    local fallback = kit.rowDrag.rowH or kit.px(28);
    local gap = sepH or kit.px(kit.LIST_GAP_Y);
    local acc = listTopY;
    local insert = 0;
    for _, row in ipairs(sourceRows) do
        if (row.slot ~= fromSlot) then
            local h = heights[row.slot] or fallback;
            if (my < acc + h * 0.5) then
                break;
            end
            acc = acc + h + gap;
            insert = insert + 1;
        end
    end
    local toVis = insert + 1;
    if (toVis < 1) then
        toVis = 1;
    elseif (toVis > #sourceRows) then
        toVis = #sourceRows;
    end
    kit.rowDrag.toVis = toVis;
    kit.rowDrag.to = toVis;
end

function kit.draw_row_placeholder(id, width, height, kind, visIndex)
    local w = width or kit.remaining_width();
    local h = height or kit.rowDrag.rowH or kit.px(28);
    local x = imgui.GetCursorPosX();
    local y = imgui.GetCursorPosY();
    imgui.SetCursorPos({ x, y });
    if (imgui.Dummy ~= nil) then
        imgui.Dummy({ w, h });
    elseif (imgui.InvisibleButton ~= nil) then
        imgui.InvisibleButton('##rowhole' .. tostring(id), { w, h });
    end
    imgui.SetCursorPos({ x, y + h });
    kit.submit_space(0);
end

function kit.draw_row_drop_zone(id, x, y, w, h, kind, visIndex)
    -- Kept for call-site compatibility; drop index comes from frozen heights.
end

function kit.draw_row_drag_handle(id, x, y, w, h, kind, index, list, state, listKey, label, grabW, iconCenterY, meta)
    if (w == nil or w <= 0 or h == nil or h <= 0) then
        return;
    end
    imgui.SetCursorPos({ x, y });
    imgui.PushStyleColor(ImGuiCol_Button, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_Border, theme.colors.clear);
    local pushed = 0;
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_FrameBorderSize ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 0);
        pushed = 1;
    end
    imgui.Button('##' .. tostring(id), { w, h });
    if (pushed > 0) then
        imgui.PopStyleVar(pushed);
    end
    imgui.PopStyleColor(4);
    local info = meta or {};
    if (info.rowH == nil) then
        info.rowH = h;
    end
    if (info.lineNum == nil) then
        info.lineNum = index;
    end
    kit.note_row_drag(kind, index, list, state, listKey, label, info);
    if (kit.rowDrag.active ~= true) then
        -- Only use the grab as a drop target before a drag starts elsewhere.
        kit.note_row_drop_target(kind, index);
    end
    local x1 = kit.item_rect_min();
    if (x1 == nil) then
        return;
    end
    local gw = grabW or kit.row_grab_width();
    local centerY = nil;
    if (iconCenterY ~= nil) then
        imgui.SetCursorPos({ x, iconCenterY });
        local _, sy = kit.cursor_screen_pos();
        centerY = sy;
    else
        local _, y1 = kit.item_rect_min();
        local _, y2 = kit.item_rect_max();
        if (y1 ~= nil and y2 ~= nil) then
            centerY = (y1 + y2) * 0.5;
        end
    end
    if (centerY ~= nil) then
        kit.draw_grab_bars(x1, centerY, x1 + gw);
    end
end

function kit.draw_soft_rect_shadow(draw, x1, y1, x2, y2, spread, strength)
    if (draw == nil or draw.AddRectFilled == nil or x1 == nil or y1 == nil or x2 == nil or y2 == nil) then
        return;
    end
    local radius = spread or kit.px(16);
    if (radius < 1) then
        return;
    end
    local layers = math.max(8, math.floor(radius * 1.25));
    local peak = strength or 0.28;
    -- Draw distance rings (not stacked full rects) so the edge stays soft.
    for i = 1, layers do
        local outer = radius * (i / layers);
        local inner = radius * ((i - 1) / layers);
        local mid = (i - 0.5) / layers;
        local alpha = peak * (1 - mid) * (1 - mid);
        if (alpha > 0.008) then
            local col = theme.col32({ 0, 0, 0, alpha });
            -- top
            pcall(draw.AddRectFilled, draw, { x1 - outer, y1 - outer }, { x2 + outer, y1 - inner }, col);
            -- bottom
            pcall(draw.AddRectFilled, draw, { x1 - outer, y2 + inner }, { x2 + outer, y2 + outer }, col);
            -- left
            pcall(draw.AddRectFilled, draw, { x1 - outer, y1 - inner }, { x1 - inner, y2 + inner }, col);
            -- right
            pcall(draw.AddRectFilled, draw, { x2 + inner, y1 - inner }, { x2 + outer, y2 + inner }, col);
        end
    end
end

function kit.draw_row_drag_overlay()
    if (kit.rowDrag.active ~= true) then
        return;
    end
    local ghost = kit.rowDrag.ghost;
    if (ghost == nil) then
        return;
    end
    local mx, my = kit.mouse_pos();
    local hotX = kit.rowDrag.hotX or 0;
    local hotY = kit.rowDrag.hotY or 0;
    local width = ghost.rowW or kit.px(320);
    local height = ghost.rowH or kit.px(28);
    local px = mx - hotX;
    local py = my - hotY;
    local pad = kit.px(16);
    local cond = ImGuiCond_Always or 1;
    -- Oversized transparent window so a 4-sided soft shadow can sit behind the row.
    imgui.SetNextWindowPos({ px - pad, py - pad }, cond);
    imgui.SetNextWindowSize({ width + pad * 2, height + pad * 2 }, cond);
    imgui.SetNextWindowBgAlpha(0.0);
    local flags = kit.bor_flags(
        ImGuiWindowFlags_NoTitleBar,
        kit.NO_RESIZE,
        kit.NO_MOVE,
        kit.NO_SCROLL,
        kit.NO_SCROLL_MOUSE,
        kit.NO_SAVED,
        ImGuiWindowFlags_NoFocusOnAppearing or 4096,
        ImGuiWindowFlags_NoNav or 0,
        ImGuiWindowFlags_NoInputs or ImGuiWindowFlags_NoMouseInputs or 0,
        kit.NO_DOCK
    );
    local stylePush = 0;
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_WindowPadding ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
        stylePush = stylePush + 1;
    end
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_WindowBorderSize ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
        stylePush = stylePush + 1;
    end
    imgui.PushStyleColor(ImGuiCol_WindowBg, theme.colors.clear);
    local open = { true };
    if (imgui.Begin('###gmhelper_rowghost', open, flags)) then
        local winDraw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
        if (winDraw ~= nil) then
            kit.draw_soft_rect_shadow(winDraw, px, py, px + width, py + height, pad, 0.26);
            if (winDraw.AddRectFilled ~= nil) then
                pcall(winDraw.AddRectFilled, winDraw, { px, py }, { px + width, py + height }, theme.col32(theme.colors.glass));
            end
        end
        imgui.SetCursorPos({ pad, pad });
        -- Lock layout width to the measured row so content can't spill past the shadow.
        kit._ghostRemainW = width;
        if (ghost.kind == 'script') then
            local widgets = require('libs.widgets');
            local grabW = kit.row_grab_width();
            local numW = ghost.numW or kit.line_num_width(ghost.lineNum or 1);
            local x = imgui.GetCursorPosX();
            local y = imgui.GetCursorPosY();
            local textH, controlH, lineH = kit.row_metrics();
            local rowH = ghost.rowH or lineH;
            local nameY = y + math.max(0, (lineH - textH) * 0.5);
            local buttonY = y + math.max(0, (lineH - controlH) * 0.5);
            local favW = widgets.icon_button_size();
            local execW = kit.px(kit.EXEC_W);
            local gap = kit.px(kit.GAP);
            local pair = execW + gap + favW;
            local rowW = ghost.rowW or width;
            imgui.SetCursorPos({ x, nameY + textH * 0.5 });
            local _, cy = kit.cursor_screen_pos();
            imgui.SetCursorPos({ x, y });
            local sx = kit.cursor_screen_pos();
            if (sx ~= nil and cy ~= nil) then
                kit.draw_grab_bars(sx, cy, sx + grabW);
            end
            kit.draw_line_num(ghost.lineNum, numW, x + grabW, nameY, textH);
            imgui.SetCursorPos({ x + grabW + numW, nameY });
            imgui.Text(tostring(ghost.cmdText or ghost.label or ''));
            local actionsX = x + rowW - pair;
            imgui.SetCursorPos({ actionsX, buttonY });
            widgets.execute('ghostscript');
            imgui.SetCursorPos({ actionsX + execW + gap, buttonY });
            widgets.remove('ghostscript');
        elseif (ghost.command ~= nil) then
            require('libs.ui.commands').draw_command(
                ghost.command,
                ghost.bag,
                'ghost',
                nil,
                function() end,
                function() end,
                nil,
                ghost.nameCol,
                false,
                'ghost',
                nil,
                ghost.lineNum,
                ghost.numW
            );
        end
        kit._ghostRemainW = nil;
    end
    imgui.End();
    imgui.PopStyleColor(1);
    if (stylePush > 0) then
        imgui.PopStyleVar(stylePush);
    end
end

function kit.finish_row_drag(save)
    if (imgui.IsMouseReleased == nil or not imgui.IsMouseReleased(0)) then
        if (kit.rowDrag.active == true and not kit.mouse_held(0)) then
            kit.clear_row_drag();
        end
        return;
    end
    if (kit.rowDrag.active == true and kit.rowDrag.list ~= nil and kit.rowDrag.from ~= nil and kit.rowDrag.toVis ~= nil) then
        if (kit.apply_row_drag_reorder(kit.rowDrag.list, kit.rowDrag.sourceRows, kit.rowDrag.from, kit.rowDrag.toVis)) then
            if (kit.rowDrag.state ~= nil) then
                kit.bump_list(kit.rowDrag.state, kit.rowDrag.listKey);
            end
            if (save ~= nil) then
                save();
            end
        end
    end
    kit.clear_row_drag();
end

function kit.note_tab_drag(kind, index)
    if (imgui.IsItemActive == nil or imgui.IsMouseDragging == nil) then
        return;
    end
    if (imgui.IsItemActive() and imgui.IsMouseDragging(0, kit.px(4))) then
        kit.tabDrag.kind = kind;
        if (kit.tabDrag.from == nil) then
            kit.tabDrag.from = index;
        end
        kit.tabDrag.moved = true;
    end
end

function kit.accept_tab_drop(kind, index, list, state, listKey)
    if (kit.tabDrag.kind ~= kind or kit.tabDrag.from == nil or kit.tabDrag.from == index) then
        return false;
    end
    if (imgui.IsMouseDragging == nil) then
        return false;
    end
    if (kit.item_hovered_for_drop() and imgui.IsMouseDragging(0, 0)) then
        kit.move_item(list, kit.tabDrag.from, index);
        kit.tabDrag.from = index;
        kit.tabDrag.moved = true;
        if (state ~= nil) then
            kit.bump_list(state, listKey);
        end
        return true;
    end
    return false;
end

function kit.finish_tab_drag(save)
    if (imgui.IsMouseReleased == nil or not imgui.IsMouseReleased(0)) then
        return;
    end
    if (kit.tabDrag.moved and save ~= nil) then
        save();
    end
    kit.tabDrag.kind = nil;
    kit.tabDrag.from = nil;
    kit.tabDrag.moved = false;
end

function kit.seed_rename(state, tab)
    if (state.favRenameId ~= tab.id or state.favRename == nil) then
        state.favRenameId = tab.id;
        state.favRename = { tab.name or '' };
    end
end

function kit.apply_rename(tab, renameBuf, save)
    local shown = tostring((renameBuf and renameBuf[1]) or '');
    shown = (shown:gsub('^%s+', ''):gsub('%s+$', ''));
    if (shown == '') then
        return false;
    end
    tab.name = shown;
    save();
    return true;
end

function kit.menu_hit(label, enabled, width)
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

function kit.mouse_clicked(button)
    if (imgui.IsMouseClicked == nil) then
        return false;
    end
    local ok, clicked = pcall(imgui.IsMouseClicked, button or 0);
    return ok and clicked == true;
end

function kit.mouse_released(button)
    if (imgui.IsMouseReleased == nil) then
        return false;
    end
    local ok, released = pcall(imgui.IsMouseReleased, button or 0);
    return ok and released == true;
end

function kit.mouse_held(button)
    if (imgui.IsMouseDown == nil) then
        return false;
    end
    local ok, down = pcall(imgui.IsMouseDown, button or 0);
    return ok and down == true;
end

function kit.mouse_pos()
    if (imgui.GetMousePos ~= nil) then
        local a, b;
        local ok = pcall(function()
            a, b = imgui.GetMousePos();
        end);
        if (ok and a ~= nil) then
            return kit.vec2(a, b);
        end
    end
    local io = imgui.GetIO ~= nil and imgui.GetIO() or nil;
    if (io ~= nil and io.MousePos ~= nil) then
        return kit.vec2(io.MousePos);
    end
    return 0, 0;
end

-- Custom resize of the title+body shell. ImGui body resize can't grow up/left
-- because the body is pinned under a separate title bar.

kit.shellResize = nil;

kit.RESIZE_GRIP = 6;

function kit.update_shell_resize(cfg, titleX, titleY, width, bodyH, barH)
    local grip = kit.px(kit.RESIZE_GRIP);
    local totalH = bodyH + barH - 1;
    local x1, y1 = titleX, titleY;
    local x2, y2 = titleX + width, titleY + totalH;
    local mx, my = kit.mouse_pos();
    local minW, minH = 320, 240;

    if (widgets.combo_open()) then
        kit.shellResize = nil;
        return titleX, titleY, false;
    end

    local function on_edge(value, edge)
        return math.abs(value - edge) <= grip;
    end

    if (kit.shellResize == nil and kit.mouse_clicked(0) and not kit.modal_open()) then
        local hitL = on_edge(mx, x1) and my >= (y1 - grip) and my <= (y2 + grip);
        local hitR = on_edge(mx, x2) and my >= (y1 - grip) and my <= (y2 + grip);
        local hitT = on_edge(my, y1) and mx >= (x1 - grip) and mx <= (x2 + grip);
        local hitB = on_edge(my, y2) and mx >= (x1 - grip) and mx <= (x2 + grip);
        if (hitL or hitR or hitT or hitB) then
            kit.shellResize = {
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

    if (kit.shellResize == nil) then
        return titleX, titleY, false;
    end

    if (kit.mouse_held(0)) then
        local dx = mx - kit.shellResize.mx;
        local dy = my - kit.shellResize.my;
        local w = kit.shellResize.w;
        local h = kit.shellResize.h;
        local x = kit.shellResize.x;
        local y = kit.shellResize.y;
        local right = kit.shellResize.x + kit.shellResize.w * kit.scale;
        local bottom = kit.shellResize.y + kit.shellResize.h * kit.scale;

        if (kit.shellResize.R) then
            w = math.max(minW, kit.shellResize.w + dx / kit.scale);
        end
        if (kit.shellResize.B) then
            h = math.max(minH, kit.shellResize.h + dy / kit.scale);
        end
        if (kit.shellResize.L) then
            w = math.max(minW, kit.shellResize.w - dx / kit.scale);
            x = right - w * kit.scale;
        end
        if (kit.shellResize.T) then
            h = math.max(minH, kit.shellResize.h - dy / kit.scale);
            y = bottom - h * kit.scale;
        end

        cfg.windowW = math.floor(w + 0.5);
        cfg.windowH = math.floor(h + 0.5);
        cfg.windowX = math.floor(x + 0.5);
        cfg.windowY = math.floor(y + 0.5);
        return cfg.windowX, cfg.windowY, true;
    end

    if (kit.mouse_released(0)) then
        kit.shellResize = nil;
    end
    return titleX, titleY, false;
end

function kit.paint_menu_label(label)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    local x1, y1, x2, y2 = kit.last_item_rect();
    if (draw == nil or draw.AddText == nil) then
        return;
    end
    local tw, th = kit.text_width(label), 13;
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

function kit.screen_size()
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

function kit.center_next_window()
    local width, height = kit.screen_size();
    local cond = ImGuiCond_Appearing or 8;
    if (not pcall(imgui.SetNextWindowPos, { width * 0.5, height * 0.5 }, cond, { 0.5, 0.5 })) then
        pcall(imgui.SetNextWindowPos, { width * 0.5, height * 0.5 }, cond);
    end
end

function kit.center_buttons(widths)
    local gap = kit.px(kit.GAP);
    local total = 0;
    for index, width in ipairs(widths) do
        total = total + width;
        if (index > 1) then
            total = total + gap;
        end
    end
    local avail = kit.remaining_width();
    if (avail > total and imgui.SetCursorPosX ~= nil) then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + (avail - total) * 0.5);
    end
end

function kit.modal_button_width()
    local available = math.max(1, kit.remaining_width() - kit.px(kit.GAP));
    return math.max(1, math.min(kit.px(110), math.floor(available * 0.5)));
end

function kit.claim_modal_capture()
    kit.modalActive = true;
    if (imgui.SetNextFrameWantCaptureMouse ~= nil) then
        pcall(imgui.SetNextFrameWantCaptureMouse, true);
    end
    if (imgui.SetNextFrameWantCaptureKeyboard ~= nil) then
        pcall(imgui.SetNextFrameWantCaptureKeyboard, true);
    end
end

kit.modalHeights = {};

kit.modalBodyStyles = 0;

kit.modalBodyFont = false;

kit.NO_SAVED = ImGuiWindowFlags_NoSavedSettings or 256;

function kit.draw_modal_title_label(label)
    local glyph = kit.px(kit.TITLE_GLYPH);
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
    if (not kit.fontScaled) then
        textH = textH * kit.scale;
    end
    local textY = rowY + math.max(0, (glyph - textH) * 0.5);
    imgui.SetCursorPos({ startX, textY });
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text);
    imgui.Text(label or '');
    imgui.PopStyleColor();
    kit.submit_space(0);
end

function kit.paint_modal_dim(sw, sh)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    if (draw ~= nil and draw.AddRectFilled ~= nil) then
        local x, y = kit.window_pos();
        pcall(draw.AddRectFilled, draw, { x, y }, { x + sw, y + sh }, theme.col32({ 0.02, 0.01, 0.01, 0.55 }));
    end
    if (imgui.InvisibleButton ~= nil) then
        imgui.InvisibleButton('##gmhelper_modal_dim', { sw, sh });
    else
        kit.submit_space(sh);
    end
end

-- Title + body are separate windows, same chrome as the main GM Helper frame.

function kit.begin_modal(id, title, request, opts)
    if (request and kit.mouse_held(0)) then
        return false;
    end
    kit.claim_modal_capture();

    opts = opts or {};
    local sw, sh = kit.screen_size();
    local _, padX, padY, barH = kit.title_metrics();
    local pad = kit.px(kit.PAD);
    local maxContentW = math.max(1, sw - pad * 2 - kit.px(32));
    local wantedW = opts.contentW or kit.px(320);
    local contentW = math.min(wantedW, maxContentW);
    local modalW = contentW + pad * 2;
    local bodyH = kit.modalHeights[id] or kit.px(120);
    local totalH = barH + bodyH - 1;
    local left = math.floor((sw - modalW) * 0.5);
    local top = math.floor((sh - totalH) * 0.5);
    local rounding = kit.px(kit.ROUND);
    local cond = ImGuiCond_Always or 1;
    local open = { true };

    if (imgui.SetNextWindowDockID ~= nil) then
        pcall(imgui.SetNextWindowDockID, 0, cond);
    end
    imgui.SetNextWindowPos({ 0, 0 }, cond);
    imgui.SetNextWindowSize({ sw, sh }, cond);
    imgui.SetNextWindowBgAlpha(0);
    local dimFlags = kit.bor_flags(
        ImGuiWindowFlags_NoTitleBar,
        kit.NO_RESIZE,
        kit.NO_MOVE,
        kit.NO_SCROLL,
        kit.NO_SCROLL_MOUSE,
        kit.NO_BACKGROUND,
        kit.NO_SAVED,
        kit.NO_DOCK,
        ImGuiWindowFlags_NoFocusOnAppearing or 4096
    );
    if (imgui.Begin('###gmhelper_modal_dim_' .. id, open, dimFlags)) then
        kit.paint_modal_dim(sw, sh);
    end
    imgui.End();

    if (imgui.SetNextWindowDockID ~= nil) then
        pcall(imgui.SetNextWindowDockID, 0, cond);
    end
    imgui.SetNextWindowPos({ left, top }, cond);
    imgui.SetNextWindowSize({ modalW, barH }, cond);
    imgui.SetNextWindowBgAlpha(0);
    local titleStyles = kit.push_styles({
        { ImGuiStyleVar_WindowPadding, { padX, padY } },
        { ImGuiStyleVar_WindowRounding, 0 },
        { ImGuiStyleVar_WindowBorderSize, 0 },
    });
    local titleFlags = kit.bor_flags(
        ImGuiWindowFlags_NoTitleBar,
        kit.NO_RESIZE,
        kit.NO_MOVE,
        kit.NO_SCROLL,
        kit.NO_SCROLL_MOUSE,
        kit.NO_BACKGROUND,
        kit.NO_SAVED,
        kit.NO_DOCK
    );
    if (imgui.Begin('###gmhelper_modal_title_' .. id, open, titleFlags)) then
        local titleFont = kit.push_font();
        kit.fontScaled = titleFont;
        kit.paint_panel(rounding, kit.ROUND_TOP, theme.colors.glass, theme.colors.accentSoft);
        kit.draw_modal_title_label(title);
        kit.pop_font(titleFont);
    end
    imgui.End();
    kit.pop_styles(titleStyles);

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
    kit.modalBodyStyles = kit.push_styles({
        { ImGuiStyleVar_WindowPadding, { pad, pad } },
        { ImGuiStyleVar_WindowRounding, 0 },
        { ImGuiStyleVar_WindowBorderSize, 0 },
        { ImGuiStyleVar_ItemSpacing, { kit.px(kit.GAP), kit.px(kit.GAP) } },
    });
    local bodyFlags = kit.bor_flags(
        ImGuiWindowFlags_NoTitleBar,
        kit.NO_RESIZE,
        kit.NO_MOVE,
        kit.NO_SCROLL,
        kit.NO_SCROLL_MOUSE,
        kit.NO_BACKGROUND,
        kit.NO_SAVED,
        kit.NO_DOCK,
        ImGuiWindowFlags_AlwaysAutoResize or 64
    );
    local opened = false;
    if (imgui.Begin('###gmhelper_modal_body_' .. id, open, bodyFlags)) then
        opened = true;
        kit.modalBodyFont = kit.push_font();
        kit.fontScaled = kit.modalBodyFont;
        kit.paint_panel(rounding, kit.ROUND_BOTTOM, theme.colors.glass, theme.colors.border);
    else
        imgui.End();
        kit.pop_styles(kit.modalBodyStyles);
        kit.modalBodyStyles = 0;
    end
    return opened;
end

function kit.end_modal(id)
    if (imgui.GetWindowHeight ~= nil) then
        local height = imgui.GetWindowHeight();
        if (type(height) == 'number' and height > 0) then
            kit.modalHeights[id] = height;
        end
    end
    kit.pop_font(kit.modalBodyFont);
    kit.modalBodyFont = false;
    imgui.End();
    kit.pop_styles(kit.modalBodyStyles);
    kit.modalBodyStyles = 0;
end

function kit.modal_open()
    return kit.modalActive == true;
end

return kit;
