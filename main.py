import pygame

# Initialize Pygame
pygame.init()

# Constants
WIDTH, HEIGHT = 800, 600
GRAVITY = 0.5
JUMP_STRENGTH = -15
MOVE_SPEED = 7
ENEMY_SPEED = 3
MARIO_SIZE = 15  # Increased size of Mario
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

# Screen setup
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Super Mario Pixel")

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

boxes_overworld = [pygame.Rect(250, 450, 30, 30), pygame.Rect(450, 350, 30, 30)]

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

enemies_underworld = [{"rect": pygame.Rect(400, HEIGHT - 30, 20, 20), "direction": -1}]


def check_collisions():
    global velocity_y, on_ground, power_up, current_scene
    on_ground = False
    platforms = (
        platforms_overworld
        if current_scene == SCENE_OVERWORLD
        else platforms_underworld
    )
    pipes = pipes_overworld if current_scene == SCENE_OVERWORLD else []
    enemies = (
        enemies_overworld if current_scene == SCENE_OVERWORLD else enemies_underworld
    )

    for platform in platforms:
        if mario.colliderect(platform) and velocity_y > 0:
            mario.y = platform.y - mario.height
            velocity_y = 0
            on_ground = True

    # Check collision with pipes to switch scene
    for pipe in pipes:
        if mario.colliderect(pipe):
            current_scene = (
                SCENE_UNDERWORLD
                if current_scene == SCENE_OVERWORLD
                else SCENE_OVERWORLD
            )
            mario.x = 50  # Reset Mario position
            mario.y = HEIGHT - 100

    # Check collision with enemies
    for enemy in enemies:
        if mario.colliderect(enemy["rect"]):
            if mario.bottom <= enemy["rect"].top + 5:  # Mario stomps the enemy
                enemies.remove(enemy)
                power_up = False
            else:
                print("Game Over!")
                pygame.quit()
                exit()


# Game loop
running = True
clock = pygame.time.Clock()

while running:
    clock.tick(60)
    screen.fill(WHITE if current_scene == SCENE_OVERWORLD else DARK_BLUE)

    # Event handling
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    # Movement
    keys = pygame.key.get_pressed()
    if keys[pygame.K_LEFT]:
        mario.x -= MOVE_SPEED
    if keys[pygame.K_RIGHT]:
        mario.x += MOVE_SPEED
    if keys[pygame.K_SPACE] and on_ground:
        velocity_y = JUMP_STRENGTH
        on_ground = False

    # Apply gravity
    velocity_y += GRAVITY
    mario.y += velocity_y

    # Move enemies
    enemies = (
        enemies_overworld if current_scene == SCENE_OVERWORLD else enemies_underworld
    )
    for enemy in enemies:
        enemy["rect"].x += enemy["direction"] * ENEMY_SPEED
        if enemy["rect"].x <= 0 or enemy["rect"].x >= WIDTH - enemy["rect"].width:
            enemy["direction"] *= -1  # Reverse direction when hitting a wall

    # Check collisions
    check_collisions()

    # Draw Mario
    pygame.draw.rect(screen, RED if not power_up else BLACK, mario)

    # Draw platforms
    platforms = (
        platforms_overworld
        if current_scene == SCENE_OVERWORLD
        else platforms_underworld
    )
    for platform in platforms:
        pygame.draw.rect(screen, GREEN, platform)

    # Draw boxes
    if current_scene == SCENE_OVERWORLD:
        for box in boxes_overworld:
            pygame.draw.rect(screen, BROWN, box)

    # Draw pipes
    if current_scene == SCENE_OVERWORLD:
        for pipe in pipes_overworld:
            pygame.draw.rect(screen, BLUE, pipe)

    # Draw enemies
    for enemy in enemies:
        pygame.draw.rect(screen, (255, 0, 0), enemy["rect"])

    pygame.display.flip()

pygame.quit()
