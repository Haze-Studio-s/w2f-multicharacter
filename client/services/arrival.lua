--- W2F.Arrival — Orquestrador de Histórias de Chegada.
---
--- Responsável por:
---   1. Receber o arrivalId do personagem (gravado no metadata da criação).
---   2. Montar o ctx (contexto de câmeras, legendas, handBack).
---   3. Rotear para a história correta (container, plane, ou nenhuma).
---   4. Após a história, retornar o fluxo normal de spawn.
---
--- Ativado por W2F.Arrival.Play() chamado a partir do creator.lua logo após
--- finishCreation() confirmar sucesso no servidor.

W2F.Arrival = W2F.Arrival or {}

local function dbg(...)
    if W2F.Debug then W2F.Debug(...) end
end

--- Tabela de roteamento: arrivalId → função da história
--- As histórias se registram sozinhas ao serem carregadas
--- (container.lua faz W2F.Arrival.Container = ..., etc.)
local STORY_REGISTRY = {}

function W2F.Arrival.Register(id, fn)
    STORY_REGISTRY[id] = fn
    dbg('[arrival] historia registrada: %s', id)
end

--- Autoregistra as histórias embutidas após carregar os arquivos
CreateThread(function()
    Wait(0)  -- espera o próximo frame para garantir que os arquivos de histórias carregaram
    if W2F.Arrival.Container then
        W2F.Arrival.Register('container', W2F.Arrival.Container)
    end
    if W2F.Arrival.Plane then
        W2F.Arrival.Register('plane', W2F.Arrival.Plane)
    end
    if W2F.Arrival.Prison then
        W2F.Arrival.Register('prison', W2F.Arrival.Prison)
    end
    if W2F.Arrival.Train then
        W2F.Arrival.Register('train', W2F.Arrival.Train)
    end
    dbg('[arrival] historias registradas no sistema')
end)

--- Determina o arrivalId correto para uma nacionalidade.
--- Estrangeiros (não-Brasileiro, não-Americano) → contêiner por padrão.
--- Americanos/Brasileiros sem chegada configurada → nenhuma história.
local function resolveArrivalId(meta)
    local arrivalId = meta and meta.arrivalId
    if arrivalId and arrivalId ~= '' and arrivalId ~= 'none' then
        return arrivalId
    end

    -- Seleção automática por nacionalidade
    local nat = (meta and (meta.nationality or meta.charNationality)) or ''
    local nonNative = { ['Brasileiro'] = true, ['Americano'] = true, ['American'] = true, ['Brazilian'] = true }
    if not nonNative[nat] then
        return 'container'
    end
    return nil  -- sem história
end

--- Monta o contexto passado para a função de história.
local function buildCtx(spawnCoords, onDone)
    return {
        --- Câmera ativa do sistema W2F (pode ser nil antes de qualquer cam ser criada)
        mainCam = W2F.Camera and W2F.Camera.handle,
        --- Entrega controle de volta ao chamador (deve ser chamado pelo story ao final)
        handBack = function(resolvedCoords)
            if onDone then
                onDone(resolvedCoords or spawnCoords)
            end
        end,
    }
end

--- Ponto de entrada principal.
--- @param meta        table   Metadados do personagem: { arrivalId, nationality, name, age, ... }
--- @param spawnCoords vec4    Coordenadas de destino final após a cena.
--- @param onDone      function Callback(resolvedCoords) chamado após a história terminar.
function W2F.Arrival.Play(meta, spawnCoords, onDone)
    local cfg = Config.Arrival or {}
    if cfg.enabled == false then
        if onDone then onDone(spawnCoords) end
        return
    end

    local arrivalId = resolveArrivalId(meta)

    if not arrivalId then
        dbg('[arrival] sem historia de chegada para este personagem')
        if onDone then onDone(spawnCoords) end
        return
    end

    local storyFn = STORY_REGISTRY[arrivalId]
    if not storyFn then
        dbg('[arrival] historia "%s" nao encontrada no registry, pulando', tostring(arrivalId))
        if onDone then onDone(spawnCoords) end
        return
    end

    -- Fallback seguro para coordenadas de spawn de acordo com a história
    local finalSpawnCoords = spawnCoords
    if not finalSpawnCoords then
        if arrivalId == 'container' then
            local contCfg = cfg.container or {}
            local contCoords = contCfg.spawnCoords or vec4(428.34, -3005.00, 5.90, 180.0)
            local rad = math.rad(contCoords.w or 0.0)
            local fwdX = -math.sin(rad)
            local fwdY = math.cos(rad)
            local dist = (contCfg.exitOffset and contCfg.exitOffset.y) or 4.2
            finalSpawnCoords = vec4(contCoords.x + (fwdX * dist), contCoords.y + (fwdY * dist), contCoords.z, contCoords.w)
        elseif arrivalId == 'plane' then
            finalSpawnCoords = cfg.planeSpawnCoords or vec4(-1037.0, -2737.0, 13.8, 330.0)
        elseif arrivalId == 'prison' then
            local prisCfg = cfg.prison or {}
            finalSpawnCoords = prisCfg.spawnCoords or vec4(1837.20, 2586.20, 45.67, 270.0)
        elseif arrivalId == 'train' then
            local trainCfg = cfg.train or {}
            finalSpawnCoords = trainCfg.spawnCoords or vec4(264.00, -1198.00, 29.28, 90.0)
        end
    end

    dbg('[arrival] executando historia: %s', arrivalId)

    local ctx = buildCtx(finalSpawnCoords, onDone)
    storyFn(ctx, finalSpawnCoords)
end

