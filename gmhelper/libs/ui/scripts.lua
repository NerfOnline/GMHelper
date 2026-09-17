--[[
* GM Helper Scripts tab — user script tabs (saved).
]]

require('common');

local imgui = require('imgui');
local kit = require('libs.ui.kit');
local listload = require('libs.listload');
local theme = require('libs.theme');
local widgets = require('libs.widgets');

local M = {};

local FISHING_OBSERVATION_LINES = T{
    '/echo ===== Starting Observation =====',
    '/check <t>',
    '!getskill fishing <t> <wait 60>',
    '/echo 1 minute <wait 60>',
    '/echo 2 minutes <wait 60>',
    '/echo 3 minutes <wait 60>',
    '/echo 4 minutes <wait 60>',
    '/echo 5 minutes',
    '/echo ===== Observation Over =====',
};

function M.fishing_observation_script()
    return T{
        id = 'fishing-observation',
        name = 'Fishing Observation',
        lines = FISHING_OBSERVATION_LINES,
        body = table.concat(FISHING_OBSERVATION_LINES, '\n'),
    };
end

function M.seed_builtin_scripts(cfg)
    if (cfg == nil or cfg.scriptBuiltinsSeeded == true) then
        return;
    end
    cfg.scriptBuiltinsSeeded = true;
    local tab = nil;
    for _, saved in ipairs(cfg.scriptTabs or {}) do
        if (saved.id == 'default') then
            tab = saved;
            break;
        end
    end
    if (tab == nil) then
        tab = cfg.scriptTabs and cfg.scriptTabs[1];
    end
    if (tab == nil) then
        return;
    end
    if (type(tab.items) ~= 'table') then
        tab.items = T{};
    end
    for _, item in ipairs(tab.items) do
        if (type(item) == 'table' and item.id == 'fishing-observation') then
            return;
        end
    end
    table.insert(tab.items, 1, M.fishing_observation_script());
end

function M.ensure_script_tabs(cfg)
    if (type(cfg.scriptTabs) ~= 'table') then
        cfg.scriptTabs = T{};
    end
    cfg.nextScriptId = cfg.nextScriptId or 1;
    local tabs = {};
    for _, tab in ipairs(cfg.scriptTabs) do
        if (type(tab) == 'table' and tab.id ~= 'presets') then
            tab.locked = false;
            if (type(tab.items) ~= 'table') then
                tab.items = T{};
            end
            if (tab.name == nil or tab.name == '') then
                tab.name = 'Tab';
            end
            if (tab.id == nil or tab.id == '') then
                cfg.nextScriptId = (cfg.nextScriptId or 1) + 1;
                tab.id = 'tab' .. tostring(cfg.nextScriptId);
            end
            tabs[#tabs + 1] = tab;
        end
    end
    if (#tabs == 0) then
        tabs[1] = T{ id = 'default', name = 'Default', items = T{} };
    end
    cfg.scriptTabs = tabs;
    M.seed_builtin_scripts(cfg);
end

function M.script_tab(cfg, id)
    M.ensure_script_tabs(cfg);
    for _, tab in ipairs(cfg.scriptTabs) do
        if (tab.id == id) then
            return tab;
        end
    end
    return cfg.scriptTabs[1];
end

function M.selected_script_tab(state, cfg)
    M.ensure_script_tabs(cfg);
    local tab = M.script_tab(cfg, state.scriptTab);
    state.scriptTab = tab.id;
    return tab;
end

function M.script_tab_count(cfg)
    M.ensure_script_tabs(cfg);
    return #cfg.scriptTabs;
end

function M.script_search(state, tabId)
    if (state.scriptSearches == nil) then
        state.scriptSearches = {};
    end
    local key = tostring(tabId or 'default');
    if (state.scriptSearches[key] == nil) then
        state.scriptSearches[key] = T{ '' };
    end
    return state.scriptSearches[key];
end

function M.draw_scripts_page(state, cfg, save)
    local tab = M.selected_script_tab(state, cfg);
    local queryBuf = M.script_search(state, tab.id);
    local query = kit.trim_query(queryBuf[1]);
    local items = tab.items or {};
    local token = table.concat({
        'script',
        tostring(tab.id),
        query,
        tostring(#items),
        tostring(state.scriptListEpoch or 0),
    }, '|');
    local cache = listload.cache(state, 'scripts', token, #items);
    listload.pump(cache, function(index)
        local item = items[index];
        if (item == nil) then
            return;
        end
        local label = tostring(item.name or item.id or 'Script');
        if (query == '' or label:lower():find(query, 1, true) ~= nil) then
            cache.rows[#cache.rows + 1] = { item = item, slot = index };
        end
    end);
    kit.draw_list_loading(cache);

    local showedList = false;
    if (#items == 0 and cache.ready) then
        widgets.empty_state('No scripts in this tab yet.');
    elseif (#cache.rows == 0 and cache.ready) then
        widgets.empty_state('No scripts match.');
    elseif (#cache.rows > 0) then
        showedList = true;
        local numW = kit.line_num_width(#items);
        local grabW = kit.row_grab_width();
        local leftW = grabW + numW;
        local startX = imgui.GetCursorPosX();
        local listSpace = kit.begin_command_list_spacing();
        kit.rowDrag.liveRows = cache.rows;
        local rows = cache.rows;
        local _, listTopY = kit.cursor_screen_pos();
        if (kit.rowDrag.active == true and kit.rowDrag.kind == 'scriptrow') then
            kit.resolve_row_drag_from_heights('scriptrow', listTopY, kit.px(kit.LIST_GAP_Y));
            rows = kit.row_drag_layout(cache.rows, kit.rowDrag.from, kit.rowDrag.toVis);
        end
        for index, row in ipairs(rows) do
            if (row.hole == true) then
                local holeH = row.height or kit.rowDrag.rowH or kit.px(28);
                kit.draw_row_placeholder('script' .. tostring(tab.id) .. '_' .. tostring(row.slot), kit.remaining_width(), holeH, 'scriptrow', index);
                if (index < #rows) then
                    imgui.Separator();
                end
            else
                local item = row.item;
                local label = item.name or item.id or 'Script';
                local y = imgui.GetCursorPosY();
                local textH, controlH, lineH = kit.row_metrics();
                local rowH = lineH;
                local nameY = y + math.max(0, (lineH - textH) * 0.5);
                local buttonY = y + math.max(0, (lineH - controlH) * 0.5);
                local dragLabel = tostring(row.slot) .. '  ' .. tostring(label);
                local rowW = kit.remaining_width();
                local favW = widgets.icon_button_size();
                local execW = kit.px(kit.EXEC_W);
                local gap = kit.px(kit.GAP);
                local pair = execW + gap + favW;
                imgui.SetCursorPos({ startX, y });
                local rowSX, rowSY = kit.cursor_screen_pos();
                kit.draw_row_drag_handle(
                    'scriptdrag' .. tostring(tab.id) .. '_' .. tostring(row.slot),
                    startX,
                    y,
                    leftW,
                    rowH,
                    'scriptrow',
                    row.slot,
                    items,
                    state,
                    'scripts',
                    dragLabel,
                    grabW,
                    nameY + textH * 0.5,
                    {
                        kind = 'script',
                        lineNum = row.slot,
                        cmdText = tostring(label),
                        numW = numW,
                        rowH = rowH,
                        rowW = rowW,
                        rowSX = rowSX,
                        rowSY = rowSY,
                        label = label,
                    }
                );
                kit.draw_line_num(row.slot, numW, startX + grabW, nameY, textH);
                local nameX = startX + leftW;
                local labelText = tostring(label);
                local nameW = kit.text_px(labelText);
                imgui.SetCursorPos({ nameX, nameY });
                imgui.Text(labelText);
                local tip = M.tooltip_text(item);
                if (tip ~= nil and tip ~= '') then
                    kit.hover_tip(tip);
                end
                M.note_script_item_menu(state, tab.id, row.slot);
                local actionsX = startX + rowW - pair;
                local running = M.is_running(state, tab.id, row.slot);
                local run = running and state.scriptRun or nil;
                if (running and run ~= nil) then
                    local inset = kit.px(30);
                    local progX = nameX + nameW + gap + inset;
                    local progressW = math.max(1, actionsX - gap - inset - progX);
                    local progressH = math.max(1, controlH * 0.5);
                    local progY = y + (lineH - progressH) * 0.5;
                    local frac, overlay = M.progress_info(run);
                    imgui.SetCursorPos({ progX, progY });
                    kit.draw_progress_timer(frac, progressW, progressH, overlay);
                end
                imgui.SetCursorPos({ actionsX, buttonY });
                if (running) then
                    if (widgets.button('Stop', 'scriptstop' .. tostring(tab.id) .. '_' .. tostring(row.slot), execW, 'primary')) then
                        M.stop(state);
                    end
                else
                    if (widgets.execute('scriptrun' .. tostring(tab.id) .. '_' .. tostring(row.slot))) then
                        M.start(cfg, tab, row.slot, item, save, state);
                    end
                end
                imgui.SetCursorPos({ actionsX + execW + gap, buttonY });
                if (widgets.remove('scriptrm' .. tostring(tab.id) .. '_' .. tostring(row.slot))) then
                    table.remove(items, row.slot);
                    kit.bump_list(state, 'scripts');
                    save();
                end
                kit.note_row_height(row.slot, rowH);
                imgui.SetCursorPos({ startX, y + rowH });
                kit.submit_space(0);
                if (index < #rows) then
                    imgui.Separator();
                end
            end
        end
        kit.end_command_list_spacing(listSpace);
        kit.draw_row_drag_overlay();
        M.script_item_menu(state, cfg);
    end

    if (cache.ready) then
        if (showedList) then
            imgui.Separator();
            imgui.Spacing();
        else
            imgui.Spacing();
        end
        local addW = kit.px(88);
        kit.center_buttons({ addW });
        if (widgets.button('Add', 'scriptlistadd' .. tostring(tab.id), addW, 'primary')) then
            state.scriptAddOpen = true;
            state.scriptAddRequest = true;
            state.scriptAddMode = 'add';
            state.scriptEditTabId = nil;
            state.scriptEditSlot = nil;
        end
    end
end

function M.find_tab(cfg, name)
    M.ensure_script_tabs(cfg);
    local q = tostring(name or ''):lower();
    if (q == '') then
        return nil;
    end
    for _, tab in ipairs(cfg.scriptTabs) do
        if (tostring(tab.name or ''):lower() == q or tostring(tab.id or ''):lower() == q) then
            return tab;
        end
    end
    return nil;
end

local function trim_line(value)
    return (tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''));
end

--[[
* Split a script body into lines, strip inline <wait N>, and compile send/wait steps.
* Standalone /wait N lines only wait. Inline waits are removed from the sent text.
]]
function M.compile_steps(lines)
    local steps = {};
    for _, raw in ipairs(lines or {}) do
        local line = trim_line(raw);
        if (line ~= '') then
            local waitOnly = line:match('^/wait%s+([%d%.]+)%s*$');
            if (waitOnly ~= nil) then
                local seconds = tonumber(waitOnly) or 0;
                if (seconds > 0) then
                    steps[#steps + 1] = { wait = seconds };
                end
            else
                local waitAfter = 0;
                local cleaned = line:gsub('%s*<wait%s+([%d%.]+)%s*>', function(amount)
                    waitAfter = waitAfter + (tonumber(amount) or 0);
                    return '';
                end);
                cleaned = trim_line(cleaned);
                if (cleaned ~= '') then
                    steps[#steps + 1] = {
                        send = cleaned,
                        wait = waitAfter > 0 and waitAfter or nil,
                    };
                elseif (waitAfter > 0) then
                    steps[#steps + 1] = { wait = waitAfter };
                end
            end
        end
    end
    return steps;
end

function M.split_body(body)
    local lines = {};
    local text = tostring(body or '');
    text = text:gsub('\r\n', '\n'):gsub('\r', '\n');
    if (text == '') then
        return lines;
    end
    for line in (text .. '\n'):gmatch('(.-)\n') do
        lines[#lines + 1] = line;
    end
    return lines;
end

function M.is_running(state, tabId, slot)
    local run = state and state.scriptRun;
    return run ~= nil and run.tabId == tabId and run.slot == slot;
end

function M.stop(state)
    if (state ~= nil) then
        state.scriptRun = nil;
    end
end

function M.step_pause(step, isLast)
    if (isLast or step == nil) then
        return 0;
    end
    return tonumber(step.wait) or 0;
end

function M.estimate_duration(steps)
    local total = 0;
    for index, step in ipairs(steps or {}) do
        total = total + M.step_pause(step, index == #(steps or {}));
    end
    return total;
end

function M.remaining_duration(run)
    if (run == nil) then
        return 0;
    end
    local steps = run.steps or {};
    local remaining = 0;
    local now = os.clock();
    local nextAt = tonumber(run.nextAt) or 0;
    if (nextAt > now) then
        remaining = remaining + (nextAt - now);
    end
    local index = tonumber(run.index) or 1;
    for i = index, #steps do
        remaining = remaining + M.step_pause(steps[i], i == #steps);
    end
    return remaining;
end

function M.format_duration(seconds)
    local secs = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5));
    local hours = math.floor(secs / 3600);
    local mins = math.floor((secs % 3600) / 60);
    local rem = secs % 60;
    if (hours > 0) then
        return ('%d:%02d:%02d'):format(hours, mins, rem);
    end
    return ('%d:%02d'):format(mins, rem);
end

function M.progress_info(run)
    local done = math.max(0, tonumber(run and run.done) or 0);
    local total = math.max(1, tonumber(run and run.total) or 1);
    local totalSecs = tonumber(run and run.totalSecs) or 0;
    local remaining = M.remaining_duration(run);
    if (totalSecs < remaining) then
        totalSecs = remaining;
    end
    local frac;
    if (totalSecs > 0) then
        frac = 1 - (remaining / totalSecs);
    else
        frac = done / total;
    end
    if (frac < 0) then
        frac = 0;
    elseif (frac > 1) then
        frac = 1;
    end
    local overlay = '';
    if (totalSecs > 0) then
        overlay = M.format_duration(remaining);
    end
    return frac, overlay;
end

local function send_script_payload(cfg, payload, save, state)
    local say = require('libs.say');
    local ok, err = say.send_line(payload);
    if (not ok) then
        return false, err or 'Could not send.';
    end
    if (save ~= nil and state ~= nil) then
        require('libs.ui.history').push_history(cfg, payload, save, state);
    end
    return true;
end

function M.start(cfg, tab, slot, item, save, state)
    if (item == nil) then
        return false, 'Script not found.';
    end
    local lines = item.lines or item.commands;
    if (type(lines) ~= 'table' or #lines == 0) then
        return false, 'Script has no commands yet.';
    end
    local steps = M.compile_steps(lines);
    if (#steps == 0) then
        return false, 'Script has no commands yet.';
    end
    local total = 0;
    for _, step in ipairs(steps) do
        if (step.send ~= nil and step.send ~= '') then
            total = total + 1;
        end
    end
    if (total < 1) then
        total = #steps;
    end
    state.presetRun = nil;
    state.scriptRun = {
        tabId = tab and tab.id or nil,
        slot = slot,
        steps = steps,
        index = 1,
        done = 0,
        total = total,
        totalSecs = M.estimate_duration(steps),
        nextAt = 0,
        startedAt = os.clock(),
    };
    M.tick(state, cfg, save);
    return true;
end

function M.tick(state, cfg, save)
    local run = state and state.scriptRun;
    if (run == nil) then
        return;
    end
    local steps = run.steps or {};
    local guard = 0;
    while (run ~= nil and guard < 200) do
        guard = guard + 1;
        if (run.index == nil or run.index > #steps) then
            state.scriptRun = nil;
            return;
        end
        local now = os.clock();
        if (now < (run.nextAt or 0)) then
            return;
        end
        local step = steps[run.index];
        if (step == nil) then
            state.scriptRun = nil;
            return;
        end
        if (step.send ~= nil and step.send ~= '') then
            local ok = send_script_payload(cfg, step.send, save, state);
            if (not ok) then
                state.scriptRun = nil;
                return;
            end
            run.done = (run.done or 0) + 1;
        end
        local stepIndex = run.index;
        run.index = run.index + 1;
        if (run.index > #steps) then
            state.scriptRun = nil;
            return;
        end
        local pause = M.step_pause(step, stepIndex == #steps);
        if (pause > 0) then
            run.nextAt = now + pause;
            return;
        end
        run.nextAt = now;
    end
end

function M.run_line(cfg, tabName, line, save, state)
    local tab = M.find_tab(cfg, tabName);
    if (tab == nil) then
        return false, 'Unknown scripts tab.';
    end
    local index = math.floor(tonumber(line) or 0);
    local item = tab.items and tab.items[index];
    if (item == nil) then
        return false, 'Script line not found.';
    end
    return M.start(cfg, tab, index, item, save, state);
end

function M.tooltip_text(item)
    if (item == nil) then
        return '';
    end
    local lines = item.lines or item.commands;
    if (type(lines) ~= 'table') then
        local body = tostring(item.body or '');
        if (body ~= '') then
            return body;
        end
        return '';
    end
    local out = {};
    for _, line in ipairs(lines) do
        local text = trim_line(line);
        if (text ~= '') then
            out[#out + 1] = text;
        end
    end
    return table.concat(out, '\n');
end

function M.body_text(item)
    if (item == nil) then
        return '';
    end
    if (item.body ~= nil and tostring(item.body) ~= '') then
        return tostring(item.body);
    end
    local lines = item.lines or item.commands;
    if (type(lines) == 'table') then
        return table.concat(lines, '\n');
    end
    return '';
end

function M.add_script_item(cfg, tabId, name, body, save, state)
    local tab = M.script_tab(cfg, tabId);
    if (tab == nil) then
        return false, 'Unknown scripts tab.';
    end
    local shown = trim_line(name);
    if (shown == '') then
        return false, 'Script name is required.';
    end
    local lines = M.split_body(body);
    local steps = M.compile_steps(lines);
    if (#steps == 0) then
        return false, 'Add at least one command line.';
    end
    if (tab.items == nil) then
        tab.items = T{};
    end
    tab.items[#tab.items + 1] = T{
        name = shown,
        lines = lines,
        body = tostring(body or ''),
    };
    kit.bump_list(state, 'scripts');
    if (save ~= nil) then
        save();
    end
    return true;
end

function M.update_script_item(cfg, tabId, slot, name, body, save, state)
    local tab = M.script_tab(cfg, tabId);
    if (tab == nil or tab.items == nil or tab.items[slot] == nil) then
        return false, 'Script not found.';
    end
    local shown = trim_line(name);
    if (shown == '') then
        return false, 'Script name is required.';
    end
    local lines = M.split_body(body);
    local steps = M.compile_steps(lines);
    if (#steps == 0) then
        return false, 'Add at least one command line.';
    end
    local item = tab.items[slot];
    item.name = shown;
    item.lines = lines;
    item.body = tostring(body or '');
    kit.bump_list(state, 'scripts');
    if (save ~= nil) then
        save();
    end
    return true;
end

function M.open_script_editor(state, tabId, slot, item)
    state.scriptAddOpen = true;
    state.scriptAddRequest = true;
    state.scriptAddMode = 'edit';
    state.scriptEditTabId = tabId;
    state.scriptEditSlot = slot;
    state.scriptAddName = T{ tostring((item and item.name) or '') };
    state.scriptAddBody = T{ M.body_text(item) };
    state.scriptAddError = nil;
end

function M.open_script_renamer(state, tabId, slot, item)
    state.scriptItemRenameTabId = tabId;
    state.scriptItemRenameSlot = slot;
    state.scriptItemRename = { tostring((item and item.name) or '') };
    state.scriptItemRenameRequest = true;
end

function M.rename_script_item(cfg, tabId, slot, name, save, state)
    local tab = M.script_tab(cfg, tabId);
    if (tab == nil or tab.items == nil or tab.items[slot] == nil) then
        return false, 'Script not found.';
    end
    local shown = trim_line(name);
    if (shown == '') then
        return false, 'Script name is required.';
    end
    tab.items[slot].name = shown;
    kit.bump_list(state, 'scripts');
    if (save ~= nil) then
        save();
    end
    return true;
end

function M.other_script_tab_id(cfg, fromId)
    M.ensure_script_tabs(cfg);
    for _, tab in ipairs(cfg.scriptTabs) do
        if (tab.id ~= fromId) then
            return tab.id;
        end
    end
    return fromId;
end

function M.move_script_item(cfg, fromTabId, slot, toTabId, save, state)
    if (fromTabId == nil or toTabId == nil or slot == nil) then
        return false, 'Script not found.';
    end
    if (fromTabId == toTabId) then
        return true;
    end
    local fromTab = M.script_tab(cfg, fromTabId);
    local toTab = M.script_tab(cfg, toTabId);
    if (fromTab == nil or toTab == nil or fromTab.items == nil or fromTab.items[slot] == nil) then
        return false, 'Script not found.';
    end
    if (toTab.items == nil) then
        toTab.items = T{};
    end
    local item = fromTab.items[slot];
    table.remove(fromTab.items, slot);
    toTab.items[#toTab.items + 1] = item;
    if (state ~= nil) then
        state.scriptTab = toTab.id;
    end
    kit.bump_list(state, 'scripts');
    if (save ~= nil) then
        save();
    end
    return true;
end

function M.script_picker(cfg, choiceId)
    M.ensure_script_tabs(cfg);
    local shown = M.script_tab(cfg, choiceId).name or 'Default';
    local tabLabels = {};
    for _, tab in ipairs(cfg.scriptTabs) do
        tabLabels[#tabLabels + 1] = tab.name or 'Tab';
    end
    local flags = ImGuiComboFlags_PopupAlignLeft;
    local opened, centered, listW = widgets.begin_labels_combo('##scriptmovetab', shown, tabLabels, flags, 'fill');
    local picked = choiceId;
    if (opened) then
        for _, tab in ipairs(cfg.scriptTabs) do
            if (widgets.labels_combo_option('scriptmove' .. tab.id, tab.name or 'Tab', tab.id == picked, listW)) then
                picked = tab.id;
            end
        end
        widgets.end_labels_combo(opened, centered);
    end
    return picked;
end

function M.note_script_item_menu(state, tabId, slot)
    if (imgui.IsItemClicked == nil) then
        return;
    end
    local ok, clicked = pcall(imgui.IsItemClicked, 1);
    if (not ok or clicked ~= true) then
        return;
    end
    local mx, my = kit.mouse_pos();
    state.scriptItemMenuTabId = tabId;
    state.scriptItemMenuSlot = slot;
    state.scriptItemMenuPos = { mx, my };
    state.scriptItemMenuRequest = true;
end

function M.script_item_menu(state, cfg)
    if (state.scriptItemMenuTabId == nil or state.scriptItemMenuSlot == nil or imgui.BeginPopup == nil) then
        return;
    end
    local tab = M.script_tab(cfg, state.scriptItemMenuTabId);
    local slot = state.scriptItemMenuSlot;
    local item = tab and tab.items and tab.items[slot];
    if (item == nil) then
        state.scriptItemMenuRequest = false;
        state.scriptItemMenuTabId = nil;
        state.scriptItemMenuSlot = nil;
        return;
    end
    if (state.scriptItemMenuRequest) then
        if (kit.mouse_held(1) or kit.mouse_held(0)) then
            return;
        end
        if (imgui.OpenPopup ~= nil) then
            imgui.OpenPopup('###gmhelper_scriptitemmenu');
        end
        state.scriptItemMenuRequest = false;
    end
    local pos = state.scriptItemMenuPos or { 0, 0 };
    local cond = ImGuiCond_Always or 1;
    if (imgui.SetNextWindowDockID ~= nil) then
        pcall(imgui.SetNextWindowDockID, 0, cond);
    end
    if (not pcall(imgui.SetNextWindowPos, pos, cond, { 0, 0 })) then
        pcall(imgui.SetNextWindowPos, pos, cond);
    end
    local ok, result = pcall(imgui.BeginPopup, '###gmhelper_scriptitemmenu');
    local opened = ok and (result == true or (result ~= nil and result ~= false));
    if (not opened) then
        return;
    end
    local itemW = kit.px(84);
    local canMove = M.script_tab_count(cfg) > 1;
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_SelectableTextAlign ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_SelectableTextAlign, { 0.5, 0.5 });
    end
    if (kit.menu_hit('Move', canMove, itemW)) then
        state.scriptMove = {
            fromTabId = tab.id,
            slot = slot,
            toTabId = M.other_script_tab_id(cfg, tab.id),
        };
        state.scriptMoveRequest = true;
        state.scriptItemMenuTabId = nil;
        state.scriptItemMenuSlot = nil;
        if (imgui.CloseCurrentPopup ~= nil) then
            imgui.CloseCurrentPopup();
        end
    end
    if (kit.menu_hit('Rename', true, itemW)) then
        M.open_script_renamer(state, tab.id, slot, item);
        state.scriptItemMenuTabId = nil;
        state.scriptItemMenuSlot = nil;
        if (imgui.CloseCurrentPopup ~= nil) then
            imgui.CloseCurrentPopup();
        end
    end
    if (kit.menu_hit('Edit', true, itemW)) then
        M.open_script_editor(state, tab.id, slot, item);
        state.scriptItemMenuTabId = nil;
        state.scriptItemMenuSlot = nil;
        if (imgui.CloseCurrentPopup ~= nil) then
            imgui.CloseCurrentPopup();
        end
    end
    if (imgui.PopStyleVar ~= nil and ImGuiStyleVar_SelectableTextAlign ~= nil) then
        imgui.PopStyleVar();
    end
    imgui.EndPopup();
end
function M.note_script_menu(state, tab)
    if (imgui.IsItemClicked == nil) then
        return;
    end
    local ok, clicked = pcall(imgui.IsItemClicked, 1);
    if (not ok or clicked ~= true) then
        return;
    end
    local mx, my = kit.mouse_pos();
    state.scriptMenuId = tab.id;
    state.scriptMenuPos = { mx, my };
    state.scriptMenuRequest = true;
end

function M.script_tab_menu(state, cfg)
    if (state.scriptMenuId == nil or imgui.BeginPopup == nil) then
        return;
    end
    local tab = M.script_tab(cfg, state.scriptMenuId);
    if (tab == nil or tab.id ~= state.scriptMenuId) then
        state.scriptMenuRequest = false;
        state.scriptMenuId = nil;
        return;
    end
    if (state.scriptMenuRequest) then
        if (kit.mouse_held(1) or kit.mouse_held(0)) then
            return;
        end
        if (imgui.OpenPopup ~= nil) then
            imgui.OpenPopup('###gmhelper_scriptmenu');
        end
        state.scriptMenuRequest = false;
    end
    local pos = state.scriptMenuPos or { 0, 0 };
    local cond = ImGuiCond_Always or 1;
    if (imgui.SetNextWindowDockID ~= nil) then
        pcall(imgui.SetNextWindowDockID, 0, cond);
    end
    if (not pcall(imgui.SetNextWindowPos, pos, cond, { 0, 0 })) then
        pcall(imgui.SetNextWindowPos, pos, cond);
    end
    local opened = false;
    local ok, result = pcall(imgui.BeginPopup, '###gmhelper_scriptmenu');
    opened = ok and (result == true or (result ~= nil and result ~= false));
    if (not opened) then
        return;
    end
    local itemW = kit.px(84);
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_SelectableTextAlign ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_SelectableTextAlign, { 0.5, 0.5 });
    end
    if (kit.menu_hit('Rename', true, itemW)) then
        state.scriptRenameId = tab.id;
        state.scriptRename = { tab.name or '' };
        state.scriptRenameRequest = true;
        state.scriptMenuId = nil;
        if (imgui.CloseCurrentPopup ~= nil) then
            imgui.CloseCurrentPopup();
        end
    end
    if (kit.menu_hit('Delete', M.script_tab_count(cfg) > 1, itemW)) then
        state.scriptDeleteId = tab.id;
        state.scriptDeleteName = tab.name or 'this tab';
        state.scriptDeleteRequest = true;
        state.scriptMenuId = nil;
        if (imgui.CloseCurrentPopup ~= nil) then
            imgui.CloseCurrentPopup();
        end
    end
    if (imgui.PopStyleVar ~= nil and ImGuiStyleVar_SelectableTextAlign ~= nil) then
        imgui.PopStyleVar();
    end
    imgui.EndPopup();
end

function M.next_script_name(cfg)
    local used = {};
    for _, tab in ipairs(cfg.scriptTabs) do
        used[tab.name] = true;
    end
    local number = M.script_tab_count(cfg) + 1;
    local name = 'Tab ' .. tostring(number);
    while (used[name]) do
        number = number + 1;
        name = 'Tab ' .. tostring(number);
    end
    return name;
end

function M.add_script_tab(state, cfg, save)
    M.ensure_script_tabs(cfg);
    cfg.nextScriptId = (cfg.nextScriptId or 1) + 1;
    local tab = T{
        id = 'tab' .. tostring(cfg.nextScriptId),
        name = M.next_script_name(cfg),
        items = T{},
    };
    cfg.scriptTabs[#cfg.scriptTabs + 1] = tab;
    state.scriptTab = tab.id;
    save();
end

function M.draw_script_tabs(state, cfg, save)
    M.ensure_script_tabs(cfg);
    local startX = imgui.GetCursorPosX();
    local startY = imgui.GetCursorPosY();
    local indent = kit.px(kit.ROUND);
    if (imgui.SetCursorPosX ~= nil) then
        imgui.SetCursorPosX(startX + indent);
    end
    local usable = math.max(1, kit.remaining_width() - indent);
    local right = startX + indent + usable;
    local cursorX = startX + indent;
    local row = 0;
    local rowH = kit.px(30);
    local current = M.selected_script_tab(state, cfg);
    for index, tab in ipairs(cfg.scriptTabs) do
        local width = math.max(kit.px(48), math.ceil(kit.text_px(tab.name or '') + kit.px(20)));
        if (cursorX > startX + indent and cursorX + width > right and imgui.SetCursorPos ~= nil) then
            row = row + 1;
            cursorX = startX + indent;
            imgui.SetCursorPos({ cursorX, startY + row * rowH });
        elseif (index > 1) then
            imgui.SameLine(0, 0);
        end
        local clicked = kit.nav_button(tab.name or 'Tab', 'scripttab' .. tab.id, current.id == tab.id, width);
        cursorX = cursorX + width;
        kit.note_tab_drag('script', index);
        kit.accept_tab_drop('script', index, cfg.scriptTabs);
        M.note_script_menu(state, tab);
        if (clicked and not kit.tabDrag.moved) then
            state.scriptTab = tab.id;
            state.section = 'scripts';
        end
    end
    local addW = kit.px(30);
    if (cursorX > startX + indent and cursorX + addW > right and imgui.SetCursorPos ~= nil) then
        row = row + 1;
        cursorX = startX + indent;
        imgui.SetCursorPos({ cursorX, startY + row * rowH });
    else
        imgui.SameLine(0, 0);
    end
    if (kit.nav_button('+', 'scripttabadd', false, kit.px(30)) and not kit.tabDrag.moved) then
        M.add_script_tab(state, cfg, save);
    end
    if (kit.tabDrag.kind == 'script' and kit.tabDrag.from ~= nil and imgui.IsItemHovered ~= nil and imgui.IsItemHovered() and imgui.IsMouseDragging ~= nil and imgui.IsMouseDragging(0, 0)) then
        local last = #cfg.scriptTabs;
        if (kit.tabDrag.from ~= last) then
            kit.move_item(cfg.scriptTabs, kit.tabDrag.from, last);
            kit.tabDrag.from = last;
            kit.tabDrag.moved = true;
        end
    end
    if (imgui.SetCursorPos ~= nil) then
        imgui.SetCursorPos({ startX, startY + (row + 1) * rowH - kit.px(kit.GAP) });
        kit.submit_space(0);
    end
    M.script_tab_menu(state, cfg);
end

function M.delete_script_tab(state, cfg, save, tabId)
    if (M.script_tab_count(cfg) <= 1) then
        return;
    end
    local nextTabs = {};
    for _, saved in ipairs(cfg.scriptTabs) do
        if (saved.id ~= tabId) then
            nextTabs[#nextTabs + 1] = saved;
        end
    end
    cfg.scriptTabs = nextTabs;
    M.ensure_script_tabs(cfg);
    if (state.scriptTab == tabId) then
        state.scriptTab = cfg.scriptTabs[1].id;
    end
    kit.bump_list(state, 'scripts');
    save();
end

function M.draw_script_rename_modal(state, cfg, save)
    if (state.scriptRenameRequest ~= true and state.scriptRenameId == nil) then
        return;
    end
    local tab = M.script_tab(cfg, state.scriptRenameId);
    if (tab == nil) then
        state.scriptRenameRequest = false;
        state.scriptRenameId = nil;
        return;
    end
    if (state.scriptRenameRequest and kit.mouse_held(0)) then
        return;
    end
    local request = state.scriptRenameRequest == true;
    if (not kit.begin_modal('scriptrename', 'Rename Tab', request)) then
        return;
    end
    state.scriptRenameRequest = false;
    widgets.helper_text('Rename this scripts tab.', theme.colors.text);
    imgui.Spacing();
    imgui.SetNextItemWidth(-1);
    local enterFlags = ImGuiInputTextFlags_EnterReturnsTrue or 64;
    local result = nil;
    local ok, changed = pcall(imgui.InputText, '##scriptrenamefield', state.scriptRename, 64, enterFlags);
    if (ok) then
        result = changed;
    else
        result = imgui.InputText('##scriptrenamefield', state.scriptRename, 64);
    end
    if (type(result) == 'string') then
        state.scriptRename[1] = result;
        result = false;
    end
    imgui.Spacing();
    local buttonW = kit.modal_button_width();
    kit.center_buttons({ buttonW, buttonW });
    if (widgets.button('Confirm', 'scriptrenameconfirm', buttonW, 'primary') or result == true) then
        if (kit.apply_rename(tab, state.scriptRename, save)) then
            state.scriptRenameId = nil;
            state.scriptRenameRequest = false;
        end
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'scriptrenamecancel', buttonW, 'secondary')) then
        state.scriptRenameId = nil;
        state.scriptRenameRequest = false;
    end
    kit.end_modal('scriptrename');
end

function M.draw_script_item_rename_modal(state, cfg, save)
    if (state.scriptItemRenameRequest ~= true and state.scriptItemRenameTabId == nil) then
        return;
    end
    local tab = M.script_tab(cfg, state.scriptItemRenameTabId);
    local slot = state.scriptItemRenameSlot;
    local item = tab and tab.items and tab.items[slot];
    if (item == nil) then
        state.scriptItemRenameRequest = false;
        state.scriptItemRenameTabId = nil;
        state.scriptItemRenameSlot = nil;
        return;
    end
    if (state.scriptItemRenameRequest and kit.mouse_held(0)) then
        return;
    end
    local request = state.scriptItemRenameRequest == true;
    if (not kit.begin_modal('scriptitemrename', 'Rename Script', request)) then
        return;
    end
    state.scriptItemRenameRequest = false;
    if (state.scriptItemRename == nil) then
        state.scriptItemRename = { tostring(item.name or '') };
    end
    widgets.helper_text('Rename this script.', theme.colors.text);
    imgui.Spacing();
    imgui.SetNextItemWidth(-1);
    local enterFlags = ImGuiInputTextFlags_EnterReturnsTrue or 64;
    local result = nil;
    local ok, changed = pcall(imgui.InputText, '##scriptitemrenamefield', state.scriptItemRename, 64, enterFlags);
    if (ok) then
        result = changed;
    else
        result = imgui.InputText('##scriptitemrenamefield', state.scriptItemRename, 64);
    end
    if (type(result) == 'string') then
        state.scriptItemRename[1] = result;
        result = false;
    end
    imgui.Spacing();
    local buttonW = kit.modal_button_width();
    kit.center_buttons({ buttonW, buttonW });
    if (widgets.button('Confirm', 'scriptitemrenameconfirm', buttonW, 'primary') or result == true) then
        local renamed = M.rename_script_item(
            cfg,
            state.scriptItemRenameTabId,
            state.scriptItemRenameSlot,
            state.scriptItemRename[1],
            save,
            state
        );
        if (renamed) then
            state.scriptItemRenameTabId = nil;
            state.scriptItemRenameSlot = nil;
            state.scriptItemRenameRequest = false;
        end
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'scriptitemrenamecancel', buttonW, 'secondary')) then
        state.scriptItemRenameTabId = nil;
        state.scriptItemRenameSlot = nil;
        state.scriptItemRenameRequest = false;
    end
    kit.end_modal('scriptitemrename');
end

function M.draw_script_delete_modal(state, cfg, save)
    if (state.scriptDeleteRequest ~= true and state.scriptDeleteId == nil) then
        return;
    end
    if (M.script_tab_count(cfg) <= 1) then
        state.scriptDeleteId = nil;
        state.scriptDeleteRequest = false;
        return;
    end
    if (state.scriptDeleteRequest and kit.mouse_held(0)) then
        return;
    end
    local request = state.scriptDeleteRequest == true;
    if (not kit.begin_modal('scriptdelete', 'Delete Tab', request)) then
        return;
    end
    state.scriptDeleteRequest = false;
    local name = state.scriptDeleteName or 'this tab';
    imgui.Text('Delete "' .. name .. '"?');
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.peach);
    local warn = 'Scripts in this tab will be removed.';
    if (imgui.TextWrapped ~= nil) then
        imgui.TextWrapped(warn);
    else
        imgui.Text(warn);
    end
    imgui.PopStyleColor();
    imgui.Spacing();
    local buttonW = kit.modal_button_width();
    kit.center_buttons({ buttonW, buttonW });
    if (widgets.button('Delete', 'scriptdeleteconfirm', buttonW, 'danger')) then
        M.delete_script_tab(state, cfg, save, state.scriptDeleteId);
        state.scriptDeleteId = nil;
        state.scriptDeleteRequest = false;
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'scriptdeletecancel', buttonW, 'secondary')) then
        state.scriptDeleteId = nil;
        state.scriptDeleteRequest = false;
    end
    kit.end_modal('scriptdelete');
end

function M.draw_script_move_modal(state, cfg, save)
    if (state.scriptMove == nil) then
        return;
    end
    if (state.scriptMoveRequest and kit.mouse_held(0)) then
        return;
    end
    local request = state.scriptMoveRequest == true;
    if (not kit.begin_modal('scriptmove', 'Move Script', request)) then
        return;
    end
    state.scriptMoveRequest = false;
    widgets.helper_text('Choose a scripts tab.', theme.colors.text);
    imgui.Spacing();
    state.scriptMove.toTabId = M.script_picker(cfg, state.scriptMove.toTabId);
    imgui.Spacing();
    local buttonW = kit.modal_button_width();
    kit.center_buttons({ buttonW, buttonW });
    if (widgets.button('Confirm', 'scriptmoveconfirm', buttonW, 'primary')) then
        M.move_script_item(
            cfg,
            state.scriptMove.fromTabId,
            state.scriptMove.slot,
            state.scriptMove.toTabId,
            save,
            state
        );
        state.scriptMove = nil;
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'scriptmovecancel', buttonW, 'secondary')) then
        state.scriptMove = nil;
    end
    kit.end_modal('scriptmove');
end

function M.draw_script_add_modal(state, cfg, save)
    if (state.scriptAddOpen ~= true) then
        return;
    end
    if (state.scriptAddRequest and kit.mouse_held(0)) then
        return;
    end
    local editing = state.scriptAddMode == 'edit';
    if (state.scriptAddRequest == true) then
        if (not editing) then
            state.scriptAddName = T{ '' };
            state.scriptAddBody = T{ '' };
            state.scriptEditTabId = nil;
            state.scriptEditSlot = nil;
        end
        state.scriptAddError = nil;
    end
    local request = state.scriptAddRequest == true;
    local title = editing and 'Edit Script' or 'Add Script';
    if (not kit.begin_modal('scriptadd', title, request, { contentW = kit.px(350) })) then
        return;
    end
    state.scriptAddRequest = false;
    if (state.scriptAddName == nil) then
        state.scriptAddName = T{ '' };
    end
    if (state.scriptAddBody == nil) then
        state.scriptAddBody = T{ '' };
    end

    widgets.label('Name');
    local fieldW = kit.remaining_width();
    widgets.placeholder('scriptaddname', state.scriptAddName, 'Script name', fieldW);
    imgui.Spacing();
    widgets.label('Commands');
    local lineH = kit.text_height();
    if (imgui.GetTextLineHeight ~= nil) then
        local ok, h = pcall(imgui.GetTextLineHeight);
        if (ok and type(h) == 'number' and h > 0) then
            lineH = h;
        end
    end
    -- FramePadding.y is 6 in theme; +1 avoids float clip that would scroll on line 18.
    local bodyH = math.ceil(lineH * 18 + kit.px(6) * 2) + 1;
    widgets.multiline('scriptaddbody', state.scriptAddBody, '/echo hello <wait 1>', fieldW, bodyH, 16384);
    if (state.scriptAddError ~= nil and state.scriptAddError ~= '') then
        imgui.Spacing();
        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.remove);
        imgui.Text(tostring(state.scriptAddError));
        imgui.PopStyleColor();
    end
    imgui.Spacing();
    local buttonW = kit.modal_button_width();
    kit.center_buttons({ buttonW, buttonW });
    if (widgets.button('Confirm', 'scriptaddconfirm', buttonW, 'primary')) then
        local ok, err;
        if (editing) then
            ok, err = M.update_script_item(
                cfg,
                state.scriptEditTabId,
                state.scriptEditSlot,
                state.scriptAddName[1],
                state.scriptAddBody[1],
                save,
                state
            );
        else
            local tab = M.selected_script_tab(state, cfg);
            ok, err = M.add_script_item(cfg, tab.id, state.scriptAddName[1], state.scriptAddBody[1], save, state);
        end
        if (ok) then
            state.scriptAddOpen = false;
            state.scriptAddMode = nil;
            state.scriptEditTabId = nil;
            state.scriptEditSlot = nil;
            state.scriptAddError = nil;
        else
            state.scriptAddError = err or 'Could not save script.';
        end
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'scriptaddcancel', buttonW, 'secondary')) then
        state.scriptAddOpen = false;
        state.scriptAddMode = nil;
        state.scriptEditTabId = nil;
        state.scriptEditSlot = nil;
        state.scriptAddError = nil;
    end
    kit.end_modal('scriptadd');
end
return M;
