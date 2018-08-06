import std.stdio;
import graphics;
import pong;

void main() {
	GraphicsPrefs prefs;
	prefs.winwidth = WIDTH;
	prefs.winheight = HEIGHT;
	prefs.borderless = false;
	prefs.use_vsync = true;
	Graphics.init(prefs);


	new Pong().run();


	Graphics.end();
}
