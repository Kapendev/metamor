module noveldev.app;

import popka.basic; // Most code inside the popka folder is wip.
import ray = popka.vendor.ray.raylib; // Must use something that is not in popka.
import noveldev.config;
import noveldev.globals;

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
    ray.Music music;

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

void readyResources(const(char)[] exePath) {
    static char[1024] exeDirPathBuffer = void;
    static List!char filePathBuffer;

    // Find assets path.
    auto exeDirPath = exeDirPathBuffer[];
    foreach (i, c; exePath) {
        exeDirPath[i] = c;
    }
    foreach_reverse(i, c; exeDirPath) {
        version (Windows) {
            if (c == '\\') {
                exeDirPath = exeDirPathBuffer[0 .. i];
                break;
            }
        } else {
            if (c == '/') {
                exeDirPath = exeDirPathBuffer[0 .. i];
                break;
            }
        }
    }

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
        backgroundPaths[id].append(exeDirPath);
        version (Windows) {
            backgroundPaths[id].append("\\assets\\");
        } else {
            backgroundPaths[id].append("/assets/");
        }
        backgroundPaths[id].append(path);
        println(backgroundPaths[id].items);
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
        filePathBuffer.clear();
        filePathBuffer.append(exeDirPath);
        version (Windows) {
            filePathBuffer.append("\\assets\\");
        } else {
            filePathBuffer.append("/assets/");
        }
        filePathBuffer.append(path);
        return filePathBuffer.items;
    }
    game.font.load(filePath("pixeloid_sans.ttf"), 11, pixeloidFontRunes);
    game.font.spacing = pixeloadFontSpacing;
    game.actorAtlas.load(filePath("actor_atlas.png"));
    game.cursorSprite.load(filePath("cursor.png"));
    game.dialogue.load(filePath("dialogue.txt"));
    game.music = ray.LoadMusicStream(filePath("stop_for_a_moment.ogg").toStrz());
    game.dialogue.update();

    // Change some default popka state.
    popkaState.backgroundColor = backgroundColor;
    filePathBuffer.free();
}

void freeResources() {
    game.font.free();
    game.actorAtlas.free();
    game.backgroundAtlas.free();
    game.backgroundBufferAtlas.free();
    game.cursorSprite.free();
    ray.UnloadMusicStream(game.music);
    game.dialogue.free();
    foreach (ref path; backgroundPaths) {
        path.free();
    }
    game = Game();
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
                game.actorBoxes[index].id = toEnum!ActorID(actor);
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
                game.actorBoxes[index].id = ActorID.none;
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
            game.background.id = toEnum!BackgroundID(background);
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
    auto offsetRate = (mouse - screenCenter) / screenCenter;
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

    drawTile(game.backgroundAtlas, backgroundSize, cast(uint) game.background.frame, backgroundOffset);
    if (game.backgroundTransition <= 0.5f) {
        drawTile(game.backgroundBufferAtlas, backgroundSize, cast(uint) game.backgroundBuffer.frame, backgroundOffset);
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
            drawTile(
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
                auto rect = Rect(
                    x * transitionRectWidth,
                    y * transitionRectHeight,
                    transitionRectWidth * transitionValue,
                    transitionRectHeight * transitionValue
                );
                drawRect(rect, backgroundColor);
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
    auto rect = Rect(position, Vec2(resolution.x, 16.0f));
    rect = rect.rect(options.hook);
    rect.position.y += 1;

    drawRect(rect, backgroundColor);
    options.color = actorColors[toEnum!ActorID(game.dialogue.actor)];
    drawText(
        game.font,
        game.dialogue.text[0 .. cast(uint) game.visibleRunes],
        position,
        options
    );
}

void updateDialogueOptions() {
    auto gameOptions = game.dialogue.options;
    auto startY = resolution.y * 0.5f;
    if (gameOptions.length % 2 == 0) {
        startY += (floor(gameOptions.length / 2.0f) - 0.5f) * -optionRectOffset;
    } else {
        startY += (floor(gameOptions.length / 2.0f)) * -optionRectOffset;
    }

    auto maxTextWidth = 0.0f;
    foreach (option; gameOptions) {
        auto textSize = measureText(game.font, option);
        if (maxTextWidth < textSize.x) {
            maxTextWidth = textSize.x;
        }
    }

    foreach (i, option; gameOptions) {
        if (game.optionTimer <= optionDelayTime) {
            game.optionTimer += deltaTime;
            return;
        }

        auto rect = Rect(
            Vec2(resolution.x * 0.5f, startY + (optionRectOffset * i)),
            Vec2(maxTextWidth + optionRectExtraWidth, optionRectHeight)
        );
        auto mouseRect = Rect(mouse, cursorSize).rect(Hook.center);
        auto centeredRect = rect.rect(Hook.center);
        if (centeredRect.hasIntersection(mouseRect)) {
            if (Mouse.left.isReleased) {
                game.dialogue.select(i);
                game.optionTimer = 0.0f;
            }
        }
    }
}

void drawDialogueOptions() {
    auto gameOptions = game.dialogue.options;
    auto startY = resolution.y * 0.5f;
    if (gameOptions.length % 2 == 0) {
        startY += (floor(gameOptions.length / 2.0f) - 0.5f) * -optionRectOffset;
    } else {
        startY += (floor(gameOptions.length / 2.0f)) * -optionRectOffset;
    }

    auto maxTextWidth = 0.0f;
    foreach (option; gameOptions) {
        auto textSize = measureText(game.font, option);
        if (maxTextWidth < textSize.x) {
            maxTextWidth = textSize.x;
        }
    }

    auto textOptions = DrawOptions();
    textOptions.hook = Hook.center;
    foreach (i, option; gameOptions) {
        auto rect = Rect(
            Vec2(resolution.x * 0.5f, startY + (optionRectOffset * i)),
            Vec2(maxTextWidth + optionRectExtraWidth, optionRectHeight)
        );
        auto mouseRect = Rect(mouse, cursorSize).rect(Hook.center);
        auto centeredRect = rect.rect(Hook.center);
        if (game.optionTimer > optionDelayTime && centeredRect.hasIntersection(mouseRect)) {
            drawRect(centeredRect, textColor);
            textOptions.color = textColor;
        } else {
            drawRect(centeredRect, worldColor);
            textOptions.color = worldColor;
        }
        centeredRect.subAll(1);
        drawRect(centeredRect, backgroundColor);
        drawText(game.font, option, rect.position + Vec2(0.0f, -1.0f), textOptions);
    }
}

void drawCursor() {
    auto options = DrawOptions();
    options.hook = Hook.center;
    drawTile(game.cursorSprite, cursorSize, Mouse.left.isDown, mouse, options);
}

void main(const(char)[][] args) {
    openWindow(1280, 720);
    lockResolution(320, 180);
    hideCursor();
    toggleFullscreen();
    ray.InitAudioDevice();

    readyResources(args[0]);
    ray.SetMusicVolume(game.music, 0.2f);
    ray.PlayMusicStream(game.music);

    while (isWindowOpen) {
        ray.UpdateMusicStream(game.music);
        // Define some buttons.
        if (Keyboard.f11.isPressed) {
            toggleFullscreen();
        }
        if (Keyboard.esc.isPressed) {
            closeWindow();
        }
        // Hide UI if needed.
        if (Mouse.right.isReleased) {
            game.isUIVisible = !game.isUIVisible;
        }
        // Update game.
        if (game.dialogue.hasText) {
            updateDialogueScene();
            if (game.isUIVisible) {
                if (game.dialogue.hasOptions) {
                    updateDialogueOptions();
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
                drawDialogueOptions();
            }
        }
        if (game.isUIVisible) {
            drawCursor();
        }
    }

    freeResources();
    ray.CloseAudioDevice();
    freeWindow();
}
