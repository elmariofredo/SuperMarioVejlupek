function love.load()
    love.window.setMode(800, 600)
    love.window.setTitle("Platformovka: PF cheat, dynamický sliz, bambitka a super mystery box")

    -- Zvětšíme svět i do negativních souřadnic nahoře,
    -- abychom mohli mít "slizové království" v y < 0.
    worldWidth = 10000
    worldHeight = 1200   -- vyšší kvůli slizovému království nahoře

    screenWidth = 800
    screenHeight = 600

    camera = {x=0, y=0}

    -- Hra
    gravitace = 800
    hraVyhrana = false
    gameOver = false
    godMode = false       -- cheat "iddqd"
    cheatFlyMode = false  -- cheat "pf"
    typedSequence = ""    -- buffer pro klávesy

    -- Speciální efekt: obří hovínko na 3s
    giantPoop = nil  -- {timeLeft=3} pokud je aktivní

    ----------------------------------------------------------------------------
    -- Definice hrdiny
    ----------------------------------------------------------------------------
    hrac = {
        x = 50,
        y = 580,  -- dole
        w = 20,
        h = 20,

        baseSpeed = 200,
        rychlost = 200,   -- aktuální vodorovná rychlost
        rychlostY = 0,    -- pád/skok
        naZemi = false,
        maxSkoku = 2,
        zbyvajiciSkoky = 2,

        -- Dvě barvy / životy
        health = {
            red  = 3,
            pink = 3,
        },
        activeColor = "red",
        colors = {
            red  = {1,0,0},
            pink = {1,0.7,0.8},
        },

        -- Různé stavy
        isBig = false,        -- velký hrdina, může střílet (bambitka)
        hasCilindr = false,
        hasSmoking = false,
        spaceDrzeno = false,
        switchCooldown = 0,

        -- Letací mráček
        flyCloud = nil,       -- {timeLeft=10} => dočasné létání

        -- Sliz
        isOnSlime = false,    -- zda právě leze po slizu

        -- Získání barvy dle activeColor
        getColor = function(self)
            return self.colors[self.activeColor]
        end
    }

    -- Funkce: hrdina dostane zásah
    function hrac:takeDamage()
        if godMode then return end

        if self.isBig then
            -- Pokud je velký, jen se zmenší (neztratí život)
            self.isBig = false
            self.rychlost = self.baseSpeed
            return
        end

        -- Normální ztráta života
        self.health[self.activeColor] = self.health[self.activeColor] - 1
        if self.health[self.activeColor] <= 0 then
            if self.activeColor == "red" then
                if self.health["pink"]>0 then
                    self.activeColor="pink"
                else
                    gameOver=true
                end
            else
                if self.health["red"]>0 then
                    self.activeColor="red"
                else
                    gameOver=true
                end
            end
        end
    end

    -- Funkce: přepnutí barvy
    function hrac:switchColor()
        if self.activeColor=="red" and self.health["pink"]>0 then
            self.activeColor="pink"
        elseif self.activeColor=="pink" and self.health["red"]>0 then
            self.activeColor="red"
        end
    end

    -- Střely hrdiny (mráčky z bambitky)
    mracky = {}

    ----------------------------------------------------------------------------
    -- Platformy
    ----------------------------------------------------------------------------
    platformy = {}

    -- Dolní podlaha (celý svět)
    table.insert(platformy, {
        x=0,
        y=580,
        w=worldWidth,
        h=20,
        bounce=false,
        falling=false,
        color={0.7,0.3,0.3}
    })

    -- Několik "středních" a "horních" platforem (ruční definice)
    table.insert(platformy, {
        x=400, y=450, w=200, h=20,
        bounce=false, falling=false,
        color={0.7,0.3,0.3}
    })
    table.insert(platformy, {
        x=900, y=350, w=150, h=20,
        bounce=true, falling=false,
        color={0,0,0}
    })
    table.insert(platformy, {
        x=1400, y=300, w=200, h=20,
        bounce=false, falling=true,
        color={1,0.8,0.5}
    })
    -- Můžete přidat libovolně dalších.

    -- Nakonec "velmi horní" platforma (např. y=0) – přechod do sliz království
    -- i nad 0 budeme mít ještě sliz, ale tahle platforma je "vstup do sliz království".
    table.insert(platformy, {
        x=3000, y=50, w=200, h=20,
        bounce=false, falling=false,
        color={0.7,0.3,0.3}
    })

    -- Pro "slizové království" můžeme definovat platformy s y < 0
    table.insert(platformy, {
        x=2800, y=-100, w=300, h=20,
        bounce=false, falling=false,
        color={0.2,0.6,0.2} -- nazelenalá
    })
    -- atd., pokud chcete víc "nad strechou".

    -- Poslední bezpečná platforma (pro pád) = podlaha
    lastSafePlatform = platformy[1]

    ----------------------------------------------------------------------------
    -- Mystery boxy
    ----------------------------------------------------------------------------
    mysteryBlocks = {
        -- Několik normálních
        { x=420, y=400, w=20, h=20, opened=false, color={1,1,0} },
        { x=920, y=300, w=20, h=20, opened=false, color={1,1,0} },
        -- "Super Mystery box" = prázdný, ale pak obří hovínko
        { x=1450, y=250, w=20, h=20, opened=false, color={1,1,0}, superBox=true }
    }

    -- Další boxy pro "slizové království" (nad 0)
    table.insert(mysteryBlocks, {
        x=2850, y=-150, w=20, h=20, opened=false,
        color={1,1,0}, superBox=false
    })

    ----------------------------------------------------------------------------
    -- Slizy (dynamické, natahují se)
    ----------------------------------------------------------------------------
    -- Budeme mít segmenty, každý bude měnit svoji "bottomY" sinusově nebo lineárně.
    slizSegments = {}
    for i=1,5 do
        local segX = 600*i
        -- Strop definujeme y = -200 (vysoko) a budeme jej rozšiřovat?
        local seg = {
            x = segX,
            topY = -200,     -- hodně nahoře
            bottomBase = love.math.random(80,300), -- kam defaultně sahá
            w = 20,          -- šířka slizu
            color={0,1,0},
            phase=0
        }
        table.insert(slizSegments, seg)
    end

    ----------------------------------------------------------------------------
    -- Nepřátelé (včetně Mega bosse)
    ----------------------------------------------------------------------------
    nepratele = {
        {
            x=300,y=560, w=20,h=20,
            rychlost=100, smer=1,
            levaHranice=250, pravaHranice=600
        },
        {
            x=700,y=560, w=20,h=20,
            rychlost=120, smer=-1,
            levaHranice=600, pravaHranice=800
        },
        {
            x=1400,y=560, w=20,h=20,
            rychlost=80, smer=1,
            levaHranice=1300, pravaHranice=1500
        },
        -- Mega boss (hnědý)
        {
            bossMega=true, hp=3,
            x=9500, y=430, w=150, h=150,
            vy=0, naZemi=false,
            jumpTimer=2, shootTimer=1
        }
    }

    banany = {}  -- bossovy střely

end

--------------------------------------------------------------------------------
-- Kolize
--------------------------------------------------------------------------------
local function kolize(a,b)
    local ah = b.h or 0
    return a.x < b.x + b.w and
           a.x + a.w > b.x and
           a.y < b.y + (b.h or 0) and
           a.y + a.h > b.y
end

--------------------------------------------------------------------------------
-- Boss střílí banány (žluté)
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
        x=boss.x+boss.w/2,
        y=boss.y+boss.h/2,
        w=10,h=10,
        vx=dx*speed, vy=dy*speed
    }
    table.insert(banany,banana)
end

--------------------------------------------------------------------------------
-- KeyPressed => cheat
--------------------------------------------------------------------------------
function love.keypressed(key)
    typedSequence = typedSequence .. key
    if #typedSequence>15 then
        typedSequence=string.sub(typedSequence,-15)
    end

    -- iddqd => god mode
    if string.sub(typedSequence,-5)=="iddqd" then
        godMode=true
        print("God mode ON (iddqd)")
    end

    -- pf => cheatFlyMode
    if string.sub(typedSequence,-2)=="pf" then
        cheatFlyMode=not cheatFlyMode
        print("Fly mode toggled =>",cheatFlyMode)
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

    -- 1) Obří hovínko efekt (pokud existuje, odpočítat)
    if giantPoop then
        giantPoop.timeLeft = giantPoop.timeLeft - dt
        if giantPoop.timeLeft<=0 then
            giantPoop=nil
        end
    end

    -- 2) Dynamický sliz (natahování + kapání)
    --   Zkusíme sinusový posun bottomY kolem "bottomBase".
    --   A "fáze" se bude incrementovat.
    for _,sl in ipairs(slizSegments) do
        sl.phase = sl.phase + dt
        sl.dynamicBottom = sl.bottomBase + math.sin(sl.phase)*50
        -- kapání => můžeme si představit, že dole spadne kapka, ale to jen "efekt"
        -- Pro hru klíčové je, kam sliz sahá (sl.dynamicBottom).
    end

    -- 3) Rozhodnutí, zda hrdina létá
    local isFlying = false
    if cheatFlyMode then
        isFlying=true
    end
    if hrac.flyCloud then
        isFlying=true
        hrac.flyCloud.timeLeft=hrac.flyCloud.timeLeft - dt
        if hrac.flyCloud.timeLeft<=0 then
            hrac.flyCloud=nil
        end
    end

    -- 4) Pohyb hrdiny
    if isFlying then
        if love.keyboard.isDown("up") then
            hrac.y=hrac.y-hrac.rychlost*dt
        end
        if love.keyboard.isDown("down") then
            hrac.y=hrac.y+hrac.rychlost*dt
        end
        if love.keyboard.isDown("left") then
            hrac.x=hrac.x-hrac.rychlost*dt
        end
        if love.keyboard.isDown("right") then
            hrac.x=hrac.x+hrac.rychlost*dt
        end
    else
        -- Normální pohyb
        if love.keyboard.isDown("left") then
            hrac.x=hrac.x-hrac.rychlost*dt
        elseif love.keyboard.isDown("right") then
            hrac.x=hrac.x+hrac.rychlost*dt
        end
        -- gravitace
        hrac.rychlostY=hrac.rychlostY+gravitace*dt
        hrac.y=hrac.y+hrac.rychlostY*dt
    end

    -- Omezení do hranic
    if hrac.x<0 then hrac.x=0 end
    if hrac.x+hrac.w>worldWidth then
        hrac.x=worldWidth-hrac.w
    end
    -- Pokud byste chtěli omezit i do horní/záporné zóny, musíte to upravit.

    -- 5) Dvojitý skok, pokud se nelétá
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

    -- 6) Přepínání barvy
    if love.keyboard.isDown("p") then
        if hrac.switchCooldown<=0 then
            hrac.switchCooldown=0.3
            hrac:switchColor()
        end
    end
    if hrac.switchCooldown>0 then
        hrac.switchCooldown=hrac.switchCooldown-dt
    end

    -- 7) Střelba (pokud je hrdina big => bambitka)
    if hrac.isBig and love.keyboard.isDown("m") then
        shootMracek()
    end
    updateMracky(dt)

    -- 8) Kolize se slizem => hrac.isOnSlime?
    --   Nyní sliz sahá od sl.topY do sl.dynamicBottom
    hrac.isOnSlime=false
    if not isFlying then
        for _,sl in ipairs(slizSegments) do
            local slimeRect = {
                x=sl.x,
                y=sl.topY,
                w=sl.w,
                h=(sl.dynamicBottom - sl.topY)
            }
            -- korekce, aby h>0 i když dynamicBottom < topY
            if slimeRect.h<0 then
                slimeRect.y = slimeRect.y + slimeRect.h
                slimeRect.h = -slimeRect.h
            end
            if kolize(hrac,slimeRect) then
                hrac.isOnSlime=true
                break
            end
        end
    end

    if hrac.isOnSlime and not isFlying then
        -- Vypneme gravitaci
        hrac.rychlostY=0
        -- Šplh nahoru?
        if love.keyboard.isDown("up") then
            hrac.y=hrac.y-100*dt
        end
        -- Tímto se hrdina může dostat do y<0 => slizové království
        -- (kde už jsou další platformy a mystery boxy).
    end

    -- 9) Kolize s platformami, pokud se nelétá a není na slizu
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

    -- 10) Mystery boxy - bouchnutí zespodu
    checkMysteryBlocks(dt)

    -- 11) Pád pod lastSafePlatform
    if not isFlying and not hrac.isOnSlime and lastSafePlatform then
        local padThreshold = lastSafePlatform.y+200
        if hrac.y+hrac.h>padThreshold then
            hrac:takeDamage()
            if not gameOver then
                hrac.x=lastSafePlatform.x+10
                hrac.y=lastSafePlatform.y-hrac.h
                hrac.rychlostY=0
            end
        end
    end

    -- 12) Pohyb nepřátel
    for i=#nepratele,1,-1 do
        local n=nepratele[i]
        if not n.bossMega then
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
            -- Mega boss
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
            -- Skok bosse
            n.jumpTimer=n.jumpTimer-dt
            if n.jumpTimer<=0 and n.naZemi then
                n.vy=-300
                n.jumpTimer=2+love.math.random()*2
            end
            -- Střelba bosse
            n.shootTimer=n.shootTimer-dt
            if n.shootTimer<=0 then
                bossShootBanana(n)
                n.shootTimer=1.5+love.math.random()*2
            end
        end

        -- Kolize hrdina vs nepřítel
        if kolize(hrac,n) then
            -- shora?
            if not isFlying and not hrac.isOnSlime
               and hrac.rychlostY>0
               and (hrac.y+hrac.h)<= (n.y+10) then
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
                -- z boku => dmg
                hrac:takeDamage()
                if not gameOver and lastSafePlatform then
                    hrac.x=lastSafePlatform.x+10
                    hrac.y=lastSafePlatform.y-hrac.h
                    hrac.rychlostY=0
                end
            end
        end
    end

    -- 13) Banány
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
        elseif b.x<0 or b.x>worldWidth or b.y<-300 or b.y> (580+200) then
            -- Mírně nad horní hranici a dole 200px navíc
            table.remove(banany,i)
        end
    end

    -- 14) Konec hry => vyhrál jsi, pokud žádní nepřátelé
    if #nepratele==0 then
        hraVyhrana=true
    end

    -- Kamera
    camera.x=hrac.x - screenWidth/2
    if camera.x<0 then camera.x=0 end
    if camera.x>worldWidth-screenWidth then
        camera.x=worldWidth-screenWidth
    end
end

--------------------------------------------------------------------------------
-- STŘELBA MRAČKŮ
--------------------------------------------------------------------------------
function shootMracek()
    local speed=300
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
        m.x=m.x+m.vx*dt
        m.y=m.y+m.vy*dt

        local removeIt=false
        -- kolize s nepřáteli
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

        if removeIt or m.x<0 or m.x>worldWidth or m.y<-200 or m.y>800 then
            table.remove(mracky,i)
        end
    end
end

--------------------------------------------------------------------------------
-- MYSTERY BOXY - bouchnutí zespodu
--------------------------------------------------------------------------------
function checkMysteryBlocks(dt)
    for i=#mysteryBlocks,1,-1 do
        local mb=mysteryBlocks[i]
        if not mb.opened then
            if kolize(hrac, mb) then
                -- úder zespoda => hrdina.rychlostY<0 a hrac.y>mb.y
                if hrac.rychlostY<0 and hrac.y>mb.y then
                    openMysteryBlock(mb)
                end
            end
        end
    end
end

-- Více power-upů, plus superBox => obří hovínko
function openMysteryBlock(block)
    block.opened=true
    if block.superBox then
        -- Na první pohled prázdný, ale promění se v obří hovínko
        giantPoop = { timeLeft=3 }
        print("SUPER Mystery box => obří hovínko na 3s!")
        return
    end

    -- Teď zvolíme náhodný power-up (1..5)
    local r = love.math.random(1,5)
    -- 1) Letací mráček
    -- 2) Big mode s bambitkou
    -- 3) Cilindr
    -- 4) Smoking
    -- 5) Nic
    if r==1 then
        hrac.flyCloud={ timeLeft=10 }
        print("Power-up: Letací mráček (10s)!")
    elseif r==2 then
        hrac.isBig=true
        hrac.rychlost=hrac.baseSpeed*2
        print("Power-up: BIG mode + bambitka!")
    elseif r==3 then
        hrac.hasCilindr=true
        print("Power-up: Cilindr!")
    elseif r==4 then
        hrac.hasSmoking=true
        print("Power-up: Smoking!")
    else
        print("Power-up: Nic :-)")
    end
end

--------------------------------------------------------------------------------
-- LOVE.DRAW
--------------------------------------------------------------------------------
function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)

    -- Pozadí (zelené)
    love.graphics.clear(0.1,0.7,0.1)

    -- Platformy
    for _,p in ipairs(platformy) do
        love.graphics.setColor(p.color)
        love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
    end

    -- Mystery boxy
    for _,mb in ipairs(mysteryBlocks) do
        if not mb.opened then
            love.graphics.setColor(mb.color)
            love.graphics.rectangle("fill", mb.x, mb.y, mb.w, mb.h)
        end
    end

    -- Sliz segmenty (dynamicky)
    for _,sl in ipairs(slizSegments) do
        love.graphics.setColor(sl.color)
        local topY=sl.topY
        local bottom=sl.dynamicBottom
        local hh = bottom - topY
        if hh<0 then
            topY=bottom
            hh=-hh
        end
        love.graphics.rectangle("fill", sl.x, topY, sl.w, hh)
        -- Kapky? Můžete si dokreslit malé kapky dole.
    end

    -- Banány (žluté)
    love.graphics.setColor(1,1,0)
    for _,b in ipairs(banany) do
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    end

    -- Nepřátelé (fialoví), boss (hnědý)
    for _,n in ipairs(nepratele) do
        if n.bossMega then
            love.graphics.setColor(0.6,0.3,0)
        else
            love.graphics.setColor(0.7,0,0.7)
        end
        love.graphics.rectangle("fill", n.x, n.y, n.w, n.h)
    end

    -- Hrdinovy střely (mráčky)
    love.graphics.setColor(0.9,0.9,0.9)
    for _,m in ipairs(mracky) do
        love.graphics.rectangle("fill", m.x, m.y, m.w, m.h)
    end

    -- Hrdina
    local r,g,b = hrac:getColor()[1], hrac:getColor()[2], hrac:getColor()[3]
    love.graphics.setColor(r,g,b)
    love.graphics.rectangle("fill", hrac.x, hrac.y, hrac.w, hrac.h)

    -- Hrdinovy doplňky (cylindr, smoking)
    if hrac.hasCilindr then
        love.graphics.setColor(0,0,0)
        local hatH=10
        love.graphics.rectangle("fill", hrac.x, hrac.y - hatH, hrac.w, hatH)
        love.graphics.setColor(1,0,0)
        love.graphics.rectangle("fill", hrac.x, hrac.y - hatH/2-1, hrac.w, 2)
    end
    if hrac.hasSmoking then
        love.graphics.setColor(0,0,0)
        local coatH=10
        love.graphics.rectangle("fill", hrac.x, hrac.y+hrac.h, hrac.w, coatH)
    end

    -- Letací mráček
    if hrac.flyCloud then
        local alpha = hrac.flyCloud.timeLeft/10
        love.graphics.setColor(0,0.6,1, alpha)
        local cw=hrac.w+10
        local ch=8
        love.graphics.rectangle("fill", hrac.x-5, hrac.y+hrac.h, cw, ch)
    end

    -- Konec transformací
    love.graphics.pop()

    -- Obří hovínko?
    if giantPoop then
        local alpha=1
        -- Můžeme ho plynule zmenšovat, ale tady jen 3s plné
        love.graphics.setColor(0.5,0.35,0.1, alpha)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    end

    -- UI
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
        love.graphics.print("Fly mode (pf)", 10, 50)
    end

    if hraVyhrana then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Vyhrál jsi! [R] pro restart.",
            0, screenHeight/2 - 20, screenWidth, "center")
    elseif gameOver then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Prohrál jsi! [R] pro restart.",
            0, screenHeight/2 - 20, screenWidth, "center")
    end
end
