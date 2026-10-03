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

        -- Tenta carregar a cutscene nativa do GTA Online
        local cutsceneOk = false
        pcall(function()
            if not HasThisCutsceneLoaded('mp_intro_concat') then
                RequestCutscene('mp_intro_concat', 8)
                local deadline = GetGameTimer() + 6000
                while not HasThisCutsceneLoaded('mp_intro_concat') and GetGameTimer() < deadline do
                    Wait(100)
                end
            end
            if HasThisCutsceneLoaded('mp_intro_concat') then
                cutsceneOk = true
            end
        end)

        if cutsceneOk then
            dbg('[plane] cutscene mp_intro_concat carregada com sucesso')
            StartCutscene(0)
            DoScreenFadeIn(400)

            -- Legendas sincronizadas
            local timings = { 500, 5000, 10000 }
            for i, subtitle in ipairs(subtitles) do
                Wait(timings[i] or 1000)
                if not IsCutsceneActive() then break end
                W2F.SendNui('showArrivalSubtitle', { text = subtitle, durationMs = 3500 })
            end

            -- Aguarda cutscene terminar ou tecla de pulo (Enter / Espaço)
            local deadline = GetGameTimer() + 25000
            while IsCutsceneActive() and GetGameTimer() < deadline do
                if IsControlJustReleased(0, 191) or IsControlJustReleased(0, 201) then
                    StopCutscene(true)
                    break
                end
                Wait(50)
            end

            if IsCutsceneActive() then StopCutscene(true) end
            RemoveCutscene()
            dbg('[plane] cutscene concluida')
        else
            -- Travelling aéreo in-engine sobre o Aeroporto Internacional LSIA
            dbg('[plane] executando sobrevoo cinematografico in-engine sobre LSIA')

            -- Áudio ambiente de turbinas de aeronave
            pcall(function()
                PlaySoundFrontend(-1, 'Air_Defenses_Activated', 'DLC_sum20_Business_Hub_Soundset', false)
            end)

            -- Câmera 1: Alta altitude sobre a pista de pouso com vista da torre
            local cam1 = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            SetCamCoord(cam1, -1550.0, -3150.0, 95.0)
            PointCamAtCoord(cam1, cutscenePos.x, cutscenePos.y, cutscenePos.z + 10.0)
            SetCamFov(cam1, 50.0)
            SetCamActive(cam1, true)
            RenderScriptCams(true, false, 0, true, false)

            DoScreenFadeIn(800)
            while not IsScreenFadedIn() do Wait(0) end

            -- Legenda 1
            W2F.SendNui('showArrivalSubtitle', { text = subtitles[1], durationMs = 3500 })

            -- Câmera 2: Travelling rasante aproximando do terminal de desembarque
            local cam2 = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            SetCamCoord(cam2, -1080.0, -2780.0, 28.0)
            PointCamAtCoord(cam2, cutscenePos.x, cutscenePos.y, cutscenePos.z + 1.5)
            SetCamFov(cam2, 45.0)

            SetCamActiveWithInterp(cam2, cam1, 5000, 1, 1)

            -- Verifica skip durante a transição
            local skipPressed = false
            local timerStart = GetGameTimer()
            while GetGameTimer() - timerStart < 5200 do
                if IsControlJustReleased(0, 191) or IsControlJustReleased(0, 201) then
                    skipPressed = true
                    break
                end
                Wait(50)
            end

            if not skipPressed then
                if DoesCamExist(cam1) then DestroyCam(cam1, false) end
                SetCamActive(cam2, true)

                -- Legenda 2
                W2F.SendNui('showArrivalSubtitle', { text = subtitles[2], durationMs = 3500 })

                -- Câmera 3: Foco no saguão frontal de desembarque
                local cam3 = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                SetCamCoord(cam3, -1045.0, -2745.0, 16.0)
                PointCamAtCoord(cam3, cutscenePos.x, cutscenePos.y, cutscenePos.z + 1.0)
                SetCamFov(cam3, 38.0)
                SetCamActiveWithInterp(cam3, cam2, 3500, 1, 1)

                timerStart = GetGameTimer()
                while GetGameTimer() - timerStart < 3700 do
                    if IsControlJustReleased(0, 191) or IsControlJustReleased(0, 201) then
                        skipPressed = true
                        break
                    end
                    Wait(50)
                end

                if not skipPressed then
                    -- Legenda 3
                    W2F.SendNui('showArrivalSubtitle', { text = subtitles[3], durationMs = 3000 })
                    Wait(2500)
                end

                if DoesCamExist(cam3) then DestroyCam(cam3, false) end
            end

            if DoesCamExist(cam1) then DestroyCam(cam1, false) end
            if DoesCamExist(cam2) then DestroyCam(cam2, false) end
            RenderScriptCams(false, false, 0, true, false)
        end

        -- Cleanup e entrega
        DoScreenFadeOut(600)
        while not IsScreenFadedOut() do Wait(0) end

        -- Define coordenadas seguras de destino final (calçada do desembarque LSIA)
        local targetCoords = spawnCoords or cutscenePos
        local okGround, safeZ = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, targetCoords.z + 2.0, false)
        if okGround and safeZ > 1.0 then
            targetCoords = vec4(targetCoords.x, targetCoords.y, safeZ, targetCoords.w or 330.0)
        end

        W2F.SendNui('hideArrivalSubtitle', {})
        SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
        SetEntityHeading(ped, targetCoords.w or 330.0)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)

        dbg('[plane] historia concluida, entregando para spawn em %s %s %s', targetCoords.x, targetCoords.y, targetCoords.z)
        if ctx and ctx.handBack then
            ctx.handBack(targetCoords)
        end
    end)
end

