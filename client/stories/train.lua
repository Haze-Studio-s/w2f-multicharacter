--- W2F.Arrival.Train — História de Chegada: Trem de Carga Clandestino.
---
--- O jogador chega a Los Santos como passageiro clandestino pegando carona
--- em um vagão aberto de trem de carga que para no pátio ferroviário de Davis.
--- Sequência:
---   1. Stream da área da ferrovia de Davis / Rancho.
---   2. Áudio de buzina de trem e freios de aço rangendo nos trilhos.
---   3. Ped pula da plataforma do vagão nos trilhos industriais.
---   4. Câmera revela a malha ferroviária e os galpões da zona industrial.
---   5. Entrega na calçada da estação de Davis com kit de sobrevivência e R$ 20.

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

local function createLookAtCam(fromCoords, targetCoords, fov)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, fromCoords.x, fromCoords.y, fromCoords.z)
    PointCamAtCoord(cam, targetCoords.x, targetCoords.y, targetCoords.z)
    SetCamFov(cam, fov or 50.0)
    return cam
end

local function destroyCam(cam)
    if cam and DoesCamExist(cam) then
        DestroyCam(cam, false)
    end
end

function W2F.Arrival.Train(ctx, spawnCoords)
    local cfg = (Config.Arrival or {}).train or {}

    -- Coordenadas do pátio ferroviário de Davis / Strawberry
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

        -- 1. Streaming da área da ferrovia
        local streamHandle = nil
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

        -- 2. Prop de carga ferroviária nos trilhos
        local freightHash = GetHashKey('prop_container_05a')
        local freightLoaded = requestModelSafe(freightHash, 6000)
        local freightProp = nil
        if freightLoaded then
            freightProp = CreateObjectNoOffset(freightHash, trainCoords.x, trainCoords.y, trainCoords.z - 0.2, false, false, false)
            if DoesEntityExist(freightProp) then
                SetEntityHeading(freightProp, trainCoords.w)
                FreezeEntityPosition(freightProp, true)
            end
            SetModelAsNoLongerNeeded(freightHash)
        end

        -- 3. Câmera 1: Rente aos trilhos com visão baixa da plataforma
        local cam1Pos = vec3(trainCoords.x - 4.5, trainCoords.y - 6.0, trainCoords.z + 1.2)
        local cam1 = createLookAtCam(cam1Pos, vec3(trainCoords.x, trainCoords.y, trainCoords.z + 1.5), 52.0)
        SetCamActive(cam1, true)
        RenderScriptCams(true, false, 0, true, false)

        DoScreenFadeIn(800)
        while not IsScreenFadedIn() do Wait(0) end

        -- Efeito sonoro de buzina de trem e freios
        pcall(function()
            PlaySoundFrontend(-1, 'TRAIN_HORN', 'EXT_HORN_SOUNDSET', false)
            PlaySoundFrontend(-1, 'Air_Defenses_Activated', 'DLC_sum20_Business_Hub_Soundset', false)
        end)

        -- NUI: legenda 1
        W2F.SendNui('showArrivalSubtitle', { text = subtitles[1], durationMs = 3500 })

        Wait(2200)

        -- 4. Ped desce do vagão e caminha para a calçada da estação
        SetEntityCoords(ped, trainCoords.x, trainCoords.y + 1.5, trainCoords.z, false, false, false, false)
        SetEntityHeading(ped, trainCoords.w)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)
        TaskGoStraightToCoord(ped, exitCoords.x, exitCoords.y, exitCoords.z, 1.0, 4500, trainCoords.w, 0.5)

        -- Câmera 2: Travelling lateral subindo acompanhando os galpões industriais
        local cam2Pos = vec3(trainCoords.x + 8.0, trainCoords.y + 2.0, trainCoords.z + 4.5)
        local cam2 = createLookAtCam(cam2Pos, vec3(exitCoords.x, exitCoords.y, exitCoords.z + 1.0), 45.0)
        SetCamActiveWithInterp(cam2, cam1, 3500, 1, 1)

        Wait(1400)
        W2F.SendNui('showArrivalSubtitle', { text = subtitles[2], durationMs = 3500 })

        Wait(2200)
        destroyCam(cam1)
        SetCamActive(cam2, true)

        -- Câmera 3: Plano médio na saída da ferrovia para as ruas de Davis
        local cam3Pos = vec3(exitCoords.x - 3.5, exitCoords.y + 6.0, exitCoords.z + 3.0)
        local cam3 = createLookAtCam(cam3Pos, vec3(exitCoords.x, exitCoords.y, exitCoords.z + 1.0), 42.0)
        SetCamActiveWithInterp(cam3, cam2, 3000, 1, 1)

        Wait(1200)
        W2F.SendNui('showArrivalSubtitle', { text = subtitles[3], durationMs = 3000 })
        Wait(2400)

        -- 5. Fade out e cleanup
        DoScreenFadeOut(800)
        while not IsScreenFadedOut() do Wait(0) end

        destroyCam(cam2)
        destroyCam(cam3)
        RenderScriptCams(false, false, 0, true, false)

        if freightProp and DoesEntityExist(freightProp) then
            DeleteObject(freightProp)
        end
        if streamHandle and W2F.Streaming and W2F.Streaming.Release then
            W2F.Streaming.Release(streamHandle)
        end

        W2F.SendNui('hideArrivalSubtitle', {})

        -- Posição final segura na calçada da estação ferroviária de Davis
        local targetCoords = spawnCoords or vec4(exitCoords.x, exitCoords.y, exitCoords.z, trainCoords.w or 90.0)
        local okGround, safeZ = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, targetCoords.z + 2.0, false)
        if okGround and safeZ > 1.0 then
            targetCoords = vec4(targetCoords.x, targetCoords.y, safeZ, targetCoords.w or 90.0)
        end

        SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
        SetEntityHeading(ped, targetCoords.w or 90.0)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)

        dbg('[train] historia concluida, entregando para spawn em %s %s %s', targetCoords.x, targetCoords.y, targetCoords.z)
        if ctx and ctx.handBack then
            ctx.handBack(targetCoords)
        end
    end)
end

if W2F.Arrival and W2F.Arrival.Register then
    W2F.Arrival.Register('train', W2F.Arrival.Train)
end
