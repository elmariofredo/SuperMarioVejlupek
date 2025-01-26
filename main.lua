function love.load()
    -- Nastavení okna
    love.window.setMode(800, 600)
    love.window.setTitle("Jednoduchá platformovka")

    -- Hráč
    hrac = {
        x = 50,
        y = 0,
        w = 20,
        h = 20,
        rychlost = 200,
        rychlostY = 0,
        naZemi = false
    }

    -- Gravitační konstanta
    gravitace = 800

    -- Platformy (můžete jich přidat libovolný počet)
    platformy = {
        { x = 0,   y = 580, w = 800, h = 20 },  -- podlaha
        { x = 200, y = 450, w = 100, h = 20 },
        { x = 400, y = 350, w = 100, h = 20 }
    }

    -- Nepřátelé (pro jednoduchost jeden)
    -- Nepřítel se bude pohybovat doleva a doprava mezi dvěma body
    nepratele = {
        {
            x = 300,
            y = 560,
            w = 20,
            h = 20,
            rychlost = 100,
            smer = 1,    -- 1 = doprava, -1 = doleva
            levaHranice = 300,
            pravaHranice = 500
        }
    }

    -- Cíl
    cil = { x = 750, y = 560, w = 20, h = 20 }

    -- Stav hry
    hraVyhrana = false
end

-- Pomocná funkce pro kontrolu kolizí mezi dvěma obdélníky
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

        -- Skok
        if love.keyboard.isDown("space") and hrac.naZemi then
            hrac.rychlostY = -300  -- síla skoku
            hrac.naZemi = false
        end

        -- Gravitační pád
        hrac.rychlostY = hrac.rychlostY + gravitace * dt
        hrac.y = hrac.y + hrac.rychlostY * dt

        -- Kontrola kolize s platformami
        hrac.naZemi = false
        for _, p in ipairs(platformy) do
            if kolize(hrac, p) then
                -- Opravit polohu, aby "seděl" na platformě
                if hrac.rychlostY > 0 then
                    hrac.y = p.y - hrac.h
                    hrac.naZemi = true
                    hrac.rychlostY = 0
                end
            end
        end

        -- Pohyb nepřítele
        for _, n in ipairs(nepratele) do
            n.x = n.x + n.smer * n.rychlost * dt
            -- Pokud dojde k hranici, otočí směr
            if n.x < n.levaHranice then
                n.x = n.levaHranice
                n.smer = 1
            elseif n.x > n.pravaHranice then
                n.x = n.pravaHranice
                n.smer = -1
            end

            -- Kontrola kolize hráče a nepřítele
            if kolize(hrac, n) then
                -- Reset pozice hráče při kolizi
                hrac.x = 50
                hrac.y = 0
                hrac.rychlostY = 0
            end
        end

        -- Kontrola dosažení cíle
        if kolize(hrac, cil) then
            hraVyhrana = true
        end
    else
        -- Po výhře lze restartovat hru
        if love.keyboard.isDown("r") then
            love.load()
        end
    end
end

function love.draw()
    -- Vykreslení platform
    love.graphics.setColor(0.5, 0.5, 0.5)
    for _, p in ipairs(platformy) do
        love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
    end

    -- Vykreslení nepřátel (červeně)
    love.graphics.setColor(1, 0, 0)
    for _, n in ipairs(nepratele) do
        love.graphics.rectangle("fill", n.x, n.y, n.w, n.h)
    end

    -- Vykreslení cíle (zeleně)
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle("fill", cil.x, cil.y, cil.w, cil.h)

    -- Vykreslení hráče (modře)
    love.graphics.setColor(0, 0, 1)
    love.graphics.rectangle("fill", hrac.x, hrac.y, hrac.w, hrac.h)

    -- Text po výhře
    if hraVyhrana then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Vyhrál jsi! Stiskni R pro restart.", 300, 250, 0, 2, 2)
    end
end
