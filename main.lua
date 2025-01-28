function love.load()
    love.window.setMode(800, 600)
    love.window.setTitle("Platformovka s dosažitelnými platformami, slizem na stropě a mizejícím mráčkem")

    -- Rozměry obrazovky a světa
    screenWidth = 800
    screenHeight = 600
    worldWidth = 10000
    worldHeight = 600

    -- Kamera
    camera = { x = 0, y = 0 }

    -- Stav hry
    gravitace = 800
    hraVyhrana = false
    gameOver = false
    godMode = false         -- cheat "iddqd"
    cheatFlyMode = false    -- cheat "prettyfly"
    typedSequence = ""      -- buffer pro klávesy

    ----------------------------------------------------------------
    -- Definice hrdiny
    ----------------------------------------------------------------
    hrac = {
        x = 50,
        y = 560,
        w = 20,
        h = 20,

        baseSpeed = 200,
        rychlost = 200,     -- aktuální rychlost (vodorovná)
        rychlostY = 0,      -- svislá rychlost
        naZemi = false,
        maxSkoku = 2,       -- dvojitý skok
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

        -- Speciální stavy
        hasCilindr = false,
        hasSmoking = false,
        isBig = false,
        -- Dříve "canFly", teď bude řešeno mráčkem:
        flyCloud = nil,      -- pokud existuje, hrdina létá
        spaceDrzeno = false,
        switchCooldown = 0,

        -- Pomocná pro sliz/šplhání
        isOnSlime = false,

        getColor = function(self)
            return self.colors[self.activeColor]
        end
    }

    -- Metoda: hrdina dostane zásah
    function hrac:takeDamage()
        if godMode then return end  -- v god módu žádné zranění

        -- Pokud je hrdina velký, jen se zmenší
        if self.isBig then
            self.isBig = false
            self.rychlost = self.baseSpeed
            return
        end

        -- Jinak ztratí 1 život aktuální barvy
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

    -- Metoda: přepnutí barvy (P)
    function hrac:switchColor()
        if self.activeColor == "red" and self.health["pink"] > 0 then
            self.activeColor = "pink"
        elseif self.activeColor == "pink" and self.health["red"] > 0 then
            self.activeColor = "red"
        end
    end

    -- Střely (mráčky), pokud je hrdina velký
    mracky = {}

    ----------------------------------------------------------------
    -- Generované platformy (vždy dosažitelné)
    ----------------------------------------------------------------
    platformy = generateReachablePlatforms(worldWidth)

    -- Velká spodní platforma (zajistí, že dole je vždy "zem")
    table.insert(platformy, {
        x = 0,
        y = 580,
        w = worldWidth,
        h = 20,
        bounce = false,
        falling = false,
        color = {0.7, 0.3, 0.3}
    })

    -- Poslední bezpečná platforma (start: dole)
    lastSafePlatform = platformy[#platformy]

    ----------------------------------------------------------------
    -- Mystery bloky (vždy nad platformou v doskočitelné vzdálenosti)
    ----------------------------------------------------------------
    mysteryBlocks = generateMysteryBoxes(5, platformy)

    ----------------------------------------------------------------
    -- Zelený sliz na stropě (náhodné "lišty"), po kterých se dá šplhat
    ----------------------------------------------------------------
    slizSegments = generateSlimeSegments(10)
    -- 10 segmentů, můžete měnit dle potřeby

    ----------------------------------------------------------------
    -- Nepřátelé (včetně Mega bosse)
    ----------------------------------------------------------------
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
        -- Pár "kostkových" nepřátel nahoře
        {
            enemyBlock=true,
            x=2000, y=300, w=30, h=30,
            rychlost=60, smer=1,
            levaHranice=1900, pravaHranice=2100
        },
        {
            enemyBlock=true,
            x=2500, y=250, w=30, h=30,
            rychlost=70, smer=-1,
            levaHranice=2400, pravaHranice=2700
        },
        -- Mega Boss (hnědý, střílí žluté banány)
        {
            bossMega=true,
            hp=3,
            x=9500, y=430,
            w=150, h=150,
            vy=0, naZemi=false,
            jumpTimer=2, shootTimer=1,
        }
    }

    banany = {} -- bossovy střely (žluté)

end

--------------------------------------------------------------------------------
-- FUNKCE: Generování dosažitelných platform
--------------------------------------------------------------------------------
function generateReachablePlatforms(maxWidth)
    -- Předpoklady:
    --  - hrdina skáče max. ~ (100 px) do výšky
    --  - horizontální "doskok" ~ 300 px (podle baseSpeed a skokové dráhy)
    -- Tady si definujeme menší "kroky".
    local plats = {}
    local x = 200   -- začneme kousek odkraje
    local y = 400   -- a někde v polovině
    local lastX, lastY = x, y

    local stepCount = 0
    while x < maxWidth - 500 do
        local p = {}
        p.x = x
        p.w = 150
        p.h = 20
        p.bounce = false
        p.falling = false
        p.color = {0.7, 0.3, 0.3}

        -- Náhodný posun, ale omezený tak, aby se dalo doskočit
        -- horizontálně do ~ 300 px, vertikálně do ~ 100 px
        local dx = love.math.random(100, 250)
        local dy = love.math.random(-80, 80)

        x = x + dx
        y = y + dy

        -- Omezit y tak, aby zůstalo v "rozumném" rozmezí
        -- (např. 100..500)
        if y < 100 then y = 100 end
        if y > 500 then y = 500 end

        p.y = y
        table.insert(plats, p)

        lastX, lastY = p.x, p.y
        stepCount = stepCount + 1
    end

    return plats
end

--------------------------------------------------------------------------------
-- FUNKCE: Generování Mystery boxů (počet, platformy)
-- Vždy umístíme box ~50..80 px nad vybranou platformu (aby šel bouchnout zespodu)
--------------------------------------------------------------------------------
function generateMysteryBoxes(count, plats)
    local boxes = {}
    for i=1,count do
        -- vybereme náhodnou platformu
        local p = plats[love.math.random(#plats)]
        -- box bude v horizontálním rozmezí platformy
        local boxX = love.math.random(p.x, p.x + p.w - 20)
        -- boxY ~ kousek nad platformou (max doskok ~ 80 px)
        local boxY = p.y - love.math.random(50,80)
        if boxY < 0 then boxY=0 end

        table.insert(boxes, {
            x=boxX, y=boxY,
            w=20, h=20,
            opened=false,
            color={1,1,0}
        })
    end
    return boxes
end

--------------------------------------------------------------------------------
-- FUNKCE: Generování zeleného slizu na stropě
-- Uděláme N segmentů, každý bude svislý "pruh" slizu, který sahá
-- od stropu (y=0) dolů k určitému y. Hrdina po něm může lézt nahoru/dolů.
--------------------------------------------------------------------------------
function generateSlimeSegments(count)
    local slimes = {}
    for i=1,count do
        local x = love.math.random(100, worldWidth-200)
        local length = love.math.random(50, 200)  -- jak "hluboko" sliz sahá
        local topY = 0
        local bottomY = length

        table.insert(slimes, {
            x = x,
            topY = topY,
            bottomY = bottomY,
            w = 20,     -- šířka pruhu
            color = {0, 1, 0}, -- zelená
        })
    end
    return slimes
end

--------------------------------------------------------------------------------
-- Kolize obdélníků
--------------------------------------------------------------------------------
local function kolize(a, b)
    return  a.x < b.x + b.w and
            a.x + a.w > b.x and
            a.y < b.y + (b.h or 0) and
            a.y + a.h > b.y
end

--------------------------------------------------------------------------------
-- Boss střílí žlutý banán
--------------------------------------------------------------------------------
local function bossShootBanana(boss)
    local speed=250
    local dx = (hrac.x + hrac.w/2) - (boss.x + boss.w/2)
    local dy = (hrac.y + hrac.h/2) - (boss.y + boss.h/2)
    local length = math.sqrt(dx*dx + dy*dy)
    if length==0 then
        dx,dy=1,0
    else
        dx=dx/length
        dy=dy/length
    end
    local banana={
        x = boss.x+boss.w/2,
        y = boss.y+boss.h/2,
        w = 10, h = 10,
        vx=dx*speed,
        vy=dy*speed
    }
    table.insert(banany, banana)
end

--------------------------------------------------------------------------------
-- KeyPressed => sledujeme cheaty
--------------------------------------------------------------------------------
function love.keypressed(key)
    typedSequence = typedSequence .. key
    if #typedSequence>15 then
        typedSequence=string.sub(typedSequence,-15)
    end

    -- iddqd => god mode
    if string.sub(typedSequence, -5)=="iddqd" then
        godMode=true
        print("God mode ON (iddqd)")
    end

    -- prettyfly => toggle cheat fly mode
    if string.sub(typedSequence, -9)=="prettyfly" then
        cheatFlyMode = not cheatFlyMode
        print("Fly mode toggled =>", cheatFlyMode)
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

    -- 1) Pohyb hrdiny
    local isFlying = false
    -- a) Cheat fly mode
    if cheatFlyMode then
        isFlying=true
    end
    -- b) Mráček (letací power-up)
    if hrac.flyCloud then
        isFlying=true
        -- Odpočet života mráčku
        hrac.flyCloud.timeLeft = hrac.flyCloud.timeLeft - dt
        if hrac.flyCloud.timeLeft <= 0 then
            hrac.flyCloud = nil
        end
    end

    if isFlying then
        -- Let = pohyb up/down/left/right
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
    else
        -- Normální pohyb (vlevo/vpravo + gravitace)
        if love.keyboard.isDown("left") then
            hrac.x = hrac.x - hrac.rychlost*dt
        elseif love.keyboard.isDown("right") then
            hrac.x = hrac.x + hrac.rychlost*dt
        end
        hrac.rychlostY = hrac.rychlostY + gravitace*dt
        hrac.y = hrac.y + hrac.rychlostY*dt
    end

    -- Omezit do hranic světa
    if hrac.x<0 then hrac.x=0 end
    if hrac.x+hrac.w>worldWidth then
        hrac.x=worldWidth-hrac.w
    end

    -- 2) Dvojitý skok (pokud zrovna nepoužíváme let)
    if not isFlying then
        if love.keyboard.isDown("space") then
            if not hrac.spaceDrzeno then
                hrac.spaceDrzeno=true
                if hrac.zbyvajiciSkoky>0 then
                    hrac.rychlostY=-300
                    hrac.zbyvajiciSkoky=hrac.zbyvajiciSkoky-1
                end
            end
        else
            hrac.spaceDrzeno=false
        end
    end

    -- 3) Přepnutí barvy (P)
    if love.keyboard.isDown("p") then
        if hrac.switchCooldown<=0 then
            hrac.switchCooldown=0.3
            hrac:switchColor()
        end
    end
    if hrac.switchCooldown>0 then
        hrac.switchCooldown = hrac.switchCooldown - dt
    end

    -- 4) Střelba mráčků, pokud je hrdina velký
    if hrac.isBig and love.keyboard.isDown("m") then
        shootMracek()
    end
    updateMracky(dt)

    -- 5) Šplhání po slizu (pokud hrdina koliduje s jedním ze slizSegmentů)
    hrac.isOnSlime = false
    for _,sl in ipairs(slizSegments) do
        local slimeRect = {
            x = sl.x,
            y = sl.topY,
            w = sl.w,
            h = sl.bottomY - sl.topY
        }
        if kolize(hrac, slimeRect) then
            hrac.isOnSlime = true
            break
        end
    end

    if hrac.isOnSlime and not isFlying then
        -- Můžeme lézt nahoru/dolů
        -- Zastavíme gravitaci
        hrac.rychlostY = 0
        if love.keyboard.isDown("up") then
            hrac.y = hrac.y - 100*dt
        elseif love.keyboard.isDown("down") then
            hrac.y = hrac.y + 100*dt
        end
    end

    -- 6) Kolize s platformami (pokud se neletí a není na slizu)
    if not isFlying and not hrac.isOnSlime then
        hrac.naZemi=false
        for i=#platformy,1,-1 do
            local p=platformy[i]
            if kolize(hrac,p) then
                if hrac.rychlostY>0 then
                    hrac.y=p.y-hrac.h
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

    -- 7) Mystery boxy - bouchnutí zespodu
    checkMysteryBlocks(dt)

    -- 8) Pád pod úroveň "lastSafePlatform"
    if lastSafePlatform then
        if not isFlying and not hrac.isOnSlime then
            local padThreshold = lastSafePlatform.y + 200
            if hrac.y+hrac.h>padThreshold then
                hrac:takeDamage()
                if not gameOver then
                    hrac.x=lastSafePlatform.x+10
                    hrac.y=lastSafePlatform.y-hrac.h
                    hrac.rychlostY=0
                end
            end
        end
    end

    -- 9) Pohyb nepřátel (včetně mega bosse)
    for i=#nepratele,1,-1 do
        local n=nepratele[i]
        if not n.bossMega then
            -- obyčejní nepřátelé
            n.x=n.x+n.smer*n.rychlost*dt
            if n.levaHranice and n.pravaHranice then
                if n.x<n.levaHranice then
                    n.x=n.levaHranice
                    n.smer=1
                elseif n.x+n.w>n.pravaHranice then
                    n.x=n.pravaHranice-n.w
                    n.smer=-1
                end
            end
        else
            -- mega boss
            n.vy=n.vy+gravitace*dt
            n.y=n.y+n.vy*dt
            n.naZemi=false
            for _,p in ipairs(platformy) do
                if (n.x+n.w>p.x) and (n.x<p.x+p.w)
                   and (n.y+n.h<=p.y+5)
                   and (n.vy>0) then
                    if n.y+n.h>p.y then
                        n.y=p.y-n.h
                        n.vy=0
                        n.naZemi=true
                        break
                    end
                end
            end
            -- boss skok
            n.jumpTimer=n.jumpTimer-dt
            if n.jumpTimer<=0 and n.naZemi then
                n.vy=-300
                n.jumpTimer=2+love.math.random()*2
            end
            -- boss střelba
            n.shootTimer=n.shootTimer-dt
            if n.shootTimer<=0 then
                bossShootBanana(n)
                n.shootTimer=1.5+love.math.random()*2
            end
        end

        -- Kolize hrdiny vs nepřítel
        if kolize(hrac,n) then
            if not isFlying and not hrac.isOnSlime
               and hrac.rychlostY>0
               and (hrac.y+hrac.h)<=(n.y+10) then
                -- skok na hlavu
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
                -- hrdina z boku/spodu => dmg
                hrac:takeDamage()
                if not gameOver and lastSafePlatform then
                    hrac.x=lastSafePlatform.x+10
                    hrac.y=lastSafePlatform.y-hrac.h
                    hrac.rychlostY=0
                end
            end
        end
    end

    -- 10) Banány (bossovy střely)
    for i=#banany,1,-1 do
        local b=banany[i]
        b.x=b.x+b.vx*dt
        b.y=b.y+b.vy*dt
        if kolize(b,hrac) then
            hrac:takeDamage()
            if not gameOver and lastSafePlatform then
                hrac.x=lastSafePlatform.x+10
                hrac.y=lastSafePlatform.y-hrac.h
                hrac.rychlostY=0
            end
            table.remove(banany,i)
        elseif b.x<0 or b.x>worldWidth or b.y<0 or b.y>worldHeight then
            table.remove(banany,i)
        end
    end

    -- Konec hry (výhra) - všichni nepřátelé pryč
    if #nepratele==0 then
        hraVyhrana=true
    end

    -- Kamera
    camera.x=hrac.x-screenWidth/2
    if camera.x<0 then camera.x=0 end
    if camera.x>worldWidth-screenWidth then
        camera.x=worldWidth-screenWidth
    end
end

--------------------------------------------------------------------------------
-- FUNKCE: Střelba mráčků (hrac.isBig)
--------------------------------------------------------------------------------
function shootMracek()
    local speed=300
    local m={
        x=hrac.x+hrac.w/2,
        y=hrac.y+hrac.h/2,
        w=10, h=10,
        vx=speed,
        vy=0
    }
    table.insert(mracky,m)
end

function updateMracky(dt)
    for i=#mracky,1,-1 do
        local m=mracky[i]
        m.x=m.x+m.vx*dt
        m.y=m.y+m.vy*dt
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

--------------------------------------------------------------------------------
-- Mystery boxy -> bouchnutí zespodu => power-up
-- (včetně nového "letacího" mráčku s mizícím časem)
--------------------------------------------------------------------------------
function checkMysteryBlocks(dt)
    for i=#mysteryBlocks,1,-1 do
        local mb=mysteryBlocks[i]
        if not mb.opened then
            if kolize(hrac,mb) then
                -- úder zespodu => hrdina.rychlostY<0 a hrac.y>mb.y
                if hrac.rychlostY<0 and hrac.y>mb.y then
                    openMysteryBlock(mb)
                end
            end
        end
    end
end

function openMysteryBlock(block)
    block.opened=true
    local r = love.math.random(1,5)
    -- Teď budeme mít 5 variant (1..5):
    -- 1) křídla => dříve canFly, nyní "modrý mráček" 10s
    -- 2) big mode => dvojnásobná rychlost + střelba
    -- 3) cylindr
    -- 4) smoking
    -- 5) nic (nebo byste mohli přidat cokoliv jiného)
    if r==1 then
        -- Letací "mráček" = hrac.flyCloud
        hrac.flyCloud = {
            timeLeft = 10  -- 10 vteřin
        }
        print("Power-up: Modrý mráček (let na 10s)!")
    elseif r==2 then
        hrac.isBig=true
        hrac.rychlost=hrac.baseSpeed*2
        print("Power-up: BIG mode!")
    elseif r==3 then
        hrac.hasCilindr=true
        print("Power-up: Cilindr!")
    elseif r==4 then
        hrac.hasSmoking=true
        print("Power-up: Smoking!")
    else
        print("Power-up: Nic zajímavého. :-)")
    end
end

--------------------------------------------------------------------------------
-- LOVE.DRAW
--------------------------------------------------------------------------------
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

    -- Mystery boxy (žluté)
    for _,mb in ipairs(mysteryBlocks) do
        if not mb.opened then
            love.graphics.setColor(mb.color)
            love.graphics.rectangle("fill", mb.x, mb.y, mb.w, mb.h)
        end
    end

    -- Sliz na stropě
    for _,sl in ipairs(slizSegments) do
        love.graphics.setColor(sl.color)
        love.graphics.rectangle("fill", sl.x, sl.topY, sl.w, sl.bottomY - sl.topY)
    end

    -- Banány (žluté)
    love.graphics.setColor(1,1,0)
    for _,b in ipairs(banany) do
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    end

    -- Nepřátelé (fialoví), Mega boss (hnědý)
    for _,n in ipairs(nepratele) do
        if n.bossMega then
            love.graphics.setColor(0.6,0.3,0)   -- hnědý
        else
            love.graphics.setColor(0.7,0,0.7)  -- fialový
        end
        love.graphics.rectangle("fill", n.x, n.y, n.w, n.h)
    end

    -- Mráčky hráče (světle šedé)
    love.graphics.setColor(0.9,0.9,0.9)
    for _,m in ipairs(mracky) do
        love.graphics.rectangle("fill", m.x, m.y, m.w, m.h)
    end

    -- Hrdina
    local r,g,b = hrac:getColor()[1], hrac:getColor()[2], hrac:getColor()[3]
    love.graphics.setColor(r,g,b)
    love.graphics.rectangle("fill", hrac.x, hrac.y, hrac.w, hrac.h)

    -- Doplňky: cylindr, smoking
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
    if hrac.hasSmoking then
        love.graphics.setColor(0,0,0)
        local coatW=hrac.w
        local coatH=10
        local coatX=hrac.x
        local coatY=hrac.y+hrac.h
        love.graphics.rectangle("fill", coatX, coatY, coatW, coatH)
    end

    -- Pokud je aktivní letací mráček, vykreslíme jej pod hrdinou modře
    if hrac.flyCloud then
        local alpha = hrac.flyCloud.timeLeft / 10  -- z 10s zbývá
        love.graphics.setColor(0,0.6,1, alpha)     -- poloprůhledně
        local cloudW = hrac.w + 10
        local cloudH = 8
        local cloudX = hrac.x - 5
        local cloudY = hrac.y + hrac.h
        love.graphics.rectangle("fill", cloudX, cloudY, cloudW, cloudH)
    end

    love.graphics.pop()

    -- UI texty
    love.graphics.setColor(1,1,1)
    local msg = string.format("RED HP: %d | PINK HP: %d",
        hrac.health.red, hrac.health.pink)
    love.graphics.print(msg,10,10)

    if godMode then
        love.graphics.setColor(1,1,0)
        love.graphics.print("God mode (iddqd)",10,30)
    end
    if cheatFlyMode then
        love.graphics.setColor(1,1,0)
        love.graphics.print("Fly mode (prettyfly)",10,50)
    end

    if hraVyhrana then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Vyhrál jsi! [R] pro restart",
            0, screenHeight/2, screenWidth, "center")
    elseif gameOver then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Prohrál jsi! [R] pro restart",
            0, screenHeight/2, screenWidth, "center")
    end
end
