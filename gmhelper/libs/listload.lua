--[[
* Chunked list builds for Favorites / Presets / History.
* One chunk per frame so huge custom lists do not hitch.
]]

local listload = {};

local CHUNK = 40;

local function clamp_pct(done, total, ready)
    if (total <= 0 or ready) then
        return 100;
    end
    local pct = math.floor((done * 100) / total);
    if (done > 0 and pct < 1) then
        pct = 1;
    end
    if (pct > 99) then
        pct = 99;
    end
    return pct;
end

function listload.cache(state, key, token, total)
    state.pageCaches = state.pageCaches or {};
    local cache = state.pageCaches[key];
    if (cache == nil or cache.token ~= token or cache.total ~= total) then
        cache = {
            token = token,
            total = total or 0,
            nextIndex = 1,
            rows = {},
            ready = (total or 0) <= 0,
        };
        state.pageCaches[key] = cache;
    end
    return cache;
end

function listload.pump(cache, visit)
    if (cache == nil or cache.ready) then
        return cache;
    end
    local n = 0;
    while (cache.nextIndex <= cache.total and n < CHUNK) do
        visit(cache.nextIndex);
        cache.nextIndex = cache.nextIndex + 1;
        n = n + 1;
    end
    if (cache.nextIndex > cache.total) then
        cache.ready = true;
    end
    return cache;
end

function listload.percent(cache)
    if (cache == nil) then
        return 100;
    end
    local done = math.max(0, (cache.nextIndex or 1) - 1);
    return clamp_pct(done, cache.total or 0, cache.ready == true);
end

function listload.label(cache)
    local pct = listload.percent(cache);
    if (pct >= 100) then
        return nil;
    end
    return ('Loading...%d%%'):format(pct);
end

function listload.invalidate(state, key)
    if (state == nil or state.pageCaches == nil) then
        return;
    end
    if (key == nil) then
        state.pageCaches = {};
        return;
    end
    state.pageCaches[key] = nil;
end

return listload;
