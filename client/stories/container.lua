--- W2F.Arrival.Container — História de Chegada: Contêiner do Coiote (Fiel ao MRI Brasil).
---
--- Referência visual e narrativa: MRI Brasil (YouTube: BvDAXO483BQ @ 5:18).
--- Sequência:
---   1. Stream da área do cais do porto.
---   2. Props tr_prop_tr_container_01a (animado) e prop_ld_container (colisão física).
---   3. Ped do jogador sentado no chão segurando a cabeça em desespero profundo (flinch_loop).
---   4. 2 NPCs acompanhantes clandestinos sentados ao lado dentro do contêiner.
---   5. Letterbox de cinema permanente + botão [ENTER] PULAR ativo no canto inferior.
---   6. Câmera interna mostrando o desalento com iluminação sombria.
---   7. Legendas sincronizadas:
---      - "Vinte e três dias no escuro."
---      - "Ele prometeu trabalho. Cobrou adiantado."
---   8. 3 batidas pesadas na porta de ferro pelo lado de fora (BOSS_KNOCK).
---   9. Trava estala (DOOR_BUZZ) e portas abrem devagar (action_container).
---  10. Clarão de luz solar invade o contêiner + som de gaivotas.
---  11. Legenda: "Bem-vindo a Los Santos."
---  12. Câmera frontal no exterior: o jogador se levanta e caminha para a luz do cais.
---  13. Os 2 clandestinos também se levantam e saem andando para lados opostos.
---  14. Legenda: "Agora você deve."
---  15. Transição suave de câmera para 3ª pessoa de gameplay e liberação dos controles.
---  16. Suporte completo a skip ([ENTER] PULAR) a qualquer instante sem travamentos.

W2F.Arrival = W2F.Arrival or {}

local function dbg(...)
    if W2F.Debug then W2F.Debug(...) end
end

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

local function requestAnimDict(dict, timeoutMs)
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeoutMs or 6000)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(50)
    end
    return HasAnimDictLoaded(dict)
end

local function createLookAtCam(camPos, lookAt, fov)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)
    SetCamFov(cam, fov or 55.0)
    return cam
end

local function destroyCam(cam)
    if cam and DoesCamExist(cam) then
        DestroyCam(cam, false)
    end
end

function W2F.Arrival.Container(ctx, spawnCoords)
    local cfg = (Config.Arrival or {}).container or {}

    local containerModel = cfg.model          or 'tr_prop_tr_container_01a'
    local collisionModel = cfg.collisionProp  or 'prop_ld_container'
    local containerCoords = cfg.spawnCoords   or vec4(428.34, -3005.00, 5.90, 180.0)
    local animDict        = cfg.animDict       or 'container@'
    local animClip        = cfg.animClip       or 'action_container'

    dbg('[container] iniciando historia estilo MRI em %s %s %s', containerCoords.x, containerCoords.y, containerCoords.z)

    local function getSub(key, fallback)
        if type(locale) == 'function' then
            local ok, res = pcall(locale, key)
            if ok and res and res ~= key then return res end
        end
        return fallback
    end

    local subtitles = {
        getSub('story.container_1', 'Vinte e três dias no escuro.'),
        getSub('story.container_2', 'Ele prometeu trabalho. Cobrou adiantado.'),
        getSub('story.container_3', 'Bem-vindo a Los Santos.'),
        getSub('story.container_4', 'Agora você deve.'),
    }

    CreateThread(function()
        local ped = PlayerPedId()

        -- Flag de controle de skip
        local skipped = false
        local containerProp = nil
        local collisionProp = nil
        local npc1 = nil
        local npc2 = nil
        local cam1 = nil
        local cam2 = nil
        local cam3 = nil
        local streamHandle = nil

        local function doSkip()
            if skipped then return end
            skipped = true
            dbg('[container] jogador pulou a cinematica')
        end

        -- Registra callback NUI para pular a cutscene
        RegisterNUICallback('skipArrivalStory', function(data, cb)
            doSkip()
            if cb then cb('ok') end
        end)

        -- 1. Stream da área do porto
        if W2F.Streaming and W2F.Streaming.Acquire then
            streamHandle = W2F.Streaming.Acquire(vec3(containerCoords.x, containerCoords.y, containerCoords.z), {
                radius = 120.0,
                keepThread = true,
                focus = true,
                scene = false,
            })
        end

        -- Esconde o ped enquanto cria o cenário
        SetEntityVisible(ped, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, containerCoords.x, containerCoords.y, containerCoords.z + 1.0, false, false, false, false)

        -- 2. Carrega modelos dos props
        local containerHash = GetHashKey(containerModel)
        local containerLoaded = requestModelSafe(containerHash, 12000)
        local collisionHash = GetHashKey(collisionModel)
        local collisionLoaded = requestModelSafe(collisionHash, 8000)

        if containerLoaded then
            containerProp = CreateObjectNoOffset(containerHash, containerCoords.x, containerCoords.y, containerCoords.z, false, false, false)
            SetEntityHeading(containerProp, containerCoords.w)
            SetEntityVisible(containerProp, true, false)
            FreezeEntityPosition(containerProp, true)
            SetModelAsNoLongerNeeded(containerHash)
        end

        if collisionLoaded then
            collisionProp = CreateObjectNoOffset(collisionHash, containerCoords.x, containerCoords.y, containerCoords.z, false, false, false)
            SetEntityHeading(collisionProp, containerCoords.w)
            SetEntityVisible(collisionProp, false, false)
            FreezeEntityPosition(collisionProp, true)
            SetModelAsNoLongerNeeded(collisionHash)
        end

        -- 3. Carrega animações de desespero e modelos dos 2 companheiros de contêiner
        local hostageDict = 'anim@heists@ornate_bank@hostages@ped_c@'
        local hostageDictOk = requestAnimDict(hostageDict, 6000)

        local npc1Model = GetHashKey('a_m_y_latino_01')
        local npc2Model = GetHashKey('a_m_m_tramp_01')
        requestModelSafe(npc1Model, 6000)
        requestModelSafe(npc2Model, 6000)

        -- Posições relativas dentro do contêiner
        local playerInside = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.0, -1.6, 0.05)
            or vec3(containerCoords.x, containerCoords.y - 1.6, containerCoords.z + 0.05)
        local npc1Pos = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, -0.75, -2.4, 0.05)
            or vec3(containerCoords.x - 0.75, containerCoords.y - 2.4, containerCoords.z + 0.05)
        local npc2Pos = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.75, -2.4, 0.05)
            or vec3(containerCoords.x + 0.75, containerCoords.y - 2.4, containerCoords.z + 0.05)

        -- Posiciona o jogador sentado no chão com as mãos na cabeça em desespero
        SetEntityCoords(ped, playerInside.x, playerInside.y, playerInside.z, false, false, false, false)
        SetEntityHeading(ped, containerCoords.w)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)

        if hostageDictOk then
            TaskPlayAnim(ped, hostageDict, 'flinch_loop', 8.0, -8.0, -1, 1, 0.0, false, false, false)
        end

        -- Cria NPC 1 (companheiro à esquerda)
        if HasModelLoaded(npc1Model) then
            npc1 = CreatePed(4, npc1Model, npc1Pos.x, npc1Pos.y, npc1Pos.z, containerCoords.w + 20.0, false, false)
            if DoesEntityExist(npc1) then
                SetEntityInvincible(npc1, true)
                SetBlockingOfNonTemporaryEvents(npc1, true)
                FreezeEntityPosition(npc1, true)
                if hostageDictOk then
                    TaskPlayAnim(npc1, hostageDict, 'flinch_loop', 8.0, -8.0, -1, 1, 0.0, false, false, false)
                end
            end
            SetModelAsNoLongerNeeded(npc1Model)
        end

        -- Cria NPC 2 (companheiro à direita)
        if HasModelLoaded(npc2Model) then
            npc2 = CreatePed(4, npc2Model, npc2Pos.x, npc2Pos.y, npc2Pos.z, containerCoords.w - 20.0, false, false)
            if DoesEntityExist(npc2) then
                SetEntityInvincible(npc2, true)
                SetBlockingOfNonTemporaryEvents(npc2, true)
                FreezeEntityPosition(npc2, true)
                if hostageDictOk then
                    TaskPlayAnim(npc2, hostageDict, 'flinch_loop', 8.0, -8.0, -1, 1, 0.0, false, false, false)
                end
            end
            SetModelAsNoLongerNeeded(npc2Model)
        end

        -- 4. Câmera INTERIOR 1 (Close dramático no jogador sentado e nos companheiros)
        local cam1Pos = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.15, -0.5, 0.72)
            or vec3(containerCoords.x + 0.15, containerCoords.y - 0.5, containerCoords.z + 0.72)
        local cam1Look = vec3(playerInside.x, playerInside.y, playerInside.z + 0.35)
        cam1 = createLookAtCam(cam1Pos, cam1Look, 48.0)
        SetCamActive(cam1, true)
        RenderScriptCams(true, false, 0, true, false)

        -- Ativa as barras de cinema e o botão de skip no NUI
        W2F.SendNui('showCinemaBars', {})
        W2F.SendNui('showArrivalSkip', {})

        -- Fade in na escuridão do contêiner
        DoScreenFadeIn(900)
        while not IsScreenFadedIn() do Wait(0) end

        -- Som ambiente de metal rangendo no interior
        pcall(function()
            PlaySoundFromCoord(-1, 'METAL_CREAK', playerInside.x, playerInside.y, playerInside.z, 'VEHICLES_HORNS_SOUNDSET', false, 20.0, false)
        end)

        -- Legenda 1: "Vinte e três dias no escuro."
        W2F.SendNui('showArrivalSubtitle', { text = subtitles[1], durationMs = 3500 })

        -- Loop de espera responsivo com verificação de [ENTER]
        local timerEnd = GetGameTimer() + 3500
        while GetGameTimer() < timerEnd and not skipped do
            if IsControlJustReleased(0, 191) or IsControlJustReleased(0, 201) then doSkip() break end
            Wait(0)
        end

        if not skipped then
            -- Som de buzina de navio ao longe
            pcall(function()
                PlaySoundFromCoord(-1, 'PORT_HORN', containerCoords.x, containerCoords.y, containerCoords.z, 'GTAO_RANDOM_EVENTS_SOUNDSET', false, 80.0, false)
            end)

            -- Legenda 2: "Ele prometeu trabalho. Cobrou adiantado."
            W2F.SendNui('showArrivalSubtitle', { text = subtitles[2], durationMs = 3500 })

            timerEnd = GetGameTimer() + 3500
            while GetGameTimer() < timerEnd and not skipped do
                if IsControlJustReleased(0, 191) or IsControlJustReleased(0, 201) then doSkip() break end
                Wait(0)
            end
        end

        -- 5. Batidas pesadas do coiote pelo lado de fora
        if not skipped then
            pcall(function() PlaySoundFrontend(-1, 'BOSS_KNOCK', 'GTAO_EXEC_SECUROSERV_NETWORK_SOUNDSET', false) end)
            Wait(350)
            pcall(function() PlaySoundFrontend(-1, 'BOSS_KNOCK', 'GTAO_EXEC_SECUROSERV_NETWORK_SOUNDSET', false) end)
            Wait(350)
            pcall(function() PlaySoundFrontend(-1, 'BOSS_KNOCK', 'GTAO_EXEC_SECUROSERV_NETWORK_SOUNDSET', false) end)
            Wait(350)

            -- Trava estala
            pcall(function()
                PlaySoundFrontend(-1, 'DOOR_BUZZ', 'MP_PLAYER_APARTMENT', false)
            end)

            -- 6. Animação de abertura das portas do contêiner
            local animDictOk = requestAnimDict(animDict, 4000)
            if containerProp and animDictOk then
                TaskPlayAnimOnEntity(containerProp, animDict, animClip, 1.0, 1.0, -1, 0, 0.0, false, false, false)
            end

            -- Câmera exterior de frente para o contêiner (como nos Frames 15 e 20 do MRI)
            local cam2Pos = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.0, 6.4, 1.4)
                or vec3(containerCoords.x, containerCoords.y + 6.4, containerCoords.z + 1.4)
            local cam2Look = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.0, 0.2, 1.1)
                or vec3(containerCoords.x, containerCoords.y, containerCoords.z + 1.1)
            cam2 = createLookAtCam(cam2Pos, cam2Look, 52.0)

            -- Transição suave da câmera interior para a câmera exterior
            SetCamActiveWithInterp(cam2, cam1, 700, 1, 1)
            Wait(750)
            destroyCam(cam1)
            SetCamActive(cam2, true)

            -- Swap de colisão
            if containerProp then SetEntityCollision(containerProp, false, false) end
            if collisionProp then
                SetEntityCollision(collisionProp, true, true)
                SetEntityVisible(collisionProp, false, false)
            end

            -- Clarão solar + gaivotas
            pcall(function() AnimpostfxPlay('DeathFailNeutralIn', 450, false) end)
            pcall(function()
                PlaySoundFrontend(-1, 'SEAGULLS_LOOP', 'ANIMALS_GENERAL_SOUNDSET', false)
            end)

            -- Legenda 3: "Bem-vindo a Los Santos."
            W2F.SendNui('showArrivalSubtitle', { text = subtitles[3], durationMs = 3500 })

            -- 7. Personagens se levantam e caminham para fora do contêiner
            local exitDist = (cfg.exitOffset and cfg.exitOffset.y) or 4.5
            local exitCoords = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.0, exitDist, 0.0)
                or vec3(containerCoords.x, containerCoords.y + exitDist, containerCoords.z)

            -- Solo seguro garantido
            local okGround, safeZ = GetGroundZFor_3dCoord(exitCoords.x, exitCoords.y, exitCoords.z + 2.0, false)
            if okGround and safeZ > 1.0 then
                exitCoords = vec3(exitCoords.x, exitCoords.y, safeZ)
            end

            -- Ped do jogador se levanta e caminha para a frente rumo ao cais
            ClearPedTasks(ped)
            FreezeEntityPosition(ped, false)
            TaskGoStraightToCoord(ped, exitCoords.x, exitCoords.y, exitCoords.z, 1.0, 7000, containerCoords.w, 0.5)

            -- NPCs companheiros também se levantam e caminham para lados opostos
            if npc1 and DoesEntityExist(npc1) then
                ClearPedTasks(npc1)
                FreezeEntityPosition(npc1, false)
                local npc1Exit = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, -2.8, exitDist + 3.0, 0.0)
                    or vec3(exitCoords.x - 2.8, exitCoords.y + 3.0, exitCoords.z)
                TaskGoStraightToCoord(npc1, npc1Exit.x, npc1Exit.y, npc1Exit.z, 1.0, 7000, containerCoords.w, 0.5)
            end

            if npc2 and DoesEntityExist(npc2) then
                ClearPedTasks(npc2)
                FreezeEntityPosition(npc2, false)
                local npc2Exit = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 2.8, exitDist + 3.0, 0.0)
                    or vec3(exitCoords.x + 2.8, exitCoords.y + 3.0, exitCoords.z)
                TaskGoStraightToCoord(npc2, npc2Exit.x, npc2Exit.y, npc2Exit.z, 1.0, 7000, containerCoords.w, 0.5)
            end

            Wait(1800)

            -- Legenda 4: "Agora você deve."
            W2F.SendNui('showArrivalSubtitle', { text = subtitles[4], durationMs = 3500 })

            -- 8. Câmera 3: Pull back suave acompanhando o personagem do lado de fora
            local cam3Pos = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, -1.8, 10.5, 3.2)
                or vec3(containerCoords.x - 1.8, containerCoords.y + 10.5, containerCoords.z + 3.2)
            cam3 = createLookAtCam(cam3Pos, vec3(exitCoords.x, exitCoords.y, exitCoords.z + 0.9), 45.0)
            SetCamActiveWithInterp(cam3, cam2, 2200, 1, 1)

            timerEnd = GetGameTimer() + 3200
            while GetGameTimer() < timerEnd and not skipped do
                if IsControlJustReleased(0, 191) or IsControlJustReleased(0, 201) then doSkip() break end
                Wait(0)
            end

            destroyCam(cam2)
            SetCamActive(cam3, true)
        end

        -- =========================================================================
        -- FINALIZAÇÃO / CLEANUP / TRANSIÇÃO PARA GAMEPLAY
        -- =========================================================================
        -- Se o jogador pulou, faz fade out rápido para ocultar o cleanup
        if skipped then
            DoScreenFadeOut(300)
            while not IsScreenFadedOut() do Wait(0) end
        end

        -- Oculta UI de cinema
        W2F.SendNui('hideArrivalSubtitle', {})
        W2F.SendNui('hideArrivalSkip', {})
        W2F.SendNui('hideCinemaBars', {})
        pcall(function() AnimpostfxStopAll() end)

        -- Destrói câmeras
        destroyCam(cam1)
        destroyCam(cam2)
        destroyCam(cam3)
        RenderScriptCams(false, not skipped, 1000, true, false)

        -- Deleta props temporários
        if containerProp and DoesEntityExist(containerProp) then DeleteObject(containerProp) end
        if collisionProp and DoesEntityExist(collisionProp) then DeleteObject(collisionProp) end

        -- Libera NPCs companheiros para vagarem e serem despawnados pelo engine
        if npc1 and DoesEntityExist(npc1) then
            SetPedAsNoLongerNeeded(npc1)
        end
        if npc2 and DoesEntityExist(npc2) then
            SetPedAsNoLongerNeeded(npc2)
        end

        if streamHandle and W2F.Streaming and W2F.Streaming.Release then
            W2F.Streaming.Release(streamHandle)
        end
        pcall(function() RemoveAnimDict(animDict) end)
        pcall(function() RemoveAnimDict(hostageDict) end)

        -- Coordenadas de destino final firme no cais do porto
        local rad = math.rad(containerCoords.w or 0.0)
        local fwdX = -math.sin(rad)
        local fwdY = math.cos(rad)
        local finalDist = (cfg.exitOffset and cfg.exitOffset.y) or 4.5
        local targetCoords = vec4(containerCoords.x + (fwdX * finalDist), containerCoords.y + (fwdY * finalDist), containerCoords.z, containerCoords.w or 180.0)

        local okGround, safeZ = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, targetCoords.z + 2.0, false)
        if okGround and safeZ > 1.0 then
            targetCoords = vec4(targetCoords.x, targetCoords.y, safeZ, targetCoords.w)
        end

        SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
        SetEntityHeading(ped, targetCoords.w)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, false)
        ClearPedTasks(ped)

        if skipped then
            DoScreenFadeIn(500)
        end

        dbg('[container] historia concluida, entregando para spawn em %s %s %s', targetCoords.x, targetCoords.y, targetCoords.z)
        if ctx and ctx.handBack then
            ctx.handBack(targetCoords)
        end
    end)
end

if W2F.Arrival and W2F.Arrival.Register then
    W2F.Arrival.Register('container', W2F.Arrival.Container)
end
