function love.load()
    -- Okno
    love.window.setMode(800, 600)
    love.window.setTitle("Obří svět s hnědým bossem, banány a dvoubarevným hrdinou")

    -- Rozměry okna a světa
    screenWidth = 800
    screenHeight = 600
    worldWidth = 2000 * 5    -- svět 5x širší (10 000 px)
    worldHeight = 600

    -- Kamera
    camera = { x = 0, y = 0 }

    -- Hráč (dvě barvy, oddělené životy)
    hrac = {
        x = 50,
        y = 0,
        w = 20,
        h = 20,

        rychlost = 200,     -- horizontální rychlost
        rychlostY = 0,      -- vertikální rychlost (pád/skok)
        naZemi = false,
        maxSkoku = 2,       -- dvojitý skok
        zbyvajiciSkoky = 2,

        -- Dvě sady životů pro dvě barvy
        health = {
            red = 3,
            pink = 3,
        },

        -- Aktivní barva (red/pink)
        activeColor = "red",

        -- Definice RGB pro obě barvy
        colors = {
            red  = {1, 0, 0},
            pink = {1, 0.7, 0.8}
        },

        spaceDrzeno = false -- pomocná proměnná pro detekci nového stisku mezerníku
    }

    -- Jednoduché funkce pro práci s barvou hrdiny a životy
    function hrac:getColor()
        return self.colors[self.activeColor]
    end

    -- Když hráč dostane zásah (ztrácí 1 život aktuální barvy)
    function hrac:takeDamage()
        self.health[self.activeColor] = self.health[self.activeColor] - 1

        -- Pokud tato barva padla na 0, zkus automaticky přepnout na druhou
        if self.health[self.activeColor] <= 0 then
            if self.activeColor == "red" then
                -- Pokus o přepnutí na růžovou
                if self.health["pink"] > 0 then
                    self.activeColor = "pink"
                else
                    -- Růžová má taky 0 => konec hry
                    gameOver = true
                end
            else
                -- Pokus o přepnutí na červenou
                if self.health["red"] > 0 then
                    self.activeColor = "red"
                else
                    gameOver = true
                end
            end
        end
    end

    -- Přepnutí barvy klávesou P (pokud druhá barva ještě má životy)
    function hrac:switchColor()
        if self.activeColor == "red" and self.health["pink"] > 0 then
            self.activeColor = "pink"
        elseif self.activeColor == "pink" and self.health["red"] > 0 then
            self.activeColor = "red"
        end
    end

    -- Gravitační konstanta
    gravitace = 800

    -- Platformy – můžete přidat více. Svět je dlouhý 10 000, takže některé umístíme dále
    platformy = {
        { x = 0,     y = 580,  w = 400, h = 20 },
        { x = 600,   y = 550,  w = 120, h = 20 },
        { x = 900,   y = 500,  w = 200, h = 20 },
        { x = 1300,  y = 480,  w = 200, h = 20 },
        { x = 1700,  y = 550,  w = 200, h = 20 },
        { x = 2200,  y = 550,  w = 200, h = 20 },
        { x = 2600,  y = 580,  w = 400, h = 20 },
        { x = 3000,  y = 500,  w = 200, h = 20 },
        { x = 3300,  y = 540,  w = 150, h = 20 },
        { x = 3600,  y = 580,  w = 300, h = 20 },
        { x = 4000,  y = 550,  w = 200, h = 20 },
        { x = 4400,  y = 580,  w = 400, h = 20 },
        { x = 5000,  y = 550,  w = 200, h = 20 },
        { x = 5400,  y = 580,  w = 300, h = 20 },  -- plošina pro bosse (konec světa)
    }

    -- Nepřátelé (menší) + Boss na konci
    nepratele = {
        {
            x = 300,  y = 560, w = 20,  h = 20,
            rychlost = 100,
            smer = 1,
            levaHranice = 250,
            pravaHranice = 400
        },
        {
            x = 700,  y = 480, w = 20,  h = 20,
            rychlost = 120,
            smer = -1,
            levaHranice = 600,
            pravaHranice = 800
        },
        -- Boss (hnědý, velký, skáče a střílí banány)
        {
            boss = true,
            hp = 3,             -- kolikrát na něj hrdina musí skočit
            x = 9800,           -- téměř na konci světa
            y = 480,
            w = 100,
            h = 100,
            vy = 0,             -- vertikální rychlost
            naZemi = false,     -- zda je boss na zemi
            jumpTimer = 2,      -- čas do dalšího skoku
            shootTimer = 1,     -- čas do další střelby
            barva = {0.6,0.3,0},-- hnědá
        }
    }

    -- Banány vystřelené bossem
    banany = {}

    -- Stav hry
    hraVyhrana = false
    gameOver = false
end

--------------------------------------------------------------------------------
-- Pomocné funkce
--------------------------------------------------------------------------------

local function kolize(a, b)
    return  a.x < b.x + b.w and
            a.x + a.w > b.x and
            a.y < b.y + b.h and
            a.y + a.h > b.y
end

-- Funkce, kterou boss volá ke střelbě banánu
local function bossShootBanana(boss, dt)
    -- Boss bude mířit směrem k hráči
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
        w = 10,
        h = 10,
        vx = dx * speed,
        vy = dy * speed
    }
    table.insert(banany, banana)
end

--------------------------------------------------------------------------------
-- UPDATE
--------------------------------------------------------------------------------

function love.update(dt)
    if hraVyhrana or gameOver then
        -- Po výhře nebo konci hry lze restartovat
        if love.keyboard.isDown("r") then
            love.load()
        end
        return
    end

    ----------------------------------------------------------------------------
    -- Ovládání hrdiny
    ----------------------------------------------------------------------------
    if love.keyboard.isDown("left") then
        hrac.x = hrac.x - hrac.rychlost * dt
    elseif love.keyboard.isDown("right") then
        hrac.x = hrac.x + hrac.rychlost * dt
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

    -- Přepnutí barvy (klávesa P)
    if love.keyboard.isDown("p") then
        -- Pro jednoduchost: přepneme jen jednou za stisk
        -- (uděláme si "cooldown" 0.2s třeba)
        if not hrac.switchCooldown then
            hrac.switchCooldown = 0.2
            hrac:switchColor()
        end
    end
    if hrac.switchCooldown then
        hrac.switchCooldown = hrac.switchCooldown - dt
        if hrac.switchCooldown <= 0 then
            hrac.switchCooldown = nil
        end
    end

    ----------------------------------------------------------------------------
    -- Gravitační pád hrdiny
    ----------------------------------------------------------------------------
    hrac.rychlostY = hrac.rychlostY + gravitace * dt
    hrac.y = hrac.y + hrac.rychlostY * dt

    -- Hrdina není na zemi, dokud to neprokáže kolize s platformou
    hrac.naZemi = false

    -- Omezit hrdinu na okraje světa
    if hrac.x < 0 then
        hrac.x = 0
    end
    if hrac.x + hrac.w > worldWidth then
        hrac.x = worldWidth - hrac.w
    end

    ----------------------------------------------------------------------------
    -- Kolize hrdiny s platformami (podlaha)
    ----------------------------------------------------------------------------
    for _, p in ipairs(platformy) do
        if kolize(hrac, p) then
            -- Hrdina padal shora
            if hrac.rychlostY > 0 then
                hrac.y = p.y - hrac.h
                hrac.rychlostY = 0
                hrac.naZemi = true
                hrac.zbyvajiciSkoky = hrac.maxSkoku
            end
        end
    end

    ----------------------------------------------------------------------------
    -- Nepřátelé (včetně bosse)
    ----------------------------------------------------------------------------
    for i = #nepratele, 1, -1 do
        local n = nepratele[i]

        if not n.boss then
            -- Obyčejný nepřítel (chodící tam a zpět)
            n.x = n.x + n.smer * n.rychlost * dt
            if n.x < n.levaHranice then
                n.x = n.levaHranice
                n.smer = 1
            elseif n.x > n.pravaHranice then
                n.x = n.pravaHranice
                n.smer = -1
            end
        else
            -- Bossova AI: skákání a střílení banánů

            -- Gravitační pád bosse
            n.vy = n.vy + gravitace * dt
            n.y = n.y + n.vy * dt

            -- Zjistit, zda boss stojí na nějaké platformě
            n.naZemi = false
            for _, p in ipairs(platformy) do
                -- Zajímá nás kolize jen pokud boss padá shora
                if    n.x + n.w > p.x
                  and n.x < p.x + p.w
                  and n.y + n.h <= p.y + 5  -- rezerva
                  and n.vy > 0 then
                    -- boss dopadá na platformu
                    if n.y + n.h > p.y then
                        n.y = p.y - n.h
                        n.vy = 0
                        n.naZemi = true
                    end
                end
            end

            -- Skákání bosse
            n.jumpTimer = n.jumpTimer - dt
            if n.jumpTimer <= 0 and n.naZemi then
                -- boss skočí
                n.vy = -400
                n.jumpTimer = 2 + math.random() * 2  -- do dalšího skoku
            end

            -- Střílení banánů
            n.shootTimer = n.shootTimer - dt
            if n.shootTimer <= 0 then
                bossShootBanana(n, dt)
                n.shootTimer = 1.5 + math.random() * 2
            end
        end

        -- Kolize hrdiny s nepřítelem (n)
        if kolize(hrac, n) then
            -- Dopadl hrdina shora?
            if hrac.rychlostY > 0 and (hrac.y + hrac.h) <= (n.y + 10) then
                -- Pokud je to boss, snížíme jeho HP
                if n.boss then
                    n.hp = n.hp - 1
                    if n.hp <= 0 then
                        -- Boss je poražen
                        table.remove(nepratele, i)
                    end
                else
                    -- Obyčejný nepřítel – rovnou ho odstraníme
                    table.remove(nepratele, i)
                end
                -- Hráč se odrazí
                hrac.rychlostY = -200
            else
                -- Z boku / zespodu => hrdina dostává zásah
                hrac:takeDamage()
                -- Vrátit hrdinu na start
                hrac.x = 50
                hrac.y = 0
                hrac.rychlostY = 0
                hrac.zbyvajiciSkoky = hrac.maxSkoku
            end
        end
    end

    ----------------------------------------------------------------------------
    -- Pohyb a kolize banánů
    ----------------------------------------------------------------------------
    for i = #banany, 1, -1 do
        local b = banany[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt

        -- Pokud banán trefí hrdinu
        if kolize(b, hrac) then
            hrac:takeDamage()
            -- Vrátit hrdinu na start (jako trest)
            hrac.x = 50
            hrac.y = 0
            hrac.rychlostY = 0
            hrac.zbyvajiciSkoky = hrac.maxSkoku

            table.remove(banany, i)
        -- Nebo vyletí ze světa
        elseif b.x < 0 or b.x > worldWidth or b.y < 0 or b.y > worldHeight then
            table.remove(banany, i)
        end
    end

    ----------------------------------------------------------------------------
    -- Kontrola, zda jsou všichni nepřátelé (včetně bosse) pryč -> výhra
    ----------------------------------------------------------------------------
    if #nepratele == 0 then
        hraVyhrana = true
    end

    ----------------------------------------------------------------------------
    -- Kontrola, zda hrdina vyčerpal obě barvy
    ----------------------------------------------------------------------------
    if gameOver then
        -- Nic víc, jen umožnit restart
    end

    ----------------------------------------------------------------------------
    -- Kamera sleduje hrdinu (horizontálně)
    ----------------------------------------------------------------------------
    camera.x = hrac.x - screenWidth/2
    if camera.x < 0 then camera.x = 0 end
    if camera.x > worldWidth - screenWidth then
        camera.x = worldWidth - screenWidth
    end
end

--------------------------------------------------------------------------------
-- DRAW
--------------------------------------------------------------------------------

function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)

    -- Pozadí (světle šedé)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle("fill", 0, 0, worldWidth, worldHeight)

    -- Platformy (šedé)
    love.graphics.setColor(0.5, 0.5, 0.5)
    for _, p in ipairs(platformy) do
        love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
    end

    -- Banány (žluté)
    love.graphics.setColor(1, 1, 0)
    for _, b in ipairs(banany) do
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    end

    -- Nepřátelé (červení), Boss (hnědý)
    for _, n in ipairs(nepratele) do
        if n.boss then
            love.graphics.setColor(n.barva)  -- hnědá
        else
            love.graphics.setColor(1, 0, 0)  -- červená
        end
        love.graphics.rectangle("fill", n.x, n.y, n.w, n.h)
    end

    -- Hráč – barva podle activeColor
    love.graphics.setColor(hrac:getColor())
    love.graphics.rectangle("fill", hrac.x, hrac.y, hrac.w, hrac.h)

    love.graphics.pop()

    ----------------------------------------------------------------------------
    -- Texty rozhraní (UI) + stavy hry
    ----------------------------------------------------------------------------
    love.graphics.setColor(1, 1, 1)

    -- Vypíšeme životy: RED a PINK
    local msg = string.format("RED HP: %d  |  PINK HP: %d",
        hrac.health.red, hrac.health.pink)
    love.graphics.print(msg, 10, 10)

    if hraVyhrana then
        local text = "Vyhrál jsi! Porazil jsi bosse. (R pro restart)"
        love.graphics.printf(text, 0, screenHeight/2 - 20, screenWidth, "center")
    elseif gameOver then
        local text = "Prohrál jsi! (R pro restart)"
        love.graphics.printf(text, 0, screenHeight/2 - 20, screenWidth, "center")
    end
end
