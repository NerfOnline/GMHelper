--[[
* GM Helper Commands tab.
]]

require('common');

local imgui = require('imgui');
local kit = require('libs.ui.kit');
local listload = require('libs.listload');
local tell = require('libs.tell');
local theme = require('libs.theme');
local widgets = require('libs.widgets');
local commandsData = require('data.commands');

local M = {};

M.GROUPS = {
    { id = 'Player', label = 'Player' },
    { id = 'Combat', label = 'Combat' },
    { id = 'Items', label = 'Items' },
    { id = 'Progression', label = 'Progress' },
    { id = 'World', label = 'World' },
    { id = 'Entities', label = 'Entity' },
    { id = 'Other', label = 'Other' },
};

function M.fill_target_keys(fields)
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

function M.draw_field(command, field, bag, rowId, maxWidth)
    if (imgui.BeginGroup ~= nil) then
        imgui.BeginGroup();
    end
    if (field.kind == 'lookup') then
        widgets.lookup(rowId .. field.key, field, bag, kit.labels, maxWidth);
    else
        local width = math.min(widgets.input_width(field), math.max(1, maxWidth or widgets.input_width(field)));
        widgets.placeholder(rowId .. field.key, bag[field.key], field.placeholder, width);
        if (tell.is_player_field(field)) then
            tell.apply_buffer(bag[field.key]);
        end
    end
    if (imgui.EndGroup ~= nil) then
        imgui.EndGroup();
    end
    kit.field_hover_tip(command, field);
end

function M.rect_visible(width, height)
    if (imgui.IsRectVisible == nil) then
        return true;
    end
    local ok, visible = pcall(imgui.IsRectVisible, {
        math.max(1, width or 1),
        math.max(1, height or 1),
    });
    return not ok or visible ~= false;
end

function M.pack_field_rows(fields, fieldLeft, fieldRight, hiddenKeys)
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
            x = x + width + kit.px(kit.GAP);
        end
    end
    if (#line > 0) then
        rows[#rows + 1] = line;
    end
    return rows;
end

function M.draw_field_rows(rows, startY, lineH, controlH, command, bag, rowId)
    for index, fieldRow in ipairs(rows) do
        local fieldY = startY + (index - 1) * lineH + math.max(0, (lineH - controlH) * 0.5);
        for _, item in ipairs(fieldRow) do
            imgui.SetCursorPos({ item.x, fieldY });
            M.draw_field(command, item.field, bag, rowId, item.width);
        end
    end
end

function M.widest_field(fields, hiddenKeys)
    local widest = 0;
    for _, field in ipairs(fields or {}) do
        if (hiddenKeys == nil or not hiddenKeys[field.key]) then
            widest = math.max(widest, widgets.field_width(field));
        end
    end
    return widest;
end

function M.draw_command(command, bag, mode, onFavorite, onRemove, onExecute, errorText, nameCol, showSeparator, uniqueKey, favorited, lineNum, lineNumW, dragKind, dragList, dragState, dragListKey, dragLabel)
    if (showSeparator == nil) then
        showSeparator = true;
    end
    local isGhost = (mode == 'ghost');
    local rowId = mode .. tostring(uniqueKey or command.id);
    local originX = imgui.GetCursorPosX();
    local startY = imgui.GetCursorPosY();
    local totalW = kit.remaining_width();
    if (totalW < 1) then
        totalW = 1;
    end
    local numW = 0;
    if (lineNum ~= nil and lineNumW ~= nil and lineNumW > 0) then
        numW = lineNumW;
    end
    local grabW = 0;
    if ((dragKind ~= nil or isGhost) and numW > 0) then
        grabW = kit.row_grab_width();
    end
    local leftW = grabW + numW;
    local startX = originX + leftW;
    local contentW = math.max(1, totalW - leftW);
    local favW = widgets.icon_button_size();
    local pair = kit.px(kit.EXEC_W) + kit.px(kit.GAP) + favW;
    local textH, controlH, lineH = kit.row_metrics();

    local required = {};
    local optional = {};
    for _, field in ipairs(command.fields or {}) do
        if (field.optional) then
            optional[#optional + 1] = field;
        else
            required[#required + 1] = field;
        end
    end

    local hiddenKeys = M.fill_target_keys(command.fields);
    local wideFieldLeft = startX + (nameCol or 0);
    local wideFieldRight = startX + contentW - pair - kit.px(kit.GAP);
    local wideFieldW = math.max(0, wideFieldRight - wideFieldLeft);
    local largestField = math.max(M.widest_field(required, hiddenKeys), M.widest_field(optional, hiddenKeys));
    local compact = largestField > wideFieldW or wideFieldW < kit.px(120);
    local fieldLeft = compact and startX or wideFieldLeft;
    local fieldRight = compact and (startX + contentW) or wideFieldRight;
    local fieldsStartY = startY;
    local headerH = 0;
    local actionsRow = 0;
    if (compact) then
        if (kit.text_px('!' .. command.id) + kit.px(kit.GAP) + pair > contentW) then
            actionsRow = 1;
        end
        headerH = lineH * (actionsRow + 1) + kit.px(4);
        fieldsStartY = startY + headerH;
    end

    local requiredRows = M.pack_field_rows(required, fieldLeft, fieldRight, hiddenKeys);
    local optionalRows = {};
    local optionalFieldLeft = fieldLeft;
    if (#optional > 0) then
        if (compact) then
            optionalFieldLeft = startX + kit.text_px('Optional') + kit.px(12);
        end
        optionalRows = M.pack_field_rows(optional, optionalFieldLeft, fieldRight, hiddenKeys);
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
    if (not isGhost and not M.rect_visible(totalW, visibleH)) then
        imgui.SetCursorPos({ originX, startY + blockH });
        kit.submit_space(0);
        if (errorText ~= nil and errorText ~= '') then
            imgui.Text(errorText);
        end
        if (showSeparator) then
            imgui.Separator();
        end
        return;
    end

    if (leftW > 0 and dragKind ~= nil and dragList ~= nil and lineNum ~= nil) then
        imgui.SetCursorPos({ originX, startY });
        local rowSX, rowSY = kit.cursor_screen_pos();
        kit.draw_row_drag_handle(
            'listdrag' .. rowId,
            originX,
            startY,
            leftW,
            math.max(lineH, blockH),
            dragKind,
            lineNum,
            dragList,
            dragState,
            dragListKey,
            dragLabel or ('!' .. tostring(command.id)),
            grabW,
            nameY + textH * 0.5,
            {
                kind = 'command',
                lineNum = lineNum,
                cmdText = '!' .. tostring(command.id),
                numW = numW,
                rowH = math.max(lineH, blockH),
                rowW = totalW,
                rowSX = rowSX,
                rowSY = rowSY,
                command = command,
                bag = bag,
                nameCol = nameCol,
            }
        );
    elseif (isGhost and grabW > 0) then
        imgui.SetCursorPos({ originX, nameY + textH * 0.5 });
        local _, cy = kit.cursor_screen_pos();
        imgui.SetCursorPos({ originX, startY });
        local sx = kit.cursor_screen_pos();
        if (sx ~= nil and cy ~= nil) then
            kit.draw_grab_bars(sx, cy, sx + grabW);
        end
    end

    if (numW > 0) then
        kit.draw_line_num(lineNum, numW, originX + grabW, nameY, textH);
    end

    imgui.SetCursorPos({ startX, nameY });
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.royal);
    imgui.Text('!');
    imgui.PopStyleColor();
    imgui.SameLine(0, 0);
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text);
    imgui.Text(command.id);
    imgui.PopStyleColor();
    if (not isGhost) then
        kit.hover_tip(command.desc, kit.command_example(command));
    end

    imgui.SetCursorPos({ startX + contentW - pair, buttonY });
    if (widgets.execute(rowId) and onExecute ~= nil and not isGhost) then
        onExecute();
    end
    imgui.SetCursorPos({ startX + contentW - favW, buttonY });
    if (mode == 'favorite' or isGhost) then
        if (widgets.remove(rowId) and onRemove ~= nil and not isGhost) then
            onRemove();
        end
    else
        if (widgets.favorite(rowId, favorited == true) and onFavorite ~= nil) then
            onFavorite();
        end
    end

    M.draw_field_rows(requiredRows, fieldsStartY, lineH, controlH, command, bag, rowId);

    if (#optionalRows > 0) then
        local optStartY = fieldsStartY + requiredH;
        local optLabelY = optStartY + math.max(0, (lineH - textH) * 0.5);
        imgui.SetCursorPos({ startX, optLabelY });
        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.muted);
        imgui.Text('Optional');
        imgui.PopStyleColor();
        M.draw_field_rows(optionalRows, optStartY, lineH, controlH, command, bag, rowId);
    end

    imgui.SetCursorPos({ originX, startY + blockH });
    kit.submit_space(0);

    if (not isGhost and errorText ~= nil and errorText ~= '') then
        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.remove);
        imgui.Text(errorText);
        imgui.PopStyleColor();
    end

    if (not isGhost and showSeparator) then
        imgui.PushStyleColor(ImGuiCol_Separator, theme.colors.borderSoft);
        imgui.Separator();
        imgui.PopStyleColor();
    end
end

function M.ensure_group_order(cfg)
    if (type(cfg.groupOrder) ~= 'table') then
        cfg.groupOrder = {};
    end
    local seen = {};
    local order = {};
    for _, id in ipairs(cfg.groupOrder) do
        for _, group in ipairs(M.GROUPS) do
            if (group.id == id and not seen[id]) then
                order[#order + 1] = id;
                seen[id] = true;
            end
        end
    end
    for _, group in ipairs(M.GROUPS) do
        if (not seen[group.id]) then
            order[#order + 1] = group.id;
        end
    end
    cfg.groupOrder = order;
end

function M.ordered_groups(cfg)
    M.ensure_group_order(cfg);
    local byId = {};
    for _, group in ipairs(M.GROUPS) do
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

function M.draw_page_search(state)
    kit.draw_search_bar('cmdsearch', state.search);
end

function M.draw_category_page(state, cfg, save, category, query)
    local pageCommands = {};
    for _, command in ipairs(commandsData) do
        if (command.category == category and command.minTier <= (cfg.tier or 5)) then
            pageCommands[#pageCommands + 1] = command;
        end
    end
    local matched = {};
    for _, command in ipairs(pageCommands) do
        if (kit.matches_query(command, query)) then
            matched[#matched + 1] = command;
        end
    end
    local nameCol = kit.name_column(matched);
    local listSpace = kit.begin_command_list_spacing();
    for index, command in ipairs(matched) do
        local bag = kit.bag_for(state.values, command);
        local favs = require('libs.ui.favorites');
        M.draw_command(command, bag, 'cmd', function()
            favs.ensure_favorite_tabs(cfg);
            local tab = favs.favorite_tab(cfg, state.favTab);
            state.favPick = {
                commandId = command.id,
                tabId = tab.id,
                values = kit.snapshot_bag(bag, command),
            };
            state.favPickRequest = true;
        end, nil, function()
            kit.run_command(cfg, command, bag, save, state.errors, command.id, state);
        end, state.errors[command.id], nameCol, index < #matched, command.id, favs.command_is_favorited(cfg, command.id));
    end
    kit.end_command_list_spacing(listSpace);
    if (#matched == 0) then
        if (query ~= '') then
            widgets.empty_state('No commands match.');
        else
            widgets.empty_state('No commands are assigned to this tier yet.');
        end
    end
end

function M.draw_group_tabs(state, cfg)
    M.ensure_group_order(cfg);
    local startX = imgui.GetCursorPosX();
    local startY = imgui.GetCursorPosY();
    local indent = kit.px(kit.ROUND);
    local groups = M.ordered_groups(cfg);
    local usable = math.max(1, kit.remaining_width() - indent * 2);
    local ideal = math.max(kit.px(56), kit.letter_tab_width());
    local perRow = math.max(1, math.min(#groups, math.floor(usable / ideal)));
    local width = math.floor(usable / perRow);
    local rowH = kit.px(30);
    for index, group in ipairs(groups) do
        local column = (index - 1) % perRow;
        local row = math.floor((index - 1) / perRow);
        if (column == 0 and imgui.SetCursorPos ~= nil) then
            imgui.SetCursorPos({ startX + indent, startY + row * rowH });
        elseif (index > 1) then
            imgui.SameLine(0, 0);
        end
        local clicked = kit.nav_button(group.label, 'nav' .. group.id, state.page == group.id, width);
        kit.note_tab_drag('group', index);
        kit.accept_tab_drop('group', index, cfg.groupOrder);
        if (clicked and not kit.tabDrag.moved) then
            state.page = group.id;
            state.section = 'commands';
        end
    end
    if (imgui.SetCursorPos ~= nil) then
        local rows = math.max(1, math.ceil(#groups / perRow));
        imgui.SetCursorPos({ startX, startY + rows * rowH - kit.px(kit.GAP) });
        kit.submit_space(0);
    end
end

return M;
