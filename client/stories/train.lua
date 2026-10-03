--- W2F.Arrival.Train — História de Chegada: Trem de Carga Clandestino.
---
--- O jogador chega a Los Santos como clandestino em um vagão de carga
--- parando no pátio ferroviário de Davis.
--- Protegido com skip universal, controle de câmeras, ciclo de vida de props e cleanup.

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

function W2F.Arrival.Train(ctx, spawnCoords)
    local cfg = (Config.Arrival or {}).train or {}

    local trainCoords = cfg.spawnCoords or vec4(264.00, -1205.00, 29.28, 90.0)
    local exitCoords  = vec3(264.00, -1198.00, 29.28)

    dbg('[train] historia iniciando em %s %s %s', trainCoords.x, trainCoords.y, trainCoords.z)

    local function getSub(key, fallback)
        if type(locale) == 'function' then
            local ok, res = pcall(locale, key)
            if ok and res and res ~= key then return res end
        end
        return fallback
    end

    local subtitles = {
        getSub('story.train_1', 'O ranger do aço nos trilhos. O apito da locomotiva na madrugada.'),
        getSub('story.train_2', 'Sem documentos, vinte pratas no bolso e carvão nas mãos.'),
        getSub('story.train_3', 'Os trilhos te trouxeram a Los Santos. A linha termina aqui.'),
    }

    CreateThread(function()
        local ped = PlayerPedId()
        local skipped = false
        local cameras = {}
        local freightProp = nil
        local streamHandle = nil

        local function doSkip()
            if skipped then return end
            skipped = true
            dbg('[train] jogador pulou a historia de trem')
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

            if freightProp and DoesEntityExist(freightProp) then
                DeleteObject(freightProp)
                freightProp = nil
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

        -- 1. Streaming da área da ferrovia
        if W2F.Streaming and W2F.Streaming.Acquire then
            streamHandle = W2F.Streaming.Acquire(vec3(trainCoords.x, trainCoords.y, trainCoords.z), {
                radius = 100.0,
                keepThread = true,
                focus = true,
                scene = false,
            })
        end

        SetEntityVisible(ped, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, trainCoords.x, trainCoords.y, trainCoords.z, false, false, false, false)

        W2F.SendNui('showArrivalSkip', {})
        W2F.SendNui('showCinemaBars', {})

        -- 2. Prop de carga ferroviária nos trilhos
        local freightHash = GetHashKey('prop_container_05a')
        local freightLoaded = requestModelSafe(freightHash, 6000)
        if freightLoaded and not skipped then
            freightProp = CreateObjectNoOffset(freightHash, trainCoords.x, trainCoords.y, trainCoords.z - 0.2, false, false, false)
            if DoesEntityExist(freightProp) then
                SetEntityHeading(freightProp, trainCoords.w)
                FreezeEntityPosition(freightProp, true)
            end
            SetModelAsNoLongerNeeded(freightHash)
        end

        -- 3. Câmera 1: Rente aos trilhos
        local cam1 = createCam(vec3(trainCoords.x - 4.5, trainCoords.y - 6.0, trainCoords.z + 1.2), vec3(trainCoords.x, trainCoords.y, trainCoords.z + 1.5), 52.0)
        SetCamActive(cam1, true)
        RenderScriptCams(true, false, 0, true, false)

        DoScreenFadeIn(800)
        while not IsScreenFadedIn() do Wait(0) end

        pcall(function()
            PlaySoundFrontend(-1, 'TRAIN_HORN', 'EXT_HORN_SOUNDSET', false)
            PlaySoundFrontend(-1, 'Air_Defenses_Activated', 'DLC_sum20_Business_Hub_Soundset', false)
        end)

        W2F.SendNui('showArrivalSubtitle', { text = subtitles[1], durationMs = 3500 })

        local timerStart = GetGameTimer()
        while GetGameTimer() - timerStart < 2200 and not skipped do
            Wait(50)
        end

        -- 4. Ped desce do vagão e caminha para a calçada da estação
        if not skipped then
            SetEntityCoords(ped, trainCoords.x, trainCoords.y + 1.5, trainCoords.z, false, false, false, false)
            SetEntityHeading(ped, trainCoords.w)
            SetEntityVisible(ped, true, false)
            FreezeEntityPosition(ped, false)
            TaskGoStraightToCoord(ped, exitCoords.x, exitCoords.y, exitCoords.z, 1.0, 4500, trainCoords.w, 0.5)

            local cam2 = createCam(vec3(trainCoords.x + 8.0, trainCoords.y + 2.0, trainCoords.z + 4.5), vec3(exitCoords.x, exitCoords.y, exitCoords.z + 1.0), 45.0)
            SetCamActiveWithInterp(cam2, cam1, 3500, 1, 1)

            timerStart = GetGameTimer()
            while GetGameTimer() - timerStart < 1400 and not skipped do
                Wait(50)
            end

            if not skipped then
                W2F.SendNui('showArrivalSubtitle', { text = subtitles[2], durationMs = 3500 })

                timerStart = GetGameTimer()
                while GetGameTimer() - timerStart < 2200 and not skipped do
                    Wait(50)
                end

                if not skipped then
                    local cam3 = createCam(vec3(exitCoords.x - 3.5, exitCoords.y + 6.0, exitCoords.z + 3.0), vec3(exitCoords.x, exitCoords.y, exitCoords.z + 1.0), 42.0)
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

        local targetCoords = spawnCoords or vec4(exitCoords.x, exitCoords.y, exitCoords.z, trainCoords.w or 90.0)
        local okGround, safeZ = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, targetCoords.z + 2.0, false)
        if okGround and safeZ > 1.0 then
            targetCoords = vec4(targetCoords.x, targetCoords.y, safeZ, targetCoords.w or 90.0)
        end

        SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
        SetEntityHeading(ped, targetCoords.w or 90.0)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        ClearPedTasks(ped)

        DoScreenFadeIn(600)

        dbg('[train] historia concluida, entregando para spawn em %s %s %s', targetCoords.x, targetCoords.y, targetCoords.z)
        if ctx and ctx.handBack then
            ctx.handBack(targetCoords)
        end
    end)
end

if W2F.Arrival and W2F.Arrival.Register then
    W2F.Arrival.Register('train', W2F.Arrival.Train)
end
