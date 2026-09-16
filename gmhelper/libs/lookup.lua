--[[
* Chunked, cached lookup loads. One chunk per frame so a dropdown open does not hitch.
]]

local lookup = {};

local cache = {};
local focus = nil;
local focusPending = nil;
local order = {
    'items', 'keyitems', 'quests', 'missions', 'cutscenes', 'mobs', 'skills',
    'npcs', 'effects', 'costumes', 'titles', 'spells', 'zones', 'jobs', 'weather', 'mounts',
};

local function entry(id)
    local current = cache[id];
    if (current ~= nil) then
        return current;
    end
    local meta = require('data.' .. id .. '.meta');
    current = {
        id = id,
        meta = meta,
        status = 'idle',
        loaded = 0,
        rows = {},
        zones = {},
        zoneSeen = {},
        nextChunk = 1,
    };
    cache[id] = current;
    return current;
end

function lookup.order()
    return order;
end

function lookup.meta(id)
    return entry(id).meta;
end

function lookup.ensure(id)
    local current = entry(id);
    if (current.status == 'idle') then
        if ((current.meta.chunks or 0) == 0) then
            current.status = 'ready';
            current.loaded = 0;
        else
            current.status = 'loading';
        end
    end
    return current;
end

local function append_chunk(current)
    local index = current.nextChunk;
    if (index > (current.meta.chunks or 0)) then
        current.status = 'ready';
        return false;
    end
    local chunk = require(('data.%s.%d'):format(current.id, index));
    for _, row in ipairs(chunk) do
        current.rows[#current.rows + 1] = row;
        if (row.zone ~= nil and current.zoneSeen[row.zone] == nil) then
            current.zoneSeen[row.zone] = true;
            current.zones[#current.zones + 1] = row.zone;
        end
    end
    current.loaded = #current.rows;
    current.nextChunk = index + 1;
    if (current.nextChunk > current.meta.chunks) then
        table.sort(current.zones);
        current.status = 'ready';
    end
    return true;
end

function lookup.begin_frame()
    focusPending = nil;
end

function lookup.focus(ids)
    focusPending = ids;
end

function lookup.end_frame()
    focus = focusPending;
end

local function load_next(ids)
    if (ids == nil) then
        return false;
    end
    for _, id in ipairs(ids) do
        local current = cache[id];
        if (current ~= nil and current.status == 'loading') then
            append_chunk(current);
            return true;
        end
    end
    return false;
end

function lookup.tick()
    -- One chunk per frame. A time loop is unsafe here: os.clock can stay
    -- flat for a whole frame and would pull the rest of the table at once.
    if (load_next(focus)) then
        return;
    end
    for _, id in ipairs(order) do
        local current = cache[id];
        if (current ~= nil and current.status == 'loading') then
            append_chunk(current);
            return;
        end
    end
end

function lookup.ready(id)
    return entry(id).status == 'ready';
end

function lookup.loading(id)
    local current = entry(id);
    return current.status == 'loading';
end

local function chunks_done(current)
    local chunks = current.meta.chunks or 0;
    if (current.status == 'ready') then
        return chunks, chunks;
    end
    local done = math.max(0, (current.nextChunk or 1) - 1);
    if (done > chunks) then
        done = chunks;
    end
    return done, chunks;
end

function lookup.percent(id)
    local done, chunks = chunks_done(entry(id));
    if (chunks <= 0) then
        return entry(id).status == 'ready' and 100 or 0;
    end
    if (done >= chunks) then
        return 100;
    end
    local pct = math.floor((done * 100) / chunks);
    if (done > 0 and pct < 1) then
        pct = 1;
    end
    return pct;
end

function lookup.groupLoading(ids)
    local done = 0;
    local chunks = 0;
    local loading = false;
    for _, id in ipairs(ids) do
        local current = entry(id);
        local partDone, partChunks = chunks_done(current);
        done = done + partDone;
        chunks = chunks + partChunks;
        if (current.status == 'loading') then
            loading = true;
        end
    end
    if (not loading) then
        return nil;
    end
    if (chunks <= 0) then
        return 0;
    end
    local pct = math.floor((done * 100) / chunks);
    if (done > 0 and pct < 1) then
        pct = 1;
    end
    if (pct > 99) then
        pct = 99;
    end
    return pct;
end

function lookup.loadingText(id)
    local pct = lookup.percent(id);
    if (pct > 99) then
        pct = 99;
    end
    return ('Loading...%d%%'):format(pct);
end

function lookup.rows(id)
    return entry(id).rows;
end

function lookup.zones(id)
    return entry(id).zones;
end

function lookup.label(id)
    return entry(id).meta.label or id;
end

function lookup.longestName(id)
    local meta = entry(id).meta;
    if (meta.longestName ~= nil and meta.longestName ~= '') then
        return meta.longestName;
    end
    return meta.label or '';
end

function lookup.longestId(id)
    local meta = entry(id).meta;
    if (meta.longestId ~= nil and meta.longestId ~= '') then
        return meta.longestId;
    end
    return '0';
end

return lookup;
