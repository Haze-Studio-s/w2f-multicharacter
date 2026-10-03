Config = {}

Config.Framework = Config.Framework or 'auto'
-- valid values: 'auto', 'qbox', 'qbcore', 'esx'

Config.General = {
    Debug = true, -- TEMP: tracar fluxo de criacao (editor de aparencia nao abre). Voltar p/ false depois.
    --- Should match the number of scene ped slots (visual lineup positions).
    MaxCharacters = 3,
    DefaultSlots = 3,
    --- MLO lineup interiors stream in bucket 0. Isolated per-player buckets
    --- leave the selector in an empty world shell (void rendering).
    UseRoutingBuckets = false,
}

--- New character registration + clothing (illenium-appearance).
Config.CharacterCreation = {
    enabled = true,
    auditLog = true,
    nameMinLength = 2,
    nameMaxLength = 24,
    birthdateMin = '1940-01-01',
    birthdateMax = '2006-12-31',
    defaultNationality = 'American',
    nationalities = {
        'American', 'British', 'Canadian', 'Mexican', 'German',
        'French', 'Italian', 'Spanish', 'Russian', 'Chinese',
        'Japanese', 'Korean', 'Australian', 'Brazilian', 'Other',
    },
    --- Uses illenium-appearance when started; falls back to qb-clothes event.
    preferIllenium = true,
    --- World coords used during the non-apartment appearance editor (used when
    --- `directToApartment` is false, or as the fallback when an apartment claim
    --- can't be confirmed). The player ped is placed here and the editor camera
    --- frames it from the front.
    ---
    --- Heading 73° faces the player from the "Main character location"
    --- (-260.25, -982.19, 30.22) toward the "ped location" (-263.44, -981.2,
    --- 30.22), so illenium's default 2.65m front camera lands right at that ped
    --- spot for a clean head-to-feet shot. Nudge the heading (vec4.w) if the
    --- backdrop behind the ped isn't clean.
    appearanceLocation = vec4(-260.25, -982.19, 30.22, 73.0),
    --- Radius streamed in around the appearance location before the editor
    --- starts so the world has loaded by the time we fade in.
    appearanceStreamRadius = 75.0,
    --- After creation finishes, skip the character selector and drop the
    --- player straight into the spawn picker (default locations + the
    --- starter apartment options). Set false to keep the legacy lineup flow.
    --- This is now legacy: `directToApartment` (below) takes precedence and
    --- skips the spawn picker entirely.
    directToSpawnPicker = true,
    --- NEW FLOW (preferred): right after the create form is submitted, log
    --- the player in as the new character and drop them DIRECTLY into the
    --- starter apartment. This requires qbx_properties to complete its
    --- apartment-first flow and trigger `qb-clothes:client:CreateFirstCharacter`
    --- so appearance is created inside the apartment.
    ---
    --- This flow is OPTIONAL and self-disabling: it only runs when the
    --- apartment resource named by `apartmentResource` (below) is actually
    --- started. On servers without an apartment system, creation automatically
    --- falls back to the legacy appearance-editor-then-spawn-picker pipeline,
    --- so the resource works completely standalone with no apartments at all.
    ---
    --- If qbx_properties is unavailable or its claim cannot be confirmed, the
    --- resource falls back to legacy appearance creation before opening the
    --- spawn picker. directToApartment must never skip appearance creation
    --- unless the apartment flow is confirmed available.
    ---
    --- Set false to always use the legacy LSIA-appearance-then-spawn-picker
    --- pipeline even when an apartment resource is present.
    directToApartment = true,
    --- Name of the apartment/property resource that provides the starter
    --- apartment flow. Only `qbx_properties` is integrated out of the box.
    --- Set to '' (empty string) or false to force the no-apartment flow
    --- regardless of which resources are running.
    apartmentResource = '', -- Sem qbx_properties neste servidor: '' força o fluxo aparência→spawn-picker.
    --- Which apartment index to use as the starter when `directToApartment`
    --- is true AND `apartmentResource` is running. See that resource's
    --- `config/shared.lua` (`apartmentOptions`) — 1 = Del Perro Heights by
    --- default in qbx_properties.
    starterApartmentIndex = 1,
}

Config.Debug = Config.General.Debug

-----------------------------------------------------------------------------
--- Debug / diagnostic toggles (W2F.Diag).
---
--- These are STRICTLY OPT-IN. With every flag below set to `false` (the
--- defaults), the resource MUST behave identically to the un-instrumented
--- legacy build — no log spam, no behaviour changes, no extra natives.
---
--- Toggles can also be flipped at runtime via the `/w2fmc_safemode` command
--- (which writes into `W2F.Diag.runtime` without mutating these defaults).
---
---   DebugStreaming           Verbose logs around every streaming Acquire/Release
---                            (focus, scene sphere, collision, follow-camera).
---   DebugSceneSafeMode       Reduced streaming pressure: smaller sphere radius,
---                            slower per-frame collision tick, no follow-camera.
---                            Use to rule out streaming overload as the crash cause.
---   DebugDisableBuckets      Skip the per-source routing bucket on EnterSelection.
---                            Use to rule out bucket-induced MLO load failures.
---   DebugDisablePreviewEmotes Skip emote scenarios / anims / world props / attached
---                             props on preview peds. Falls back to a still ped.
---                             Use to rule out asset/scenario load races.
---   DebugExteriorScene       Replace the lineup interior coords with the exterior
---                            LSIA fallback (`Config.DebugExteriorSceneCoords`).
---                            Use to confirm the crash is interior/MLO-specific.
---   DebugCollisionLogs       Log collision/focus/scene status every ~250ms while
---                            a streaming handle is live. Pair with DebugStreaming
---                            for the most verbose trail.
---
--- All diag log lines are prefixed `[w2f-multicharacter][stream-debug]`.
-----------------------------------------------------------------------------
Config.DebugStreaming = false
Config.DebugSceneSafeMode = false       -- void resolvido (era aust_banking), debug desligado.
Config.DebugDisableBuckets = false
Config.DebugDisablePreviewEmotes = false
Config.DebugExteriorScene = false
Config.DebugCollisionLogs = false
--- When true, prints a `/w2fmc_diag`-style snapshot automatically ~2s after
--- the character selector fades in (F8 console). Also runs when DebugStreaming
--- is true.
Config.DebugAutoDiagOnSelection = false

--- Exterior fallback scene used when `DebugExteriorScene` (or `/w2fmc_exteriortest`)
--- is active. Picked to be a wide, low-traffic outdoor area (LSIA south apron)
--- so we can verify the selector + camera + preview peds work correctly with
--- zero MLO/IPL dependencies.
Config.DebugExteriorSceneCoords = {
    pedSlots = {
        vec4(-1042.50, -2745.40, 21.36, 320.0),
        vec4(-1044.30, -2746.90, 21.36, 320.0),
        vec4(-1046.10, -2748.40, 21.36, 320.0),
    },
    overviewCamera = vec4(-1043.30, -2740.40, 23.20, 145.0),
}

--- Set true only when qbx_core/config/client.lua has characters.useExternalCharacters = true
Config.UseExternalCharacters = true

--- Opens selection on session start (requires UseExternalCharacters)
Config.AutoOpen = true

--- Startup / reconnect reliability (server restart, slow MySQL, late NUI).
Config.Startup = {
    maxAttempts = 6,
    attemptDelayMs = 1500,
    dependencyTimeoutMs = 45000,
    nuiReadyTimeoutMs = 10000,
    --- World streaming for the selection interior on cold boot. Without focus +
    --- a persistent scene sphere the overview camera often frames empty space
    --- until the resource is restarted.
    sceneStreamRadius = 90.0,
    sceneCollisionTimeoutMs = 15000,
}

-- Character selection scene (ped lineup)
--
-- Each ped slot can be either:
--   * vec4(x, y, z, heading)                            (no emote)
--   * { coords = vec4(...), emote = 'emoteName' }      (uses Config.Emotes)
--
-- When `emote` is set, the slot's heading is honored verbatim (auto-facing is
-- skipped for that slot) so the staged pose is preserved.
Config.Scene = {
    --- All slots share the same interior as overviewCamera so the locked
    --- camera can frame them. Per-slot heading is honored verbatim.
    pedSlots = {
        { coords = vec4(916.7150, 40.9866, 111.7013, 63.8547), emote = 'sitchair4' },
        { coords = vec4(914.9835, 39.3125, 111.7013, 337.9402), emote = 'smoke' },
        { coords = vec4(912.2994, 40.3135, 111.7012, 295.9295), emote = 'leanbar' },
    },
    --- Fixed overview camera position (x, y, z). vec4.w is optional legacy
    --- metadata only — rotation is computed from this position toward the
    --- ped-lineup focal point so the camera always faces the characters.
    overviewCamera = vec4(916.2162, 47.8691, 111.6620, 175.3658),
    introDurationMs = 2800,
    introStartHeight = 12.0,
    --- When true, first session connect skips the intro fly-in and snaps
    --- straight to overviewCamera (same as the default session boot path).
    skipIntroOnBoot = true,
    --- Focal point is the ped-center lifted by this amount (chest/face height).
    focalHeightOffset = 1.0,
    --- Auto-orient preview peds toward the overview camera. Off here because
    --- the staged emotes look correct only at the headings provided.
    autoFacePedsToCamera = false,
    --- Emote pool for the most recently played character (highest lastLoggedOut).
    --- One entry is picked deterministically per citizenid when the lineup loads.
    lastLocationEmotes = {
        'smoke',
        'wait', 'wait2', 'wait3', 'wait4', 'wait5', 'wait6', 'wait7',
        'stretch', 'stretch2', 'stretch3', 'stretch4',
        'shakeoff',
    },
    --- Interior/MLO streaming for the lineup location. Auto-detects via
    --- GetInteriorAtCoords at the scene focal; fill `ipls` if your map uses IPLs.
    ---
    --- The lineup sits in the BASE-GAME Diamond Casino & Resort (penthouse
    --- level, ~916/40/111). The casino is DLC geometry that is NOT streamed
    --- unless its IPLs are requested — with no IPLs the interior renders as
    --- broken/missing geometry (z-fighting, holes). These RequestIpl names
    --- load the full casino shell + penthouse so it renders correctly.
    --- (Coordinates are unchanged; this only loads the geometry that was
    --- always supposed to be there.)
    interior = {
        ipls = {
            'vw_casino_main',       -- main casino building shell
            'vw_casino_penthouse',  -- penthouse level (lineup is here)
            'vw_casino_carpark',    -- car park substructure
            'vw_casino_garage',     -- penthouse garage
            'hei_dlc_casino_aircon',
            'vw_dlc_casino_door',
            'hei_dlc_windows_casino',
        },
        pinInterior = true,
        --- Ymap MLOs at the lineup coords may not register with GetInteriorAtCoords
        --- until after the scene sphere loads — force the interior streaming path.
        forceMloScene = true,
        --- Safemode uses 40m; 90m can fail to load tight MLO lineups on cold boot.
        streamRadius = 40.0,
        streamKeepaliveMs = 100,
        streamFocusRefreshMs = 500,
        --- Keep NewLoadSceneStartSphere active for the whole selection session.
        keepSceneSphere = true,
        --- Hide the local ped at focal Z instead of 50m underground (required
        --- for the engine to keep streaming the interior shell).
        keepPlayerInside = true,
    },
}

--- Emote registry used by curated scene slots. Each entry can specify any of:
---   scenario   = GTA ped scenario name (TaskStartScenarioInPlace / AtPosition)
---   anim       = { dict, clip }    plays a looped animation (LOOP flag = 1)
---   prop       = { model, offsetZ } spawns a world prop at the slot (kept
---                with the slot lifetime). When provided alongside `scenario`,
---                the scenario is started at the prop's position so the ped
---                snaps onto it (e.g. sitting in a chair).
---   attachProp = { model, bone, offset, rot } attaches a prop to a ped bone
---                (bone defaults to 60309 = SKEL_R_Hand). Useful for cups etc.
Config.Emotes = {
    --- scully_emotemenu: /smoke
    smoke = {
        scenario = 'WORLD_HUMAN_SMOKING',
    },
    --- scully_emotemenu: /wait through /wait7
    wait = {
        anim = { dict = 'random@shop_tattoo', clip = '_idle_a' },
    },
    wait2 = {
        anim = { dict = 'missbigscore2aig_3', clip = 'wait_for_van_c' },
    },
    wait3 = {
        anim = { dict = 'amb@world_human_hang_out_street@female_hold_arm@idle_a', clip = 'idle_a' },
    },
    wait4 = {
        anim = { dict = 'amb@world_human_hang_out_street@Female_arm_side@idle_a', clip = 'idle_a' },
    },
    wait5 = {
        anim = { dict = 'missclothing', clip = 'idle_storeclerk' },
    },
    wait6 = {
        anim = { dict = 'timetable@amanda@ig_2', clip = 'ig_2_base_amanda' },
    },
    wait7 = {
        anim = { dict = 'rcmnigel1cnmt_1c', clip = 'base' },
    },
    --- scully_emotemenu: /stretch through /stretch4
    stretch = {
        anim = { dict = 'mini@triathlon', clip = 'idle_e' },
    },
    stretch2 = {
        anim = { dict = 'mini@triathlon', clip = 'idle_f' },
    },
    stretch3 = {
        anim = { dict = 'mini@triathlon', clip = 'idle_d' },
    },
    stretch4 = {
        anim = { dict = 'rcmfanatic1maryann_stretchidle_b', clip = 'idle_e' },
    },
    --- scully_emotemenu: /shakeoff
    shakeoff = {
        anim = { dict = 'move_m@_idles@shake_off', clip = 'shakeoff_1' },
    },
    --- Legacy slot emotes (kept for reference / custom slot configs).
    sitchair = {
        anim = { dict = 'timetable@ron@ig_3_couch', clip = 'base' },
    },
    whiskey = {
        scenario = 'WORLD_HUMAN_DRINKING',
    },
    lean = {
        scenario = 'WORLD_HUMAN_LEANING',
    },
    --- scully_emotemenu: /sitchair4
    sitchair4 = {
        anim = { dict = 'timetable@jimmy@mics3_ig_15@', clip = 'mics3_15_base_tracy' },
    },
    --- scully_emotemenu: /leanbar
    ---
    --- WAS: scenario = 'PROP_HUMAN_BUM_SHOPPING_CART'. That scenario's
    --- controller asynchronously creates a shopping-cart prop and queries
    --- the floor physics under the ped — if the MLO floor isn't fully
    --- dispatched yet (which happens in the lineup interior on cold boot
    --- and after routing-bucket swap), the engine crashes inside the entity
    --- render path with the `floor-item-batman` signature ~1s after the ped
    --- spawns.
    ---
    --- Replaced with the equivalent loop anim from `amb@world_human_leaning`
    --- which renders the same "leaning against a wall" pose but does not
    --- spawn any engine-side world props, so it can't trigger the race.
    leanbar = {
        anim = { dict = 'amb@world_human_leaning@male@wall@back@hands_together@idle_a', clip = 'idle_a' },
    },
    sitchair2 = {
        anim = { dict = 'timetable@reunited@ig_10', clip = 'base_amanda' },
    },
}

Config.SceneProfiles = {
    neutral = {
        lighting = 'clean',
        animation = 'WORLD_HUMAN_STAND_IMPATIENT',
        props = {},
    },
    police = {
        lighting = 'emergency',
        animation = 'WORLD_HUMAN_COP_IDLES',
        props = {},
    },
    medical = {
        lighting = 'medical',
        animation = 'WORLD_HUMAN_CLIPBOARD',
        props = {},
    },
    garage = {
        lighting = 'garage',
        animation = 'WORLD_HUMAN_HAMMERING',
        props = {},
    },
    street = {
        lighting = 'dark',
        animation = 'WORLD_HUMAN_SMOKING',
        props = {},
    },
    executive = {
        lighting = 'clean',
        animation = 'WORLD_HUMAN_STAND_MOBILE',
        props = {},
    },
}

Config.SceneJobMap = {
    police = 'police',
    sheriff = 'police',
    state = 'police',
    ambulance = 'medical',
    ems = 'medical',
    doctor = 'medical',
    mechanic = 'garage',
    tuner = 'garage',
    gang = 'street',
    ballas = 'street',
    vagos = 'street',
    families = 'street',
    cartel = 'street',
    unemployed = 'neutral',
    realestate = 'executive',
    lawyer = 'executive',
    judge = 'executive',
    casino = 'executive',
}

Config.CameraControl = {
    --- Camera drag is fully disabled — the overview stays locked at the
    --- configured overviewCamera position at all times.
    enabled = false,
    holdButton = 'LEFT_CLICK',
    sensitivityX = 0.06,
    sensitivityY = 0.03,
    smoothing = 0.07,
    --- Drag clamps are relative to the base overview orbit (degrees).
    minYaw = -25.0,
    maxYaw = 25.0,
    minPitch = -10.0,
    maxPitch = 10.0,
    minDistance = 6.0,
    maxDistance = 16.0,
    defaultDistance = 9.0,
    defaultYaw = 0.0,
    defaultPitch = 0.0,
    --- Settle = how fast the camera returns to base orbit after drag release.
    settleSpeed = 0.045,
    dragThreshold = 8,
    fov = 42.0,
    collisionProbe = false,
}

Config.Camera = {
    overview = {
        --- Used only as fallback when Config.Scene.overviewCamera is nil.
        distance = 11.0,
        height = 0.0,
        fov = 42.0,
        yaw = 0.0,
        pitch = 0.0,
    },
    focus = {
        distance = 5.5,
        height = 1.4,
        fov = 33.0,
    },
    sky = {
        height = 420.0,
        fov = 50.0,
    },
    descent = {
        endHeight = 28.0,
        fovStart = 48.0,
        fovEnd = 42.0,
        rotationOffset = 15.0,
    },
    smoothing = 0.055,
    --- Look-at glide speed when the focal target moves (lower = silkier pan).
    focalSmoothing = 0.038,
    rotSmoothing = 0.048,
    idleDrift = true,
    idleDriftStrength = 0.018,
    resetSpeed = 0.04,
    --- Slower smoothing while a character is selected — makes switching
    --- between lineup peds feel like a gentle re-frame instead of a snap.
    selection = {
        focalSmoothing = 0.028,
        rotSmoothing = 0.034,
        fovSmoothing = 0.030,
    },
    fov = {
        overview = 42.0,
        focus = 33.0,
        sky = 50.0,
        descent = 48.0,
        ground = 42.0,
    },
}

Config.Highlight = {
    --- Master toggle for SetEntityDrawOutline / *Color / *Shader natives.
    --- A handful of FiveM client builds (and certain GPU + driver combos)
    --- crash inside the entity outline shader when these natives are called
    --- on a streamed-in ped. Set to `false` on those servers to fall back
    --- to an alpha-only highlight (full alpha = hovered/selected, dim = idle).
    --- Hover detection, selection, and NUI details all keep working.
    enabled = true,
    --- Stock mp_m/mp_f freemode peds crash inside the outline shader on hover
    --- for many FiveM client builds; addon/custom ped models are usually fine.
    --- When true (default), freemode slots use alpha highlight only while
    --- custom ped models still get the full outline when enabled = true.
    alphaForFreemode = false,
    outlineColor = { r = 16, g = 185, b = 129 },
    selectedColor = { r = 52, g = 211, b = 153 },
    emptyHoverColor = { r = 16, g = 185, b = 129 },
    --- Outline shader index (FiveM SetEntityDrawOutlineShader):
    --- 0 = thin/neutral, 1 = thick/sharper, 2 = pulse. Defaults to 1
    --- which matches the legacy look.
    outlineShader = 1,
    --- Alpha values used when `enabled = false`. The hover/selected ped is
    --- rendered fully opaque while idle peds dim slightly so the active
    --- target reads clearly without touching the outline natives.
    fallbackIdleAlpha = 200,
    fallbackHoverAlpha = 255,
    fallbackSelectedAlpha = 255,
    --- Empty-slot ghost peds stay translucent regardless of mode.
    fallbackEmptyAlpha = 140,
    fallbackEmptyHoverAlpha = 200,
}

--- Optional secondary fallback for environments where the hover frontend
--- sound also misbehaves (rare but reported alongside the outline crash on
--- the same boxes). Setting `disableHoverSound = true` silences the per-hover
--- audio cue while keeping every other selector sound (select/details/etc).
Config.Hover = Config.Hover or {}
Config.Hover.disableHoverSound = false

--- Performance tuning for the character selection phase.
---
--- preset:
---   high       — default; outline on addon peds, 120+ Hz loops, camera drift
---   balanced   — middle ground for mid-range PCs
---   universal  — low-end / compatibility fallback
---   auto       — starts universal; adaptive governor adjusts at runtime
---
--- Interior/MLO streaming (keepSceneSphere, streamRadius, etc.) is unchanged
--- by preset — those settings live under Config.Scene.interior.
Config.Performance = {
    preset = 'high',
    adaptive = true,
    streamKeepaliveMs = nil,
    streamFocusRefreshMs = nil,
    selectionLoopMs = nil,
    hoverIntervalMs = nil,
    integrityCheckMs = nil,
    hudUpdateMs = nil,
    cameraIdleDrift = true,
    pedSampleHeights = nil,
    useAlphaHighlightFallback = false,
    --- Must stay false for MLO lineups — see Config.Scene.interior.keepSceneSphere.
    relaxStreamAfterLoad = false,
}

--- Visual quality and world-state control during character selection.
Config.Rendering = {
    --- Consistent interior lighting (hour/minute). nil = don't override clock.
    freezeTime = { hour = 22, minute = 0 },
    --- Stop qb-weathersync from fighting the staged timecycle while selecting.
    suppressWeatherSync = true,
    --- Hide ambient peds/vehicles so the lineup isn't cluttered or streamed over.
    suppressWorldPopulation = true,
    --- Interior MLOs often need artificial lights forced on for correct look.
    artificialLights = true,
    --- Default lineup timecycle (profile overrides below).
    --- Strength kept modest so the casino interior stays crisp and readable —
    --- MP_corona_heist_blend adds a warm bloom/haze that washes out ped detail
    --- and the holographic UI at higher strengths ("not clear").
    timecycle = 'MP_corona_heist_blend',
    timecycleStrength = 0.15,
    timecycleEmergency = 'MP_corona_heist_blend',
    timecycleStrengthEmergency = 0.30,
    timecycleMedical = 'int_hospital2_dm',
    timecycleStrengthMedical = 0.24,
    timecycleGarage = 'int_carrier_hanger',
    timecycleStrengthGarage = 0.20,
    timecycleDark = 'V_FIB_IT3',
    timecycleStrengthDark = 0.32,
    --- How far below focal the local player is hidden after the lineup loads.
    playerHideOffset = 50.0,
    --- Periodic collision prime while in selection (ms). 0 = disabled.
    integrityCheckMs = 4000,
}

Config.Interaction = {
    clickDebounceMs = 70,
    --- Max ray length used when picking a ped (meters) — fallback only.
    rayMaxDistance = 120.0,
    --- Tube radius around a ped used to register hover/click (meters).
    pedSelectRadius = 4.5,
    --- Cursor distance to the ped's projected screen-space position, in pixels,
    --- that still counts as a hover. Larger = more forgiving.
    pedSelectScreenRadius = 240,
    --- Empty-slot ghost peds get a slightly larger hit area.
    pedSelectScreenRadiusEmpty = 280,
    --- World heights (meters above ped root) sampled for screen hit-testing.
    --- Covers seated + standing poses in the lineup.
    pedSampleHeights = { 0.35, 0.68, 1.05 },
    --- Score multiplier for the ped already hovered (< 1 keeps hover sticky).
    hoverStickiness = 0.68,
    --- Hover ray pick interval (ms). nil = use Config.Performance preset.
    hoverIntervalMs = nil,
    dragThreshold = 8.0,
    hoverEnabled = true,
    selectionEnabled = true,
    hoverDistance = 80.0,
    hoverEffectStrength = 0.7,
    pedAimHeight = 0.95,
    --- Select on mouse-down when camera drag is off (snappier than release).
    selectOnMouseDown = true,
}

Config.UI = {
    brandTitle = 'Haze Studio',
    brandSubtitle = 'Seleção de Cidadão',
    hologramEnabled = true,
    animationSpeed = 0.52,
    detailsPosition = 'right',
    showControlHints = true,
}

Config.SpawnCinematic = {
    enabled = true,
    skyHeight = 380.0,
    skyRiseDurationMs = 2600,
    flyDurationMs = 5200,
    flyHeight = 320.0,
    hoverDurationMs = 1600,
    descendDurationMs = 4200,
    descendEndHeight = 28.0,
    fovSky = 52.0,
    fovDescend = 46.0,
    fovGround = 40.0,
    fadeOutMs = 800,
    fadeInMs = 950,
    travelFadeDistance = 2200.0,
    travelFadeOutMs = 320,
    travelFadeInMs = 420,
    soundHooks = true,
    --- Per-frame damping (0..1) applied to cinematic camera position / rotation /
    --- FOV so spline samples glide instead of snapping each tick.
    cameraSmoothFactor = 0.12,
    --- Additional smoothing for look-at target while tracking the ped.
    cameraLookAtSmoothFactor = 0.16,
    --- World height above ped feet the fly camera locks onto.
    pedFocusHeight = 0.95,
    --- Radius passed to NewLoadSceneStartSphere at the destination so map
    --- geometry streams in while the camera is still in transit.
    streamingRadius = 120.0,
}

Config.Spawns = {
    {
        id = 'last',
        label = 'Última Localização',
        type = 'last',
        fallback = 'public',
        description = 'Retorne à sua última posição salva na cidade.',
    },
    {
        id = 'police',
        label = 'Departamento de Polícia',
        coords = vec4(441.23, -981.89, 30.69, 90.0),
        description = 'Apresente-se no departamento principal de polícia.',
        jobs = { ['police'] = true, ['sheriff'] = true, ['state'] = true },
    },
    {
        id = 'hospital',
        label = 'Hospital Central',
        coords = vec4(298.54, -584.41, 43.26, 70.0),
        description = 'Apresente-se no centro médico / hospital.',
        jobs = { ['ambulance'] = true, ['ems'] = true, ['doctor'] = true },
    },
    {
        id = 'firefighter',
        label = 'Corpo de Bombeiros',
        coords = vec4(1194.27, -1457.12, 34.86, 90.0),
        description = 'Apresente-se no quartel do corpo de bombeiros.',
        jobs = { ['firefighter'] = true, ['fire'] = true },
    },
    {
        id = 'public',
        label = 'Centro da Cidade',
        coords = vec4(215.76, -810.12, 30.73, 160.0),
        description = 'Desembarque na praça central de Los Santos.',
    },
}

Config.UseQbox = (Config.Framework == "auto" or Config.Framework == "qbox")
Config.MaxCharacters = Config.General.MaxCharacters

Config.Spawn = {
    skySpawnEnabled = true,
    allowedSpawnPoints = { 'last', 'police', 'public', 'hospital', 'firefighter' },
    lastLocationFallback = 'public',
    flyTimeMs = Config.SpawnCinematic.flyDurationMs,
    freezeTimeMs = Config.SpawnCinematic.hoverDurationMs,
    descentTimeMs = Config.SpawnCinematic.descendDurationMs,
}

Config.Audio = {
    enabled = true,
    hover = 'ui_hover',
    select = 'ui_select',
    detailsOpen = 'ui_details_open',
    spawnPress = 'ui_spawn_press',
    skyLaunch = 'sky_launch',
    locationSelect = 'location_select',
    descentPulse = 'descent_pulse',
    finalSpawn = 'final_spawn',
}

--- New-character apartment integration for the SPAWN PICKER. When enabled and
--- the apartment resource (`CharacterCreation.apartmentResource`) is running,
--- brand-new characters get a "Starter Apartment" panel after finishing
--- creation, alongside the usual spawn points. When that resource is not
--- running the picker silently shows only the default spawn locations, so this
--- can be left enabled even on servers without any apartment system.
Config.Apartments = {
    enabled = true,
    --- Show the picker on the very first spawn of a new character only.
    onlyFirstSpawn = true,
    --- Optional extra description appended to each apartment card.
    cardSuffix = 'Free starter apartment',
}

Config.SpawnPreview = {
    enabled = true,
    --- How far (0..1) the smoothed goal glides toward the raw hovered target.
    --- This is the first stage; the camera then follows the smoothed goal.
    hoverGoalSpeed = 0.10,
    --- How far (0..1) the look-at smooths toward the goal each frame.
    hoverPreviewSpeed = 0.016,
    --- How far (0..1) the camera position smooths toward its goal each frame.
    hoverCameraDriftSpeed = 0.014,
    --- Max world-space fraction the look-at shifts toward the hovered location.
    hoverPreviewStrength = 0.55,
    --- Max world-space fraction the camera drifts toward the hovered location.
    hoverCameraDriftStrength = 0.25,
}

Config.Scenes = {
    jobMappings = Config.SceneJobMap,
    fallbackScene = 'neutral',
    lightingProfiles = Config.SceneProfiles,
    animationProfiles = Config.SceneProfiles,
    propLimits = 0,
}

--- Returns the vec4 coords from a slot regardless of whether it's stored as
--- a bare vec4 or as the table form `{ coords = vec4, emote = ... }`.
function Config.GetSlotCoords(slot)
    if not slot then return nil end
    if slot.coords then return slot.coords end
    return slot
end

function Config.GetSlotEmote(slot)
    if not slot then return nil end
    return slot.emote
end

--- Computes the camera look-at focal point from ped slot positions.
function Config.GetSceneFocal()
    local slots = Config.Scene.pedSlots
    if not slots or #slots == 0 then
        return vec3(0.0, 0.0, 0.0)
    end

    local sumX, sumY, sumZ = 0.0, 0.0, 0.0
    for i = 1, #slots do
        local c = Config.GetSlotCoords(slots[i])
        sumX = sumX + c.x
        sumY = sumY + c.y
        sumZ = sumZ + c.z
    end

    local count = #slots
    return vec3(
        sumX / count,
        sumY / count,
        (sumZ / count) + (Config.Scene.focalHeightOffset or 0.0)
    )
end

--- Distance from focal point based on ped lineup span (keeps all peds in frame).
--- Uses the bounding-box diagonal of all slots, not just first/last, so it
--- works with curated non-linear arrangements too.
function Config.GetRecommendedCameraDistance()
    local slots = Config.Scene.pedSlots
    local c = Config.CameraControl
    if not slots or #slots < 2 then
        return c.defaultDistance
    end

    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    for i = 1, #slots do
        local sc = Config.GetSlotCoords(slots[i])
        if sc.x < minX then minX = sc.x end
        if sc.x > maxX then maxX = sc.x end
        if sc.y < minY then minY = sc.y end
        if sc.y > maxY then maxY = sc.y end
    end

    local dx, dy = maxX - minX, maxY - minY
    local span = math.sqrt(dx * dx + dy * dy)
    local distance = span * 1.25 + 5.5
    if distance < c.minDistance then return c.minDistance end
    if distance > c.maxDistance then return c.maxDistance end
    return distance
end

---@param opts? table { newCharacter = boolean, job = string|table }
function Config.GetSpawnOptionsForNui(opts)
    opts = opts or {}
    local newOnly = opts.newCharacter == true

    local rawJob = opts.job
    local jobName = 'unemployed'
    if type(rawJob) == 'table' then
        jobName = tostring(rawJob.name or rawJob.type or 'unemployed'):lower()
    elseif type(rawJob) == 'string' then
        jobName = rawJob:lower()
    end

    local isEmergency = (jobName == 'police' or jobName == 'sheriff' or jobName == 'state'
        or jobName == 'ambulance' or jobName == 'ems' or jobName == 'doctor'
        or jobName == 'firefighter' or jobName == 'fire')

    local options = {}
    for i = 1, #Config.Spawns do
        local spawn = Config.Spawns[i]
        local include = true

        if newOnly and (spawn.type == 'last' or spawn.id == 'last') then
            include = false
        elseif not newOnly then
            if spawn.id == 'last' then
                include = true
            elseif isEmergency then
                -- Jogadores de emergência (polícia, médico, bombeiro): vêem APENAS 'last' e o spawn do seu respectivo trabalho
                if spawn.jobs and spawn.jobs[jobName] then
                    include = true
                else
                    include = false
                end
            else
                -- Jogadores sem trabalho governamental/emergência: vêem APENAS 'last' e 'public' (Centro da Cidade)
                if spawn.id == 'public' then
                    include = true
                else
                    include = false
                end
            end
        end

        if include then
            options[#options + 1] = {
                id = spawn.id,
                label = spawn.label,
                description = spawn.description,
            }
        end
    end
    return options
end

-----------------------------------------------------------------------------
--- Histórias de Chegada — Sistema de Prelúdio e Cenas Cinematográficas
--- (W2F.Prelude + W2F.Arrival)
-----------------------------------------------------------------------------

--- Prelúdio: sequência de freeze de tempo + cartão do personagem + cartão
--- de capítulo. Executado uma única vez na primeira criação de personagem.
Config.Prelude = {
    --- Habilitar ou desabilitar o prelúdio completo (default: true).
    enabled = true,
    --- Velocidade do mundo durante o freeze (0.1 = quase parado).
    timeScale = 0.1,
    --- Duração do cartão do personagem em millisegundos (ágil e impactante).
    freezeDurationMs = 1500,
    --- Duração do cartão de capítulo em millisegundos.
    chapterCardDurationMs = 1400,
}

--- Sistema de Histórias de Chegada
Config.Arrival = {
    --- Habilitar ou desabilitar as histórias de chegada (default: true).
    enabled = true,

    --- Histórias disponíveis e seus destinos
    --- 'container': Chegada clandestina pelo porto
    --- 'plane':     Chegada de avião (cutscene nativa GTA Online)

    --- Configuração da história: Contêiner do Coiote
    container = {
        --- Modelo do contêiner animado (prop do DLC Tuners)
        model = 'tr_prop_tr_container_01a',
        --- Prop de colisão física invisível (prop_ld_container)
        collisionProp = 'prop_ld_container',
        --- Coordenadas de spawn do contêiner no cais asfaltado do porto (Terminal / Pátio de Carga)
        --- (Portas abrem em direção ao norte/pátio, totalmente afastadas da água)
        spawnCoords = vec4(520.39, -2935.94, 6.04, 180.0),
        --- Offset do interior do contêiner (fundo onde os clandestinos ficam sentados)
        interiorOffset = vec3(0.0, 1.8, 0.22),
        --- Offset de câmera exterior (plano frontal das portas abrindo para fora)
        exteriorOffset = vec3(0.0, -7.2, 1.45),
        --- Distância de saída do ped após as portas abrirem
        exitOffset = vec3(0.0, 5.0, 0.0),
        --- Dict e clip da animação de abertura das portas (DLC Tuners trem ig1)
        openDict = 'anim@scripted@player@mission@tunf_train_ig1_container_p1@male@',
        openAnim = 'action_container',
        openPhase = 0.66,
        doorAxis = -1,
        doorOpenMs = 1200,
        --- Distância entre as portas e o destino (gap do MRI = 1.4)
        gap = 1.4,
        --- Piso acima da base do modelo (m)
        floor = 0.12,
        fov = 50.0,
        streamTimeout = 10000,
        blendOutMs = 1200,
        darkness = 'int_extlight_none_dark',
        migrants = { 'a_m_m_mexlabor_01', 'a_m_y_mexthug_01', 'a_m_m_soucent_01' },
        beats = { dark = 2400, impact = 1800, open = 2400, out = 4000 },
        sounds = {
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
    },

    --- Coordenadas de posição segura para cutscene do avião (calçada externa LSIA)
    planeSpawnCoords = vec4(-1037.0, -2737.0, 13.8, 330.0),

    --- Configuração da história: Saída da Penitenciária de Bolingbroke
    prison = {
        spawnCoords = vec4(1846.50, 2586.20, 45.67, 270.0),
        exitCoords  = vec3(1837.20, 2586.20, 45.67),
    },

    --- Configuração da história: Trem de Carga Clandestino (Estação de Davis)
    train = {
        spawnCoords = vec4(264.00, -1205.00, 29.28, 90.0),
        exitCoords  = vec3(264.00, -1198.00, 29.28),
    },

    --- Distribuição de itens e dinheiro conforme a história de chegada:
    ---   * container: sem dinheiro/banco, sem documentos, % chance celular (ex: 20%), vem com 5 cigarros e isqueiro.
    ---   * plane: celular garantido, sem carteira de motorista (mas com RG/id_card), % chance cigarro (ex: 40%), dinheiro normal.
    ---   * prison: R$ 50 de auxílio-soltura do Estado, banco zerado, RG sem CNH, 5 cigarros e isqueiro.
    ---   * train: R$ 20 no bolso, banco zerado, água, bandagem, 2 cigarros, sem documentos formais.
    ---   * default/none: kit padrão completo (qbx_core/config/shared.lua).
    starterPerArrival = {
        container = {
            wipeCash = true,
            wipeBank = true,
            items = {
                { name = 'cigarette', amount = 5 },
                { name = 'lighter', amount = 1 },
                { name = 'phone', amount = 1, chance = 20 }, -- 20% chance de ter escondido um celular
            },
        },
        plane = {
            wipeCash = false,
            wipeBank = false,
            items = {
                { name = 'phone', amount = 1 },
                { name = 'id_card', amount = 1, requireIdCardMeta = true }, -- Com documento de identidade
                { name = 'cigarette', amount = 2, chance = 40 },           -- 40% chance de ter cigarros no bolso
                { name = 'lighter', amount = 1, chance = 40 },
                -- Sem carteira de motorista (driver_license omitido)
            },
        },
        prison = {
            wipeCash = false,
            setCash = 50, -- R$ 50 de auxílio-soltura do Estado
            wipeBank = true,
            items = {
                { name = 'id_card', amount = 1, requireIdCardMeta = true }, -- Registro civil emitido na soltura
                { name = 'cigarette', amount = 5 },
                { name = 'lighter', amount = 1 },
            },
        },
        train = {
            wipeCash = false,
            setCash = 20, -- R$ 20 amarfanhados no bolso
            wipeBank = true,
            items = {
                { name = 'water', amount = 1 },
                { name = 'bandage', amount = 1 },
                { name = 'cigarette', amount = 2 },
            },
        },
        default = {
            -- Segue o starterItems nativo de qbx_core/config/shared.lua
            useFrameworkDefaults = true,
        },
    },
}

