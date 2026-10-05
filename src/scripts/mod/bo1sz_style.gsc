// bo1-style-zombies: style meter.
// Milestone 2: HUD, gauge, rank up/down, decay (step 1) and real style events (step 2):
// kills scored by headshot, streak, multi-kill, range, melee, explosive, clutch and
// variety; revives; taking damage drops a rank; going down resets to D.
//
// Other modules add style by appending to the player's queue (no cross-file calls):
//   p.bo1sz_style_q_pts[ p.bo1sz_style_q_pts.size ] = points;
//   p.bo1sz_style_q_tag[ p.bo1sz_style_q_tag.size ] = "tag";
//   p.bo1sz_style_q_arch[ p.bo1sz_style_q_arch.size ] = "archetype";   // or "none"
// Every event also accrues hidden per-run affinity: p.bo1sz_aff[ archetype ].
//
// Dvars (console, before loading a map unless noted):
//   bo1sz_style 0        disable this module
//   bo1sz_style_fake 1   feed random fake style events (can be toggled in game)
//   bo1sz_style_add 1    add one 30-point fake event to every player (in game)
//   bo1sz_style_debug 1  log every scored style event (in game)
//
// Tunables: data/balance/style*.csv (generated into bo1sz_balance.gsc).

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
	style_build_event_table();
	level thread style_debug_input();
	level thread style_install_hooks();
	level thread style_round_report();
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
	self.bo1sz_style_q_arch = [];
	self.bo1sz_style_rank = 0;
	self.bo1sz_style_gauge = 0;
	self.bo1sz_style_last_ms = 0;
	self.bo1sz_style_last_tag = "";
	self.bo1sz_style_rep = 1.0;
	self.bo1sz_style_hit = false;
	self.bo1sz_style_hit_ms = 0;
	self.bo1sz_style_downed = false;
	self.bo1sz_hs_streak = 0;
	self.bo1sz_recent_classes = [];
	self.bo1sz_kill_ms = -1;
	self.bo1sz_kill_n = 0;
	self.bo1sz_hit_total = 0;
	if ( !isDefined( self.bo1sz_aff ) )
	{
		self.bo1sz_aff = [];
	}
	self thread style_listen( "player_downed" );
	self thread style_listen( "player_revived" );

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

		// Going down resets the meter; taking damage drops one rank (with a cooldown).
		if ( self.bo1sz_style_downed )
		{
			self.bo1sz_style_downed = false;
			self.bo1sz_style_hit = false;
			if ( self.bo1sz_style_rank > 0 || self.bo1sz_style_gauge > 0 )
			{
				self.bo1sz_style_rank = 0;
				self.bo1sz_style_gauge = 0;
				self thread style_popup( false );
				changed = true;
			}
		}
		if ( self.bo1sz_style_hit )
		{
			self.bo1sz_style_hit = false;
			// Brawler Ascended: getting hit no longer drops the style rank (user request).
			if ( self.bo1sz_style_rank > 0 && style_arch_tier( self, "brawler" ) < 2 && getTime() - self.bo1sz_style_hit_ms > style_bal( "hit_drop_cooldown_ms" ) )
			{
				self.bo1sz_style_hit_ms = getTime();
				self.bo1sz_style_rank--;
				self thread style_popup( false );
				changed = true;
			}
		}

		// Drain queued style events.
		pts = self.bo1sz_style_q_pts;
		if ( pts.size > 0 )
		{
			tags = self.bo1sz_style_q_tag;
			archs = self.bo1sz_style_q_arch;
			self.bo1sz_style_q_pts = [];
			self.bo1sz_style_q_tag = [];
			self.bo1sz_style_q_arch = [];
			for ( i = 0; i < pts.size; i++ )
			{
				gain = pts[ i ] * self style_repetition( tags[ i ] );
				self style_affinity( archs[ i ], gain );
				self style_gain( gain, gauge_max, top );
				if ( tags[ i ] == "hit" )
				{
					self.bo1sz_hit_total += gain;
				}
				else if ( getDvar( "bo1sz_style_debug" ) == "1" )
				{
					style_log( "ev tag=" + tags[ i ] + " arch=" + archs[ i ] + " pts=" + pts[ i ] + " gain=" + gain + " rank=" + self.bo1sz_style_rank );
				}
			}
			self.bo1sz_style_last_ms = getTime();
			changed = true;
		}

		// Decay when idle; empty gauge drops one rank.
		if ( getTime() - self.bo1sz_style_last_ms > grace && ( self.bo1sz_style_gauge > 0 || self.bo1sz_style_rank > 0 ) )
		{
			decay = level.bo1sz_style_ranks_decay_per_sec[ self.bo1sz_style_rank ] * 0.1;
			// High Roller run modifier drains the meter faster.
			if ( isDefined( level.bo1sz_style_decay_mult ) )
			{
				decay = decay * level.bo1sz_style_decay_mult;
			}
			self.bo1sz_style_gauge -= decay;
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
	// The boss victory screen hides the meter (ending screen).
	if ( isDefined( self.bo1sz_style_hidden ) )
	{
		return;
	}
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
		if ( v != "" && v != "0" && getDvar( "bo1sz_dev" ) == "1" )
		{
			setDvar( "bo1sz_style_add", "0" );
			style_fake_all( 30 );
		}

		if ( getDvar( "bo1sz_style_fake" ) == "1" && getDvar( "bo1sz_dev" ) == "1" && ticks >= style_bal( "fake_interval_ticks" ) )
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
		// A different tag each time so the repetition penalty doesn't throttle the demo.
		p style_queue( points, "debug" + RandomInt( 1000 ), "none" );
	}
}

style_queue( points, tag, arch )
{
	if ( !isDefined( self.bo1sz_style_q_pts ) )
	{
		return;
	}
	self.bo1sz_style_q_pts[ self.bo1sz_style_q_pts.size ] = points;
	self.bo1sz_style_q_tag[ self.bo1sz_style_q_tag.size ] = tag;
	self.bo1sz_style_q_arch[ self.bo1sz_style_q_arch.size ] = arch;
}

// Repeating the same primary action gives diminishing returns; any other action resets it.
style_repetition( tag )
{
	// Hits are rate-capped instead, and must not reset the penalty for kills.
	if ( tag == "hit" )
	{
		return 1.0;
	}
	if ( tag == self.bo1sz_style_last_tag )
	{
		self.bo1sz_style_rep = self.bo1sz_style_rep * style_bal( "rep_decay" );
		if ( self.bo1sz_style_rep < style_bal( "rep_min" ) )
		{
			self.bo1sz_style_rep = style_bal( "rep_min" );
		}
	}
	else
	{
		self.bo1sz_style_rep = 1.0;
		self.bo1sz_style_last_tag = tag;
	}
	return self.bo1sz_style_rep;
}

// Hidden per-run affinity (read by the archetype module at Milestone 5).
style_affinity( arch, amount )
{
	if ( !isDefined( arch ) || arch == "none" || arch == "" )
	{
		return;
	}
	if ( !isDefined( self.bo1sz_aff[ arch ] ) )
	{
		self.bo1sz_aff[ arch ] = 0;
	}
	self.bo1sz_aff[ arch ] += amount;
}

style_listen( note )
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( note, reviver );
		if ( note == "player_downed" )
		{
			self.bo1sz_style_downed = true;
		}
		else if ( isDefined( reviver ) && isPlayer( reviver ) && reviver != self )
		{
			reviver style_queue( style_ev_pts( "revive" ), "revive", style_ev_arch( "revive" ) );
		}
	}
}

// ---------------------------------------------------------------------------
// Event table (data/balance/style_events.csv)
// ---------------------------------------------------------------------------

style_build_event_table()
{
	level.bo1sz_style_ev_pts = [];
	level.bo1sz_style_ev_arch = [];
	for ( i = 0; i < level.bo1sz_style_events_count; i++ )
	{
		name = level.bo1sz_style_events_name[ i ];
		level.bo1sz_style_ev_pts[ name ] = level.bo1sz_style_events_points[ i ];
		level.bo1sz_style_ev_arch[ name ] = level.bo1sz_style_events_archetype[ i ];
	}
}

style_ev_pts( name )
{
	return level.bo1sz_style_ev_pts[ name ];
}

style_ev_arch( name )
{
	return level.bo1sz_style_ev_arch[ name ];
}

// "auto" events credit the archetype of the weapon used (a shotgun headshot feeds
// Blaster, not Gunslinger: playtest 2026-10-05, shotgun-only run grew Gunslinger).
style_event_arch( name, cls, mod )
{
	a = style_ev_arch( name );
	if ( a == "auto" )
	{
		return style_class_arch( cls, mod );
	}
	return a;
}

// ---------------------------------------------------------------------------
// Hooks: wrap stock callbacks (stock always runs first; proven in Phase 0 B3/B8)
// ---------------------------------------------------------------------------

style_install_hooks()
{
	t = 0;
	while ( ( !isDefined( level.overrideActorKilled ) || !isDefined( level.overridePlayerDamage ) || !isDefined( level.overrideActorDamage ) ) && t < 300 )
	{
		wait 0.1;
		t++;
	}
	for ( i = 0; i < 10; i++ )
	{
		waittillframeend;
	}
	level.bo1sz_style_orig_killed = level.overrideActorKilled;
	level.bo1sz_style_orig_pdamage = level.overridePlayerDamage;
	level.bo1sz_style_orig_adamage = level.overrideActorDamage;
	level.overrideActorKilled = ::style_actor_killed;
	level.overridePlayerDamage = ::style_player_damage;
	level.overrideActorDamage = ::style_actor_damage;
	style_log( "hooks installed (stock killed=" + isDefined( level.bo1sz_style_orig_killed ) + " pdamage=" + isDefined( level.bo1sz_style_orig_pdamage ) + " adamage=" + isDefined( level.bo1sz_style_orig_adamage ) + ")" );
}

// Zombie damage (spy only, proven in Phase 0 B2): every hit adds a little style and
// keeps the meter from decaying while the player is fighting.
style_actor_damage( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, modelIndex, psOffsetTime )
{
	dmg = damage;
	if ( isDefined( level.bo1sz_style_orig_adamage ) )
	{
		dmg = self [[ level.bo1sz_style_orig_adamage ]]( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, modelIndex, psOffsetTime );
	}
	if ( !isDefined( dmg ) )
	{
		dmg = damage;
	}
	if ( dmg > 0 && isDefined( attacker ) && isPlayer( attacker ) && isDefined( attacker.bo1sz_style_q_pts ) )
	{
		attacker style_on_hit( meansofdeath, weapon, sHitLoc, self );
	}
	return dmg;
}

style_on_hit( mod, weapon, hitloc, victim )
{
	now = getTime();
	if ( !isDefined( mod ) )
	{
		mod = "";
	}
	cls = style_weapon_class( weapon );
	head = ( isDefined( hitloc ) && ( hitloc == "head" || hitloc == "helmet" || hitloc == "neck" ) && style_is_bullet( mod ) );

	// Shotguns and explosives score once per zombie hit (user request: give the weaker
	// area weapons a fast way to build style). Other weapons score once per frame.
	aoe = ( cls == "spread" || style_is_explosive( mod ) );
	if ( aoe )
	{
		// Several pellets on the same zombie in one frame still count once.
		if ( isDefined( victim.bo1sz_hit_ms ) && victim.bo1sz_hit_ms == now && isDefined( victim.bo1sz_hit_by ) && victim.bo1sz_hit_by == self )
		{
			return;
		}
		victim.bo1sz_hit_ms = now;
		victim.bo1sz_hit_by = self;
		pts = style_ev_pts( "hit_aoe" );
		cap = style_bal( "hit_cap_per_sec_aoe" );
		if ( !isDefined( self.bo1sz_aoe_win_ms ) || now - self.bo1sz_aoe_win_ms >= 1000 )
		{
			self.bo1sz_aoe_win_ms = now;
			self.bo1sz_aoe_win_pts = 0;
		}
		used = self.bo1sz_aoe_win_pts;
	}
	else
	{
		if ( isDefined( self.bo1sz_hit_ms ) && self.bo1sz_hit_ms == now )
		{
			return;
		}
		self.bo1sz_hit_ms = now;
		pts = style_ev_pts( "hit" );
		cap = style_bal( "hit_cap_per_sec" );
		if ( !isDefined( self.bo1sz_hit_win_ms ) || now - self.bo1sz_hit_win_ms >= 1000 )
		{
			self.bo1sz_hit_win_ms = now;
			self.bo1sz_hit_win_pts = 0;
		}
		used = self.bo1sz_hit_win_pts;
	}
	if ( head && style_ev_pts( "hit_headshot" ) > pts )
	{
		pts = style_ev_pts( "hit_headshot" );
	}

	room = cap - used;
	if ( room <= 0 )
	{
		// Still fighting: keep decay paused even when the cap is reached.
		self.bo1sz_style_last_ms = now;
		return;
	}
	if ( pts > room )
	{
		pts = room;
	}
	if ( aoe )
	{
		self.bo1sz_aoe_win_pts += pts;
	}
	else
	{
		self.bo1sz_hit_win_pts += pts;
	}
	self style_queue( pts, "hit", style_class_arch( cls, mod ) );
}

style_actor_killed( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime )
{
	if ( isDefined( level.bo1sz_style_orig_killed ) )
	{
		self [[ level.bo1sz_style_orig_killed ]]( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime );
	}
	if ( isDefined( attacker ) && isPlayer( attacker ) && isDefined( attacker.bo1sz_style_q_pts ) )
	{
		self style_on_kill( attacker, sMeansOfDeath, sWeapon, sHitLoc );
	}
}

style_player_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime )
{
	dmg = iDamage;
	if ( isDefined( level.bo1sz_style_orig_pdamage ) )
	{
		dmg = self [[ level.bo1sz_style_orig_pdamage ]]( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime );
	}
	if ( !isDefined( dmg ) )
	{
		dmg = iDamage;
	}
	// Spy only: never changes the damage.
	if ( dmg > 0 && isDefined( self.bo1sz_style_q_pts ) )
	{
		self.bo1sz_style_hit = true;
	}
	return dmg;
}

// ---------------------------------------------------------------------------
// Kill scoring: all events from one kill are summed into one queue entry whose
// tag is the highest-scoring (primary) event, so repetition is judged per kill.
// ---------------------------------------------------------------------------

style_is_explosive( mod )
{
	return ( mod == "MOD_GRENADE" || mod == "MOD_GRENADE_SPLASH" || mod == "MOD_PROJECTILE" || mod == "MOD_PROJECTILE_SPLASH" || mod == "MOD_EXPLOSIVE" );
}

style_is_bullet( mod )
{
	return ( mod == "MOD_PISTOL_BULLET" || mod == "MOD_RIFLE_BULLET" || mod == "MOD_HEAD_SHOT" );
}

style_weapon_class( weapon )
{
	if ( !isDefined( weapon ) || weapon == "none" || weapon == "" )
	{
		return "none";
	}
	// Wonder weapons and equipment are their own classes for archetype affinity.
	if ( isDefined( level.bo1sz_pay_excluded ) )
	{
		for ( i = 0; i < level.bo1sz_pay_excluded.size; i++ )
		{
			if ( isSubStr( weapon, level.bo1sz_pay_excluded[ i ] ) )
			{
				return "wonder";
			}
		}
	}
	if ( isSubStr( weapon, "claymore" ) || isSubStr( weapon, "cymbal_monkey" ) )
	{
		return "equipment";
	}
	// Same class overrides as the payoffs module (payoffs.class_overrides), when loaded.
	if ( isDefined( level.bo1sz_pay_ovr_name ) )
	{
		for ( i = 0; i < level.bo1sz_pay_ovr_name.size; i++ )
		{
			if ( isSubStr( weapon, level.bo1sz_pay_ovr_name[ i ] ) )
			{
				return level.bo1sz_pay_ovr_class[ i ];
			}
		}
	}
	return WeaponClass( weapon );
}

// Archetype ids: gunslinger, marksman, brawler (melee), blaster (shotguns), demolitions, tech.
style_class_arch( cls, mod )
{
	// Melee feeds Brawler whatever is in hand (knife, Bowie).
	if ( mod == "MOD_MELEE" )
	{
		return "brawler";
	}
	// Wonder weapons and equipment (claymores, monkeys) feed Tech; checked before
	// explosives because claymore kills are explosive.
	if ( cls == "wonder" || cls == "equipment" )
	{
		return "tech";
	}
	// Grenade kills can report the held gun as the weapon: classify by means of death first.
	if ( style_is_explosive( mod ) || cls == "rocketlauncher" || cls == "grenade" )
	{
		return "demolitions";
	}
	if ( cls == "pistol" )
	{
		return "gunslinger";
	}
	if ( cls == "spread" )
	{
		return "blaster";
	}
	if ( cls == "sniper" )
	{
		return "marksman";
	}
	return "none";
}

style_on_kill( attacker, mod, weapon, hitloc )
{
	if ( !isDefined( mod ) )
	{
		mod = "";
	}
	cls = style_weapon_class( weapon );
	total = style_ev_pts( "kill" );
	best_tag = "kill";
	best_pts = 0;
	best_arch = style_class_arch( cls, mod );

	// Headshot and headshot streak.
	headshot = ( isDefined( hitloc ) && ( hitloc == "head" || hitloc == "helmet" || hitloc == "neck" ) && style_is_bullet( mod ) );
	if ( headshot )
	{
		attacker.bo1sz_hs_streak++;
		extra = attacker.bo1sz_hs_streak - 1;
		if ( extra > style_bal( "hs_streak_cap" ) )
		{
			extra = style_bal( "hs_streak_cap" );
		}
		pts = style_ev_pts( "headshot" ) + extra * style_ev_pts( "headshot_streak" );
		total += pts;
		if ( pts > best_pts )
		{
			best_pts = pts;
			best_tag = "headshot";
			best_arch = style_event_arch( "headshot", cls, mod );
		}
	}
	else
	{
		attacker.bo1sz_hs_streak = 0;
	}

	// Multi-kill: several kills by one player in the same server frame (proven in C5).
	now = getTime();
	if ( attacker.bo1sz_kill_ms == now )
	{
		attacker.bo1sz_kill_n++;
		pts = style_ev_pts( "multi_kill" );
		total += pts;
		if ( pts > best_pts )
		{
			best_pts = pts;
			best_tag = "multi_kill";
			best_arch = "marksman";
			if ( style_is_explosive( mod ) )
			{
				best_arch = "demolitions";
			}
			else if ( cls == "spread" )
			{
				best_arch = "blaster";
			}
			else if ( cls == "wonder" )
			{
				best_arch = "tech";
			}
		}
	}
	else
	{
		attacker.bo1sz_kill_ms = now;
		attacker.bo1sz_kill_n = 1;
	}

	// Melee finish.
	if ( mod == "MOD_MELEE" )
	{
		pts = style_ev_pts( "melee" );
		total += pts;
		if ( pts > best_pts )
		{
			best_pts = pts;
			best_tag = "melee";
			best_arch = style_ev_arch( "melee" );
		}
	}

	// Explosive kill.
	if ( style_is_explosive( mod ) )
	{
		pts = style_ev_pts( "explosive" );
		total += pts;
		if ( pts > best_pts )
		{
			best_pts = pts;
			best_tag = "explosive";
			best_arch = style_event_arch( "explosive", cls, mod );
		}
	}

	// Long-range kill (bullets only). Eagle Eye augment halves the distance.
	long_units = style_bal( "long_range_units" );
	if ( isDefined( attacker.bo1sz_aug ) && isDefined( attacker.bo1sz_aug[ "mark_eye" ] ) )
	{
		long_units = long_units * 0.5;
	}
	long_kill = ( style_is_bullet( mod ) && Distance( attacker.origin, self.origin ) > long_units );
	if ( long_kill )
	{
		pts = style_ev_pts( "long_range" );
		total += pts;
		if ( pts > best_pts )
		{
			best_pts = pts;
			best_tag = "long_range";
			best_arch = style_event_arch( "long_range", cls, mod );
		}
	}

	// Clutch: kill while badly hurt.
	if ( isDefined( attacker.maxhealth ) && attacker.maxhealth > 0 && attacker.health < attacker.maxhealth * style_bal( "clutch_health_frac" ) )
	{
		pts = style_ev_pts( "clutch" );
		total += pts;
		if ( pts > best_pts )
		{
			best_pts = pts;
			best_tag = "clutch";
		}
	}

	// Variety: a weapon class not used in the last N kills.
	window = style_bal( "variety_window" );
	recent = attacker.bo1sz_recent_classes;
	if ( recent.size >= window )
	{
		fresh = true;
		for ( i = 0; i < recent.size; i++ )
		{
			if ( recent[ i ] == cls )
			{
				fresh = false;
				break;
			}
		}
		if ( fresh )
		{
			total += style_ev_pts( "variety" );
		}
	}
	updated = [];
	updated[ 0 ] = cls;
	for ( i = 0; i < recent.size && updated.size < window; i++ )
	{
		updated[ updated.size ] = recent[ i ];
	}
	attacker.bo1sz_recent_classes = updated;

	// Tech Awakened: wonder weapon kills give extra style.
	if ( cls == "wonder" && isDefined( attacker.bo1sz_arch ) && isDefined( attacker.bo1sz_arch[ "tech" ] ) && attacker.bo1sz_arch[ "tech" ] >= 1 )
	{
		total = total * level.bo1sz_bal[ "archetype_rules.tech_t1_style_mult" ];
	}

	// Marksman Ascended: long-range kills give double style.
	if ( long_kill && style_arch_tier( attacker, "marksman" ) >= 2 )
	{
		total = total * level.bo1sz_bal[ "archetype_rules.marksman_t2_long_style_mult" ];
	}
	// Augments: style multiplier for the archetype this kill belongs to.
	total = total * style_aug_style( attacker, style_class_arch( cls, mod ) );

	attacker style_queue( total, best_tag, best_arch );
}

style_arch_tier( player, id )
{
	if ( isDefined( player.bo1sz_arch ) && isDefined( player.bo1sz_arch[ id ] ) )
	{
		return player.bo1sz_arch[ id ];
	}
	return 0;
}

// Product of the player's "style" augments for one archetype (1.0 if none).
style_aug_style( player, arch )
{
	m = 1.0;
	if ( !isDefined( player.bo1sz_aug ) || !isDefined( level.bo1sz_augments_count ) )
	{
		return m;
	}
	for ( i = 0; i < level.bo1sz_augments_count; i++ )
	{
		if ( isDefined( player.bo1sz_aug[ level.bo1sz_augments_id[ i ] ] ) && level.bo1sz_augments_arch[ i ] == arch && level.bo1sz_augments_kind[ i ] == "style" )
		{
			m = m * level.bo1sz_augments_value[ i ];
		}
	}
	return m;
}

// Logs each player's rank and hidden affinity at every round end (tuning aid).
style_round_report()
{
	for ( ;; )
	{
		level waittill( "end_of_round" );
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isDefined( p.bo1sz_aff ) )
			{
				continue;
			}
			line = "round " + level.round_number + " " + p.playername + " rank=" + p.bo1sz_style_rank + " hit_pts=" + int( p.bo1sz_hit_total ) + " aff:";
			keys = getArrayKeys( p.bo1sz_aff );
			for ( k = 0; k < keys.size; k++ )
			{
				line = line + " " + keys[ k ] + "=" + int( p.bo1sz_aff[ keys[ k ] ] );
			}
			style_log( line );
		}
	}
}
