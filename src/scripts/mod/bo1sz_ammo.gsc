// bo1-style-zombies: double ammo (user request, 2026-10-05).
// Max ammo lives in weapon files we can't ship, so each weapon instead carries one hidden
// spare reserve (ammo.extra_reserves). When its reserve hits 0 the spare is spent on a
// GiveMaxAmmo, doubling the total ammo per weapon. A Max Ammo drop or a wall-ammo
// purchase (any reserve increase the mod didn't cause) restores the spare.
//
// Dvar: bo1sz_ammo 0 disables this module. Tunables: data/balance/ammo.csv.

init()
{
	if ( getDvar( "zombiemode" ) != "1" && !( isDefined( level.is_zombie_level ) && level.is_zombie_level ) )
	{
		return;
	}
	if ( getDvar( "bo1sz_enable" ) == "0" || getDvar( "bo1sz_ammo" ) == "0" )
	{
		return;
	}
	level thread ammo_start();
}

ammo_start()
{
	t = 0;
	while ( !isDefined( level.bo1sz_bal ) && t < 100 )
	{
		wait 0.05;
		t++;
	}
	if ( !isDefined( level.bo1sz_bal ) )
	{
		ammo_log( "balance data missing; ammo module off" );
		return;
	}
	level.bo1sz_ammo_excluded = strTok( level.bo1sz_bal[ "ammo.excluded" ], " " );
	ammo_log( "double ammo on (extra reserves=" + level.bo1sz_bal[ "ammo.extra_reserves" ] + ")" );

	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		players[ i ] thread ammo_player();
	}
	for ( ;; )
	{
		level waittill( "connected", player );
		player thread ammo_player();
	}
}

ammo_log( msg )
{
	line = "[BO1SZ] ammo: " + msg;
	println( line );
	logprint( line + "\n" );
}

ammo_eligible( weapon )
{
	if ( !isDefined( weapon ) || weapon == "none" || weapon == "" )
	{
		return false;
	}
	for ( i = 0; i < level.bo1sz_ammo_excluded.size; i++ )
	{
		if ( isSubStr( weapon, level.bo1sz_ammo_excluded[ i ] ) )
		{
			return false;
		}
	}
	if ( WeaponClass( weapon ) == "grenade" )
	{
		return false;
	}
	return ( WeaponClipSize( weapon ) > 0 );
}

ammo_player()
{
	self endon( "disconnect" );
	if ( isDefined( self.bo1sz_ammo_started ) )
	{
		return;
	}
	self.bo1sz_ammo_started = true;
	self waittill( "spawned_player" );

	spare = [];
	last = [];
	for ( ;; )
	{
		wait 0.2;
		list = self GetWeaponsList();
		held = [];
		for ( i = 0; i < list.size; i++ )
		{
			w = list[ i ];
			if ( !ammo_eligible( w ) )
			{
				continue;
			}
			held[ w ] = true;
			stock = self GetWeaponAmmoStock( w );
			if ( !isDefined( spare[ w ] ) )
			{
				// Newly acquired (or re-bought) weapon: give it its spare reserve.
				spare[ w ] = self ammo_reserves( w );
				last[ w ] = stock;
				continue;
			}
			if ( stock > last[ w ] )
			{
				// Refilled by the game (Max Ammo, wall ammo): restore the spare.
				spare[ w ] = self ammo_reserves( w );
			}
			if ( stock <= 0 && spare[ w ] > 0 )
			{
				self GiveMaxAmmo( w );
				spare[ w ]--;
				stock = self GetWeaponAmmoStock( w );
				ammo_log( self.playername + " spare reserve used on " + w + " (stock now " + stock + ", spares left " + spare[ w ] + ")" );
				if ( stock > 0 )
				{
					self iPrintLn( "Reserve ammo restocked" );
				}
			}
			last[ w ] = stock;
		}

		// Forget weapons no longer held, so a re-bought weapon gets a fresh spare.
		keys = getArrayKeys( spare );
		for ( k = 0; k < keys.size; k++ )
		{
			if ( !isDefined( held[ keys[ k ] ] ) )
			{
				spare[ keys[ k ] ] = undefined;
				last[ keys[ k ] ] = undefined;
			}
		}
	}
}

// Spare reserves per weapon; Mule Kick II (perks module) adds more via a player field,
// and Tech Ascended adds one more for wonder weapons.
ammo_reserves( weapon )
{
	n = level.bo1sz_bal[ "ammo.extra_reserves" ];
	if ( isDefined( self.bo1sz_extra_reserve_bonus ) )
	{
		n += self.bo1sz_extra_reserve_bonus;
	}
	if ( isDefined( self.bo1sz_arch ) && isDefined( self.bo1sz_arch[ "tech" ] ) && self.bo1sz_arch[ "tech" ] >= 2 && isDefined( level.bo1sz_pay_excluded ) )
	{
		for ( i = 0; i < level.bo1sz_pay_excluded.size; i++ )
		{
			if ( isSubStr( weapon, level.bo1sz_pay_excluded[ i ] ) )
			{
				n += level.bo1sz_bal[ "archetype_rules.tech_t2_extra_reserves" ];
				break;
			}
		}
	}
	return n;
}
