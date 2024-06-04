module metamor.config;

import popka;

enum runeTime = 0.03f;
enum frameTime = 0.12f;

enum transitionSpeed = 1.0f;
enum transitionRectWidth = 10;
enum transitionRectHeight = 10;

enum maxBackgroundOffsetX = 52.0f;
enum maxActorOffsetX = 82.0f;
enum offsetSlowdown = 0.12f;

enum optionRectOffset = 25.0f;
enum optionRectHeight = 16.0f;
enum optionRectExtraWidth = 20.0f;
enum optionDelayTime = 0.5f;

enum actorSize = Vec2(70.0f, 140.0f);
enum cursorSize = Vec2(7.0f, 7.0f);
enum backgroundSize = Vec2(320.0f, 180.0f);

enum textColor = Color(0x85, 0x95, 0xa1);
enum worldColor = Color(0x14, 0x0c, 0x1c);
enum gameColor = Color(0x44, 0x24, 0x34);

enum pixeloidFontRunes = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~äöÜßΑαΒβΓγΔδΕεΖζΗηΘθΙιΚκΛλΜμΝνΞξΟοΠπΡρΣσςΤτΥυΦφΧχΨψΩωʹ͵ͺ;΄΅·ΆΈΉΊΌΎΏΐΪΫάέήίΰϊϋόύώϔ";
enum pixeloadFontSpacing = Vec2(1.0f, 14.0f);
