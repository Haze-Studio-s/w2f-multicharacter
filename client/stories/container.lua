--- W2F.Arrival.Container — História de Chegada: Contêiner do Coiote
---
--- Engenharia reversa e fusão 1:1 do mri_Qmultichar (v1.4.0 / YouTube @ 5:18).
--- Destaques técnicos:
---   1. Cena Sincronizada (CreateSynchronizedScene): portas seguras no frame 0.0 e pulo direto para 0.66.
---   2. Feixes de Luz Volumétrica (DrawSpotLight): raios quentes de sol passando pelas frestas das portas no escuro.
---   3. Tranco do Guindaste: LARGE_EXPLOSION_SHAKE + som de impacto (Container_Impact_Land) + sobressalto (flinch).
---   4. Animações Encadeadas: cower no chão, sobressalto com o tranco, e OpenSequenceTask com 'exit' ao levantar.
---   5. Paisagem Sonora GTA Nativa: áudio submarino H4, estalos de guindaste, buzina de cargueiro e gaivotas.
---   6. Destino Seguro no Pátio do Porto: portas abrem em direção ao Norte (longe da água).
---   7. Suporte Integral a Skip ([ENTER] PULAR).

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
    SetCamFov(cam, fov or 52.0)
    return cam
end

local function destroyCam(cam)
    if cam and DoesCamExist(cam) then
        DestroyCam(cam, false)
    end
end

-- Tabela de animações para postura encolhida / susto / levantar (estilo MRI)
local COWER = {
    male = {
        base = 'amb@code_human_cower@male@base',
        scared = 'amb@code_human_cower@male@idle_a',
        exit = 'amb@code_human_cower@male@exit',
    },
    female = {
        base = 'amb@code_human_cower@female@base',
        scared = 'amb@code_human_cower@female@idle_a',
        exit = 'amb@code_human_cower@female@exit',
    },
}

local function getCowerSet(ped)
    return IsPedMale(ped) and COWER.male or COWER.female
end

local function playCower(ped)
    local set = getCowerSet(ped)
    if requestAnimDict(set.base, 4000) then
        TaskPlayAnim(ped, set.base, 'base', 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

local function playFlinch(ped)
    local set = getCowerSet(ped)
    if requestAnimDict(set.scared, 4000) then
        TaskPlayAnim(ped, set.scared, 'idle_a', 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

local function standAndWalk(ped, destination, heading)
    local set = getCowerSet(ped)
    requestAnimDict(set.exit, 4000)
    FreezeEntityPosition(ped, false)
    local seq = OpenSequenceTask()
    TaskPlayAnim(0, set.exit, 'exit', 4.0, -4.0, -1, 0, 0.0, false, false, false)
    TaskGoStraightToCoord(0, destination.x, destination.y, destination.z, 1.0, 7000, heading or 0.0, 0.4)
    CloseSequenceTask(seq)
    TaskPerformSequence(ped, seq)
    ClearSequenceTask(seq)
end

function W2F.Arrival.Container(ctx, spawnCoords)
    local cfg = (Config.Arrival or {}).container or {}

    local containerModel = cfg.model          or 'tr_prop_tr_container_01a'
    local collisionModel = cfg.collisionProp  or 'prop_ld_container'
    local containerCoords = cfg.spawnCoords   or vec4(520.39, -2935.94, 6.04, 180.0)
    local openDict        = cfg.openDict       or 'anim@scripted@player@mission@tunf_train_ig1_container_p1@male@'
    local openAnim        = cfg.openAnim       or 'action_container'
    local openPhase       = cfg.openPhase      or 0.66

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

        -- Controle de estado e entidades
        local skipped = false
        local containerProp = nil
        local collisionProp = nil
        local doorScene = nil
        local npc1 = nil
        local npc2 = nil
        local cam1 = nil
        local cam2 = nil
        local cam3 = nil
        local streamHandle = nil
        local activeSoundIds = {} -- Rastreia todos os soundIds para cleanup sem vazamento

        local function doSkip()
            if skipped then return end
            skipped = true
            dbg('[container] jogador pulou a cinematica')
        end

        RegisterNUICallback('skipArrivalStory', function(data, cb)
            doSkip()
            if cb then cb('ok') end
        end)

        -- Exibe overlay de loading ANTES de qualquer load pesado (elimina tela preta muda)
        W2F.SendNui('showStoryLoading', { text = 'Preparando embarque...' })

        -- 1. Carrega bancos de áudio do GTA
        pcall(function()
            RequestScriptAudioBank('DLC_HEI4/DLC_HEI4_Submarine', false)
            RequestScriptAudioBank('Container_Lifter', false)
            RequestScriptAudioBank('DLC_APARTMENT/APT_Yacht_01', false)
            RequestAmbientAudioBank('Crane', false)
            RequestAmbientAudioBank('Crane_Impact_Sweeteners', false)
        end)

        -- 2. Stream da área do porto
        if W2F.Streaming and W2F.Streaming.Acquire then
            streamHandle = W2F.Streaming.Acquire(vec3(containerCoords.x, containerCoords.y, containerCoords.z), {
                radius = 120.0,
                keepThread = true,
                focus = true,
                scene = false,
            })
        end

        SetEntityVisible(ped, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, containerCoords.x, containerCoords.y, containerCoords.z + 1.0, false, false, false, false)

        -- 3. Carrega modelos dos props
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

        -- Trava as portas do contêiner fechadas com Cena Sincronizada (estilo MRI)
        local animDictOk = requestAnimDict(openDict, 5000)
        if containerProp and animDictOk then
            local p = GetEntityCoords(containerProp)
            local r = GetEntityRotation(containerProp, 2)
            doorScene = CreateSynchronizedScene(p.x, p.y, p.z, r.x, r.y, r.z, 2)
            PlaySynchronizedEntityAnim(containerProp, doorScene, openAnim, openDict, 1000.0, -8.0, 0, 1000.0)
            SetSynchronizedSceneHoldLastFrame(doorScene, true)
            SetSynchronizedScenePhase(doorScene, 0.0) -- 0.0 = porta 100% trancada
            SetSynchronizedSceneRate(doorScene, 0.0)
            ForceEntityAiAndAnimationUpdate(containerProp)
        end

        -- 4. Companheiros clandestinos
        local npc1Model = GetHashKey('a_m_m_mexlabor_01')
        local npc2Model = GetHashKey('a_m_y_mexthug_01')
        requestModelSafe(npc1Model, 6000)
        requestModelSafe(npc2Model, 6000)

        -- Posições relativas — geometria do tr_prop_tr_container_01a (20ft ISO):
        --   Comprimento: 6.1m  → fundo fechado em +Y~2.95, portas em -Y~2.95
        --   Largura:     2.4m  → laterais em ±0.85 (sem tocar a parede)
        --   Chão interno: Z local = -1.15 (prop com NoOffset → GetOffset usa transform do prop)
        --
        -- Valores validados pelo OmniRoute (kiro/claude-sonnet-4.5):
        -- Jogador ao centro próximo ao fundo, NPCs à esq/dir na mesma linha
        local playerInside = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.0, 2.2, -1.15)
            or vec3(containerCoords.x, containerCoords.y + 2.2, containerCoords.z)
        local npc1Pos = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, -0.85, 2.0, -1.15)
            or vec3(containerCoords.x - 0.85, containerCoords.y + 2.0, containerCoords.z)
        local npc2Pos = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.85, 2.0, -1.15)
            or vec3(containerCoords.x + 0.85, containerCoords.y + 2.0, containerCoords.z)

        local faceDoorsHeading = (containerCoords.w + 180.0) % 360.0

        -- Posiciona o jogador sentado no chão encolhido de medo
        SetEntityCoords(ped, playerInside.x, playerInside.y, playerInside.z, false, false, false, false)
        SetEntityHeading(ped, faceDoorsHeading)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        playCower(ped)

        -- Cria NPC 1
        if HasModelLoaded(npc1Model) then
            npc1 = CreatePed(4, npc1Model, npc1Pos.x, npc1Pos.y, npc1Pos.z, (faceDoorsHeading - 20.0) % 360.0, false, false)
            if DoesEntityExist(npc1) then
                SetEntityInvincible(npc1, true)
                SetBlockingOfNonTemporaryEvents(npc1, true)
                FreezeEntityPosition(npc1, true)
                playCower(npc1)
            end
            SetModelAsNoLongerNeeded(npc1Model)
        end

        -- Cria NPC 2
        if HasModelLoaded(npc2Model) then
            npc2 = CreatePed(4, npc2Model, npc2Pos.x, npc2Pos.y, npc2Pos.z, (faceDoorsHeading + 20.0) % 360.0, false, false)
            if DoesEntityExist(npc2) then
                SetEntityInvincible(npc2, true)
                SetBlockingOfNonTemporaryEvents(npc2, true)
                FreezeEntityPosition(npc2, true)
                playCower(npc2)
            end
            SetModelAsNoLongerNeeded(npc2Model)
        end

        -- 5. Câmera INTERIOR 1
        -- Validado pelo OmniRoute: Y=-2.3 (perto das portas, dentro), Z=-0.4 local
        -- Aponta para os peds no fundo (+Y) levemente para baixo
        local cam1Pos = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.0, -2.3, -0.4)
            or vec3(containerCoords.x, containerCoords.y - 2.3, containerCoords.z - 0.4)
        local cam1Target = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.0, 2.0, -1.0)
            or vec3(containerCoords.x, containerCoords.y + 2.0, containerCoords.z - 1.0)
        cam1 = createLookAtCam(cam1Pos, cam1Target, 54.0)
        SetCamActive(cam1, true)
        RenderScriptCams(true, false, 0, true, false)

        -- Ativa as barras de cinema no NUI
        W2F.SendNui('showCinemaBars', {})

        -- Iluminação escura de interior — usar força reduzida para não anular a câmera
        SetTimecycleModifier('int_extlight_none_dark')
        SetTimecycleModifierStrength(0.65)

        -- Fecha overlay de loading e faz fade in — agora a cena está pronta
        W2F.SendNui('hideStoryLoading', {})
        DoScreenFadeIn(800)
        while not IsScreenFadedIn() do Wait(0) end

        -- Som de motor diesel de navio ao fundo (loop) + onda batendo no casco
        pcall(function()
            local sndCreaking = GetSoundId()
            PlaySoundFromCoord(sndCreaking, 'Creaking_Loop', playerInside.x, playerInside.y, playerInside.z, 'DLC_H4_Submarine_Crush_Depth_Sounds', false, 25.0, false)
            table.insert(activeSoundIds, sndCreaking)
            local sndHorn = GetSoundId()
            PlaySoundFromCoord(sndHorn, 'HORN', containerCoords.x, containerCoords.y - 90.0, containerCoords.z + 10.0, 'DLC_Apt_Yacht_Ambient_Soundset', false, 90.0, false)
            table.insert(activeSoundIds, sndHorn)
        end)

        -- SÓ AGORA mostra o botão de skip (após fade in completo)
        W2F.SendNui('showArrivalSkip', {})

        local beats = cfg.beats or { dark = 2000, impact = 1600, open = 2000, out = 3500 }

        -- Legenda 1: "Vinte e três dias no escuro."
        W2F.SendNui('showArrivalSubtitle', { text = subtitles[1], durationMs = beats.dark })

        -- ATO 1: Desenha feixes de luz dourada pelas frestas metálicas (DrawSpotLight)
        -- Pré-calcula os feixes uma vez (contêiner estático = sem GetOffset por frame)
        local beamsAto1 = {}
        if containerProp and DoesEntityExist(containerProp) then
            for i = -1, 1 do
                local beamFrom = GetOffsetFromEntityInWorldCoords(containerProp, i * 0.35, -2.8, 1.0 + i * 0.25)
                local beamTo   = GetOffsetFromEntityInWorldCoords(containerProp, i * 0.2, 1.8, 0.2)
                local dir = beamTo - beamFrom
                beamsAto1[#beamsAto1 + 1] = { from = beamFrom, dir = dir }
            end
        end
        local timerEnd = GetGameTimer() + beats.dark
        while GetGameTimer() < timerEnd and not skipped do
            for i = 1, #beamsAto1 do
                local b = beamsAto1[i]
                DrawSpotLight(b.from.x, b.from.y, b.from.z, b.dir.x, b.dir.y, b.dir.z, 255, 214, 160, 6.0, 9.0, 0.0, 3.5, 30.0)
            end
            if IsControlJustReleased(0, 191) or IsControlJustReleased(0, 201) then doSkip() break end
            Wait(0)
        end

        -- ATO 2: O TRANCO DO GUINDASTE (Solavanco violento e impacto de aço)
        if not skipped then
            -- Som de impacto pesado
            pcall(function()
                PlaySoundFromCoord(-1, 'Container_Impact_Land', playerInside.x, playerInside.y, playerInside.z, 'CRANE_SOUNDS', false, 40.0, false)
                PlaySoundFromCoord(-1, 'Container_Land', playerInside.x, playerInside.y, playerInside.z, 'CONTAINER_LIFTER_SOUNDS', false, 40.0, false)
            end)

            -- Tremor violento de câmera
            ShakeCam(cam1, 'LARGE_EXPLOSION_SHAKE', 0.22)

            -- Personagens tomam sobressalto de pânico
            playFlinch(ped)
            if npc1 and DoesEntityExist(npc1) then playFlinch(npc1) end
            if npc2 and DoesEntityExist(npc2) then playFlinch(npc2) end

            -- Legenda 2: "Ele prometeu trabalho. Cobrou adiantado."
            W2F.SendNui('showArrivalSubtitle', { text = subtitles[2], durationMs = beats.impact })

            timerEnd = GetGameTimer() + beats.impact
            local cachedBeams = {}
            if containerProp and DoesEntityExist(containerProp) then
                for i = -1, 1 do
                    local beamFrom = GetOffsetFromEntityInWorldCoords(containerProp, i * 0.35, -2.8, 1.0 + i * 0.25)
                    local beamTo = GetOffsetFromEntityInWorldCoords(containerProp, i * 0.2, 1.8, 0.2)
                    local dir = beamTo - beamFrom
                    cachedBeams[#cachedBeams + 1] = { from = beamFrom, dir = dir }
                end
            end
            local settled = false
            while GetGameTimer() < timerEnd and not skipped do
                if not settled and (GetGameTimer() > timerEnd - 1000) then
                    settled = true
                    StopCamShaking(cam1, false)
                    playCower(ped)
                    if npc1 and DoesEntityExist(npc1) then playCower(npc1) end
                    if npc2 and DoesEntityExist(npc2) then playCower(npc2) end
                end
                for i = 1, #cachedBeams do
                    local b = cachedBeams[i]
                    DrawSpotLight(b.from.x, b.from.y, b.from.z, b.dir.x, b.dir.y, b.dir.z, 255, 214, 160, 6.0, 9.0, 0.0, 3.5, 30.0)
                end
                if IsControlJustReleased(0, 191) or IsControlJustReleased(0, 201) then doSkip() break end
                Wait(0)
            end
        end

        -- ATO 3: ABERTURA DAS PORTAS & CLARÃO SOLAR
        if not skipped then
            -- 3 batidas secas e rápidas do coiote por fora
            pcall(function() PlaySoundFrontend(-1, 'BOSS_KNOCK', 'GTAO_EXEC_SECUROSERV_NETWORK_SOUNDSET', false) end)
            Wait(180)
            pcall(function() PlaySoundFrontend(-1, 'BOSS_KNOCK', 'GTAO_EXEC_SECUROSERV_NETWORK_SOUNDSET', false) end)
            Wait(180)
            pcall(function() PlaySoundFrontend(-1, 'BOSS_KNOCK', 'GTAO_EXEC_SECUROSERV_NETWORK_SOUNDSET', false) end)
            Wait(180)

            -- Trava estala e as portas abrem instantaneamente na fase 0.66
            pcall(function()
                PlaySoundFrontend(-1, 'container_door', 'dlc_prison_break_heist_sounds', false)
            end)

            if doorScene then
                SetSynchronizedScenePhase(doorScene, openPhase)
                SetSynchronizedSceneRate(doorScene, 1.0)
                ForceEntityAiAndAnimationUpdate(containerProp)
            end

            -- Câmera exterior 2 (Filmando de frente as portas se abrindo para fora em -Y)
            local cam2Pos = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.0, -7.2, 1.45)
                or vec3(containerCoords.x, containerCoords.y - 7.2, containerCoords.z + 1.45)
            local cam2Look = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.0, -0.5, 1.1)
                or vec3(containerCoords.x, containerCoords.y - 0.5, containerCoords.z + 1.1)
            cam2 = createLookAtCam(cam2Pos, cam2Look, 52.0)

            SetCamActiveWithInterp(cam2, cam1, 550, 1, 1)
            Wait(600)
            destroyCam(cam1)
            SetCamActive(cam2, true)

            -- Troca suave de colisão para liberar a passagem das portas
            if containerProp then SetEntityCollision(containerProp, false, false) end
            if collisionProp then
                SetEntityCollision(collisionProp, true, true)
                SetEntityVisible(collisionProp, false, false)
            end

            -- Clarão solar, som de gaivotas e remoção do filtro escuro
            ClearTimecycleModifier()
            pcall(function() AnimpostfxPlay('DeathFailNeutralIn', 500, false) end)
            pcall(function()
                PlaySoundFrontend(-1, 'Seagulls', 'JEWEL_HEIST_SOUNDS', false)
                PlaySoundFrontend(-1, 'SCREEN_FLASH', 'CELEBRATION_SOUNDSET', false)
            end)

            -- Legenda 3: "Bem-vindo a Los Santos."
            W2F.SendNui('showArrivalSubtitle', { text = subtitles[3], durationMs = beats.open })

            -- ATO 4: LEVANTAR-SE DO CHÃO E CAMINHAR PARA O CAIS (standAndWalk via OpenSequenceTask)
            local exitDist = (cfg.exitOffset and cfg.exitOffset.y) or 5.0
            local exitCoords = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 0.0, -exitDist, 0.0)
                or vec3(containerCoords.x, containerCoords.y - exitDist, containerCoords.z)

            local okGround, safeZ = GetGroundZFor_3dCoord(exitCoords.x, exitCoords.y, exitCoords.z + 2.0, false)
            if okGround and safeZ > 1.0 then
                exitCoords = vec3(exitCoords.x, exitCoords.y, safeZ)
            end

            local exitHeading = (containerCoords.w + 180.0) % 360.0

            -- Jogador se levanta suavemente do chão e caminha em direção ao pátio do porto
            standAndWalk(ped, exitCoords, exitHeading)

            -- Companheiros também se levantam com ligeiro delay e saem para direções opostas
            if npc1 and DoesEntityExist(npc1) then
                SetTimeout(450, function()
                    if DoesEntityExist(npc1) then
                        local npc1Exit = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, -2.8, -exitDist - 2.5, 0.0)
                            or vec3(exitCoords.x - 2.8, exitCoords.y - 2.5, exitCoords.z)
                        standAndWalk(npc1, npc1Exit, exitHeading)
                    end
                end)
            end

            if npc2 and DoesEntityExist(npc2) then
                SetTimeout(800, function()
                    if DoesEntityExist(npc2) then
                        local npc2Exit = containerProp and GetOffsetFromEntityInWorldCoords(containerProp, 2.8, -exitDist - 2.5, 0.0)
                            or vec3(exitCoords.x + 2.8, exitCoords.y - 2.5, exitCoords.z)
                        standAndWalk(npc2, npc2Exit, exitHeading)
                    end
                end)
            end

            Wait(1100)

            -- Legenda 4: "Agora você deve."
            W2F.SendNui('showArrivalSubtitle', { text = subtitles[4], durationMs = beats.out })

            -- ATO 5: CÂMERA SEGUINDO O JOGADOR PELAS COSTAS (AttachCamToEntity)
            cam3 = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            -- Offset: 2m atrás do ped, 1m acima — câmera do tipo shoulder/terceira pessoa
            AttachCamToEntity(cam3, ped, 0.0, -2.2, 1.0, true)
            PointCamAtEntity(cam3, ped, 0.0, 0.0, 0.5, true)
            SetCamFov(cam3, 55.0)
            SetCamActiveWithInterp(cam3, cam2, 1200, 1, 1)

            timerEnd = GetGameTimer() + 2200
            while GetGameTimer() < timerEnd and not skipped do
                if IsControlJustReleased(0, 191) or IsControlJustReleased(0, 201) then doSkip() break end
                Wait(0)
            end

            DetachCam(cam3)
            destroyCam(cam2)
            SetCamActive(cam3, true)
        end

        -- =========================================================================
        -- FINALIZAÇÃO / CLEANUP / TRANSIÇÃO PARA GAMEPLAY
        -- =========================================================================
        if skipped then
            DoScreenFadeOut(300)
            while not IsScreenFadedOut() do Wait(0) end
        end

        -- Oculta UI de cinema e restaura efeitos
        W2F.SendNui('hideArrivalSubtitle', {})
        W2F.SendNui('hideArrivalSkip', {})
        W2F.SendNui('hideCinemaBars', {})
        W2F.SendNui('hideStoryLoading', {}) -- garante que overlay de load some se houve skip precoce
        ClearTimecycleModifier()
        pcall(function() AnimpostfxStopAll() end)

        -- Para TODOS os sons rastreados explicitamente antes de liberar o banco
        pcall(function()
            for _, sId in ipairs(activeSoundIds) do
                if HasSoundFinished(sId) == false then
                    StopSound(sId)
                end
                ReleaseSoundId(sId)
            end
        end)
        activeSoundIds = {}

        -- Libera bancos de áudio (somente após StopSound de todos os soundIds)
        pcall(function()
            ReleaseNamedScriptAudioBank('DLC_HEI4/DLC_HEI4_Submarine')
            ReleaseNamedScriptAudioBank('Container_Lifter')
            ReleaseNamedScriptAudioBank('DLC_APARTMENT/APT_Yacht_01')
            ReleaseAmbientAudioBank()
        end)

        -- Destrói câmeras e restaura a câmera de jogo
        destroyCam(cam1)
        destroyCam(cam2)
        destroyCam(cam3)
        RenderScriptCams(false, not skipped, 1000, true, false)

        -- Deleta props temporários do contêiner
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

        pcall(function() RemoveAnimDict(openDict) end)
        pcall(function()
            RemoveAnimDict('amb@code_human_cower@male@base')
            RemoveAnimDict('amb@code_human_cower@male@scared')
            RemoveAnimDict('amb@code_human_cower@male@exit')
            RemoveAnimDict('amb@code_human_cower@female@base')
            RemoveAnimDict('amb@code_human_cower@female@scared')
            RemoveAnimDict('amb@code_human_cower@female@exit')
        end)

        -- Coordenadas de destino final firme no cais do porto
        local exitDist = (cfg.exitOffset and cfg.exitOffset.y) or 5.0
        local rad = math.rad(containerCoords.w or 0.0)
        local fwdX = math.sin(rad)
        local fwdY = -math.cos(rad)
        local targetHeading = (containerCoords.w + 180.0) % 360.0
        local targetCoords = vec4(containerCoords.x + (fwdX * exitDist), containerCoords.y + (fwdY * exitDist), containerCoords.z, targetHeading)

        local okGround, safeZ = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, targetCoords.z + 2.0, false)
        if okGround and safeZ > 1.0 then
            targetCoords = vec4(targetCoords.x, targetCoords.y, safeZ, targetHeading)
        end

        SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
        SetEntityHeading(ped, targetCoords.w)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        ClearPedTasks(ped)

        -- Proteção temporária de invencibilidade pós-spawn contra glitches de física
        SetTimeout(2500, function()
            if DoesEntityExist(ped) then
                SetEntityInvincible(ped, false)
            end
        end)

        if skipped then
            DoScreenFadeIn(500)
        end

        dbg('[container] historia concluida com sucesso, entregando em %s %s %s', targetCoords.x, targetCoords.y, targetCoords.z)
        if ctx and ctx.handBack then
            ctx.handBack(targetCoords)
        end
    end)
end

if W2F.Arrival and W2F.Arrival.Register then
    W2F.Arrival.Register('container', W2F.Arrival.Container)
end
