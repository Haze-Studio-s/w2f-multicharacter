--- W2F.Arrival.Plane — História de Chegada: Avião.
---
--- Usa a cutscene nativa mp_intro_concat do GTA Online com legendas
--- sincronizadas via NUI ou travelling aéreo in-engine caso a cutscene falhe.
--- Protegido contra memory leaks de câmeras, skip universal (NUI/Teclado) e disconnect.

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
        local skipped = false
        local cameras = {}

        local function doSkip()
            if skipped then return end
            skipped = true
            dbg('[plane] jogador pulou a historia de aviao')
        end

        RegisterNUICallback('skipArrivalStory', function(data, cb)
            doSkip()
            if cb then cb('ok') end
        end)

        local function createCam(pos, lookAt, fov)
            local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            SetCamCoord(cam, pos.x, pos.y, pos.z)
            if lookAt then PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z) end
            SetCamFov(cam, fov or 50.0)
            cameras[#cameras + 1] = cam
            return cam
        end

        local function cleanupCameras()
            for _, cam in ipairs(cameras) do
                if DoesCamExist(cam) then
                    DestroyCam(cam, false)
                end
            end
            cameras = {}
            RenderScriptCams(false, false, 0, true, false)
        end

        -- Monitor de tecla de pulo (Enter / Espaço)
        CreateThread(function()
            while not skipped do
                if IsDisabledControlJustPressed(0, 22) or IsDisabledControlJustPressed(0, 201) or IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) then
                    doSkip()
                    break
                end
                Wait(0)
            end
        end)

        -- Posição segura para cutscene (fora de qualquer interior)
        local cutscenePos = (Config.Arrival or {}).planeSpawnCoords or vec4(-1037.0, -2737.0, 13.8, 330.0)
        SetEntityCoords(ped, cutscenePos.x, cutscenePos.y, cutscenePos.z, false, false, false, false)
        SetEntityCollision(ped, false, false)
        SetEntityVisible(ped, false, false)
        FreezeEntityPosition(ped, true)
        Wait(200)

        W2F.SendNui('showArrivalSkip', {})
        W2F.SendNui('showCinemaBars', {})

        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(0) end

        -- Tenta carregar a cutscene nativa do GTA Online
        local cutsceneOk = false
        pcall(function()
            if not HasThisCutsceneLoaded('mp_intro_concat') then
                RequestCutscene('mp_intro_concat', 8)
                local deadline = GetGameTimer() + 6000
                while not HasThisCutsceneLoaded('mp_intro_concat') and GetGameTimer() < deadline and not skipped do
                    Wait(100)
                end
            end
            if HasThisCutsceneLoaded('mp_intro_concat') and not skipped then
                cutsceneOk = true
            end
        end)

        if cutsceneOk and not skipped then
            dbg('[plane] cutscene mp_intro_concat carregada com sucesso')
            StartCutscene(0)
            DoScreenFadeIn(400)

            local timings = { 500, 5000, 10000 }
            for i, subtitle in ipairs(subtitles) do
                local timerEnd = GetGameTimer() + (timings[i] or 1000)
                while GetGameTimer() < timerEnd and not skipped do
                    if not IsCutsceneActive() then break end
                    Wait(50)
                end
                if skipped or not IsCutsceneActive() then break end
                W2F.SendNui('showArrivalSubtitle', { text = subtitle, durationMs = 3500 })
            end

            local deadline = GetGameTimer() + 25000
            while IsCutsceneActive() and GetGameTimer() < deadline and not skipped do
                Wait(50)
            end

            if IsCutsceneActive() then StopCutscene(true) end
            if HasThisCutsceneLoaded('mp_intro_concat') then RemoveCutscene() end
            dbg('[plane] cutscene concluida')
        else
            -- Travelling aéreo in-engine sobre o Aeroporto Internacional LSIA
            dbg('[plane] executando sobrevoo cinematografico in-engine sobre LSIA')

            pcall(function()
                PlaySoundFrontend(-1, 'Air_Defenses_Activated', 'DLC_sum20_Business_Hub_Soundset', false)
            end)

            local cam1 = createCam(vec3(-1550.0, -3150.0, 95.0), vec3(cutscenePos.x, cutscenePos.y, cutscenePos.z + 10.0), 50.0)
            SetCamActive(cam1, true)
            RenderScriptCams(true, false, 0, true, false)

            DoScreenFadeIn(800)
            while not IsScreenFadedIn() do Wait(0) end

            W2F.SendNui('showArrivalSubtitle', { text = subtitles[1], durationMs = 3500 })

            -- Aguarda cam1 com checagem de skip
            local timerStart = GetGameTimer()
            while GetGameTimer() - timerStart < 3500 and not skipped do
                Wait(50)
            end

            if not skipped then
                local cam2 = createCam(vec3(-1080.0, -2780.0, 28.0), vec3(cutscenePos.x, cutscenePos.y, cutscenePos.z + 1.5), 45.0)
                SetCamActiveWithInterp(cam2, cam1, 4500, 1, 1)

                timerStart = GetGameTimer()
                while GetGameTimer() - timerStart < 4700 and not skipped do
                    Wait(50)
                end

                if not skipped then
                    W2F.SendNui('showArrivalSubtitle', { text = subtitles[2], durationMs = 3500 })

                    local cam3 = createCam(vec3(-1045.0, -2745.0, 16.0), vec3(cutscenePos.x, cutscenePos.y, cutscenePos.z + 1.0), 38.0)
                    SetCamActiveWithInterp(cam3, cam2, 3500, 1, 1)

                    timerStart = GetGameTimer()
                    while GetGameTimer() - timerStart < 3700 and not skipped do
                        Wait(50)
                    end

                    if not skipped then
                        W2F.SendNui('showArrivalSubtitle', { text = subtitles[3], durationMs = 3000 })
                        timerStart = GetGameTimer()
                        while GetGameTimer() - timerStart < 2500 and not skipped do
                            Wait(50)
                        end
                    end
                end
            end

            cleanupCameras()
        end

        -- Cleanup geral
        cleanupCameras()
        W2F.SendNui('hideArrivalSubtitle', {})
        W2F.SendNui('hideArrivalSkip', {})
        W2F.SendNui('hideCinemaBars', {})

        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(0) end

        local targetCoords = spawnCoords or cutscenePos
        local okGround, safeZ = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, targetCoords.z + 2.0, false)
        if okGround and safeZ > 1.0 then
            targetCoords = vec4(targetCoords.x, targetCoords.y, safeZ, targetCoords.w or 330.0)
        end

        SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
        SetEntityHeading(ped, targetCoords.w or 330.0)
        SetEntityCollision(ped, true, true)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)

        DoScreenFadeIn(600)

        dbg('[plane] historia concluida, entregando para spawn em %s %s %s', targetCoords.x, targetCoords.y, targetCoords.z)
        if ctx and ctx.handBack then
            ctx.handBack(targetCoords)
        end
    end)
end

if W2F.Arrival and W2F.Arrival.Register then
    W2F.Arrival.Register('plane', W2F.Arrival.Plane)
end
