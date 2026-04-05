void
opacity(Client *c, double opacity)
{
	if (opacity > 0 && opacity <= 1.0) {
		unsigned long real_opacity[] = { opacity * 0xffffffff };
		XChangeProperty(dpy, c->win, netatom[NetWMWindowOpacity], XA_CARDINAL,
				32, PropModeReplace, (unsigned char *)real_opacity, 1);
	} else {
		XDeleteProperty(dpy, c->win, netatom[NetWMWindowOpacity]);
	}
}

void
changeopacity(const Arg *arg)
{
	Client *c = selmon->sel;
	if (!c)
		return;

	if (arg->f > 1.0)
		c->opacity = arg->f - 1.0;
	else
		c->opacity += (c->opacity == 0 ? 1.0 + arg->f : arg->f);

	if (c->opacity > 1.0)
		c->opacity = 1.0;
	if (c->opacity < 0.0)
		c->opacity = 0.0;

	opacity(c, c->opacity);
}
