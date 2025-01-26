import pygame
import sys

pygame.init()

# -------------------------------------------------------------------
# KONSTANTY
# -------------------------------------------------------------------
WIDTH, HEIGHT = 800, 600
FPS = 60

GRAVITY = 0.5
MOVE_SPEED = 5
JUMP_SPEED = -12

# Velikosti Maria
MARIO_SMALL_SIZE = (15, 15)
MARIO_BIG_SIZE = (30, 30)

STATE_SMALL = 0
STATE_BIG = 1

# Scény
SCENE_OVERWORLD = 0
SCENE_UNDERWORLD = 1

# Barvy
WHITE = (255, 255, 255)
GREEN = (0, 255, 0)
BROWN = (139, 69, 19)
BLUE = (0, 0, 255)
BLACK = (0, 0, 0)
DARK_BLUE = (0, 0, 128)
RED = (255, 0, 0)
MAGENTA = (255, 0, 255)
GRAY = (128, 128, 128)
YELLOW = (255, 255, 0)

# Délka levelu do strany
LEVEL_WIDTH = 3000

screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Super Mario Demo")

clock = pygame.time.Clock()

# -------------------------------------------------------------------
# HRA – GLOBÁLNÍ PROMĚNNÉ (pro zjednodušení)
# -------------------------------------------------------------------
mario_state = STATE_SMALL
mario_w, mario_h = MARIO_SMALL_SIZE
mario_x = 50
mario_y = 300
mario_vel_x = 0
mario_vel_y = 0
on_ground = False

current_scene = SCENE_OVERWORLD
camera_x = 0

# Platformy – Overworld
platforms_overworld = [
    pygame.Rect(0, 550, 900, 50),   # dlouhá podlaha od x=0 do x=900
    pygame.Rect(900, 500, 150, 20),
    pygame.Rect(1100, 450, 150, 20),
    pygame.Rect(1400, 500, 150, 20),
    # Plošina kolem bosse (boss je cca na x=2200)
    pygame.Rect(1600, 550, 900, 50),
]

# Platformy – Underworld
platforms_underworld = [
    pygame.Rect(0, 550, 800, 50),
]

# Boxy (houbičky) – Overworld
boxes_overworld = [
    {"rect": pygame.Rect(500, 400, 30, 30), "used": False},
    {"rect": pygame.Rect(1000, 450, 30, 30), "used": False},
]

# Houbičky – Overworld
mushrooms_overworld = []

# Potrubí – Overworld -> Underworld
pipe_to_underworld = pygame.Rect(800, 520, 50, 30)

# Potrubí – Underworld -> Overworld
pipe_to_overworld = pygame.Rect(100, 520, 50, 30)

# Nepřátelé – Overworld
enemies_overworld = [
    {"rect": pygame.Rect(700, 530, 20, 20), "dir": -1},
    {"rect": pygame.Rect(1200, 530, 20, 20), "dir": 1},
]

# Nepřátelé – Underworld
enemies_underworld = [
    {"rect": pygame.Rect(400, 530, 20, 20), "dir": 1},
]

# Boss (Donkey Kong) v Overworldu
boss = {
    "rect": pygame.Rect(2200, 480, 40, 70),
    "timer": 0,
    "throw_interval": 120
}
# Sudy
barrels = []

# -------------------------------------------------------------------
# FUNKCE
# -------------------------------------------------------------------
def reset_game():
    """
    Reset do výchozího stavu hry (pro možnost 'Hrát znovu').
    """
    global mario_state, mario_w, mario_h
    global mario_x, mario_y, mario_vel_x, mario_vel_y, on_ground
    global current_scene, camera_x

    mario_state = STATE_SMALL
    mario_w, mario_h = MARIO_SMALL_SIZE
    mario_x = 50
    mario_y = 300
    mario_vel_x = 0
    mario_vel_y = 0
    on_ground = False

    current_scene = SCENE_OVERWORLD
    camera_x = 0

    # Zresetujeme i boxy, houbičky, nepřátele, sudy...
    for box in boxes_overworld:
        box["used"] = False
    mushrooms_overworld.clear()

    enemies_overworld[:] = [
        {"rect": pygame.Rect(700, 530, 20, 20), "dir": -1},
        {"rect": pygame.Rect(1200, 530, 20, 20), "dir": 1},
    ]
    enemies_underworld[:] = [
        {"rect": pygame.Rect(400, 530, 20, 20), "dir": 1},
    ]
    boss["rect"] = pygame.Rect(2200, 480, 40, 70)
    boss["timer"] = 0
    barrels.clear()

def set_mario_size(state):
    global mario_w, mario_h
    if state == STATE_SMALL:
        mario_w, mario_h = MARIO_SMALL_SIZE
    else:
        mario_w, mario_h = MARIO_BIG_SIZE

def become_big():
    global mario_state
    mario_state = STATE_BIG
    set_mario_size(mario_state)

def become_small():
    global mario_state
    mario_state = STATE_SMALL
    set_mario_size(mario_state)

def game_over_screen():
    """
    Místo ukončení programu zobrazíme 'Game Over',
    dáme možnost stisknout Enter pro novou hru, Esc pro konec.
    """
    font = pygame.font.SysFont(None, 60)
    text1 = font.render("GAME OVER!", True, (255, 0, 0))
    text2 = pygame.font.SysFont(None, 40).render("Enter = Nová hra, Escape = Konec", True, (0, 0, 0))

    screen.fill(WHITE)
    screen.blit(text1, (WIDTH//2 - text1.get_width()//2, HEIGHT//2 - 50))
    screen.blit(text2, (WIDTH//2 - text2.get_width()//2, HEIGHT//2 + 20))
    pygame.display.flip()

    waiting = True
    while waiting:
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_RETURN:  # Enter
                    waiting = False
                    reset_game()
                elif ev.key == pygame.K_ESCAPE:
                    pygame.quit()
                    sys.exit()

def handle_input():
    global mario_vel_x, mario_vel_y, on_ground
    keys = pygame.key.get_pressed()

    # Horizontální
    mario_vel_x = 0
    if keys[pygame.K_LEFT]:
        mario_vel_x = -MOVE_SPEED
    if keys[pygame.K_RIGHT]:
        mario_vel_x = MOVE_SPEED

    # Skok
    if keys[pygame.K_SPACE] and on_ground:
        mario_vel_y = JUMP_SPEED
        on_ground = False

    # Pro warp do trubky: Mario musí stát "shora" na trubce + mačkat šipku dolů
    # to budeme řešit ve funkci check_pipes(), ale tady si jen zkontrolujeme, jestli je stisk dolů
    # a podle toho tam pak v check_pipes() provedeme teleport.

def move_mario_and_check_collisions():
    global mario_x, mario_y, mario_vel_y, on_ground

    # Které platformy
    if current_scene == SCENE_OVERWORLD:
        plats = platforms_overworld
    else:
        plats = platforms_underworld

    # 1) Osa X
    mario_x += mario_vel_x
    m_rect = pygame.Rect(mario_x, mario_y, mario_w, mario_h)
    for p in plats:
        if m_rect.colliderect(p):
            if mario_vel_x > 0:
                mario_x = p.left - mario_w
            elif mario_vel_x < 0:
                mario_x = p.right
            m_rect.x = mario_x

    # 2) Osa Y + gravitace
    mario_vel_y += GRAVITY
    mario_y += mario_vel_y
    m_rect = pygame.Rect(mario_x, mario_y, mario_w, mario_h)

    on_ground = False
    for p in plats:
        if m_rect.colliderect(p):
            # zda mario padá shora
            if mario_vel_y > 0 and m_rect.bottom > p.top and m_rect.top < p.top:
                mario_y = p.top - mario_h
                mario_vel_y = 0
                on_ground = True
            # hlavou do platformy
            elif mario_vel_y < 0 and m_rect.top < p.bottom and m_rect.bottom > p.bottom:
                mario_y = p.bottom
                mario_vel_y = 0
            m_rect.y = mario_y

    # Můžeš nastavit i "dno mapy" (např. y>600 => spadne do jamy)
    # Ale bod #1 říká, že pád není konec hry, tak to necháme tak, aby prostě padal
    # a pokud tam není platforma, spadne až do "nekonečna". :-)
    #
    # Pokud bys chtěl, aby při y > 1000 byla smrt, třeba:
    # if mario_y > 1000:
    #     game_over_screen()

    # Omezíme šířku levelu
    if mario_x < 0:
        mario_x = 0
    if mario_x > LEVEL_WIDTH - mario_w:
        mario_x = LEVEL_WIDTH - mario_w

def check_boxes_collisions():
    """
    Když Mario narazí hlavou do boxu v overworldu, vyhodí houbičku.
    """
    global mario_y, mario_vel_y
    if current_scene != SCENE_OVERWORLD:
        return

    m_rect = pygame.Rect(mario_x, mario_y, mario_w, mario_h)
    for box in boxes_overworld:
        if box["used"]:
            continue
        box_r = box["rect"]
        if m_rect.colliderect(box_r):
            # Hlava
            if mario_vel_y < 0 and (m_rect.top < box_r.bottom <= m_rect.bottom):
                # Odraz Maria dolů
                mario_y = box_r.bottom
                mario_vel_y = 2
                # Houbička
                spawn_mushroom(box_r)
                box["used"] = True

def spawn_mushroom(box_rect):
    mush_rect = pygame.Rect(box_rect.x + 5, box_rect.y - 20, 20, 20)
    mushrooms_overworld.append({
        "rect": mush_rect,
        "vel_y": 0,
        "active": True
    })

def update_mushrooms():
    if current_scene != SCENE_OVERWORLD:
        return
    for mush in mushrooms_overworld:
        if not mush["active"]:
            continue
        mush["vel_y"] += GRAVITY
        mush["rect"].y += mush["vel_y"]
        # kolize s platformami
        for p in platforms_overworld:
            if mush["rect"].colliderect(p):
                if mush["vel_y"] > 0:
                    mush["rect"].bottom = p.top
                    mush["vel_y"] = 0
        # kolize s Mariem
        m_rect = pygame.Rect(mario_x, mario_y, mario_w, mario_h)
        if mush["rect"].colliderect(m_rect) and mush["active"]:
            become_big()
            mush["active"] = False

def move_enemies():
    if current_scene == SCENE_OVERWORLD:
        enemies = enemies_overworld
        plats = platforms_overworld
    else:
        enemies = enemies_underworld
        plats = platforms_underworld

    for e in enemies:
        # osa X
        e["rect"].x += e["dir"] * 2
        if e["rect"].x < 0:
            e["dir"] = 1
        if e["rect"].x + e["rect"].width > LEVEL_WIDTH:
            e["dir"] = -1
        # pád
        e["rect"].y += GRAVITY * 2
        # kolize s platformami
        for p in plats:
            if e["rect"].colliderect(p):
                if e["rect"].bottom > p.top and e["rect"].centery < p.centery:
                    e["rect"].bottom = p.top

def check_enemy_collisions():
    """
    - Shora => nepřítel zničen
    - Z boku => pokud Mario velký -> zmenšit, pokud malý -> Game Over
    """
    if current_scene == SCENE_OVERWORLD:
        enemies = enemies_overworld
    else:
        enemies = enemies_underworld

    m_rect = pygame.Rect(mario_x, mario_y, mario_w, mario_h)
    for e in enemies[:]:
        if m_rect.colliderect(e["rect"]):
            # Shora
            if mario_vel_y > 0 and (m_rect.bottom <= e["rect"].top + 5):
                enemies.remove(e)
                mario_vel_y = JUMP_SPEED // 2
            else:
                if mario_state == STATE_BIG:
                    become_small()
                else:
                    game_over_screen()
                    return  # abychom nepokračovali dál po game over

def check_pipes():
    """
    Trubka pro přechod do podzemí a zpět.
    Mario musí stát 'shora' na trubce a mačkat šipku dolů (K_DOWN).
    """
    global current_scene, mario_x, mario_y, mario_vel_y
    keys = pygame.key.get_pressed()
    m_rect = pygame.Rect(mario_x, mario_y, mario_w, mario_h)

    if current_scene == SCENE_OVERWORLD:
        if m_rect.colliderect(pipe_to_underworld):
            # Stojí shora?
            if abs(m_rect.bottom - pipe_to_underworld.top) < 5 and keys[pygame.K_DOWN]:
                # Teleport
                current_scene = SCENE_UNDERWORLD
                mario_x = 100
                mario_y = 300
                mario_vel_y = 0
    else:
        if m_rect.colliderect(pipe_to_overworld):
            if abs(m_rect.bottom - pipe_to_overworld.top) < 5 and keys[pygame.K_DOWN]:
                current_scene = SCENE_OVERWORLD
                # Vrátíme Maria "za" trubku overworldu
                mario_x = pipe_to_underworld.x + 80
                mario_y = 300
                mario_vel_y = 0

def update_boss_and_barrels():
    if current_scene != SCENE_OVERWORLD:
        return
    # Jakmile je Mario cca méně než 600 px od bosse, boss začně házet
    distance_to_boss = boss["rect"].x - mario_x
    if distance_to_boss < 600:
        boss["timer"] += 1
        if boss["timer"] >= boss["throw_interval"]:
            spawn_barrel()
            boss["timer"] = 0

    # Pohyb sudů
    for b in barrels[:]:
        b.x -= 4
        if b.x + b.width < 0:
            barrels.remove(b)
            continue
        # kolize s Mariem
        m_rect = pygame.Rect(mario_x, mario_y, mario_w, mario_h)
        if m_rect.colliderect(b):
            if mario_state == STATE_BIG:
                become_small()
                barrels.remove(b)
            else:
                game_over_screen()
                return

def spawn_barrel():
    bx = boss["rect"].x
    by = boss["rect"].y + 10
    new_b = pygame.Rect(bx, by, 20, 20)
    barrels.append(new_b)

def update_camera():
    global camera_x
    # chceme, aby byl Mario cca uprostřed
    target = mario_x - WIDTH // 2
    if target > camera_x:
        camera_x = target
    if camera_x < 0:
        camera_x = 0
    if camera_x > LEVEL_WIDTH - WIDTH:
        camera_x = LEVEL_WIDTH - WIDTH

def translate_rect(r):
    return pygame.Rect(r.x - camera_x, r.y, r.width, r.height)

# -------------------------------------------------------------------
# HLAVNÍ SMYČKA
# -------------------------------------------------------------------
def main_loop():
    running = True
    while running:
        clock.tick(FPS)
        # Pozadí
        if current_scene == SCENE_OVERWORLD:
            screen.fill(WHITE)
        else:
            screen.fill(DARK_BLUE)

        # Eventy
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

        # Ovládání
        handle_input()

        # Pohyb, kolize
        move_mario_and_check_collisions()
        check_boxes_collisions()
        update_mushrooms()
        move_enemies()
        check_enemy_collisions()
        check_pipes()
        update_boss_and_barrels()
        update_camera()

        # ----------------------------------------------------------------
        # Vykreslování
        # ----------------------------------------------------------------
        # Platformy
        if current_scene == SCENE_OVERWORLD:
            for p in platforms_overworld:
                pygame.draw.rect(screen, GREEN, translate_rect(p))
        else:
            for p in platforms_underworld:
                pygame.draw.rect(screen, GREEN, translate_rect(p))

        # Boxy
        if current_scene == SCENE_OVERWORLD:
            for box in boxes_overworld:
                col = BROWN if not box["used"] else (100, 70, 50)
                pygame.draw.rect(screen, col, translate_rect(box["rect"]))

        # Houbičky
        if current_scene == SCENE_OVERWORLD:
            for mush in mushrooms_overworld:
                if mush["active"]:
                    pygame.draw.rect(screen, MAGENTA, translate_rect(mush["rect"]))

        # Trubky
        if current_scene == SCENE_OVERWORLD:
            pygame.draw.rect(screen, BLUE, translate_rect(pipe_to_underworld))
        else:
            pygame.draw.rect(screen, BLUE, translate_rect(pipe_to_overworld))

        # Nepřátelé
        if current_scene == SCENE_OVERWORLD:
            for e in enemies_overworld:
                pygame.draw.rect(screen, RED, translate_rect(e["rect"]))
        else:
            for e in enemies_underworld:
                pygame.draw.rect(screen, RED, translate_rect(e["rect"]))

        # Boss + sudy
        if current_scene == SCENE_OVERWORLD:
            pygame.draw.rect(screen, GRAY, translate_rect(boss["rect"]))
            for b in barrels:
                pygame.draw.rect(screen, BROWN, translate_rect(b))

        # Mario
        mario_color = YELLOW if mario_state == STATE_BIG else RED
        m_draw = pygame.Rect(mario_x - camera_x, mario_y, mario_w, mario_h)
        pygame.draw.rect(screen, mario_color, m_draw)

        pygame.display.flip()

    pygame.quit()
    sys.exit()

# Spuštění
reset_game(
    
)
main_loop()
