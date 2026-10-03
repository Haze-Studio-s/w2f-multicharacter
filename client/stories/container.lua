--- W2F.Arrival.Container — História de Chegada: Contêiner do Coiote
---
--- Engenharia Reversa e Transplante Fiel 1:1 do mri_Qmultichar (v1.4.0).
--- Utiliza exatamente a mesma matemática do MRI:
---   1. GetModelDimensions() para medir o prop real.
---   2. Alinhamento de porta na coordenada de destino (spawn.heading e gap).
---   3. Raycast descendente dinâmico (StartExpensiveSynchronousShapeTestLosProbe) para encontrar o chão interno exato.
---   4. Posicionamento de jogador e NPCs via inside(x, depth, z) em espaço local do contêiner.
---   5. Câmera interna com interpolação suave (camA), foco no rosto/cabeça sem recortes e feixes volumétricos (DrawSpotLight).
---   6. Tranco de impacto com ShakeCam('LARGE_EXPLOSION_SHAKE') e sobressalto (flinch/cower).
---   7. Abertura sincronizada das portas (fase 0.66) e clarão solar.
---   8. Sequência de saída standAndWalk (TaskPlayAnim exit + TaskGoStraightToCoord).
---   9. Sistema de áudio GTA nativo via RequestScriptAudioBank / RequestAmbientAudioBank.

W2F.Arrival = W2F.Arrival or {}

local function dbg(...)
    if W2F.Debug then W2F.Debug(...) end
end

local COWER = {
    male = { base = 'amb@code_human_cower@male@base', scared = 'amb@code_human_cower@male@idle_a', exit = 'amb@code_human_cower@male@exit' },
    female = { base = 'amb@code_human_cower@female@base', scared = 'amb@code_human_cower@female@idle_a', exit = 'amb@code_human_cower@female@exit' },
}

local PLAYER_DEPTH = 0.55

local function cowerSet(ped)
    return IsPedMale(ped) and COWER.male or COWER.female
end

local function cower(ped)
    local set = cowerSet(ped)
    if lib.requestAnimDict(set.base, 5000) then
        TaskPlayAnim(ped, set.base, 'base', 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

local function flinch(ped)
    local set = cowerSet(ped)
    if lib.requestAnimDict(set.scared, 5000) then
        local clips = { 'idle_a', 'idle_b', 'idle_c' }
        TaskPlayAnim(ped, set.scared, clips[math.random(#clips)], 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

local function standAndWalk(ped, legs, heading)
    local set = cowerSet(ped)
    lib.requestAnimDict(set.exit, 5000)
    FreezeEntityPosition(ped, false)
    local seq = OpenSequenceTask()
    TaskPlayAnim(0, set.exit, 'exit', 4.0, -4.0, -1, 0, 0.0, false, false, false)
    for i, p in ipairs(legs) do
        TaskGoStraightToCoord(0, p.x, p.y, p.z, 1.0, -1, i == #legs and heading or 0.0, 0.3)
    end
    CloseSequenceTask(seq)
    TaskPerformSequence(ped, seq)
    ClearSequenceTask(seq)
end

local function headingTo(from, to)
    return GetHeadingFromVector_2d(to.x - from.x, to.y - from.y)
end

local function forwardOf(h)
    local r = math.rad(h)
    return -math.sin(r), math.cos(r)
end

local function rightOf(h)
    local r = math.rad(h)
    return math.cos(r), math.sin(r)
end

local function groundAt(p)
    for _ = 1, 30 do
        local found, z = GetGroundZFor_3dCoord(p.x, p.y, p.z + 2.0, false)
        if found then return z end
        Wait(0)
    end
    return p.z - 1.0
end

local function holdDoorsClosed(box, ccfg)
    if not lib.requestAnimDict(ccfg.openDict, 5000) then
        dbg('[container] animacao das portas nao carregou')
        return nil
    end
    local pos = GetEntityCoords(box)
    local rot = GetEntityRotation(box, 2)
    local scene = CreateSynchronizedScene(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, 2)
    PlaySynchronizedEntityAnim(box, scene, ccfg.openAnim, ccfg.openDict, 1000.0, -8.0, 0, 1000.0)
    SetSynchronizedSceneHoldLastFrame(scene, true)
    SetSynchronizedScenePhase(scene, 0.0)
    SetSynchronizedSceneRate(scene, 0.0)
    ForceEntityAiAndAnimationUpdate(box)
    return scene
end

local function drawSeams(s)
    for i = -1, 1 do
        local from = s.inside(i * 0.35, -0.4, 1.0 + i * 0.25)
        local to = s.inside(i * 0.2, 1.8, 0.2)
        local d = to - from
        DrawSpotLight(from.x, from.y, from.z, d.x, d.y, d.z, 255, 214, 160, 6.0, 9.0, 0.0, 3.5, 30.0)
    end
end

function W2F.Arrival.Container(ctx, spawnCoords)
    local cfg = (Config.Arrival or {}).container or {}
    local ccfg = {
        model = GetHashKey(cfg.model or 'tr_prop_tr_container_01a'),
        collisionModel = GetHashKey(cfg.collisionProp or 'prop_ld_container'),
        openDict = cfg.openDict or 'anim@scripted@player@mission@tunf_train_ig1_container_p1@male@',
        openAnim = cfg.openAnim or 'action_container',
        openPhase = cfg.openPhase or 0.66,
        doorAxis = cfg.doorAxis or -1,
        doorOpenMs = cfg.doorOpenMs or 1200,
        floor = cfg.floor or 0.12,
        gap = cfg.gap or 1.4,
        darkness = cfg.darkness or 'int_extlight_none_dark',
        migrants = cfg.migrants or { 'a_m_m_mexlabor_01', 'a_m_y_mexthug_01', 'a_m_m_soucent_01' },
        beats = cfg.beats or { dark = 2400, impact = 1800, open = 2400, out = 4000 },
        sounds = cfg.sounds or {
            banks = {
                script = { 'DLC_HEI4/DLC_HEI4_Submarine', 'Container_Lifter', 'DLC_APARTMENT/APT_Yacht_01' },
                ambient = { 'Crane', 'Crane_Impact_Sweeteners', 'Crane_Stress', 'CREAK_V1' },
            },
            creakLoop = { 'Creaking_Loop', 'DLC_H4_Submarine_Crush_Depth_Sounds' },
            creaks = { { 'CREAK_01', 'DOCKS_HEIST_SETUP_SOUNDS' }, { 'Strain', 'CRANE_SOUNDS' } },
            horn = { 'HORN', 'DLC_Apt_Yacht_Ambient_Soundset' },
            impact = {
                { 'Container_Impact_Land', 'CRANE_SOUNDS' },
                { 'Container_Land', 'CONTAINER_LIFTER_SOUNDS' },
            },
            door = { 'container_door', 'dlc_prison_break_heist_sounds' },
            flash = { 'SCREEN_FLASH', 'CELEBRATION_SOUNDSET' },
            gulls = { 'Seagulls', 'JEWEL_HEIST_SOUNDS' },
        },
    }

    local destination = spawnCoords or cfg.spawnCoords or vec4(520.39, -2935.94, 6.04, 180.0)
    local spawn = {
        x = destination.x,
        y = destination.y,
        z = destination.z,
        heading = destination.w or 180.0,
    }

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
        local skipped = false
        local loops = {}
        local activeCams = {}
        local leftovers = {}

        local function doSkip()
            if skipped then return end
            skipped = true
            dbg('[container] pulando cena a pedido do jogador')
        end

        RegisterNUICallback('skipArrivalStory', function(data, cb)
            doSkip()
            if cb then cb('ok') end
        end)

        -- Audio design
        local sfx = ccfg.sounds
        local function loadBanks()
            if sfx and sfx.banks then
                for _, name in ipairs(sfx.banks.script or {}) do
                    for _ = 1, 20 do
                        if RequestScriptAudioBank(name, false) then break end
                        Wait(0)
                    end
                end
                for _, name in ipairs(sfx.banks.ambient or {}) do
                    for _ = 1, 20 do
                        if RequestAmbientAudioBank(name, false) then break end
                        Wait(0)
                    end
                end
            end
        end

        local function soundAt(def, p)
            if not def or not def[1] then return -1 end
            local id = GetSoundId()
            PlaySoundFromCoord(id, def[1], p.x, p.y, p.z, def[2], false, 0, false)
            return id
        end

        local function oneShot(def, p)
            local id = soundAt(def, p)
            if id ~= -1 then
                ReleaseSoundId(id)
            end
        end

        local function startLoop(key, def, p)
            loops[key] = soundAt(def, p)
        end

        local function stopLoop(key)
            local id = loops[key]
            if not id or id == -1 then return end
            StopSound(id)
            ReleaseSoundId(id)
            loops[key] = nil
        end

        local function stopAllLoops()
            for key in pairs(loops) do stopLoop(key) end
        end

        local function releaseBanks()
            if sfx and sfx.banks then
                for _, name in ipairs(sfx.banks.script or {}) do
                    ReleaseNamedScriptAudioBank(name)
                end
                ReleaseAmbientAudioBank()
            end
        end

        local function newCam(camFov)
            local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            SetCamFov(cam, camFov or 50.0)
            activeCams[#activeCams + 1] = cam
            return cam
        end

        local function cutTo(cam)
            for i = 1, #activeCams do
                if activeCams[i] ~= cam then SetCamActive(activeCams[i], false) end
            end
            SetCamActive(cam, true)
            RenderScriptCams(true, false, 0, true, true)
        end

        local function destroyCams()
            for i = 1, #activeCams do
                if DoesCamExist(activeCams[i]) then DestroyCam(activeCams[i], false) end
            end
            activeCams = {}
        end

        local function run(ms, onFrame)
            local startAt = GetGameTimer()
            while true do
                if skipped then return false end
                local t = (GetGameTimer() - startAt) / ms
                if t >= 1.0 then return true end
                if onFrame then onFrame(t) end
                Wait(0)
            end
        end

        -- Monitor de tecla Skip in-game (Space ou Enter)
        CreateThread(function()
            while not skipped do
                if IsDisabledControlJustPressed(0, 22) or IsDisabledControlJustPressed(0, 201) or IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) then
                    doSkip()
                    break
                end
                Wait(0)
            end
        end)

        loadBanks()

        -- STAGING (Geometria 1:1 MRI)
        local model = ccfg.model
        if not lib.requestModel(model, 10000) then
            dbg('[container] modelo do conteiner invalido')
            return
        end
        local dmin, dmax = GetModelDimensions(model)
        local axis = ccfg.doorAxis >= 0 and 1 or -1
        local endY = axis > 0 and dmax.y or dmin.y
        local length = dmax.y - dmin.y
        local width = dmax.x - dmin.x

        local fx, fy = forwardOf(spawn.heading)
        local door = vector3(spawn.x - fx * ccfg.gap, spawn.y - fy * ccfg.gap, spawn.z)

        -- Stream da área
        SetFocusPosAndVel(door.x, door.y, door.z, 0.0, 0.0, 0.0)
        NewLoadSceneStartSphere(door.x, door.y, door.z, 120.0, 0)
        local deadline = GetGameTimer() + 8000
        while not IsNewLoadSceneLoaded() and GetGameTimer() < deadline do
            RequestCollisionAtCoord(door.x, door.y, door.z)
            Wait(0)
        end
        NewLoadSceneStop()

        local ground = groundAt(door)

        local heading = axis > 0 and spawn.heading or (spawn.heading + 180.0) % 360.0
        local ex, ey = forwardOf(heading)
        local origin = vector3(door.x - ex * endY, door.y - ey * endY, ground - dmin.z)

        if not lib.requestModel(ccfg.collisionModel, 10000) then
            dbg('[container] modelo de colisao invalido')
            return
        end

        local box = CreateObject(model, origin.x, origin.y, origin.z, false, false, false)
        local shell = CreateObject(ccfg.collisionModel, origin.x, origin.y, origin.z, false, false, false)
        leftovers[#leftovers + 1] = box
        leftovers[#leftovers + 1] = shell
        SetModelAsNoLongerNeeded(model)
        SetModelAsNoLongerNeeded(ccfg.collisionModel)
        SetEntityHeading(box, heading)
        SetEntityHeading(shell, heading)
        SetEntityVisible(shell, false, false)

        local dz = ground - (GetEntityCoords(box).z + dmin.z)
        for _, e in ipairs({ box, shell }) do
            local p = GetEntityCoords(e)
            SetEntityCoordsNoOffset(e, p.x, p.y, p.z + dz, false, false, false)
            FreezeEntityPosition(e, true)
        end

        local floorZ = dmin.z + ccfg.floor
        local function inside(x, depth, z)
            return GetOffsetFromEntityInWorldCoords(box, x, endY - axis * depth, floorZ + (z or 0.0))
        end

        -- Raycast do piso real
        local probeFrom = inside(0.0, length * 0.5, 1.2)
        local probeTo = inside(0.0, length * 0.5, -2.5)
        local floorHit
        for _ = 1, 30 do
            local ray = StartExpensiveSynchronousShapeTestLosProbe(probeFrom.x, probeFrom.y, probeFrom.z, probeTo.x, probeTo.y, probeTo.z, 17, 0, 7)
            local _, hit, at = GetShapeTestResult(ray)
            if hit == 1 then
                floorHit = at.z
                break
            end
            Wait(0)
        end
        if floorHit then
            floorZ = floorZ + (floorHit - inside(0.0, length * 0.5, 0.0).z)
            dbg('[container] piso detectado a %.2f m da base', floorZ - dmin.z)
        end

        local doorScene = holdDoorsClosed(box, ccfg)

        local spot = inside(0.25, length * PLAYER_DEPTH)
        SetEntityCoordsNoOffset(ped, spot.x, spot.y, spot.z + 1.0, false, false, false)
        SetEntityHeading(ped, spawn.heading)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        cower(ped)

        local center = inside(0.0, length * 0.5, 0.0)
        local migrants = {}
        local slots = {
            { x = -(width / 2 - 0.5), depth = length * 0.72 },
            { x = width / 2 - 0.5, depth = length * 0.84 },
        }
        for i, slot in ipairs(slots) do
            local mModel = ccfg.migrants[(i - 1) % #ccfg.migrants + 1]
            local mHash = type(mModel) == 'number' and mModel or GetHashKey(mModel)
            if lib.requestModel(mHash, 8000) then
                local p = inside(slot.x, slot.depth, 0.0)
                local npc = CreatePed(26, mHash, p.x, p.y, p.z, 0.0, false, false)
                leftovers[#leftovers + 1] = npc
                SetModelAsNoLongerNeeded(mHash)
                SetEntityCoordsNoOffset(npc, p.x, p.y, p.z + 1.0, false, false, false)
                SetEntityHeading(npc, headingTo(p, center))
                SetBlockingOfNonTemporaryEvents(npc, true)
                SetEntityInvincible(npc, true)
                FreezeEntityPosition(npc, true)
                cower(npc)
                migrants[#migrants + 1] = npc
            end
        end

        local s = {
            box = box, doorScene = doorScene, migrants = migrants, ped = ped,
            heading = heading, axis = axis, inside = inside, length = length,
            width = width, endY = endY, floorZ = floorZ,
            doorCenter = inside(0.0, 0.0, 1.2), shell = shell,
        }

        -- SCENE (CENAS E BEATS 1:1 MRI)
        local beats = ccfg.beats

        -- 1. Dark & Creaks
        SetTimecycleModifier(ccfg.darkness)
        SetTimecycleModifierStrength(1.0)
        local farAway = vector3(center.x + fx * 90.0, center.y + fy * 90.0, center.z + 10.0)
        startLoop('creak', sfx.creakLoop, center)
        local nextCreak = GetGameTimer() + 900
        local hornAt = GetGameTimer() + 1400

        local function creaks()
            local now = GetGameTimer()
            if now >= nextCreak then
                if sfx.creaks and #sfx.creaks > 0 then
                    oneShot(sfx.creaks[math.random(#sfx.creaks)], s.inside((math.random() - 0.5) * s.width, math.random() * s.length, 2.0))
                end
                nextCreak = now + math.random(1600, 3200)
            end
            if hornAt and now >= hornAt then
                hornAt = nil
                oneShot(sfx.horn, farAway)
            end
        end

        local head = s.inside(0.25, s.length * PLAYER_DEPTH, 0.75)
        local camA = newCam(36.0)
        local fromA = s.inside(0.9, s.length * PLAYER_DEPTH - 1.1, 0.7)
        SetCamCoord(camA, fromA.x, fromA.y, fromA.z)
        PointCamAtCoord(camA, head.x, head.y, head.z)
        cutTo(camA)

        -- Revela cena (NUI e FadeIn)
        W2F.SendNui('showCinemaBars', {})
        W2F.SendNui('showArrivalSkip', {})
        DoScreenFadeIn(700)
        W2F.SendNui('showArrivalSubtitle', { text = subtitles[1], durationMs = beats.dark - 600 })

        local toA = fromA + (head - fromA) * 0.25
        local okScene = run(beats.dark, function(t)
            local k = t * t * (3 - 2 * t)
            SetCamCoord(camA, fromA.x + (toA.x - fromA.x) * k, fromA.y + (toA.y - fromA.y) * k, fromA.z + (toA.z - fromA.z) * k)
            drawSeams(s)
            creaks()
        end)

        -- 2. Impacto do guindaste
        if okScene and not skipped then
            for _, def in ipairs(sfx.impact or {}) do oneShot(def, center) end
            ShakeCam(camA, 'LARGE_EXPLOSION_SHAKE', 0.22)
            for _, npc in ipairs(s.migrants) do flinch(npc) end
            flinch(ped)
            W2F.SendNui('showArrivalSubtitle', { text = subtitles[2], durationMs = beats.impact - 400 })

            local settled = false
            okScene = run(beats.impact, function(t)
                if not settled and t > 0.35 then
                    settled = true
                    StopCamShaking(camA, false)
                    for _, npc in ipairs(s.migrants) do cower(npc) end
                    cower(ped)
                end
                drawSeams(s)
                creaks()
            end)
        end

        -- 3. Portas abrem e luz invade
        if okScene and not skipped then
            local camB = newCam(cfg.fov or 50.0)
            local fromB = s.inside(-0.45, s.length * PLAYER_DEPTH + 1.0, 1.4)
            SetCamCoord(camB, fromB.x, fromB.y, fromB.z)
            PointCamAtCoord(camB, s.doorCenter.x, s.doorCenter.y, s.doorCenter.z)
            cutTo(camB)
            stopLoop('creak')
            oneShot(sfx.door, s.doorCenter)
            oneShot(sfx.flash, s.doorCenter)
            oneShot(sfx.gulls, vector3(s.doorCenter.x + fx * 20.0, s.doorCenter.y + fy * 20.0, s.doorCenter.z + 8.0))
            pcall(function() AnimpostfxPlay('DeathFailNeutralIn', 500, false) end)

            if s.doorScene then
                SetSynchronizedScenePhase(s.doorScene, ccfg.openPhase)
                SetSynchronizedSceneRate(s.doorScene, 1.0)
                ForceEntityAiAndAnimationUpdate(s.box)
            end

            local opened = false
            okScene = run(beats.open, function(t)
                local k = math.min(1.0, (t * beats.open) / ccfg.doorOpenMs)
                SetTimecycleModifierStrength(math.max(0.0, 1.0 - k * 1.4))
                if not opened and k >= 1.0 then
                    opened = true
                    ClearTimecycleModifier()
                    SetEntityCollision(s.box, false, true)
                    W2F.SendNui('showArrivalSubtitle', { text = subtitles[3], durationMs = beats.open })
                end
                if k < 0.5 then drawSeams(s) end
            end)
        end

        -- 4. Caminhada para fora em direção ao cais
        if okScene and not skipped then
            oneShot(sfx.horn, vector3(farAway.x + fx * 60.0, farAway.y + fy * 60.0, farAway.z))
            local camC = newCam(cfg.fov or 50.0)
            SetCamCoord(camC, spawn.x + fx * 3.2, spawn.y + fy * 3.2, spawn.z + 0.6)
            PointCamAtCoord(camC, s.doorCenter.x, s.doorCenter.y, s.doorCenter.z - 0.3)
            cutTo(camC)

            local doorway = s.inside(0.0, 0.5, 1.0)
            standAndWalk(ped, { doorway, vector3(spawn.x, spawn.y, spawn.z) }, spawn.heading)

            local rx, ry = rightOf(spawn.heading)
            for i, npc in ipairs(s.migrants) do
                SetTimeout(900 + i * 700, function()
                    if not DoesEntityExist(npc) then return end
                    local off = (i % 2 == 0) and 1.8 or -1.8
                    local out = vector3(spawn.x + rx * off + fx * 2.0, spawn.y + ry * off + fy * 2.0, spawn.z)
                    standAndWalk(npc, { doorway, out }, spawn.heading)
                end)
            end

            W2F.SendNui('showArrivalSubtitle', { text = subtitles[4], durationMs = beats.out - 600 })
            run(beats.out, nil)

            ClearPedTasks(ped)
            if #(GetEntityCoords(ped) - vector3(spawn.x, spawn.y, spawn.z)) > 2.5 then
                SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
            end
            SetEntityHeading(ped, spawn.heading)
        end

        -- CLEANUP (Restauro total de estado)
        ClearTimecycleModifier()
        StopGameplayCamShaking(true)
        stopAllLoops()
        releaseBanks()
        W2F.SendNui('hideArrivalSubtitle', {})
        W2F.SendNui('hideArrivalSkip', {})
        W2F.SendNui('hideCinemaBars', {})
        pcall(function() AnimpostfxStopAll() end)

        if skipped then
            DoScreenFadeOut(250)
            while not IsScreenFadedOut() do Wait(0) end
            ClearPedTasksImmediately(ped)
            SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
            SetEntityHeading(ped, spawn.heading)
        end

        SetGameplayCamRelativeHeading(0.0)
        SetGameplayCamRelativePitch(0.0, 1.0)
        RenderScriptCams(false, not skipped, skipped and 0 or (cfg.blendOutMs or 1200), true, true)
        destroyCams()
        ClearFocus()

        -- Libera peds para vagarem antes de serem excluídos
        SetTimeout(5000, function()
            for _, npc in ipairs(s.migrants or {}) do
                if DoesEntityExist(npc) then
                    FreezeEntityPosition(npc, false)
                    TaskWanderStandard(npc, 10.0, 10)
                end
            end
        end)

        -- Exclui cena sincronizada se ainda estiver ativa
        if s and s.doorScene then
            pcall(function() DeleteSynchronizedScene(s.doorScene) end)
            s.doorScene = nil
        end

        -- Exclui entidades temporárias criadas quando o jogador estiver distante ou após timeout de 60s
        for _, ent in ipairs(leftovers) do
            if DoesEntityExist(ent) then
                CreateThread(function()
                    local lifetime = GetGameTimer() + 60000
                    while DoesEntityExist(ent) and GetGameTimer() < lifetime do
                        local playerPed = PlayerPedId()
                        if not DoesEntityExist(playerPed) then
                            DeleteEntity(ent)
                            break
                        end
                        local dist = #(GetEntityCoords(ent) - GetEntityCoords(playerPed))
                        if dist > 35.0 then
                            DeleteEntity(ent)
                            break
                        end
                        Wait(1000)
                    end
                    if DoesEntityExist(ent) then DeleteEntity(ent) end
                end)
            end
        end

        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, false)

        if IsScreenFadedOut() or IsScreenFadingOut() then
            DoScreenFadeIn(600)
        end

        dbg('[container] historia concluida, entregando em %s %s %s', spawn.x, spawn.y, spawn.z)
        if ctx and ctx.handBack then
            ctx.handBack(vec4(spawn.x, spawn.y, spawn.z, spawn.heading))
        end
    end)
end

if W2F.Arrival and W2F.Arrival.Register then
    W2F.Arrival.Register('container', W2F.Arrival.Container)
end
