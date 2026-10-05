// bo1sz Phase 0 feasibility probe (Batches B and C). NOT gameplay code.
//
// Enable before loading a map, from the in-game console:
//   set probe_batch b          (or c)   -> runs every test of that batch
//   set probe_b7 0                      -> disables one test of the enabled batch
//   set probe_c10 1                     -> enables one test without its batch
//   set probe_finish 1                  -> stop waiting; resolve everything now
//   set probe_timeout 900               -> seconds before an unanswered test resolves
// Results: on screen, console, main/games.log, and the dvar probe_log.
//
// Rules this file follows (see CLAUDE.md):
// - Hooks wrap stock level callbacks; the stock function is always still called.
// - Cross-file stock functions are looked up with getFunction() at runtime, so a
//   missing one shows up as BLOCKED/FAIL instead of preventing the map from loading.
// - Each test runs in its own thread with a watchdog; a script error inside a test
//   only kills that thread, and the watchdog reports it as FAIL with the last stage.

main()
{
	level.probe_main_ms = getTime();
}

init()
{
	level.probe_init_ms = getTime();
	if ( getDvar( "zombiemode" ) != "1" && !( isDefined( level.is_zombie_level ) && level.is_zombie_level ) )
	{
		return;
	}

	probe_register();
	if ( level.probe_active.size == 0 )
	{
		return;
	}

	// Precache must happen before the first wait of the level.
	if ( level.probe_on[ "C1" ] || level.probe_on[ "C13" ] )
	{
		PrecacheShader( "white" );
	}

	level.probe_init_before_player = ( GetPlayers().size == 0 );
	level thread probe_start();
}

// ---------------------------------------------------------------------------
// Registry, runner, watchdog
// ---------------------------------------------------------------------------

probe_register()
{
	level.probe_fn = [];
	level.probe_fn[ "B1" ] = ::probe_b1;
	level.probe_fn[ "B2" ] = ::probe_b2;
	level.probe_fn[ "B3" ] = ::probe_b3;
	level.probe_fn[ "B4" ] = ::probe_b4;
	level.probe_fn[ "B5" ] = ::probe_b5;
	level.probe_fn[ "B6" ] = ::probe_b6;
	level.probe_fn[ "B7" ] = ::probe_b7;
	level.probe_fn[ "B8" ] = ::probe_b8;
	level.probe_fn[ "B9" ] = ::probe_b9;
	level.probe_fn[ "C1" ] = ::probe_c1;
	level.probe_fn[ "C2" ] = ::probe_c2;
	level.probe_fn[ "C3" ] = ::probe_c3;
	level.probe_fn[ "C4" ] = ::probe_c4;
	level.probe_fn[ "C5" ] = ::probe_c5;
	level.probe_fn[ "C6" ] = ::probe_c6;
	level.probe_fn[ "C7" ] = ::probe_c7;
	level.probe_fn[ "C8" ] = ::probe_c8;
	level.probe_fn[ "C9" ] = ::probe_c9;
	level.probe_fn[ "C10" ] = ::probe_c10;
	level.probe_fn[ "C11" ] = ::probe_c11;
	level.probe_fn[ "C12" ] = ::probe_c12;
	level.probe_fn[ "C13" ] = ::probe_c13;

	level.probe_ids = getArrayKeys( level.probe_fn );
	level.probe_on = [];
	level.probe_status = [];
	level.probe_stage = [];
	level.probe_stage_ms = [];
	level.probe_active = [];
	level.probe_modifiable = "";

	batch = toLower( getDvar( "probe_batch" ) );
	for ( i = 0; i < level.probe_ids.size; i++ )
	{
		id = level.probe_ids[ i ];
		v = getDvar( "probe_" + toLower( id ) );
		on = false;
		if ( v == "1" )
		{
			on = true;
		}
		else if ( v != "0" && batch != "" && toLower( getSubStr( id, 0, 1 ) ) == batch )
		{
			on = true;
		}
		level.probe_on[ id ] = on;
		level.probe_status[ id ] = "OFF";
		if ( on )
		{
			level.probe_active[ level.probe_active.size ] = id;
		}
	}
}

probe_start()
{
	setDvar( "probe_finish", "0" );

	if ( probe_any_on( "B2 B3 B8 C3 C4 C5" ) )
	{
		level thread probe_install_hooks();
	}

	for ( i = 0; i < level.probe_active.size; i++ )
	{
		id = level.probe_active[ i ];
		level.probe_status[ id ] = "RUNNING";
		probe_stage( id, "start" );
		level thread probe_watch( id );
		level thread [[ level.probe_fn[ id ] ]]( id );
	}

	p = probe_player();
	wait 5;
	p iPrintLnBold( "[PROBE] " + level.probe_active.size + " tests running - see console / main/games.log" );
	logprint( "[PROBE-INFO] active=" + probe_join( level.probe_active ) + " main_ms=" + probe_str( level.probe_main_ms ) + " init_ms=" + level.probe_init_ms + "\n" );
}

probe_watch( id )
{
	limit = getDvarInt( "probe_timeout" );
	if ( limit <= 0 )
	{
		limit = 900;
	}
	elapsed = 0;
	while ( level.probe_status[ id ] == "RUNNING" )
	{
		stage = level.probe_stage[ id ];
		waiting = ( getSubStr( stage + "     ", 0, 5 ) == "wait:" );
		stuck = ( !waiting && getTime() - level.probe_stage_ms[ id ] > 20000 );
		if ( stuck )
		{
			probe_result( id, "FAIL", "error: thread died at stage '" + stage + "'" );
			return;
		}
		if ( elapsed >= limit || getDvar( "probe_finish" ) == "1" )
		{
			if ( waiting )
			{
				probe_result( id, "BLOCKED", "do in game: " + getSubStr( stage, 5, stage.size ) );
			}
			else
			{
				probe_result( id, "FAIL", "error: no result at stage '" + stage + "'" );
			}
			return;
		}
		wait 1;
		elapsed++;
	}
}

probe_stage( id, stage )
{
	level.probe_stage[ id ] = stage;
	level.probe_stage_ms[ id ] = getTime();
}

probe_result( id, status, evidence )
{
	if ( level.probe_status[ id ] != "RUNNING" )
	{
		return;
	}
	level.probe_status[ id ] = status;
	probe_emit( probe_line( id, status, evidence ) );
	probe_check_batch_done( getSubStr( id, 0, 1 ) );
}

probe_mark_modifiable( id )
{
	if ( level.probe_modifiable == "" )
	{
		level.probe_modifiable = id;
	}
	else
	{
		level.probe_modifiable = level.probe_modifiable + "," + id;
	}
}

probe_check_batch_done( b )
{
	if ( isDefined( level.probe_summary_done ) && isDefined( level.probe_summary_done[ b ] ) )
	{
		return;
	}
	n = [];
	n[ "PASS" ] = 0;
	n[ "PARTIAL" ] = 0;
	n[ "FAIL" ] = 0;
	n[ "BLOCKED" ] = 0;
	n[ "SKIPPED" ] = 0;
	any = false;
	for ( i = 0; i < level.probe_active.size; i++ )
	{
		id = level.probe_active[ i ];
		if ( getSubStr( id, 0, 1 ) != b )
		{
			continue;
		}
		any = true;
		s = level.probe_status[ id ];
		if ( s == "RUNNING" )
		{
			return;
		}
		n[ s ]++;
	}
	if ( !any )
	{
		return;
	}
	if ( !isDefined( level.probe_summary_done ) )
	{
		level.probe_summary_done = [];
	}
	level.probe_summary_done[ b ] = true;

	next = "done";
	reason = "none";
	if ( b == "B" )
	{
		if ( level.probe_status[ "B2" ] == "PASS" && ( level.probe_status[ "B3" ] == "PASS" || level.probe_status[ "B3" ] == "PARTIAL" ) )
		{
			next = "C";
		}
		else
		{
			reason = "B2/B3 not both hooked+modifiable (B2=" + level.probe_status[ "B2" ] + " B3=" + level.probe_status[ "B3" ] + ")";
		}
	}

	probe_emit( "[PROBE] ==== BATCH " + b + " SUMMARY ====" );
	probe_emit( "[PROBE] passed=" + n[ "PASS" ] + " partial=" + n[ "PARTIAL" ] + " failed=" + n[ "FAIL" ] + " blocked=" + n[ "BLOCKED" ] + " skipped=" + n[ "SKIPPED" ] );
	if ( b == "B" )
	{
		mods = level.probe_modifiable;
		if ( mods == "" )
		{
			mods = "none";
		}
		probe_emit( "[PROBE] hooks_modifiable=" + mods );
	}
	probe_emit( "[PROBE] next_batch=" + next + " stop_reason=" + reason );
	probe_emit( "[PROBE] ==== END ====" );
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

probe_mode()
{
	if ( isDedicated() )
	{
		return "server";
	}
	if ( GetPlayers().size > 1 )
	{
		return "coop";
	}
	return "solo";
}

probe_line( id, status, evidence )
{
	if ( !isDefined( evidence ) )
	{
		evidence = "";
	}
	if ( evidence.size > 79 )
	{
		evidence = getSubStr( evidence, 0, 79 );
	}
	return "[PROBE] " + id + " | " + status + " | " + getDvar( "mapname" ) + " | " + probe_mode() + " | " + evidence;
}

probe_emit( line )
{
	iPrintLn( line );
	println( line );
	logprint( line + "\n" );

	if ( !isDefined( level.probe_log ) )
	{
		level.probe_log = getDvar( "probe_log" ) + " ## ---- " + getDvar( "mapname" ) + " ----";
	}
	level.probe_log = level.probe_log + " ## " + line;
	cap = getDvarInt( "probe_log_max" );
	if ( cap <= 0 )
	{
		cap = 4000;
	}
	if ( level.probe_log.size > cap )
	{
		level.probe_log = getSubStr( level.probe_log, level.probe_log.size - cap, level.probe_log.size );
	}
	setDvar( "probe_log", level.probe_log );
}

// Extra data that does not fit a result line goes to the log only.
probe_data( id, text )
{
	logprint( "[PROBE-DATA] " + id + " " + text + "\n" );
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

probe_any_on( list )
{
	ids = strTok( list, " " );
	for ( i = 0; i < ids.size; i++ )
	{
		if ( level.probe_on[ ids[ i ] ] )
		{
			return true;
		}
	}
	return false;
}

probe_player()
{
	for ( ;; )
	{
		players = GetPlayers();
		if ( players.size > 0 && isAlive( players[ 0 ] ) )
		{
			return players[ 0 ];
		}
		wait 0.25;
	}
}

probe_str( v )
{
	if ( !isDefined( v ) )
	{
		return "undef";
	}
	return "" + v;
}

probe_join( arr )
{
	s = "";
	for ( i = 0; i < arr.size; i++ )
	{
		if ( i > 0 )
		{
			s = s + ",";
		}
		s = s + arr[ i ];
	}
	return s;
}

probe_is_headshot( hitloc, mod )
{
	if ( !isDefined( hitloc ) )
	{
		return false;
	}
	if ( hitloc != "head" && hitloc != "helmet" && hitloc != "neck" )
	{
		return false;
	}
	if ( !isDefined( mod ) )
	{
		return true;
	}
	return ( mod == "MOD_PISTOL_BULLET" || mod == "MOD_RIFLE_BULLET" || mod == "MOD_HEAD_SHOT" );
}

probe_weapon_class( weapon )
{
	if ( !isDefined( weapon ) || weapon == "none" || weapon == "" )
	{
		return "none";
	}
	return WeaponClass( weapon );
}

// Adds points through the stock score function when available.
// Returns the score delta actually observed.
probe_add_points( player, pts )
{
	before = player.score;
	fn = getFunction( "maps/_zombiemode_score", "add_to_player_score" );
	level.probe_points_self = true;
	if ( isDefined( fn ) )
	{
		player [[ fn ]]( pts );
	}
	else
	{
		player.score = player.score + pts;
	}
	level.probe_points_self = undefined;
	return player.score - before;
}

probe_wait_hooks()
{
	while ( !isDefined( level.probe_hooks_ready ) )
	{
		wait 0.1;
	}
}

probe_enemies()
{
	return GetAiSpeciesArray( "axis", "all" );
}

// Waits for one zombie that this probe has not seen before.
probe_next_new_zombie()
{
	for ( ;; )
	{
		ai = probe_enemies();
		for ( i = 0; i < ai.size; i++ )
		{
			if ( isAlive( ai[ i ] ) && !isDefined( ai[ i ].probe_seen ) )
			{
				ai[ i ].probe_seen = true;
				return ai[ i ];
			}
		}
		wait 0.1;
	}
}

// Marks every zombie that already exists as seen, so only new spawns count.
probe_mark_existing_zombies()
{
	ai = probe_enemies();
	for ( i = 0; i < ai.size; i++ )
	{
		ai[ i ].probe_seen = true;
	}
}

probe_perk_list()
{
	return strTok( "specialty_quickrevive specialty_armorvest specialty_rof specialty_fastreload specialty_longersprint specialty_flakjacket specialty_deadshot specialty_additionalprimaryweapon", " " );
}

probe_count_perks( p )
{
	list = probe_perk_list();
	n = 0;
	for ( i = 0; i < list.size; i++ )
	{
		if ( p HasPerk( list[ i ] ) )
		{
			n++;
		}
	}
	return n;
}

probe_machine_perks()
{
	out = [];
	trigs = GetEntArray( "zombie_vending", "targetname" );
	for ( i = 0; i < trigs.size; i++ )
	{
		if ( isDefined( trigs[ i ].script_noteworthy ) )
		{
			out[ out.size ] = trigs[ i ].script_noteworthy;
		}
	}
	return out;
}

probe_in_array( arr, v )
{
	for ( i = 0; i < arr.size; i++ )
	{
		if ( arr[ i ] == v )
		{
			return true;
		}
	}
	return false;
}

// ---------------------------------------------------------------------------
// Hooks: wrap stock level callbacks (stock version is always called first)
// ---------------------------------------------------------------------------

probe_install_hooks()
{
	// Stock _zombiemode assigns these during load; wait for them, max 30s.
	t = 0;
	while ( !isDefined( level.overrideActorDamage ) && t < 300 )
	{
		wait 0.1;
		t++;
	}
	// Let any other script that sets callbacks late go first.
	for ( i = 0; i < 10; i++ )
	{
		waittillframeend;
	}

	level.probe_hook_actor_damage = isDefined( level.overrideActorDamage );
	level.probe_hook_actor_killed = isDefined( level.overrideActorKilled );
	level.probe_hook_player_damage = isDefined( level.overridePlayerDamage );

	level.probe_orig_actor_damage = level.overrideActorDamage;
	level.probe_orig_actor_killed = level.overrideActorKilled;
	level.probe_orig_player_damage = level.overridePlayerDamage;

	// Our wrappers are installed even if no stock callback existed;
	// the engine-side caller treats the return value as the final damage.
	level.overrideActorDamage = ::probe_actor_damage;
	level.overrideActorKilled = ::probe_actor_killed;
	level.overridePlayerDamage = ::probe_player_damage;

	logprint( "[PROBE-INFO] hooks: actor_damage_stock=" + level.probe_hook_actor_damage + " actor_killed_stock=" + level.probe_hook_actor_killed + " player_damage_stock=" + level.probe_hook_player_damage + "\n" );
	level.probe_hooks_ready = true;
}

probe_actor_damage( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, modelIndex, psOffsetTime )
{
	dmg = damage;
	if ( isDefined( level.probe_orig_actor_damage ) )
	{
		dmg = self [[ level.probe_orig_actor_damage ]]( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, modelIndex, psOffsetTime );
	}
	if ( !isDefined( dmg ) )
	{
		dmg = damage;
	}
	if ( isDefined( attacker ) && isPlayer( attacker ) )
	{
		dmg = self probe_on_actor_damage( attacker, dmg, meansofdeath, weapon, sHitLoc );
	}
	return dmg;
}

probe_on_actor_damage( attacker, dmg, mod, weapon, hitloc )
{
	if ( level.probe_on[ "B2" ] && !isDefined( level.probe_b2_spy ) )
	{
		level.probe_b2_spy = "wep=" + probe_str( weapon ) + " dmg=" + dmg + " hit=" + probe_str( hitloc ) + " mod=" + probe_str( mod );
	}

	// B2 modification: double one non-lethal hit, verify the health drop next frame.
	if ( level.probe_on[ "B2" ] && !isDefined( level.probe_b2_mod ) && dmg > 0 && dmg * 2 < self.health )
	{
		level.probe_b2_mod = "pending";
		self thread probe_verify_drop( "B2", self.health, dmg * 2, dmg );
		return dmg * 2;
	}

	// C3: double damage for the pistol class on one test zombie.
	if ( level.probe_on[ "C3" ] && !isDefined( level.probe_c3_mod ) && probe_weapon_class( weapon ) == "pistol" && dmg > 0 && dmg * 2 < self.health )
	{
		level.probe_c3_mod = "pending";
		self thread probe_verify_drop( "C3", self.health, dmg * 2, dmg );
		return dmg * 2;
	}
	return dmg;
}

probe_verify_drop( id, before, expected, original )
{
	waittillframeend;
	if ( !isDefined( self ) || !isAlive( self ) )
	{
		// Died from something else in the same frame: inconclusive, try again.
		if ( id == "B2" )
		{
			level.probe_b2_mod = undefined;
		}
		else
		{
			level.probe_c3_mod = undefined;
		}
		return;
	}
	drop = before - self.health;
	ok = ( drop >= expected - 1 && drop <= expected + 1 );
	if ( id == "B2" )
	{
		level.probe_b2_mod = ok;
		level.probe_b2_drop = "drop=" + drop + " want=" + expected + " base=" + original;
	}
	else
	{
		level.probe_c3_mod = ok;
		level.probe_c3_drop = "drop=" + drop + " want=" + expected + " base=" + original;
	}
}

probe_actor_killed( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime )
{
	if ( isDefined( level.probe_orig_actor_killed ) )
	{
		self [[ level.probe_orig_actor_killed ]]( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime );
	}
	if ( isDefined( attacker ) && isPlayer( attacker ) )
	{
		self probe_on_actor_killed( attacker, sMeansOfDeath, sWeapon, sHitLoc );
	}
}

probe_on_actor_killed( attacker, mod, weapon, hitloc )
{
	hs = probe_is_headshot( hitloc, mod );

	if ( level.probe_on[ "B3" ] )
	{
		if ( !isDefined( level.probe_b3_any ) )
		{
			level.probe_b3_any = "wep=" + probe_str( weapon ) + " hs=" + hs + " hit=" + probe_str( hitloc ) + " mod=" + probe_str( mod );
		}
		if ( hs && !isDefined( level.probe_b3_hs ) )
		{
			got = probe_add_points( attacker, 10 );
			level.probe_b3_hs = "wep=" + probe_str( weapon ) + " hs=1 hit=" + hitloc + " bonus+10->" + got;
			level.probe_b3_mod = ( got == 10 );
		}
	}

	// C4: refund one bullet to the clip on a headshot kill.
	if ( level.probe_on[ "C4" ] && hs && !isDefined( level.probe_c4 ) && isDefined( weapon ) && weapon != "none" && attacker HasWeapon( weapon ) )
	{
		clip = attacker GetWeaponAmmoClip( weapon );
		size = WeaponClipSize( weapon );
		if ( clip < size )
		{
			attacker SetWeaponAmmoClip( weapon, clip + 1 );
			after = attacker GetWeaponAmmoClip( weapon );
			level.probe_c4 = ( after == clip + 1 );
			level.probe_c4_ev = "wep=" + weapon + " clip " + clip + "->" + after + " size=" + size;
		}
	}

	// C5: two or more kills by one player in the same server frame = one shot.
	if ( level.probe_on[ "C5" ] )
	{
		now = getTime();
		if ( isDefined( attacker.probe_kill_ms ) && attacker.probe_kill_ms == now )
		{
			attacker.probe_kill_n++;
		}
		else
		{
			attacker.probe_kill_ms = now;
			attacker.probe_kill_n = 1;
		}
		if ( attacker.probe_kill_n == 2 && !isDefined( level.probe_c5 ) )
		{
			got = probe_add_points( attacker, 50 );
			level.probe_c5 = ( got == 50 );
			level.probe_c5_ev = "2 kills same frame wep=" + probe_str( weapon ) + " mod=" + probe_str( mod ) + " bonus+50->" + got;
		}
	}
}

probe_player_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime )
{
	dmg = iDamage;
	if ( isDefined( level.probe_orig_player_damage ) )
	{
		dmg = self [[ level.probe_orig_player_damage ]]( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime );
	}
	if ( !isDefined( dmg ) )
	{
		dmg = iDamage;
	}
	if ( level.probe_on[ "B8" ] )
	{
		if ( !isDefined( level.probe_b8_spy ) )
		{
			from = "other";
			if ( isDefined( eAttacker ) && isAI( eAttacker ) )
			{
				from = "ai";
			}
			level.probe_b8_spy = "dmg=" + dmg + " mod=" + probe_str( sMeansOfDeath ) + " from=" + from;
		}
		// Halve one hit (a buff, never a nerf) and verify the drop.
		half = int( dmg / 2 );
		if ( !isDefined( level.probe_b8_mod ) && half >= 1 && self.health > dmg + 1 )
		{
			level.probe_b8_mod = "pending";
			self thread probe_verify_player_drop( self.health, half );
			return half;
		}
	}
	return dmg;
}

probe_verify_player_drop( before, expected )
{
	waittillframeend;
	drop = before - self.health;
	level.probe_b8_mod = ( drop >= expected - 1 && drop <= expected + 1 );
	level.probe_b8_drop = "drop=" + drop + " want=" + expected;
}

// ---------------------------------------------------------------------------
// Batch B: hooks
// ---------------------------------------------------------------------------

probe_b1( id )
{
	level.probe_b1_connect = "no";
	level.probe_b1_spawn = "no";
	level thread probe_b1_listen( "connecting" );
	level thread probe_b1_listen( "connected" );
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		players[ i ] thread probe_b1_spawn_listen();
	}
	probe_stage( id, "wait:spawn into the map (or respawn next round in co-op)" );

	alive_for = 0;
	while ( level.probe_b1_spawn == "no" && alive_for < 15 )
	{
		players = GetPlayers();
		if ( players.size > 0 && isAlive( players[ 0 ] ) )
		{
			alive_for++;
		}
		wait 1;
	}
	ev = "connect_notify=" + level.probe_b1_connect + " spawned_notify=" + level.probe_b1_spawn + " init_before_player=" + level.probe_init_before_player + " main=" + isDefined( level.probe_main_ms );
	if ( level.probe_b1_spawn != "no" )
	{
		probe_result( id, "PASS", ev );
	}
	else
	{
		probe_result( id, "PARTIAL", ev );
	}
}

probe_b1_listen( note )
{
	for ( ;; )
	{
		level waittill( note, p );
		level.probe_b1_connect = note;
		if ( isDefined( p ) )
		{
			p thread probe_b1_spawn_listen();
		}
	}
}

probe_b1_spawn_listen()
{
	self waittill( "spawned_player" );
	level.probe_b1_spawn = "yes";
}

probe_b2( id )
{
	probe_stage( id, "wait:(automatic) hook install" );
	probe_wait_hooks();
	if ( !level.probe_hook_actor_damage )
	{
		probe_result( id, "FAIL", "level.overrideActorDamage undefined after 30s" );
		return;
	}
	probe_stage( id, "wait:shoot a zombie in the body (not a one-shot kill)" );
	while ( !isDefined( level.probe_b2_mod ) || level.probe_b2_mod == "pending" || !isDefined( level.probe_b2_spy ) )
	{
		wait 0.1;
	}
	if ( level.probe_b2_mod )
	{
		probe_mark_modifiable( id );
		probe_result( id, "PASS", level.probe_b2_spy + " | x2 " + level.probe_b2_drop );
	}
	else
	{
		probe_result( id, "PARTIAL", "spy ok, mod failed " + level.probe_b2_drop );
	}
}

probe_b3( id )
{
	probe_stage( id, "wait:(automatic) hook install" );
	probe_wait_hooks();
	if ( !level.probe_hook_actor_killed )
	{
		probe_result( id, "FAIL", "level.overrideActorKilled undefined after 30s" );
		return;
	}
	probe_stage( id, "wait:kill a zombie with a headshot" );
	while ( !isDefined( level.probe_b3_hs ) )
	{
		if ( getDvar( "probe_finish" ) == "1" && isDefined( level.probe_b3_any ) )
		{
			probe_result( id, "PARTIAL", "kills seen, no headshot kill: " + level.probe_b3_any );
			return;
		}
		wait 0.1;
	}
	if ( level.probe_b3_mod )
	{
		probe_mark_modifiable( id );
		probe_result( id, "PASS", level.probe_b3_hs );
	}
	else
	{
		probe_result( id, "PARTIAL", "spy ok, bonus failed: " + level.probe_b3_hs );
	}
}

probe_b4( id )
{
	p = probe_player();
	probe_stage( id, "wait:shoot a zombie to earn points" );
	last = p.score;
	natural = undefined;
	while ( !isDefined( natural ) )
	{
		wait 0.05;
		if ( p.score != last && !isDefined( level.probe_points_self ) )
		{
			natural = p.score - last;
		}
		last = p.score;
	}
	probe_stage( id, "modify" );
	fn = isDefined( getFunction( "maps/_zombiemode_score", "add_to_player_score" ) );
	got = probe_add_points( p, 5000 );
	scalar = "undef";
	if ( isDefined( p.zombie_vars ) && isDefined( p.zombie_vars[ "zombie_point_scalar" ] ) )
	{
		scalar = "" + p.zombie_vars[ "zombie_point_scalar" ];
	}
	ev = "spy +" + natural + " | add 5000 -> +" + got + " fn=" + fn + " scalar=" + scalar;
	if ( got == 5000 )
	{
		probe_mark_modifiable( id );
		probe_result( id, "PASS", ev );
	}
	else
	{
		probe_result( id, "PARTIAL", ev );
	}
}

probe_b5( id )
{
	probe_stage( id, "wait:finish the current round" );
	level waittill( "end_of_round" );
	r1 = level.round_number;
	t1 = getTime();
	probe_stage( id, "wait:wait for the next round to start" );
	level waittill( "start_of_round" );
	r2 = level.round_number;
	probe_result( id, "PASS", "end_of_round@r" + r1 + " start_of_round@r" + r2 + " gap=" + int( ( getTime() - t1 ) / 1000 ) + "s mod=n/a" );
}

probe_b6( id )
{
	p = probe_player();
	level.probe_b6_list = "no";
	p thread probe_b6_poll_list();
	probe_stage( id, "wait:buy a wall/box weapon, then swap weapons" );
	p waittill( "weapon_change", w );
	wait 1;
	probe_stage( id, "modify" );
	cur = p GetCurrentWeapon();
	ev = "weapon_change=" + probe_str( w ) + " list_change=" + level.probe_b6_list;
	if ( cur != "none" )
	{
		before = p GetWeaponAmmoStock( cur );
		p GiveMaxAmmo( cur );
		after = p GetWeaponAmmoStock( cur );
		ev = ev + " maxammo stock " + before + "->" + after;
		if ( after >= before )
		{
			probe_mark_modifiable( id );
		}
	}
	if ( level.probe_b6_list != "no" )
	{
		probe_result( id, "PASS", ev );
	}
	else
	{
		probe_result( id, "PARTIAL", ev );
	}
}

probe_b6_poll_list()
{
	self endon( "disconnect" );
	last = probe_join( self GetWeaponsList() );
	for ( ;; )
	{
		wait 0.25;
		now = probe_join( self GetWeaponsList() );
		if ( now != last )
		{
			level.probe_b6_list = "yes";
			probe_data( "B6", "list " + last + " -> " + now );
			return;
		}
	}
}

probe_b7( id )
{
	p = probe_player();
	level.probe_b7_notify = "no";
	p thread probe_b7_listen();
	start = p.num_perks;
	probe_stage( id, "wait:buy any perk (turn the power on first)" );
	while ( level.probe_b7_notify == "no" && probe_str( p.num_perks ) == probe_str( start ) )
	{
		wait 0.1;
	}
	wait 3;  // let the drink animation finish
	ev = "perk_bought=" + level.probe_b7_notify + " num_perks " + probe_str( start ) + "->" + probe_str( p.num_perks ) + " owned=" + probe_count_perks( p ) + " limit=num_perks>=4";
	probe_result( id, "PASS", ev );
}

probe_b7_listen()
{
	self waittill( "perk_bought", perk );
	level.probe_b7_notify = probe_str( perk );
}

probe_b8( id )
{
	p = probe_player();
	level.probe_b8_down = "no";
	level.probe_b8_revive = "no";
	p thread probe_b8_listen( "player_downed" );
	p thread probe_b8_listen( "player_revived" );
	probe_stage( id, "wait:(automatic) hook install" );
	probe_wait_hooks();
	if ( !level.probe_hook_player_damage )
	{
		probe_data( id, "no stock overridePlayerDamage; wrapper installed anyway" );
	}
	probe_stage( id, "wait:let a zombie hit you once" );
	while ( !isDefined( level.probe_b8_mod ) || level.probe_b8_mod == "pending" )
	{
		wait 0.1;
	}
	// Give down/revive a little longer if the user is testing it.
	probe_stage( id, "wait:optional - go down and get revived (needs Quick Revive solo)" );
	t = 0;
	while ( level.probe_b8_revive == "no" && t < 60 && getDvar( "probe_finish" ) != "1" )
	{
		wait 1;
		t++;
	}
	ev = level.probe_b8_spy + " half " + level.probe_b8_drop + " down=" + level.probe_b8_down + " rev=" + level.probe_b8_revive;
	if ( level.probe_b8_mod )
	{
		probe_mark_modifiable( id );
		probe_result( id, "PASS", ev );
	}
	else
	{
		probe_result( id, "PARTIAL", ev );
	}
}

probe_b8_listen( note )
{
	self waittill( note );
	if ( note == "player_downed" )
	{
		level.probe_b8_down = "yes";
	}
	else
	{
		level.probe_b8_revive = "yes";
	}
}

probe_b9( id )
{
	probe_stage( id, "spawnwatch" );
	probe_player();
	probe_mark_existing_zombies();
	probe_stage( id, "wait:wait for a zombie to spawn" );
	z = probe_next_new_zombie();
	hp0 = z.health;
	wait 0.5;  // let stock spawn init set its health
	if ( !isDefined( z ) || !isAlive( z ) )
	{
		probe_result( id, "PARTIAL", "spawn seen hp0=" + hp0 + ", died before modify" );
		return;
	}
	hp1 = z.health;
	z.maxhealth = hp1 + 100;
	z.health = hp1 + 100;
	wait 1;
	if ( !isDefined( z ) || !isAlive( z ) )
	{
		probe_result( id, "PARTIAL", "spawn hp0=" + hp0 + " hp=" + hp1 + ", died before readback" );
		return;
	}
	stuck = ( z.health >= hp1 + 100 );
	ev = "spawn hp0=" + hp0 + " hp=" + hp1 + " lvl_hp=" + probe_str( level.zombie_health ) + " +100 stuck=" + stuck;
	if ( stuck )
	{
		probe_mark_modifiable( id );
		probe_result( id, "PASS", ev );
	}
	else
	{
		probe_result( id, "PARTIAL", ev );
	}
}

// ---------------------------------------------------------------------------
// Batch C: capabilities
// ---------------------------------------------------------------------------

probe_c1( id )
{
	p = probe_player();
	probe_stage( id, "draw" );

	letter = NewClientHudElem( p );
	letter.horzAlign = "user_left";
	letter.vertAlign = "middle";
	letter.alignX = "left";
	letter.alignY = "middle";
	letter.x = 12;
	letter.y = -60;
	letter.fontScale = 3;
	letter.foreground = true;
	letter.alpha = 1;
	letter SetText( "D" );

	bg = NewClientHudElem( p );
	bg.horzAlign = "user_left";
	bg.vertAlign = "middle";
	bg.alignX = "left";
	bg.alignY = "middle";
	bg.x = 12;
	bg.y = -30;
	bg.alpha = 0.5;
	bg.color = ( 0.1, 0.1, 0.1 );
	bg SetShader( "white", 120, 6 );

	bar = NewClientHudElem( p );
	bar.horzAlign = "user_left";
	bar.vertAlign = "middle";
	bar.alignX = "left";
	bar.alignY = "middle";
	bar.x = 12;
	bar.y = -30;
	bar.foreground = true;
	bar.alpha = 1;
	bar.color = ( 1, 0.7, 0.1 );
	bar SetShader( "white", 1, 6 );

	pop = NewClientHudElem( p );
	pop.horzAlign = "user_center";
	pop.vertAlign = "middle";
	pop.alignX = "center";
	pop.alignY = "middle";
	pop.y = -120;
	pop.fontScale = 1.6;
	pop.alpha = 0;
	pop SetText( "PROBE: RANK UP" );

	probe_stage( id, "update" );
	ranks = strTok( "D C B A S SS SSS", " " );
	for ( r = 0; r < ranks.size; r++ )
	{
		letter SetText( ranks[ r ] );
		for ( f = 1; f <= 4; f++ )
		{
			bar SetShader( "white", 30 * f, 6 );
			wait 0.25;
		}
		pop FadeOverTime( 0.2 );
		pop.alpha = 1;
		wait 0.4;
		pop FadeOverTime( 0.3 );
		pop.alpha = 0;
		bar SetShader( "white", 1, 6 );
		probe_stage( id, "update" );
	}

	probe_stage( id, "wait:finish a round (HUD should hide at round end)" );
	level waittill( "end_of_round" );
	letter.alpha = 0;
	bg.alpha = 0;
	bar.alpha = 0;
	probe_result( id, "PASS", "drawn, 7 ranks, hid at round end - CONFIRM: seen at left middle?" );
	level waittill( "start_of_round" );
	letter Destroy();
	bg Destroy();
	bar Destroy();
	pop Destroy();
}

probe_c2( id )
{
	p = probe_player();
	wait 6;
	aliases = strTok( "zmb_cha_ching evt_perk_deny zmb_perks_power_on zmb_switch_flip", " " );
	for ( i = 0; i < aliases.size; i++ )
	{
		probe_stage( id, "play " + aliases[ i ] );
		p iPrintLnBold( "C2 sound " + ( i + 1 ) + ": " + aliases[ i ] );
		p PlayLocalSound( aliases[ i ] );
		wait 3;
	}
	probe_result( id, "PARTIAL", "played 1-4 (" + probe_join( aliases ) + ") - tell me which you heard" );
}

probe_c3( id )
{
	probe_stage( id, "wait:(automatic) hook install" );
	probe_wait_hooks();
	if ( !level.probe_hook_actor_damage )
	{
		probe_result( id, "SKIPPED", "prereq B2: actor damage hook unavailable" );
		return;
	}
	probe_stage( id, "wait:shoot a zombie in the body with a pistol" );
	while ( !isDefined( level.probe_c3_mod ) || level.probe_c3_mod == "pending" )
	{
		wait 0.1;
	}
	if ( level.probe_c3_mod )
	{
		probe_result( id, "PASS", "pistol x2 " + level.probe_c3_drop );
	}
	else
	{
		probe_result( id, "FAIL", "pistol x2 not applied " + level.probe_c3_drop );
	}
}

probe_c4( id )
{
	probe_stage( id, "wait:(automatic) hook install" );
	probe_wait_hooks();
	if ( !level.probe_hook_actor_killed )
	{
		probe_result( id, "SKIPPED", "prereq B3: actor killed hook unavailable" );
		return;
	}
	probe_stage( id, "wait:fire a few shots, then headshot-kill a zombie" );
	while ( !isDefined( level.probe_c4 ) )
	{
		wait 0.1;
	}
	if ( level.probe_c4 )
	{
		probe_result( id, "PASS", level.probe_c4_ev );
	}
	else
	{
		probe_result( id, "FAIL", level.probe_c4_ev );
	}
}

probe_c5( id )
{
	probe_stage( id, "wait:(automatic) hook install" );
	probe_wait_hooks();
	if ( !level.probe_hook_actor_killed )
	{
		probe_result( id, "SKIPPED", "prereq B3: actor killed hook unavailable" );
		return;
	}
	probe_stage( id, "wait:kill 2+ zombies with one grenade or one piercing shot" );
	while ( !isDefined( level.probe_c5 ) )
	{
		wait 0.1;
	}
	if ( level.probe_c5 )
	{
		probe_result( id, "PASS", level.probe_c5_ev );
	}
	else
	{
		probe_result( id, "PARTIAL", "multi-kill seen, bonus failed: " + level.probe_c5_ev );
	}
}

probe_c6( id )
{
	p = probe_player();
	wait 2;
	machines = probe_machine_perks();
	probe_data( id, "machines=" + probe_join( machines ) + " num_perks=" + probe_str( p.num_perks ) );
	if ( !isDefined( p.num_perks ) )
	{
		probe_result( id, "FAIL", "player.num_perks undefined; limit mechanism unknown" );
		return;
	}
	// The stock limit check is num_perks >= 4: offset it far below the limit.
	p.num_perks = p.num_perks - 100;
	p thread probe_c6_keep_offset();
	probe_stage( id, "wait:buy perks from machines (map has " + machines.size + " machines)" );
	bought = 0;
	last = p.num_perks;
	while ( probe_count_perks( p ) < 5 )
	{
		if ( p.num_perks > last )
		{
			bought++;
		}
		last = p.num_perks;
		if ( getDvar( "probe_finish" ) == "1" )
		{
			break;
		}
		wait 0.2;
	}
	owned = probe_count_perks( p );
	ev = "owned=" + owned + " bought_with_offset=" + bought + " num_perks=" + p.num_perks + " machines=" + machines.size;
	if ( owned >= 5 )
	{
		probe_result( id, "PASS", ev );
	}
	else if ( bought > 0 )
	{
		probe_result( id, "PARTIAL", ev + " (need 5+ machines)" );
	}
	else
	{
		probe_result( id, "BLOCKED", "buy a perk; for full test use zombie_temple/coast/moon" );
	}
}

// Stock may reset num_perks on down/respawn; keep the offset applied.
probe_c6_keep_offset()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		wait 0.5;
		if ( isDefined( self.num_perks ) && self.num_perks >= 0 )
		{
			self.num_perks = self.num_perks - 100;
		}
	}
}

probe_c7( id )
{
	p = probe_player();
	wait 3;
	machines = probe_machine_perks();
	probe_data( id, "machines on " + getDvar( "mapname" ) + ": " + probe_join( machines ) );

	// Pick a perk whose machine is NOT on this map.
	list = probe_perk_list();
	perk = undefined;
	for ( i = 0; i < list.size; i++ )
	{
		if ( !probe_in_array( machines, list[ i ] ) )
		{
			perk = list[ i ];
			break;
		}
	}
	if ( !isDefined( perk ) )
	{
		probe_result( id, "PASS", "all 8 perk machines exist on this map: " + machines.size );
		return;
	}

	probe_stage( id, "spawn shop" );
	trig = Spawn( "trigger_radius_use", p.origin + ( 0, 0, 30 ), 0, 48, 72 );
	trig SetCursorHint( "HINT_NOICON" );
	trig SetHintString( "PROBE SHOP: hold USE for " + perk );
	p iPrintLnBold( "C7: probe shop placed where you stand. Hold USE there." );

	probe_stage( id, "wait:stand where the C7 message appeared and hold USE" );
	trig waittill( "trigger", who );
	who SetPerk( perk );
	wait 0.1;
	has = who HasPerk( perk );
	trig Delete();
	ev = "machines=" + machines.size + " shop gave " + perk + " has=" + has + " - CONFIRM hint text shown?";
	if ( has )
	{
		probe_result( id, "PARTIAL", ev );
	}
	else
	{
		probe_result( id, "FAIL", ev );
	}
}

probe_c8( id )
{
	p = probe_player();
	wait 2;
	probe_stage( id, "dvar" );
	orig = getDvar( "perk_weapRateMultiplier" );
	if ( getDvar( "probe_c8_orig" ) == "" )
	{
		setDvar( "probe_c8_orig", orig );
	}
	setDvar( "perk_weapRateMultiplier", "0.5" );
	p SetClientDvar( "perk_weapRateMultiplier", "0.5" );
	now = getDvar( "perk_weapRateMultiplier" );
	cur = p GetCurrentWeapon();
	ft = "n/a";
	if ( cur != "none" )
	{
		ft = "" + WeaponFireTime( cur );
	}
	level thread probe_c8_restore();
	probe_stage( id, "wait:buy Double Tap and compare fire rate (set probe_finish 1 when done)" );
	dt = p HasPerk( "specialty_rof" );
	while ( !dt && getDvar( "probe_finish" ) != "1" )
	{
		wait 0.5;
		dt = p HasPerk( "specialty_rof" );
	}
	ev = "perk_weapRateMultiplier " + orig + "->" + now + " firetime=" + ft + " dt=" + dt + " - faster?";
	if ( now == "0.5" )
	{
		probe_result( id, "PARTIAL", ev );
	}
	else
	{
		probe_result( id, "FAIL", ev );
	}
}

probe_c8_restore()
{
	level waittill( "end_game" );
	orig = getDvar( "probe_c8_orig" );
	if ( orig != "" )
	{
		setDvar( "perk_weapRateMultiplier", orig );
		setDvar( "probe_c8_orig", "" );
	}
}

probe_c9( id )
{
	probe_player();
	wait 2;
	probe_stage( id, "read" );
	delay0 = probe_str( level.zombie_vars[ "zombie_spawn_delay" ] );
	maxai = probe_str( level.zombie_vars[ "zombie_max_ai" ] );
	limit0 = probe_str( level.zombie_ai_limit );
	hp0 = probe_str( level.zombie_health );

	level.zombie_vars[ "zombie_spawn_delay" ] = 0.5;
	if ( isDefined( level.zombie_ai_limit ) )
	{
		level.zombie_ai_limit = 32;
	}
	probe_data( id, "delay=" + delay0 + " max_ai=" + maxai + " ai_limit=" + limit0 + " zombie_health=" + hp0 );

	probe_stage( id, "spawnwatch" );
	probe_mark_existing_zombies();
	probe_stage( id, "wait:play into the next round (watch spawn speed)" );
	z = probe_next_new_zombie();
	wait 0.5;
	scaled = "died";
	if ( isDefined( z ) && isAlive( z ) )
	{
		h = z.health;
		z.maxhealth = int( h * 1.5 );
		z.health = int( h * 1.5 );
		scaled = h + "->" + z.health;
	}

	peak = 0;
	level waittill( "start_of_round" );
	for ( t = 0; t < 60; t++ )
	{
		n = probe_enemies().size;
		if ( n > peak )
		{
			peak = n;
		}
		wait 1;
	}
	ev = "delay " + delay0 + "->" + level.zombie_vars[ "zombie_spawn_delay" ] + " ai_limit=" + limit0 + " peak=" + peak + " hp x1.5 " + scaled;
	if ( isDefined( level.zombie_ai_limit ) )
	{
		probe_result( id, "PASS", ev );
	}
	else
	{
		probe_result( id, "PARTIAL", ev + " (cap hardcoded?)" );
	}
}

probe_c10( id )
{
	p = probe_player();
	wait 2;
	probe_stage( id, "list" );
	keys = [];
	if ( isDefined( level.zombie_weapons ) )
	{
		keys = getArrayKeys( level.zombie_weapons );
	}
	probe_data( id, "zombie_weapons(" + keys.size + ")=" + probe_join( keys ) );

	// In-pool give: first registered weapon the player does not already have.
	probe_stage( id, "give in-pool" );
	pool = "none";
	for ( i = 0; i < keys.size; i++ )
	{
		c = probe_weapon_class( keys[ i ] );
		owned = p HasWeapon( keys[ i ] );
		if ( ( c == "smg" || c == "rifle" || c == "spread" || c == "pistol" ) && !owned )
		{
			p GiveWeapon( keys[ i ] );
			owned = p HasWeapon( keys[ i ] );
			pool = keys[ i ] + ":" + owned;
			wait 2;
			p TakeWeapon( keys[ i ] );
			break;
		}
	}

	foreign = getDvar( "probe_c10_weapon" );
	if ( foreign == "" )
	{
		probe_result( id, "PARTIAL", "pool=" + keys.size + " give " + pool + " | foreign: set probe_c10_weapon <name>" );
		return;
	}
	// Breadcrumb first: if the game crashes now, this is the last log line.
	logprint( "[PROBE-TRY] C10 giving foreign weapon " + foreign + "\n" );
	probe_stage( id, "give foreign " + foreign );
	p GiveWeapon( foreign );
	wait 0.5;
	has = p HasWeapon( foreign );
	ev = "pool=" + keys.size + " give " + pool + " | foreign " + foreign + " has=" + has;
	if ( has )
	{
		p SwitchToWeapon( foreign );
		probe_result( id, "PASS", ev + " CONFIRM model/fire ok?" );
	}
	else
	{
		probe_result( id, "PARTIAL", ev );
	}
}

probe_c11( id )
{
	probe_player();
	probe_data( id, "special AI: " + probe_c11_special_ai() );
	probe_stage( id, "spawnwatch" );
	probe_mark_existing_zombies();
	probe_stage( id, "wait:wait for a zombie to spawn (it becomes the boss)" );
	boss = probe_next_new_zombie();
	wait 0.5;
	if ( !isDefined( boss ) || !isAlive( boss ) )
	{
		probe_result( id, "FAIL", "boss candidate died before setup" );
		return;
	}
	boss.maxhealth = 4000;
	boss.health = 4000;
	boss.probe_boss = true;
	level.probe_c11_phase = 1;
	level.probe_c11_ticks = 0;
	boss thread probe_c11_hazard();
	boss thread probe_c11_phase();
	players = GetPlayers();
	players[ 0 ] iPrintLnBold( "C11: next zombie is a 4000hp boss. Screen shake = hazard pulse." );

	probe_stage( id, "wait:shoot the boss below half health, then kill it" );
	boss waittill( "death" );
	ev = "hp=4000 phase=" + level.probe_c11_phase + " hazard_ticks=" + level.probe_c11_ticks + " ai=" + probe_c11_special_ai();
	if ( level.probe_c11_phase >= 2 && level.probe_c11_ticks >= 1 )
	{
		probe_result( id, "PASS", ev );
	}
	else
	{
		probe_result( id, "PARTIAL", ev );
	}
}

probe_c11_hazard()
{
	self endon( "death" );
	for ( ;; )
	{
		wait 6;
		Earthquake( 0.35, 1.0, self.origin, 600 );
		RadiusDamage( self.origin + ( 0, 0, 30 ), 160, 25, 5 );
		level.probe_c11_ticks++;
	}
}

probe_c11_phase()
{
	self endon( "death" );
	while ( self.health > self.maxhealth / 2 )
	{
		wait 0.2;
	}
	level.probe_c11_phase = 2;
	self.moveplaybackrate = 1.5;
	fn = getFunction( "maps/_zombiemode_spawner", "set_zombie_run_cycle" );
	if ( isDefined( fn ) )
	{
		self [[ fn ]]( "sprint" );
	}
	players = GetPlayers();
	players[ 0 ] iPrintLnBold( "C11: boss phase 2 (sprint)" );
}

probe_c11_special_ai()
{
	switch ( getDvar( "mapname" ) )
	{
		case "zombie_theater":
		case "zombie_cod5_factory":
			return "dogs";
		case "zombie_pentagon":
			return "thief,dogs";
		case "zombie_cosmodrome":
			return "monkeys";
		case "zombie_coast":
			return "director";
		case "zombie_temple":
			return "napalm,sonic,monkey";
		case "zombie_moon":
			return "astronaut,quad";
		case "zombie_cod5_asylum":
		case "zombie_cod5_prototype":
		case "zombie_cod5_sumpf":
			return "none/dogs?";
	}
	return "unknown";
}

probe_c12( id )
{
	p = probe_player();
	setDvar( "probe_codex", "0" );
	probe_stage( id, "wait:console: set probe_codex 1 (or bind a key to it); also hold ADS+USE" );
	combo = "no";
	t0 = getTime();
	while ( getDvar( "probe_codex" ) != "1" )
	{
		if ( p AdsButtonPressed() && p UseButtonPressed() )
		{
			combo = "yes";
		}
		wait 0.05;
	}
	setDvar( "probe_codex", "0" );
	probe_result( id, "PASS", "dvar toggle seen after " + int( ( getTime() - t0 ) / 1000 ) + "s; ads+use combo=" + combo );
}

probe_c13( id )
{
	p = probe_player();
	probe_stage( id, "wait:finish a round" );
	level waittill( "end_of_round" );
	msg = NewClientHudElem( p );
	msg.horzAlign = "user_center";
	msg.vertAlign = "middle";
	msg.alignX = "center";
	msg.alignY = "middle";
	msg.y = -150;
	msg.fontScale = 1.4;
	msg.alpha = 1;
	msg SetText( "PROBE: between rounds" );
	t0 = getTime();
	probe_stage( id, "wait:wait for the next round to start" );
	level waittill( "start_of_round" );
	msg Destroy();
	probe_result( id, "PASS", "shown end_of_round -> hidden start_of_round, break=" + int( ( getTime() - t0 ) / 1000 ) + "s" );
}
