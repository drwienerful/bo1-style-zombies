// bo1-style-zombies: pacing (Milestone 6). Approved by the user on 2026-10-05:
//   - max zombies alive at once: stock 24, pacing.cap (128, user request) from cap_round
//   - spawn delay: an extra x0.9 per round on top of stock's x0.95 (same 0.08 floor)
//   - zombie health growth after round 10: x1.07 per round instead of x1.10
// Zombies per round are unchanged. All values: data/balance/pacing.csv.
//
// The engine's actor limit may sit below the requested cap: failed spawns are retried
// by stock, and the per-round log below records the real peak.
//
// Dvars: bo1sz_pacing 0 disables (stock pacing); bo1sz_pacing_test 1 applies the cap
// from round 1 for testing; bo1sz_pacing_flood 1 (in game, testing only) adds 100
// zombies to the current round to find the engine's real limit.

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
		return;
	}
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
	level.bo1sz_stock_ai_limit = 24;
	if ( isDefined( level.zombie_ai_limit ) )
	{
		level.bo1sz_stock_ai_limit = level.zombie_ai_limit;
	}
	level.zombie_vars[ "zombie_health_increase_multiplier" ] = pace_bal( "health_growth_mult" );
	pace_log_raw( "pacing on (cap " + pace_bal( "cap" ) + " from round " + pace_cap_round() + ", stock limit " + level.bo1sz_stock_ai_limit + ")" );

	level thread pace_round_log();
	level thread pace_flood_command();
	pace_apply();
	for ( ;; )
	{
		level waittill( "start_of_round" );
		// Stock updates its own spawn delay around the round start; apply ours after it.
		wait 0.05;
		pace_apply();
		pace_faster_spawns();
	}
}

pace_bal( key )
{
	return level.bo1sz_bal[ "pacing." + key ];
}

pace_cap_round()
{
	if ( getDvar( "bo1sz_pacing_test" ) == "1" )
	{
		return 1;
	}
	return pace_bal( "cap_round" );
}

pace_log_raw( msg )
{
	line = "[BO1SZ] pacing: " + msg;
	println( line );
	logprint( line + "\n" );
}

pace_apply()
{
	if ( level.round_number >= pace_cap_round() )
	{
		level.zombie_ai_limit = pace_bal( "cap" );
	}
	else
	{
		level.zombie_ai_limit = level.bo1sz_stock_ai_limit;
	}
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
