-- Konstanta a nastavení okna
function love.load()
    -- Konstanty
    WORLD_WIDTH   = 10000
    WORLD_HEIGHT  = 1200    -- vyšší kvůli slizovému království nahoře
    SCREEN_WIDTH  = 800
    SCREEN_HEIGHT = 600
    GRAVITY       = 800
    JUMP_FORCE    = -300
    BOUNCE_FORCE  = -500
    HERO_BASE_SPEED = 200
    HERO_MAX_JUMPS  = 2

    love.window.setMode(SCREEN_WIDTH, SCREEN_HEIGHT)
    love.window.setTitle("Platformovka: PF cheat, dynamický sliz, bambitka a super mystery box")

    -- Kamera
    camera = { x = 0, y = 0 }

    -- Herní stavy
    hraVyhrana = false
    gameOver   = false
    godMode    = false
    cheatFlyMode = false
    typedSequence = ""

    -- Speciální efekt: obří hovínko na 3 s
    giantPoop = nil

    ----------------------------------------------------------------------------
    -- Definice hrdiny
    ----------------------------------------------------------------------------
    hrac = {
        x = 50,
        y = 580,  -- počáteční pozice dole
        w = 20,
        h = 20,

        baseSpeed = HERO_BASE_SPEED,
        rychlost   = HERO_BASE_SPEED,   -- aktuální horizontální rychlost
        rychlostY = 0,                -- svislá rychlost
        naZemi    = false,
        maxSkoku  = HERO_MAX_JUMPS,
        zbyvajiciSkoky = HERO_MAX_JUMPS,

        health = {
            red  = 3,
            pink = 3,
        },
        activeColor = "red",
        colors = {
            red  = {1, 0, 0},
            pink = {1, 0.7, 0.8},
        },

        isBig = false,        -- BIG mode umožňuje bambitku
        hasCilindr = false,
        hasSmoking = false,
        spaceDrzeno = false,
        switchCooldown = 0,

        flyCloud = nil,       -- dočasné létání
        isOnSlime = false,    -- zda hrdina leze po slizu

        getColor = function(self)
            return self.colors[self.activeColor]
        end,

        takeDamage = function(self)
            if godMode then return end

            if self.isBig then
                -- Velký hráč se jen zmenší
                self.isBig = false
                self.rychlost = self.baseSpeed
                return
            end

            self.health[self.activeColor] = self.health[self.activeColor] - 1
            if self.health[self.activeColor] <= 0 then
                if self.activeColor == "red" then
                    if self.health["pink"] > 0 then
                        self.activeColor = "pink"
                    else
                        gameOver = true
                    end
                else
                    if self.health["red"] > 0 then
                        self.activeColor = "red"
                    else
                        gameOver = true
                    end
                end
            end
        end,

        switchColor = function(self)
            if self.activeColor == "red" and self.health["pink"] > 0 then
                self.activeColor = "pink"
            elseif self.activeColor == "pink" and self.health["red"] > 0 then
                self.activeColor = "red"
            end
        end,
    }

    ----------------------------------------------------------------------------
    -- Střely hrdiny (mráčky z bambitky)
    ----------------------------------------------------------------------------
    mracky = {}

    ----------------------------------------------------------------------------
    -- Platformy
    ----------------------------------------------------------------------------
    platformy = {}
    -- Dolní podlaha (celý svět)
    table.insert(platformy, {
        x = 0,
        y = 580,
        w = WORLD_WIDTH,
        h = 20,
        bounce = false,
        falling = false,
        color = {0.7, 0.3, 0.3}
    })
    -- Další platformy
    table.insert(platformy, {
        x = 400, y = 450, w = 200, h = 20,
        bounce = false, falling = false,
        color = {0.7, 0.3, 0.3}
    })
    table.insert(platformy, {
        x = 900, y = 350, w = 150, h = 20,
        bounce = true, falling = false,
        color = {0, 0, 0}
    })
    table.insert(platformy, {
        x = 1400, y = 300, w = 200, h = 20,
        bounce = false, falling = true,
        color = {1, 0.8, 0.5}
    })
    table.insert(platformy, {
        x = 3000, y = 50, w = 200, h = 20,
        bounce = false, falling = false,
        color = {0.7, 0.3, 0.3}
    })
    table.insert(platformy, {
        x = 2800, y = -100, w = 300, h = 20,
        bounce = false, falling = false,
        color = {0.2, 0.6, 0.2}
    })
    lastSafePlatform = platformy[1]

    ----------------------------------------------------------------------------
    -- Mystery boxy
    ----------------------------------------------------------------------------
    mysteryBlocks = {
        { x = 420,  y = 400, w = 20, h = 20, opened = false, color = {1, 1, 0} },
        { x = 920,  y = 300, w = 20, h = 20, opened = false, color = {1, 1, 0} },
        { x = 1450, y = 250, w = 20, h = 20, opened = false, color = {1, 1, 0}, superBox = true }
    }
    table.insert(mysteryBlocks, {
        x = 2850, y = -150, w = 20, h = 20, opened = false,
        color = {1, 1, 0}, superBox = false
    })

    ----------------------------------------------------------------------------
    -- Sliz (dynamické segmenty)
    ----------------------------------------------------------------------------
    slizSegments = {}
    for i = 1, 5 do
        local segX = 600 * i
        local seg = {
            x = segX,
            topY = -200,
            bottomBase = love.math.random(80, 300),
            w = 20,
            color = {0, 1, 0},
            phase = 0
        }
        table.insert(slizSegments, seg)
    end

    ----------------------------------------------------------------------------
    -- Nepřátelé (včetně Mega bosse)
    ----------------------------------------------------------------------------
    nepratele = {
        {
            x = 300, y = 560, w = 20, h = 20,
            rychlost = 100, smer = 1,
            levaHranice = 250, pravaHranice = 600
        },
        {
            x = 700, y = 560, w = 20, h = 20,
            rychlost = 120, smer = -1,
            levaHranice = 600, pravaHranice = 800
        },
        {
            x = 1400, y = 560, w = 20, h = 20,
            rychlost = 80, smer = 1,
            levaHranice = 1300, pravaHranice = 1500
        },
        -- Mega boss
        {
            bossMega = true, hp = 3,
            x = 9500, y = 430, w = 150, h = 150,
            vy = 0, naZemi = false,
            jumpTimer = 2, shootTimer = 1
        }
    }

    banany = {}  -- střely bosse
end

--------------------------------------------------------------------------------
-- Cheat klávesy (vyčištění bufferu po detekci)
--------------------------------------------------------------------------------
function love.keypressed(key)
    typedSequence = (typedSequence .. key):sub(-15)
    if typedSequence:sub(-5) == "iddqd" then
        godMode = true
        print("God mode activated!")
        typedSequence = ""
    elseif typedSequence:sub(-2) == "pf" then
        cheatFlyMode = not cheatFlyMode
        print("Fly mode toggled:", cheatFlyMode)
        typedSequence = ""
    end
end

--------------------------------------------------------------------------------
-- KOLIZE (AABB)
--------------------------------------------------------------------------------
local function kolize(a, b)
    return a.x < b.x + b.w and
           a.x + a.w > b.x and
           a.y < b.y + (b.h or 0) and
           a.y + a.h > b.y
end

--------------------------------------------------------------------------------
-- Boss: vystřelení banánu (projektil)
--------------------------------------------------------------------------------
local function bossShootBanana(boss)
    local speed = 250
    local dx = (hrac.x + hrac.w/2) - (boss.x + boss.w/2)
    local dy = (hrac.y + hrac.h/2) - (boss.y + boss.h/2)
    local length = math.sqrt(dx*dx + dy*dy)
    if length == 0 then
        dx, dy = 1, 0
    else
        dx = dx / length
        dy = dy / length
    end
    local banana = {
        x = boss.x + boss.w/2,
        y = boss.y + boss.h/2,
        w = 10, h = 10,
        vx = dx * speed, vy = dy * speed
    }
    table.insert(banany, banana)
end

--------------------------------------------------------------------------------
-- POWER-UP: otevření Mystery boxu
--------------------------------------------------------------------------------
function openMysteryBlock(block)
    block.opened = true
    if block.superBox then
        giantPoop = { timeLeft = 3 }
        print("SUPER Mystery box => obří hovínko na 3s!")
        return
    end

    local r = love.math.random(1, 5)
    if r == 1 then
        hrac.flyCloud = { timeLeft = 10 }
        print("Power-up: Letací mráček (10s)!")
    elseif r == 2 then
        hrac.isBig = true
        hrac.rychlost = hrac.baseSpeed * 2
        print("Power-up: BIG mode + bambitka!")
    elseif r == 3 then
        hrac.hasCilindr = true
        print("Power-up: Cilindr!")
    elseif r == 4 then
        hrac.hasSmoking = true
        print("Power-up: Smoking!")
    else
        print("Power-up: Nic :-)")
    end
end

--------------------------------------------------------------------------------
-- UPDATE FUNKCE ROZDĚLENÉ DO MODULŮ
--------------------------------------------------------------------------------
local function updateGiantPoop(dt)
    if giantPoop then
        giantPoop.timeLeft = giantPoop.timeLeft - dt
        if giantPoop.timeLeft <= 0 then
            giantPoop = nil
        end
    end
end

local function updateSlizSegments(dt)
    for _, sl in ipairs(slizSegments) do
        sl.phase = sl.phase + dt
        sl.dynamicBottom = sl.bottomBase + math.sin(sl.phase) * 50
    end
end

local function updateFlyingStatus(dt)
    local isFlying = cheatFlyMode
    if hrac.flyCloud then
        hrac.flyCloud.timeLeft = hrac.flyCloud.timeLeft - dt
        if hrac.flyCloud.timeLeft <= 0 then
            hrac.flyCloud = nil
        else
            isFlying = true
        end
    end
    return isFlying
end

local function updateHeroMovement(dt, isFlying)
    if isFlying then
        if love.keyboard.isDown("up") then
            hrac.y = hrac.y - hrac.rychlost * dt
        end
        if love.keyboard.isDown("down") then
            hrac.y = hrac.y + hrac.rychlost * dt
        end
        if love.keyboard.isDown("left") then
            hrac.x = hrac.x - hrac.rychlost * dt
        end
        if love.keyboard.isDown("right") then
            hrac.x = hrac.x + hrac.rychlost * dt
        end
    else
        if love.keyboard.isDown("left") then
            hrac.x = hrac.x - hrac.rychlost * dt
        elseif love.keyboard.isDown("right") then
            hrac.x = hrac.x + hrac.rychlost * dt
        end
        hrac.rychlostY = hrac.rychlostY + GRAVITY * dt
        hrac.y = hrac.y + hrac.rychlostY * dt
    end

    -- Omezení, aby hrdina nezmizel za okrajem světa
    if hrac.x < 0 then hrac.x = 0 end
    if hrac.x + hrac.w > WORLD_WIDTH then
        hrac.x = WORLD_WIDTH - hrac.w
    end
end

local function updateHeroJump(dt, isFlying)
    if not isFlying then
        if love.keyboard.isDown("space") then
            if not hrac.spaceDrzeno then
                hrac.spaceDrzeno = true
                if hrac.zbyvajiciSkoky > 0 then
                    hrac.rychlostY = JUMP_FORCE
                    hrac.zbyvajiciSkoky = hrac.zbyvajiciSkoky - 1
                end
            end
        else
            hrac.spaceDrzeno = false
        end
    end
end

local function updateHeroSwitchColor(dt)
    if love.keyboard.isDown("p") then
        if hrac.switchCooldown <= 0 then
            hrac.switchCooldown = 0.3
            hrac:switchColor()
        end
    end
    if hrac.switchCooldown > 0 then
        hrac.switchCooldown = hrac.switchCooldown - dt
    end
end

local function handleHeroShooting()
    if hrac.isBig and love.keyboard.isDown("m") then
        shootMracek()
    end
end

function shootMracek()
    local speed = 300
    local mrak = {
        x = hrac.x + hrac.w / 2,
        y = hrac.y + hrac.h / 2,
        w = 10, h = 10,
        vx = speed, vy = 0
    }
    table.insert(mracky, mrak)
end

function updateMracky(dt)
    for i = #mracky, 1, -1 do
        local m = mracky[i]
        m.x = m.x + m.vx * dt
        m.y = m.y + m.vy * dt

        local removeIt = false
        for j = #nepratele, 1, -1 do
            local n = nepratele[j]
            if kolize(m, n) then
                if n.bossMega then
                    n.hp = n.hp - 1
                    if n.hp <= 0 then
                        table.remove(nepratele, j)
                    end
                else
                    table.remove(nepratele, j)
                end
                removeIt = true
                break
            end
        end

        if removeIt or m.x < 0 or m.x > WORLD_WIDTH or m.y < -200 or m.y > 800 then
            table.remove(mracky, i)
        end
    end
end

local function updateSlizCollision(dt, isFlying)
    hrac.isOnSlime = false
    if not isFlying then
        for _, sl in ipairs(slizSegments) do
            local slimeRect = {
                x = sl.x,
                y = sl.topY,
                w = sl.w,
                h = sl.dynamicBottom - sl.topY
            }
            if slimeRect.h < 0 then
                slimeRect.y = slimeRect.y + slimeRect.h
                slimeRect.h = -slimeRect.h
            end
            if kolize(hrac, slimeRect) then
                hrac.isOnSlime = true
                break
            end
        end
    end

    if hrac.isOnSlime and not isFlying then
        hrac.rychlostY = 0
        if love.keyboard.isDown("up") then
            hrac.y = hrac.y - 100 * dt
        end
    end
end

local function updatePlatformCollision(dt, isFlying)
    if not isFlying and not hrac.isOnSlime then
        hrac.naZemi = false
        for i = #platformy, 1, -1 do
            local p = platformy[i]
            if kolize(hrac, p) then
                if hrac.rychlostY > 0 then
                    hrac.y = p.y - hrac.h
                    hrac.rychlostY = 0
                    hrac.naZemi = true
                    hrac.zbyvajiciSkoky = hrac.maxSkoku
                    if p.bounce then
                        hrac.rychlostY = BOUNCE_FORCE
                    end
                    if p.falling then
                        table.remove(platformy, i)
                    else
                        lastSafePlatform = p
                    end
                end
            end
        end
    end
end

local function updateMysteryBlocks(dt)
    for i = #mysteryBlocks, 1, -1 do
        local mb = mysteryBlocks[i]
        if not mb.opened then
            if kolize(hrac, mb) then
                if hrac.rychlostY < 0 and hrac.y > mb.y then
                    openMysteryBlock(mb)
                end
            end
        end
    end
end

local function updateHeroFall(isFlying)
    if not isFlying and not hrac.isOnSlime and lastSafePlatform then
        local padThreshold = lastSafePlatform.y + 200
        if hrac.y + hrac.h > padThreshold then
            hrac:takeDamage()
            if not gameOver then
                hrac.x = lastSafePlatform.x + 10
                hrac.y = lastSafePlatform.y - hrac.h
                hrac.rychlostY = 0
            end
        end
    end
end

local function updateEnemies(dt, isFlying)
    for i = #nepratele, 1, -1 do
        local n = nepratele[i]
        if not n.bossMega then
            n.x = n.x + n.smer * n.rychlost * dt
            if n.levaHranice and n.pravaHranice then
                if n.x < n.levaHranice then
                    n.x = n.levaHranice
                    n.smer = 1
                elseif n.x + n.w > n.pravaHranice then
                    n.x = n.pravaHranice - n.w
                    n.smer = -1
                end
            end
        else
            n.vy = n.vy + GRAVITY * dt
            n.y = n.y + n.vy * dt
            n.naZemi = false
            for _, p in ipairs(platformy) do
                if (n.x + n.w > p.x) and (n.x < p.x + p.w) and
                   (n.y + n.h <= p.y + 5) and (n.vy > 0) then
                    if n.y + n.h > p.y then
                        n.y = p.y - n.h
                        n.vy = 0
                        n.naZemi = true
                        break
                    end
                end
            end
            n.jumpTimer = n.jumpTimer - dt
            if n.jumpTimer <= 0 and n.naZemi then
                n.vy = JUMP_FORCE
                n.jumpTimer = 2 + love.math.random() * 2
            end
            n.shootTimer = n.shootTimer - dt
            if n.shootTimer <= 0 then
                bossShootBanana(n)
                n.shootTimer = 1.5 + love.math.random() * 2
            end
        end

        -- Kolize hrdina vs nepřítel
        if kolize(hrac, n) then
            if not isFlying and not hrac.isOnSlime and hrac.rychlostY > 0 and (hrac.y + hrac.h) <= (n.y + 10) then
                if n.bossMega then
                    n.hp = n.hp - 1
                    if n.hp <= 0 then
                        table.remove(nepratele, i)
                    end
                else
                    table.remove(nepratele, i)
                end
                hrac.rychlostY = -200
            else
                hrac:takeDamage()
                if not gameOver and lastSafePlatform then
                    hrac.x = lastSafePlatform.x + 10
                    hrac.y = lastSafePlatform.y - hrac.h
                    hrac.rychlostY = 0
                end
            end
        end
    end

    if #nepratele == 0 then
        hraVyhrana = true
    end
end

local function updateBanany(dt)
    for i = #banany, 1, -1 do
        local b = banany[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        if kolize(b, hrac) then
            hrac:takeDamage()
            if not gameOver and lastSafePlatform then
                hrac.x = lastSafePlatform.x + 10
                hrac.y = lastSafePlatform.y - hrac.h
                hrac.rychlostY = 0
            end
            table.remove(banany, i)
        elseif b.x < 0 or b.x > WORLD_WIDTH or b.y < -300 or b.y > (580 + 200) then
            table.remove(banany, i)
        end
    end
end

local function updateCamera()
    camera.x = hrac.x - SCREEN_WIDTH / 2
    if camera.x < 0 then camera.x = 0 end
    if camera.x > WORLD_WIDTH - SCREEN_WIDTH then
        camera.x = WORLD_WIDTH - SCREEN_WIDTH
    end
end

--------------------------------------------------------------------------------
-- LOVE.UPDATE
--------------------------------------------------------------------------------
function love.update(dt)
    if hraVyhrana or gameOver then
        if love.keyboard.isDown("r") then
            love.load()
        end
        return
    end

    updateGiantPoop(dt)
    updateSlizSegments(dt)
    local isFlying = updateFlyingStatus(dt)
    updateHeroMovement(dt, isFlying)
    updateHeroJump(dt, isFlying)
    updateHeroSwitchColor(dt)
    handleHeroShooting()
    updateMracky(dt)
    updateSlizCollision(dt, isFlying)
    updatePlatformCollision(dt, isFlying)
    updateMysteryBlocks(dt)
    updateHeroFall(isFlying)
    updateEnemies(dt, isFlying)
    updateBanany(dt)
    updateCamera()
end

--------------------------------------------------------------------------------
-- LOVE.DRAW
--------------------------------------------------------------------------------
function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)

    -- Pozadí
    love.graphics.clear(0.1, 0.7, 0.1)

    -- Platformy
    for _, p in ipairs(platformy) do
        love.graphics.setColor(p.color)
        love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
    end

    -- Mystery boxy
    for _, mb in ipairs(mysteryBlocks) do
        if not mb.opened then
            love.graphics.setColor(mb.color)
            love.graphics.rectangle("fill", mb.x, mb.y, mb.w, mb.h)
        end
    end

    -- Sliz segmenty
    for _, sl in ipairs(slizSegments) do
        love.graphics.setColor(sl.color)
        local topY = sl.topY
        local bottom = sl.dynamicBottom
        local hh = bottom - topY
        if hh < 0 then
            topY = bottom
            hh = -hh
        end
        love.graphics.rectangle("fill", sl.x, topY, sl.w, hh)
    end

    -- Banány
    love.graphics.setColor(1, 1, 0)
    for _, b in ipairs(banany) do
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    end

    -- Nepřátelé
    for _, n in ipairs(nepratele) do
        if n.bossMega then
            love.graphics.setColor(0.6, 0.3, 0)
        else
            love.graphics.setColor(0.7, 0, 0.7)
        end
        love.graphics.rectangle("fill", n.x, n.y, n.w, n.h)
    end

    -- Hrdinovy střely (mráčky)
    love.graphics.setColor(0.9, 0.9, 0.9)
    for _, m in ipairs(mracky) do
        love.graphics.rectangle("fill", m.x, m.y, m.w, m.h)
    end

    -- Hrdina
    local r, g, b = hrac:getColor()[1], hrac:getColor()[2], hrac:getColor()[3]
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", hrac.x, hrac.y, hrac.w, hrac.h)

    -- Doplňky: cilindr a smoking
    if hrac.hasCilindr then
        love.graphics.setColor(0, 0, 0)
        local hatH = 10
        love.graphics.rectangle("fill", hrac.x, hrac.y - hatH, hrac.w, hatH)
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", hrac.x, hrac.y - hatH/2 - 1, hrac.w, 2)
    end
    if hrac.hasSmoking then
        love.graphics.setColor(0, 0, 0)
        local coatH = 10
        love.graphics.rectangle("fill", hrac.x, hrac.y + hrac.h, hrac.w, coatH)
    end

    -- Letací mráček
    if hrac.flyCloud then
        local alpha = hrac.flyCloud.timeLeft / 10
        love.graphics.setColor(0, 0.6, 1, alpha)
        local cw = hrac.w + 10
        local ch = 8
        love.graphics.rectangle("fill", hrac.x - 5, hrac.y + hrac.h, cw, ch)
    end

    love.graphics.pop()

    -- Obří hovínko efekt
    if giantPoop then
        local alpha = 1
        love.graphics.setColor(0.5, 0.35, 0.1, alpha)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    end

    -- UI
    love.graphics.setColor(1, 1, 1)
    local msg = string.format("RED HP: %d  |  PINK HP: %d", hrac.health.red, hrac.health.pink)
    love.graphics.print(msg, 10, 10)

    if godMode then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("God mode (iddqd)", 10, 30)
    end
    if cheatFlyMode then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Fly mode (pf)", 10, 50)
    end

    if hraVyhrana then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Vyhrál jsi! [R] pro restart.", 0, SCREEN_HEIGHT/2 - 20, SCREEN_WIDTH, "center")
    elseif gameOver then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Prohrál jsi! [R] pro restart.", 0, SCREEN_HEIGHT/2 - 20, SCREEN_WIDTH, "center")
    end
end
