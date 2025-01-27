function love.load()
    love.window.setMode(800, 600)
    love.window.setTitle("Platformovka s Mystery Bloky, Fly módem a cheaty")

    -- Rozměry obrazovky a světa
    screenWidth = 800
    screenHeight = 600
    worldWidth = 10000  -- velký posuvný svět
    worldHeight = 600

    -- Kamera
    camera = { x = 0, y = 0 }

    -- Herní stavy
    gravitace = 800
    hraVyhrana = false
    gameOver = false
    godMode = false             -- pro cheat "iddqd" (nesmrtelnost)
    cheatFlyMode = false        -- pro cheat "prettyfly" (permanentní létání)
    typedSequence = ""          -- sledujeme psané klávesy kvůli cheatům

    --------------------------------------------------
    -- Definice hrdiny (dvoubarevný)
    --------------------------------------------------
    hrac = {
        x = 50,
        y = 0,
        w = 20,
        h = 20,

        baseSpeed = 200,       -- základní rychlost (při normal velikosti)
        rychlost = 200,        -- aktuální vodorovná rychlost
        rychlostY = 0,         -- svislá rychlost (pád/skok)
        naZemi = false,
        maxSkoku = 2,          -- dvojitý skok
        zbyvajiciSkoky = 2,

        -- Životy pro každou barvu
        health = {
            red = 3,
            pink = 3,
        },
        activeColor = "red",      -- začínáme v červené
        colors = {
            red  = {1, 0, 0},        -- (R,G,B)
            pink = {1, 0.7, 0.8},
        },

        -- Speciální stavy
        hasCilindr = false,     -- módní doplněk
        isBig = false,          -- stav, kdy je hrdina zvětšený
        canFly = false,         -- dočasné létání (10s) z Mystery bloku
        flyTimer = 0,           -- čas zbývajícího létání

        spaceDrzeno = false,    -- pomocná proměnná pro stisk mezerníku
        switchCooldown = 0,     -- aby se barva nepřepínala neustále

        -- Funkce pro získání barvy
        getColor = function(self)
            return self.colors[self.activeColor]
        end
    }

    -- Metoda: hrdina dostane zásah
    function hrac:takeDamage()
        -- 1) God mód => bez účinku
        if godMode then return end

        -- 2) Pokud je hrdina velký, neztrácí život, jen se zmenší
        if self.isBig then
            self.isBig = false
            -- Vrátíme rychlost
            self.rychlost = self.baseSpeed
            return
        end

        -- 3) Normální ztráta životu pro danou barvu
        self.health[self.activeColor] = self.health[self.activeColor] - 1
        if self.health[self.activeColor] <= 0 then
            -- Přepnout na druhou barvu, pokud ještě má životy
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
    end

    -- Metoda: přepnutí barvy klávesou 'P'
    function hrac:switchColor()
        if self.activeColor == "red" and self.health["pink"] > 0 then
            self.activeColor = "pink"
        elseif self.activeColor == "pink" and self.health["red"] > 0 then
            self.activeColor = "red"
        end
    end

    -- Seznam střel (mráčků), kterými střílí velký hrdina
    mracky = {}

    --------------------------------------------------
    -- Vygenerované platformy
    --------------------------------------------------
    platformy = generatePlatforms(worldWidth)

    --------------------------------------------------
    -- Mystery bloky (5 kusů)
    -- Umístíme je ručně na nějaké x-pozice, např. 1000, 2000, 3000, 4000, 8000
    -- Každý Mystery blok: w=20, h=20, color=žlutá, atd.
    --------------------------------------------------
    mysteryBlocks = {
        {x=1000,y=450,w=20,h=20, opened=false, color={1,1,0}},
        {x=2000,y=350,w=20,h=20, opened=false, color={1,1,0}},
        {x=3000,y=400,w=20,h=20, opened=false, color={1,1,0}},
        {x=4000,y=480,w=20,h=20, opened=false, color={1,1,0}},
        {x=8000,y=500,w=20,h=20, opened=false, color={1,1,0}},
    }

    --------------------------------------------------
    -- Nepřátelé (včetně bosse)
    --------------------------------------------------
    nepratele = {
        {
            x = 300, y = 560, w = 20, h = 20,
            rychlost = 100, smer = 1,
            levaHranice = 250, pravaHranice = 400,
        },
        {
            x = 700, y = 480, w = 20, h = 20,
            rychlost = 120, smer = -1,
            levaHranice = 600, pravaHranice = 800,
        },
        -- Boss (fialový, velký, střílí banány)
        {
            boss = true,
            hp = 3,
            x = 9800,
            y = 400,
            w = 100,
            h = 100,
            vy = 0,
            naZemi = false,
            jumpTimer = 2,
            shootTimer = 1,
        }
    }

    -- Banány (bossovy střely)
    banany = {}

    -- Poslední bezpečná platforma
    lastSafePlatform = nil
end

--------------------------------------------------------------------------------
-- GENERÁTOR PLATFOREM (stejně jako v předchozím příkladu)
--------------------------------------------------------------------------------
function generatePlatforms(maxWidth)
    local plats = {}
    local x = 0
    local y = 500

    while x < maxWidth - 300 do
        local p = {}
        p.x = x
        p.w = 200

        local dx = 300 + love.math.random(-50, 50)
        x = x + dx

        local dy = love.math.random(-50, 50)
        y = y + dy
        if y < 100 then y = 100 end
        if y > 500 then y = 500 end
        p.y = y
        p.h = 20

        -- Speciální platformy (10% trampolína, 10% padající, jinak normální)
        local randType = love.math.random(1,100)
        if randType <= 10 then
            p.bounce  = true
            p.falling = false
            p.color   = {0,0,0}     -- černá
            p.h       = 15
        elseif randType <= 20 then
            p.falling = true
            p.bounce  = false
            p.color   = {1,0.8,0.5} -- padající (světle oranžová)
            p.h       = 10
        else
            p.bounce  = false
            p.falling = false
            p.color   = {0.7,0.3,0.3} -- cihlová
        end

        table.insert(plats,p)
    end

    -- Finální platforma pro bosse
    local bossPlat = {
        x = maxWidth - 300,
        y = 550,
        w = 300,
        h = 20,
        bounce = false,
        falling = false,
        color = {0.7,0.3,0.3}
    }
    table.insert(plats, bossPlat)
    return plats
end

--------------------------------------------------------------------------------
-- Pomocná funkce pro kolizi dvou obdélníků
--------------------------------------------------------------------------------
local function kolize(a, b)
    return  a.x < b.x + b.w and
            a.x + a.w > b.x and
            a.y < b.y + b.h and
            a.y + a.h > b.y
end

--------------------------------------------------------------------------------
-- Bossova střelba banánů
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
        vx = dx * speed,
        vy = dy * speed
    }
    table.insert(banany, banana)
end

--------------------------------------------------------------------------------
-- LOVE.KEYPRESSED => cheat kódy
--------------------------------------------------------------------------------
function love.keypressed(key)
    -- Ukládáme stisknuté klávesy do short bufferu
    typedSequence = typedSequence .. key
    if #typedSequence > 10 then
        typedSequence = string.sub(typedSequence, -10) -- oříznout na posledních 10 znaků
    end

    -- IDDQD => god mode
    if string.sub(typedSequence, -5) == "iddqd" then
        godMode = true
        print("God mode aktivován (iddqd).")
    end

    -- PRETTYFLY => fly mode
    if string.sub(typedSequence, -9) == "prettyfly" then
        cheatFlyMode = not cheatFlyMode  -- přepínání
        print("Fly mode toggled:", cheatFlyMode)
    end
end

--------------------------------------------------------------------------------
-- LOVE.UPDATE
--------------------------------------------------------------------------------
function love.update(dt)
    -- Pokud hra skončila (výhra/prohra), čekáme na R pro restart
    if hraVyhrana or gameOver then
        if love.keyboard.isDown("r") then
            love.load()
        end
        return
    end

    -- Ovládání hrdiny
    if cheatFlyMode or hrac.canFly then
        -- Létání: ignorujeme gravitaci, hrdina může nahoru/dolů
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

        -- Pokud je to jen dočasné létání z Mystery blocku
        if hrac.canFly then
            hrac.flyTimer = hrac.flyTimer - dt
            if hrac.flyTimer <= 0 then
                hrac.canFly = false
            end
        end
    else
        -- Normální pohyb + gravitace
        if love.keyboard.isDown("left") then
            hrac.x = hrac.x - hrac.rychlost * dt
        elseif love.keyboard.isDown("right") then
            hrac.x = hrac.x + hrac.rychlost * dt
        end

        -- Gravitační pád
        hrac.rychlostY = hrac.rychlostY + gravitace * dt
        hrac.y = hrac.y + hrac.rychlostY * dt
    end

    -- Omezit pohyb do hranic světa
    if hrac.x < 0 then hrac.x = 0 end
    if hrac.x + hrac.w > worldWidth then
        hrac.x = worldWidth - hrac.w
    end

    -- Dvojitý skok (jen pokud nemáme cheat/létání)
    if not cheatFlyMode and not hrac.canFly then
        if love.keyboard.isDown("space") then
            if not hrac.spaceDrzeno then
                hrac.spaceDrzeno = true
                if hrac.zbyvajiciSkoky > 0 then
                    hrac.rychlostY = -300
                    hrac.zbyvajiciSkoky = hrac.zbyvajiciSkoky - 1
                end
            end
        else
            hrac.spaceDrzeno = false
        end
    end

    -- Přepnutí barvy (P)
    if love.keyboard.isDown("p") then
        if hrac.switchCooldown <= 0 then
            hrac.switchCooldown = 0.3
            hrac:switchColor()
        end
    end
    if hrac.switchCooldown > 0 then
        hrac.switchCooldown = hrac.switchCooldown - dt
    end

    -- Střelba mraků, jen pokud je hrdina velký
    if hrac.isBig and love.keyboard.isDown("m") then
        shootMracek()
    end
    updateMracky(dt)

    -- Kontrola, zda hrdina je na zemi (není-li v cheat/létacím módu)
    if not cheatFlyMode and not hrac.canFly then
        hrac.naZemi = false
    end

    -- Kolize s platformami
    local stoodOnPlatformThisFrame = false
    if not cheatFlyMode and not hrac.canFly then
        -- jen řešíme, když nepoužíváme létání
        for i=#platformy,1,-1 do
            local p = platformy[i]
            if kolize(hrac,p) then
                -- Hrdina dopadá shora?
                if hrac.rychlostY > 0 then
                    hrac.y = p.y - hrac.h
                    hrac.rychlostY = 0
                    hrac.naZemi = true
                    hrac.zbyvajiciSkoky = hrac.maxSkoku

                    -- Trampolína?
                    if p.bounce then
                        hrac.rychlostY = -500
                    end

                    -- Padající platforma => zmizí
                    if p.falling then
                        table.remove(platformy,i)
                    else
                        lastSafePlatform = p
                        stoodOnPlatformThisFrame = true
                    end
                end
            end
        end
    end

    -- Mystery bloky - bouchnutí ze spoda?
    checkMysteryBlocks(dt)

    -- Pád pod úroveň poslední bezpečné platformy
    if lastSafePlatform ~= nil
       and (not cheatFlyMode and not hrac.canFly) then
        local padThreshold = lastSafePlatform.y + 200
        if (hrac.y + hrac.h) > padThreshold then
            -- Spadl
            hrac:takeDamage()
            if not gameOver then
                -- reset
                hrac.x = lastSafePlatform.x + 10
                hrac.y = lastSafePlatform.y - hrac.h
                hrac.rychlostY = 0
            end
        end
    end

    -- Pohyb nepřátel (včetně bosse)
    for i=#nepratele,1,-1 do
        local n = nepratele[i]
        if not n.boss then
            -- Obyčejný nepřítel
            n.x = n.x + n.smer * n.rychlost * dt
            if n.x < n.levaHranice then
                n.x = n.levaHranice
                n.smer = 1
            elseif (n.x+n.w) > n.pravaHranice then
                n.x = n.pravaHranice - n.w
                n.smer = -1
            end
        else
            -- Boss
            n.vy = n.vy + gravitace * dt
            n.y = n.y + n.vy * dt
            n.naZemi = false
            -- dopad na platformu?
            for _, p in ipairs(platformy) do
                if (n.x + n.w > p.x) and (n.x < p.x + p.w)
                   and (n.y + n.h <= p.y + 5)
                   and (n.vy > 0) then
                    if n.y + n.h > p.y then
                        n.y = p.y - n.h
                        n.vy = 0
                        n.naZemi = true
                        break
                    end
                end
            end
            -- skok bosse
            n.jumpTimer = n.jumpTimer - dt
            if n.jumpTimer <= 0 and n.naZemi then
                n.vy = -400
                n.jumpTimer = 2 + love.math.random()*2
            end
            -- střelba banánů
            n.shootTimer = n.shootTimer - dt
            if n.shootTimer <= 0 then
                bossShootBanana(n)
                n.shootTimer = 1.5 + love.math.random()*2
            end
        end

        -- Kolize hrdiny s nepřítelem
        if kolize(hrac, n) then
            -- Dopadl na hlavu?
            if (not cheatFlyMode and not hrac.canFly)
               and hrac.rychlostY > 0
               and (hrac.y + hrac.h) <= (n.y + 10) then
                -- Boss?
                if n.boss then
                    n.hp = n.hp - 1
                    if n.hp <= 0 then
                        table.remove(nepratele,i)
                    end
                else
                    table.remove(nepratele,i)
                end
                hrac.rychlostY = -200
            else
                -- Z boku/spodu => hrdina dostane dmg
                hrac:takeDamage()
                if not gameOver and lastSafePlatform ~= nil then
                    hrac.x = lastSafePlatform.x + 10
                    hrac.y = lastSafePlatform.y - hrac.h
                    hrac.rychlostY = 0
                end
            end
        end
    end

    -- Pohyb banánů + kolize s hrdinou
    for i=#banany,1,-1 do
        local b = banany[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt

        -- Kolize s hrdinou
        if kolize(b, hrac) then
            hrac:takeDamage()
            if not gameOver and lastSafePlatform then
                hrac.x = lastSafePlatform.x + 10
                hrac.y = lastSafePlatform.y - hrac.h
                hrac.rychlostY = 0
            end
            table.remove(banany,i)
        elseif b.x < 0 or b.x>worldWidth or b.y<0 or b.y>worldHeight then
            table.remove(banany,i)
        end
    end

    -- Všichni nepřátelé pryč => výhra
    if #nepratele == 0 then
        hraVyhrana = true
    end

    -- Kamera
    camera.x = hrac.x - screenWidth/2
    if camera.x<0 then camera.x=0 end
    if camera.x>worldWidth - screenWidth then
        camera.x = worldWidth - screenWidth
    end
end

--------------------------------------------------------------------------------
-- FUNKCE: Mráčky (střely hrdiny, je-li velký) ----------------------------------
--------------------------------------------------------------------------------
function shootMracek()
    -- Pro zjednodušení: jeden mráček za "frame"? Nebo uděláme cooldown?
    -- Tady to necháme volné. Můžete si přidat cooldown.
    local speed = 300
    local mrak = {
        x = hrac.x + hrac.w/2,
        y = hrac.y + hrac.h/2,
        w = 10,
        h = 10,
        vx = speed, -- letí doprava
        vy = 0
    }
    table.insert(mracky, mrak)
end

function updateMracky(dt)
    -- Pohyb mráčků + kolize s nepřáteli
    for i=#mracky,1,-1 do
        local m = mracky[i]
        m.x = m.x + m.vx * dt
        m.y = m.y + m.vy * dt

        -- Kolize s nepřáteli
        local removeIt = false
        for j=#nepratele,1,-1 do
            local n = nepratele[j]
            if kolize(m, n) then
                -- boss?
                if n.boss then
                    n.hp = n.hp - 1
                    if n.hp <= 0 then
                        table.remove(nepratele,j)
                    end
                else
                    table.remove(nepratele,j)
                end
                removeIt = true
                break
            end
        end

        -- Mráček vyletěl mimo mapu?
        if m.x < 0 or m.x>worldWidth or m.y<0 or m.y>worldHeight then
            removeIt = true
        end

        if removeIt then
            table.remove(mracky,i)
        end
    end
end

--------------------------------------------------------------------------------
-- FUNKCE: Zpracování Mystery bloků
--------------------------------------------------------------------------------
function checkMysteryBlocks(dt)
    -- Mystery blok se aktivuje, pokud hrdina narazí ze spodu
    -- Tj. hrdina: y + h ~ block.y, a hrdina se pohybuje nahoru
    -- Zjednodušeně: kolize + hrdina.rychlostY < 0 + hrdinova hlava je těsně pod blokem
    for i=#mysteryBlocks,1,-1 do
        local mb = mysteryBlocks[i]
        if not mb.opened then
            if kolize(hrac, mb) then
                -- Ověříme, zda byl úder zespodu:
                --   hrdina.rychlostY < 0 a
                --   hrac.y > mb.y (hlava je níž než spodek mystery bloku)
                if hrac.rychlostY < 0 and hrac.y > mb.y then
                    -- Otevřít Mystery blok
                    openMysteryBlock(mb)
                end
            end
        end
    end
end

function openMysteryBlock(block)
    block.opened = true
    -- Random power-up: 3 varianty
    local r = love.math.random(1,3)
    if r == 1 then
        -- (a) Hrdina dostane na 10s křídla => canFly
        hrac.canFly = true
        hrac.flyTimer = 10
        print("Power-up: křídla na 10s!")
    elseif r == 2 then
        -- (b) Hrdina se zvětší => isBig = true, 2x speed, střílí mráčky.
        hrac.isBig = true
        hrac.rychlost = hrac.baseSpeed * 2
        print("Power-up: BIG mode (2x speed, střílí mráčky)!")
    else
        -- (c) Hrdina dostane cylindr
        hrac.hasCilindr = true
        print("Power-up: Cylindr s červenou stužkou (módní doplněk)!")
    end
end

--------------------------------------------------------------------------------
-- LOVE.DRAW
--------------------------------------------------------------------------------
function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)

    -- Džunglově zelené pozadí
    love.graphics.clear(0.1, 0.7, 0.1)

    -- Vykreslení všech platforem
    for _, p in ipairs(platformy) do
        love.graphics.setColor(p.color)
        love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
    end

    -- Mystery bloky (žluté), pokud ještě nejsou otevřené
    for _, mb in ipairs(mysteryBlocks) do
        if not mb.opened then
            love.graphics.setColor(mb.color)
            love.graphics.rectangle("fill", mb.x, mb.y, mb.w, mb.h)
        else
            -- Můžete si nakreslit "prázdný" blok, z kterého nic už nevypadne,
            -- nebo ho smazat úplně. Zde ho jen nebudeme vykreslovat.
        end
    end

    -- Banány (fialové)
    love.graphics.setColor(0.7,0,0.7)
    for _, b in ipairs(banany) do
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    end

    -- Nepřátelé (fialoví) - i boss
    love.graphics.setColor(0.7,0,0.7)
    for _, n in ipairs(nepratele) do
        love.graphics.rectangle("fill", n.x, n.y, n.w, n.h)
    end

    -- Mráčky (světle šedá)
    love.graphics.setColor(0.9,0.9,0.9)
    for _, m in ipairs(mracky) do
        love.graphics.rectangle("fill", m.x, m.y, m.w, m.h)
    end

    -- Hráč
    local r,g,b = hrac:getColor()[1], hrac:getColor()[2], hrac:getColor()[3]
    love.graphics.setColor(r,g,b)
    love.graphics.rectangle("fill", hrac.x, hrac.y, hrac.w, hrac.h)

    -- Pokud má cylindr, můžeme nakreslit klobouk (např. malý obdélník nad hlavou)
    if hrac.hasCilindr then
        love.graphics.setColor(0,0,0)
        local hatW = hrac.w
        local hatH = 10
        local hatX = hrac.x
        local hatY = hrac.y - hatH
        love.graphics.rectangle("fill", hatX, hatY, hatW, hatH)
        -- Červená stužka
        love.graphics.setColor(1,0,0)
        love.graphics.rectangle("fill", hatX, hatY+hatH/2-1, hatW, 2)
    end

    love.graphics.pop()

    -- UI texty
    love.graphics.setColor(1,1,1)
    local msg = string.format("RED HP: %d   |   PINK HP: %d",
        hrac.health.red, hrac.health.pink)
    love.graphics.print(msg, 10, 10)

    if godMode then
        love.graphics.setColor(1,1,0)
        love.graphics.print("God mode (iddqd)", 10, 30)
    end
    if cheatFlyMode then
        love.graphics.setColor(1,1,0)
        love.graphics.print("Fly mode (prettyfly)", 10, 50)
    end

    if hraVyhrana then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Vyhrál jsi! (R pro restart)",
            0, screenHeight/2 - 20, screenWidth, "center")
    elseif gameOver then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Prohrál jsi! (R pro restart)",
            0, screenHeight/2 - 20, screenWidth, "center")
    end
end
