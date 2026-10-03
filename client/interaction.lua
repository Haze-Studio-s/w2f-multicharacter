W2F.Interaction = {
    lastMouseX = nil,
    lastMouseY = nil,
    dragDistance = 0.0,
    lastHoverUpdateAt = 0,
    --- Falls back to Config.Interaction.hoverIntervalMs when present.
    hoverIntervalMs = 30,
    loopRunning = false,
    --- Throttle for repeated `chat:setActive` re-suppression so we don't flood
    --- the chat resource every frame while still defeating its key-mapped
    --- /t open command.
    chatSuppressLastMs = 0,
    --- Cached pick result, valid for the current frame only. Set inside the
    --- loop's per-frame block and consumed by UpdatePedTargeting + HandleClick
    --- so they don't both invoke the raycaster.
    cachedPickAt = 0,
    cachedPickSlot = nil,
    cachedPickEntry = nil,
    --- Dirty flag for the highlight pass; set whenever hover/selection or
    --- the ped list changes. Cleared after RefreshHighlights runs.
    highlightDirty = true,
}

--- Hard-disables the cfx chat resource while the multichar UI owns input.
--- Re-fires periodically because cfx `chat` registers a key-mapped command for
--- T which still fires even when control 245 is suppressed.
local function suppressChat()
    if GetResourceState('chat') ~= 'started' then return end
    local now = GetGameTimer()
    if (now - W2F.Interaction.chatSuppressLastMs) < 400 then return end
    W2F.Interaction.chatSuppressLastMs = now
    pcall(TriggerEvent, 'chat:setActive', false)
end

local function isLeftClickHeld()
    if (Config.CameraControl.holdButton or 'LEFT_CLICK') == 'LEFT_CLICK' then
        return IsDisabledControlPressed(0, 24) or IsControlPressed(0, 24)
    end
    return false
end

local function wasLeftClickReleased()
    if (Config.CameraControl.holdButton or 'LEFT_CLICK') == 'LEFT_CLICK' then
        return IsDisabledControlJustReleased(0, 24) or IsControlJustReleased(0, 24)
    end
    return false
end

local function wasLeftClickPressed()
    if (Config.CameraControl.holdButton or 'LEFT_CLICK') == 'LEFT_CLICK' then
        return IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 24)
    end
    return false
end

function W2F.Interaction.UpdateCameraDrag()
    if LocalPlayer.state.whitelist_dialog_open then return end
    if W2F.State.isCreatePanelOpen or W2F.State.isCreatingCharacter then
        return
    end
    if not W2F.State.isInSelection or W2F.State.isSkySpawnMode or W2F.State.isSpawning or W2F.State.isTransitioningToSky then
        return
    end
    if W2F.Camera.mode ~= 'overview' or W2F.State.isIntroPlaying then
        return
    end

    local camCfg = Config.CameraControl
    if not camCfg.enabled then return end

    local cursorX, cursorY = GetNuiCursorPosition()
    if not cursorX then return end

    if isLeftClickHeld() then
        if not W2F.State.isDraggingCamera then
            W2F.State.isDraggingCamera = true
            W2F.State.hasDraggedCamera = false
            W2F.Interaction.dragDistance = 0.0
            W2F.State.dragStartX = cursorX
            W2F.State.dragStartY = cursorY
            W2F.Interaction.lastMouseX = cursorX
            W2F.Interaction.lastMouseY = cursorY
        else
            local dx = cursorX - (W2F.Interaction.lastMouseX or cursorX)
            local dy = cursorY - (W2F.Interaction.lastMouseY or cursorY)
            W2F.Interaction.dragDistance = W2F.Interaction.dragDistance + math.abs(dx) + math.abs(dy)
            if W2F.Interaction.dragDistance > (Config.CameraControl.dragThreshold or Config.Interaction.dragThreshold) then
                W2F.State.hasDraggedCamera = true
            end
            W2F.Camera.ApplyDrag(dx, dy)
            W2F.Interaction.lastMouseX = cursorX
            W2F.Interaction.lastMouseY = cursorY
        end
    elseif wasLeftClickReleased() and W2F.State.isDraggingCamera then
        W2F.State.isDraggingCamera = false
        W2F.State.dragStartX = nil
        W2F.State.dragStartY = nil
        W2F.Interaction.lastMouseX = nil
        W2F.Interaction.lastMouseY = nil
    end
end

--- Performs a single raycast for the current frame and caches the result so
--- HandleClick can reuse it. Returns (slot, entry).
local function pickPedThisFrame()
    local now = GetGameTimer()
    if W2F.Interaction.cachedPickAt == now then
        return W2F.Interaction.cachedPickSlot, W2F.Interaction.cachedPickEntry
    end
    local slot, entry = W2F.Characters.FindPedAtCursor()
    W2F.Interaction.cachedPickAt = now
    W2F.Interaction.cachedPickSlot = slot
    W2F.Interaction.cachedPickEntry = entry
    return slot, entry
end

function W2F.Interaction.UpdatePedTargeting()
    if LocalPlayer.state.whitelist_dialog_open then return end
    if Config.Interaction.hoverEnabled == false then
        return
    end
    if not W2F.Session.Is('selection') then return end
    if W2F.State.isDraggingCamera or W2F.State.isIntroPlaying then
        return
    end

    local now = GetGameTimer()
    local intervalMs = (W2F.Performance and W2F.Performance.Get and W2F.Performance.Get('hoverIntervalMs'))
        or (Config.Interaction and Config.Interaction.hoverIntervalMs)
        or W2F.Interaction.hoverIntervalMs
        or 20
    if intervalMs > 0 and (now - W2F.Interaction.lastHoverUpdateAt) < intervalMs then
        --- Skip the raycast + highlight refresh for the throttle window.
        return
    end
    W2F.Interaction.lastHoverUpdateAt = now

    local slot, entry = pickPedThisFrame()

    local prevHovered = W2F.State.hoveredPed
    if slot and entry then
        if prevHovered ~= entry.ped then
            W2F.SetHovered(slot, entry.ped)
            W2F.SendNui('updateHoveredPed', { slot = slot })
            --- Per-hover frontend sound is opt-out via Config.Hover.disableHoverSound.
            if not (Config.Hover and Config.Hover.disableHoverSound) then
                W2F.PlayW2FSound(Config.Audio.hover)
            end
            pcall(function()
                local camCoords = W2F.Camera.GetCurrentCoord()
                if camCoords and DoesEntityExist(entry.ped) then
                    TaskLookAtCoord(entry.ped, camCoords.x, camCoords.y, camCoords.z, 1500, 2048, 3)
                end
            end)
            W2F.Debug('hover ped slot=%d', slot)
            W2F.Interaction.highlightDirty = true
        end
    elseif prevHovered then
        W2F.SetHovered(nil, nil)
        W2F.SendNui('updateHoveredPed', { slot = nil })
        W2F.Interaction.highlightDirty = true
    end

    --- Only re-apply outlines when something changed. Cuts ~70% of the
    --- per-frame native calls during a static hover.
    if W2F.Interaction.highlightDirty then
        W2F.Characters.RefreshHighlights()
        W2F.Interaction.highlightDirty = false
    end
end

function W2F.Interaction.HandleClick()
    if LocalPlayer.state.whitelist_dialog_open then return end
    if Config.Interaction.selectionEnabled == false then
        return
    end
    if not W2F.Session.Is('selection') then return end
    if W2F.State.isIntroPlaying or W2F.State.isDraggingCamera then
        return
    end

    local camDragEnabled = Config.CameraControl.enabled == true
    local clicked = wasLeftClickPressed() or wasLeftClickReleased()

    if not clicked or not W2F.CanClick() then
        return
    end

    if camDragEnabled and (W2F.State.hasDraggedCamera or W2F.Interaction.dragDistance > (Config.CameraControl.dragThreshold or Config.Interaction.dragThreshold)) then
        W2F.State.hasDraggedCamera = false
        W2F.Interaction.dragDistance = 0.0
        return
    end

    --- Reuse the cached pick from the targeting pass earlier this frame; if
    --- the click pass runs first (rare but possible if hoverIntervalMs is
    --- still in cooldown) we run our own raycast on demand.
    local slot, entry = pickPedThisFrame()

    if slot and entry then
        if entry.character and not entry.isEmpty then
            if W2F.State.selectedPed ~= entry.ped then
                W2F.Characters.SelectSlot(slot, entry)
            end
        elseif entry.isEmpty then
            if W2F.State.selectedSlot ~= slot then
                W2F.MarkClick()
                W2F.Characters.SelectEmptySlot(slot)
            end
        end
    end

    W2F.State.hasDraggedCamera = false
    W2F.Interaction.dragDistance = 0.0
end

--- Blocks chat, pause menu, phone, weapon wheel, etc. Only whitelists controls
--- needed for the current multichar UI mode.
function W2F.Interaction.DisableControls()
    local pad = 0
    DisableAllControlActions(pad)

    --- Pad 1/2 are not needed for NUI mouse selection; skipping them saves
    --- two expensive native sweeps per tick on low-end hardware.
    --- Prevent pause / map / phone / chat / inventory / scoreboard shortcuts.
    --- 245/246/247/248 cover all four chat input controls (all/team/private/reply).
    local blocked = {
        199, 200, 202, 243, 244, 245, 246, 247, 248, 249,
        288, 289, 311, 322, 323, 167, 168, 169, 170, 177, 300,
    }
    for i = 1, #blocked do
        DisableControlAction(pad, blocked[i], true)
    end

    SetPauseMenuActive(false)
    if IsPauseMenuActive() then
        SetFrontendActive(false)
    end
    --- Suppress chat resource even when it tries to open via key-mapped /t.
    suppressChat()

    if W2F.State.isCreatePanelOpen or W2F.State.isModalOpen then
        --- Registration form or confirmation modal: NUI only (no ped raycasts / camera drag / game controls).
        return
    end

    if W2F.State.isSkySpawnMode or W2F.State.isSpawning or W2F.State.isTransitioningToSky then
        return
    end

    if W2F.State.isInSelection then
        EnableControlAction(pad, 24, true) --- LMB — ped pick / camera orbit
    end
end

function W2F.Interaction.UpdateKeyboardNavigation()
    if LocalPlayer.state.whitelist_dialog_open then return end
    if W2F.State.isModalOpen or W2F.State.isCreatePanelOpen or W2F.State.isCreatingCharacter then return end
    if W2F.State.isIntroPlaying or W2F.State.isDraggingCamera then return end
    if not W2F.Session.Is('selection') then return end

    -- A (34) ou Seta Esquerda (174) -> Slot anterior
    if IsDisabledControlJustPressed(0, 34) or IsDisabledControlJustPressed(0, 174) then
        if W2F.Characters and W2F.Characters.NavigateSlot then
            W2F.Characters.NavigateSlot(-1)
        end
        return
    end

    -- D (35) ou Seta Direita (175) -> Próximo slot
    if IsDisabledControlJustPressed(0, 35) or IsDisabledControlJustPressed(0, 175) then
        if W2F.Characters and W2F.Characters.NavigateSlot then
            W2F.Characters.NavigateSlot(1)
        end
        return
    end

    -- W (32) ou Seta Cima (172) ou Enter (18 / 191) -> Confirmar Entrada ou Criar
    if IsDisabledControlJustPressed(0, 32) or IsDisabledControlJustPressed(0, 172) or IsDisabledControlJustPressed(0, 18) or IsDisabledControlJustPressed(0, 191) then
        if W2F.Characters and W2F.Characters.ConfirmCurrentSlot then
            W2F.Characters.ConfirmCurrentSlot()
        end
        return
    end

    -- S (33) ou Seta Baixo (173) ou Esc (177 / 200) -> Voltar / Cancelar foco para Overview geral
    if IsDisabledControlJustPressed(0, 33) or IsDisabledControlJustPressed(0, 173) or IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
        if W2F.Characters and W2F.Characters.ClearSelection then
            W2F.Characters.ClearSelection()
        end
        return
    end

    -- Atalhos numéricos 1 a 5 (157..161)
    for i = 1, 5 do
        if IsDisabledControlJustPressed(0, 156 + i) then
            if W2F.Characters and W2F.Characters.JumpToSlot then
                W2F.Characters.JumpToSlot(i)
            end
            return
        end
    end

    -- Delete (178) -> Abrir modal de confirmação de exclusão
    if IsDisabledControlJustPressed(0, 178) then
        if W2F.State.selectedSlot and W2F.State.selectedCharacter then
            W2F.SendNui('openConfirmDeleteModal', {})
        end
        return
    end
end

function W2F.Interaction.StartLoop()
    if W2F.Interaction.loopRunning then
        return
    end
    W2F.Interaction.loopRunning = true

    CreateThread(function()
        --- Loop runs while the session machine is inside any phase that
        --- still wants game controls suppressed + the orbit camera updated.
        while W2F.Session.OwnsScreen() and not W2F.Session.Is('bootstrapping') do
            W2F.Interaction.DisableControls()
            if W2F.Render and W2F.Render.SuppressWorldPopulation then
                W2F.Render.SuppressWorldPopulation()
            end
            if W2F.Session.Is('selection') and W2F.Render and W2F.Render.EnforcePedAnchor then
                W2F.Render.EnforcePedAnchor()
            end
            if W2F.Performance and W2F.Performance.SampleFrame then
                W2F.Performance.SampleFrame()
            end

            local interactivePhase = W2F.Session.Is('selection')
                and (W2F.Camera.mode == 'overview' or W2F.Camera.mode == 'focused')

            if interactivePhase then
                W2F.Interaction.UpdateCameraDrag()
                W2F.Interaction.UpdatePedTargeting()
                W2F.Interaction.HandleClick()
                W2F.Interaction.UpdateKeyboardNavigation()
            end

            W2F.Camera.Update()

            --- Cinematic + dragging paths need every frame to stay buttery.
            --- The LOCKED overview/focused camera is also continuously
            --- animating — it smooths its focal toward the selected ped, runs
            --- idle drift, and settles rotation. Driving W2F.Camera.Update()
            --- only every `selectionTick` ms (≈50 Hz) while the display renders
            --- at 120-144 Hz makes that motion visibly stutter (the cam holds
            --- the same transform for 2-3 frames, then jumps). Update the
            --- scripted camera every frame whenever it is active in an
            --- interactive phase; the hover raycast stays independently
            --- throttled by `hoverIntervalMs`, so this costs almost nothing.
            local needsHighFps = W2F.State.isIntroPlaying
                or W2F.State.isDraggingCamera
                or W2F.Session.In('sky_picker', 'flying', 'finalizing')
                or (W2F.Camera and W2F.Camera.cinematic)
                or (W2F.Camera and W2F.Camera.active
                    and (W2F.Camera.mode == 'overview' or W2F.Camera.mode == 'focused'))

            local perf = Config.Performance or {}
            local selectionTick = (W2F.Performance and W2F.Performance.Get and W2F.Performance.Get('selectionLoopMs'))
                or perf.selectionLoopMs or 20
            Wait(needsHighFps and 0 or (interactivePhase and selectionTick or 8))
        end

        --- Loop just exited; re-enable every control we suppressed so the
        --- player isn't left with frozen input after spawn.
        if W2F.Cleanup and W2F.Cleanup.EnableAllControls then
            W2F.Cleanup.EnableAllControls()
        end
        W2F.Interaction.loopRunning = false
    end)
end

RegisterNUICallback('clickWorld', function(data, cb)
    if W2F.State.isModalOpen or W2F.State.isCreatePanelOpen or W2F.State.isCreatingCharacter then
        cb('ok')
        return
    end
    if not W2F.Session.Is('selection') then
        cb('ok')
        return
    end
    if W2F.State.isIntroPlaying or W2F.State.isDraggingCamera then
        cb('ok')
        return
    end

    local cx = data and tonumber(data.x)
    local cy = data and tonumber(data.y)
    local slot, entry = W2F.Characters.FindPedAtCursor(cx, cy)

    if slot and entry then
        if entry.character and not entry.isEmpty then
            if W2F.State.selectedPed ~= entry.ped then
                W2F.Characters.SelectSlot(slot, entry)
            end
        elseif entry.isEmpty then
            if W2F.State.selectedSlot ~= slot then
                W2F.Characters.SelectEmptySlot(slot)
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('selectSlot', function(data, cb)
    if W2F.State.isCreatePanelOpen then
        cb('ok')
        return
    end
    local slot = tonumber(data and data.slot)
    if slot then
        local entry = W2F.State.previewPeds[slot]
        if entry then
            if entry.character and not entry.isEmpty then
                W2F.Characters.SelectSlot(slot, entry, true)
            else
                W2F.Characters.SelectEmptySlot(slot)
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('selectEmptySlot', function(data, cb)
    if W2F.State.isCreatePanelOpen then
        cb('ok')
        return
    end
    local slot = tonumber(data and data.slot)
    if slot then
        local entry = W2F.State.previewPeds[slot]
        if entry and entry.character and not entry.isEmpty then
            W2F.Characters.SelectSlot(slot, entry)
        else
            W2F.Characters.SelectEmptySlot(slot)
        end
    end
    cb('ok')
end)

RegisterNUICallback('openCreateForSlot', function(data, cb)
    if W2F.State.isCreatePanelOpen then
        cb('ok')
        return
    end
    local slot = tonumber(data and data.slot) or W2F.State.selectedSlot or 1
    W2F.Characters.OpenCreateForSlot(slot)
    cb('ok')
end)

RegisterNUICallback('cancelDetails', function(_, cb)
    if W2F.State.isCreatePanelOpen then
        cb('ok')
        return
    end
    if W2F.CanClick() then
        W2F.Characters.ClearSelection()
    end
    cb('ok')
end)

RegisterNUICallback('deleteCharacter', function(_, cb)
    if W2F.State.isCreatePanelOpen or W2F.State.isCreatingCharacter then
        cb('ok')
        return
    end
    if W2F.Characters and W2F.Characters.DeleteSelected then
        W2F.Characters.DeleteSelected()
    end
    cb('ok')
end)

RegisterNUICallback('resetCamera', function(_, cb)
    W2F.Camera.ResetTargets()
    cb('ok')
end)

RegisterNUICallback('navigateSlot', function(data, cb)
    if W2F.State.isCreatePanelOpen or W2F.State.isCreatingCharacter then
        cb('ok')
        return
    end
    local dir = tonumber(data and data.direction) or 1
    if W2F.Characters and W2F.Characters.NavigateSlot then
        W2F.Characters.NavigateSlot(dir)
    end
    cb('ok')
end)

RegisterNUICallback('confirmSlot', function(_, cb)
    if W2F.State.isModalOpen or W2F.State.isCreatePanelOpen or W2F.State.isCreatingCharacter then
        cb('ok')
        return
    end
    if W2F.Characters and W2F.Characters.ConfirmCurrentSlot then
        W2F.Characters.ConfirmCurrentSlot()
    end
    cb('ok')
end)

RegisterNUICallback('setModalState', function(data, cb)
    local isOpen = data and data.open == true
    W2F.State.isModalOpen = isOpen
    if isOpen then
        --- Foco estrito: CEF consome 100% de teclado e mouse; nada passa para o GTA V
        W2F.SetSelectionFocus(true, false)
    else
        if W2F.Session.Is('selection') and not W2F.State.isCreatePanelOpen then
            --- Restaura o modo padrão permitindo orbitar câmera com mouse
            W2F.SetSelectionFocus(true, true)
        end
    end
    cb('ok')
end)
