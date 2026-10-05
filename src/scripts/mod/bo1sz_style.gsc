// bo1-style-zombies: style meter.
// Milestone 2, step 1: HUD, gauge, rank up/down, decay, and fake input only.
// Real style events (kills, headshots, ...) arrive in step 2.
//
// Other modules add style by appending to the player's queue (no cross-file calls):
//   p.bo1sz_style_q_pts[ p.bo1sz_style_q_pts.size ] = points;
//   p.bo1sz_style_q_tag[ p.bo1sz_style_q_tag.size ] = "tag";
//
// Dvars (console, before loading a map unless noted):
//   bo1sz_style 0        disable this module
//   bo1sz_style_fake 1   feed random fake style events (can be toggled in game)
//   bo1sz_style_add 1    add one 30-point fake event to every player (in game)
//
// Tunables: data/balance/style.csv and style_ranks.csv (generated into bo1sz_balance.gsc).

init()
{
	if ( getDvar( "zombiemode" ) != "1" && !( isDefined( level.is_zombie_level ) && level.is_zombie_level ) )
	{
		return;
	}
	if ( getDvar( "bo1sz_enable" ) == "0" || getDvar( "bo1sz_style" ) == "0" )
	{
		return;
	}
	// Precache must happen before the first wait of the level.
	PrecacheShader( "white" );
	level thread style_start();
}

style_start()
{
	t = 0;
	while ( !isDefined( level.bo1sz_bal ) && t < 100 )
	{
		wait 0.05;
		t++;
	}
	if ( !isDefined( level.bo1sz_bal ) )
	{
		style_log( "balance data missing (bo1sz_balance.gsc not loaded); style meter off" );
		return;
	}
	setDvar( "bo1sz_style_add", "0" );
	level thread style_debug_input();
	style_log( "style meter on, ranks=" + level.bo1sz_style_ranks_count );

	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		players[ i ] thread style_player();
	}
	for ( ;; )
	{
		level waittill( "connected", player );
		player thread style_player();
	}
}

style_bal( key )
{
	return level.bo1sz_bal[ "style." + key ];
}

style_log( msg )
{
	line = "[BO1SZ] style: " + msg;
	println( line );
	logprint( line + "\n" );
}

// ---------------------------------------------------------------------------
// Per-player state and update loop
// ---------------------------------------------------------------------------

style_player()
{
	self endon( "disconnect" );
	if ( isDefined( self.bo1sz_style_started ) )
	{
		return;
	}
	self.bo1sz_style_started = true;
	self waittill( "spawned_player" );

	self.bo1sz_style_q_pts = [];
	self.bo1sz_style_q_tag = [];
	self.bo1sz_style_rank = 0;
	self.bo1sz_style_gauge = 0;
	self.bo1sz_style_last_ms = 0;

	self style_hud_create();
	self style_hud_refresh();
	self thread style_tick();
}

style_tick()
{
	self endon( "disconnect" );
	gauge_max = style_bal( "gauge_max" );
	grace = style_bal( "idle_grace_ms" );
	top = level.bo1sz_style_ranks_count - 1;
	for ( ;; )
	{
		wait 0.1;
		changed = false;

		// Drain queued style events.
		pts = self.bo1sz_style_q_pts;
		if ( pts.size > 0 )
		{
			self.bo1sz_style_q_pts = [];
			self.bo1sz_style_q_tag = [];
			for ( i = 0; i < pts.size; i++ )
			{
				self style_gain( pts[ i ], gauge_max, top );
			}
			self.bo1sz_style_last_ms = getTime();
			changed = true;
		}

		// Decay when idle; empty gauge drops one rank.
		if ( getTime() - self.bo1sz_style_last_ms > grace && ( self.bo1sz_style_gauge > 0 || self.bo1sz_style_rank > 0 ) )
		{
			self.bo1sz_style_gauge -= level.bo1sz_style_ranks_decay_per_sec[ self.bo1sz_style_rank ] * 0.1;
			if ( self.bo1sz_style_gauge <= 0 )
			{
				if ( self.bo1sz_style_rank > 0 )
				{
					self.bo1sz_style_rank--;
					self.bo1sz_style_gauge = gauge_max * style_bal( "drop_refill" );
					self thread style_popup( false );
				}
				else
				{
					self.bo1sz_style_gauge = 0;
				}
			}
			changed = true;
		}

		if ( changed )
		{
			self style_hud_refresh();
		}
	}
}

style_gain( points, gauge_max, top )
{
	self.bo1sz_style_gauge += points * level.bo1sz_style_ranks_gain_mult[ self.bo1sz_style_rank ];
	while ( self.bo1sz_style_gauge >= gauge_max && self.bo1sz_style_rank < top )
	{
		self.bo1sz_style_gauge -= gauge_max;
		self.bo1sz_style_rank++;
		self thread style_popup( true );
	}
	if ( self.bo1sz_style_rank == top && self.bo1sz_style_gauge > gauge_max )
	{
		self.bo1sz_style_gauge = gauge_max;
	}
}

// ---------------------------------------------------------------------------
// HUD (positions and element types proven in Phase 0, C1)
// ---------------------------------------------------------------------------

style_hud_elem( x, y, scale )
{
	e = NewClientHudElem( self );
	e.horzAlign = "user_left";
	e.vertAlign = "middle";
	e.alignX = "left";
	e.alignY = "middle";
	e.x = x;
	e.y = y;
	e.fontScale = scale;
	e.foreground = true;
	e.alpha = 1;
	return e;
}

style_hud_create()
{
	self.bo1sz_hud_letter = self style_hud_elem( 12, -70, 3 );
	self.bo1sz_hud_word = self style_hud_elem( 14, -44, 1.3 );
	// Archetype name sits beside the letter; filled in at Milestone 5.
	self.bo1sz_hud_arch = self style_hud_elem( 70, -70, 1.2 );
	self.bo1sz_hud_arch SetText( "" );

	self.bo1sz_hud_bg = self style_hud_elem( 12, -28, 1 );
	self.bo1sz_hud_bg.foreground = false;
	self.bo1sz_hud_bg.alpha = 0.5;
	self.bo1sz_hud_bg.color = ( 0.1, 0.1, 0.1 );
	self.bo1sz_hud_bg SetShader( "white", 120, 6 );

	self.bo1sz_hud_bar = self style_hud_elem( 12, -28, 1 );
	self.bo1sz_hud_bar SetShader( "white", 1, 6 );

	pop = NewClientHudElem( self );
	pop.horzAlign = "user_center";
	pop.vertAlign = "middle";
	pop.alignX = "center";
	pop.alignY = "middle";
	pop.y = -120;
	pop.fontScale = 1.6;
	pop.foreground = true;
	pop.alpha = 0;
	self.bo1sz_hud_pop = pop;

	self.bo1sz_hud_shown_rank = -1;
}

style_hud_refresh()
{
	r = self.bo1sz_style_rank;
	if ( r != self.bo1sz_hud_shown_rank )
	{
		// SetText only on rank change: keeps the number of distinct strings small.
		color = ( level.bo1sz_style_ranks_r[ r ], level.bo1sz_style_ranks_g[ r ], level.bo1sz_style_ranks_b[ r ] );
		self.bo1sz_hud_letter SetText( level.bo1sz_style_ranks_letter[ r ] );
		self.bo1sz_hud_word SetText( level.bo1sz_style_ranks_word[ r ] );
		self.bo1sz_hud_letter.color = color;
		self.bo1sz_hud_word.color = color;
		self.bo1sz_hud_bar.color = color;
		self.bo1sz_hud_shown_rank = r;
	}

	// Rank D with an empty gauge is the baseline: dim the meter, never hide it.
	alpha = 1;
	if ( r == 0 && self.bo1sz_style_gauge <= 0 )
	{
		alpha = 0.35;
	}
	self.bo1sz_hud_letter.alpha = alpha;
	self.bo1sz_hud_word.alpha = alpha;

	w = int( 120 * self.bo1sz_style_gauge / style_bal( "gauge_max" ) );
	if ( w < 1 )
	{
		w = 1;
	}
	if ( w > 120 )
	{
		w = 120;
	}
	self.bo1sz_hud_bar SetShader( "white", w, 6 );
}

style_popup( up )
{
	self endon( "disconnect" );
	self notify( "bo1sz_style_popup" );
	self endon( "bo1sz_style_popup" );

	r = self.bo1sz_style_rank;
	pop = self.bo1sz_hud_pop;
	pop SetText( level.bo1sz_style_ranks_word[ r ] );
	pop.color = ( level.bo1sz_style_ranks_r[ r ], level.bo1sz_style_ranks_g[ r ], level.bo1sz_style_ranks_b[ r ] );
	if ( up )
	{
		self PlayLocalSound( style_bal( "sound_rank_up" ) );
	}
	else
	{
		self PlayLocalSound( style_bal( "sound_rank_down" ) );
	}
	pop FadeOverTime( 0.15 );
	pop.alpha = 1;
	wait style_bal( "popup_seconds" );
	pop FadeOverTime( 0.4 );
	pop.alpha = 0;
}

// ---------------------------------------------------------------------------
// Debug input (fake events) until real style events exist
// ---------------------------------------------------------------------------

style_debug_input()
{
	ticks = 0;
	for ( ;; )
	{
		wait 0.25;
		ticks++;

		// String compare on purpose: getDvarInt returned 0 for console-typed values.
		v = getDvar( "bo1sz_style_add" );
		if ( v != "" && v != "0" )
		{
			setDvar( "bo1sz_style_add", "0" );
			style_fake_all( 30 );
		}

		if ( getDvar( "bo1sz_style_fake" ) == "1" && ticks >= style_bal( "fake_interval_ticks" ) )
		{
			ticks = 0;
			lo = style_bal( "fake_min" );
			style_fake_all( lo + RandomInt( style_bal( "fake_max" ) - lo + 1 ) );
		}
	}
}

style_fake_all( points )
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( isDefined( p.bo1sz_style_q_pts ) )
		{
			p.bo1sz_style_q_pts[ p.bo1sz_style_q_pts.size ] = points;
			p.bo1sz_style_q_tag[ p.bo1sz_style_q_tag.size ] = "debug";
		}
	}
}
