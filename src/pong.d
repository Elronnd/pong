import assetlib;
import graphics;

import std.random: uniform;
import core.thread: Thread;
import core.time: dur;
import std.datetime: StopWatch;


template mmap(alias fun) {
	void mmap(T...)(T list) {
		foreach (item; list) {
			fun(item);
		}
	}
}


enum WIDTH = 640;
enum HEIGHT = 480;

enum PALLETTE_SPEED = 70; // px/s
enum INIT_BALL_SPEED = 55;

enum FPS = 1.0 / 30.0;

enum PAD_DISTFROMEDGE = 15; // distance, in pixels, that the palletes have from the edge

struct Direction {
	float x, y;
}


class Pong {
	uint ball_speed;
	Sprite lpal, rpal, ball, center;

       	Direction ball_dir; // direction can be -1 for left/up, +1 for down/right, 0 for nothing.  But it's a float so the multiplier can be changed

	bool lpal_up, lpal_down; // is the button to move the left pallette up/down held right now?
	bool rpal_up, rpal_down;

	uint right_wins, left_wins;

	this() {
		center.load("assets/sep.png");
		ball.load("assets/ball.png");
		lpal.load("assets/pallette.png");
		rpal.load("assets/pallette.png");

		initshit();
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
	}

	void run() {
		ulong delta;

		auto sw = StopWatch();
		sw.start();

		while (true) {
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
				ball_dir.x = -ball_dir.x;
				ball_dir.y = uniform(-1.0, 1.0);
				ball_speed *= 1.1;
			// we went off the edge of the screen
			} else if ((ball_potential.x < 0) || ((ball_potential.x + ball_potential.getrect().w) >= WIDTH)) {
				if (ball_potential.x < 0) {
					right_wins++;
				} else if (ball_potential.x > WIDTH) {
					left_wins++;
				}

				initshit();
				continue;
			} else {
				ball = ball_potential;
			}

			Thread.sleep(dur!"msecs"(cast(uint)((FPS * 1000) - delta)));

			draw();
		}
	}


	void draw() {
		Graphics.clear();
		mmap!(Graphics.placesprite)(lpal, rpal, ball, center);
		Graphics.blit();
	}
}
