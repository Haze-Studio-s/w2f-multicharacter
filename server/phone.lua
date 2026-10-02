--- W2F Multicharacter — Phone Number Resolver
--- Adaptado para desacoplamento de múltiplos scripts de telefone

W2F = W2F or {}
W2F.Phone = {}

--- Busca o número de telefone de forma segura e não bloqueante
---@param source number
---@param citizenid string
---@return string?
function W2F.Phone.GetNumber(source, citizenid)
    if not citizenid or citizenid == '' then return nil end

    -- 1. LB-Phone
    if GetResourceState('lb-phone') == 'started' then
        local ok, num = pcall(function()
            return exports['lb-phone']:GetEquippedPhoneNumber(source)
        end)
        if ok and num and num ~= '' then return tostring(num) end
    end

    -- 2. QS-Smartphone Pro
    if GetResourceState('qs-smartphone-pro') == 'started' then
        local ok, num = pcall(function()
            return exports['qs-smartphone-pro']:GetPhoneNumberFromIdentifier(citizenid, true)
        end)
        if ok and num and num ~= '' then return tostring(num) end
    end

    -- 3. QS-Smartphone (standard)
    if GetResourceState('qs-smartphone') == 'started' then
        local ok, num = pcall(function()
            return exports['qs-smartphone']:GetPhoneNumberFromIdentifier(citizenid, true)
        end)
        if ok and num and num ~= '' then return tostring(num) end
    end

    -- 4. YSeries Phone
    if GetResourceState('yseries') == 'started' then
        local ok, num = pcall(function()
            return exports.yseries:GetPhoneNumberBySourceId(source)
        end)
        if ok and num and num ~= '' then return tostring(num) end
    end

    -- 5. Fallback para banco de dados do QBox / QBCore
    local ok, row = pcall(function()
        return MySQL.single.await('SELECT charinfo, metadata, phone_number FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    end)

    if ok and row then
        if row.phone_number and row.phone_number ~= '' then
            return tostring(row.phone_number)
        end
        if row.charinfo then
            local cinfo = json.decode(row.charinfo)
            if cinfo and cinfo.phone and cinfo.phone ~= '' then
                return tostring(cinfo.phone)
            end
        end
        if row.metadata then
            local meta = json.decode(row.metadata)
            if meta and meta.phone and meta.phone ~= '' then
                return tostring(meta.phone)
            end
        end
    end

    return nil
end

lib.callback.register('w2f-multicharacter:server:getPhoneNumber', function(source, citizenid)
    return W2F.Phone.GetNumber(source, citizenid)
end)
