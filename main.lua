-------------------------------------------------------
-- main.lua
-------------------------------------------------------
function love.load()
    love.window.setMode(800, 600)
    love.window.setTitle("Velký svět, generované platformy, boss, god mód 'iddqd'")

    -- Rozměry okna a herního světa
    screenWidth = 800
    screenHeight = 600
    worldWidth = 10000   -- 5x větší než původních 2000
    worldHeight = 600

    -- Kamera (posun ve světě)
    camera = { x = 0, y = 0 }

    ---------------------------------------------------
    -- Hráč (systém dvou barev + životy)
    ---------------------------------------------------
    hrac = {
        x = 50,
        y = 0,
        w = 20,
        h = 20,

        rychlost = 200,      -- vodorovná rychlost
        rychlostY = 0,       -- svislá rychlost (pád, skok)
        naZemi = false,
        maxSkoku = 2,        -- dvojitý skok
        zbyvajiciSkoky = 2,

        -- Každá barva má vlastní životy
        health = {
            red = 3,
            pink = 3,
        },

        -- Aktivní barva (red / pink)
        activeColor = "red",

        -- Definice RGB pro obě barvy
        colors = {
            red  = {1, 0, 0},        -- červená
            pink = {1, 0.7, 0.8},    -- růžová
        },

        spaceDrzeno = false,  -- pomocná proměnná pro skok
        switchCooldown = 0,   -- aby se barva nepřepínala opakovaně při držení klávesy

        -- Funkce pro získání aktuální barvy (RGB)
        getColor = function(self)
            return self.colors[self.activeColor]
        end
    }

    -- Metoda pro ztrátu života (respektuje god mód)
    function hrac:takeDamage()
        if godMode then
            return -- v god módu se nic nestane
        end
        self.health[self.activeColor] = self.health[self.activeColor] - 1
        -- Pokud aktuální barva klesla na 0 => automatické přepnutí na druhou (pokud má životy)
        if self.health[self.activeColor] <= 0 then
            if self.activeColor == "red" then
                if self.health["pink"] > 0 then
                    self.activeColor = "pink"
                else
                    gameOver = true
                end
            else -- byla pink
                if self.health["red"] > 0 then
                    self.activeColor = "red"
                else
                    gameOver = true
                end
            end
        end
    end

    -- Přepnutí barvy (klávesa P)
    function hrac:switchColor()
        if self.activeColor == "red" and self.health["pink"] > 0 then
            self.activeColor = "pink"
        elseif self.activeColor == "pink" and self.health["red"] > 0 then
            self.activeColor = "red"
        end
    end

    ---------------------------------------------------
    -- Herní stav
    ---------------------------------------------------
    gravitace = 800
    hraVyhrana = false
    gameOver = false
    godMode = false  -- po zadání iddqd
    typedSequence = "" -- pro odposlech kláves (god mód)

    ---------------------------------------------------
    -- Vygenerujeme platformy
    ---------------------------------------------------
    platformy = generatePlatforms(worldWidth)

    -- Nepřátelé: pár menších + 1 boss na konci
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
        -- Boss (fialový, velký, střílí banány, skáče)
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
            -- barva pro bosse později přepíšeme na fialovou při vykreslování
        }
    }

    -- Střely (banány)
    banany = {}

    -- Pro zapamatování "poslední bezpečné platformy", na které hrdina stál
    lastSafePlatform = nil
end

--------------------------------------------------------------------------------
-- GENERÁTOR PLATFOREM
--------------------------------------------------------------------------------
-- Vytvoří seznam platform napříč světem,
-- aby hráč teoreticky mohl přeskočit z jedné na druhou.
--------------------------------------------------------------------------------
function generatePlatforms(maxWidth)
    local plats = {}
    -- Začneme někde poblíž x=0
    local x = 0
    local y = 500  -- výchozí výška
    local stepCount = 0

    -- Dokud se nevejdeme do konce světa, generujeme
    while x < maxWidth - 300 do
        stepCount = stepCount + 1

        -- Vytvoříme novou platformu
        local p = {}
        p.x = x
        p.w = 200

        -- Horizontální posun  (300 ± 50)
        local dx = 300 + love.math.random(-50, 50)
        x = x + dx

        -- Vertikální posun (-50..50), omezíme do rozmezí [100..500]
        local dy = love.math.random(-50, 50)
        y = y + dy
        if y < 100 then y = 100 end
        if y > 500 then y = 500 end

        p.y = y

        -- Tloušťka platformy
        -- Pro normální i padající dáme trochu náhodné h
        -- Pro trampolíny zvolíme jednotně 15
        p.h = 20

        -- Určíme, zda je platforma speciální (padající nebo trampolína)
        -- Např. 10% trampolín, 10% padajících
        local randType = love.math.random(1, 100)
        if randType <= 10 then
            -- trampolína (bounce)
            p.bounce = true
            p.color = {0, 0, 0}  -- černá
            p.h = 15
        elseif randType <= 20 then
            -- padající (falling)
            p.falling = true
            p.color = {1, 0.8, 0.5} -- trochu světlejší cihlová/oranž
            p.h = 10
        else
            -- normální platforma
            p.bounce = false
            p.falling = false
            p.color = {0.7, 0.3, 0.3} -- cihlová
        end

        table.insert(plats, p)

        -- Po cca 30 generovaných platformách si můžeme nechat větší mezeru atd.
        -- (Zde jen ukázka, pro zjednodušení nic speciálního neděláme.)
    end

    -- Přidáme finální platformu pro bosse (pevně u x ~ 9700)
    local bossPlat = {
        x = maxWidth - 300,
        y = 550,
        w = 300,
        h = 20,
        color = {0.7, 0.3, 0.3}, -- cihlová
        bounce = false,
        falling = false
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
-- BOSS vystřelí "banán" (fialová střela) směrem k hrdinovi
--------------------------------------------------------------------------------
local function bossShootBanana(boss, dt)
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
-- LOVE.UPDATE
--------------------------------------------------------------------------------
function love.update(dt)
    -- Pokud je konec hry (výhra/prohra), čekáme na R pro restart
    if hraVyhrana or gameOver then
        if love.keyboard.isDown("r") then
            love.load()
        end
        return
    end

    ----------------------------------------------------------------------------
    -- Pohyb hráče
    ----------------------------------------------------------------------------
    if love.keyboard.isDown("left") then
        hrac.x = hrac.x - hrac.rychlost * dt
    elseif love.keyboard.isDown("right") then
        hrac.x = hrac.x + hrac.rychlost * dt
    end

    -- Omezit pohyb do hranic světa
    if hrac.x < 0 then hrac.x = 0 end
    if hrac.x + hrac.w > worldWidth then
        hrac.x = worldWidth - hrac.w
    end

    -- Skok (dvojitý)
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

    -- Přepínání barvy (klávesa P)
    if love.keyboard.isDown("p") then
        if hrac.switchCooldown <= 0 then
            hrac.switchCooldown = 0.3  -- aby nedošlo k opakovanému přepnutí
            hrac:switchColor()
        end
    end
    if hrac.switchCooldown > 0 then
        hrac.switchCooldown = hrac.switchCooldown - dt
    end

    -- Gravitační pád
    hrac.rychlostY = hrac.rychlostY + gravitace * dt
    hrac.y = hrac.y + hrac.rychlostY * dt

    -- Hráč není na zemi, dokud to nepotvrdí kolize
    hrac.naZemi = false

    ----------------------------------------------------------------------------
    -- Kolize s platformami
    ----------------------------------------------------------------------------
    local stoodOnPlatformThisFrame = false

    for i = #platformy, 1, -1 do
        -- (Nevyužité, kdybychom platformy mazali i jinak, teď nepotřebujeme.)
    end

    for i=#platformy,1,-1 do
        local p = platformy[i]
        if kolize(hrac, p) then
            -- Kontrola, zda hráč dopadá shora
            if hrac.rychlostY > 0 then
                -- Nastavíme hráče nad platformu
                hrac.y = p.y - hrac.h
                hrac.rychlostY = 0
                hrac.naZemi = true
                hrac.zbyvajiciSkoky = hrac.maxSkoku

                -- Pokud je to trampolína (bounce), tak ho vymrští nahoru
                if p.bounce then
                    hrac.rychlostY = -500
                end

                -- Pokud je to padající platforma, okamžitě ji odstraníme (propadne)
                if p.falling then
                    table.remove(platformy, i)
                else
                    -- Pokud to není padající, považujeme ji za "bezpečnou"
                    lastSafePlatform = p
                    stoodOnPlatformThisFrame = true
                end
            end
        end
    end

    -- Pokud jsme tento frame nestoupli na žádnou platformu, zůstává lastSafePlatform nezměněná

    ----------------------------------------------------------------------------
    -- Kontrola, zda hráč "propadl" pod úroveň poslední bezpečné platformy
    ----------------------------------------------------------------------------
    if lastSafePlatform ~= nil then
        -- Řekneme, že pokud hráčova spodní hrana je
        -- > (lastSafePlatform.y + 200), považujeme to za pád (lze upravit, aby to nebylo hned)
        local padThreshold = lastSafePlatform.y + 200
        if (hrac.y + hrac.h) > padThreshold then
            -- Hráč spadl
            hrac:takeDamage()
            -- Reset pozice na poslední bezpečnou platformu (pokud ještě existuje)
            if not gameOver then
                hrac.x = lastSafePlatform.x + 10
                hrac.y = lastSafePlatform.y - hrac.h
                hrac.rychlostY = 0
                hrac.zbyvajiciSkoky = hrac.maxSkoku
            end
        end
    end

    ----------------------------------------------------------------------------
    -- Pohyb / AI nepřátel (včetně bosse)
    ----------------------------------------------------------------------------
    for i = #nepratele, 1, -1 do
        local n = nepratele[i]

        if not n.boss then
            -- Obyčejný nepřítel (fialový), pohyb tam a zpět
            n.x = n.x + n.smer * n.rychlost * dt
            if n.x < n.levaHranice then
                n.x = n.levaHranice
                n.smer = 1
            elseif n.x + n.w > n.pravaHranice then
                n.x = n.pravaHranice - n.w
                n.smer = -1
            end
        else
            -- BOSS
            -- Gravitační pád
            n.vy = n.vy + gravitace * dt
            n.y = n.y + n.vy * dt
            n.naZemi = false

            -- Zjišťujeme, zda boss stojí na nějaké platformě
            for _, p in ipairs(platformy) do
                -- Šířkou se překrývají?
                if  (n.x + n.w > p.x) and
                    (n.x < p.x + p.w) and
                    (n.y + n.h <= p.y + 5) and
                    (n.vy > 0) then
                    -- boss dopadá shora
                    if n.y + n.h > p.y then
                        n.y = p.y - n.h
                        n.vy = 0
                        n.naZemi = true
                        break
                    end
                end
            end

            -- Boss skáče v intervalu
            n.jumpTimer = n.jumpTimer - dt
            if n.jumpTimer <= 0 and n.naZemi then
                n.vy = -400
                n.jumpTimer = 2 + love.math.random() * 2
            end

            -- Boss střílí banány
            n.shootTimer = n.shootTimer - dt
            if n.shootTimer <= 0 then
                bossShootBanana(n, dt)
                n.shootTimer = 1.5 + love.math.random() * 2
            end
        end

        -- Kolize hrdiny s nepřítelem
        if kolize(hrac, n) then
            -- Dopadl na hlavu?
            if hrac.rychlostY > 0 and (hrac.y + hrac.h) <= (n.y + 10) then
                -- Boss nebo obyč. nepřítel
                if n.boss then
                    n.hp = n.hp - 1
                    if n.hp <= 0 then
                        table.remove(nepratele, i)
                    end
                else
                    table.remove(nepratele, i)
                end
                hrac.rychlostY = -200 -- odraz
            else
                -- Z boku / zespodu => hrdina dostane damage
                hrac:takeDamage()
                -- Vrátí se na poslední bezpečnou platformu
                if lastSafePlatform ~= nil and (not gameOver) then
                    hrac.x = lastSafePlatform.x + 10
                    hrac.y = lastSafePlatform.y - hrac.h
                    hrac.rychlostY = 0
                    hrac.zbyvajiciSkoky = hrac.maxSkoku
                end
            end
        end
    end

    ----------------------------------------------------------------------------
    -- Pohyb banánů + kolize s hrdinou
    ----------------------------------------------------------------------------
    for i = #banany, 1, -1 do
        local b = banany[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt

        -- Kolize s hrdinou
        if kolize(b, hrac) then
            hrac:takeDamage()
            if lastSafePlatform ~= nil and (not gameOver) then
                hrac.x = lastSafePlatform.x + 10
                hrac.y = lastSafePlatform.y - hrac.h
                hrac.rychlostY = 0
            end
            table.remove(banany, i)
        -- Banán mimo svět
        elseif b.x < 0 or b.x > worldWidth or b.y < 0 or b.y > worldHeight then
            table.remove(banany, i)
        end
    end

    ----------------------------------------------------------------------------
    -- Pokud jsou všichni nepřátelé (včetně bosse) pryč => výhra
    ----------------------------------------------------------------------------
    if #nepratele == 0 then
        hraVyhrana = true
    end

    ----------------------------------------------------------------------------
    -- Kamera
    ----------------------------------------------------------------------------
    camera.x = hrac.x - screenWidth/2
    if camera.x < 0 then camera.x = 0 end
    if camera.x > worldWidth - screenWidth then
        camera.x = worldWidth - screenWidth
    end
end

--------------------------------------------------------------------------------
-- LOVE.KEYPRESSED -> sledujeme zadání "iddqd" pro godMode
--------------------------------------------------------------------------------
function love.keypressed(key)
    -- Přidáme klávesu do sledované sekvence
    typedSequence = typedSequence .. key
    -- Ořízneme, aby nebyla delší než 5 znaků
    if #typedSequence > 5 then
        typedSequence = string.sub(typedSequence, -5)
    end

    -- Kontrola, zda končí na "iddqd"
    if typedSequence == "iddqd" then
        godMode = true
        -- Pro vizuální potvrzení můžeme krátce vypsat do konzole:
        print("GOD MODE ACTIVATED!")
    end
end

--------------------------------------------------------------------------------
-- LOVE.DRAW
--------------------------------------------------------------------------------
function love.draw()
    -- Posun kamery
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)

    -- Pozadí: džunglově zelené
    love.graphics.clear(0.1, 0.7, 0.1)

    -- Vykreslení všech platforem
    for _, p in ipairs(platformy) do
        love.graphics.setColor(p.color)
        love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
    end

    -- Banány (vystřely bosse) – nakreslíme fialovou
    love.graphics.setColor(0.7, 0, 0.7)
    for _, b in ipairs(banany) do
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    end

    -- Nepřátelé fialoví (včetně bosse)
    for _, n in ipairs(nepratele) do
        love.graphics.setColor(0.7, 0, 0.7)  -- fialová
        love.graphics.rectangle("fill", n.x, n.y, n.w, n.h)
    end

    -- Hráč: barva podle activeColor
    love.graphics.setColor(hrac:getColor())
    love.graphics.rectangle("fill", hrac.x, hrac.y, hrac.w, hrac.h)

    love.graphics.pop()

    ----------------------------------------------------------------------------
    -- UI / texty
    ----------------------------------------------------------------------------
    love.graphics.setColor(1,1,1)
    local msg = string.format("RED HP: %d   |   PINK HP: %d",
        hrac.health.red, hrac.health.pink)
    love.graphics.print(msg, 10, 10)

    if godMode then
        love.graphics.setColor(1,1,0)
        love.graphics.print("GOD MODE", 10, 30)
    end

    if hraVyhrana then
        local txt = "Vyhrál jsi! (R pro restart)"
        love.graphics.printf(txt, 0, screenHeight/2 - 20, screenWidth, "center")
    elseif gameOver then
        local txt = "Prohrál jsi! (R pro restart)"
        love.graphics.printf(txt, 0, screenHeight/2 - 20, screenWidth, "center")
    end
end
