static void
enqueuerotate(Client *c)
{
	Client *l;
	for (l = c->mon->clients; l && l->next; l = l->next);
	if (l) {
		l->next = c;
		c->next = NULL;
	}
}

static void
enqueuestackrotate(Client *c)
{
	Client *l;
	for (l = c->mon->stack; l && l->snext; l = l->snext);
	if (l) {
		l->snext = c;
		c->snext = NULL;
	}
}

void
rotatestack(const Arg *arg)
{
	Client *c = NULL, *f;

	if (!selmon->sel)
		return;
	f = selmon->sel;
	if (arg->i > 0) {
		/* rotate down: bring last tiled client to the front */
		for (c = nexttiled(selmon->clients); c && nexttiled(c->next); c = nexttiled(c->next));
		if (c) {
			detach(c);
			attach(c);
			detachstack(c);
			attachstack(c);
		}
	} else {
		/* rotate up: send first tiled client to the end */
		if ((c = nexttiled(selmon->clients))) {
			detach(c);
			enqueuerotate(c);
			detachstack(c);
			enqueuestackrotate(c);
		}
	}
	if (c) {
		arrange(selmon);
		focus(f);
		restack(selmon);
	}
}
