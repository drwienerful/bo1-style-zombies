// bo1-style-zombies: pacing (Milestone 6). Approved by the user on 2026-10-05:
//   - spawn delay: an extra x0.9 per round on top of stock's x0.95 (same 0.08 floor)
//   - zombie health growth after round 10: x1.07 per round instead of x1.10
// Zombies per round are unchanged. Values: data/balance/pacing.csv.
//
// Max zombies alive stays at 24: the user asked for 128, but the engine refuses any
// spawn past 24 alive, with both DoSpawn and the force-spawn (tested 2026-10-05, see
// docs/platform_findings.md).
//
// Dvars: bo1sz_pacing 0 disables (stock pacing); bo1sz_pacing_flood 1 (in game, testing
// only) adds 100 zombies to the current round; bo1sz_pacing_hud 1 shows the live count.

init()
{
	if ( getDvar( "zombiemode" ) != "1" && !( isDefined( level.is_zombie_level ) && level.is_zombie_level ) )
	{
		return;
	}
	if ( getDvar( "bo1sz_enable" ) == "0" || getDvar( "bo1sz_pacing" ) == "0" )
	{
		pace_log_raw( "pacing off (stock)" );
		level thread pace_round_log();
		level thread pace_monitor();
		return;
	}
	// Started here, not in pace_start(): round 1's "start_of_round" can fire before
	// pace_start() finishes waiting for its data.
	level thread pace_round_log();
	level thread pace_monitor();
	level thread pace_start();
}

pace_start()
{
	t = 0;
	while ( ( !isDefined( level.bo1sz_bal ) || !isDefined( level.zombie_vars ) || !isDefined( level.zombie_vars[ "zombie_health_increase_multiplier" ] ) ) && t < 200 )
	{
		wait 0.05;
		t++;
	}
	if ( !isDefined( level.bo1sz_bal ) || !isDefined( level.zombie_vars ) )
	{
		pace_log_raw( "balance or zombie vars missing; pacing off" );
		return;
	}
	level.zombie_vars[ "zombie_health_increase_multiplier" ] = pace_bal( "health_growth_mult" );
	pace_log_raw( "pacing on (spawn delay x" + pace_bal( "spawn_delay_extra_mult" ) + "/round, health growth " + pace_bal( "health_growth_mult" ) + ")" );

	level thread pace_flood_command();
	for ( ;; )
	{
		level waittill( "start_of_round" );
		// Stock updates its own spawn delay around the round start; apply ours after it.
		wait 0.05;
		pace_faster_spawns();
	}
}

pace_bal( key )
{
	return level.bo1sz_bal[ "pacing." + key ];
}


pace_log_raw( msg )
{
	line = "[BO1SZ] pacing: " + msg;
	println( line );
	logprint( line + "\n" );
}


pace_faster_spawns()
{
	d = level.zombie_vars[ "zombie_spawn_delay" ] * pace_bal( "spawn_delay_extra_mult" );
	if ( d < pace_bal( "spawn_delay_floor" ) )
	{
		d = pace_bal( "spawn_delay_floor" );
	}
	level.zombie_vars[ "zombie_spawn_delay" ] = d;
}

// One line per round: length, peak zombies alive, health and spawn settings.
// Runs with pacing on or off, so stock and modded runs can be compared.
pace_round_log()
{
	for ( ;; )
	{
		level waittill( "start_of_round" );
		start_ms = getTime();
		peak = 0;
		level.bo1sz_pace_round_over = false;
		level thread pace_wait_end();
		while ( !level.bo1sz_pace_round_over )
		{
			n = GetAiSpeciesArray( "axis", "all" ).size;
			if ( n > peak )
			{
				peak = n;
			}
			wait 0.5;
		}
		limit = "undef";
		if ( isDefined( level.zombie_ai_limit ) )
		{
			limit = "" + level.zombie_ai_limit;
		}
		pace_log_raw( "round " + level.round_number + " length=" + int( ( getTime() - start_ms ) / 1000 ) + "s peak_alive=" + peak + " limit=" + limit + " zombie_health=" + level.zombie_health + " spawn_delay=" + level.zombie_vars[ "zombie_spawn_delay" ] );
	}
}

pace_wait_end()
{
	level waittill( "end_of_round" );
	level.bo1sz_pace_round_over = true;
}

// Testing aid: add 100 zombies to the current round.
pace_flood_command()
{
	setDvar( "bo1sz_pacing_flood", "0" );
	for ( ;; )
	{
		wait 0.5;
		v = getDvar( "bo1sz_pacing_flood" );
		if ( v == "" || v == "0" )
		{
			continue;
		}
		setDvar( "bo1sz_pacing_flood", "0" );
		if ( isDefined( level.zombie_total ) )
		{
			level.zombie_total += 100;
			pace_log_raw( "flood: +100 zombies this round (zombie_total=" + level.zombie_total + ")" );
		}
	}
}




// Live monitor, started from init() so it can't miss round 1. Logs every new peak above
// 24 (should never happen: engine limit). "set bo1sz_pacing_hud 1" shows the live count.
pace_monitor()
{
	peak = 0;
	hud = undefined;
	shown = -1;
	for ( ;; )
	{
		wait 0.5;
		n = GetAiSpeciesArray( "axis", "all" ).size;
		if ( n > peak )
		{
			peak = n;
			if ( peak > 24 )
			{
				pace_log_raw( "peak alive now " + peak );
			}
		}

		if ( getDvar( "bo1sz_pacing_hud" ) == "1" )
		{
			players = GetPlayers();
			if ( !isDefined( hud ) && players.size > 0 )
			{
				hud = NewClientHudElem( players[ 0 ] );
				hud.horzAlign = "user_center";
				hud.vertAlign = "middle";
				hud.alignX = "center";
				hud.alignY = "middle";
				hud.y = 160;
				hud.fontScale = 1.4;
				hud.foreground = true;
			}
			if ( isDefined( hud ) && n != shown )
			{
				shown = n;
				hud SetText( "Zombies alive: " + n + "  (peak " + peak + ")" );
				hud.alpha = 1;
			}
		}
		else if ( isDefined( hud ) && hud.alpha > 0 )
		{
			hud.alpha = 0;
			shown = -1;
		}
	}
}
