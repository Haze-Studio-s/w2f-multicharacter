--- W2F.Arrival.Prison — História de Chegada: Saída da Penitenciária de Bolingbroke.
---
--- O jogador é libertado pelos portões de aço de Bolingbroke após cumprir pena.
--- Sequência:
---   1. Stream da área da penitenciária (Route 68 / Grand Senora Desert).
---   2. Sirene penitenciária e rangido de portões de ferro.
---   3. Ped caminha para fora dos portões em direção à liberdade no deserto.
---   4. Ônibus penitenciário (pbus) estacionado na guarita.
---   5. Entrega na calçada da Route 68 com R$ 50 de auxílio-soltura do Estado.

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

function W2F.Arrival.Prison(ctx, spawnCoords)
    local cfg = (Config.Arrival or {}).prison or {}

    -- Coordenadas do portão principal de Bolingbroke
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

        -- 1. Streaming da área da penitenciária
        local streamHandle = nil
        if W2F.Streaming and W2F.Streaming.Acquire then
            streamHandle = W2F.Streaming.Acquire(vec3(gateCoords.x, gateCoords.y, gateCoords.z), {
                radius = 100.0,
                keepThread = true,
                focus = true,
                scene = false,
            })
        end

        -- Teleporta ped inicialmente invisível
        SetEntityVisible(ped, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, gateCoords.x, gateCoords.y, gateCoords.z, false, false, false, false)

        -- 2. Veículo temático: Ônibus Penitenciário (pbus) na guarita
        local busHash = GetHashKey('pbus')
        local busLoaded = requestModelSafe(busHash, 6000)
        local prisonBus = nil
        if busLoaded then
            prisonBus = CreateVehicle(busHash, 1836.0, 2595.0, 45.67, 270.0, false, false)
            if DoesEntityExist(prisonBus) then
                SetVehicleDoorsLocked(prisonBus, 2)
                SetVehicleLights(prisonBus, 2)
                FreezeEntityPosition(prisonBus, true)
                SetEntityInvincible(prisonBus, true)
            end
            SetModelAsNoLongerNeeded(busHash)
        end

        -- 3. Câmera 1: Plano detalhe no portão de ferro e cerca de arame farpado
        local cam1Pos = vec3(1853.0, 2589.0, 48.0)
        local cam1 = createLookAtCam(cam1Pos, vec3(gateCoords.x, gateCoords.y, gateCoords.z + 1.2), 48.0)
        SetCamActive(cam1, true)
        RenderScriptCams(true, false, 0, true, false)

        DoScreenFadeIn(800)
        while not IsScreenFadedIn() do Wait(0) end

        -- Efeitos sonoros de portão e alarme distante
        pcall(function()
            PlaySoundFrontend(-1, 'Air_Defenses_Activated', 'DLC_sum20_Business_Hub_Soundset', false)
            PlaySoundFrontend(-1, 'DOOR_BUZZ', 'MP_PLAYER_APARTMENT', false)
        end)

        -- NUI: legenda 1
        W2F.SendNui('showArrivalSubtitle', { text = subtitles[1], durationMs = 3500 })

        Wait(2200)

        -- 4. Ped aparece e caminha para fora dos portões em direção à liberdade
        SetEntityCoords(ped, gateCoords.x, gateCoords.y, gateCoords.z, false, false, false, false)
        SetEntityHeading(ped, gateCoords.w)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)
        TaskGoStraightToCoord(ped, exitCoords.x, exitCoords.y, exitCoords.z, 1.0, 5000, gateCoords.w, 0.5)

        -- Câmera 2: Travelling acompanhando a saída do ped com vista de Bolingbroke
        local cam2Pos = vec3(1830.0, 2578.0, 47.5)
        local cam2 = createLookAtCam(cam2Pos, vec3(exitCoords.x, exitCoords.y, exitCoords.z + 1.0), 42.0)
        SetCamActiveWithInterp(cam2, cam1, 3500, 1, 1)

        Wait(1500)
        W2F.SendNui('showArrivalSubtitle', { text = subtitles[2], durationMs = 3500 })

        Wait(2200)
        destroyCam(cam1)
        SetCamActive(cam2, true)

        -- Câmera 3: Plano aberto do deserto de Grand Senora sob o sol
        local cam3Pos = vec3(1820.0, 2592.0, 50.0)
        local cam3 = createLookAtCam(cam3Pos, vec3(exitCoords.x, exitCoords.y, exitCoords.z + 0.8), 45.0)
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

        if prisonBus and DoesEntityExist(prisonBus) then
            DeleteVehicle(prisonBus)
        end
        if streamHandle and W2F.Streaming and W2F.Streaming.Release then
            W2F.Streaming.Release(streamHandle)
        end

        W2F.SendNui('hideArrivalSubtitle', {})

        -- Posição final na calçada da Route 68 em frente à guarita
        local targetCoords = spawnCoords or vec4(exitCoords.x, exitCoords.y, exitCoords.z, gateCoords.w or 270.0)
        local okGround, safeZ = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, targetCoords.z + 2.0, false)
        if okGround and safeZ > 1.0 then
            targetCoords = vec4(targetCoords.x, targetCoords.y, safeZ, targetCoords.w or 270.0)
        end

        SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
        SetEntityHeading(ped, targetCoords.w or 270.0)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)

        dbg('[prison] historia concluida, entregando para spawn em %s %s %s', targetCoords.x, targetCoords.y, targetCoords.z)
        if ctx and ctx.handBack then
            ctx.handBack(targetCoords)
        end
    end)
end

if W2F.Arrival and W2F.Arrival.Register then
    W2F.Arrival.Register('prison', W2F.Arrival.Prison)
end
