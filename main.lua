function love.load()
    love.window.setMode(800, 600)
    love.window.setTitle("Mega Boss, kostky nahoře, smoking power-up, více nepřátelských kostek")

    -- Rozměry obrazovky a herního světa
    screenWidth = 800
    screenHeight = 600
    worldWidth = 10000
    worldHeight = 600

    -- Kamera
    camera = { x = 0, y = 0 }

    -- Různé stavy hry
    gravitace = 800
    hraVyhrana = false
    gameOver = false
    godMode = false        -- cheat "iddqd"
    cheatFlyMode = false   -- cheat "prettyfly"
    typedSequence = ""     -- buffer pro klávesy

    -----------------------------------------------------------------
    -- Hrdina
    -----------------------------------------------------------------
    hrac = {
        x = 50,
        y = 560,   -- Dole na hlavní platformě
        w = 20,
        h = 20,

        baseSpeed = 200,
        rychlost = 200,      -- aktuální rychlost (vodorovná)
        rychlostY = 0,       -- svislá rychlost
        naZemi = false,
        maxSkoku = 2,
        zbyvajiciSkoky = 2,

        -- Dvě barvy + životy
        health = {
            red  = 3,
            pink = 3,
        },
        activeColor = "red",
        colors = {
            red  = {1, 0, 0},
            pink = {1, 0.7, 0.8},
        },

        spaceDrzeno = false,
        switchCooldown = 0,

        -- Speciální stavy
        hasCilindr = false,   -- doplněk z předchozích power-upů
        hasSmoking = false,   -- nový doplněk
        isBig = false,        -- velký hrdina power-up
        canFly = false,       -- dočasné létání
        flyTimer = 0,

        -- Funkce pro získání aktuální barvy (RGB)
        getColor = function(self)
            return self.colors[self.activeColor]
        end
    }

    -- Metoda: Hrdina dostane zásah (ztrácí život nebo se zmenší)
    function hrac:takeDamage()
        if godMode then return end  -- v god módu nedostává dmg

        -- Pokud je hrdina velký, jen se zmenší a neztrácí život
        if self.isBig then
            self.isBig = false
            self.rychlost = self.baseSpeed
            return
        end

        -- Jinak ztrácí život v rámci aktivní barvy
        self.health[self.activeColor] = self.health[self.activeColor] - 1
        if self.health[self.activeColor] <= 0 then
            -- Přepnout na druhou barvu, pokud má životy
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

    -- Metoda: přepnout barvu (klávesa P)
    function hrac:switchColor()
        if self.activeColor == "red" and self.health["pink"] > 0 then
            self.activeColor = "pink"
        elseif self.activeColor == "pink" and self.health["red"] > 0 then
            self.activeColor = "red"
        end
    end

    -- Střely (mráčky), pokud je hrdina velký
    mracky = {}

    -----------------------------------------------------------------
    -- Platformy
    -----------------------------------------------------------------
    -- Velká hlavní platforma dole (na y=580)
    -- + pár vygenerovaných nahoře (pokud chcete)
    platformy = {
        { x=0,    y=580, w=10000, h=20, bounce=false, falling=false, color={0.7,0.3,0.3} }, -- hlavní

        -- Můžeme vygenerovat nějaké menší platformy nahoře. Místo generátoru
        -- je tu pro ukázku pár ručních. Třeba v rozmezí y=70..120
        { x=600,  y=120, w=150,   h=20, bounce=false, falling=false, color={0.7,0.3,0.3} },
        { x=1200, y=100, w=200,   h=20, bounce=false, falling=false, color={0.7,0.3,0.3} },
        { x=2000, y=80,  w=150,   h=20, bounce=true,  falling=false, color={0,0,0} },      -- trampolína
        { x=2500, y=90,  w=200,   h=20, bounce=false, falling=true,  color={1,0.8,0.5} },  -- padající
        { x=3500, y=120, w=200,   h=20, bounce=false, falling=false, color={0.7,0.3,0.3} },
        { x=9000, y=110, w=400,   h=20, bounce=false, falling=false, color={0.7,0.3,0.3} }, -- u bosse
    }

    -- Můžeme si pamatovat "poslední bezpečnou" platformu – pro pád
    lastSafePlatform = platformy[1]  -- start: velká dole

    -----------------------------------------------------------------
    -- Mystery Bloky nahoře (5 ks)
    -----------------------------------------------------------------
    -- Dáme je kolem y=50
    mysteryBlocks = {
        { x=1000, y=50, w=20, h=20, opened=false, color={1,1,0} },
        { x=2000, y=50, w=20, h=20, opened=false, color={1,1,0} },
        { x=3000, y=50, w=20, h=20, opened=false, color={1,1,0} },
        { x=6000, y=50, w=20, h=20, opened=false, color={1,1,0} },
        { x=8000, y=50, w=20, h=20, opened=false, color={1,1,0} },
    }

    -----------------------------------------------------------------
    -- Nepřátelé (včetně "kostek" a "mega boss")
    -----------------------------------------------------------------

    -- 1) Běžní malí nepřátelé dole
    --    (pohyb tam a zpět na hlavní platformě)
    nepratele = {
        {
            x=300, y=560, w=20, h=20,
            rychlost=100, smer=1,
            levaHranice=250, pravaHranice=600,
        },
        {
            x=700, y=560, w=20, h=20,
            rychlost=150, smer=-1,
            levaHranice=600, pravaHranice=800,
        },
    }

    -- 2) "Nepřátelské kostky" nahoře (větší, fialové, pohyblivé)
    --    Třeba 3 kusy
    table.insert(nepratele, {
        enemyBlock=true,
        x=1500, y=70, w=30, h=30,
        rychlost=80, smer=1,
        levaHranice=1400, pravaHranice=1600
    })
    table.insert(nepratele, {
        enemyBlock=true,
        x=2500, y=60, w=30, h=30,
        rychlost=70, smer=-1,
        levaHranice=2400, pravaHranice=2800
    })
    table.insert(nepratele, {
        enemyBlock=true,
        x=4200, y=100, w=30, h=30,
        rychlost=90, smer=1,
        levaHranice=4000, pravaHranice=4500
    })

    -- 3) Mega Boss (hnědý), velký 150x150, střílí žluté banány
    table.insert(nepratele, {
        bossMega=true,   -- příznak pro vykreslování i logiku
        hp=3,
        x=9500, y=430,   -- dole, ale o kousek výš, aby byl vidět
        w=150,  h=150,
        vy=0, naZemi=false,
        jumpTimer=2, shootTimer=1,
    })

    -- Banány (bossovy střely) - žluté
    banany = {}

end

---------------------------------------------------------------------
-- Kolize obdélníků
---------------------------------------------------------------------
local function kolize(a, b)
    return  a.x < b.x + b.w and
            a.x + a.w > b.x and
            a.y < b.y + b.h and
            a.y + a.h > b.y
end

---------------------------------------------------------------------
-- Boss střílí banán (žlutý)
---------------------------------------------------------------------
local function bossShootBanana(boss)
    -- Rychlost + směr k hráči
    local speed = 250
    local dx = (hrac.x + hrac.w/2) - (boss.x + boss.w/2)
    local dy = (hrac.y + hrac.h/2) - (boss.y + boss.h/2)
    local length = math.sqrt(dx*dx + dy*dy)
    if length == 0 then
        dx, dy = 1,0
    else
        dx = dx / length
        dy = dy / length
    end

    local banana = {
        x = boss.x + boss.w/2,
        y = boss.y + boss.h/2,
        w = 10, h = 10,
        vx = dx*speed,
        vy = dy*speed
    }
    table.insert(banany, banana)
end

---------------------------------------------------------------------
-- KeyPressed -> sledujeme cheaty
---------------------------------------------------------------------
function love.keypressed(key)
    typedSequence = typedSequence .. key
    if #typedSequence > 15 then
        typedSequence = string.sub(typedSequence, -15)
    end

    -- IDDQD => god mode
    if string.sub(typedSequence, -5) == "iddqd" then
        godMode = true
        print("God mode aktivován (iddqd).")
    end

    -- PRETTYFLY => fly mode
    if string.sub(typedSequence, -9) == "prettyfly" then
        cheatFlyMode = not cheatFlyMode
        print("Fly mode toggled:", cheatFlyMode)
    end
end

---------------------------------------------------------------------
-- LOVE.UPDATE
---------------------------------------------------------------------
function love.update(dt)
    if hraVyhrana or gameOver then
        if love.keyboard.isDown("r") then
            love.load()
        end
        return
    end

    -- Ovládání hrdiny (podle fly módu)
    if cheatFlyMode or hrac.canFly then
        -- Může létat nahoru/dolů
        if love.keyboard.isDown("up") then
            hrac.y = hrac.y - hrac.rychlost*dt
        end
        if love.keyboard.isDown("down") then
            hrac.y = hrac.y + hrac.rychlost*dt
        end
        if love.keyboard.isDown("left") then
            hrac.x = hrac.x - hrac.rychlost*dt
        end
        if love.keyboard.isDown("right") then
            hrac.x = hrac.x + hrac.rychlost*dt
        end

        -- Pokud je to dočasné létání z Mystery blocku
        if hrac.canFly then
            hrac.flyTimer = hrac.flyTimer - dt
            if hrac.flyTimer <= 0 then
                hrac.canFly = false
            end
        end
    else
        -- Normální pohyb
        if love.keyboard.isDown("left") then
            hrac.x = hrac.x - hrac.rychlost*dt
        elseif love.keyboard.isDown("right") then
            hrac.x = hrac.x + hrac.rychlost*dt
        end

        -- Gravitační pád
        hrac.rychlostY = hrac.rychlostY + gravitace*dt
        hrac.y = hrac.y + hrac.rychlostY*dt
    end

    -- Omezit pohyb hrdiny do hranic
    if hrac.x < 0 then hrac.x=0 end
    if hrac.x+hrac.w > worldWidth then
        hrac.x = worldWidth - hrac.w
    end

    -- Dvojitý skok (pokud nelétáme)
    if not cheatFlyMode and not hrac.canFly then
        if love.keyboard.isDown("space") then
            if not hrac.spaceDrzeno then
                hrac.spaceDrzeno = true
                if hrac.zbyvajiciSkoky>0 then
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
        if hrac.switchCooldown<=0 then
            hrac.switchCooldown=0.3
            hrac:switchColor()
        end
    end
    if hrac.switchCooldown>0 then
        hrac.switchCooldown = hrac.switchCooldown - dt
    end

    -- Střelba mráčků, pokud je hrdina velký
    if hrac.isBig and love.keyboard.isDown("m") then
        shootMracek()
    end
    updateMracky(dt)

    -- Kolize s platformami (pokud nepoužíváme létání)
    if not cheatFlyMode and not hrac.canFly then
        hrac.naZemi = false
        for i=#platformy,1,-1 do
            local p = platformy[i]
            if kolize(hrac,p) then
                if hrac.rychlostY>0 then
                    hrac.y = p.y - hrac.h
                    hrac.rychlostY=0
                    hrac.naZemi=true
                    hrac.zbyvajiciSkoky=hrac.maxSkoku
                    if p.bounce then
                        hrac.rychlostY=-500
                    end
                    if p.falling then
                        table.remove(platformy,i)
                    else
                        lastSafePlatform=p
                    end
                end
            end
        end
    end

    -- Mystery bloky: bouchnutí ze spodu?
    checkMysteryBlocks(dt)

    -- Pád pod úroveň poslední bezpečné platformy
    if lastSafePlatform then
        if (not cheatFlyMode and not hrac.canFly) then
            local padThreshold = lastSafePlatform.y + 200
            if hrac.y + hrac.h > padThreshold then
                hrac:takeDamage()
                if not gameOver then
                    hrac.x = lastSafePlatform.x+10
                    hrac.y = lastSafePlatform.y - hrac.h
                    hrac.rychlostY=0
                end
            end
        end
    end

    -- Nepřátelé
    for i=#nepratele,1,-1 do
        local n = nepratele[i]
        if not n.bossMega then
            -- Běžný nepřítel (včetně "enemyBlock")
            n.x = n.x + n.smer*n.rychlost*dt
            -- Restrikce pohybu
            if n.levaHranice and n.pravaHranice then
                if n.x < n.levaHranice then
                    n.x = n.levaHranice
                    n.smer=1
                elseif n.x + n.w>n.pravaHranice then
                    n.x = n.pravaHranice - n.w
                    n.smer=-1
                end
            end
        else
            -- Mega boss (hnědý)
            n.vy = n.vy + gravitace*dt
            n.y = n.y + n.vy*dt
            n.naZemi = false

            -- Dopad na platformu?
            for _,p in ipairs(platformy) do
                if (n.x+n.w>p.x) and (n.x<p.x+p.w)
                   and (n.y+n.h<=p.y+5)
                   and (n.vy>0) then
                    if n.y+n.h>p.y then
                        n.y = p.y - n.h
                        n.vy=0
                        n.naZemi=true
                        break
                    end
                end
            end

            -- Skákání
            n.jumpTimer = n.jumpTimer - dt
            if n.jumpTimer<=0 and n.naZemi then
                n.vy=-300
                n.jumpTimer=2 + love.math.random()*2
            end

            -- Střílení
            n.shootTimer = n.shootTimer - dt
            if n.shootTimer<=0 then
                bossShootBanana(n)
                n.shootTimer=1.5 + love.math.random()*2
            end
        end

        -- Kolize hrdiny s nepřítelem
        if kolize(hrac,n) then
            -- Shora?
            if (not cheatFlyMode and not hrac.canFly)
               and hrac.rychlostY>0
               and (hrac.y+hrac.h) <= (n.y + 10) then
                -- Boss?
                if n.bossMega then
                    n.hp=n.hp-1
                    if n.hp<=0 then
                        table.remove(nepratele,i)
                    end
                else
                    table.remove(nepratele,i)
                end
                hrac.rychlostY=-200
            else
                -- Z boku nebo zespodu => damage
                hrac:takeDamage()
                if not gameOver and lastSafePlatform then
                    hrac.x = lastSafePlatform.x+10
                    hrac.y = lastSafePlatform.y-hrac.h
                    hrac.rychlostY=0
                end
            end
        end
    end

    -- Banány (žluté)
    for i=#banany,1,-1 do
        local b = banany[i]
        b.x = b.x + b.vx*dt
        b.y = b.y + b.vy*dt

        -- Kolize s hrdinou
        if kolize(b, hrac) then
            hrac:takeDamage()
            if not gameOver and lastSafePlatform then
                hrac.x = lastSafePlatform.x+10
                hrac.y = lastSafePlatform.y-hrac.h
                hrac.rychlostY=0
            end
            table.remove(banany,i)
        elseif b.x<0 or b.x>worldWidth or b.y<0 or b.y>worldHeight then
            table.remove(banany,i)
        end
    end

    -- Vyhrál jsi, pokud není žádný nepřítel
    if #nepratele==0 then
        hraVyhrana=true
    end

    -- Kamera
    camera.x = hrac.x - screenWidth/2
    if camera.x<0 then camera.x=0 end
    if camera.x>worldWidth - screenWidth then
        camera.x=worldWidth - screenWidth
    end
end

---------------------------------------------------------------------
-- Střelba mráčků
---------------------------------------------------------------------
function shootMracek()
    local speed = 300
    local mrak = {
        x=hrac.x+hrac.w/2,
        y=hrac.y+hrac.h/2,
        w=10,h=10,
        vx=speed, vy=0
    }
    table.insert(mracky,mrak)
end

function updateMracky(dt)
    for i=#mracky,1,-1 do
        local m=mracky[i]
        m.x = m.x + m.vx*dt
        m.y = m.y + m.vy*dt

        -- Kolize s nepřáteli
        local removeIt=false
        for j=#nepratele,1,-1 do
            local n=nepratele[j]
            if kolize(m,n) then
                if n.bossMega then
                    n.hp=n.hp-1
                    if n.hp<=0 then
                        table.remove(nepratele,j)
                    end
                else
                    table.remove(nepratele,j)
                end
                removeIt=true
                break
            end
        end

        if removeIt or m.x<0 or m.x>worldWidth or m.y<0 or m.y>worldHeight then
            table.remove(mracky,i)
        end
    end
end

---------------------------------------------------------------------
-- Mystery bloky (bouchnutí zespodu => power-up)
---------------------------------------------------------------------
function checkMysteryBlocks(dt)
    for i=#mysteryBlocks,1,-1 do
        local mb = mysteryBlocks[i]
        if not mb.opened then
            if kolize(hrac, mb) then
                -- Úder zespodu => hrdina.rychlostY<0 a (hrac.y>mb.y)
                if hrac.rychlostY<0 and hrac.y>mb.y then
                    openMysteryBlock(mb)
                end
            end
        end
    end
end

function openMysteryBlock(block)
    block.opened=true
    -- Nyní máme 4 power-upy: (1) křídla, (2) big mode, (3) cylindr, (4) smoking
    local r = love.math.random(1,4)
    if r==1 then
        hrac.canFly=true
        hrac.flyTimer=10
        print("Power-up: Křídla na 10s!")
    elseif r==2 then
        hrac.isBig=true
        hrac.rychlost=hrac.baseSpeed*2
        print("Power-up: BIG mode (dvojnásobná rychlost + střelba mráčků)!")
    elseif r==3 then
        hrac.hasCilindr=true
        print("Power-up: Cilindr s červenou stužkou!")
    else
        hrac.hasSmoking=true
        print("Power-up: Smoking (frak)!")
    end
end

---------------------------------------------------------------------
-- LOVE.DRAW
---------------------------------------------------------------------
function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)

    -- Džunglově zelené pozadí
    love.graphics.clear(0.1,0.7,0.1)

    -- Platformy
    for _,p in ipairs(platformy) do
        love.graphics.setColor(p.color)
        love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
    end

    -- Mystery Bloky
    for _,mb in ipairs(mysteryBlocks) do
        if not mb.opened then
            love.graphics.setColor(mb.color)
            love.graphics.rectangle("fill", mb.x, mb.y, mb.w, mb.h)
        end
    end

    -- Banány (mega boss) - žluté
    love.graphics.setColor(1,1,0)
    for _,b in ipairs(banany) do
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    end

    -- Nepřátelé (fialoví) + Mega boss (hnědý)
    for _,n in ipairs(nepratele) do
        if n.bossMega then
            -- Hnědý mega boss
            love.graphics.setColor(0.6,0.3,0)
        else
            -- Fialoví
            love.graphics.setColor(0.7,0,0.7)
        end
        love.graphics.rectangle("fill", n.x, n.y, n.w, n.h)
    end

    -- Mráčky (střely hrdiny, světle šedé)
    love.graphics.setColor(0.9,0.9,0.9)
    for _,m in ipairs(mracky) do
        love.graphics.rectangle("fill", m.x, m.y, m.w, m.h)
    end

    -- Hrdina - barva podle activeColor
    local r,g,b = hrac:getColor()[1], hrac:getColor()[2], hrac:getColor()[3]
    love.graphics.setColor(r,g,b)
    love.graphics.rectangle("fill", hrac.x, hrac.y, hrac.w, hrac.h)

    -- Pokud má cylindr, nakreslíme klobouk
    if hrac.hasCilindr then
        love.graphics.setColor(0,0,0)
        local hatW = hrac.w
        local hatH = 10
        local hatX = hrac.x
        local hatY = hrac.y - hatH
        love.graphics.rectangle("fill", hatX, hatY, hatW, hatH)
        -- červená stužka
        love.graphics.setColor(1,0,0)
        love.graphics.rectangle("fill", hatX, hatY+hatH/2-1, hatW, 2)
    end

    -- Pokud má smoking, nakreslíme obdélník (frak) pod postavou
    if hrac.hasSmoking then
        love.graphics.setColor(0,0,0)
        local coatW = hrac.w
        local coatH = 10
        -- trošku přesahuje dole
        local coatX = hrac.x
        local coatY = hrac.y + hrac.h
        love.graphics.rectangle("fill", coatX, coatY, coatW, coatH)
    end

    love.graphics.pop()

    -- UI / texty
    love.graphics.setColor(1,1,1)
    local msg = string.format("RED HP: %d  |  PINK HP: %d",
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
            0, screenHeight/2, screenWidth, "center")
    elseif gameOver then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Prohrál jsi! (R pro restart)",
            0, screenHeight/2, screenWidth, "center")
    end
end
