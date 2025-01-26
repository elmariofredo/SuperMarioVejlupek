function love.load()
    love.window.setMode(800, 600)
    love.window.setTitle("Větší svět s posouváním kamery a bossem")

    -- Velikost herního okna
    screenWidth = 800
    screenHeight = 600

    -- Velikost herního světa
    worldWidth = 2000
    worldHeight = 600  -- V tomto příkladu stejná jako výška okna, ale může být i větší

    -- Kamera
    camera = {
        x = 0,
        y = 0
    }

    -- Hráč
    hrac = {
        x = 50,
        y = 0,
        w = 20,
        h = 20,
        rychlost = 200,       -- horizontální rychlost
        rychlostY = 0,        -- vertikální rychlost (pád/skok)
        naZemi = false,
        maxSkoku = 2,         -- kolikrát může skočit (dvojitý skok)
        zbyvajiciSkoky = 2,   -- kolik skoků mu ještě zbývá aktuálně
        spaceDrzeno = false   -- pomocná proměnná pro detekci nového stisku mezerníku
    }

    -- Gravitační konstanta
    gravitace = 800

    -- Několik platforem v průběhu světa
    -- (můžete libovolně upravit, přidat/ubrat)
    platformy = {
        { x = 0,    y = 580,  w = 400, h = 20 },  -- startovní podlaha
        { x = 450,  y = 550,  w = 100, h = 20 },
        { x = 600,  y = 500,  w = 200, h = 20 },
        { x = 900,  y = 450,  w = 100, h = 20 },
        { x = 1200, y = 480,  w = 150, h = 20 },
        { x = 1500, y = 550,  w = 200, h = 20 },
        { x = 1800, y = 580,  w = 200, h = 20 },  -- plošina pro bosse
    }

    -- Menší nepřátelé (pohybují se tam a zpět) + jeden „velký boss“ na konci
    nepratele = {
        {
            x = 300, y = 560, w = 20, h = 20,
            rychlost = 100,
            smer = 1,           -- 1 = doprava, -1 = doleva
            levaHranice = 250,  -- mezi nimi se pohybuje
            pravaHranice = 400
        },
        {
            x = 700, y = 480, w = 20, h = 20,
            rychlost = 120,
            smer = -1,
            levaHranice = 600,
            pravaHranice = 800
        },
        -- Hlavní boss (větší, má víc "životů", nepohybuje se)
        {
            x = 1850, y = 540, w = 40, h = 40,
            rychlost = 0,
            smer = 0,
            levaHranice = 1850,
            pravaHranice = 1850,
            boss = true,  -- příznak, že jde o bosse
            hp = 3        -- počet zásahů (seskoků), než zemře
        }
    }

    -- Stav hry
    hraVyhrana = false
end

-- Pomocná funkce pro kolizi dvou obdélníků
local function kolize(a, b)
    return  a.x < b.x + b.w and
            a.x + a.w > b.x and
            a.y < b.y + b.h and
            a.y + a.h > b.y
end

function love.update(dt)
    if not hraVyhrana then
        -- Ovládání hráče (vodorovný pohyb)
        if love.keyboard.isDown("left") then
            hrac.x = hrac.x - hrac.rychlost * dt
        elseif love.keyboard.isDown("right") then
            hrac.x = hrac.x + hrac.rychlost * dt
        end

        -- Omezit hráče na hranice světa
        if hrac.x < 0 then hrac.x = 0 end
        if hrac.x + hrac.w > worldWidth then
            hrac.x = worldWidth - hrac.w
        end

        -- Skok (dvojitý skok)
        if love.keyboard.isDown("space") then
            if not hrac.spaceDrzeno then
                hrac.spaceDrzeno = true
                if hrac.zbyvajiciSkoky > 0 then
                    hrac.rychlostY = -300  -- síla skoku
                    hrac.zbyvajiciSkoky = hrac.zbyvajiciSkoky - 1
                end
            end
        else
            hrac.spaceDrzeno = false
        end

        -- Gravitační pád
        hrac.rychlostY = hrac.rychlostY + gravitace * dt
        hrac.y = hrac.y + hrac.rychlostY * dt

        -- Předpokládejme, že hráč je ve vzduchu
        hrac.naZemi = false

        -- Kolize s platformami (zjištění, zda stojí na zemi)
        for _, p in ipairs(platformy) do
            if kolize(hrac, p) then
                -- Kontrola, zda hráč padá shora dolů
                if hrac.rychlostY > 0 then
                    hrac.y = p.y - hrac.h
                    hrac.naZemi = true
                    hrac.rychlostY = 0
                    -- Obnova počtu možných skoků, když se dotkne země
                    hrac.zbyvajiciSkoky = hrac.maxSkoku
                end
            end
        end

        -- Pohyb nepřátel a kolize s hráčem
        for i = #nepratele, 1, -1 do
            local n = nepratele[i]

            -- Pokud není boss (boss = true), pohybuje se
            if not n.boss then
                n.x = n.x + n.smer * n.rychlost * dt
                if n.x < n.levaHranice then
                    n.x = n.levaHranice
                    n.smer = 1
                elseif n.x > n.pravaHranice then
                    n.x = n.pravaHranice
                    n.smer = -1
                end
            end

            -- Kontrola kolize hráče s nepřítelem
            if kolize(hrac, n) then
                -- Zjištění, zda hráč dopadl shora
                -- Podmínky:
                --   1) hráč padá dolů (hrac.rychlostY > 0)
                --   2) spodní hrana hráče je přibližně nad horní hranou nepřítele
                if hrac.rychlostY > 0 and (hrac.y + hrac.h) <= (n.y + 10) then
                    -- Pokud je to boss, sniž mu HP
                    if n.boss then
                        n.hp = n.hp - 1
                        if n.hp <= 0 then
                            -- Boss poražen => odstraníme ho ze seznamu
                            table.remove(nepratele, i)
                        end
                    else
                        -- Pokud to není boss, rovnou ho odstraníme
                        table.remove(nepratele, i)
                    end

                    -- Hráč se "odrazí" nahoru
                    hrac.rychlostY = -200
                else
                    -- Hráč zasáhne nepřítele z boku/spodku => restart pozice
                    hrac.x = 50
                    hrac.y = 0
                    hrac.rychlostY = 0
                    hrac.zbyvajiciSkoky = hrac.maxSkoku
                end
            end
        end

        -- Pokud už neexistuje žádný nepřítel (včetně bosse), vyhraje se
        if #nepratele == 0 then
            hraVyhrana = true
        end

        -- Update kamery, aby sledovala hráče
        -- Cílem je mít hráče cca uprostřed obrazovky
        camera.x = hrac.x - (screenWidth / 2)
        -- Omezit, aby kamera neukazovala "mimo" svět
        if camera.x < 0 then camera.x = 0 end
        if camera.x > (worldWidth - screenWidth) then
            camera.x = worldWidth - screenWidth
        end
    else
        -- Po výhře lze restartovat
        if love.keyboard.isDown("r") then
            love.load()
        end
    end
end

function love.draw()
    -- Posun kamery
    love.graphics.push()            -- uložíme aktuální transformační matici
    love.graphics.translate(-camera.x, -camera.y)

    -- Vykreslení "pozadí" (pro jednoduchost jen bílá)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, worldWidth, worldHeight)

    -- Platformy (šedé)
    love.graphics.setColor(0.5, 0.5, 0.5)
    for _, p in ipairs(platformy) do
        love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
    end

    -- Nepřátelé (červení), boss (fialový)
    for _, n in ipairs(nepratele) do
        if n.boss then
            -- Boss = fialová barva
            love.graphics.setColor(0.7, 0, 0.7)
        else
            -- Obyčejný nepřítel = červená barva
            love.graphics.setColor(1, 0, 0)
        end
        love.graphics.rectangle("fill", n.x, n.y, n.w, n.h)
    end

    -- Hráč (modrý)
    love.graphics.setColor(0, 0, 1)
    love.graphics.rectangle("fill", hrac.x, hrac.y, hrac.w, hrac.h)

    -- Vrátíme se zpět k původnímu nastavení kamery
    love.graphics.pop()

    -- Text po výhře
    if hraVyhrana then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Boss je poražen! (R pro restart)",
            0, screenHeight/2 - 20, screenWidth, "center")
    end
end
