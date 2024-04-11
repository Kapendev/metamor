module noveldev.globals;

import popka.basic;
import noveldev.app;

Game game;
ubyte[ActorID.max + 1] actorTileIDs;
Color[ActorID.max + 1] actorColors;
List!char[BackgroundID.max + 1] backgroundPaths;
ubyte[BackgroundID.max + 1] backgroundFrameCounts;
