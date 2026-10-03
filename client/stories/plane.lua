--- W2F.Arrival.Plane — História de Chegada: Avião.
---
--- Usa a cutscene nativa mp_intro_concat do GTA Online com legendas
--- sincronizadas via NUI. Disponível para qualquer nacionalidade.
--- Sequência:
---   1. Fade out + tela preta.
---   2. Cutscene mp_intro_concat (pode ser pulada com Enter/Space).
---   3. Legendas sobre a cutscene via NUI.
---   4. Teleporta para spawnCoords e entrega.

W2F.Arrival = W2F.Arrival or {}

local function dbg(...)
    if W2F.Debug then W2F.Debug(...) end
end

function W2F.Arrival.Plane(ctx, spawnCoords)
    dbg('[plane] historia de aviao iniciando')

    local function getSub(key, fallback)
        if type(locale) == 'function' then
            local ok, res = pcall(locale, key)
            if ok and res and res ~= key then return res end
        end
        return fallback
    end

    local subtitles = {
        getSub('story.plane_1', 'O voo foi longo. Los Santos cresceu pela janela.'),
        getSub('story.plane_2', 'Primeira classe ou economia — o destino é o mesmo.'),
        getSub('story.plane_3', 'Bem-vindo a Los Santos. Não há volta.'),
    }

    CreateThread(function()
        local ped = PlayerPedId()

        -- Posição segura para cutscene (fora de qualquer interior)
        local cutscenePos = (Config.Arrival or {}).planeSpawnCoords or vec4(-1037.0, -2737.0, 13.8, 0.0)
        SetEntityCoords(ped, cutscenePos.x, cutscenePos.y, cutscenePos.z, false, false, false, false)
        SetEntityVisible(ped, false, false)
        FreezeEntityPosition(ped, true)
        Wait(200)

        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(0) end

        -- Tenta iniciar cutscene (pode não existir em todas as builds)
        local cutsceneOk = false
        pcall(function()
            if not HasThisCutsceneLoaded('mp_intro_concat') then
                RequestCutscene('mp_intro_concat', 8)
                local deadline = GetGameTimer() + 10000
                while not HasThisCutsceneLoaded('mp_intro_concat') and GetGameTimer() < deadline do
                    Wait(100)
                end
            end
            if HasThisCutsceneLoaded('mp_intro_concat') then
                cutsceneOk = true
            end
        end)

        if cutsceneOk then
            dbg('[plane] cutscene mp_intro_concat carregada')
            StartCutscene('mp_intro_concat')
            DoScreenFadeIn(400)

            -- Legendas sincronizadas
            local timings = { 0, 4000, 8000 }
            for i, subtitle in ipairs(subtitles) do
                Wait(timings[i] or 0)
                W2F.SendNui('showArrivalSubtitle', { text = subtitle, durationMs = 3500 })
            end

            -- Aguarda cutscene terminar (ou skip)
            local skipPressed = false
            CreateThread(function()
                while IsCutsceneActive() do
                    if IsControlJustReleased(0, 191) or IsControlJustReleased(0, 201) then  -- Enter / Space
                        StopCutscene(true)
                        skipPressed = true
                    end
                    Wait(0)
                end
            end)

            local deadline = GetGameTimer() + 30000  -- max 30s
            while IsCutsceneActive() and GetGameTimer() < deadline do
                Wait(200)
            end

            if IsCutsceneActive() then StopCutscene(true) end
            RemoveCutscene()
            dbg('[plane] cutscene concluida, skip=%s', tostring(skipPressed))
        else
            -- Fallback sem cutscene: fade simples com legendas
            dbg('[plane] cutscene indisponivel, usando fade simples')
            DoScreenFadeIn(500)
            for _, subtitle in ipairs(subtitles) do
                W2F.SendNui('showArrivalSubtitle', { text = subtitle, durationMs = 3000 })
                Wait(3200)
            end
        end

        -- Cleanup e entrega
        DoScreenFadeOut(600)
        while not IsScreenFadedOut() do Wait(0) end

        W2F.SendNui('hideArrivalSubtitle', {})
        SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
        SetEntityHeading(ped, spawnCoords.w or 0.0)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)

        DoScreenFadeIn(700)
        while not IsScreenFadedIn() do Wait(0) end

        dbg('[plane] historia concluida, entregando para spawn')
        if ctx and ctx.handBack then
            ctx.handBack(spawnCoords)
        end
    end)
end
