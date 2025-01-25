import pygame

# Initialize Pygame
pygame.init()

# Constants
WIDTH, HEIGHT = 800, 600
GRAVITY = 0.5
JUMP_STRENGTH = -15
MOVE_SPEED = 7
ENEMY_SPEED = 3
MARIO_SIZE = 15  # Mario
PLATFORM_HEIGHT = 20
SCENE_OVERWORLD = 0
SCENE_UNDERWORLD = 1

# Colors
RED = (255, 0, 0)
WHITE = (255, 255, 255)
GREEN = (0, 255, 0)
BROWN = (139, 69, 19)
BLUE = (0, 0, 255)
BLACK = (0, 0, 0)
DARK_BLUE = (0, 0, 128)
MAGENTA = (255, 0, 255)  # Barva houbičky (libovolná)

# Screen setup
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Super Mario (Minimal)")

# Mario setup
mario = pygame.Rect(50, HEIGHT - 100, MARIO_SIZE, MARIO_SIZE)
velocity_y = 0
on_ground = False
power_up = False
current_scene = SCENE_OVERWORLD

# Overworld elements
platforms_overworld = [
    pygame.Rect(0, HEIGHT - PLATFORM_HEIGHT, WIDTH, PLATFORM_HEIGHT),
    pygame.Rect(200, 500, 120, PLATFORM_HEIGHT),
    pygame.Rect(400, 400, 180, PLATFORM_HEIGHT),
    pygame.Rect(600, 300, 120, PLATFORM_HEIGHT),
]

# U každého boxu si pamatuj, jestli už byl použit
boxes_overworld = [
    {"rect": pygame.Rect(250, 450, 30, 30), "used": False},
    {"rect": pygame.Rect(450, 350, 30, 30), "used": False},
]

pipes_overworld = [pygame.Rect(700, HEIGHT - 80, 80, 60)]

enemies_overworld = [
    {"rect": pygame.Rect(350, HEIGHT - 30, 20, 20), "direction": 1},
    {"rect": pygame.Rect(500, HEIGHT - 30, 20, 20), "direction": -1},
]

# Underworld elements
platforms_underworld = [
    pygame.Rect(0, HEIGHT - PLATFORM_HEIGHT, WIDTH, PLATFORM_HEIGHT),
    pygame.Rect(200, 450, 120, PLATFORM_HEIGHT),
    pygame.Rect(400, 350, 180, PLATFORM_HEIGHT),
    pygame.Rect(600, 250, 120, PLATFORM_HEIGHT),
]
enemies_underworld = [
    {"rect": pygame.Rect(400, HEIGHT - 30, 20, 20), "direction": -1},
]

# Seznam houbiček (pouze pro overworld, ale můžeš si udělat i pro underworld)
mushrooms_overworld = []

def check_collisions():
    """
    Kontroluje srážky s platformami, trubkami, nepřáteli a
    také vyřeší logiku vstupu do underworld/overworld.
    """
    global velocity_y, on_ground, power_up, current_scene
    on_ground = False

    # Které prvky v aktuální scéně sledujeme
    platforms = platforms_overworld if current_scene == SCENE_OVERWORLD else platforms_underworld
    pipes = pipes_overworld if current_scene == SCENE_OVERWORLD else []
    enemies = enemies_overworld if current_scene == SCENE_OVERWORLD else enemies_underworld

    # Kolize s platformami (zeshora)
    for platform in platforms:
        if mario.colliderect(platform) and velocity_y > 0:
            mario.bottom = platform.top  # Postav Maria na platformu
            velocity_y = 0
            on_ground = True

    # Kolize s trubkami -> přepnutí scény
    for pipe in pipes:
        if mario.colliderect(pipe):
            # Přepne scénu
            current_scene = SCENE_UNDERWORLD if current_scene == SCENE_OVERWORLD else SCENE_OVERWORLD
            # Reset pozice Maria
            mario.x = 50
            mario.y = HEIGHT - 100
            return  # Předejdeme kolizím, které by se řešily níže

    # Kolize s nepřáteli
    for enemy in enemies:
        if mario.colliderect(enemy["rect"]):
            # Pokud Mario skočil na nepřítele
            if mario.bottom <= enemy["rect"].top + 5:
                enemies.remove(enemy)
                power_up = False
            else:
                print("Game Over!")
                pygame.quit()
                exit()

def check_box_collisions():
    """
    Koukne, jestli Mario netrefil box zespodu.
    Pokud ano, a box ještě nebyl použit, 'vyhodí' houbičku.
    """
    global velocity_y
    if current_scene != SCENE_OVERWORLD:
        return  # U underworldu teď nic neřešíme

    for box in boxes_overworld:
        # Pokud už box byl použit, přeskočíme
        if box["used"]:
            continue

        # Zjistíme, zda Mario koliduje s boxem, ale hlavně zespodu (tedy Mario se pohybuje nahoru -> velocity_y < 0)
        if mario.colliderect(box["rect"]) and velocity_y < 0:
            # Opravíme kolizi tak, aby se Mario hlavou nedostal nad box
            mario.top = box["rect"].bottom
            # Trochu ho odrazíme dolů, aby neprocházel boxem
            velocity_y = 2

            # 'Vystřelíme' houbičku nahoru na box (resp. těsně nad box)
            mushroom_rect = pygame.Rect(
                box["rect"].x + 5,  # aby to bylo trošku zarovnané
                box["rect"].y - 20,  # nad box
                20,
                20
            )
            mushrooms_overworld.append({
                "rect": mushroom_rect,
                "vel_y": 0,
                "active": True
            })

            # Box označíme jako použitý
            box["used"] = True

def update_mushrooms():
    """
    Spustí na houbičky gravitaci, otestuje kolize s platformami
    a zjistí, jestli je Mario nesebral.
    """
    global power_up
    if current_scene != SCENE_OVERWORLD:
        return

    platforms = platforms_overworld

    for mushroom in mushrooms_overworld:
        if not mushroom["active"]:
            continue

        # Aplikujeme gravitaci
        mushroom["vel_y"] += GRAVITY
        mushroom["rect"].y += mushroom["vel_y"]

        # Kolize houbiček s platformami
        for plat in platforms:
            if mushroom["rect"].colliderect(plat):
                # Položíme houbičku na platformu
                mushroom["rect"].bottom = plat.top
                mushroom["vel_y"] = 0

        # Pokud Mario sebere houbičku
        if mario.colliderect(mushroom["rect"]):
            # Nastavíme power_up, smažeme (nebo deaktivujeme) houbičku
            power_up = True
            mushroom["active"] = False

def move_enemies():
    """
    Prosté posouvání nepřátel zleva doprava s otočením
    při nárazu na okraj.
    """
    enemies = enemies_overworld if current_scene == SCENE_OVERWORLD else enemies_underworld
    for enemy in enemies:
        enemy["rect"].x += enemy["direction"] * ENEMY_SPEED
        if enemy["rect"].x <= 0 or enemy["rect"].x >= WIDTH - enemy["rect"].width:
            enemy["direction"] *= -1  # Reverse direction


# Game loop
running = True
clock = pygame.time.Clock()

while running:
    clock.tick(60)
    # Vyplnění pozadí dle scény
    screen.fill(WHITE if current_scene == SCENE_OVERWORLD else DARK_BLUE)

    # Event handling
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    # Movement (left, right)
    keys = pygame.key.get_pressed()
    if keys[pygame.K_LEFT]:
        mario.x -= MOVE_SPEED
    if keys[pygame.K_RIGHT]:
        mario.x += MOVE_SPEED

    # Jump
    if keys[pygame.K_SPACE] and on_ground:
        velocity_y = JUMP_STRENGTH
        on_ground = False

    # Apply gravity
    velocity_y += GRAVITY
    mario.y += velocity_y

    # Nejdřív zkontrolujeme kolize s boxy (zespodu)
    check_box_collisions()

    # Pak klasické kolize (platformy, nepřátelé, trubky)
    check_collisions()

    # Hýbeme nepřáteli
    move_enemies()

    # Update houbiček (gravitace, kolize, sebrání)
    update_mushrooms()

    # Draw Mario
    pygame.draw.rect(screen, RED if not power_up else BLACK, mario)

    # Draw platforms
    if current_scene == SCENE_OVERWORLD:
        for platform in platforms_overworld:
            pygame.draw.rect(screen, GREEN, platform)
    else:
        for platform in platforms_underworld:
            pygame.draw.rect(screen, GREEN, platform)

    # Draw boxes (použité můžeme nechat hnědé, nebo je překreslit jinou barvou)
    if current_scene == SCENE_OVERWORLD:
        for box in boxes_overworld:
            color = BROWN if not box["used"] else (100, 70, 50)  # trošku jiná barva
            pygame.draw.rect(screen, color, box["rect"])

    # Draw pipes
    if current_scene == SCENE_OVERWORLD:
        for pipe in pipes_overworld:
            pygame.draw.rect(screen, BLUE, pipe)

    # Draw enemies
    enemies = enemies_overworld if current_scene == SCENE_OVERWORLD else enemies_underworld
    for enemy in enemies:
        pygame.draw.rect(screen, (255, 0, 0), enemy["rect"])

    # Draw mushrooms
    if current_scene == SCENE_OVERWORLD:
        for mushroom in mushrooms_overworld:
            if mushroom["active"]:
                pygame.draw.rect(screen, MAGENTA, mushroom["rect"])

    pygame.display.flip()

pygame.quit()
