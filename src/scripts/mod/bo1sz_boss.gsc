// bo1-style-zombies: boss "Der Eiserne" (Milestone 7, design approved 2026-10-05:
// docs/design/boss.md, no screen shake in phase 2).
//
// The first zombie spawned in the boss round is promoted (scripts can't spawn actors).
//   Phase 1 Onslaught  100-66%  damage race: enrages (sprint + pulses) after p1_timer
//   Phase 2 Hunt        66-33%  sprints; telegraphed pulses (on-screen warning + sound)
//   Phase 3 Iron Skin   33-0%   x0.25 damage except headshots/explosives; armour cracks
// One hit can remove at most hit_cap_frac of max health (Insta-Kill, nukes, failsafes).
// Victory: summary screen, then stock game over (end_on_victory) or endless play.
//
// Dvars: bo1sz_boss 0 disables; bo1sz_boss_now 1 (in game) promotes the next spawned
// zombie now; bo1sz_boss_test 1 (before load) scales boss health down.
// Tunables: data/balance/boss.csv.

init()
{
	if ( getDvar( "zombiemode" ) != "1" && !( isDefined( level.is_zombie_level ) && level.is_zombie_level ) )
	{
		return;
	}
	if ( getDvar( "bo1sz_enable" ) == "0" || getDvar( "bo1sz_boss" ) == "0" )
	{
		return;
	}
	// Precache must happen before the first wait of the level.
	PrecacheShader( "white" );
	level thread boss_start();
}

boss_start()
{
	t = 0;
	while ( !isDefined( level.bo1sz_bal ) && t < 100 )
	{
		wait 0.05;
		t++;
	}
	if ( !isDefined( level.bo1sz_bal ) )
	{
		boss_log( "balance data missing; boss off" );
		return;
	}
	level.bo1sz_boss_done = false;
	level.bo1sz_boss_armed = false;
	setDvar( "bo1sz_boss_now", "0" );
	boss_log( "boss on (round " + boss_bal( "round" ) + ", end_on_victory " + boss_bal( "end_on_victory" ) + ")" );

	level thread boss_install_hooks();
	level thread boss_track_max_rank();
	level thread boss_log_effects();
	level thread boss_now_command();
	for ( ;; )
	{
		level waittill( "start_of_round" );
		wait 0.1;
		if ( level.bo1sz_boss_done || level.bo1sz_boss_armed || level.round_number < boss_bal( "round" ) )
		{
			continue;
		}
		if ( boss_flag( "dog_round" ) || boss_flag( "thief_round" ) || boss_flag( "monkey_round" ) )
		{
			boss_log( "round " + level.round_number + " is a special round; boss waits for the next one" );
			continue;
		}
		level thread boss_arm( 1.0 );
	}
}

boss_bal( key )
{
	return level.bo1sz_bal[ "boss." + key ];
}

boss_log( msg )
{
	line = "[BO1SZ] boss: " + msg;
	println( line );
	logprint( line + "\n" );
}

boss_flag( name )
{
	return ( isDefined( level.flag ) && isDefined( level.flag[ name ] ) && level.flag[ name ] );
}

boss_now_command()
{
	for ( ;; )
	{
		wait 0.5;
		v = getDvar( "bo1sz_boss_now" );
		if ( v == "" || v == "0" || !( getDvar( "bo1sz_dev" ) == "1" ) )
		{
			continue;
		}
		setDvar( "bo1sz_boss_now", "0" );
		if ( !level.bo1sz_boss_armed && !level.bo1sz_boss_done )
		{
			level thread boss_arm( 1.0 );
		}
	}
}

// Highest style rank each player reached, for the victory summary.
boss_track_max_rank()
{
	for ( ;; )
	{
		wait 1;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isDefined( p.bo1sz_style_rank ) )
			{
				continue;
			}
			if ( !isDefined( p.bo1sz_style_max ) || p.bo1sz_style_rank > p.bo1sz_style_max )
			{
				p.bo1sz_style_max = p.bo1sz_style_rank;
			}
		}
	}
}

// ---------------------------------------------------------------------------
// Promotion and the fight
// ---------------------------------------------------------------------------

boss_wait_new_zombie()
{
	ai = GetAiSpeciesArray( "axis", "all" );
	for ( i = 0; i < ai.size; i++ )
	{
		ai[ i ].bo1sz_boss_seen = true;
	}
	for ( ;; )
	{
		ai = GetAiSpeciesArray( "axis", "all" );
		for ( i = 0; i < ai.size; i++ )
		{
			if ( isAlive( ai[ i ] ) && !isDefined( ai[ i ].bo1sz_boss_seen ) )
			{
				ai[ i ].bo1sz_boss_seen = true;
				return ai[ i ];
			}
		}
		wait 0.1;
	}
}

// health_frac < 1 re-promotes after the boss vanished without dying (watchdog).
boss_arm( health_frac )
{
	level.bo1sz_boss_armed = true;
	boss = boss_wait_new_zombie();
	wait 0.5;
	if ( !isDefined( boss ) || !isAlive( boss ) )
	{
		level.bo1sz_boss_armed = false;
		level thread boss_arm( health_frac );
		return;
	}
	players = GetPlayers();
	hp = int( level.zombie_health * boss_bal( "hp_mult" ) * players.size );
	if ( getDvar( "bo1sz_boss_test" ) == "1" && getDvar( "bo1sz_dev" ) == "1" )
	{
		hp = int( hp * boss_bal( "test_hp_scale" ) );
	}
	if ( hp < 1000 )
	{
		hp = 1000;
	}
	boss.maxhealth = hp;
	boss.health = int( hp * health_frac );
	boss.bo1sz_boss = true;
	level.bo1sz_boss_ent = boss;
	level.bo1sz_boss_phase = 1;
	level.bo1sz_boss_enraged = false;
	level.bo1sz_boss_crack = false;
	boss_log( "promoted at round " + level.round_number + " hp=" + boss.health + "/" + hp );

	boss_log( "creating HUD" );
	boss_hud_create();
	boss_log( "HUD created" );
	boss_hud_text( "phase", "Phase 1: Onslaught" );
	level thread boss_hud_loop( boss );
	level thread boss_phases( boss );
	level thread boss_pulses( boss );
	level thread boss_armour( boss );
	level thread boss_watch( boss );
}

boss_sprint( boss )
{
	boss.moveplaybackrate = boss_bal( "sprint_rate" );
	fn = getFunction( "maps/_zombiemode_spawner", "set_zombie_run_cycle" );
	if ( isDefined( fn ) )
	{
		boss [[ fn ]]( "sprint" );
	}
}

boss_phases( boss )
{
	boss endon( "death" );
	level endon( "bo1sz_boss_gone" );
	start = getTime();
	while ( boss.health > boss.maxhealth * boss_bal( "phase2_at" ) )
	{
		if ( !level.bo1sz_boss_enraged && getTime() - start > boss_bal( "p1_timer" ) * 1000 )
		{
			level.bo1sz_boss_enraged = true;
			boss_sprint( boss );
			boss_hud_text( "phase", "Phase 1: ENRAGED" );
			boss_log( "enraged" );
		}
		wait 0.2;
	}
	level.bo1sz_boss_phase = 2;
	boss_sprint( boss );
	boss_hud_text( "phase", "Phase 2: Hunt" );
	boss_log( "phase 2" );
	while ( boss.health > boss.maxhealth * boss_bal( "phase3_at" ) )
	{
		wait 0.2;
	}
	level.bo1sz_boss_phase = 3;
	boss_hud_text( "phase", "Phase 3: Iron Skin" );
	boss_log( "phase 3" );
}

// Phase 2 (and an enraged phase 1): telegraphed area pulses. No screen shake (user).
boss_pulses( boss )
{
	boss endon( "death" );
	level endon( "bo1sz_boss_gone" );
	for ( ;; )
	{
		wait boss_bal( "p2_pulse_interval" ) - boss_bal( "p2_warn_seconds" );
		if ( !( level.bo1sz_boss_phase == 2 || ( level.bo1sz_boss_phase == 1 && level.bo1sz_boss_enraged ) ) )
		{
			continue;
		}
		boss_hud_text( "warn", "PULSE INCOMING" );
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			players[ i ] PlayLocalSound( boss_bal( "warn_sound" ) );
		}
		wait boss_bal( "p2_warn_seconds" );
		r = boss_bal( "p2_pulse_radius" );
		d = boss_bal( "p2_pulse_damage" );
		RadiusDamage( boss.origin + ( 0, 0, 30 ), r, d, d, boss );
		boss_hud_text( "warn", "" );
	}
}

// Phase 3: armour cracks open on a timer.
boss_armour( boss )
{
	boss endon( "death" );
	level endon( "bo1sz_boss_gone" );
	while ( level.bo1sz_boss_phase < 3 )
	{
		wait 0.2;
	}
	for ( ;; )
	{
		wait boss_bal( "p3_crack_interval" );
		level.bo1sz_boss_crack = true;
		boss_hud_text( "warn", "ARMOUR DOWN!" );
		wait boss_bal( "p3_crack_seconds" );
		level.bo1sz_boss_crack = false;
		boss_hud_text( "warn", "" );
	}
}

// Victory on death; re-promotion if the boss vanished without dying (e.g. removed
// by a stock failsafe).
boss_watch( boss )
{
	level endon( "bo1sz_boss_gone" );
	frac = 1.0;
	while ( isDefined( boss ) && isAlive( boss ) )
	{
		frac = boss.health / boss.maxhealth;
		wait 0.1;
	}
	boss_log( "watch ended: defined=" + isDefined( boss ) + " killed_by=" + ( isDefined( boss ) && isDefined( boss.bo1sz_boss_killed_by ) ) );
	if ( isDefined( boss ) && isDefined( boss.bo1sz_boss_killed_by ) )
	{
		// Start the next thread BEFORE the notify: this thread has
		// endon( "bo1sz_boss_gone" ), so the notify ends it immediately (that bug
		// swallowed the victory screen in the 2026-10-05 test).
		level thread boss_victory( boss.bo1sz_boss_killed_by );
		level notify( "bo1sz_boss_gone" );
		return;
	}
	if ( isDefined( boss ) && boss.health <= 0 )
	{
		level thread boss_victory( undefined );
		level notify( "bo1sz_boss_gone" );
		return;
	}
	boss_log( "boss vanished without dying (health " + int( frac * 100 ) + "%); promoting another zombie" );
	level.bo1sz_boss_armed = false;
	level thread boss_arm( frac );
	level notify( "bo1sz_boss_gone" );
}

// ---------------------------------------------------------------------------
// Damage rules (outermost actor damage wrapper, so they apply after every bonus)
// ---------------------------------------------------------------------------

boss_install_hooks()
{
	t = 0;
	while ( ( !isDefined( level.overrideActorDamage ) || !isDefined( level.overrideActorKilled ) ) && t < 300 )
	{
		wait 0.1;
		t++;
	}
	// The other modules install after 10 frame-ends; wait longer so this wraps them all.
	wait 2;
	level.bo1sz_boss_orig_damage = level.overrideActorDamage;
	level.overrideActorDamage = ::boss_actor_damage;
	level.bo1sz_boss_orig_killed = level.overrideActorKilled;
	level.overrideActorKilled = ::boss_actor_killed;
}

boss_actor_damage( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, modelIndex, psOffsetTime )
{
	dmg = damage;
	if ( isDefined( level.bo1sz_boss_orig_damage ) )
	{
		dmg = self [[ level.bo1sz_boss_orig_damage ]]( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, modelIndex, psOffsetTime );
	}
	if ( !isDefined( dmg ) )
	{
		dmg = damage;
	}
	if ( !isDefined( self.bo1sz_boss ) || dmg <= 0 )
	{
		return dmg;
	}
	if ( !isDefined( meansofdeath ) )
	{
		meansofdeath = "";
	}
	if ( level.bo1sz_boss_phase == 3 )
	{
		if ( level.bo1sz_boss_crack )
		{
			dmg = dmg * boss_bal( "p3_crack_mult" );
		}
		else
		{
			head = ( isDefined( sHitLoc ) && ( sHitLoc == "head" || sHitLoc == "helmet" || sHitLoc == "neck" ) );
			boom = ( meansofdeath == "MOD_GRENADE" || meansofdeath == "MOD_GRENADE_SPLASH" || meansofdeath == "MOD_PROJECTILE" || meansofdeath == "MOD_PROJECTILE_SPLASH" || meansofdeath == "MOD_EXPLOSIVE" );
			if ( !head && !boom )
			{
				dmg = dmg * boss_bal( "p3_damage_mult" );
			}
		}
	}
	// Cap per server frame, not per hit: a shotgun blast is several pellet hits at once.
	now = getTime();
	if ( !isDefined( self.bo1sz_cap_ms ) || self.bo1sz_cap_ms != now )
	{
		self.bo1sz_cap_ms = now;
		self.bo1sz_cap_used = 0;
	}
	room = self.maxhealth * boss_bal( "hit_cap_frac" ) - self.bo1sz_cap_used;
	if ( room < 1 )
	{
		room = 1;
	}
	if ( dmg > room )
	{
		dmg = room;
	}
	dmg = int( dmg );
	if ( dmg < 1 )
	{
		dmg = 1;
	}
	self.bo1sz_cap_used += dmg;
	return dmg;
}

boss_actor_killed( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime )
{
	if ( isDefined( self.bo1sz_boss ) )
	{
		self.bo1sz_boss_killed_by = attacker;
		boss_log( "killed hook: boss died" );
	}
	if ( isDefined( level.bo1sz_boss_orig_killed ) )
	{
		self [[ level.bo1sz_boss_orig_killed ]]( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime );
	}
}

// ---------------------------------------------------------------------------
// HUD: name, health bar, phase and warning text at the top of the screen
// ---------------------------------------------------------------------------

boss_elem( player, y, scale )
{
	e = NewClientHudElem( player );
	if ( !isDefined( e ) )
	{
		boss_log( "HUD element could not be created (limit reached?)" );
		return e;
	}
	e.horzAlign = "user_center";
	e.vertAlign = "middle";
	e.alignX = "center";
	e.alignY = "middle";
	e.y = y;
	e.fontScale = scale;
	e.foreground = true;
	e.alpha = 1;
	return e;
}

boss_hud_create()
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( isDefined( p.bo1sz_boss_name ) )
		{
			p.bo1sz_boss_name.alpha = 1;
			p.bo1sz_boss_bg.alpha = 0.6;
			p.bo1sz_boss_bar.alpha = 1;
			p.bo1sz_boss_phase.alpha = 1;
			continue;
		}
		p.bo1sz_boss_name = boss_elem( p, -175, 1.6 );
		p.bo1sz_boss_name SetText( boss_bal( "name" ) );
		p.bo1sz_boss_name.color = ( 1, 0.3, 0.2 );
		p.bo1sz_boss_bg = boss_elem( p, -158, 1 );
		p.bo1sz_boss_bg.foreground = false;
		p.bo1sz_boss_bg.color = ( 0.1, 0.1, 0.1 );
		p.bo1sz_boss_bg.alpha = 0.6;
		p.bo1sz_boss_bg SetShader( "white", 300, 8 );
		p.bo1sz_boss_bar = boss_elem( p, -158, 1 );
		p.bo1sz_boss_bar.color = ( 0.9, 0.15, 0.1 );
		p.bo1sz_boss_bar SetShader( "white", 300, 8 );
		p.bo1sz_boss_phase = boss_elem( p, -144, 1.15 );
		p.bo1sz_boss_warn = boss_elem( p, -118, 1.6 );
		p.bo1sz_boss_warn.color = ( 1, 0.85, 0.2 );
	}
}

boss_hud_text( which, text )
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( which == "phase" && isDefined( p.bo1sz_boss_phase ) )
		{
			p.bo1sz_boss_phase SetText( text );
		}
		else if ( which == "warn" && isDefined( p.bo1sz_boss_warn ) )
		{
			p.bo1sz_boss_warn SetText( text );
		}
	}
}

boss_hud_loop( boss )
{
	level endon( "bo1sz_boss_gone" );
	last = -1;
	while ( isDefined( boss ) && isAlive( boss ) )
	{
		w = int( 300 * boss.health / boss.maxhealth );
		if ( w < 1 )
		{
			w = 1;
		}
		if ( w != last )
		{
			last = w;
			players = GetPlayers();
			for ( i = 0; i < players.size; i++ )
			{
				if ( isDefined( players[ i ].bo1sz_boss_bar ) )
				{
					players[ i ].bo1sz_boss_bar SetShader( "white", w, 8 );
				}
			}
		}
		wait 0.2;
	}
}

boss_hud_hide()
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		// Destroyed, not hidden (HUD draw limit).
		if ( isDefined( p.bo1sz_boss_name ) )
		{
			p.bo1sz_boss_name Destroy();
			p.bo1sz_boss_bg Destroy();
			p.bo1sz_boss_bar Destroy();
			p.bo1sz_boss_phase Destroy();
			p.bo1sz_boss_warn Destroy();
			p.bo1sz_boss_name = undefined;
			p.bo1sz_boss_bg = undefined;
			p.bo1sz_boss_bar = undefined;
			p.bo1sz_boss_phase = undefined;
			p.bo1sz_boss_warn = undefined;
		}
	}
}

// ---------------------------------------------------------------------------
// Victory
// ---------------------------------------------------------------------------

boss_victory( killer )
{
	level.bo1sz_boss_done = true;
	boss_log( "defeated at round " + level.round_number );
	boss_hud_hide();
	if ( isDefined( killer ) && isPlayer( killer ) )
	{
		fn = getFunction( "maps/_zombiemode_score", "add_to_player_score" );
		if ( isDefined( fn ) )
		{
			killer [[ fn ]]( boss_bal( "kill_points" ) );
		}
	}
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		players[ i ] thread boss_victory_screen();
	}
	wait boss_bal( "victory_seconds" );
	if ( boss_bal( "end_on_victory" ) == 1 )
	{
		boss_log( "ending the game (end_game)" );
		level notify( "end_game" );
	}
}

// User preference (2026-10-05): just "VICTORY" after the kill, then stock's own game-over
// screen. Layout is the one confirmed visible; held for victory_seconds, then removed
// before stock's end screen starts.
// "VICTORY" through the game's centre-print message, then stock's game-over screen (user
// preference). A large HUD-element title never rendered at this point in any build
// (created, logged as shown, invisible; cause unknown), so the centre print is used.
boss_victory_screen()
{
	self endon( "disconnect" );
	self iPrintLnBold( "VICTORY" );
	self PlayLocalSound( boss_bal( "victory_sound" ) );
	boss_log( "victory shown to " + self.playername );
}

// Diagnostic: names of the effects this map has loaded (level._effect), to pick an existing
// effect for making the boss stand out. Logged once, a few seconds after load.
boss_log_effects()
{
	wait 5;
	if ( !isDefined( level._effect ) )
	{
		boss_log( "effects: level._effect undefined" );
		return;
	}
	keys = getArrayKeys( level._effect );
	line = "";
	for ( i = 0; i < keys.size; i++ )
	{
		line = line + keys[ i ] + " ";
		if ( ( i + 1 ) % 12 == 0 )
		{
			boss_log( "effects: " + line );
			line = "";
		}
	}
	if ( line != "" )
	{
		boss_log( "effects: " + line );
	}
	boss_log( "effects: " + keys.size + " total" );
}
