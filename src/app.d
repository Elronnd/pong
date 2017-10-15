import std.stdio;
import graphics;
import pong;

void main() {
	GraphicsPrefs prefs;
	prefs.winwidth = WIDTH;
	prefs.winheight = HEIGHT;
	Graphics.init(prefs);


	new Pong().run();


	Graphics.end();
}
