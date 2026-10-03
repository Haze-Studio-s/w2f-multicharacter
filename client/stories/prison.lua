--- W2F.Arrival.Prison — História de Chegada: Saída da Penitenciária de Bolingbroke.
---
--- O jogador é libertado pelos portões de aço de Bolingbroke após cumprir pena.
--- Protegido com skip universal, controle de câmeras, ciclo de vida do veículo e cleanup.

W2F.Arrival = W2F.Arrival or {}

local function dbg(...)
    if W2F.Debug then W2F.Debug(...) end
end

local function requestModelSafe(modelHash, timeoutMs)
    if HasModelLoaded(modelHash) then return true end
    RequestModel(modelHash)
    local deadline = GetGameTimer() + (timeoutMs or 8000)
    while not HasModelLoaded(modelHash) and GetGameTimer() < deadline do
        Wait(50)
    end
    return HasModelLoaded(modelHash)
end

function W2F.Arrival.Prison(ctx, spawnCoords)
    local cfg = (Config.Arrival or {}).prison or {}

    local gateCoords = cfg.spawnCoords or vec4(1846.50, 2586.20, 45.67, 270.0)
    local exitCoords = vec3(1837.20, 2586.20, 45.67)

    dbg('[prison] historia iniciando em %s %s %s', gateCoords.x, gateCoords.y, gateCoords.z)

    local function getSub(key, fallback)
        if type(locale) == 'function' then
            local ok, res = pcall(locale, key)
            if ok and res and res ~= key then return res end
        end
        return fallback
    end

    local subtitles = {
        getSub('story.prison_1', 'A pena foi paga. O portão de aço se abre.'),
        getSub('story.prison_2', 'Cinquenta pratas no bolso, registro civil e um horizonte aberto.'),
        getSub('story.prison_3', 'Bolingbroke ficou para trás. Bem-vindo à liberdade.'),
    }

    CreateThread(function()
        local ped = PlayerPedId()
        local skipped = false
        local cameras = {}
        local prisonBus = nil
        local streamHandle = nil

        local function doSkip()
            if skipped then return end
            skipped = true
            dbg('[prison] jogador pulou a historia de prisao')
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

        local function cleanup()
            for _, cam in ipairs(cameras) do
                if DoesCamExist(cam) then
                    DestroyCam(cam, false)
                end
            end
            cameras = {}
            RenderScriptCams(false, false, 0, true, false)

            if prisonBus and DoesEntityExist(prisonBus) then
                DeleteVehicle(prisonBus)
                prisonBus = nil
            end

            if streamHandle and W2F.Streaming and W2F.Streaming.Release then
                W2F.Streaming.Release(streamHandle)
                streamHandle = nil
            end

            W2F.SendNui('hideArrivalSubtitle', {})
            W2F.SendNui('hideArrivalSkip', {})
            W2F.SendNui('hideCinemaBars', {})
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

        -- 1. Streaming da área da penitenciária
        if W2F.Streaming and W2F.Streaming.Acquire then
            streamHandle = W2F.Streaming.Acquire(vec3(gateCoords.x, gateCoords.y, gateCoords.z), {
                radius = 100.0,
                keepThread = true,
                focus = true,
                scene = false,
            })
        end

        SetEntityVisible(ped, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, gateCoords.x, gateCoords.y, gateCoords.z, false, false, false, false)

        W2F.SendNui('showArrivalSkip', {})
        W2F.SendNui('showCinemaBars', {})

        -- 2. Veículo temático: Ônibus Penitenciário (pbus) na guarita
        local busHash = GetHashKey('pbus')
        local busLoaded = requestModelSafe(busHash, 6000)
        if busLoaded and not skipped then
            prisonBus = CreateVehicle(busHash, 1836.0, 2595.0, 45.67, 270.0, false, false)
            if DoesEntityExist(prisonBus) then
                SetVehicleDoorsLocked(prisonBus, 2)
                SetVehicleLights(prisonBus, 2)
                FreezeEntityPosition(prisonBus, true)
                SetEntityInvincible(prisonBus, true)
            end
            SetModelAsNoLongerNeeded(busHash)
        end

        -- 3. Câmera 1: Plano detalhe no portão de ferro
        local cam1 = createCam(vec3(1853.0, 2589.0, 48.0), vec3(gateCoords.x, gateCoords.y, gateCoords.z + 1.2), 48.0)
        SetCamActive(cam1, true)
        RenderScriptCams(true, false, 0, true, false)

        DoScreenFadeIn(800)
        while not IsScreenFadedIn() do Wait(0) end

        pcall(function()
            PlaySoundFrontend(-1, 'Air_Defenses_Activated', 'DLC_sum20_Business_Hub_Soundset', false)
            PlaySoundFrontend(-1, 'DOOR_BUZZ', 'MP_PLAYER_APARTMENT', false)
        end)

        W2F.SendNui('showArrivalSubtitle', { text = subtitles[1], durationMs = 3500 })

        local timerStart = GetGameTimer()
        while GetGameTimer() - timerStart < 2200 and not skipped do
            Wait(50)
        end

        -- 4. Ped caminha para fora dos portões
        if not skipped then
            SetEntityCoords(ped, gateCoords.x, gateCoords.y, gateCoords.z, false, false, false, false)
            SetEntityHeading(ped, gateCoords.w)
            SetEntityVisible(ped, true, false)
            FreezeEntityPosition(ped, false)
            TaskGoStraightToCoord(ped, exitCoords.x, exitCoords.y, exitCoords.z, 1.0, 5000, gateCoords.w, 0.5)

            local cam2 = createCam(vec3(1830.0, 2578.0, 47.5), vec3(exitCoords.x, exitCoords.y, exitCoords.z + 1.0), 42.0)
            SetCamActiveWithInterp(cam2, cam1, 3500, 1, 1)

            timerStart = GetGameTimer()
            while GetGameTimer() - timerStart < 1500 and not skipped do
                Wait(50)
            end

            if not skipped then
                W2F.SendNui('showArrivalSubtitle', { text = subtitles[2], durationMs = 3500 })

                timerStart = GetGameTimer()
                while GetGameTimer() - timerStart < 2200 and not skipped do
                    Wait(50)
                end

                if not skipped then
                    local cam3 = createCam(vec3(1820.0, 2592.0, 50.0), vec3(exitCoords.x, exitCoords.y, exitCoords.z + 0.8), 45.0)
                    SetCamActiveWithInterp(cam3, cam2, 3000, 1, 1)

                    timerStart = GetGameTimer()
                    while GetGameTimer() - timerStart < 1200 and not skipped do
                        Wait(50)
                    end

                    if not skipped then
                        W2F.SendNui('showArrivalSubtitle', { text = subtitles[3], durationMs = 3000 })
                        timerStart = GetGameTimer()
                        while GetGameTimer() - timerStart < 2400 and not skipped do
                            Wait(50)
                        end
                    end
                end
            end
        end

        -- 5. Fade out e cleanup
        DoScreenFadeOut(800)
        while not IsScreenFadedOut() do Wait(0) end

        cleanup()

        local targetCoords = spawnCoords or vec4(exitCoords.x, exitCoords.y, exitCoords.z, gateCoords.w or 270.0)
        local okGround, safeZ = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, targetCoords.z + 2.0, false)
        if okGround and safeZ > 1.0 then
            targetCoords = vec4(targetCoords.x, targetCoords.y, safeZ, targetCoords.w or 270.0)
        end

        SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
        SetEntityHeading(ped, targetCoords.w or 270.0)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        ClearPedTasks(ped)

        DoScreenFadeIn(600)

        dbg('[prison] historia concluida, entregando para spawn em %s %s %s', targetCoords.x, targetCoords.y, targetCoords.z)
        if ctx and ctx.handBack then
            ctx.handBack(targetCoords)
        end
    end)
end

if W2F.Arrival and W2F.Arrival.Register then
    W2F.Arrival.Register('prison', W2F.Arrival.Prison)
end
