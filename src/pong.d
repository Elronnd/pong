import assetlib;
import graphics;
import graphics.scancode;
import maybe;

import std.random: uniform;
import core.thread: Thread;
import core.time: dur;
import std.datetime: StopWatch;
import std.algorithm.iteration: map;

import std.stdio: writefln;


// because stdlib map is retarted
template mmap(alias fun) {
	void mmap(T...)(T list) {
		foreach (item; list) {
			fun(item);
		}
	}
}


enum lup_key = Key.a, ldown_key = Key.z, rup_key = Key.up, rdown_key = Key.down;
enum quit_key = Key.q;


enum WIDTH = 640;
enum HEIGHT = 480;

enum PALLETTE_SPEED = 100; // px/s
enum INIT_BALL_SPEED = 75;

enum FPS = 1.0 / 30.0;

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
	uint ball_speed;
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
		Graphics.loadfont("assets/DejaVuSans.ttf", 1, 24);

		update_scores();

		initshit();
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

		ball_dir = Direction(uniform(0, 2) ? -1 : 1, 0); // -1/1: sometimes starts out moving right, sometimes left
		ball.x = WIDTH / 2;
		ball.y = HEIGHT / 2;

		ball_speed = INIT_BALL_SPEED;


		mmap!((x) => *x = randclr())(&ball_clr, &lpal_clr, &rpal_clr);
		bg = Colour(0, 0, 0);
		sep = Colour(255, 255, 255);
	}

	void run() {
		ulong delta;

		auto sw = StopWatch();
		sw.start();

mainloop:	while (true) {
			delta = sw.peek().msecs;
			sw.reset();


			Sprite ball_potential = ball;
			ball_potential.x += ball_speed * ball_dir.x * FPS;
			ball_potential.y += ball_speed * ball_dir.y * FPS;



			// bounce, if we hit the ceiling or the floor
			if ((ball_potential.y <= 0) || ((ball_potential.y + ball_potential.getrect().h) >= HEIGHT)) {
				ball_dir.y = -ball_dir.y;
			// if we hit a paddle, reverse x direction but random y direction and increase speed
			} else if ((ball_potential.getrect().collides(lpal.getrect())) || (ball_potential.getrect().collides(rpal.getrect()))) {
				if (ball_potential.getrect().collides(lpal.getrect())) {
					ball_clr = lpal_clr;
					rpal_clr = randclr();
				} else {
					ball_clr = rpal_clr;
					lpal_clr = randclr();
				}

				bg = ball_clr;
				sep = oppositeclr(bg);
				targetbg = darkenclr(sep);

				ball_dir.x = -ball_dir.x;
				ball_dir.y = uniform(-1.0, 1.0);
				ball_speed *= 1.1;
				// we went off the edge of the screen
			} else if ((ball_potential.x < 0) || ((ball_potential.x + ball_potential.getrect().w) >= WIDTH)) {
				if (ball_potential.x < 0) {
					right_wins++;
				} else if ((ball_potential.x + ball_potential.getrect.w) >= WIDTH) {
					left_wins++;
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
				if (ev.key == lup_key) {
					lpal_up = (ev.type == Evtype.Keydown) ? true :
						(ev.type == Evtype.Keyup) ? false : lpal_up;
				} else if (ev.key == ldown_key) {
					lpal_down = (ev.type == Evtype.Keydown) ? true :
						(ev.type == Evtype.Keyup) ? false : lpal_down;
				} else if (ev.key == rup_key) {
					rpal_up = (ev.type == Evtype.Keydown) ? true :
						(ev.type == Evtype.Keyup) ? false : rpal_up;
				} else if (ev.key == rdown_key) {
					rpal_down = (ev.type == Evtype.Keydown) ? true :
						(ev.type == Evtype.Keyup) ? false : rpal_down;
				} else if (ev.key == quit_key) {
					break mainloop;
				}
			}

			if (lpal_up) {
				if ((lpal.y - (PALLETTE_SPEED * FPS)) >= 0) {
					lpal.y -= PALLETTE_SPEED * FPS;
				}
			} else if (lpal_down) {
				if ((lpal.y + lpal.getrect().h + (PALLETTE_SPEED * FPS)) <= HEIGHT) {
					lpal.y += PALLETTE_SPEED * FPS;
				}
			}

			if (rpal_up) {
				if ((rpal.y - (PALLETTE_SPEED * FPS)) >= 0) {
					rpal.y -= PALLETTE_SPEED * FPS;
				}
			} else if (rpal_down) {
				if ((rpal.y + rpal.getrect().h + (PALLETTE_SPEED * FPS)) <= HEIGHT) {
					rpal.y += PALLETTE_SPEED * FPS;
				}
			}


			draw();

			int sleep = cast(int)((FPS * 1000) - delta);
			if (sleep < 0) {
				writefln("Error, we have lag!  Trying to sleep for %s seconds!  (Our delta is %s)", sleep, delta);
			} else {
				Thread.sleep(dur!"msecs"(sleep));
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
