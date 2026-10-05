// bo1sz Phase 0, Batch A: load-location beacon.
// tools/install.ps1 -Batch A stamps the A-id and folder label into one copy per
// candidate folder (bo1sz_beacon_a1.gsc ... a5). Each copy reports whether it was
// loaded; the lowest-numbered loaded copy also prints the batch summary.
// Uses only builtins proven by stock or Plutonium-shipped scripts.

beacon_id()
{
	return "__ID__";
}

beacon_where()
{
	return "__WHERE__";
}

main()
{
	if ( !isDefined( level.probe_a_main ) )
	{
		level.probe_a_main = [];
	}
	level.probe_a_main[ beacon_id() ] = getTime();
}

init()
{
	if ( !isDefined( level.probe_a_init ) )
	{
		level.probe_a_init = [];
	}
	level.probe_a_init[ beacon_id() ] = getTime();

	if ( getDvar( "zombiemode" ) != "1" && !( isDefined( level.is_zombie_level ) && level.is_zombie_level ) )
	{
		return;
	}
	level thread beacon_report();
}

beacon_report()
{
	players = GetPlayers();
	while ( players.size == 0 )
	{
		wait 0.5;
		players = GetPlayers();
	}
	wait 8;

	id = beacon_id();
	main_ran = "no";
	if ( isDefined( level.probe_a_main ) && isDefined( level.probe_a_main[ id ] ) )
	{
		main_ran = "yes@" + level.probe_a_main[ id ];
	}
	beacon_emit( beacon_line( id, "PASS", "loaded " + beacon_where() + " init@" + level.probe_a_init[ id ] + " main=" + main_ran ) );

	// Only the first loaded beacon (in A1..A5 order) writes the summary.
	ids = beacon_all_ids();
	first = undefined;
	for ( i = 0; i < ids.size; i++ )
	{
		if ( isDefined( level.probe_a_init[ ids[ i ] ] ) )
		{
			first = ids[ i ];
			break;
		}
	}
	if ( !isDefined( first ) || first != id )
	{
		return;
	}

	wait 1;
	passed = 0;
	failed = 0;
	skipped = 0;
	canonical = "unknown";
	for ( i = 0; i < ids.size; i++ )
	{
		other = ids[ i ];
		if ( isDefined( level.probe_a_init[ other ] ) )
		{
			passed++;
			if ( canonical == "unknown" )
			{
				canonical = beacon_label( other );
			}
		}
		else if ( other == "A5" && !isSubStr( toLower( getDvar( "fs_game" ) ), "bo1sz" ) )
		{
			skipped++;
			beacon_emit( beacon_line( other, "SKIPPED", "prereq: load mods/bo1sz_probe from the Mods menu" ) );
		}
		else
		{
			failed++;
			beacon_emit( beacon_line( other, "FAIL", "not loaded from " + beacon_label( other ) ) );
		}
	}

	next = "B";
	reason = "none";
	if ( passed == 0 )
	{
		next = "done";
		reason = "no load path works";
	}
	beacon_emit( "[PROBE] ==== BATCH A SUMMARY ====" );
	beacon_emit( "[PROBE] passed=" + passed + " partial=0 failed=" + failed + " blocked=0 skipped=" + skipped );
	beacon_emit( "[PROBE] canonical_path=" + canonical );
	beacon_emit( "[PROBE] next_batch=" + next + " stop_reason=" + reason );
	beacon_emit( "[PROBE] ==== END ====" );
}

beacon_all_ids()
{
	ids = [];
	ids[ 0 ] = "A1";
	ids[ 1 ] = "A2";
	ids[ 2 ] = "A3";
	ids[ 3 ] = "A4";
	ids[ 4 ] = "A5";
	return ids;
}

beacon_label( id )
{
	switch ( id )
	{
		case "A1": return "scripts/sp/";
		case "A2": return "scripts/sp/zom/";
		case "A3": return "scripts/sp/" + getDvar( "mapname" ) + "/";
		case "A4": return "raw/scripts/sp/";
		case "A5": return "mods/bo1sz_probe/scripts/sp/";
	}
	return "?";
}

beacon_mode()
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

beacon_line( id, status, evidence )
{
	if ( evidence.size > 79 )
	{
		evidence = getSubStr( evidence, 0, 79 );
	}
	return "[PROBE] " + id + " | " + status + " | " + getDvar( "mapname" ) + " | " + beacon_mode() + " | " + evidence;
}

beacon_emit( line )
{
	iPrintLn( line );
	println( line );
	logprint( line + "\n" );

	// Shared with probe.gsc via the level struct: one rolling log per map load.
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
