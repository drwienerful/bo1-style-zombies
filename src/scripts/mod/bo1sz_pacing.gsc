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
	if ( pace_bal( "supplement" ) == 1 )
	{
		level thread pace_supplement();
	}
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
				if ( peak > 24 && peak % 8 == 1 )
				{
					pace_log_raw( "peak alive now " + peak );
				}
			}
			wait 0.5;
		}
		limit = "undef";
		if ( isDefined( level.zombie_ai_limit ) )
		{
			limit = "" + level.zombie_ai_limit;
		}
		extra = "";
		if ( isDefined( level.bo1sz_pace_tries ) )
		{
			extra = " supplement_tries=" + level.bo1sz_pace_tries + " fails=" + level.bo1sz_pace_fails;
			level.bo1sz_pace_tries = 0;
			level.bo1sz_pace_fails = 0;
		}
		pace_log_raw( "round " + level.round_number + " length=" + int( ( getTime() - start_ms ) / 1000 ) + "s peak_alive=" + peak + " limit=" + limit + " zombie_health=" + level.zombie_health + " spawn_delay=" + level.zombie_vars[ "zombie_spawn_delay" ] + extra );
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

// ---------------------------------------------------------------------------
// Supplemental spawner. Playtest 2026-10-05: with level.zombie_ai_limit at 128,
// spawning still stopped at 24, so stock's loop has its own fixed limit. This thread
// spawns the extra zombies (stock_fixed_limit .. cap) the way stock does: stock's
// spawn_zombie on a random active spawner, one off level.zombie_total, and stock's
// stuck-zombie failsafe. It never runs during special rounds or while stock spawning
// is paused. Attempts and failures are logged per round to find the engine's limit.
// ---------------------------------------------------------------------------

pace_flag( name )
{
	return ( isDefined( level.flag ) && isDefined( level.flag[ name ] ) && level.flag[ name ] );
}

pace_supplement()
{
	spawn_fn = getFunction( "maps/_zombiemode_utility", "spawn_zombie" );
	failsafe = getFunction( "maps/_zombiemode", "round_spawn_failsafe" );
	pace_log_raw( "supplemental spawner (spawn fn=" + isDefined( spawn_fn ) + " failsafe=" + isDefined( failsafe ) + ")" );
	if ( !isDefined( spawn_fn ) )
	{
		return;
	}
	level.bo1sz_pace_tries = 0;
	level.bo1sz_pace_fails = 0;
	for ( ;; )
	{
		delay = 0.5;
		if ( isDefined( level.zombie_vars[ "zombie_spawn_delay" ] ) )
		{
			delay = level.zombie_vars[ "zombie_spawn_delay" ];
		}
		wait delay;
		wait 0.05;

		if ( level.round_number < pace_cap_round() || !isDefined( level.zombie_total ) || level.zombie_total <= 0 )
		{
			continue;
		}
		if ( pace_flag( "dog_round" ) || pace_flag( "thief_round" ) || pace_flag( "monkey_round" ) || pace_flag( "enter_nml" ) )
		{
			continue;
		}
		if ( isDefined( level.flag ) && isDefined( level.flag[ "spawn_zombies" ] ) && !level.flag[ "spawn_zombies" ] )
		{
			continue;
		}
		alive = GetAiSpeciesArray( "axis", "all" ).size;
		if ( alive < pace_bal( "stock_fixed_limit" ) || alive >= pace_bal( "cap" ) )
		{
			continue;
		}
		if ( !isDefined( level.enemy_spawns ) || level.enemy_spawns.size == 0 )
		{
			continue;
		}
		spawner = level.enemy_spawns[ RandomInt( level.enemy_spawns.size ) ];
		level.bo1sz_pace_tries++;
		ai = [[ spawn_fn ]]( spawner );
		if ( isDefined( ai ) )
		{
			level.zombie_total--;
			if ( isDefined( failsafe ) )
			{
				ai thread [[ failsafe ]]();
			}
		}
		else
		{
			level.bo1sz_pace_fails++;
		}
	}
}
