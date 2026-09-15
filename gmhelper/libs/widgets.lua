--[[
* Placeholder inputs, command-row buttons, and searchable database dropdowns.
]]

require('common');

local imgui = require('imgui');
local theme = require('libs.theme');
local lookup = require('libs.lookup');

local widgets = {};

local searches = {};
local childCall = nil;
local scale = 1;
local fontScaled = false;
local sharedInput = nil;
local sharedCombo = nil;
local arrowCapture = false;
local arrowCaptureRequest = false;
local comboOpenPrev = false;
local comboOpenNow = false;
local scrollEpoch = 0;
local scrollApplied = {};
-- Screen rects for centered closed-combo labels (keyed by combo id).
local centeredPreviewRect = {};

local MIN_INPUT = 45;
local POPUP_PAD = 8;
-- Matches left inset, optional gap-before-scrollbar, and scrollbar width.
local COMBO_SCROLL = 16;
local COMBO_LIST_H = 180;
local COMBO_ROW_H = 18;
local COMBO_ARROW = 20;
-- Left/right inset inside the closed field and popup list (+10 total width).
local COMBO_SIDE_PAD = 5;
-- Extra room between preview text and the combo arrow (settings closed field).
local COMBO_PREVIEW_GAP = 10;
-- Max width for command/lookup dropdowns (content). Settings combos ignore this.
local COMBO_MAX_W = 350;
local CATALOG_COPY_CHUNK = 1200;
local CATALOG_SORT_ZONES = 2;

local JOB_NAMES = {
    WAR = 'Warrior',
    MNK = 'Monk',
    WHM = 'White Mage',
    BLM = 'Black Mage',
    RDM = 'Red Mage',
    THF = 'Thief',
    PLD = 'Paladin',
    DRK = 'Dark Knight',
    BST = 'Beastmaster',
    BRD = 'Bard',
    RNG = 'Ranger',
    SAM = 'Samurai',
    NIN = 'Ninja',
    DRG = 'Dragoon',
    SMN = 'Summoner',
    BLU = 'Blue Mage',
    COR = 'Corsair',
    PUP = 'Puppetmaster',
    DNC = 'Dancer',
    SCH = 'Scholar',
    GEO = 'Geomancer',
    RUN = 'Rune Fencer',
    MON = 'Monster',
};

function widgets.begin_frame()
    arrowCaptureRequest = false;
    comboOpenPrev = comboOpenNow;
    comboOpenNow = false;
    lookup.begin_frame();
end

function widgets.end_frame()
    arrowCapture = arrowCaptureRequest;
end

function widgets.arrows_captured()
    return arrowCapture;
end

function widgets.combo_open()
    return comboOpenPrev == true or comboOpenNow == true;
end

function widgets.reset_scrolls()
    scrollEpoch = scrollEpoch + 1;
    scrollApplied = {};
    for _, state in pairs(searches) do
        if (type(state) == 'table') then
            state.scrollY = 0;
            state.needScrollRestore = false;
        end
    end
end

function widgets.apply_load_scroll(id)
    if (id == nil or scrollApplied[id] == scrollEpoch) then
        return false;
    end
    scrollApplied[id] = scrollEpoch;
    if (imgui.SetScrollY ~= nil) then
        pcall(imgui.SetScrollY, 0);
    end
    return true;
end

local function note_combo_open()
    comboOpenNow = true;
end

function widgets.configure(nextScale, usedFontScale)
    scale = nextScale or 1;
    if (scale < 0.1) then
        scale = 0.1;
    elseif (scale > 3) then
        scale = 3;
    end
    fontScaled = usedFontScale == true;
end

function widgets.px(value)
    return math.floor(value * scale + 0.5);
end

function widgets.apply_font()
    if (fontScaled or imgui.SetWindowFontScale == nil) then
        return;
    end
    pcall(imgui.SetWindowFontScale, scale);
end

local function child_flags(border, usePadding)
    local flags = 0;
    if (border) then
        flags = ImGuiChildFlags_Borders or 1;
    end
    if (usePadding ~= false) then
        flags = bit.bor(flags, ImGuiChildFlags_AlwaysUseWindowPadding or 2);
    end
    return flags;
end

--[[
* Ashita's imgui binds BeginChild(id, size, ImGuiChildFlags), not the old bool border.
* Probe once so a different overload still opens a child instead of crashing the frame.
]]
function widgets.begin_child(id, size, border, windowFlags, usePadding)
    local x = size[1] or 0;
    local y = size[2] or 0;
    local flags = child_flags(border, usePadding);
    windowFlags = windowFlags or 0;
    if (windowFlags ~= 0) then
        local ok, result = pcall(imgui.BeginChild, id, size, flags, windowFlags);
        if (ok) then
            childCall = 'flags';
            return result;
        end
    end
    local attempts = childCall and { childCall } or { 'flags', 'xy', 'size', 'xyonly' };
    local lastError = nil;
    for _, mode in ipairs(attempts) do
        local ok, result;
        if (mode == 'flags') then
            ok, result = pcall(imgui.BeginChild, id, size, flags);
        elseif (mode == 'xy') then
            ok, result = pcall(imgui.BeginChild, id, x, y, flags);
        elseif (mode == 'size') then
            ok, result = pcall(imgui.BeginChild, id, size);
        else
            ok, result = pcall(imgui.BeginChild, id, x, y);
        end
        if (ok) then
            childCall = mode;
            return result;
        end
        lastError = result;
    end
    error(tostring(lastError));
end

local function trim(value)
    if (value == nil) then
        return '';
    end
    return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''));
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

local function item_bounds(fallbackW, fallbackH)
    local x1, y1 = 0, 0;
    local x2, y2 = fallbackW or 0, fallbackH or 22;
    if (imgui.GetItemRectMin ~= nil) then
        local a, b = imgui.GetItemRectMin();
        x1, y1 = vec2(a, b);
    end
    if (imgui.GetItemRectMax ~= nil) then
        local a, b = imgui.GetItemRectMax();
        local mx, my = vec2(a, b);
        if (mx > x1 and my > y1) then
            x2, y2 = mx, my;
        else
            x2, y2 = x1 + (fallbackW or 0), y1 + (fallbackH or 22);
        end
    else
        x2, y2 = x1 + (fallbackW or 0), y1 + (fallbackH or 22);
    end
    return x1, y1, x2, y2;
end

local function text_size(text)
    if (imgui.CalcTextSize ~= nil) then
        local a, b = imgui.CalcTextSize(text);
        local w, h = vec2(a, b);
        if (w > 0) then
            return w, h > 0 and h or 13;
        end
    end
    return #tostring(text or '') * 7, 13;
end

function widgets.placeholder(id, buffer, hint, width, align)
    if (buffer[1] == nil) then
        buffer[1] = '';
    end
    imgui.SetNextItemWidth(width);
    local result = imgui.InputText('##' .. id, buffer, 256);
    if (type(result) == 'string') then
        buffer[1] = result;
    end

    if (trim(buffer[1]) == '' and not imgui.IsItemActive()) then
        local x1, y1, x2, y2 = item_bounds(width, 22);
        local tw, th = text_size(hint or '');
        local draw = imgui.GetWindowDrawList();
        local x = x1 + math.max(4, ((x2 - x1) - tw) * 0.5);
        if (align == 'left') then
            x = x1 + widgets.px(10);
        end
        if (draw ~= nil and draw.AddText ~= nil) then
            draw:AddText({
                x,
                y1 + math.max(2, ((y2 - y1) - th) * 0.5),
            }, theme.col32(theme.colors.muted), hint or '');
        end
    end
end

function widgets.icon_button_size()
    local textH = 13;
    if (imgui.CalcTextSize ~= nil) then
        local size, second = imgui.CalcTextSize('Ag');
        local _, height = vec2(size, second);
        if (height > 0) then
            textH = height;
        end
    end
    if (not fontScaled) then
        textH = textH * scale;
    end
    return math.max(widgets.px(22), math.floor(textH + widgets.px(6) * 2));
end

local function royal_button(id)
    local size = widgets.icon_button_size();
    imgui.PushStyleColor(ImGuiCol_Button, theme.colors.royal);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.colors.royalHover);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.colors.royalActive);
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text);
    imgui.PushStyleColor(ImGuiCol_Border, theme.colors.royal);
    local clicked = imgui.Button('##' .. id, { size, size });
    imgui.PopStyleColor(5);
    return clicked;
end

local function paint_star(filled)
    local draw = imgui.GetWindowDrawList();
    if (draw == nil) then
        return;
    end
    local x1, y1, x2, y2 = item_bounds(22, 22);
    local cx = (x1 + x2) * 0.5;
    local cy = (y1 + y2) * 0.5;
    local radius = math.min(x2 - x1, y2 - y1) * 0.32;
    local inner = radius * 0.58;
    local col = theme.col32(theme.colors.text);
    local points = {};
    for index = 0, 9 do
        local angle = -math.pi / 2 + index * math.pi / 5;
        local reach = (index % 2 == 0) and radius or inner;
        points[#points + 1] = { cx + math.cos(angle) * reach, cy + math.sin(angle) * reach };
    end
    if (filled ~= false and draw.AddTriangleFilled ~= nil) then
        pcall(function()
            for index = 1, 10 do
                local nextIndex = index % 10 + 1;
                draw:AddTriangleFilled({ cx, cy }, points[index], points[nextIndex], col);
            end
        end);
        return;
    end
    if (draw.AddLine ~= nil) then
        local thick = 1;
        pcall(function()
            for index = 1, 10 do
                local nextIndex = index % 10 + 1;
                draw:AddLine(points[index], points[nextIndex], col, thick);
            end
        end);
    end
end

local function paint_trash()
    local draw = imgui.GetWindowDrawList();
    if (draw == nil or draw.AddRectFilled == nil) then
        return;
    end
    local x1, y1, x2, y2 = item_bounds(22, 22);
    local cx = (x1 + x2) * 0.5;
    local cy = (y1 + y2) * 0.5;
    local size = math.min(x2 - x1, y2 - y1) * 0.46;
    local top = cy - size * 0.46;
    local col = theme.col32(theme.colors.text);
    local slot = theme.colors.royal;
    if (imgui.IsItemActive ~= nil and imgui.IsItemActive()) then
        slot = theme.colors.royalActive;
    elseif (imgui.IsItemHovered ~= nil and imgui.IsItemHovered()) then
        slot = theme.colors.royalHover;
    end
    local slotCol = theme.col32(slot);
    local function fill(minX, minY, maxX, maxY, color)
        draw:AddRectFilled({ minX, minY }, { maxX, maxY }, color);
    end
    pcall(function()
        fill(cx - size * 0.12, top, cx + size * 0.12, top + size * 0.1, col);
        fill(cx - size * 0.4, top + size * 0.12, cx + size * 0.4, top + size * 0.24, col);
        fill(cx - size * 0.3, top + size * 0.3, cx + size * 0.3, top + size * 0.92, col);
        local bodyTop = top + size * 0.4;
        local bodyBottom = top + size * 0.82;
        fill(cx - size * 0.14, bodyTop, cx - size * 0.06, bodyBottom, slotCol);
        fill(cx - size * 0.04, bodyTop, cx + size * 0.04, bodyBottom, slotCol);
        fill(cx + size * 0.06, bodyTop, cx + size * 0.14, bodyBottom, slotCol);
    end);
end

function widgets.favorite(id, selected)
    local clicked = royal_button('fav' .. id);
    paint_star(selected == true);
    return clicked;
end

function widgets.remove(id)
    local clicked = royal_button('remove' .. id);
    paint_trash();
    return clicked;
end

function widgets.execute(id)
    imgui.PushStyleColor(ImGuiCol_Button, theme.colors.royal);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.colors.royalHover);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.colors.royalActive);
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text);
    imgui.PushStyleColor(ImGuiCol_Border, theme.colors.royal);
    local clicked = imgui.Button('Execute##' .. id, { widgets.px(88), 0 });
    imgui.PopStyleColor(5);
    return clicked;
end

local FIELD_GAP = 8;

local function fit_text(text)
    local width = select(1, text_size(text or ''));
    if (not fontScaled) then
        width = width * scale;
    end
    return width;
end

local function combo_line_height()
    local _, th = text_size('Ag');
    return math.max(widgets.px(COMBO_ROW_H), math.ceil((th > 0 and th or 13) + widgets.px(2)));
end

local function paint_combo_text(x1, y1, x2, y2, wraps, color, textX, centerX, drawList)
    local draw = drawList or (imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil);
    if (draw == nil or draw.AddText == nil or wraps == nil or #wraps == 0) then
        return;
    end
    local _, fontH = text_size('Ag');
    local lineH = math.max(1, fontH > 0 and fontH or 13);
    local blockH = #wraps * lineH;
    local baseY = y1 + math.max(0, ((y2 - y1) - blockH) * 0.5);
    for index, part in ipairs(wraps) do
        local tw, th = text_size(part);
        local x = textX or x1;
        if (centerX) then
            x = x1 + math.max(0, ((x2 - x1) - tw) * 0.5);
        end
        pcall(draw.AddText, draw, {
            x,
            baseY + (index - 1) * lineH + math.max(0, (lineH - th) * 0.5),
        }, color, part);
    end
end

local function push_combo_list_spacing()
    local pushed = 0;
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_ItemSpacing ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 0, 0 });
        pushed = pushed + 1;
    end
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_FramePadding ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 0 });
        pushed = pushed + 1;
    end
    return pushed;
end

local function combo_max_width()
    return widgets.px(COMBO_MAX_W);
end

local function clamp_combo_width(width)
    local maxW = combo_max_width();
    if (width > maxW) then
        return maxW;
    end
    return width;
end

-- Wrap on whole words only. A single oversized word stays on its own line.
local function wrap_words(text, maxW)
    text = tostring(text or '');
    if (text == '') then
        return { ' ' };
    end
    maxW = math.max(1, maxW or combo_max_width());
    local lines = {};
    local current = '';
    for word in text:gmatch('%S+') do
        local trial = current == '' and word or (current .. ' ' .. word);
        if (fit_text(trial) <= maxW) then
            current = trial;
        elseif (current ~= '') then
            lines[#lines + 1] = current;
            current = word;
        else
            lines[#lines + 1] = word;
            current = '';
        end
    end
    if (current ~= '') then
        lines[#lines + 1] = current;
    end
    if (#lines == 0) then
        lines[1] = ' ';
    end
    return lines;
end

local function cats_of(field)
    local cats = { field.lookup };
    if (field.also ~= nil) then
        cats[#cats + 1] = field.also;
    end
    return cats;
end

local function field_words(field)
    local blob = tostring(field.key or '') .. ' ' .. tostring(field.label or '') .. ' ' .. tostring(field.placeholder or '');
    return blob:lower();
end

local function is_level_field(field)
    return field_words(field):find('level', 1, true) ~= nil;
end

local function min_input_width()
    return widgets.px(MIN_INPUT);
end

local ROMAN_NUMERALS = {
    i = 'I', ii = 'II', iii = 'III', iv = 'IV', v = 'V', vi = 'VI',
    vii = 'VII', viii = 'VIII', ix = 'IX', x = 'X', xi = 'XI', xii = 'XII',
};

local function title_case(text)
    return (tostring(text or ''):gsub("(%a)([%w']*)", function(first, rest)
        local lower = (first .. rest):lower();
        local roman = ROMAN_NUMERALS[lower];
        if (roman ~= nil) then
            return roman;
        end
        return first:upper() .. rest:lower();
    end));
end

local function cats_use_id_prefix(cats)
    for _, cat in ipairs(cats) do
        if (cat == 'mobs' or cat == 'npcs') then
            return true;
        end
    end
    return false;
end

local function cats_use_zone_groups(cats)
    return cats_use_id_prefix(cats);
end

local function display_name_for_measure(cat, name)
    if (cat == 'jobs') then
        local full = JOB_NAMES[(name or ''):upper()];
        if (full ~= nil) then
            return full;
        end
    end
    local label = title_case(name);
    if (label == '') then
        return ' ';
    end
    if (cat == 'mobs' or cat == 'npcs') then
        return '[' .. lookup.longestId(cat) .. '] ' .. label;
    end
    return label;
end

local function measure_zone_width(cat, widest)
    for _, zoneName in ipairs(lookup.zones(cat)) do
        local width = fit_text(title_case(zoneName));
        if (width > widest) then
            widest = width;
        end
    end
    return widest;
end

local function lookup_row_count(field)
    local total = 0;
    for _, cat in ipairs(cats_of(field)) do
        local meta = lookup.meta(cat);
        if (meta ~= nil and type(meta.total) == 'number') then
            total = total + meta.total;
        end
    end
    return total;
end

local function combo_arrow_width()
    if (imgui.GetFrameHeight ~= nil) then
        local ok, h = pcall(imgui.GetFrameHeight);
        if (ok and type(h) == 'number' and h > 0) then
            return math.ceil(h);
        end
    end
    return widgets.px(COMBO_ARROW);
end

local function combo_side_pad()
    return widgets.px(COMBO_SIDE_PAD);
end

local function combo_chrome(needsScroll)
    -- 5px left + 5px right; optional scrollbar room.
    local chrome = combo_side_pad() * 2;
    if (needsScroll) then
        chrome = chrome + widgets.px(10);
    end
    return chrome;
end

local function measure_combo(field)
    local sample = field.placeholder or '';
    local widest = fit_text(sample);
    for _, cat in ipairs(cats_of(field)) do
        if (cat == 'jobs') then
            for _, full in pairs(JOB_NAMES) do
                local width = fit_text(full);
                if (width > widest) then
                    widest = width;
                end
            end
        else
            local label = display_name_for_measure(cat, lookup.longestName(cat));
            local width = fit_text(label);
            if (cat == 'mobs' or cat == 'npcs') then
                widest = measure_zone_width(cat, widest);
            end
            if (width > widest) then
                widest = width;
            end
        end
    end
    local needsScroll = lookup_row_count(field) * combo_line_height() > widgets.px(COMBO_LIST_H);
    return clamp_combo_width(math.max(math.ceil(widest + combo_chrome(needsScroll)), min_input_width()));
end

--- Settings combo list width: fit every label on one line (no max clamp, no wrap).
function widgets.labels_combo_width(labels)
    local widest = 0;
    local count = 0;
    for _, label in ipairs(labels or {}) do
        count = count + 1;
        local width = fit_text(tostring(label));
        if (width > widest) then
            widest = width;
        end
    end
    local needsScroll = count * combo_line_height() > widgets.px(COMBO_LIST_H);
    local chrome = combo_chrome(needsScroll);
    -- Keep short options (e.g. "/") compact — do not force the text-input minimum.
    return math.max(math.ceil(widest + chrome), math.ceil(fit_text('W') + chrome));
end

--- Closed settings field: list width plus arrow and a gap so text does not crowd the arrow.
function widgets.labels_combo_display_width(labels)
    return widgets.labels_combo_width(labels) + combo_arrow_width() + widgets.px(COMBO_PREVIEW_GAP);
end

--- Begin a settings-style combo: field fits full selected text + arrow; list fits labels; no wrap.
--- Optional fixedW (logical px) forces closed field + popup list to that width (e.g. welcome / fav modal).
--- Optional centerPreview centers the closed-field label (list options are unchanged).
function widgets.begin_labels_combo(id, preview, labels, flags, fixedW, centerPreview)
    local listW = widgets.labels_combo_width(labels);
    local displayW = widgets.labels_combo_display_width(labels);
    if (type(fixedW) == 'number' and fixedW > 0) then
        displayW = widgets.px(fixedW);
        listW = math.max(1, displayW - combo_arrow_width());
    end
    imgui.SetNextItemWidth(displayW);
    -- BeginCombo switches to the popup window when open; keep the parent draw list
    -- so centered preview never paints into the dropdown list.
    local parentDraw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    -- Hide ImGui's left-aligned preview; we paint a centered label ourselves.
    local nativePreview = preview;
    if (centerPreview == true) then
        nativePreview = '';
    end
    local opened = false;
    if (flags ~= nil and flags ~= 0) then
        local ok, result = pcall(imgui.BeginCombo, id, nativePreview, flags);
        if (ok) then
            opened = result == true or (result ~= nil and result ~= false);
        else
            opened = imgui.BeginCombo(id, nativePreview) == true;
        end
    else
        opened = imgui.BeginCombo(id, nativePreview) == true;
    end
    if (centerPreview == true and parentDraw ~= nil) then
        local x1, y1, x2, y2 = item_bounds(displayW, 22);
        local cached = centeredPreviewRect[id];
        if (opened) then
            -- While open, GetItemRect belongs to the popup — reuse last closed-field rect.
            if (cached ~= nil) then
                x1, y1, x2, y2 = cached[1], cached[2], cached[3], cached[4];
            end
        else
            centeredPreviewRect[id] = { x1, y1, x2, y2 };
        end
        local textRight = x2 - combo_arrow_width();
        local bg = theme.colors.field;
        if (not opened) then
            if (imgui.IsItemActive ~= nil and imgui.IsItemActive()) then
                bg = theme.colors.fieldActive;
            elseif (imgui.IsItemHovered ~= nil and imgui.IsItemHovered()) then
                bg = theme.colors.fieldHover;
            end
        end
        if (parentDraw.AddRectFilled ~= nil) then
            pcall(parentDraw.AddRectFilled, parentDraw, { x1 + 1, y1 + 1 }, { textRight - 1, y2 - 1 }, theme.col32(bg));
        end
        local label = tostring(preview or '');
        if (label == '') then
            label = ' ';
        end
        paint_combo_text(x1, y1, textRight, y2, { label }, theme.col32(theme.colors.text), nil, true, parentDraw);
    end
    if (opened) then
        note_combo_open();
        -- Popup matches the closed preview width; options fill that width (text stays centered).
        if (imgui.SetWindowSize ~= nil) then
            local height = widgets.px(COMBO_LIST_H) + widgets.px(24);
            if (imgui.GetWindowHeight ~= nil) then
                local current = imgui.GetWindowHeight();
                if (type(current) == 'number' and current > height) then
                    height = current;
                end
            end
            pcall(imgui.SetWindowSize, { displayW, height });
        end
        if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_SelectableTextAlign ~= nil) then
            imgui.PushStyleVar(ImGuiStyleVar_SelectableTextAlign, { 0.5, 0.5 });
            return true, true, displayW;
        end
        return true, false, displayW;
    end
    return false, false, displayW;
end

function widgets.end_labels_combo(opened, alignPushed)
    if (alignPushed and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar();
    end
    if (opened) then
        imgui.EndCombo();
    end
end

--- Settings combo option: full-width hit/highlight; label text centered.
function widgets.labels_combo_option(id, label, selected, listW)
    listW = listW or widgets.px(120);
    local rowH = combo_line_height();
    local text = tostring(label or '');
    if (text == '') then
        text = ' ';
    end
    local wraps = { text };
    local height = rowH;
    local rowW = listW;
    if (imgui.GetContentRegionAvail ~= nil) then
        local a, b = imgui.GetContentRegionAvail();
        local w = a;
        if (type(a) == 'table' or type(a) == 'userdata') then
            w = a.x or a[1] or 0;
        elseif (type(a) ~= 'number' and type(b) == 'number') then
            w = b;
        end
        if (type(w) == 'number' and w > 1) then
            rowW = w;
        end
    end
    local spacingPushed = push_combo_list_spacing();
    imgui.PushStyleColor(ImGuiCol_Header, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, theme.colors.clear);
    imgui.PushStyleColor(ImGuiCol_HeaderActive, theme.colors.clear);
    local clicked = false;
    local okSelectable, result = pcall(imgui.Selectable, '##' .. tostring(id), selected == true, 0, { rowW, height });
    if (okSelectable) then
        clicked = result == true;
    else
        clicked = imgui.Selectable('##' .. tostring(id), selected == true) == true;
    end
    local hot = selected == true or (imgui.IsItemHovered ~= nil and imgui.IsItemHovered());
    local x1, y1, x2, y2 = item_bounds(rowW, height);
    if (hot) then
        theme.paint_row_highlight(x1, y1, x2, y2, widgets.px(3));
    end
    paint_combo_text(x1, y1, x2, y2, wraps, theme.col32(theme.colors.text), nil, true);
    imgui.PopStyleColor(3);
    if (spacingPushed > 0 and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar(spacingPushed);
    end
    return clicked;
end

local function measure_id(field)
    if (field.lookup == 'jobs') then
        return min_input_width();
    end
    local sample = 'ID';
    local widest = fit_text(sample);
    for _, cat in ipairs(cats_of(field)) do
        local ident = lookup.longestId(cat);
        local width = fit_text(ident);
        if (width > widest) then
            widest = width;
        end
    end
    return math.max(math.ceil(widest + widgets.px(20)), min_input_width());
end

local function measure_input(field)
    if (is_level_field(field)) then
        return min_input_width();
    end
    local chars = field.chars or 9;
    if (chars < 1) then
        chars = 1;
    end
    local sample = string.rep(field.kind == 'number' and '8' or 'M', chars);
    if (fit_text(field.placeholder or '') > fit_text(sample)) then
        sample = field.placeholder;
    end
    return math.max(math.ceil(fit_text(sample) + widgets.px(20)), min_input_width());
end

function widgets.sync_widths(commandList)
    -- Combo widths are measured per lookup from the longest displayed value.
    sharedInput = nil;
    sharedCombo = nil;
end

function widgets.combo_width(field)
    return measure_combo(field);
end

function widgets.combo_display_width(field)
    -- Arrow sits outside the clamped content width so preview text is not clipped.
    return widgets.combo_width(field) + combo_arrow_width();
end

function widgets.id_width(field)
    return measure_id(field);
end

function widgets.input_width(field)
    return measure_input(field);
end

local function measure_fill_slot()
    return math.max(min_input_width(), math.ceil(fit_text('999') + widgets.px(20)));
end

function widgets.fills_width(field)
    if (field.fills == nil) then
        return 0;
    end
    local total = 0;
    for _ in pairs(field.fills) do
        total = total + widgets.px(FIELD_GAP) + measure_fill_slot();
    end
    return total;
end

function widgets.field_width(field)
    if (field.kind ~= 'lookup') then
        return widgets.input_width(field);
    end
    return widgets.combo_display_width(field)
        + widgets.fills_width(field)
        + widgets.px(FIELD_GAP)
        + widgets.id_width(field);
end

local function jobs_only(cats)
    return #cats == 1 and cats[1] == 'jobs';
end

local function item_focused()
    if (imgui.IsItemFocused ~= nil) then
        local ok, focused = pcall(imgui.IsItemFocused);
        if (ok and focused) then
            return true;
        end
    end
    if (imgui.IsItemActive ~= nil) then
        local ok, active = pcall(imgui.IsItemActive);
        return ok and active == true;
    end
    return false;
end

local function arrow_delta()
    if (imgui.IsKeyPressed == nil) then
        return 0;
    end
    local up = ImGuiKey_UpArrow or 515;
    local down = ImGuiKey_DownArrow or 516;
    local function pressed(key)
        local ok, hit = pcall(imgui.IsKeyPressed, key, true);
        if (not ok) then
            ok, hit = pcall(imgui.IsKeyPressed, key);
        end
        return ok and hit == true;
    end
    if (pressed(up)) then
        return -1;
    end
    if (pressed(down)) then
        return 1;
    end
    return 0;
end

local function display_label(name, cats, row)
    local label;
    if (jobs_only(cats)) then
        label = JOB_NAMES[(name or ''):upper()];
        if (label == nil) then
            label = title_case(name);
        end
    else
        label = title_case(name);
    end
    if (label == nil or label == '') then
        label = ' ';
    end
    if (row ~= nil and cats_use_id_prefix(cats)) then
        return '[' .. tostring(row.id) .. '] ' .. label;
    end
    return label;
end

local function sort_name(row, cats)
    if (jobs_only(cats)) then
        local full = JOB_NAMES[(row.name or ''):upper()];
        if (full ~= nil) then
            return full:lower();
        end
    end
    return title_case(row.name or ''):lower();
end

-- A-Z first, then blank/leading-space names, then symbols, then numbers.
local function sort_bucket(name)
    name = tostring(name or '');
    if (name == '' or name:find('^%s') ~= nil) then
        return 1;
    end
    local first = name:sub(1, 1);
    if (first:find('%a') ~= nil) then
        return 0;
    end
    if (first:find('%d') ~= nil) then
        return 3;
    end
    return 2;
end

local function sort_rows(list, cats)
    local zoneGroups = cats_use_zone_groups(cats);
    table.sort(list, function(a, b)
        if (zoneGroups) then
            local az = a.zone or '';
            local bz = b.zone or '';
            if (az ~= bz) then
                local aBucket = sort_bucket(az);
                local bBucket = sort_bucket(bz);
                if (aBucket ~= bBucket) then
                    return aBucket < bBucket;
                end
                local an = title_case(az):lower();
                local bn = title_case(bz):lower();
                if (an ~= bn) then
                    return an < bn;
                end
            end
        end
        local aRaw = a.name or '';
        local bRaw = b.name or '';
        if (jobs_only(cats)) then
            aRaw = JOB_NAMES[(a.name or ''):upper()] or aRaw;
            bRaw = JOB_NAMES[(b.name or ''):upper()] or bRaw;
        end
        local aBucket = sort_bucket(aRaw);
        local bBucket = sort_bucket(bRaw);
        if (aBucket ~= bBucket) then
            return aBucket < bBucket;
        end
        local an = sort_name(a, cats);
        local bn = sort_name(b, cats);
        if (an == bn) then
            return (tonumber(a.id) or 0) < (tonumber(b.id) or 0);
        end
        return an < bn;
    end);
end

local function ensure_line_wrap(line, textMax, rowH)
    if (line.wraps ~= nil and line.wrapW == textMax) then
        return line.wraps, line.height or rowH;
    end
    line.wraps = wrap_words(line.text, math.max(1, textMax));
    line.wrapW = textMax;
    line.height = #line.wraps * rowH;
    return line.wraps, line.height;
end

local function build_zone_index(list)
    local zones = {};
    local index = 1;
    local total = #list;
    while (index <= total) do
        local zone = list[index].zone or '';
        local first = index;
        index = index + 1;
        while (index <= total and (list[index].zone or '') == zone) do
            index = index + 1;
        end
        local label = title_case(zone);
        if (label == '' or label == ' ') then
            label = 'Unknown';
        end
        zones[#zones + 1] = {
            label = label,
            first = first,
            last = index - 1,
            count = index - first,
        };
    end
    return zones;
end

local function zone_span(zone, isLast)
    -- header + separator + entries (+ blank line before the next zone)
    return 2 + zone.count + (isLast and 0 or 1);
end

local function display_count(zones, matchCount)
    if (zones == nil) then
        return matchCount;
    end
    local total = 0;
    for index = 1, #zones do
        total = total + zone_span(zones[index], index == #zones);
    end
    return total;
end

local function search_cache(popupId)
    local state = searches[popupId];
    if (state == nil) then
        state = {
            query = nil,
            matches = {},
            matchZones = nil,
            popupOpen = false,
            scrollY = 0,
            needScrollRestore = false,
        };
        searches[popupId] = state;
    end
    if (state.scrollY == nil) then
        state.scrollY = 0;
    end
    return state;
end

local function selection_token(currentId, values, field)
    local token = tostring(currentId or '');
    if (field ~= nil and field.fills ~= nil and values ~= nil) then
        for key, _ in pairs(field.fills) do
            if (values[key] ~= nil) then
                token = token .. '|' .. tostring(key) .. '=' .. trim(values[key][1]);
            end
        end
    end
    return token;
end

local function row_matches_selection(row, currentId, values, field)
    if (row == nil or currentId == nil or currentId == '') then
        return false;
    end
    if (tostring(row.id) ~= tostring(currentId)) then
        return false;
    end
    if (field ~= nil and field.fills ~= nil and values ~= nil) then
        for key, prop in pairs(field.fills) do
            if (values[key] ~= nil) then
                local want = trim(values[key][1]);
                if (want ~= '' and want ~= tostring(row[prop] or '')) then
                    return false;
                end
            end
        end
    end
    return true;
end

local function find_row_by_selection(cats, currentId, values, field)
    if (currentId == nil or currentId == '') then
        return nil;
    end
    for _, cat in ipairs(cats) do
        for _, candidate in ipairs(lookup.rows(cat)) do
            if (row_matches_selection(candidate, currentId, values, field)) then
                return candidate;
            end
        end
    end
    return nil;
end

local function row_matches_query(row, query, cats)
    if (query == nil or query == '') then
        return true;
    end
    local idText = tostring(row.id);
    local name = (row.name or ''):lower();
    local shown = name;
    if (jobs_only(cats)) then
        shown = (JOB_NAMES[row.name] or row.name or ''):lower();
    end
    local zone = (row.zone or ''):lower();
    return name:find(query, 1, true) ~= nil
        or shown:find(query, 1, true) ~= nil
        or idText:find(query, 1, true) ~= nil
        or (zone ~= '' and zone:find(query, 1, true) ~= nil);
end

-- Shared across every dropdown that uses the same lookup categories.
local sharedCatalogs = {};

local function cats_key(cats)
    return table.concat(cats, '|');
end

local function request_shared_catalog(cats)
    local key = cats_key(cats);
    local shared = sharedCatalogs[key];
    if (shared == nil) then
        local copy = {};
        for index, cat in ipairs(cats) do
            copy[index] = cat;
        end
        shared = {
            key = key,
            cats = copy,
            catalog = nil,
            zones = nil,
            loaded = -1,
            build = nil,
        };
        sharedCatalogs[key] = shared;
    end
    return shared;
end

local function zone_name_less(a, b)
    local aBucket = sort_bucket(a);
    local bBucket = sort_bucket(b);
    if (aBucket ~= bBucket) then
        return aBucket < bBucket;
    end
    return title_case(a):lower() < title_case(b):lower();
end

local function pump_shared_catalog(shared, loaded)
    if (shared.catalog ~= nil and shared.loaded == loaded) then
        return true, 100;
    end
    if (shared.catalog ~= nil and shared.loaded ~= loaded) then
        shared.catalog = nil;
        shared.zones = nil;
        shared.build = nil;
    end

    local cats = shared.cats;
    local build = shared.build;
    if (build == nil) then
        build = {
            byZone = {},
            zoneNames = {},
            zoneSeen = {},
            catalog = {},
            catIndex = 1,
            rowIndex = 1,
            zoneIndex = 1,
            phase = 'copy',
            copied = 0,
            sortedZones = 0,
            total = math.max(1, loaded),
        };
        shared.build = build;
    end

    if (build.phase == 'copy') then
        local budget = CATALOG_COPY_CHUNK;
        while (budget > 0 and build.catIndex <= #cats) do
            local rows = lookup.rows(cats[build.catIndex]);
            if (build.rowIndex > #rows) then
                build.catIndex = build.catIndex + 1;
                build.rowIndex = 1;
            else
                local last = math.min(#rows, build.rowIndex + budget - 1);
                for index = build.rowIndex, last do
                    local row = rows[index];
                    local zone;
                    if (cats_use_zone_groups(cats)) then
                        zone = row.zone or '';
                    else
                        local name = sort_name(row, cats);
                        if (name == '' or name:find('^%s') ~= nil) then
                            zone = ' ';
                        else
                            zone = name:sub(1, 1);
                        end
                    end
                    local bucket = build.byZone[zone];
                    if (bucket == nil) then
                        bucket = {};
                        build.byZone[zone] = bucket;
                        if (build.zoneSeen[zone] == nil) then
                            build.zoneSeen[zone] = true;
                            build.zoneNames[#build.zoneNames + 1] = zone;
                        end
                    end
                    bucket[#bucket + 1] = row;
                    build.copied = build.copied + 1;
                    budget = budget - 1;
                end
                build.rowIndex = last + 1;
            end
        end
        if (build.catIndex > #cats) then
            table.sort(build.zoneNames, zone_name_less);
            build.phase = 'sort';
            build.zoneIndex = 1;
        end
        local pct = math.floor((build.copied * 70) / build.total);
        if (build.copied > 0 and pct < 1) then
            pct = 1;
        end
        if (pct > 70) then
            pct = 70;
        end
        return false, pct;
    end

    if (build.phase == 'sort') then
        local zonesDone = 0;
        while (zonesDone < CATALOG_SORT_ZONES and build.zoneIndex <= #build.zoneNames) do
            local zone = build.zoneNames[build.zoneIndex];
            local bucket = build.byZone[zone] or {};
            sort_rows(bucket, cats);
            for index = 1, #bucket do
                build.catalog[#build.catalog + 1] = bucket[index];
            end
            build.byZone[zone] = nil;
            build.zoneIndex = build.zoneIndex + 1;
            build.sortedZones = build.sortedZones + 1;
            zonesDone = zonesDone + 1;
        end
        if (build.zoneIndex <= #build.zoneNames) then
            local zoneTotal = math.max(1, #build.zoneNames);
            local pct = 70 + math.floor((build.sortedZones * 29) / zoneTotal);
            if (pct > 99) then
                pct = 99;
            end
            return false, pct;
        end
        shared.catalog = build.catalog;
        shared.loaded = loaded;
        if (cats_use_zone_groups(cats)) then
            shared.zones = build_zone_index(shared.catalog);
        else
            shared.zones = nil;
        end
        shared.build = nil;
        return true, 100;
    end

    return false, 0;
end

local function filter_catalog(catalog, query, cats)
    if (query == nil or query == '') then
        return catalog;
    end
    local q = query:lower();
    local out = {};
    for index = 1, #catalog do
        local row = catalog[index];
        if (row_matches_query(row, q, cats)) then
            out[#out + 1] = row;
        end
    end
    return out;
end

local function ordered_rows(cats)
    local shared = request_shared_catalog(cats);
    if (shared.catalog ~= nil) then
        return shared.catalog;
    end
    local list = {};
    for _, cat in ipairs(cats) do
        for _, row in ipairs(lookup.rows(cat)) do
            list[#list + 1] = row;
        end
    end
    sort_rows(list, cats);
    return list;
end

local function popup_inner_width(comboW)
    local pad = widgets.px(POPUP_PAD);
    return math.max(widgets.px(48), comboW - pad * 2);
end

local function region_width(fallback)
    if (imgui.GetContentRegionAvail ~= nil) then
        local a, b = imgui.GetContentRegionAvail();
        local w = select(1, vec2(a, b));
        if (type(w) == 'number' and w > 1) then
            return w;
        end
    end
    return fallback;
end

local function push_popup_padding()
    if (imgui.PushStyleVar == nil or ImGuiStyleVar_WindowPadding == nil) then
        return 0;
    end
    local pad = widgets.px(POPUP_PAD);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { pad, pad });
    return 1;
end

local function begin_combo(id, preview, fieldW)
    imgui.SetNextItemWidth(fieldW);
    local flags = 0;
    if (ImGuiComboFlags_HeightLarge ~= nil) then
        flags = bit.bor(flags, ImGuiComboFlags_HeightLarge);
    elseif (ImGuiComboFlags_HeightLargest ~= nil) then
        flags = bit.bor(flags, ImGuiComboFlags_HeightLargest);
    end
    if (ImGuiComboFlags_PopupAlignLeft ~= nil) then
        flags = bit.bor(flags, ImGuiComboFlags_PopupAlignLeft);
    end
    local opened;
    if (flags ~= 0) then
        local ok, result = pcall(imgui.BeginCombo, id, preview, flags);
        if (ok) then
            opened = result;
        else
            opened = imgui.BeginCombo(id, preview);
        end
    else
        opened = imgui.BeginCombo(id, preview);
    end
    if (opened) then
        note_combo_open();
    end
    return opened == true or (opened ~= nil and opened ~= false);
end

local function size_open_combo_popup(width, minH)
    if (imgui.SetWindowSize == nil or type(width) ~= 'number') then
        return;
    end
    local height = minH or (widgets.px(COMBO_LIST_H) + widgets.px(56));
    if (imgui.GetWindowHeight ~= nil) then
        local current = imgui.GetWindowHeight();
        if (type(current) == 'number' and current > height) then
            height = current;
        end
    end
    pcall(imgui.SetWindowSize, { width, height });
end

local function paint_combo_separator(x1, y1, x2, y2)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    if (draw == nil or draw.AddLine == nil) then
        return;
    end
    local pad = widgets.px(4);
    local midY = math.floor((y1 + y2) * 0.5 + 0.5);
    local color = theme.col32(theme.colors.borderSoft or theme.colors.peach);
    pcall(draw.AddLine, draw, { x1 + pad, midY }, { x2 - pad, midY }, color, 1);
end

local function draw_combo_list(popupId, cats, currentId, width, onSelect, values, field)
    widgets.apply_font();
    local alignPushed = false;
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_SelectableTextAlign ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_SelectableTextAlign, { 0.5, 0.5 });
        alignPushed = true;
    end
    lookup.focus(cats);
    for _, cat in ipairs(cats) do
        lookup.ensure(cat);
    end
    local listW = region_width(popup_inner_width(width));
    if (listW > width) then
        listW = popup_inner_width(width);
    end
    local key = popupId;
    local queryBuffer = searches[key .. ':q'];
    if (queryBuffer == nil) then
        queryBuffer = T{ '' };
        searches[key .. ':q'] = queryBuffer;
    end

    imgui.SetNextItemWidth(listW);
    widgets.placeholder(key .. 'filter', queryBuffer, 'Search', listW);

    local loaded = 0;
    local dataReady = true;
    for _, cat in ipairs(cats) do
        loaded = loaded + #lookup.rows(cat);
        if (not lookup.ready(cat)) then
            dataReady = false;
        end
    end

    local state = search_cache(key);
    local shared = request_shared_catalog(cats);
    local query = trim(queryBuffer[1]);
    local catalogReady = false;
    local buildPct = nil;
    if (dataReady) then
        catalogReady, buildPct = pump_shared_catalog(shared, loaded);
    end

    if (catalogReady and state.query ~= query) then
        state.query = query;
        state.matches = filter_catalog(shared.catalog, query, cats);
        if (query == '') then
            state.matchZones = shared.zones;
        elseif (cats_use_zone_groups(cats)) then
            state.matchZones = build_zone_index(state.matches);
        else
            state.matchZones = nil;
        end
        state.scrollY = 0;
        state.needScrollRestore = true;
    end

    local listReady = catalogReady;
    if (not listReady) then
        local loadingPct = lookup.groupLoading(cats);
        if (loadingPct == nil) then
            if (dataReady and buildPct ~= nil) then
                loadingPct = buildPct;
            else
                loadingPct = 0;
            end
        elseif (dataReady and buildPct ~= nil and buildPct > loadingPct) then
            loadingPct = buildPct;
        end
        local label = ('Loading...%d%%'):format(loadingPct);
        local tw = fit_text(label);
        local curX = imgui.GetCursorPosX();
        if (imgui.SetCursorPosX ~= nil) then
            imgui.SetCursorPosX(curX + math.max(0, (listW - tw) * 0.5));
        end
        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.peach);
        if (imgui.TextUnformatted ~= nil) then
            imgui.TextUnformatted(label);
        else
            imgui.Text(label);
        end
        imgui.PopStyleColor();
    else
        local rowH = combo_line_height();
        local textMax = math.max(1, listW - widgets.px(8));
        local matches = state.matches;
        local zones = state.matchZones;
        local total = display_count(zones, #matches);

        imgui.PushStyleColor(ImGuiCol_ChildBg, theme.colors.clear);
        widgets.begin_child('results' .. key, { listW, widgets.px(COMBO_LIST_H) }, false, 0, false);
        local spacingPushed = push_combo_list_spacing();
        if (widgets.apply_load_scroll('results' .. key)) then
            state.scrollY = 0;
            state.needScrollRestore = false;
        elseif (state.needScrollRestore and imgui.SetScrollY ~= nil) then
            pcall(imgui.SetScrollY, state.scrollY or 0);
            state.needScrollRestore = false;
        end
        if (total == 0) then
            imgui.TextDisabled('No matches');
        else
            local scrollY = 0;
            if (imgui.GetScrollY ~= nil) then
                local ok, value = pcall(imgui.GetScrollY);
                if (ok and type(value) == 'number') then
                    scrollY = value;
                end
            end
            state.scrollY = scrollY;
            local viewH = widgets.px(COMBO_LIST_H);
            if (imgui.GetWindowHeight ~= nil) then
                local ok, value = pcall(imgui.GetWindowHeight);
                if (ok and type(value) == 'number' and value > 0) then
                    viewH = value;
                end
            end

            local first = math.max(1, math.floor(scrollY / rowH) + 1);
            local visible = math.max(1, math.ceil(viewH / rowH) + 2);
            local last = math.min(total, first + visible);
            local rowW = region_width(listW);
            if (rowW > listW) then
                rowW = listW;
            end
            textMax = math.max(1, rowW - widgets.px(4));
            if (first > 1) then
                imgui.Dummy({ 1, (first - 1) * rowH });
            end

            local zoneIndex = 1;
            local at = 0;
            if (zones ~= nil) then
                while (zoneIndex <= #zones) do
                    local zone = zones[zoneIndex];
                    local zoneEnd = at + zone_span(zone, zoneIndex == #zones);
                    if (first <= zoneEnd) then
                        break;
                    end
                    at = zoneEnd;
                    zoneIndex = zoneIndex + 1;
                end
            end

            for index = first, last do
                local kind = 'row';
                local row = nil;
                local text = '';
                if (zones ~= nil) then
                    while (zoneIndex <= #zones) do
                        local zone = zones[zoneIndex];
                        local isLast = zoneIndex == #zones;
                        local headerAt = at + 1;
                        local sepAt = at + 2;
                        local entryFirst = at + 3;
                        local entryLast = at + 2 + zone.count;
                        local blankAt = (not isLast) and (entryLast + 1) or nil;
                        local zoneEnd = at + zone_span(zone, isLast);
                        if (index == headerAt) then
                            kind = 'header';
                            text = zone.label;
                            break;
                        elseif (index == sepAt) then
                            kind = 'sep';
                            break;
                        elseif (index >= entryFirst and index <= entryLast) then
                            kind = 'row';
                            local rowIndex = zone.first + (index - entryFirst);
                            row = matches[rowIndex];
                            text = display_label(row.name, cats, row);
                            break;
                        elseif (blankAt ~= nil and index == blankAt) then
                            kind = 'blank';
                            break;
                        else
                            at = zoneEnd;
                            zoneIndex = zoneIndex + 1;
                        end
                    end
                else
                    row = matches[index];
                    text = display_label(row.name, cats, row);
                end

                if (kind == 'blank') then
                    imgui.Dummy({ rowW, rowH });
                elseif (kind == 'sep') then
                    imgui.Dummy({ rowW, rowH });
                    local x1, y1, x2, y2 = item_bounds(rowW, rowH);
                    paint_combo_separator(x1, y1, x2, y2);
                else
                    local line = {
                        text = text,
                        wraps = nil,
                        wrapW = nil,
                        height = rowH,
                    };
                    local wraps, height = ensure_line_wrap(line, textMax, rowH);
                    if (kind == 'header') then
                        imgui.Dummy({ rowW, height });
                        local x1, y1, x2, y2 = item_bounds(rowW, height);
                        paint_combo_text(
                            x1,
                            y1,
                            x2,
                            y2,
                            wraps,
                            theme.col32(theme.colors.peach),
                            nil,
                            true
                        );
                    else
                        local selected = row_matches_selection(row, currentId, values, field);
                        imgui.PushStyleColor(ImGuiCol_Header, theme.colors.clear);
                        imgui.PushStyleColor(ImGuiCol_HeaderHovered, theme.colors.clear);
                        imgui.PushStyleColor(ImGuiCol_HeaderActive, theme.colors.clear);
                        local pickedRow = false;
                        local okSelectable, result = pcall(imgui.Selectable, '##row' .. index .. key, false, 0, { rowW, height });
                        if (okSelectable) then
                            pickedRow = result == true;
                        else
                            pickedRow = imgui.Selectable('##row' .. index .. key, false) == true;
                        end
                        local hot = selected or (imgui.IsItemHovered ~= nil and imgui.IsItemHovered());
                        local x1, y1, x2, y2 = item_bounds(rowW, height);
                        if (hot) then
                            theme.paint_row_highlight(x1, y1, x2, y2, widgets.px(3));
                        end
                        paint_combo_text(
                            x1,
                            y1,
                            x2,
                            y2,
                            wraps,
                            theme.col32(theme.colors.text),
                            nil,
                            true
                        );
                        imgui.PopStyleColor(3);
                        if (pickedRow and row ~= nil) then
                            queryBuffer[1] = '';
                            onSelect(row);
                            imgui.CloseCurrentPopup();
                        end
                    end
                end
            end

            if (last < total) then
                imgui.Dummy({ 1, (total - last) * rowH });
            end
        end
        if (imgui.GetScrollY ~= nil) then
            local ok, value = pcall(imgui.GetScrollY);
            if (ok and type(value) == 'number') then
                state.scrollY = value;
            end
        end
        if (spacingPushed > 0 and imgui.PopStyleVar ~= nil) then
            imgui.PopStyleVar(spacingPushed);
        end
        imgui.EndChild();
        imgui.PopStyleColor();
    end
    if (alignPushed and imgui.PopStyleVar ~= nil) then
        imgui.PopStyleVar();
    end
end

function widgets.lookup(id, field, values, labels)
    local cats = cats_of(field);
    for _, cat in ipairs(cats) do
        lookup.ensure(cat);
    end
    local current = trim(values[field.key][1]);
    local pickedToken = selection_token(current, values, field);
    if (current == '') then
        labels[id] = nil;
        labels[id .. ':picked'] = nil;
        labels[id .. ':miss'] = nil;
    elseif (labels[id .. ':picked'] ~= pickedToken and labels[id .. ':miss'] ~= pickedToken) then
        local loaded = 0;
        local ready = true;
        for _, cat in ipairs(cats) do
            loaded = loaded + #lookup.rows(cat);
            if (not lookup.ready(cat)) then
                ready = false;
            end
        end
        local row = find_row_by_selection(cats, current, values, field);
        if (row == nil and ready) then
            for _, cat in ipairs(cats) do
                for _, candidate in ipairs(lookup.rows(cat)) do
                    if (tostring(candidate.id) == current) then
                        row = candidate;
                        break;
                    end
                end
                if (row ~= nil) then
                    break;
                end
            end
        end
        if (row ~= nil) then
            labels[id .. ':picked'] = pickedToken;
            labels[id] = display_label(row.name, cats, row);
            labels[id .. ':miss'] = nil;
        elseif (ready and labels[id .. ':missLoaded'] == loaded) then
            labels[id .. ':miss'] = pickedToken;
        else
            labels[id .. ':missLoaded'] = loaded;
        end
    end
    local hint = field.placeholder or lookup.label(field.lookup);
    local shown = labels[id];
    if (shown == nil or shown == '') then
        shown = hint;
    end
    local displayW = widgets.combo_display_width(field);
    local empty = shown == hint;
    if (empty) then
        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.muted);
    end
    local function apply_row(row)
        values[field.key][1] = tostring(row.id);
        if (field.fills ~= nil) then
            for key, prop in pairs(field.fills) do
                if (values[key] ~= nil) then
                    values[key][1] = tostring(row[prop] or '');
                end
            end
        end
        labels[id .. ':picked'] = selection_token(tostring(row.id), values, field);
        labels[id] = display_label(row.name, cats, row);
        labels[id .. ':miss'] = nil;
    end
    local state = search_cache(id);
    local opened = begin_combo('##' .. id, shown, displayW);
    local comboFocused = item_focused();
    if (empty) then
        imgui.PopStyleColor();
    end
    if (opened) then
        local popupPad = push_popup_padding();
        size_open_combo_popup(displayW);
        if (not state.popupOpen) then
            state.popupOpen = true;
            state.needScrollRestore = true;
        end
        draw_combo_list(id, cats, current, displayW, apply_row, values, field);
        if (popupPad > 0 and imgui.PopStyleVar ~= nil) then
            imgui.PopStyleVar(popupPad);
        end
        imgui.EndCombo();
    else
        state.popupOpen = false;
    end

    local fillFocused = false;
    if (field.fills ~= nil) then
        for key, _ in pairs(field.fills) do
            if (values[key] ~= nil) then
                imgui.SameLine();
                widgets.placeholder(id .. 'fill' .. key, values[key], 'Log ID', measure_fill_slot());
                if (item_focused()) then
                    fillFocused = true;
                end
            end
        end
    end

    imgui.SameLine();
    widgets.placeholder(id .. 'id', values[field.key], 'ID', widgets.id_width(field));
    local idFocused = item_focused();
    if (not opened and current ~= '' and (comboFocused or fillFocused or idFocused)) then
        arrowCaptureRequest = true;
        local delta = arrow_delta();
        if (delta ~= 0) then
            local list = ordered_rows(cats);
            local index = nil;
            for rowIndex, row in ipairs(list) do
                if (row_matches_selection(row, current, values, field)) then
                    index = rowIndex;
                    break;
                end
            end
            if (index == nil) then
                for rowIndex, row in ipairs(list) do
                    if (tostring(row.id) == current) then
                        index = rowIndex;
                        break;
                    end
                end
            end
            if (index ~= nil) then
                local nextIndex = index + delta;
                if (list[nextIndex] ~= nil) then
                    apply_row(list[nextIndex]);
                end
            end
        end
    end
end

local function pump_pending_catalogs()
    for _, shared in pairs(sharedCatalogs) do
        local loaded = 0;
        local ready = true;
        for _, cat in ipairs(shared.cats) do
            loaded = loaded + #lookup.rows(cat);
            if (not lookup.ready(cat)) then
                ready = false;
            end
        end
        if (ready and loaded >= 0 and (shared.catalog == nil or shared.loaded ~= loaded)) then
            pump_shared_catalog(shared, loaded);
        end
    end
end

local _end_frame = widgets.end_frame;
function widgets.end_frame()
    _end_frame();
    pump_pending_catalogs();
end

return widgets;
