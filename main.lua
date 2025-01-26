function love.load()
    -- Nastavení okna
    love.window.setMode(800, 600)
    love.window.setTitle("Jednoduchá platformovka s dvojitým skokem")

    -- Hráč
    hrac = {
        x = 50,
        y = 0,
        w = 20,
        h = 20,
        rychlost = 200,
        rychlostY = 0,
        naZemi = false,
        maxSkoku = 2,       -- kolikrát může skočit (dvojitý skok = 2)
        zbyvajiciSkoky = 2  -- kolik skoků mu ještě zbývá aktuálně
    }

    -- Gravitační konstanta
    gravitace = 800

    -- Platformy (můžete jich přidat, kolik chcete)
    platformy = {
        { x = 0,   y = 580, w = 800, h = 20 },  -- podlaha
        { x = 200, y = 450, w = 100, h = 20 },
        { x = 400, y = 350, w = 100, h = 20 }
    }

    -- Nepřátelé
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

        -- Skok (dvojitý skok)
        if love.keyboard.isDown("space") then
            -- Kontrola, zda je to čerstvě stisknutá klávesa (zabránění "drženého" stisku)
            -- v LÖVE byste mohli použít love.keypressed, ale pro jednoduchost to můžeme řešit
            -- krátkým trvalým stiskem. Níže je jednoduchá ukázka "cooldownu" pro skok.
            if not hrac.spaceDrzeno then
                hrac.spaceDrzeno = true  -- zamezí opakovanému vyvolání uvnitř jediného stisku
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

        -- Nejprve předpokládejme, že hráč ve vzduchu
        hrac.naZemi = false

        -- Kontrola kolize s platformami
        for _, p in ipairs(platformy) do
            if kolize(hrac, p) then
                -- Opravit polohu, aby "seděl" na platformě (jen pokud padá shora)
                if hrac.rychlostY > 0 then
                    hrac.y = p.y - hrac.h
                    hrac.naZemi = true
                    hrac.rychlostY = 0
                    -- Když se dotkne země/platformy, obnoví počet skoků
                    hrac.zbyvajiciSkoky = hrac.maxSkoku
                end
            end
        end

        -- Pohyb nepřítele a kontrola kolize s hráčem
        for i = #nepratele, 1, -1 do
            local n = nepratele[i]
            -- Pohyb nepřítele
            n.x = n.x + n.smer * n.rychlost * dt
            if n.x < n.levaHranice then
                n.x = n.levaHranice
                n.smer = 1
            elseif n.x > n.pravaHranice then
                n.x = n.pravaHranice
                n.smer = -1
            end

            -- Kolize hráč vs. nepřítel
            if kolize(hrac, n) then
                -- Rozlišíme, zda hráč udeřil nepřítele shora:
                -- - Podmínkou je, že hráč padá (rychlostY > 0)
                -- - Spodní hrana hráče je v oblasti horní hrany nepřítele (přidáme malou rezervu)
                if hrac.rychlostY > 0 and (hrac.y + hrac.h) <= (n.y + 10) then
                    -- Zničíme nepřítele
                    table.remove(nepratele, i)
                    -- Hráč se "odrazí" (bonus skok nahoru)
                    hrac.rychlostY = -200
                else
                    -- Pokud hráč narazil do nepřítele z boku nebo zespodu, reset pozice
                    hrac.x = 50
                    hrac.y = 0
                    hrac.rychlostY = 0
                    hrac.zbyvajiciSkoky = hrac.maxSkoku
                end
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
