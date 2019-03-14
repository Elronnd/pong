import assetlib;
import graphics;
import graphics.scancode;
import maybe;

import std.random: uniform;
import core.thread: Thread;
import core.time: dur;
import std.datetime.stopwatch: StopWatch;
import std.algorithm.iteration: map;

import std.stdio: writefln;

enum Sfx {
	bounce,
	win,
	lose,
}


// because stdlib map is retarted
template mmap(alias fun) {
	void mmap(T...)(T list) {
		foreach (item; list) {
			fun(item);
		}
	}
}


enum up_key = Key.up, down_key = Key.down;
enum quit_key = Key.q;


enum WIDTH = 640;
enum HEIGHT = 480;

enum INIT_PALLETTE_SPEED = 200; // px/s
enum INIT_BALL_SPEED = 200;

enum FPS = 1.0 / 60.0;

enum PAD_DISTFROMEDGE = 15; // distance, in pixels, that the palletes have from the edge
enum TEXT_OFFSET = 5;

struct Direction {
	float x, y;
}


Colour randclr() {
	return Colour(uniform!ubyte(), uniform!ubyte(), uniform!ubyte());
}

Colour tweenclr(in Colour curr, in Colour target = Colour(0, 0, 0)) {
	import std.math: abs;

	with(curr) return Colour(cast(ubyte)(r + (target.r-r)/50), cast(ubyte)(g + (target.g-g)/50), cast(ubyte)(b + (target.b-b)/50));
}
Colour darkenclr(in Colour curr, ubyte denom = 100) {
	with (curr) return Colour(cast(ubyte)(r/denom), cast(ubyte)(g/denom), cast(ubyte)(b/denom));
}

Colour oppositeclr(in Colour curr) {
	with (curr) return Colour(255-r, 255-g, 255-b);
}


class Pong {
	uint ball_speed, lpal_speed, rpal_speed;
	Sprite lpal, rpal, ball, center;
	Sprite lscore, rscore;
	Colour ball_clr, lpal_clr, rpal_clr, bg, targetbg, sep;

	Direction ball_dir; // direction can be -1 for left/up, +1 for down/right, 0 for nothing.  But it's a float so the multiplier can be changed

	bool lpal_up, lpal_down; // is the button to move the left pallette up/down held right now?
	bool rpal_up, rpal_down;

	uint right_wins, left_wins;

	this() {
		center.load("assets/sep.png");
		ball.load("assets/ball.png");
		lpal.load("assets/pallette.png");
		rpal.load("assets/pallette.png");
		Graphics.regsfx("blip.wav", Sfx.bounce);
		Graphics.regsfx("winup.wav", Sfx.win);
		Graphics.regsfx("windown.wav", Sfx.lose);
		Graphics.loadfont("assets/DejaVuSans.ttf", 1, 24);

		update_scores();

		initshit();
	}

	void doai() {
		// get the center of the ball along the y
		uint bally = (cast(uint)ball.y + ball.getrect().h) / 2;

		// ditto for right pallette
		uint pallettey = (cast(uint)rpal.y + rpal.getrect().h) / 2;

		if (bally < pallettey) {
			rpal_up = true;
			rpal_down = false;
		} else {
			rpal_down = true;
			rpal_up = false;
		}
	}



	void update_scores() {
		import std.conv: to;

		Graphics.rendertext(lscore, to!string(left_wins), 1);
		lscore.x = lscore.y = TEXT_OFFSET;

		Graphics.rendertext(rscore, to!string(right_wins), 1);
		rscore.y = TEXT_OFFSET;
		rscore.x = WIDTH - rscore.getrect().w - TEXT_OFFSET;
	}

	void initshit() {
		center.y = 0;
		center.x = WIDTH / 2;

		lpal.x = PAD_DISTFROMEDGE;
		lpal.y = HEIGHT / 2;

		rpal.x = WIDTH - PAD_DISTFROMEDGE - rpal.getrect().w;
		rpal.y = HEIGHT / 2;

		bool starting_going_right = uniform(0, 2) ? true : false;

		ball_dir = Direction(starting_going_right ? 1 : -1, 0); // -1/1: sometimes starts out moving right, sometimes left
		ball.x = WIDTH / 2;
		ball.y = HEIGHT / 2;

		ball_speed = INIT_BALL_SPEED;
		rpal_speed = lpal_speed = INIT_PALLETTE_SPEED;


		mmap!((x) => *x = randclr())(&lpal_clr, &rpal_clr);
		ball_clr = starting_going_right ? lpal_clr : rpal_clr;
		bg = Colour(0, 0, 0);
		sep = Colour(255, 255, 255);
	}

	void run() {
		ulong delta;
		ulong lag;

		auto sw = StopWatch();
		sw.start();

mainloop:	while (true) {
			delta = sw.peek().total!"msecs";
			sw.reset();


			Sprite ball_potential = ball;
			ball_potential.x += ball_speed * ball_dir.x * FPS;
			ball_potential.y += ball_speed * ball_dir.y * FPS;



			// bounce, if we hit the ceiling or the floor
			if ((ball_potential.y <= 0) || ((ball_potential.y + ball_potential.getrect().h) >= HEIGHT)) {
				ball_dir.y = -ball_dir.y;
			// if we hit a paddle, reverse x direction but random y direction and increase speed
			} else if ((ball_potential.getrect().collides(lpal.getrect())) || (ball_potential.getrect().collides(rpal.getrect()))) {
				Graphics.playsfx(Sfx.bounce);
				if (ball_potential.getrect().collides(lpal.getrect())) {
					lpal_speed = (lpal_speed*125)/100;
					ball_clr = lpal_clr;
					rpal_clr = randclr();
				} else {
					rpal_speed = (rpal_speed*125)/100;
					ball_clr = rpal_clr;
					lpal_clr = randclr();
				}

				bg = ball_clr;
				sep = oppositeclr(bg);
				targetbg = darkenclr(sep);

				ball_dir.x = -ball_dir.x;
				ball_dir.y = uniform(-1.0, 1.0);
				ball_speed = (ball_speed*11)/10;
			// we went off the edge of the screen
			} else if ((ball_potential.x < 0) || ((ball_potential.x + ball_potential.getrect().w) >= WIDTH)) {
				if (ball_potential.x < 0) {
					right_wins++;
					Graphics.playsfx(Sfx.lose);
				} else if ((ball_potential.x + ball_potential.getrect.w) >= WIDTH) {
					left_wins++;
					Graphics.playsfx(Sfx.win);
				}
				update_scores();

				initshit();
				continue;
			} else {
				ball = ball_potential;
			}

			if (bg != targetbg) {
				bg = tweenclr(bg, targetbg);
			} else {
				//sep = oppositeclr(bg);
			}

			Maybe!Event ev;

			while ((ev = Graphics.pollevent()).isset) {
				if (ev.key == up_key) {
					lpal_up = (ev.type == Evtype.Keydown) ? true :
						(ev.type == Evtype.Keyup) ? false : lpal_up;
				} else if (ev.key == down_key) {
					lpal_down = (ev.type == Evtype.Keydown) ? true :
						(ev.type == Evtype.Keyup) ? false : lpal_down;
				} else if (ev.key == quit_key) {
					break mainloop;
				}
			}

			doai();
			if (lpal_up) {
				if ((lpal.y - (lpal_speed * FPS)) >= 0) {
					lpal.y -= lpal_speed * FPS;
				}
			} else if (lpal_down) {
				if ((lpal.y + lpal.getrect().h + (lpal_speed * FPS)) <= HEIGHT) {
					lpal.y += lpal_speed * FPS;
				}
			}

			if (rpal_up) {
				if ((rpal.y - (rpal_speed * FPS)) >= 0) {
					rpal.y -= rpal_speed * FPS;
				}
			} else if (rpal_down) {
				if ((rpal.y + rpal.getrect().h + (rpal_speed * FPS)) <= HEIGHT) {
					rpal.y += rpal_speed * FPS;
				}
			}


			draw();

			int sleep = cast(int)((FPS * 1000) - delta);
			if (sleep < 0) {
				lag += -sleep;
			} else {
				// if we have enough lag to make up for a frame
				if (lag > (FPS * 1000)) {
					// don't sleep
					lag -= FPS * 1000;
					import std.stdio;
					writeln("LAG!");
				} else {
					Thread.sleep(dur!"msecs"(sleep));
				}
			}
		}
	}


	void draw() {
		Graphics.clear(bg);

		Graphics.placesprite(lpal, just(lpal_clr));
		Graphics.placesprite(lscore, just(lpal_clr));
		Graphics.placesprite(rpal, just(rpal_clr));
		Graphics.placesprite(rscore, just(rpal_clr));
		Graphics.placesprite(ball, just(ball_clr));
		Graphics.placesprite(center, just(sep));

		Graphics.blit();
	}
}
