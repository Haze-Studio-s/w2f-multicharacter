--- W2F.Prelude — Sequência cinemática de revelação de personagem.
---
--- Ativado logo após `finishCreation` OK, antes do spawn final.
--- Sequência:
---   1. Freeze do tempo (SetTimeScale) + filtro preto e branco (HeistCelebPassBW).
---   2. Risco de disco (PlaySoundFrontend).
---   3. NUI: cartão do personagem bate na tela (nome, idade, nacionalidade).
---   4. Pausa no cartão (Config.Prelude.freezeDurationMs).
---   5. NUI: cartão de capítulo entra na diagonal (título da história, local, hora).
---   6. NUI: cartão de capítulo sai na diagonal — revela o primeiro plano da história.
---   7. Entrega controle para W2F.Arrival.Play().
---
--- Dependências de NUI: action 'showPreludeCard', 'showChapterCard', 'hidePrelude'.
--- Todos os efeitos de camera-side são client-only (SetTimeScale, StartCamEffect)
--- e não afetam outros jogadores.

W2F.Prelude = {}

local function dbg(...)
    if W2F.Debug then W2F.Debug(...) end
end

--- Verifica se um efeito de câmera nativo existe antes de aplicar (guard anti-crash).
local function safeCamEffect(effectName, durationMs, looped)
    local ok = pcall(function()
        AnimpostfxPlay(effectName, durationMs or 0, looped or false)
    end)
    if not ok then
        dbg('[prelude] efeito %s nao disponivel, ignorado', tostring(effectName))
    end
    return ok
end

local function safeStopCamEffect(effectName)
    pcall(function() AnimpostfxStop(effectName) end)
end

--- Determina a hora do jogo formatada para o cartão de capítulo.
local function getFormattedTime()
    local h = GetClockHours()
    local m = GetClockMinutes()
    local ampm = h >= 12 and 'PM' or 'AM'
    local h12 = h % 12
    if h12 == 0 then h12 = 12 end
    return string.format('%d:%02d %s', h12, m, ampm)
end

--- Sequência principal do prelúdio.
--- @param charData table  { name, age, nationality, arrivalId, arrivalTitle, arrivalPlace }
--- @param onDone   function  Callback chamado após o prelúdio terminar (para iniciar a história).
function W2F.Prelude.Play(charData, onDone)
    local cfg = Config.Prelude or {}
    if cfg.enabled == false then
        if onDone then onDone() end
        return
    end

    local freezeMs     = cfg.freezeDurationMs     or 3500
    local chapterMs    = cfg.chapterCardDurationMs or 3000
    local timeScaleVal = cfg.timeScale             or 0.1

    charData = charData or {}
    local charName    = charData.name        or 'Cidadão'
    local charAge     = charData.age         or '—'
    local charNat     = charData.nationality or 'Desconhecido'
    local arrTitle    = charData.arrivalTitle or 'Capítulo Final'
    local arrPlace    = charData.arrivalPlace or 'Los Santos'
    local arrTime     = getFormattedTime()

    dbg('[prelude] iniciando para %s (%s, %s)', charName, charAge, charNat)

    CreateThread(function()
        -- 0. Câmera de corte seco / close-up dramático no rosto com whoosh
        local ped = PlayerPedId()
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, true)

        local headPos = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
        if headPos == vec3(0.0, 0.0, 0.0) or headPos.z < 1.0 then
            headPos = GetEntityCoords(ped) + vec3(0.0, 0.0, 0.65)
        end
        local heading = GetEntityHeading(ped)
        local rad = math.rad(heading)
        -- Posiciona a câmera a ~1.05m à frente do rosto
        local camPos = vec3(
            headPos.x + math.sin(-rad) * 1.05,
            headPos.y + math.cos(-rad) * 1.05,
            headPos.z + 0.05
        )
        local preludeCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(preludeCam, camPos.x, camPos.y, camPos.z)
        PointCamAtCoord(preludeCam, headPos.x, headPos.y, headPos.z)
        SetCamFov(preludeCam, 34.0)
        SetCamActive(preludeCam, true)
        RenderScriptCams(true, false, 0, true, false)

        -- Revela a tela após a saída do editor de aparência
        DoScreenFadeIn(400)
        while not IsScreenFadedIn() do Wait(0) end

        -- Som de Whoosh no corte seco
        pcall(function()
            PlaySoundFrontend(-1, '1st_Person_Transition', 'PLAYER_SWITCH_CUSTOM_SOUNDSET', false)
        end)
        Wait(60)

        -- 1. Freeze do tempo + efeito P&B
        SetTimeScale(timeScaleVal)
        safeCamEffect('HeistCelebPassBW', 0, true)
        Wait(80)

        -- 2. Risco de disco
        pcall(function()
            PlaySoundFrontend(-1, 'RECORD_SCRATCH', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end)
        Wait(120)

        -- 3. NUI: cartão do personagem
        W2F.SendNui('showPreludeCard', {
            name        = charName,
            age         = tostring(charAge),
            nationality = charNat,
        })

        -- 4. Aguardar leitura
        Wait(freezeMs)

        -- 5. NUI: cartão de capítulo (entra na diagonal)
        W2F.SendNui('showChapterCard', {
            title = arrTitle,
            place = arrPlace,
            time  = arrTime,
        })
        Wait(chapterMs)

        -- 6. Fade out para transicionar para a história
        DoScreenFadeOut(600)
        while not IsScreenFadedOut() do Wait(0) end

        -- 7. Restaurar tempo + remover efeito P&B + destruir câmera
        SetTimeScale(1.0)
        safeStopCamEffect('HeistCelebPassBW')
        if preludeCam and DoesCamExist(preludeCam) then
            DestroyCam(preludeCam, false)
        end
        RenderScriptCams(false, false, 0, true, false)

        -- 8. Esconder overlay do prelúdio e disparar callback
        W2F.SendNui('hidePrelude', {})
        Wait(200)

        dbg('[prelude] concluido, entregando para arrival')
        if onDone then
            CreateThread(onDone)
        end
    end)
end
