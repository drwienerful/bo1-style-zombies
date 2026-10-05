// bo1-style-zombies: main entry point.
// Loads in Zombies, announces the version, and hosts the debug points command.
//
// Dvars (set in the console before loading a map):
//   bo1sz_enable 0   disables the whole mod (default: enabled)
//   bo1sz_dev 1            enables every debug/testing command in the mod (off by default)
//   bo1sz_debug_points 1   (in game, dev) grant 50000 points to every player
//   bo1sz_hud_probe 1      (before load, dev) log how many more HUD elements a player can get
//
// Installed to storage\t5\scripts\sp\zom\, which Plutonium loads only in Zombies.

bo1sz_version()
{
	return "1.0.0";
}

init()
{
	if ( getDvar( "zombiemode" ) != "1" && !( isDefined( level.is_zombie_level ) && level.is_zombie_level ) )
	{
		return;
	}
	if ( getDvar( "bo1sz_enable" ) == "0" )
	{
		bo1sz_log( "disabled (bo1sz_enable 0)" );
		return;
	}

	level.bo1sz_version = bo1sz_version();
	bo1sz_log( "loaded v" + level.bo1sz_version + " map=" + getDvar( "mapname" ) );

	// init() runs before any player exists (Phase 0, B1), so wait for connections.
	level thread bo1sz_on_connect();
	level thread bo1sz_debug_points();
}

bo1sz_on_connect()
{
	for ( ;; )
	{
		level waittill( "connected", player );
		player thread bo1sz_greet();
	}
}

bo1sz_greet()
{
	self endon( "disconnect" );
	self waittill( "spawned_player" );
	wait 3;
	self iPrintLnBold( "bo1-style-zombies v" + level.bo1sz_version );
	bo1sz_log( "greeted " + self.playername );
	if ( getDvar( "bo1sz_hud_probe" ) == "1" && getDvar( "bo1sz_dev" ) == "1" )
	{
		wait 5;
		self bo1sz_hud_probe();
	}
}

// Diagnostic: how many more client HUD elements can this player get? Creates them one at
// a time (logging progress, in case a failure ends the thread), then destroys them.
bo1sz_hud_probe()
{
	made = [];
	for ( i = 0; i < 100; i++ )
	{
		e = NewClientHudElem( self );
		if ( !isDefined( e ) )
		{
			break;
		}
		made[ made.size ] = e;
		if ( made.size % 4 == 0 )
		{
			bo1sz_log( "hud probe: " + made.size + " extra elements so far" );
		}
	}
	bo1sz_log( "hud probe: " + made.size + " extra client HUD elements available" );
	for ( i = 0; i < made.size; i++ )
	{
		made[ i ] Destroy();
	}
}

bo1sz_log( msg )
{
	line = "[BO1SZ] " + msg;
	println( line );
	logprint( line + "\n" );
}

// Testing aid: "set bo1sz_debug_points 1" grants 50000 points to every player.
// String compare on purpose: getDvarInt returned 0 for console-typed values.
bo1sz_debug_points()
{
	setDvar( "bo1sz_debug_points", "0" );
	fn = getFunction( "maps/_zombiemode_score", "add_to_player_score" );
	for ( ;; )
	{
		wait 0.5;
		v = getDvar( "bo1sz_debug_points" );
		if ( v == "" || v == "0" || !( getDvar( "bo1sz_dev" ) == "1" ) )
		{
			continue;
		}
		setDvar( "bo1sz_debug_points", "0" );
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			if ( isDefined( fn ) )
			{
				players[ i ] [[ fn ]]( 50000 );
			}
			else
			{
				players[ i ].score += 50000;
			}
			players[ i ] iPrintLnBold( "+50000 points (debug)" );
		}
		bo1sz_log( "debug points granted" );
	}
}
