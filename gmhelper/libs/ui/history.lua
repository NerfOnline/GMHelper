--[[
* GM Helper History tab and timestamp helpers.
]]

require('common');

local imgui = require('imgui');
local kit = require('libs.ui.kit');
local listload = require('libs.listload');
local theme = require('libs.theme');
local widgets = require('libs.widgets');

local M = {};

M.HISTORY_DATE_SEPS = { '/', '-', '.' };

M.HISTORY_DATE_ORDERS = {
    { order = 'mdy', label = 'MM%sDD%sYYYY' },
    { order = 'dmy', label = 'DD%sMM%sYYYY' },
    { order = 'ymd', label = 'YYYY%sMM%sDD' },
};

M.HISTORY_TIME_FORMATS = {
    { id = '%H:%M:%S', label = 'HH:MM:SS (24H)' },
    { id = '%H:%M', label = 'HH:MM (24H)' },
    { id = '%I:%M:%S %p', label = 'HH:MM:SS (AM/PM)' },
    { id = '%I:%M %p', label = 'HH:MM (AM/PM)' },
};

function M.history_date_sep(cfg)
    local sep = cfg.historyDateSep;
    if (sep == '/' or sep == '-' or sep == '.') then
        return sep;
    end
    return '/';
end

function M.history_date_order_from_format(format)
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

function M.history_date_order(cfg)
    local order = cfg.historyDateOrder;
    if (order == 'mdy' or order == 'dmy' or order == 'ymd') then
        return order;
    end
    return M.history_date_order_from_format(cfg.historyDateFormat);
end

function M.history_date_format_for(order, sep)
    if (order == 'dmy') then
        return '%d' .. sep .. '%m' .. sep .. '%Y';
    end
    if (order == 'ymd') then
        return '%Y' .. sep .. '%m' .. sep .. '%d';
    end
    return '%m' .. sep .. '%d' .. sep .. '%Y';
end

function M.history_date_formats(sep)
    local list = {};
    for _, option in ipairs(M.HISTORY_DATE_ORDERS) do
        list[#list + 1] = {
            id = option.order,
            label = option.label:format(sep, sep),
            order = option.order,
        };
    end
    return list;
end

function M.history_format_label(list, id)
    for _, option in ipairs(list) do
        if (option.id == id) then
            return option.label;
        end
    end
    return list[1] and list[1].label or tostring(id or '');
end

function M.ensure_history_formats(cfg)
    local sep = M.history_date_sep(cfg);
    local order = M.history_date_order(cfg);
    cfg.historyDateSep = sep;
    cfg.historyDateOrder = order;
    cfg.historyDateFormat = M.history_date_format_for(order, sep);
    local timeOk = false;
    for _, option in ipairs(M.HISTORY_TIME_FORMATS) do
        if (option.id == cfg.historyTimeFormat) then
            timeOk = true;
            break;
        end
    end
    if (not timeOk) then
        cfg.historyTimeFormat = '%H:%M:%S';
    end
end

function M.history_entry_stamp(entry)
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

function M.history_apply_ampm(hour, ampm)
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

function M.history_to_stamp(year, month, day, hour, min, sec)
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

function M.parse_history_time(text)
    if (type(text) ~= 'string' or text == '') then
        return nil;
    end
    text = (text:gsub('^%s+', ''):gsub('%s+$', ''));
    text = text:gsub('%[', ''):gsub('%]', '');

    local year, month, day, hour, min, sec, ampm;

    year, month, day, hour, min, sec = text:match('^(%d%d%d%d)[/.-](%d%d)[/.-](%d%d)%s+(%d%d):(%d%d):(%d%d)$');
    if (year ~= nil) then
        return M.history_to_stamp(year, month, day, hour, min, sec);
    end
    year, month, day, hour, min = text:match('^(%d%d%d%d)[/.-](%d%d)[/.-](%d%d)%s+(%d%d):(%d%d)$');
    if (year ~= nil) then
        return M.history_to_stamp(year, month, day, hour, min, 0);
    end

    month, day, year, hour, min, sec, ampm = text:match('^(%d%d)[/.-](%d%d)[/.-](%d%d%d%d)%s+(%d%d):(%d%d):(%d%d)%s*([AaPp][Mm])$');
    if (month ~= nil) then
        return M.history_to_stamp(year, month, day, M.history_apply_ampm(hour, ampm), min, sec);
    end
    month, day, year, hour, min, ampm = text:match('^(%d%d)[/.-](%d%d)[/.-](%d%d%d%d)%s+(%d%d):(%d%d)%s*([AaPp][Mm])$');
    if (month ~= nil) then
        return M.history_to_stamp(year, month, day, M.history_apply_ampm(hour, ampm), min, 0);
    end
    month, day, year, hour, min, sec = text:match('^(%d%d)[/.-](%d%d)[/.-](%d%d%d%d)%s+(%d%d):(%d%d):(%d%d)$');
    if (month ~= nil) then
        local a, b = tonumber(month), tonumber(day);
        if (a ~= nil and a > 12 and b ~= nil and b <= 12) then
            return M.history_to_stamp(year, day, month, hour, min, sec);
        end
        return M.history_to_stamp(year, month, day, hour, min, sec);
    end
    month, day, year, hour, min = text:match('^(%d%d)[/.-](%d%d)[/.-](%d%d%d%d)%s+(%d%d):(%d%d)$');
    if (month ~= nil) then
        local a, b = tonumber(month), tonumber(day);
        if (a ~= nil and a > 12 and b ~= nil and b <= 12) then
            return M.history_to_stamp(year, day, month, hour, min, 0);
        end
        return M.history_to_stamp(year, month, day, hour, min, 0);
    end

    return nil;
end

function M.format_history_stamp(cfg, stamp)
    M.ensure_history_formats(cfg);
    local dateFmt = M.history_date_format_for(M.history_date_order(cfg), M.history_date_sep(cfg));
    local timeFmt = cfg.historyTimeFormat or '%H:%M:%S';
    local okDate, dateText = pcall(os.date, dateFmt, stamp);
    local okTime, timeText = pcall(os.date, timeFmt, stamp);
    if (okDate and okTime and type(dateText) == 'string' and type(timeText) == 'string') then
        return dateText .. ' [' .. timeText .. ']';
    end
    return os.date('%m/%d/%Y', stamp) .. ' [' .. os.date('%H:%M:%S', stamp) .. ']';
end

function M.ensure_history_stamps(cfg)
    if (type(cfg.history) ~= 'table') then
        return;
    end
    for _, entry in ipairs(cfg.history) do
        if (entry ~= nil) then
            local stamp = M.history_entry_stamp(entry);
            if (stamp == nil) then
                stamp = M.parse_history_time(entry.time);
            end
            if (stamp ~= nil) then
                entry.stamp = stamp;
            end
        end
    end
end

function M.reformat_history(cfg, save, state)
    M.ensure_history_formats(cfg);
    M.ensure_history_stamps(cfg);
    for _, entry in ipairs(cfg.history or {}) do
        local stamp = M.history_entry_stamp(entry);
        if (stamp ~= nil) then
            entry.stamp = stamp;
            entry.time = M.format_history_stamp(cfg, stamp);
        end
    end
    kit.bump_list(state, 'history');
    if (save ~= nil) then
        save();
    end
end

function M.push_history(cfg, payload, save, state)
    if (type(cfg.history) ~= 'table') then
        cfg.history = {};
    end
    local stamp = os.time();
    table.insert(cfg.history, 1, {
        stamp = stamp,
        time = M.format_history_stamp(cfg, stamp),
        command = payload,
    });
    kit.trim_history(cfg);
    kit.bump_list(state, 'history');
    save();
end

function M.draw_history_page(state, cfg, save, query)
    if (type(cfg.history) ~= 'table') then
        cfg.history = {};
    end
    kit.trim_history(cfg);
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
        local stamp = M.history_entry_stamp(entry);
        if (stamp == nil) then
            stamp = M.parse_history_time(entry.time);
            if (stamp ~= nil) then
                entry.stamp = stamp;
            end
        end
        if (stamp ~= nil) then
            local formatted = M.format_history_stamp(cfg, stamp);
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
    kit.draw_list_loading(cache);
    if (#entries == 0 and cache.ready) then
        widgets.empty_state('Executed commands will show up here.');
        return;
    end
    local removeAt = nil;
    for rowIndex, row in ipairs(cache.rows) do
        local index = row.index;
        local entry = row.entry;
        local command = entry.command or '';
        local textH, controlH, lineH = kit.row_metrics();
        local rowX = imgui.GetCursorPosX();
        local rowY = imgui.GetCursorPosY();
        local rowW = kit.remaining_width();
        local execW = kit.px(88);
        local iconW = widgets.icon_button_size();
        local gap = kit.px(kit.GAP);
        local when = entry.time or '';
        local textY = rowY + math.max(0, (lineH - textH) * 0.5);
        local buttonY = rowY + math.max(0, (lineH - controlH) * 0.5);
        imgui.SetCursorPos({ rowX, textY });
        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.muted);
        imgui.Text(when);
        imgui.PopStyleColor();
        local cursorX = rowX + kit.text_px(when) + gap;
        imgui.SetCursorPos({ cursorX, textY });
        imgui.Text(command);
        local right = rowX + rowW;
        imgui.SetCursorPos({ right - iconW - gap - execW, buttonY });
        if (widgets.execute('hist' .. index .. tostring(entry.stamp or entry.time or ''))) then
            kit.run_payload(cfg, entry.command, save, state.errors, 'hist' .. index, state);
        end
        imgui.SetCursorPos({ right - iconW, buttonY });
        if (widgets.remove('hist' .. index .. tostring(entry.stamp or entry.time or ''))) then
            removeAt = index;
        end
        if (state.errors['hist' .. index] ~= nil) then
            imgui.SetCursorPos({ rowX, textY + textH + kit.px(2) });
            imgui.PushStyleColor(ImGuiCol_Text, theme.colors.remove);
            imgui.Text(state.errors['hist' .. index]);
            imgui.PopStyleColor();
        end
        imgui.SetCursorPos({ rowX, rowY + lineH });
        kit.submit_space(0);
        if (rowIndex < #cache.rows) then
            imgui.Separator();
        end
    end
    if (removeAt ~= nil) then
        table.remove(cfg.history, removeAt);
        kit.bump_list(state, 'history');
        save();
    end
    if (#cache.rows == 0 and cache.ready and #entries > 0) then
        widgets.empty_state('No commands match.');
    end
end

return M;
