--[[
* GM Helper Settings page.
]]

require('common');

local imgui = require('imgui');
local kit = require('libs.ui.kit');
local listload = require('libs.listload');
local theme = require('libs.theme');
local widgets = require('libs.widgets');
local history = require('libs.ui.history');

local M = {};

function M.begin_settings_section(title)
    widgets.section_heading(title);
end

function M.begin_dimmed()
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

function M.end_dimmed(dimmed)
    if (imgui.EndDisabled ~= nil) then
        pcall(imgui.EndDisabled);
    end
    if (dimmed and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar();
    end
end

function M.draw_format_combo(label, id, current, options, onPick)
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label(label);
    imgui.SameLine();
    local labels = {};
    for _, option in ipairs(options) do
        labels[#labels + 1] = option.label;
    end
    local shown = history.history_format_label(options, current);
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

function M.draw_settings_page(state, cfg, save)
    M.begin_settings_section('General');
    kit.draw_tier(cfg, save);
    imgui.Spacing();
    local scaleDim = M.begin_dimmed();
    if (state.scaleBuf == nil) then
        state.scaleBuf = T{ cfg.scale or 1 };
    end
    state.scaleBuf[1] = cfg.scale or 1;
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label('Scale');
    imgui.SameLine();
    imgui.SetNextItemWidth(kit.px(220));
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
    M.end_dimmed(scaleDim);

    imgui.Spacing();
    imgui.Spacing();
    M.begin_settings_section('Presets');
    if (state.commandDelayBuf == nil) then
        state.commandDelayBuf = T{ cfg.commandDelay or 1.5 };
    end
    state.commandDelayBuf[1] = cfg.commandDelay or 1.5;
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label('Command Delay');
    imgui.SameLine();
    imgui.SetNextItemWidth(kit.px(220));
    local delayChanged = false;
    if (imgui.SliderFloat ~= nil) then
        local ok, changed = pcall(imgui.SliderFloat, '##commanddelay', state.commandDelayBuf, 0.5, 5, '%.1f');
        if (ok) then
            delayChanged = changed == true;
        else
            local ok2, changed2 = pcall(imgui.SliderFloat, '##commanddelay', state.commandDelayBuf, 0.5, 5);
            if (ok2) then
                delayChanged = changed2 == true;
            end
        end
    end
    local delay = tonumber(state.commandDelayBuf[1]) or 1.5;
    delay = math.floor(delay * 10 + 0.5) / 10;
    if (delay < 0.5) then
        delay = 0.5;
    elseif (delay > 5) then
        delay = 5;
    end
    if (delay ~= state.commandDelayBuf[1]) then
        state.commandDelayBuf[1] = delay;
        delayChanged = true;
    end
    if (delayChanged and cfg.commandDelay ~= delay) then
        cfg.commandDelay = delay;
        save();
    end
    imgui.SameLine();
    imgui.Text(('%.1fs'):format(cfg.commandDelay or 1.5));
    imgui.Spacing();
    widgets.helper_text('Seconds between each command when a preset runs.');

    imgui.Spacing();
    imgui.Spacing();
    M.begin_settings_section('History');
    history.ensure_history_formats(cfg);
    local dateFormats = history.history_date_formats(history.history_date_sep(cfg));
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label('Date');
    imgui.SameLine();
    local dateLabels = {};
    for _, option in ipairs(dateFormats) do
        dateLabels[#dateLabels + 1] = option.label;
    end
    local dateShown = history.history_format_label(dateFormats, history.history_date_order(cfg));
    local dateFlags = ImGuiComboFlags_PopupAlignLeft;
    local dateOpened, dateCentered, dateListW = widgets.begin_labels_combo('##historydate', dateShown, dateLabels, dateFlags);
    if (dateOpened) then
        for index, option in ipairs(dateFormats) do
            if (widgets.labels_combo_option('historydate' .. index, option.label, option.order == history.history_date_order(cfg), dateListW)) then
                cfg.historyDateOrder = option.order;
                cfg.historyDateFormat = history.history_date_format_for(option.order, history.history_date_sep(cfg));
                history.reformat_history(cfg, save, state);
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
    local sep = history.history_date_sep(cfg);
    local sepFlags = ImGuiComboFlags_PopupAlignLeft;
    local sepOpened, sepCentered, sepListW = widgets.begin_labels_combo('##historydatesep', sep, history.HISTORY_DATE_SEPS, sepFlags);
    if (sepOpened) then
        for index, option in ipairs(history.HISTORY_DATE_SEPS) do
            if (widgets.labels_combo_option('historydatesep' .. index, option, option == sep, sepListW)) then
                cfg.historyDateSep = option;
                cfg.historyDateFormat = history.history_date_format_for(history.history_date_order(cfg), option);
                history.reformat_history(cfg, save, state);
            end
        end
        widgets.end_labels_combo(sepOpened, sepCentered);
    end
    imgui.Spacing();
    M.draw_format_combo('Time', 'historytime', cfg.historyTimeFormat, history.HISTORY_TIME_FORMATS, function(id)
        cfg.historyTimeFormat = id;
        history.reformat_history(cfg, save, state);
    end);
    imgui.Spacing();
    if (state.historyMaxBuf == nil) then
        state.historyMaxBuf = T{ kit.history_max(cfg) };
    end
    state.historyMaxBuf[1] = kit.history_max(cfg);
    if (imgui.AlignTextToFramePadding ~= nil) then
        imgui.AlignTextToFramePadding();
    end
    widgets.label('Max Entries');
    imgui.SameLine();
    imgui.SetNextItemWidth(kit.px(220));
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
        kit.trim_history(cfg);
        kit.bump_list(state, 'history');
        save();
    end
    imgui.SameLine();
    imgui.Text(tostring(snapped));
    imgui.Spacing();
    widgets.helper_text('Formats timestamps and how many History entries to keep.');

    imgui.Spacing();
    imgui.Spacing();
    M.begin_settings_section('Help');
    local help = {
        { cmd = '/gmh   /gmhelper', desc = 'Opens or closes the GM Helper window.' },
        { cmd = '/gmh favorites <tab> <number>', desc = 'Runs a favorite from that tab by its row number.' },
        { cmd = '/gmh scripts <tab> <number>', desc = 'Runs a script from that tab by its row number.' },
        { cmd = '/gmh presets <number>', desc = 'Runs a preset by its row number.' },
        { cmd = '/gmh scripts stop', desc = 'Stops the script that is currently running.' },
        { cmd = '/gmh presets stop', desc = 'Stops the preset that is currently running.' },
    };
    for index, entry in ipairs(help) do
        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.royal);
        imgui.Text(entry.cmd);
        imgui.PopStyleColor();
        widgets.helper_text(entry.desc);
        if (index < #help) then
            imgui.Spacing();
        end
    end
end

return M;
