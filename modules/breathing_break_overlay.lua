local M = {}

local config = require("modules.breathing_break_config")

local STATE_PARKED_IDLE = "PARKED_IDLE"
local STATE_TIMER_PICKER = "TIMER_PICKER"
local STATE_COUNTDOWN_ACTIVE = "COUNTDOWN_ACTIVE"
local STATE_DEMAND_GROW = "DEMAND_GROW"
local STATE_RECOVERY_SHRINK = "RECOVERY_SHRINK"
local STATE_PAUSED = "PAUSED"
local STATE_DRAGGING = "DRAGGING"

local ELEMENT_OUTER_FIELD = 1
local ELEMENT_MIDDLE_MEMBRANE = 2
local ELEMENT_CORE_BLOB = 3
local ELEMENT_DROPLET_START = 4
local ELEMENT_DROPLET_END = 10
local ELEMENT_TIMER = 11
local ELEMENT_DEBUG = 12
local ELEMENT_SAUCE_RING = ELEMENT_OUTER_FIELD
local ELEMENT_EGG_WHITE = ELEMENT_MIDDLE_MEMBRANE
local ELEMENT_YOLK = ELEMENT_CORE_BLOB

local canvas = nil
local eventtap = nil
local animationTimer = nil
local stateTimer = nil
local screenWatcher = nil
local chooser = nil

local currentState = STATE_PARKED_IDLE
local previousState = STATE_PARKED_IDLE
local pausedReturnState = STATE_PARKED_IDLE
local canvasMode = "small"
local visible = config.enabled
local showTimer = config.showTimer
local pausedAt = nil
local pausedCountdownRemaining = nil

local parkedCenter = nil
local countdownEndsAt = nil
local lastTimerDurationSeconds = 25 * 60
local lastActivityAt = os.time()

local mouseDownAt = nil
local mouseDownPoint = nil
local mouseDownScreenPoint = nil
local dragOriginParkedCenter = nil
local dragReturnState = nil
local maybeDragging = false

local demandStartAt = nil
local demandScreenFrame = nil
local demandStartCenter = nil
local demandCenter = nil
local demandTarget = nil
local demandRadius = nil
local recoveryStartAt = nil
local recoveryStartedWallAt = nil
local recoveryStartCenter = nil
local recoveryStartRadius = nil

local lastTimerText = nil
local lastDebugText = nil
local lastDrawAt = 0
local auditMetrics = {
  center = nil,
  radius = nil,
  demandProgress = nil,
  timerText = "",
}
local eggAssets = {
  loaded = false,
  warned = false,
  sauce = nil,
  white = nil,
  yolk = nil,
  sizes = {},
  referenceHeight = nil,
}

local coreRadiusMap = {
  0.985, 0.992, 1.000, 1.006, 1.010, 1.012,
  1.008, 1.004, 1.000, 0.998, 1.004, 1.010,
  1.016, 1.020, 1.018, 1.012, 1.004, 0.996,
  0.988, 0.982, 0.976, 0.970, 0.966, 0.964,
  0.968, 0.974, 0.982, 0.990, 0.996, 1.000,
  0.996, 0.990, 0.984, 0.980, 0.982, 0.988,
  0.996, 1.002, 1.006, 1.004, 0.998, 0.990,
  0.982, 0.976, 0.974, 0.978, 0.984, 0.990,
}

local outerA = {
  { -0.10, -1.06 }, { 0.26, -1.04 }, { 0.58, -0.90 }, { 0.86, -0.64 },
  { 1.05, -0.30 }, { 1.10, 0.08 }, { 1.00, 0.44 }, { 0.76, 0.76 },
  { 0.40, 0.98 }, { -0.02, 1.04 }, { -0.42, 0.95 }, { -0.76, 0.72 },
  { -0.98, 0.38 }, { -1.05, -0.02 }, { -0.94, -0.42 }, { -0.68, -0.74 },
  { -0.36, -0.98 },
}

local outerB = {
  { -0.04, -1.10 }, { 0.32, -1.02 }, { 0.64, -0.84 }, { 0.90, -0.56 },
  { 1.02, -0.20 }, { 1.04, 0.18 }, { 0.92, 0.54 }, { 0.66, 0.82 },
  { 0.30, 1.02 }, { -0.12, 1.00 }, { -0.50, 0.88 }, { -0.82, 0.62 },
  { -1.02, 0.28 }, { -1.02, -0.12 }, { -0.86, -0.50 }, { -0.60, -0.82 },
  { -0.28, -1.02 },
}

local middleA = {
  { 0.00, -1.02 }, { 0.34, -0.96 }, { 0.64, -0.78 }, { 0.88, -0.48 },
  { 0.98, -0.10 }, { 0.94, 0.28 }, { 0.76, 0.62 }, { 0.46, 0.86 },
  { 0.10, 0.98 }, { -0.28, 0.94 }, { -0.60, 0.76 }, { -0.84, 0.46 },
  { -0.96, 0.08 }, { -0.90, -0.30 }, { -0.70, -0.64 }, { -0.40, -0.88 },
  { -0.08, -1.00 },
}

local middleB = {
  { 0.04, -0.98 }, { 0.38, -0.90 }, { 0.68, -0.70 }, { 0.86, -0.38 },
  { 0.94, 0.00 }, { 0.88, 0.36 }, { 0.66, 0.68 }, { 0.36, 0.90 },
  { -0.02, 0.98 }, { -0.36, 0.88 }, { -0.66, 0.66 }, { -0.86, 0.34 },
  { -0.92, -0.04 }, { -0.84, -0.40 }, { -0.62, -0.70 }, { -0.32, -0.92 },
  { 0.02, -1.00 },
}

local dropletShapeA = {
  { 0.00, -1.00 }, { 0.38, -0.90 }, { 0.72, -0.62 }, { 0.94, -0.22 },
  { 0.92, 0.24 }, { 0.68, 0.66 }, { 0.30, 0.92 }, { -0.14, 0.96 },
  { -0.54, 0.78 }, { -0.84, 0.42 }, { -0.94, -0.04 }, { -0.80, -0.48 },
  { -0.48, -0.82 },
}

local dropletShapeB = {
  { 0.04, -0.96 }, { 0.44, -0.84 }, { 0.76, -0.54 }, { 0.90, -0.14 },
  { 0.84, 0.32 }, { 0.60, 0.72 }, { 0.20, 0.94 }, { -0.22, 0.90 },
  { -0.60, 0.70 }, { -0.86, 0.32 }, { -0.90, -0.12 }, { -0.72, -0.56 },
  { -0.40, -0.86 },
}

local dropletAnchors = {
  { x = -0.42, y = -0.04, r = 0.055, phase = 0.0 },
  { x = 0.48, y = -0.18, r = 0.060, phase = 1.7 },
  { x = 0.18, y = 0.44, r = 0.035, phase = 3.1 },
}

local function now()
  if hs and hs.timer and hs.timer.secondsSinceEpoch then
    return hs.timer.secondsSinceEpoch()
  end
  return os.time()
end

local function clamp(value, minValue, maxValue)
  return math.max(minValue, math.min(maxValue, value))
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function lerpPoint(a, b, t)
  return { x = lerp(a.x, b.x, t), y = lerp(a.y, b.y, t) }
end

local function easeOutCubic(x)
  local t = clamp(x, 0, 1)
  return 1 - math.pow(1 - t, 3)
end

local function easeInOutCubic(x)
  local t = clamp(x, 0, 1)
  if t < 0.5 then
    return 4 * t * t * t
  end
  return 1 - math.pow(-2 * t + 2, 3) / 2
end

local function distance(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local function colorWithAlpha(color, alpha)
  local copied = {}
  for key, value in pairs(color) do
    copied[key] = value
  end
  copied.alpha = alpha
  return copied
end

local function persistedKey(name)
  return "breathingBreak." .. name
end

local function smallCanvasSize()
  return config.smallCanvasSize or config.canvasSize or 200
end

local function smallCoreRadius()
  return config.smallCoreRadius or 34
end

local function eggThemeEnabled()
  return config.visualTheme ~= "blackhole"
end

local function smallEggSize()
  return config.smallEggSize or 118
end

local function smallHitRadius()
  if eggThemeEnabled() then
    return smallEggSize() * 0.48
  end
  return smallCoreRadius()
end

local function assetPath(name)
  return (config.assetDirectory or (os.getenv("HOME") .. "/.hammerspoon/egg-break/assets")) .. "/" .. name
end

local function centeredFrame(cx, cy, size)
  return {
    x = cx - size / 2,
    y = cy - size / 2,
    w = size,
    h = size,
  }
end

local function smallCoreLocalCenter()
  local size = smallCanvasSize()
  return { x = size / 2, y = size * 0.43 }
end

local function mainScreenFrame()
  return hs.screen.mainScreen():frame()
end

local function defaultParkedCenter()
  local frame = mainScreenFrame()
  return {
    x = frame.x + frame.w - (config.marginX or 42) - smallHitRadius(),
    y = frame.y + (config.marginY or 52) + smallHitRadius(),
  }
end

local function clampParkedCenter(point)
  local frame = mainScreenFrame()
  local padding = smallHitRadius() + (config.hitPadding or 10)
  return {
    x = clamp(point.x, frame.x + padding, frame.x + frame.w - padding),
    y = clamp(point.y, frame.y + padding, frame.y + frame.h - padding),
  }
end

local function formatDuration(seconds)
  local minutes = math.max(0, math.ceil(seconds / 60))
  if minutes < 60 then
    return string.format("%dm", minutes)
  end

  local hours = math.floor(minutes / 60)
  local remainingMinutes = minutes % 60
  return string.format("%dh %dm", hours, remainingMinutes)
end

local function remainingCountdownSeconds()
  if not countdownEndsAt then
    return nil
  end
  return math.max(0, countdownEndsAt - os.time())
end

local function persistState()
  if parkedCenter then
    hs.settings.set(persistedKey("parkedPosition"), { x = parkedCenter.x, y = parkedCenter.y })
  end
  hs.settings.set(persistedKey("lastTimerDurationSeconds"), lastTimerDurationSeconds)
  hs.settings.set(persistedKey("showTimer"), showTimer)
end

local function restoreState()
  local savedPosition = hs.settings.get(persistedKey("parkedPosition"))
  local savedDuration = hs.settings.get(persistedKey("lastTimerDurationSeconds"))
  local savedShowTimer = hs.settings.get(persistedKey("showTimer"))

  if type(savedPosition) == "table" and type(savedPosition.x) == "number" and type(savedPosition.y) == "number" then
    parkedCenter = clampParkedCenter(savedPosition)
  else
    parkedCenter = defaultParkedCenter()
  end

  if type(savedDuration) == "number" and savedDuration > 0 then
    lastTimerDurationSeconds = savedDuration
  end

  if type(savedShowTimer) == "boolean" then
    showTimer = savedShowTimer
  else
    showTimer = config.showTimer
  end
end

local function catmullRomClosedPath(points)
  local path = {
    { x = points[1].x, y = points[1].y },
  }
  local count = #points

  for i = 1, count do
    local p0 = points[((i - 2) % count) + 1]
    local p1 = points[i]
    local p2 = points[(i % count) + 1]
    local p3 = points[((i + 1) % count) + 1]

    table.insert(path, {
      x = p2.x,
      y = p2.y,
      c1x = p1.x + (p2.x - p0.x) / 6,
      c1y = p1.y + (p2.y - p0.y) / 6,
      c2x = p2.x - (p3.x - p1.x) / 6,
      c2y = p2.y - (p3.y - p1.y) / 6,
    })
  end

  return path
end

local function morphValue(a, b, t)
  return a + (b - a) * t
end

local function morphShape(shapeA, shapeB, amount, cx, cy, scaleX, scaleY)
  local points = {}
  local yScale = scaleY or scaleX

  for i = 1, #shapeA do
    local x = morphValue(shapeA[i][1], shapeB[i][1], amount)
    local y = morphValue(shapeA[i][2], shapeB[i][2], amount)
    table.insert(points, { x = cx + x * scaleX, y = cy + y * yScale })
  end

  return catmullRomClosedPath(points)
end

local function makeRoundedCorePath(cx, cy, radius, t)
  local points = {}
  local n = #coreRadiusMap
  local morph = math.sin(t / 18.0) * 0.006
  local breath = 1 + math.sin(t * 2 * math.pi / 9.5) * 0.015

  for i = 1, n do
    local angle = (i - 1) / n * math.pi * 2
    local slowOrganic =
      math.sin(t / 22.0 + i * 0.37) * morph +
      math.sin(t / 31.0 + i * 0.19) * morph * 0.45
    local rr = radius * breath * (coreRadiusMap[i] + slowOrganic)

    table.insert(points, {
      x = cx + math.cos(angle) * rr,
      y = cy + math.sin(angle) * rr,
    })
  end

  return catmullRomClosedPath(points)
end

local function drawBlobLayer(canvasObject, index, path, fillColor)
  canvasObject[index].action = "strokeAndFill"
  canvasObject[index].coordinates = path
  canvasObject[index].fillColor = fillColor
  canvasObject[index].strokeColor = colorWithAlpha(fillColor, (fillColor.alpha or 0) * 0.24)
end

local function drawDroplets(canvasObject, startIndex, center, pressure, t)
  local dropletCount = pressure > 0.45 and 3 or 2
  local alphaMultiplier = center.alphaMultiplier or 1

  for index = ELEMENT_DROPLET_START, ELEMENT_DROPLET_END do
    local dropletNumber = index - startIndex + 1
    local droplet = dropletAnchors[dropletNumber]
    if not droplet or dropletNumber > dropletCount or pressure < 0.02 then
      canvasObject[index].action = "skip"
    else
      local amount = (math.sin(t * 2 * math.pi / (28 + dropletNumber * 5) + droplet.phase) + 1) / 2
      local settle = lerp(0.72, 1.0, pressure)
      local dx = math.sin(t / 11.0 + droplet.phase) * 2.0
      local dy = math.cos(t / 13.0 + droplet.phase) * 1.6
      local rr = droplet.r * center.fieldRadius * settle * (1 + math.sin(t / 9.0 + droplet.phase) * 0.08)
      local dropletCx = center.x + droplet.x * center.fieldRadius * settle + dx
      local dropletCy = center.y + droplet.y * center.fieldRadius * settle + dy
      local dropletAlpha = lerp(0.10, config.dropletColor.alpha or 0.55, pressure) * alphaMultiplier
      local path = morphShape(dropletShapeA, dropletShapeB, amount, dropletCx, dropletCy, rr, rr * 0.96)

      drawBlobLayer(canvasObject, index, path, colorWithAlpha(config.dropletColor, dropletAlpha))
    end
  end
end

local function drawOrganism(cx, cy, radius, pressure, t, alphaMultiplier)
  local middleRadius = radius * lerp(1.25, 1.55, pressure)
  local outerRadius = radius * lerp(1.8, 2.35, pressure)
  local outerMorph = (math.sin(t * 2 * math.pi / 42.0) + 1) / 2
  local middleMorph = (math.sin(t * 2 * math.pi / 26.0 + 0.7) + 1) / 2
  local outerBreath = 1 + math.sin(t * 2 * math.pi / 34.0) * 0.018
  local middleBreath = 1 + math.sin(t * 2 * math.pi / 22.0 + 1.2) * 0.020
  local middleCx = cx + math.sin(t / 29.0) * 2.2 * pressure
  local middleCy = cy + math.cos(t / 33.0) * 2.2 * pressure
  local outerCx = cx - math.sin(t / 41.0) * 3.0 * pressure
  local outerCy = cy - math.cos(t / 47.0) * 2.0 * pressure

  drawBlobLayer(canvas, ELEMENT_OUTER_FIELD,
    morphShape(outerA, outerB, outerMorph, outerCx, outerCy, outerRadius * outerBreath, outerRadius * outerBreath * 0.96),
    colorWithAlpha(config.outerColor, lerp(0.04, 0.16, pressure) * alphaMultiplier))
  drawBlobLayer(canvas, ELEMENT_MIDDLE_MEMBRANE,
    morphShape(middleA, middleB, middleMorph, middleCx, middleCy, middleRadius * middleBreath, middleRadius * middleBreath * 0.98),
    colorWithAlpha(config.middleColor, lerp(0.08, 0.22, pressure) * alphaMultiplier))
  drawBlobLayer(canvas, ELEMENT_CORE_BLOB,
    makeRoundedCorePath(cx, cy, radius, t),
    colorWithAlpha(config.coreColor, lerp(0.82, 0.92, pressure) * alphaMultiplier))

  drawDroplets(canvas, ELEMENT_DROPLET_START, {
    x = middleCx,
    y = middleCy,
    fieldRadius = middleRadius,
    alphaMultiplier = alphaMultiplier,
  }, pressure, t)
end

local function loadEggAssets(showAlerts)
  if eggAssets.loaded then
    return true
  end

  local required = {
    { key = "sauce", name = "egg_sauce_ring.png" },
    { key = "white", name = "egg_white.png" },
    { key = "yolk", name = "egg_yolk.png" },
  }
  local missing = {}

  for _, asset in ipairs(required) do
    local path = assetPath(asset.name)
    local image = hs.image.imageFromPath(path)
    if image then
      eggAssets[asset.key] = image
      local ok, imageSize = pcall(function()
        return image:size()
      end)
      if ok and imageSize and imageSize.w and imageSize.h then
        eggAssets.sizes[asset.key] = { w = imageSize.w, h = imageSize.h }
      end
    else
      table.insert(missing, asset.name)
    end
  end

  eggAssets.loaded = #missing == 0
  eggAssets.referenceHeight = 1
  for _, size in pairs(eggAssets.sizes) do
    eggAssets.referenceHeight = math.max(eggAssets.referenceHeight, size.h or 1)
  end
  if not eggAssets.loaded and showAlerts and not eggAssets.warned then
    eggAssets.warned = true
    hs.alert.show("Missing egg asset: " .. table.concat(missing, ", "))
  end

  return eggAssets.loaded
end

local function resetElementTransform(index)
  canvas[index].transformation = { m11 = 1, m12 = 0, m21 = 0, m22 = 1, tX = 0, tY = 0 }
end

local function hideBlackholeDroplets()
  for index = ELEMENT_DROPLET_START, ELEMENT_DROPLET_END do
    canvas[index].action = "skip"
  end
end

local function eggLayerSpeeds(state)
  if state == STATE_DEMAND_GROW then
    return config.demandSauceRotationSpeed or 0.55, config.demandWhiteRotationSpeed or -0.12
  elseif state == STATE_RECOVERY_SHRINK then
    return config.recoverySauceRotationSpeed or 0.18, config.recoveryWhiteRotationSpeed or -0.04
  elseif state == STATE_COUNTDOWN_ACTIVE then
    return config.countdownSauceRotationSpeed or 0.25, config.countdownWhiteRotationSpeed or -0.06
  end

  return config.parkedSauceRotationSpeed or 0.15, config.parkedWhiteRotationSpeed or -0.04
end

local function eggRegistrationConstrained()
  return config.eggLayerRegistrationConstraint ~= false
end

local function eggUsesUnifiedLayerFrame()
  return config.eggUseUnifiedLayerFrame ~= false
end

local function constrainedBreath(t, period, phase, requestedAmplitude, maxAmplitude)
  local amplitude = math.min(requestedAmplitude or 0, maxAmplitude or requestedAmplitude or 0)
  return 1 + math.sin(t / period + phase) * amplitude
end

local function eggLayerRotations(state, pressure, t, sauceSpeed, whiteSpeed)
  if not eggRegistrationConstrained() then
    return t * sauceSpeed, t * whiteSpeed
  end

  local stateMultiplier = 0.42
  if state == STATE_DEMAND_GROW then
    stateMultiplier = lerp(0.58, 1.0, pressure)
  elseif state == STATE_COUNTDOWN_ACTIVE then
    stateMultiplier = 0.55
  elseif state == STATE_RECOVERY_SHRINK then
    stateMultiplier = 0.40
  end

  local sauceLimit = (config.maxSauceRotationDegrees or 3.0) * stateMultiplier
  local whiteLimit = (config.maxWhiteRotationDegrees or 1.1) * stateMultiplier
  local sauceRotation = math.sin(t / 34.0) * sauceLimit
  local whiteRotation = math.sin(t / 41.0 + 1.7) * -whiteLimit

  return sauceRotation, whiteRotation
end

local function drawEggImageLayer(index, image, frame, alpha, rotationDegrees, center)
  if not image then
    canvas[index].action = "skip"
    resetElementTransform(index)
    return
  end

  canvas[index].type = "image"
  canvas[index].action = "fill"
  canvas[index].image = image
  canvas[index].frame = frame
  canvas[index].imageAlpha = alpha
  canvas[index].imageScaling = "scaleProportionally"
  resetElementTransform(index)
  pcall(function()
    canvas:rotateElement(index, rotationDegrees, center, false)
  end)
end

local function eggAssetFrame(key, center, visualSize, scale, breath)
  local imageSize = eggAssets.sizes[key] or { w = eggAssets.referenceHeight or 1, h = eggAssets.referenceHeight or 1 }
  local referenceHeight = eggAssets.referenceHeight or imageSize.h or 1
  local layerScale = scale * breath
  local width = visualSize * (imageSize.w / referenceHeight) * layerScale
  local height = visualSize * (imageSize.h / referenceHeight) * layerScale
  return {
    x = center.x - width / 2,
    y = center.y - height / 2,
    w = width,
    h = height,
  }
end

local function eggUnifiedFrame(center, visualSize)
  local imageSize = eggAssets.sizes.sauce or eggAssets.sizes.white or eggAssets.sizes.yolk or {
    w = eggAssets.referenceHeight or 1,
    h = eggAssets.referenceHeight or 1,
  }
  local referenceHeight = eggAssets.referenceHeight or imageSize.h or 1
  local width = visualSize * (imageSize.w / referenceHeight)
  local height = visualSize
  return centeredFrame(center.x, center.y, math.max(width, height)), {
    x = center.x - width / 2,
    y = center.y - height / 2,
    w = width,
    h = height,
  }
end

local function drawEggOrganism(center, size, state, progress, t, alphaMultiplier)
  loadEggAssets(false)
  local pressure = clamp(progress or 0, 0, 1)
  local sauceSpeed, whiteSpeed = eggLayerSpeeds(state)
  local sauceBreath = 1
  local whiteBreath = 1
  local yolkBreath = 1
  if config.eggLayerBreathEnabled then
    sauceBreath = 1 + math.sin(t / 11.0 + 1.2) * (config.sauceBreathAmplitude or 0.012)
    whiteBreath = 1 + math.sin(t / 8.0) * (config.whiteBreathAmplitude or 0.018)
    yolkBreath = 1 + math.sin(t / 6.5 + 0.4) * (config.yolkBreathAmplitude or 0.010)
  end
  if config.eggLayerBreathEnabled and eggRegistrationConstrained() then
    sauceBreath = constrainedBreath(t, 13.0, 1.2, config.sauceBreathAmplitude or 0.012, config.maxSauceBreathAmplitude or 0.004)
    whiteBreath = constrainedBreath(t, 13.0, 0.0, config.whiteBreathAmplitude or 0.018, config.maxWhiteBreathAmplitude or 0.004)
    yolkBreath = constrainedBreath(t, 8.5, 0.4, config.yolkBreathAmplitude or 0.010, config.maxYolkBreathAmplitude or 0.006)
  end
  local sauceCenter = {
    x = center.x + (config.sauceOffsetX or 4),
    y = center.y + (config.sauceOffsetY or 2),
  }
  local whiteCenter = {
    x = center.x + (config.whiteOffsetX or 0),
    y = center.y + (config.whiteOffsetY or 0),
  }
  local yolkCenter = {
    x = center.x + (config.yolkOffsetX or 1),
    y = center.y + (config.yolkOffsetY or 3),
  }
  local sauceFrame = nil
  local whiteFrame = nil
  local yolkFrame = nil
  if eggUsesUnifiedLayerFrame() then
    local _, frame = eggUnifiedFrame(center, size)
    sauceFrame = frame
    whiteFrame = frame
    yolkFrame = frame
    sauceCenter = center
    whiteCenter = center
    yolkCenter = center
  else
    sauceFrame = eggAssetFrame("sauce", sauceCenter, size, config.sauceScale or 1.0, sauceBreath)
    whiteFrame = eggAssetFrame("white", whiteCenter, size, config.whiteScale or 1.0, whiteBreath)
    yolkFrame = eggAssetFrame("yolk", yolkCenter, size, config.yolkScale or 1.0, yolkBreath)
  end
  local sauceAlpha = lerp(0.82, 1.0, pressure) * alphaMultiplier
  local whiteAlpha = lerp(0.90, 1.0, pressure) * alphaMultiplier
  local yolkAlpha = lerp(0.94, 1.0, pressure) * alphaMultiplier
  local sauceRotation, whiteRotation = eggLayerRotations(state, pressure, t, sauceSpeed, whiteSpeed)

  hideBlackholeDroplets()

  drawEggImageLayer(ELEMENT_SAUCE_RING, eggAssets.sauce, sauceFrame, sauceAlpha, sauceRotation, sauceCenter)
  drawEggImageLayer(ELEMENT_EGG_WHITE, eggAssets.white, whiteFrame, whiteAlpha, whiteRotation, whiteCenter)
  drawEggImageLayer(ELEMENT_YOLK, eggAssets.yolk, yolkFrame, yolkAlpha, 0, yolkCenter)
end

local function drawVisualOrganism(cx, cy, size, pressure, t, alphaMultiplier)
  if eggThemeEnabled() then
    drawEggOrganism({ x = cx, y = cy }, size, currentState, pressure, t, alphaMultiplier)
  else
    drawOrganism(cx, cy, size, pressure, t, alphaMultiplier)
  end
end

local function isSmallInteractiveState()
  return currentState == STATE_PARKED_IDLE or currentState == STATE_COUNTDOWN_ACTIVE
end

local function isPointInsideCore(point)
  local core = smallCoreLocalCenter()
  local dx = point.x - core.x
  local dy = point.y - core.y
  return math.sqrt(dx * dx + dy * dy) <= smallHitRadius() + (config.hitPadding or 10)
end

local function isScreenPointInsideParkedCore(point)
  if not parkedCenter then
    return false
  end

  local dx = point.x - parkedCenter.x
  local dy = point.y - parkedCenter.y
  return math.sqrt(dx * dx + dy * dy) <= smallHitRadius() + (config.hitPadding or 10)
end

local function updateCanvasFrameForParkedPosition()
  if not canvas or not parkedCenter then
    return
  end

  local core = smallCoreLocalCenter()
  local size = smallCanvasSize()
  canvas:frame({
    x = parkedCenter.x - core.x,
    y = parkedCenter.y - core.y,
    w = size,
    h = size,
  })
end

local function updateCanvasFrameForFullScreen()
  if not canvas then
    return
  end

  demandScreenFrame = mainScreenFrame()
  canvas:frame(demandScreenFrame)
end

local function applyCanvasWindowBehavior()
  if not canvas then
    return
  end

  pcall(function()
    canvas:clickActivating(false)
  end)

  local behaviors = {}
  if config.visibleOnAllSpaces then
    table.insert(behaviors, "canJoinAllSpaces")
  end
  if config.tryFullscreenOverlay then
    table.insert(behaviors, "fullScreenAuxiliary")
  end
  table.insert(behaviors, "stationary")
  table.insert(behaviors, "ignoresCycle")

  pcall(function()
    canvas:behaviorAsLabels(behaviors)
  end)
  pcall(function()
    canvas:level(config.tryFullscreenOverlay and "screenSaver" or "floating")
  end)
  pcall(function()
    canvas:bringToFront(config.tryFullscreenOverlay)
  end)
end

local function setSmallInteractivity(enabled)
  if not canvas then
    return
  end

  if enabled then
    canvas:mouseCallback(function(_, message, elementId, x, y)
      M.handleCanvasMouse(message, { x = x, y = y }, elementId)
    end)
    canvas:canvasMouseEvents(true, true, false, true)
  else
    canvas:mouseCallback(nil)
    canvas:canvasMouseEvents(false, false, false, false)
  end
end

local function enterSmallCanvasMode()
  canvasMode = "small"
  updateCanvasFrameForParkedPosition()
  setSmallInteractivity(isSmallInteractiveState())
  applyCanvasWindowBehavior()
end

local function enterFullScreenCanvasMode()
  canvasMode = "full"
  updateCanvasFrameForFullScreen()
  setSmallInteractivity(false)
  applyCanvasWindowBehavior()
end

local function computeDemandMaxRadius()
  local frame = demandScreenFrame or mainScreenFrame()
  local screenArea = frame.w * frame.h
  local targetArea = screenArea * (config.maxDemandCoverage or 0.50)
  local maxRadius = math.sqrt(targetArea / math.pi)
  return math.min(maxRadius, math.min(frame.w, frame.h) * 0.48)
end

local function computeDemandMaxEggSize()
  local frame = demandScreenFrame or mainScreenFrame()
  local screenArea = frame.w * frame.h
  local targetArea = screenArea * (config.maxDemandCoverage or 0.50)
  local compensation = config.eggVisibleScaleCompensation or 1.8
  local maxCanvasShortSide = config.maxDemandEggCanvasShortSide or 1.65
  local maxSize = math.sqrt(targetArea) * compensation
  return math.min(maxSize, math.min(frame.w, frame.h) * maxCanvasShortSide)
end

local function maxDemandVisualSize()
  if eggThemeEnabled() then
    return computeDemandMaxEggSize()
  end
  return computeDemandMaxRadius()
end

local function smallVisualSize()
  if eggThemeEnabled() then
    return smallEggSize()
  end
  return smallCoreRadius()
end

local function pickNewDemandTarget()
  local frame = demandScreenFrame or mainScreenFrame()
  local size = demandRadius or smallVisualSize()
  local margin = math.max(80, size * 0.42)
  local minX = frame.x + margin
  local maxX = frame.x + frame.w - margin
  local minY = frame.y + math.max(margin, 90)
  local maxY = frame.y + frame.h - margin

  if maxX <= minX then
    minX = frame.x + frame.w * 0.35
    maxX = frame.x + frame.w * 0.65
  end
  if maxY <= minY then
    minY = frame.y + frame.h * 0.35
    maxY = frame.y + frame.h * 0.65
  end

  return {
    x = minX + math.random() * (maxX - minX),
    y = minY + math.random() * (maxY - minY),
  }
end

local function setState(nextState)
  if currentState ~= STATE_TIMER_PICKER and currentState ~= STATE_DRAGGING and currentState ~= STATE_PAUSED then
    previousState = currentState
  end
  currentState = nextState
  setSmallInteractivity(isSmallInteractiveState())
end

local function startCountdown(durationSeconds)
  lastTimerDurationSeconds = durationSeconds
  countdownEndsAt = os.time() + durationSeconds
  demandStartAt = nil
  recoveryStartAt = nil
  setState(STATE_COUNTDOWN_ACTIVE)
  enterSmallCanvasMode()
  persistState()
end

local function enterParkedIdle()
  countdownEndsAt = nil
  demandStartAt = nil
  demandTarget = nil
  demandCenter = nil
  demandRadius = nil
  recoveryStartAt = nil
  recoveryStartedWallAt = nil
  maybeDragging = false
  setState(STATE_PARKED_IDLE)
  enterSmallCanvasMode()
  persistState()
end

local function enterDemandGrow(fromRecovery)
  local frame = mainScreenFrame()
  demandScreenFrame = frame
  demandStartAt = fromRecovery and (now() - (config.growToMaxSeconds or 180)) or now()
  demandStartCenter = demandCenter or { x = parkedCenter.x, y = parkedCenter.y }
  demandCenter = demandCenter or { x = parkedCenter.x, y = parkedCenter.y }
  demandRadius = demandRadius or smallVisualSize()
  demandTarget = pickNewDemandTarget()
  countdownEndsAt = nil
  recoveryStartAt = nil
  recoveryStartedWallAt = nil
  setState(STATE_DEMAND_GROW)
  enterFullScreenCanvasMode()
end

local function enterRecoveryShrink()
  recoveryStartAt = now()
  recoveryStartedWallAt = os.time()
  recoveryStartCenter = demandCenter and { x = demandCenter.x, y = demandCenter.y } or { x = parkedCenter.x, y = parkedCenter.y }
  recoveryStartRadius = demandRadius or maxDemandVisualSize()
  setState(STATE_RECOVERY_SHRINK)
  enterFullScreenCanvasMode()
end

local function updateTimerText(text)
  if not canvas then
    return
  end

  local value = showTimer and (text or "") or ""
  auditMetrics.timerText = value
  if value ~= lastTimerText then
    canvas[ELEMENT_TIMER].text = value
    lastTimerText = value
  end
end

local function updateDebugText(radius)
  if not canvas then
    return
  end

  if not config.debug and not config.debugVisualAudit then
    canvas[ELEMENT_DEBUG].text = ""
    lastDebugText = nil
    return
  end

  local remaining = remainingCountdownSeconds() or 0
  local inactive = os.time() - lastActivityAt
  local center = auditMetrics.center or { x = 0, y = 0 }
  local progress = auditMetrics.demandProgress
  local progressText = progress and string.format("%.2f", progress) or "-"
  local text = string.format(
    "%s %s r:%d c:%d,%d p:%s idle:%ds rem:%ds txt:%s",
    currentState,
    canvasMode,
    math.floor(radius or 0),
    math.floor(center.x or 0),
    math.floor(center.y or 0),
    progressText,
    inactive,
    remaining,
    auditMetrics.timerText or ""
  )
  if text ~= lastDebugText then
    canvas[ELEMENT_DEBUG].text = text
    lastDebugText = text
  end
end

local function drawSmall(t, alphaMultiplier)
  local core = smallCoreLocalCenter()
  local radius = smallVisualSize()
  local pressure = currentState == STATE_COUNTDOWN_ACTIVE and 0.18 or 0.08
  local timerText = ""

  if currentState == STATE_COUNTDOWN_ACTIVE then
    timerText = formatDuration(remainingCountdownSeconds() or 0)
  elseif currentState == STATE_TIMER_PICKER then
    timerText = "set"
  elseif currentState == STATE_DRAGGING then
    timerText = "move"
  end

  drawVisualOrganism(core.x, core.y, radius, pressure, t, alphaMultiplier)
  auditMetrics.center = { x = core.x, y = core.y }
  auditMetrics.radius = radius
  auditMetrics.demandProgress = nil
  canvas[ELEMENT_TIMER].frame = {
    x = core.x - 48,
    y = core.y + radius * 0.52 + 6,
    w = 96,
    h = 22,
  }
  canvas[ELEMENT_TIMER].textColor = colorWithAlpha(config.timerColor, currentState == STATE_COUNTDOWN_ACTIVE and 0.62 or 0.38)
  updateTimerText(timerText)
  updateDebugText(radius)
end

local function drawDemand(t, dt, alphaMultiplier)
  local frame = demandScreenFrame or mainScreenFrame()
  local elapsed = math.max(0, t - (demandStartAt or t))
  local progress = clamp(elapsed / (config.growToMaxSeconds or 180), 0, 1)
  local targetRadius = maxDemandVisualSize()
  demandRadius = lerp(smallVisualSize(), targetRadius, easeOutCubic(progress))

  if not demandCenter then
    demandCenter = { x = parkedCenter.x, y = parkedCenter.y }
  end
  if not demandTarget or distance(demandCenter, demandTarget) < 20 then
    demandTarget = pickNewDemandTarget()
  end

  local step = 1 - math.exp(-dt / 18)
  demandCenter = lerpPoint(demandCenter, demandTarget, step)

  local cx = demandCenter.x - frame.x
  local cy = demandCenter.y - frame.y
  drawVisualOrganism(cx, cy, demandRadius, lerp(0.35, 1.0, progress), t, alphaMultiplier)
  auditMetrics.center = { x = cx, y = cy }
  auditMetrics.radius = demandRadius
  auditMetrics.demandProgress = progress
  updateTimerText("")
  updateDebugText(demandRadius)
end

local function drawRecovery(t, alphaMultiplier)
  local frame = demandScreenFrame or mainScreenFrame()
  local duration = config.recoveryShrinkSeconds or 32
  local elapsed = math.max(0, t - (recoveryStartAt or t))
  local progress = clamp(elapsed / duration, 0, 1)
  local eased = easeInOutCubic(progress)
  local center = lerpPoint(recoveryStartCenter or parkedCenter, parkedCenter, eased)
  local radius = lerp(recoveryStartRadius or smallVisualSize(), smallVisualSize(), eased)
  demandCenter = center
  demandRadius = radius

  drawVisualOrganism(center.x - frame.x, center.y - frame.y, radius, 1 - eased * 0.78, t, alphaMultiplier)
  auditMetrics.center = { x = center.x - frame.x, y = center.y - frame.y }
  auditMetrics.radius = radius
  auditMetrics.demandProgress = progress
  updateTimerText("")
  updateDebugText(radius)

  if progress >= 1 then
    enterParkedIdle()
  end
end

local function drawPaused(t)
  local alphaMultiplier = 0.34
  if canvasMode == "small" then
    local core = smallCoreLocalCenter()
    local radius = smallVisualSize()
    drawVisualOrganism(core.x, core.y, radius, 0.08, t, alphaMultiplier)
    auditMetrics.center = { x = core.x, y = core.y }
    auditMetrics.radius = radius
    auditMetrics.demandProgress = nil
    canvas[ELEMENT_TIMER].frame = {
      x = core.x - 48,
      y = core.y + radius * 0.52 + 6,
      w = 96,
      h = 22,
    }
    canvas[ELEMENT_TIMER].textColor = colorWithAlpha(config.timerColor, 0.28)
    updateTimerText("pause")
    updateDebugText(radius)
    return
  end

  local frame = demandScreenFrame or mainScreenFrame()
  local center = demandCenter or parkedCenter
  local radius = demandRadius or smallVisualSize()
  drawVisualOrganism(center.x - frame.x, center.y - frame.y, radius, 0.35, t, alphaMultiplier)
  auditMetrics.center = { x = center.x - frame.x, y = center.y - frame.y }
  auditMetrics.radius = radius
  auditMetrics.demandProgress = nil
  updateTimerText("")
  updateDebugText(radius)
end

local function drawFrame()
  if not canvas then
    return
  end

  local t = now()
  local dt = lastDrawAt > 0 and math.min(1, math.max(0, t - lastDrawAt)) or 1 / math.max(1, config.fps)
  lastDrawAt = t

  if visible and not canvas:isShowing() then
    canvas:show()
  end

  if currentState == STATE_PAUSED then
    drawPaused(t)
  elseif canvasMode == "small" then
    local alphaMultiplier = 1
    drawSmall(t, alphaMultiplier)
  elseif currentState == STATE_RECOVERY_SHRINK then
    drawRecovery(t, 1)
  else
    drawDemand(t, dt, 1)
  end

  if visible then
    pcall(function()
      canvas:bringToFront(config.tryFullscreenOverlay)
    end)
  end
end

local function createCanvas()
  local size = smallCanvasSize()
  canvas = hs.canvas.new({ x = 0, y = 0, w = size, h = size })
  local useEggImages = eggThemeEnabled() and loadEggAssets(true)
  local elements = {}

  if eggThemeEnabled() then
    table.insert(elements, {
      id = "eggSauceRing",
      type = "image",
      action = useEggImages and "fill" or "skip",
      image = useEggImages and eggAssets.sauce or nil,
      imageAlpha = 1,
      imageScaling = "scaleProportionally",
      frame = { x = 0, y = 0, w = 1, h = 1 },
      antialias = true,
    })
    table.insert(elements, {
      id = "eggWhite",
      type = "image",
      action = useEggImages and "fill" or "skip",
      image = useEggImages and eggAssets.white or nil,
      imageAlpha = 1,
      imageScaling = "scaleProportionally",
      frame = { x = 0, y = 0, w = 1, h = 1 },
      antialias = true,
    })
    table.insert(elements, {
      id = "eggYolk",
      type = "image",
      action = useEggImages and "fill" or "skip",
      image = useEggImages and eggAssets.yolk or nil,
      imageAlpha = 1,
      imageScaling = "scaleProportionally",
      frame = { x = 0, y = 0, w = 1, h = 1 },
      antialias = true,
      trackMouseDown = true,
      trackMouseUp = true,
      trackMouseEnterExit = false,
      trackMouseMove = true,
    })
  else
    elements = {
      {
        id = "outerField",
        type = "segments",
        action = "strokeAndFill",
        closed = true,
        coordinates = {},
        fillColor = config.outerColor,
        strokeColor = { white = 0, alpha = 0.02 },
        strokeWidth = 1,
        strokeJoinStyle = "round",
        antialias = true,
      },
      {
        id = "middleMembrane",
        type = "segments",
        action = "strokeAndFill",
        closed = true,
        coordinates = {},
        fillColor = config.middleColor,
        strokeColor = { white = 0, alpha = 0.04 },
        strokeWidth = 1,
        strokeJoinStyle = "round",
        antialias = true,
      },
      {
        id = "coreBlob",
        type = "segments",
        action = "strokeAndFill",
        closed = true,
        coordinates = {},
        fillColor = config.coreColor,
        strokeColor = config.blobStrokeColor,
        strokeWidth = 1,
        strokeJoinStyle = "round",
        antialias = true,
        trackMouseDown = true,
        trackMouseUp = true,
        trackMouseEnterExit = false,
        trackMouseMove = true,
      },
    }
  end

  for i = ELEMENT_DROPLET_START, ELEMENT_DROPLET_END do
    table.insert(elements, {
      id = "droplet" .. tostring(i - ELEMENT_DROPLET_START + 1),
      type = "segments",
      action = "skip",
      closed = true,
      coordinates = {},
      fillColor = config.dropletColor,
      strokeColor = { white = 0, alpha = 0.03 },
      strokeWidth = 1,
      strokeJoinStyle = "round",
      antialias = true,
    })
  end

  table.insert(elements, {
    id = "timer",
    type = "text",
    action = "fill",
    frame = { x = 0, y = 0, w = 96, h = 22 },
    text = "",
    textColor = config.timerColor,
    textFont = ".AppleSystemUIFont",
    textSize = config.timerFontSize,
    textAlignment = "center",
    textLineBreak = "clip",
  })

  table.insert(elements, {
    id = "debug",
    type = "text",
    action = "fill",
    frame = { x = 6, y = size - 24, w = size - 12, h = 20 },
    text = "",
    textColor = { white = 0, alpha = 0.45 },
    textFont = ".AppleSystemUIFont",
    textSize = 10,
    textAlignment = "center",
    textLineBreak = "clip",
  })

  canvas:replaceElements(elements)
  enterSmallCanvasMode()

  if visible then
    canvas:show()
  else
    canvas:hide()
  end
end

local function handleActivity()
  lastActivityAt = os.time()
end

local function beginMaybeDrag(screenPoint)
  if not isSmallInteractiveState() or not isScreenPointInsideParkedCore(screenPoint) then
    return
  end

  mouseDownAt = now()
  mouseDownPoint = nil
  mouseDownScreenPoint = { x = screenPoint.x, y = screenPoint.y }
  dragOriginParkedCenter = { x = parkedCenter.x, y = parkedCenter.y }
  maybeDragging = true
end

local function updateDragFromMouse()
  if not maybeDragging and currentState ~= STATE_DRAGGING then
    return
  end

  local currentPoint = hs.mouse.absolutePosition()
  if currentState == STATE_DRAGGING then
    local dx = currentPoint.x - mouseDownScreenPoint.x
    local dy = currentPoint.y - mouseDownScreenPoint.y
    parkedCenter = clampParkedCenter({
      x = dragOriginParkedCenter.x + dx,
      y = dragOriginParkedCenter.y + dy,
    })
    updateCanvasFrameForParkedPosition()
    return
  end

  if maybeDragging then
    local heldFor = now() - mouseDownAt
    if heldFor >= (config.longPressThresholdSeconds or 0.42) and distance(currentPoint, mouseDownScreenPoint) >= (config.dragStartDistancePx or 6) then
      dragReturnState = currentState
      setState(STATE_DRAGGING)
    end
  end
end

local function finishDragOrClick()
  if currentState == STATE_DRAGGING then
    local returnState = dragReturnState or STATE_PARKED_IDLE
    maybeDragging = false
    dragReturnState = nil
    persistState()
    setState(returnState)
    enterSmallCanvasMode()
    return
  end

  if maybeDragging and mouseDownScreenPoint then
    local upPoint = hs.mouse.absolutePosition()
    local moved = distance(upPoint, mouseDownScreenPoint)
    local heldFor = now() - mouseDownAt
    local clickMaxDistance = config.clickMaxDistancePx or 5
    maybeDragging = false

    if heldFor < (config.longPressThresholdSeconds or 0.42) and moved <= clickMaxDistance then
      M.openTimerPicker()
    end
  end
end

function M.handleCanvasMouse(message, point, elementId)
  if not isSmallInteractiveState() and currentState ~= STATE_DRAGGING then
    return
  end

  if message == "mouseDown" then
    if elementId == "canvas" and not isPointInsideCore(point) then
      return
    end
    beginMaybeDrag(hs.mouse.absolutePosition())
    mouseDownPoint = point
  elseif message == "mouseUp" then
    finishDragOrClick()
  elseif message == "mouseMove" then
    updateDragFromMouse()
  end
end

function M.openTimerPicker()
  if not (currentState == STATE_PARKED_IDLE or currentState == STATE_COUNTDOWN_ACTIVE) then
    return
  end

  local returnState = currentState
  setState(STATE_TIMER_PICKER)
  setSmallInteractivity(false)

  if chooser then
    chooser:delete()
    chooser = nil
  end

  chooser = hs.chooser.new(function(choice)
    local selected = choice
    if chooser then
      chooser:delete()
      chooser = nil
    end

    if not selected then
      setState(returnState)
      enterSmallCanvasMode()
      return
    end

    if selected.custom then
      local button, value = hs.dialog.textPrompt("Break timer", "Minutes until the overlay demands a break:", tostring(math.floor(lastTimerDurationSeconds / 60)), "Start", "Cancel")
      if button == "Start" then
        local minutes = tonumber(value)
        if minutes and minutes > 0 then
          startCountdown(math.floor(minutes * 60))
          return
        end
      end
      setState(returnState)
      enterSmallCanvasMode()
      return
    end

    startCountdown(selected.durationSeconds)
  end)

  chooser:choices({
    { text = "25m", subText = "Start a 25 minute break contract", durationSeconds = 25 * 60 },
    { text = "45m", subText = "Start a 45 minute break contract", durationSeconds = 45 * 60 },
    { text = "60m", subText = "Start a 60 minute break contract", durationSeconds = 60 * 60 },
    { text = "90m", subText = "Start a 90 minute break contract", durationSeconds = 90 * 60 },
    { text = "Custom minutes...", subText = "Enter a custom duration", custom = true },
  })
  chooser:placeholderText("Choose break timer")
  chooser:show()
end

local function updateState()
  if currentState == STATE_COUNTDOWN_ACTIVE then
    if remainingCountdownSeconds() <= 0 then
      enterDemandGrow(false)
    end
  elseif currentState == STATE_DEMAND_GROW then
    if os.time() - lastActivityAt >= (config.requiredBreakSeconds or 600) then
      enterRecoveryShrink()
    end
  elseif currentState == STATE_RECOVERY_SHRINK then
    if recoveryStartedWallAt and lastActivityAt > recoveryStartedWallAt then
      enterDemandGrow(true)
    end
  elseif currentState == STATE_DRAGGING then
    updateDragFromMouse()
  end
end

local function startEventTap()
  local eventTypes = hs.eventtap.event.types
  eventtap = hs.eventtap.new({
    eventTypes.keyDown,
    eventTypes.flagsChanged,
    eventTypes.leftMouseDown,
    eventTypes.leftMouseUp,
    eventTypes.leftMouseDragged,
    eventTypes.rightMouseDown,
    eventTypes.rightMouseUp,
    eventTypes.rightMouseDragged,
    eventTypes.otherMouseDown,
    eventTypes.otherMouseUp,
    eventTypes.otherMouseDragged,
    eventTypes.scrollWheel,
    eventTypes.mouseMoved,
  }, function(event)
    handleActivity()

    local eventType = event:getType()
    if eventType == eventTypes.leftMouseDown or eventType == eventTypes.rightMouseDown or eventType == eventTypes.otherMouseDown then
      beginMaybeDrag(hs.mouse.absolutePosition())
    elseif eventType == eventTypes.mouseMoved
      or eventType == eventTypes.leftMouseDragged
      or eventType == eventTypes.rightMouseDragged
      or eventType == eventTypes.otherMouseDragged then
      updateDragFromMouse()
    elseif eventType == eventTypes.leftMouseUp or eventType == eventTypes.rightMouseUp or eventType == eventTypes.otherMouseUp then
      finishDragOrClick()
    end

    return false
  end)

  eventtap:start()
end

local function startTimers()
  animationTimer = hs.timer.doEvery(1 / math.max(1, config.fps), drawFrame)
  stateTimer = hs.timer.doEvery(0.25, updateState)
end

local function stopRuntime()
  persistState()
  if chooser then
    chooser:delete()
    chooser = nil
  end
  if animationTimer then
    animationTimer:stop()
    animationTimer = nil
  end
  if stateTimer then
    stateTimer:stop()
    stateTimer = nil
  end
  if eventtap then
    eventtap:stop()
    eventtap = nil
  end
  if screenWatcher then
    screenWatcher:stop()
    screenWatcher = nil
  end
  if canvas then
    canvas:delete()
    canvas = nil
  end
end

function M.start()
  if canvas or eventtap or animationTimer or stateTimer then
    stopRuntime()
  end

  math.randomseed(os.time())
  restoreState()
  currentState = STATE_PARKED_IDLE
  previousState = STATE_PARKED_IDLE
  countdownEndsAt = nil
  demandStartAt = nil
  recoveryStartAt = nil
  recoveryStartedWallAt = nil
  lastActivityAt = os.time()
  lastDrawAt = 0

  createCanvas()
  startEventTap()
  startTimers()

  screenWatcher = hs.screen.watcher.new(function()
    parkedCenter = clampParkedCenter(parkedCenter or defaultParkedCenter())
    if canvasMode == "full" then
      updateCanvasFrameForFullScreen()
    else
      updateCanvasFrameForParkedPosition()
    end
  end)
  screenWatcher:start()
end

function M.stop()
  stopRuntime()
end

function M.toggle()
  visible = not visible
  if canvas then
    if visible then
      canvas:show()
      applyCanvasWindowBehavior()
    else
      canvas:hide()
    end
  end
end

function M.reset()
  enterParkedIdle()
  hs.alert.show("Breathing break reset")
end

function M.pause()
  if currentState == STATE_PAUSED then
    return
  end
  pausedReturnState = currentState
  pausedAt = now()
  pausedCountdownRemaining = nil
  if currentState == STATE_COUNTDOWN_ACTIVE then
    pausedCountdownRemaining = remainingCountdownSeconds()
    countdownEndsAt = nil
  end
  setState(STATE_PAUSED)
  hs.alert.show("Breathing break paused")
end

function M.resume()
  if currentState ~= STATE_PAUSED then
    return
  end
  local pausedFor = pausedAt and math.max(0, now() - pausedAt) or 0
  local target = pausedReturnState
  pausedAt = nil

  if target == STATE_COUNTDOWN_ACTIVE and pausedCountdownRemaining then
    countdownEndsAt = os.time() + pausedCountdownRemaining
    pausedCountdownRemaining = nil
    setState(STATE_COUNTDOWN_ACTIVE)
    enterSmallCanvasMode()
  elseif target == STATE_DEMAND_GROW then
    if demandStartAt then
      demandStartAt = demandStartAt + pausedFor
    end
    setState(STATE_DEMAND_GROW)
    enterFullScreenCanvasMode()
  elseif target == STATE_RECOVERY_SHRINK then
    if recoveryStartAt then
      recoveryStartAt = recoveryStartAt + pausedFor
    end
    setState(STATE_RECOVERY_SHRINK)
    enterFullScreenCanvasMode()
  else
    pausedCountdownRemaining = nil
    enterParkedIdle()
  end
  hs.alert.show("Breathing break resumed")
end

function M.togglePause()
  if currentState == STATE_PAUSED then
    M.resume()
  else
    M.pause()
  end
end

function M.toggleTimer()
  showTimer = not showTimer
  persistState()
  lastTimerText = nil
  hs.alert.show(showTimer and "Breathing timer shown" or "Breathing timer hidden")
end

function M.startTimer(durationSeconds)
  local duration = tonumber(durationSeconds)
  if not duration or duration <= 0 then
    return
  end
  startCountdown(math.floor(duration))
end

function M.forceDemand()
  enterDemandGrow(false)
  hs.alert.show("Breathing demand state")
end

function M.forceRecovery()
  if currentState ~= STATE_DEMAND_GROW and currentState ~= STATE_RECOVERY_SHRINK then
    demandScreenFrame = mainScreenFrame()
    demandCenter = { x = parkedCenter.x, y = parkedCenter.y }
    demandRadius = smallVisualSize()
  end
  enterRecoveryShrink()
  hs.alert.show("Breathing recovery state")
end

function M.forceAuditParkedIdle()
  config.debugVisualAudit = true
  enterParkedIdle()
end

function M.forceAuditCountdownActive()
  config.debugVisualAudit = true
  startCountdown(lastTimerDurationSeconds > 0 and lastTimerDurationSeconds or 25 * 60)
end

function M.forceAuditDemandProgress(progress)
  config.debugVisualAudit = true
  enterDemandGrow(false)
  demandStartAt = now() - clamp(progress or 0, 0, 1) * (config.growToMaxSeconds or 180)
  demandRadius = lerp(smallVisualSize(), maxDemandVisualSize(), easeOutCubic(clamp(progress or 0, 0, 1)))
end

function M.forceAuditRecoveryHalfway()
  config.debugVisualAudit = true
  if currentState ~= STATE_DEMAND_GROW and currentState ~= STATE_RECOVERY_SHRINK then
    demandScreenFrame = mainScreenFrame()
    local frame = demandScreenFrame
    demandCenter = {
      x = frame.x + frame.w * 0.52,
      y = frame.y + frame.h * 0.45,
    }
    demandRadius = maxDemandVisualSize()
  end
  enterRecoveryShrink()
  recoveryStartAt = now() - (config.recoveryShrinkSeconds or 32) * 0.5
end

function M.setConfig(partialConfig)
  if type(partialConfig) ~= "table" then
    return
  end

  for key, value in pairs(partialConfig) do
    config[key] = value
  end

  parkedCenter = clampParkedCenter(parkedCenter or defaultParkedCenter())
  if canvasMode == "small" then
    enterSmallCanvasMode()
  else
    enterFullScreenCanvasMode()
  end
end

function M.state()
  return {
    currentState = currentState,
    previousState = previousState,
    canvasMode = canvasMode,
    visible = visible,
    showTimer = showTimer,
    parkedCenter = parkedCenter and { x = parkedCenter.x, y = parkedCenter.y } or nil,
    countdownEndsAt = countdownEndsAt,
    remainingSeconds = remainingCountdownSeconds(),
    lastTimerDurationSeconds = lastTimerDurationSeconds,
    inactiveSeconds = os.time() - lastActivityAt,
    demandRadius = demandRadius,
  }
end

return M
