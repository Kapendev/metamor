// Copyright 2024 Alexandros F. G. Kapretsos
// SPDX-License-Identifier: MIT

/// The engine module functions as a lightweight 2D game engine,
/// designed to provide essential tools and functionalities for developing games with ease and efficiency.

module popka.game.engine;

import ray = popka.vendor.ray.raylib;
import raygl = popka.vendor.ray.rlgl;
import popka.game.pixeloid;

public import popka.core.basic;

@safe @nogc nothrow:

PopkaState popkaState;
Font popkaPixeloidFont;

enum {
    defaultFPS = 60,
    defaultBackgroundColor = Color(0x2A, 0x36, 0x3A),
    defaultDebugFontColor = lightGray,
    toggleFullscreenWaitTime = 0.125f,
}

enum Flip : ubyte {
    none,
    x,
    y,
    xy,
}

enum Filter : ubyte {
    nearest,
    linear,
}

struct Sprite {
    ray.Texture2D data;

    @safe @nogc nothrow:

    this(const(char)[] path) {
        load(path);
    }

    bool isEmpty() {
        return data.id <= 0;
    }

    Vec2 size() {
        return Vec2(data.width, data.height);
    }

    Rect rect() {
        return Rect(size);
    }

    void load(const(char)[] path) {
        free();
        if (path.length != 0) {
            data = ray.LoadTexture(toStrz(path));
        }
    }

    void free() {
        if (!isEmpty) {
            ray.UnloadTexture(data);
            data = ray.Texture2D();
        }
    }
}

struct Font {
    ray.Font data;
    Vec2 spacing;

    @safe @nogc nothrow:

    this(const(char)[] path, uint size, const(dchar)[] runes = []) {
        load(path, size, runes);
    }

    bool isEmpty() {
        return data.texture.id <= 0;
    }

    float size() {
        return data.baseSize;
    }

    @trusted
    void load(const(char)[] path, uint size, const(dchar)[] runes = []) {
        free();
        if (path.length != 0) {
            data = ray.LoadFontEx(toStrz(path), size, cast(int*) runes.ptr, cast(int) runes.length);
        }
    }

    void free() {
        if (!isEmpty) {
            ray.UnloadFont(data);
            data = ray.Font();
        }
    }
}

struct View {
    ray.RenderTexture2D data;

    @safe @nogc nothrow:

    this(Vec2 size) {
        load(size);
    }

    this(float width, float height) {
        load(width, height);
    }

    bool isEmpty() {
        return data.texture.id <= 0;
    }

    Vec2 size() {
        return Vec2(data.texture.width, data.texture.height);
    }

    Rect rect() {
        return Rect(size);
    }

    void load(Vec2 size) {
        free();
        data = ray.LoadRenderTexture(cast(int) size.x, cast(int) size.y);
    }

    void load(float width, float height) {
        load(Vec2(width, height));
    }

    void free() {
        if (!isEmpty) {
            ray.UnloadRenderTexture(data);
            data = ray.RenderTexture();
        }
    }
}

// TODO: Needs a lot of testing and changing.
// NOTE: This should handle sounds and music.
// NOTE: I added this basic layer to use it for a visual novel.
struct AudioAsset {
    ray.Music data;

    @safe @nogc nothrow:

    this(const(char)[] path) {
        load(path);
    }

    bool isEmpty() {
        return data.stream.sampleRate == 0;
    }

    void load(const(char)[] path) {
        free();
        if (path.length != 0) {
            ray.LoadMusicStream(toStrz(path));
        }
    }

    void free() {
        if (!isEmpty) {
            ray.UnloadMusicStream(data);
            data = ray.Music();
        }
    }

    void update() {
        ray.UpdateMusicStream(data);
    }

    void play() {
        ray.PlayMusicStream(data);
    }

    void stop() {
        ray.StopMusicStream(data);
    }

    void pause() {
        ray.PauseMusicStream(data);
    }

    void resume() {
        ray.ResumeMusicStream(data);
    }
}

struct TileMap {
    Grid!short data;
    alias data this;

    @safe @nogc nothrow:

    Vec2 cellSize() {
        return Vec2(cellWidth, cellHeight);
    }

    void cellSize(Vec2 value) {
        cellWidth = value.x;
        cellHeight = value.y;
    }

    Vec2 size() {
        return Vec2(width, height);
    }

    void load(const(char)[] path) {
        free();
        if (path.length == 0) {
            return;
        }
        auto file = readText(path);
        const(char)[] view = file.items;
        while (view.length != 0) {
            auto line = view.skipLine();
            rowCount += 1;
            colCount = 0;
            while (line.length != 0) {
                auto value = line.skipValue();
                colCount += 1;
            }
        }
        resize(rowCount, colCount);

        view = file.items;
        foreach (row; 0 .. rowCount) {
            auto line = view.skipLine();
            foreach (col; 0 .. colCount) {
                auto value = line.skipValue();
                auto conv = value.toSigned();
                if (conv.error) {
                    data[row, col] = cast(short) -1;
                } else {
                    data[row, col] = cast(short) conv.value;
                }
            }
        }
        file.free();
    }
}

struct Camera {
    Vec2 position;
    float rotation = 0.0f;
    float scale = 1.0f;
    Hook hook;
    bool isAttached;

    @safe @nogc nothrow:

    this(Vec2 position) {
        this.position = position;
    }

    this(float x, float y) {
        this.position = Vec2(x, y);
    }

    Vec2 size() {
        return resolution * Vec2(scale);
    }

    Vec2 origin() {
        return Rect(size).origin(hook);
    }

    Rect rect() {
        return Rect(position - origin, size);
    }

    Vec2 point(Hook hook) {
        return rect.point(hook);
    }

    void attach() {
        if (!isAttached) {
            isAttached = true;
            auto temp = toRay(this);
            temp.target.x = floor(temp.target.x);
            temp.target.y = floor(temp.target.y);
            temp.offset.x = floor(temp.offset.x);
            temp.offset.y = floor(temp.offset.y);
            ray.BeginMode2D(temp);
        }
    }

    void detach() {
        if (isAttached) {
            isAttached = false;
            ray.EndMode2D();
        }
    }

    void follow(Vec2 target, float slowdown = 0.14f) {
        if (slowdown <= 0.0f) {
            position = target;
        } else {
            position = position.moveTo(target, Vec2(deltaTime), slowdown);
        }
    }
}

struct DrawOptions {
    Vec2 scale = Vec2(1.0f);
    float rotation = 0.0f;
    Color color = white;
    Hook hook = Hook.topLeft;
    Flip flip = Flip.none;
    Filter filter = Filter.nearest;
}

struct PopkaState {
    bool isWindowOpen;
    bool isDrawing;
    bool isFPSLocked;
    bool isCursorHidden;

    Color backgroundColor;
    Font debugFont;
    Vec2 debugFontSpacing;
    DrawOptions debugFontOptions;

    View view;
    Vec2 targetViewSize;
    bool isLockResolutionQueued;
    bool isUnlockResolutionQueued;

    Vec2 lastWindowSize;
    float toggleFullscreenTimer = 0.0f;
    bool isToggleFullscreenQueued;
}

enum Keyboard {
    a = ray.KEY_A,
    b = ray.KEY_B,
    c = ray.KEY_C,
    d = ray.KEY_D,
    e = ray.KEY_E,
    f = ray.KEY_F,
    g = ray.KEY_G,
    h = ray.KEY_H,
    i = ray.KEY_I,
    j = ray.KEY_J,
    k = ray.KEY_K,
    l = ray.KEY_L,
    m = ray.KEY_M,
    n = ray.KEY_N,
    o = ray.KEY_O,
    p = ray.KEY_P,
    q = ray.KEY_Q,
    r = ray.KEY_R,
    s = ray.KEY_S,
    t = ray.KEY_T,
    u = ray.KEY_U,
    v = ray.KEY_V,
    w = ray.KEY_W,
    x = ray.KEY_X,
    y = ray.KEY_Y,
    z = ray.KEY_Z,
    n0 = ray.KEY_ZERO,
    n1 = ray.KEY_ONE,
    n2 = ray.KEY_TWO,
    n3 = ray.KEY_THREE,
    n4 = ray.KEY_FOUR,
    n5 = ray.KEY_FIVE,
    n6 = ray.KEY_SIX,
    n7 = ray.KEY_SEVEN,
    n8 = ray.KEY_EIGHT,
    n9 = ray.KEY_NINE,
    n00 = ray.KEY_KP_0,
    n11 = ray.KEY_KP_1,
    n22 = ray.KEY_KP_2,
    n33 = ray.KEY_KP_3,
    n44 = ray.KEY_KP_4,
    n55 = ray.KEY_KP_5,
    n66 = ray.KEY_KP_6,
    n77 = ray.KEY_KP_7,
    n88 = ray.KEY_KP_8,
    n99 = ray.KEY_KP_9,
    f1 = ray.KEY_F1,
    f2 = ray.KEY_F2,
    f3 = ray.KEY_F3,
    f4 = ray.KEY_F4,
    f5 = ray.KEY_F5,
    f6 = ray.KEY_F6,
    f7 = ray.KEY_F7,
    f8 = ray.KEY_F8,
    f9 = ray.KEY_F9,
    f10 = ray.KEY_F10,
    f11 = ray.KEY_F11,
    f12 = ray.KEY_F12,
    left = ray.KEY_LEFT,
    right = ray.KEY_RIGHT,
    up = ray.KEY_UP,
    down = ray.KEY_DOWN,
    esc = ray.KEY_ESCAPE,
    enter = ray.KEY_ENTER,
    tab = ray.KEY_TAB,
    space = ray.KEY_SPACE,
    backspace = ray.KEY_BACKSPACE,
    shift = ray.KEY_LEFT_SHIFT,
    ctrl = ray.KEY_LEFT_CONTROL,
    alt = ray.KEY_LEFT_ALT,
    win = ray.KEY_LEFT_SUPER,
}

enum Mouse {
    left = ray.MOUSE_BUTTON_LEFT,
    right = ray.MOUSE_BUTTON_RIGHT,
    middle = ray.MOUSE_BUTTON_MIDDLE,
}

enum Gamepad {
    left = ray.GAMEPAD_BUTTON_LEFT_FACE_LEFT,
    right = ray.GAMEPAD_BUTTON_LEFT_FACE_RIGHT,
    up = ray.GAMEPAD_BUTTON_LEFT_FACE_UP,
    down = ray.GAMEPAD_BUTTON_LEFT_FACE_DOWN,
    y = ray.GAMEPAD_BUTTON_RIGHT_FACE_UP,
    x = ray.GAMEPAD_BUTTON_RIGHT_FACE_RIGHT,
    a = ray.GAMEPAD_BUTTON_RIGHT_FACE_DOWN,
    b = ray.GAMEPAD_BUTTON_RIGHT_FACE_LEFT,
    lb = ray.GAMEPAD_BUTTON_LEFT_TRIGGER_1,
    lt = ray.GAMEPAD_BUTTON_LEFT_TRIGGER_2,
    lsb = ray.GAMEPAD_BUTTON_LEFT_THUMB,
    rb = ray.GAMEPAD_BUTTON_RIGHT_TRIGGER_1,
    rt = ray.GAMEPAD_BUTTON_RIGHT_TRIGGER_2,
    rsb = ray.GAMEPAD_BUTTON_RIGHT_THUMB,
    back = ray.GAMEPAD_BUTTON_MIDDLE_LEFT,
    start = ray.GAMEPAD_BUTTON_MIDDLE_RIGHT,
    center = ray.GAMEPAD_BUTTON_MIDDLE,
}

Color toPopka(ray.Color from) {
    return Color(from.r, from.g, from.b, from.a);
}

Vec2 toPopka(ray.Vector2 from) {
    return Vec2(from.x, from.y);
}

Vec3 toPopka(ray.Vector3 from) {
    return Vec3(from.x, from.y, from.z);
}

Vec4 toPopka(ray.Vector4 from) {
    return Vec4(from.x, from.y, from.z, from.w);
}

Rect toPopka(ray.Rectangle from) {
    return Rect(from.x, from.y, from.width, from.height);
}

Sprite toPopka(ray.Texture2D from) {
    Sprite result;
    result.data = from;
    return result;
}

Font toPopka(ray.Font from) {
    Font result;
    result.data = from;
    return result;
}

View toPopka(ray.RenderTexture2D from) {
    View result;
    result.data = from;
    return result;
}

Camera toPopka(ray.Camera2D from) {
    Camera result;
    result.position = toPopka(from.target);
    result.rotation = from.rotation;
    result.scale = from.zoom;
    return result;
}

ray.Color toRay(Color from) {
    return ray.Color(from.r, from.g, from.b, from.a);
}

ray.Vector2 toRay(Vec2 from) {
    return ray.Vector2(from.x, from.y);
}

ray.Vector3 toRay(Vec3 from) {
    return ray.Vector3(from.x, from.y, from.z);
}

ray.Vector4 toRay(Vec4 from) {
    return ray.Vector4(from.x, from.y, from.z, from.w);
}

ray.Rectangle toRay(Rect from) {
    return ray.Rectangle(from.position.x, from.position.y, from.size.x, from.size.y);
}

ray.Texture2D toRay(Sprite from) {
    return from.data;
}

ray.Font toRay(Font from) {
    return from.data;
}

ray.RenderTexture2D toRay(View from) {
    return from.data;
}

ray.Camera2D toRay(Camera from) {
    return ray.Camera2D(toRay(from.origin), toRay(from.position), from.rotation, from.scale);
}

int randi() {
    return ray.GetRandomValue(0, int.max);
}

float randf() {
    return ray.GetRandomValue(0, cast(int) float.max) / cast(float) cast(int) float.max;
}

void randomize(uint seed) {
    ray.SetRandomSeed(seed);
}

void randomize() {
    randomize(randi);
}

void openWindow(float width, float height, const(char)[] title = "Popka", Color color = defaultBackgroundColor) {
    if (popkaState.isWindowOpen) {
        return;
    }
    ray.SetConfigFlags(ray.FLAG_VSYNC_HINT | ray.FLAG_WINDOW_RESIZABLE);
    ray.SetTraceLogLevel(ray.LOG_ERROR);
    ray.InitWindow(cast(int) width, cast(int) height, toStrz(title));
    ray.SetWindowMinSize(cast(int) (width * 0.25f), cast(int) (height * 0.25f));
    ray.SetExitKey(ray.KEY_NULL);
    lockFPS(defaultFPS);
    popkaState.isWindowOpen = true;
    popkaState.backgroundColor = color;
    popkaState.lastWindowSize = Vec2(width, height);
    popkaState.debugFont = popkaFont;
    popkaState.debugFontOptions.color = defaultDebugFontColor;
}

void closeWindow() {
    popkaState.isWindowOpen = false;
}

void freeWindow() {
    if (!popkaState.isWindowOpen) {
        return;
    }
    popkaState.view.free();
    ray.CloseWindow();
    popkaState = PopkaState();
    popkaPixeloidFont = Font();
}

bool isWindowOpen() {
    if (ray.WindowShouldClose() || !popkaState.isWindowOpen) {
        return false;
    }
    if (!popkaState.isDrawing) {
        if (isResolutionLocked) {
            ray.BeginTextureMode(popkaState.view.data);
        } else {
            ray.BeginDrawing();
        }
        ray.ClearBackground(toRay(popkaState.backgroundColor));
    } else {
        // End drawing.
        if (isResolutionLocked) {
            auto minSize = popkaState.view.size;
            auto maxSize = windowSize;
            auto ratio = maxSize / minSize;
            auto minRatio = min(ratio.x, ratio.y);
            auto targetSize = minSize * Vec2(minRatio);
            auto targetPos = maxSize * Vec2(0.5f) - targetSize * Vec2(0.5f);
            ray.EndTextureMode();
            ray.BeginDrawing();
            ray.ClearBackground(ray.BLACK);
            ray.DrawTexturePro(
                popkaState.view.data.texture,
                ray.Rectangle(0.0f, 0.0f, minSize.x, -minSize.y),
                ray.Rectangle(
                    ratio.x == minRatio ? targetPos.x : floor(targetPos.x),
                    ratio.y == minRatio ? targetPos.y : floor(targetPos.y),
                    ratio.x == minRatio ? targetSize.x : floor(targetSize.x),
                    ratio.y == minRatio ? targetSize.y : floor(targetSize.y),
                ),
                ray.Vector2(0.0f, 0.0f),
                0.0f,
                ray.WHITE,
            );
            ray.EndDrawing();
        } else {
            ray.EndDrawing();
        }
        // The lockResolution and unlockResolution queue.
        if (popkaState.isLockResolutionQueued) {
            popkaState.view.load(popkaState.targetViewSize);
            popkaState.isLockResolutionQueued = false;
        }
        if (popkaState.isUnlockResolutionQueued) {
            popkaState.view.free();
            popkaState.isUnlockResolutionQueued = false;
        }
        // Fullscreen code to fix a bug on KDE.
        if (popkaState.isToggleFullscreenQueued) {
            popkaState.toggleFullscreenTimer += deltaTime;
            if (popkaState.toggleFullscreenTimer >= toggleFullscreenWaitTime) {
                popkaState.toggleFullscreenTimer = 0.0f;
                auto screen = screenSize;
                auto window = popkaState.lastWindowSize;
                if (ray.IsWindowFullscreen()) {
                    ray.ToggleFullscreen();
                    ray.SetWindowSize(cast(int) window.x, cast(int) window.y);
                    ray.SetWindowPosition(cast(int) (screen.x * 0.5f - window.x * 0.5f), cast(int) (screen.y * 0.5f - window.y * 0.5f));
                } else {
                    ray.ToggleFullscreen();
                }
                popkaState.isToggleFullscreenQueued = false;
            }
        }
        // Begin drawing.
        if (isResolutionLocked) {
            ray.BeginTextureMode(popkaState.view.data);
        } else {
            ray.BeginDrawing();
        }
        ray.ClearBackground(toRay(popkaState.backgroundColor));
    }
    popkaState.isDrawing = true;
    return true;
}

bool isFPSLocked() {
    return popkaState.isFPSLocked;
}

void lockFPS(uint target) {
    ray.SetTargetFPS(target);
    popkaState.isFPSLocked = true;
}

void unlockFPS() {
    ray.SetTargetFPS(0);
    popkaState.isFPSLocked = false;
}

bool isResolutionLocked() {
    return !popkaState.view.isEmpty;
}

void lockResolution(Vec2 size) {
    if (popkaState.isWindowOpen && !popkaState.isDrawing) {
        popkaState.view.load(size);
    } else {
        popkaState.targetViewSize = size;
        popkaState.isLockResolutionQueued = true;
        popkaState.isUnlockResolutionQueued = false;
    }
}

void lockResolution(float width, float height) {
    lockResolution(Vec2(width, height));
}

void unlockResolution() {
    if (popkaState.isWindowOpen && !popkaState.isDrawing) {
        popkaState.view.free();
    } else {
        popkaState.isUnlockResolutionQueued = true;
        popkaState.isLockResolutionQueued = false;
    }
}

bool isFullscreen() {
    return ray.IsWindowFullscreen;
}

void toggleFullscreen() {
    if (!ray.IsWindowFullscreen()) {
        auto screen = screenSize;
        popkaState.lastWindowSize = windowSize;
        ray.SetWindowPosition(0, 0);
        ray.SetWindowSize(cast(int) screen.x, cast(int) screen.y);
    }
    popkaState.isToggleFullscreenQueued = true;
}

bool isCursorHidden() {
    return popkaState.isCursorHidden;
}

void hideCursor() {
    ray.HideCursor();
    popkaState.isCursorHidden = true;
}

void showCursor() {
    ray.ShowCursor();
    popkaState.isCursorHidden = false;
}

Vec2 screenSize() {
    auto id = ray.GetCurrentMonitor();
    return Vec2(ray.GetMonitorWidth(id), ray.GetMonitorHeight(id));
}

Vec2 windowSize() {
    if (isFullscreen) {
        return screenSize;
    } else {
        return Vec2(ray.GetScreenWidth(), ray.GetScreenHeight());
    }
}

Vec2 resolution() {
    if (isResolutionLocked) {
        return popkaState.view.size;
    } else {
        return windowSize;
    }
}

Vec2 mouse() {
    if (isResolutionLocked) {
        auto window = windowSize;
        auto minRatio = min(window.x / popkaState.view.size.x, window.y / popkaState.view.size.y);
        auto targetSize = popkaState.view.size * Vec2(minRatio);
        return Vec2(
            (ray.GetMouseX() - (window.x - targetSize.x) * 0.5f) / minRatio,
            (ray.GetMouseY() - (window.y - targetSize.y) * 0.5f) / minRatio,
        );
    } else {
        return Vec2(ray.GetMouseX(), ray.GetMouseY());
    }
}

float mouseWheel() {
    return ray.GetMouseWheelMove();
}

int fps() {
    return ray.GetFPS();
}

float deltaTime() {
    return ray.GetFrameTime();
}

Vec2 deltaMouse() {
    return toPopka(ray.GetMouseDelta());
}

Font popkaFont() {
    if (popkaPixeloidFont.isEmpty) {
        popkaPixeloidFont = loadPixeloidFont();
    }
    return popkaPixeloidFont;
}

Font rayFont() {
    auto result = toPopka(ray.GetFontDefault());
    result.spacing = Vec2(1.0f, 14.0f);
    return result;
}

bool isPressed(char key) {
    return ray.IsKeyPressed(toUpper(key));
}

bool isPressed(Keyboard key) {
    return ray.IsKeyPressed(key);
}

bool isPressed(Mouse key) {
    return ray.IsMouseButtonPressed(key);
}

bool isPressed(Gamepad key, uint id = 0) {
    return ray.IsGamepadButtonPressed(id, key);
}

bool isDown(char key) {
    return ray.IsKeyDown(toUpper(key));
}

bool isDown(Keyboard key) {
    return ray.IsKeyDown(key);
}

bool isDown(Mouse key) {
    return ray.IsMouseButtonDown(key);
}

bool isDown(Gamepad key, uint id = 0) {
    return ray.IsGamepadButtonDown(id, key);
}

bool isReleased(char key) {
    return ray.IsKeyReleased(toUpper(key));
}

bool isReleased(Keyboard key) {
    return ray.IsKeyReleased(key);
}

bool isReleased(Mouse key) {
    return ray.IsMouseButtonReleased(key);
}

bool isReleased(Gamepad key, uint id = 0) {
    return ray.IsGamepadButtonReleased(id, key);
}

void drawRect(Rect rect, Color color = white) {
    ray.DrawRectanglePro(toRay(rect.floor()), ray.Vector2(0.0f, 0.0f), 0.0f, toRay(color));
}

void drawSprite(Sprite sprite, Rect region, Vec2 position, DrawOptions options = DrawOptions()) {
    if (sprite.isEmpty) {
        return;
    }
    final switch (options.filter) {
        case Filter.nearest: ray.SetTextureFilter(sprite.data, ray.TEXTURE_FILTER_POINT); break;
        case Filter.linear: ray.SetTextureFilter(sprite.data, ray.TEXTURE_FILTER_BILINEAR); break;
    }
    Rect target, source;
    if (region.size.x <= 0.0f || region.size.y <= 0.0f) {
        target = Rect(position, sprite.size * options.scale);
        source = Rect(sprite.size);
    } else {
        target = Rect(position, region.size * options.scale);
        source = region;
    }
    final switch (options.flip) {
        case Flip.none: break;
        case Flip.x: source.size.x *= -1.0f; break;
        case Flip.y: source.size.y *= -1.0f; break;
        case Flip.xy: source.size *= Vec2(-1.0f); break;
    }
    ray.DrawTexturePro(
        sprite.data,
        toRay(source.floor()),
        toRay(target.floor()),
        toRay(target.floor().origin(options.hook).floor()),
        options.rotation,
        toRay(options.color),
    );
}

// TODO: Think about when to use ints and when to use floats or vectors.
// NOTE: For now it will be a vector because I am making a game lol.
void drawTile(Sprite sprite, Vec2 tileSize, uint tileID, Vec2 position, DrawOptions options = DrawOptions()) {
    auto gridWidth = cast(uint) (sprite.size.x / tileSize.x);
    auto gridHeight = cast(uint) (sprite.size.y / tileSize.y);
    if (gridWidth == 0 || gridHeight == 0) {
        return;
    }
    auto row = tileID / gridWidth;
    auto col = tileID % gridWidth;
    auto region = Rect(col * tileSize.x, row * tileSize.y, tileSize.x, tileSize.y);
    drawSprite(sprite, region, position, options);
}

void drawTileMap(Sprite sprite, TileMap map, Camera camera, Vec2 position, DrawOptions options = DrawOptions()) {
    auto topLeft = camera.point(Hook.topLeft);
    auto bottomRight = camera.point(Hook.bottomRight);
    size_t col1, col2, row1, row2;
    if (camera.isAttached) {
        col1 = cast(size_t) floor(clamp((topLeft.x - position.x) / map.cellWidth - 4.0f, 0, map.colCount));
        col2 = cast(size_t) floor(clamp((bottomRight.x - position.x) / map.cellWidth + 4.0f, 0, map.colCount));
        row1 = cast(size_t) floor(clamp((topLeft.y - position.y) / map.cellHeight - 4.0f, 0, map.rowCount));
        row2 = cast(size_t) floor(clamp((bottomRight.y - position.y) / map.cellHeight + 4.0f, 0, map.rowCount));
    } else {
        col1 = 0;
        col2 = map.colCount;
        row1 = 0;
        row2 = map.rowCount;
    }
    foreach (row; row1 .. row2) {
        foreach (col; col1 .. col2) {
            if (map[row, col] == -1) {
                continue;
            }
            drawTile(sprite, map.cellSize, map[row, col], position + Vec2(col, row) * map.cellSize, options);
        }
    }
}

@trusted
Vec2 measureText(Font font, const(char)[] text, Vec2 scale = Vec2(1.0f)) {
    if (font.isEmpty || text.length == 0) {
        return Vec2();
    }
    auto result = Vec2();
    auto tempByteCounter = 0; // Used to count longer text line num chars.
    auto byteCounter = 0;
    auto textWidth = 0.0f;
    auto tempTextWidth = 0.0f; // Used to count longer text line width.
    auto textHeight = font.size;

    auto letter = 0; // Current character.
    auto index = 0; // Index position in sprite font.
    auto i = 0;
    while (i < text.length) {
        byteCounter += 1;

        auto next = 0;
        letter = ray.GetCodepointNext(&text[i], &next);
        index = ray.GetGlyphIndex(font.data, letter);
        i += next;
        if (letter != '\n') {
            if (font.data.glyphs[index].advanceX != 0) {
                textWidth += font.data.glyphs[index].advanceX;
            } else {
                textWidth += font.data.recs[index].width + font.data.glyphs[index].offsetX;
            }
        } else {
            if (tempTextWidth < textWidth) {
                tempTextWidth = textWidth;
            }
            byteCounter = 0;
            textWidth = 0;
            textHeight += font.spacing.y;
        }
        if (tempByteCounter < byteCounter) {
            tempByteCounter = byteCounter;
        }
    }
    if (tempTextWidth < textWidth) {
        tempTextWidth = textWidth;
    }
    result.x = floor(tempTextWidth * scale.x + ((tempByteCounter - 1) * font.spacing.x * scale.x));
    result.y = floor(textHeight * scale.y);
    return result;
}

void drawRune(Font font, dchar rune, Vec2 position, DrawOptions options = DrawOptions()) {
    if (font.isEmpty) {
        return;
    }
    final switch (options.filter) {
        case Filter.nearest: ray.SetTextureFilter(font.data.texture, ray.TEXTURE_FILTER_POINT); break;
        case Filter.linear: ray.SetTextureFilter(font.data.texture, ray.TEXTURE_FILTER_BILINEAR); break;
    }
    auto rect = toPopka(ray.GetGlyphAtlasRec(font.data, rune)).floor();
    auto origin = rect.origin(options.hook).floor();
    raygl.rlPushMatrix();
    raygl.rlTranslatef(floor(position.x), floor(position.y), 0.0f);
    raygl.rlRotatef(options.rotation, 0.0f, 0.0f, 1.0f);
    raygl.rlScalef(options.scale.x, options.scale.y, 1.0f);
    raygl.rlTranslatef(-origin.x, -origin.y, 0.0f);
    ray.DrawTextCodepoint(font.data, rune, ray.Vector2(0.0f, 0.0f), font.size, toRay(options.color));
    raygl.rlPopMatrix();
}

@trusted
void drawText(Font font, const(char)[] text, Vec2 position, DrawOptions options = DrawOptions()) {
    if (font.isEmpty || text.length == 0) {
        return;
    }
    auto rect = Rect(measureText(font, text)).floor();
    auto origin = rect.origin(options.hook).floor();
    raygl.rlPushMatrix();
    raygl.rlTranslatef(floor(position.x), floor(position.y), 0.0f);
    raygl.rlRotatef(options.rotation, 0.0f, 0.0f, 1.0f);
    raygl.rlScalef(options.scale.x, options.scale.y, 1.0f);
    raygl.rlTranslatef(-origin.x, -origin.y, 0.0f);
    auto textOffsetY = 0.0f; // Offset between lines (on linebreak '\n').
    auto textOffsetX = 0.0f; // Offset X to next character to draw.
    auto i = 0;
    while (i < text.length) {
        // Get next codepoint from byte string and glyph index in font.
        auto codepointByteCount = 0;
        auto codepoint = ray.GetCodepointNext(&text[i], &codepointByteCount);
        auto index = ray.GetGlyphIndex(font.data, codepoint);
        if (codepoint == '\n') {
            textOffsetY += font.spacing.y;
            textOffsetX = 0.0f;
        } else {
            if (codepoint != ' ' && codepoint != '\t') {
                auto runeOptions = DrawOptions();
                runeOptions.color = options.color;
                runeOptions.filter = options.filter;
                drawRune(font, codepoint, Vec2(textOffsetX, textOffsetY), runeOptions);
            }
            if (font.data.glyphs[index].advanceX == 0) {
                textOffsetX += font.data.recs[index].width + font.spacing.x;
            } else {
                textOffsetX += font.data.glyphs[index].advanceX + font.spacing.x;
            }
        }
        // Move text bytes counter to next codepoint.
        i += codepointByteCount;
    }
    raygl.rlPopMatrix();
}

void drawDebugText(const(char)[] text, Vec2 position = Vec2(8.0f)) {
    drawText(popkaState.debugFont, text, position, popkaState.debugFontOptions);
}
