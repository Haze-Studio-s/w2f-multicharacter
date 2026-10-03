--- W2F.Arrival.Container — História de Chegada: Contêiner do Coiote.
---
--- Disponível para personagens com nacionalidade não-"Brasileiro" nem "Americano".
--- Sequência:
---   1. Carrega prop tr_prop_tr_container_01a no porto.
---   2. Carrega prop_ld_container (colisão física sobreposta — invisível).
---   3. Teleporta o ped para o interior do contêiner (escuro, luz por frestas).
---   4. Câmera interior + sons ambientes (metal rangendo, buzina ao longe).
---   5. Animação de abertura das portas (action_container).
---   6. Swap de colisão: prop animado perde colisão → prop_ld_container assume.
---   7. Câmera exterior: clarão de luz + gaivotas + saída do ped.
---   8. ctx.handBack(spawnCoords) — entrega para o fluxo normal de spawn.
---
--- Configuração em Config.Arrival.container (ver config.lua).

--- Garante que o namespace exista
W2F.Arrival = W2F.Arrival or {}

local function dbg(...)
    if W2F.Debug then W2F.Debug(...) end
end

--- Aguarda o modelo carregar com timeout
local function requestModelSafe(modelHash, timeoutMs)
    if not IsModelInCdimage(modelHash) then
        dbg('[container] modelo %s nao encontrado no jogo', modelHash)
        return false
    end
    RequestModel(modelHash)
    local deadline = GetGameTimer() + (timeoutMs or 10000)
    while not HasModelLoaded(modelHash) and GetGameTimer() < deadline do
        Wait(50)
    end
    return HasModelLoaded(modelHash)
end

--- Aguarda animação dicionário carregar
local function requestAnimDict(dict, timeoutMs)
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(50)
    end
    local ok = HasAnimDictLoaded(dict)
    if not ok then
        dbg('[container] animação %s nao carregou, ignorando', dict)
    end
    return ok
end

--- Toca um som com guard pcall
local function playContainerSound(soundDef)
    if not soundDef then return end
    pcall(function()
        PlaySoundFromCoord(-1, soundDef.sound, soundDef.coords or 0.0, soundDef.coords or 0.0, soundDef.coords or 0.0, soundDef.bank or '', false, soundDef.range or 10.0, false)
    end)
end

--- Câmera simples que aponta de uma posição para um ponto alvo
local function createLookAtCam(camPos, lookAt, fov)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    local dx = lookAt.x - camPos.x
    local dy = lookAt.y - camPos.y
    local dz = lookAt.z - camPos.z
    local pitch = math.deg(math.atan(dz, math.sqrt(dx*dx + dy*dy)))
    local yaw   = math.deg(math.atan(-dx, -dy))
    SetCamRot(cam, pitch, 0.0, yaw, 2)
    SetCamFov(cam, fov or 50.0)
    return cam
end

--- Destrói câmera com segurança
local function destroyCam(cam)
    if cam and DoesCamExist(cam) then
        DestroyCam(cam, false)
    end
end

function W2F.Arrival.Container(ctx, spawnCoords)
    local cfg = (Config.Arrival or {}).container or {}

    -- Coordenadas do contêiner no cais do porto marítimo (Terminal / Elysian Island)
    local containerCoords  = cfg.spawnCoords or vec4(428.34, -2992.08, 5.90, 185.0)
    local containerModel   = cfg.model       or 'tr_prop_tr_container_01a'
    local collisionModel   = cfg.collisionProp or 'prop_ld_container'
    local animDict         = cfg.animDict    or 'container@'
    local animClip         = cfg.animClip    or 'action_container'
    local sounds           = cfg.sounds      or {}

    dbg('[container] historia iniciando em %s %s %s', containerCoords.x, containerCoords.y, containerCoords.z)

    local function getSub(key, fallback)
        if type(locale) == 'function' then
            local ok, res = pcall(locale, key)
            if ok and res and res ~= key then return res end
        end
        return fallback
    end

    -- NUI: legendas da história
    local subtitles = {
        getSub('story.container_1', 'O calor sufocante. O som de metal contra metal. Silêncio.'),
        getSub('story.container_2', 'Dias dentro da caixa de aço. Uma promessa de recomeço.'),
        getSub('story.container_3', 'Los Santos. O fim da viagem. O começo de tudo.'),
    }

    CreateThread(function()
        local ped = PlayerPedId()

        -- 1. Stream da área do porto
        local streamHandle = nil
        if W2F.Streaming and W2F.Streaming.Acquire then
            streamHandle = W2F.Streaming.Acquire(vec3(containerCoords.x, containerCoords.y, containerCoords.z), {
                radius = 80.0,
                keepThread = true,
                followCamera = false,
                focus = true,
                scene = false,
            })
        end

        -- Teleporta imediatamente para o porto (ped escondido)
        SetEntityVisible(ped, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, containerCoords.x, containerCoords.y, containerCoords.z + 1.0, false, false, false, false)

        -- 2. Carrega o prop do contêiner (modelo animado)
        local containerHash = GetHashKey(containerModel)
        local containerLoaded = requestModelSafe(containerHash, 12000)

        -- 3. Carrega prop de colisão (invisível)
        local collisionHash = GetHashKey(collisionModel)
        local collisionLoaded = requestModelSafe(collisionHash, 8000)

        local containerProp = nil
        local collisionProp = nil

        if containerLoaded then
            containerProp = CreateObjectNoOffset(containerHash, containerCoords.x, containerCoords.y, containerCoords.z, false, false, false)
            SetEntityHeading(containerProp, containerCoords.w)
            SetEntityVisible(containerProp, true, false)
            FreezeEntityPosition(containerProp, true)
            SetModelAsNoLongerNeeded(containerHash)
            dbg('[container] prop principal criado: %s', containerProp)
        end

        if collisionLoaded then
            collisionProp = CreateObjectNoOffset(collisionHash, containerCoords.x, containerCoords.y, containerCoords.z, false, false, false)
            SetEntityHeading(collisionProp, containerCoords.w)
            SetEntityVisible(collisionProp, false, false)  -- invisível
            FreezeEntityPosition(collisionProp, true)
            SetModelAsNoLongerNeeded(collisionHash)
            dbg('[container] prop de colisao criado: %s', collisionProp)
        end

        -- 4. Posição interior do contêiner (ped dentro, escuro)
        local interiorOffset = cfg.interiorOffset or vec3(0.0, -2.0, 1.2)
        local insidePos = vec3(
            containerCoords.x + interiorOffset.x,
            containerCoords.y + interiorOffset.y,
            containerCoords.z + interiorOffset.z
        )
        SetEntityCoords(ped, insidePos.x, insidePos.y, insidePos.z, false, false, false, false)
        SetEntityHeading(ped, containerCoords.w)
        SetEntityVisible(ped, false, false)  -- ped invisível durante cena
        FreezeEntityPosition(ped, true)
        Wait(300)

        -- 5. Câmera INTERIOR (escuridão, feixes de luz)
        local camInteriorPos = cfg.camInterior or vec3(
            containerCoords.x,
            containerCoords.y - 1.0,
            containerCoords.z + 1.8
        )
        local cam1 = createLookAtCam(camInteriorPos, insidePos, 55.0)
        SetCamActive(cam1, true)
        RenderScriptCams(true, false, 0, true, false)

        -- Revela o interior do contêiner para o jogador
        DoScreenFadeIn(800)
        while not IsScreenFadedIn() do Wait(0) end

        -- NUI: legenda 1 + escuridão
        W2F.SendNui('showArrivalSubtitle', { text = subtitles[1], durationMs = 3500 })
        pcall(function() AnimpostfxPlay('SwitchHUDIn', 0, false) end)

        -- Sons interiores
        local sndInteriorCoords = vec3(insidePos.x, insidePos.y, insidePos.z)
        pcall(function()
            PlaySoundFromCoord(-1, 'METAL_CREAK', sndInteriorCoords.x, sndInteriorCoords.y, sndInteriorCoords.z, 'VEHICLES_HORNS_SOUNDSET', false, 15.0, false)
        end)
        Wait(3500)

        -- NUI: legenda 2
        W2F.SendNui('showArrivalSubtitle', { text = subtitles[2], durationMs = 3000 })

        -- Buzina de navio ao longe
        pcall(function()
            PlaySoundFromCoord(-1, 'PORT_HORN', containerCoords.x, containerCoords.y, containerCoords.z, 'GTAO_RANDOM_EVENTS_SOUNDSET', false, 80.0, false)
        end)
        Wait(3000)

        -- 6. Animação de abertura das portas
        local animDictOk = requestAnimDict(animDict, 5000)
        if containerProp and animDictOk then
            TaskPlayAnimOnEntity(containerProp, animDict, animClip, 1.0, 1.0, -1, 0, 0.0, false, false, false)
            dbg('[container] animacao de abertura iniciada')
        end

        -- Câmera exterior (plano das portas abrindo)
        Wait(200)
        local exteriorOffset = cfg.exteriorOffset or vec3(0.0, 5.5, 2.0)
        local camExteriorPos = vec3(
            containerCoords.x + exteriorOffset.x,
            containerCoords.y + exteriorOffset.y,
            containerCoords.z + exteriorOffset.z
        )
        local cam2 = createLookAtCam(camExteriorPos, vec3(containerCoords.x, containerCoords.y, containerCoords.z + 1.5), 60.0)

        -- Transição suave entre câmeras
        SetCamActiveWithInterp(cam2, cam1, 800, 1, 1)
        Wait(900)
        destroyCam(cam1)
        SetCamActive(cam2, true)

        -- Som de impacto (guindaste pousou + batida)
        Wait(500)
        pcall(function()
            PlaySoundFrontend(-1, 'BOSS_KNOCK', 'GTAO_EXEC_SECUROSERV_NETWORK_SOUNDSET', false)
        end)

        -- Swap de colisão: animado perde, invisível assume
        if containerProp then
            SetEntityCollision(containerProp, false, false)
        end
        if collisionProp then
            SetEntityCollision(collisionProp, true, true)
            SetEntityVisible(collisionProp, false, false)
        end

        -- 7. Portas abrindo — clarão + gaivotas
        Wait(cfg.openPhaseDelayMs or 1800)
        pcall(function() AnimpostfxPlay('DeathFailNeutralIn', 400, false) end)
        pcall(function()
            PlaySoundFrontend(-1, 'SEAGULLS_LOOP', 'ANIMALS_GENERAL_SOUNDSET', false)
        end)

        -- NUI: legenda 3
        W2F.SendNui('showArrivalSubtitle', { text = subtitles[3], durationMs = 3000 })

        -- Ped sai do contêiner (aparece caminhando)
        local exitCoords = cfg.exitOffset and vec3(
            containerCoords.x + cfg.exitOffset.x,
            containerCoords.y + cfg.exitOffset.y,
            containerCoords.z + cfg.exitOffset.z
        ) or vec3(containerCoords.x, containerCoords.y + 4.0, containerCoords.z)

        SetEntityCoords(ped, insidePos.x, insidePos.y, insidePos.z, false, false, false, false)
        SetEntityHeading(ped, containerCoords.w)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)
        TaskGoStraightToCoord(ped, exitCoords.x, exitCoords.y, exitCoords.z, 1.0, 4000, containerCoords.w, 0.5)

        Wait(3000)

        -- 8. Câmera exterior final (porto de Los Santos)
        local cam3FarPos = vec3(
            containerCoords.x - 4.0,
            containerCoords.y + 12.0,
            containerCoords.z + 5.0
        )
        local cam3 = createLookAtCam(cam3FarPos, vec3(exitCoords.x, exitCoords.y, exitCoords.z + 1.0), 40.0)
        SetCamActiveWithInterp(cam3, cam2, 1200, 1, 1)
        Wait(1400)
        destroyCam(cam2)
        SetCamActive(cam3, true)

        -- Buzina ao longe (saída)
        pcall(function()
            PlaySoundFromCoord(-1, 'PORT_HORN', containerCoords.x, containerCoords.y, containerCoords.z, 'GTAO_RANDOM_EVENTS_SOUNDSET', false, 80.0, false)
        end)

        Wait(2500)

        -- 9. Fade out + cleanup
        DoScreenFadeOut(800)
        while not IsScreenFadedOut() do Wait(0) end

        -- Cleanup props
        destroyCam(cam3)
        RenderScriptCams(false, false, 0, true, false)
        if containerProp then DeleteObject(containerProp) end
        if collisionProp then DeleteObject(collisionProp) end
        if streamHandle and W2F.Streaming and W2F.Streaming.Release then
            W2F.Streaming.Release(streamHandle)
        end
        pcall(function() RemoveAnimDict(animDict) end)

        -- NUI: ocultar legendas
        W2F.SendNui('hideArrivalSubtitle', {})
        pcall(function() AnimpostfxStopAll() end)

        -- Define coordenadas seguras de destino final
        local targetCoords = spawnCoords or vec4(exitCoords.x, exitCoords.y, exitCoords.z, containerCoords.w or 0.0)

        dbg('[container] historia concluida, entregando para spawn em %s %s %s', targetCoords.x, targetCoords.y, targetCoords.z)

        -- Teleporta para os coords de spawn reais
        SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
        SetEntityHeading(ped, targetCoords.w or 0.0)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)

        -- Entrega o controle mantendo a tela em fade para o spawner/creator fazer a transição final limpa
        if ctx and ctx.handBack then
            ctx.handBack(targetCoords)
        end
    end)
end

