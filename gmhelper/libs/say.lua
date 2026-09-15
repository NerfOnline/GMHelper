--[[
* Builds and sends a GM command as say chat, independent of the active chat tab.
]]

require('common');

local say = {};

local function trim(value)
    if (value == nil) then
        return '';
    end
    return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''));
end

function say.fieldValue(values, key)
    if (values == nil or values[key] == nil) then
        return '';
    end
    return trim(values[key][1]);
end

--[[
* Returns the say payload (without /say) or nil and an error string.
* Empty optional arguments are omitted. Placeholders are never part of values.
]]
function say.build(command, values)
    for _, field in ipairs(command.fields) do
        if (not field.optional and say.fieldValue(values, field.key) == '') then
            return nil, field.label .. ' is required.';
        end
    end

    local parts = { '!' .. command.id };
    local lastFilled = 0;
    for index, field in ipairs(command.fields) do
        local value = say.fieldValue(values, field.key);
        if (value ~= '') then
            if (index > lastFilled + 1) then
                return nil, 'Fill earlier fields before later ones.';
            end
            parts[#parts + 1] = value;
            lastFilled = index;
        end
    end

    return table.concat(parts, ' ');
end

function say.send(payload)
    if (payload == nil or payload == '') then
        return false, 'Nothing to send.';
    end
    if (payload:sub(1, 1) ~= '!') then
        return false, 'Command must start with !.';
    end
    AshitaCore:GetChatManager():QueueCommand(1, '/say ' .. payload);
    return true;
end

return say;
