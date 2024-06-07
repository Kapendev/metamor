module metamor.app;

import popka; // Most code inside the popka folder is wip.
import metamor.config;
import metamor.globals;

@safe @nogc nothrow:

enum ActorID {
    none,
    chloe,
    frog,
    bee,
}

enum BackgroundID {
    none,
    room,
    intro,
}

struct Actor {
    ActorID id;
    Vec2 position;
}

struct Background {
    BackgroundID id;
    float frame = 0.0f;
}

struct Game {
    Font font;
    Sprite actorAtlas;
    Sprite backgroundAtlas;
    Sprite backgroundBufferAtlas;
    Sprite cursorSprite;
    Music music;

    Dialogue dialogue;
    Background background;
    Background backgroundBuffer;
    Actor[3] actorBoxes;

    const(char)[][] args;
    float visibleRunes = 0.0f;
    float optionTimer = 0.0f;
    float backgroundTransition = 0.0f;
    bool isUIVisible = true;
}

void readyResources(const(char)[] exeDirPath) {
    // Initialize tile ids.
    actorTileIDs[ActorID.none] = 0;
    actorTileIDs[ActorID.chloe] = 0;
    actorTileIDs[ActorID.frog] = 0;
    actorTileIDs[ActorID.bee] = 7;

    // Initialize colors.
    actorColors[ActorID.none] = textColor;
    actorColors[ActorID.chloe] = textColor;
    actorColors[ActorID.frog] = Color(0x59, 0x7d, 0xce);
    actorColors[ActorID.bee] = Color(0xda, 0xd4, 0x5e);

    // Initialize background paths.
    void makePathForBackground(BackgroundID id, const(char)[] path) {
        backgroundPaths[id].clear();
        backgroundPaths[id].append(pathConcat(exeDirPath, "assets", path));
    }
    makePathForBackground(BackgroundID.none, "none_atlas.png");
    makePathForBackground(BackgroundID.room, "room_atlas.png");
    makePathForBackground(BackgroundID.intro, "intro_atlas.png");

    // Initialize background frame counts.
    backgroundFrameCounts[BackgroundID.none] = 1;
    backgroundFrameCounts[BackgroundID.room] = 1;
    backgroundFrameCounts[BackgroundID.intro] = 8;

    // Initialize actor box positions.
    auto y = resolution.y;
    game.actorBoxes[0].position = Vec2(resolution.x * 0.275f, y);
    game.actorBoxes[1].position = Vec2(resolution.x * 0.725f, y);
    game.actorBoxes[2].position = Vec2(resolution.x * 0.500f, y);

    // Load game files.
    const(char)[] filePath(const(char)[] path) {
        return pathConcat(exeDirPath, "assets", path);
    }
    game.font.load(filePath("pixeloid_sans.ttf"), 11, pixeloidFontRunes);
    game.font.spacing = pixeloadFontSpacing;
    game.actorAtlas.load(filePath("actor_atlas.png"));
    game.cursorSprite.load(filePath("cursor.png"));
    game.dialogue.load(filePath("dialogue.txt"));
    game.music.load(filePath("stop_for_a_moment.ogg"));
    game.dialogue.update();

    // Change some default popka state.
    changeBackgroundColor(gameColor);
}

void freeResources() {
    game.font.free();
    game.actorAtlas.free();
    game.backgroundAtlas.free();
    game.backgroundBufferAtlas.free();
    game.cursorSprite.free();
    game.music.free();
    game.dialogue.free();
    foreach (ref path; backgroundPaths) {
        path.free();
    }

    // For some reason "game = Game();" does not work on dmd with betterC.
    // But "game = Game.init" does.
    game = Game.init;
}

void runCommand(const(char)[][] args) {
    auto name = args[0];
    switch (name) {
        case "showActor": {
            if (args.length != 3) {
                assert(0, "Do something about the error case.");
            }
            auto box = args[1];
            auto actor = args[2];
            auto conv = toSigned(box);
            if (conv.error) {
                assert(0, "Do something about the error case.");
            } else {
                auto index = conv.value;
                game.actorBoxes[cast(size_t) index].id = toEnumWithNone!ActorID(actor);
            }
            break;
        }
        case "hideActor": {
            if (args.length != 2) {
                assert(0, "Do something about the error case.");
            }
            auto box = args[1];
            auto conv = toSigned(box);
            if (conv.error) {
                assert(0, "Do something about the error case.");
            } else {
                auto index = conv.value;
                game.actorBoxes[cast(size_t) index].id = ActorID.none;
            }
            break;
        }
        case "hideAllActors": {
            if (args.length != 1) {
                assert(0, "Do something about the error case.");
            }
            foreach (ref box; game.actorBoxes) {
                box.id = ActorID.none;
            }
            break;
        }
        case "showBackground": {
            if (args.length != 2) {
                assert(0, "Do something about the error case.");
            }
            game.backgroundBufferAtlas.free();
            game.backgroundBufferAtlas = game.backgroundAtlas;
            game.backgroundAtlas = Sprite();
            game.backgroundBuffer = game.background;
            game.background = Background();

            auto background = args[1];
            game.background.id = toEnumWithNone!BackgroundID(background);
            game.backgroundTransition = 0.0f;
            game.backgroundAtlas.load(backgroundPaths[game.background.id].items);
            break;
        }
        default: {
            assert(0, "Do something about the error case.");
        }
    }
}

void updateDialogueScene() {
    game.background.frame = wrap(game.background.frame + deltaTime / frameTime, 0.0f, backgroundFrameCounts[game.background.id]);
    game.backgroundBuffer.frame = wrap(game.backgroundBuffer.frame + deltaTime / frameTime, 0.0f, backgroundFrameCounts[game.backgroundBuffer.id]);
    if (!game.backgroundBufferAtlas.isEmpty) {
        game.backgroundTransition += deltaTime * transitionSpeed;
        if (game.backgroundTransition >= 1.0f) {
            game.backgroundBufferAtlas.free();
        }
        if (game.backgroundTransition < 0.5f) {
            game.background.frame = 0.0f;
        }
    }
}

void drawDialogueScene() {
    static backgroundOffset = Vec2();
    static actorOffset = Vec2();

    auto screenCenter = resolution * Vec2(0.5f);
    auto offsetRate = (mouseScreenPosition - screenCenter) / screenCenter;
    backgroundOffset = backgroundOffset.moveTo(
        Vec2(-maxBackgroundOffsetX, 0.0f) * offsetRate,
        Vec2(deltaTime),
        offsetSlowdown,
    );
    actorOffset = actorOffset.moveTo(
        Vec2(-maxActorOffsetX, 0.0f) * offsetRate,
        Vec2(deltaTime),
        offsetSlowdown,
    );

    draw(game.backgroundAtlas, backgroundSize, cast(uint) game.background.frame, backgroundOffset);
    if (game.backgroundTransition <= 0.5f) {
        draw(game.backgroundBufferAtlas, backgroundSize, cast(uint) game.backgroundBuffer.frame, backgroundOffset);
    }

    // Hack for hiding actor when changing background.
    auto canShowActor1 = game.background.id != BackgroundID.none && game.backgroundTransition >= 0.5f;
    auto canShowActor2 = game.background.id == BackgroundID.none && game.backgroundTransition <= 0.5f;
    if (canShowActor1 || canShowActor2) {
        auto options = DrawOptions();
        options.hook = Hook.bottom;
        foreach (box; game.actorBoxes) {
            if (box.id == ActorID.none) {
                continue;
            }
            draw(
                game.actorAtlas,
                actorSize,
                actorTileIDs[box.id],
                box.position + actorOffset,
                options
            );
        }
    }

    if (!game.backgroundBufferAtlas.isEmpty) {
        auto transitionValue = sin(game.backgroundTransition * pi);
        if (transitionValue <= 0.05f) {
            transitionValue = 0.0f;
        }
        if (transitionValue >= 0.95f) {
            transitionValue = 1.0f;
        }
        foreach (y; 0 .. ceil(resolution.y / transitionRectHeight)) {
            foreach (x; 0 .. ceil(resolution.x / transitionRectWidth)) {
                auto rectangle = Rect(
                    x * transitionRectWidth,
                    y * transitionRectHeight,
                    transitionRectWidth * transitionValue,
                    transitionRectHeight * transitionValue
                );
                draw(rectangle, gameColor);
            }
        }
    }
}

void updateDialogueBox() {
    auto hasClick = Keyboard.space.isPressed || Keyboard.enter.isPressed || Mouse.left.isPressed;
    auto hasRunes = cast(uint) game.visibleRunes == game.dialogue.text.length;
    if (hasClick && !hasRunes) {
        game.visibleRunes = game.dialogue.text.length;
    }
    game.visibleRunes = clamp(game.visibleRunes + deltaTime / runeTime, 0.0f, game.dialogue.text.length);
    if (hasClick && hasRunes) {
        game.visibleRunes = 0.0f;
        game.dialogue.update();
    }
    while (game.dialogue.hasArgs) {
        game.dialogue.run(&runCommand);
    }
}

void drawDialogueBox() {
    auto options = DrawOptions();
    options.hook = Hook.center;

    auto position = resolution * Vec2(0.50f, 0.92f);
    auto rectangle = Rect(position, Vec2(resolution.x, 16.0f));
    rectangle = rectangle.area(options.hook);
    rectangle.position.y += 1;

    draw(rectangle, backgroundColor);
    options.color = actorColors[toEnumWithNone!ActorID(game.dialogue.actor)];
    draw(
        game.font,
        game.dialogue.text[0 .. cast(uint) game.visibleRunes],
        position,
        options
    );
}

void updateDialogueChoices() {
    auto choices = game.dialogue.choices;
    auto startY = resolution.y * 0.5f;
    if (choices.length % 2 == 0) {
        startY += (floor(choices.length / 2.0f) - 0.5f) * -optionRectOffset;
    } else {
        startY += (floor(choices.length / 2.0f)) * -optionRectOffset;
    }

    auto maxTextWidth = 0.0f;
    foreach (choice; choices) {
        auto textSize = measureTextSize(game.font, choice);
        if (maxTextWidth < textSize.x) {
            maxTextWidth = textSize.x;
        }
    }

    foreach (i, choice; choices) {
        if (game.optionTimer <= optionDelayTime) {
            game.optionTimer += deltaTime;
            return;
        }

        auto rectangle = Rect(
            Vec2(resolution.x * 0.5f, startY + (optionRectOffset * i)),
            Vec2(maxTextWidth + optionRectExtraWidth, optionRectHeight)
        );
        auto mouseRect = Rect(mouseScreenPosition, cursorSize).area(Hook.center);
        auto centeredRect = rectangle.area(Hook.center);
        if (centeredRect.hasIntersection(mouseRect)) {
            if (Mouse.left.isReleased) {
                game.dialogue.select(i);
                game.optionTimer = 0.0f;
            }
        }
    }
}

void drawDialogueChoices() {
    auto choices = game.dialogue.choices;
    auto startY = resolution.y * 0.5f;
    if (choices.length % 2 == 0) {
        startY += (floor(choices.length / 2.0f) - 0.5f) * -optionRectOffset;
    } else {
        startY += (floor(choices.length / 2.0f)) * -optionRectOffset;
    }

    auto maxTextWidth = 0.0f;
    foreach (choice; choices) {
        auto textSize = measureTextSize(game.font, choice);
        if (maxTextWidth < textSize.x) {
            maxTextWidth = textSize.x;
        }
    }

    auto textOptions = DrawOptions();
    textOptions.hook = Hook.center;
    foreach (i, choice; choices) {
        auto rectangle = Rect(
            Vec2(resolution.x * 0.5f, startY + (optionRectOffset * i)),
            Vec2(maxTextWidth + optionRectExtraWidth, optionRectHeight)
        );
        auto mouseRect = Rect(mouseScreenPosition, cursorSize).area(Hook.center);
        auto centeredRect = rectangle.area(Hook.center);
        if (game.optionTimer > optionDelayTime && centeredRect.hasIntersection(mouseRect)) {
            draw(centeredRect, textColor);
            textOptions.color = textColor;
        } else {
            draw(centeredRect, worldColor);
            textOptions.color = worldColor;
        }
        centeredRect.subAll(1);
        draw(centeredRect, backgroundColor);
        draw(game.font, choice, centeredRect.centerPoint, textOptions);
    }
}

void drawCursor() {
    auto options = DrawOptions();
    options.hook = Hook.center;
    draw(game.cursorSprite, cursorSize, Mouse.left.isDown, mouseScreenPosition, options);
}

bool gameLoop() {
    version(WebAssembly) {

    } else {
        if (Keyboard.f11.isPressed) {
            toggleFullscreen();
        }
        if (Keyboard.esc.isPressed) {
            return true;
        }
    }

    // Hide UI if needed.
    if (Mouse.right.isReleased) {
        game.isUIVisible = !game.isUIVisible;
    }
    // Update game.
    game.music.update();
    if (game.dialogue.hasText) {
        updateDialogueScene();
        if (game.isUIVisible) {
            if (game.dialogue.hasChoices) {
                updateDialogueChoices();
            } else {
                updateDialogueBox();
            }
        }
    }
    // Draw game.
    if (game.dialogue.hasText) {
        drawDialogueScene();
        if (game.isUIVisible) {
            drawDialogueBox();
            drawDialogueChoices();
        }
    }
    if (game.isUIVisible) {
        drawCursor();
    }
    return false;
}

void gameStart(const(char)[] path) {
    openWindow(1280, 720);
    lockResolution(320, 180);
    hideCursor();
    togglePixelPerfect();

    readyResources(pathDir(path));
    game.music.changeVolume(0.2f);
    game.music.play();
    updateWindow!gameLoop();

    freeResources();
    closeWindow();
}

mixin addGameStart!gameStart;
