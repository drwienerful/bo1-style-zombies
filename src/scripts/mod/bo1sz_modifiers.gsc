// bo1-style-zombies: run modifiers (Milestone 8, user choice 2026-10-05).
// One random blessing per run, the same for every player, announced in round 1 with the
// archetype pop-up. All are positive. Table: data/balance/modifiers.csv.
//   discount   machine perks refund part of their price after drinking
//   pockets    one more spare ammo reserve per weapon (ammo module reads the field)
//   roller     style rank kill bonuses x2 (payoffs) but faster decay (style)
//   skin       +50 max health on top of whatever stock / Jugg II give
//   lucky      chance per kill to refill part of the magazine
//   headstart  extra points at the start
//
// Dvars: bo1sz_modifiers 0 disables; bo1sz_modifier <id> (before load) forces one.

init()
{
	if ( getDvar( "zombiemode" ) != "1" && !( isDefined( level.is_zombie_level ) && level.is_zombie_level ) )
	{
		return;
	}
	if ( getDvar( "bo1sz_enable" ) == "0" || getDvar( "bo1sz_modifiers" ) == "0" )
	{
		return;
	}
	level thread mods_start();
}

mods_start()
{
	t = 0;
	while ( !isDefined( level.bo1sz_bal ) && t < 100 )
	{
		wait 0.05;
		t++;
	}
	if ( !isDefined( level.bo1sz_bal ) )
	{
		mods_log( "balance data missing; modifiers off" );
		return;
	}

	pick = RandomInt( level.bo1sz_modifiers_count );
	forced = getDvar( "bo1sz_modifier" );
	for ( i = 0; i < level.bo1sz_modifiers_count; i++ )
	{
		if ( level.bo1sz_modifiers_id[ i ] == forced )
		{
			pick = i;
		}
	}
	level.bo1sz_modifier = level.bo1sz_modifiers_id[ pick ];
	level.bo1sz_modifier_value = level.bo1sz_modifiers_value[ pick ];
	mods_log( "this run: " + level.bo1sz_modifiers_name[ pick ] + " (" + level.bo1sz_modifier + ")" );

	// Level-wide effects other modules read.
	if ( level.bo1sz_modifier == "roller" )
	{
		level.bo1sz_rank_bonus_mult = level.bo1sz_modifier_value;
		level.bo1sz_style_decay_mult = level.bo1sz_bal[ "perks.roller_decay_mult" ];
	}

	level thread mods_install_hooks();
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		players[ i ] thread mods_player( pick );
	}
	for ( ;; )
	{
		level waittill( "connected", player );
		player thread mods_player( pick );
	}
}

mods_log( msg )
{
	line = "[BO1SZ] modifiers: " + msg;
	println( line );
	logprint( line + "\n" );
}

mods_player( pick )
{
	self endon( "disconnect" );
	if ( isDefined( self.bo1sz_mods_started ) )
	{
		return;
	}
	self.bo1sz_mods_started = true;
	self waittill( "spawned_player" );
	wait 4;

	// Announce through the archetype module's round-break pop-up queue (player fields).
	if ( isDefined( self.bo1sz_pop_title ) )
	{
		self.bo1sz_pop_title[ self.bo1sz_pop_title.size ] = "Run blessing: " + level.bo1sz_modifiers_name[ pick ];
		self.bo1sz_pop_desc[ self.bo1sz_pop_desc.size ] = level.bo1sz_modifiers_desc[ pick ];
	}
	else
	{
		self iPrintLnBold( "Run blessing: " + level.bo1sz_modifiers_name[ pick ] );
	}

	m = level.bo1sz_modifier;
	if ( m == "pockets" )
	{
		self.bo1sz_mod_reserve_bonus = level.bo1sz_modifier_value;
	}
	else if ( m == "headstart" )
	{
		fn = getFunction( "maps/_zombiemode_score", "add_to_player_score" );
		if ( isDefined( fn ) )
		{
			self [[ fn ]]( level.bo1sz_modifier_value );
		}
	}
	else if ( m == "discount" )
	{
		self thread mods_discount();
	}
	else if ( m == "skin" )
	{
		self thread mods_skin();
	}
}

// Discount Cola: refund part of the nearest machine's price after a machine perk.
mods_discount()
{
	self endon( "disconnect" );
	fn = getFunction( "maps/_zombiemode_score", "add_to_player_score" );
	for ( ;; )
	{
		self waittill( "perk_bought", perk );
		cost = 0;
		trigs = GetEntArray( "zombie_vending", "targetname" );
		for ( i = 0; i < trigs.size; i++ )
		{
			if ( isDefined( trigs[ i ].script_noteworthy ) && trigs[ i ].script_noteworthy == perk && isDefined( trigs[ i ].cost ) )
			{
				cost = trigs[ i ].cost;
			}
		}
		refund = int( cost * level.bo1sz_modifier_value );
		if ( refund > 0 && isDefined( fn ) )
		{
			self [[ fn ]]( refund );
			self iPrintLn( "Discount Cola: +" + refund + " refunded" );
		}
	}
}

// Thick Skin: keep max health at (stock base or Juggernog) + Jugg II + the bonus.
mods_skin()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		wait 0.5;
		base = 100;
		jugg = self HasPerk( "specialty_armorvest" );
		if ( jugg && isDefined( level.zombie_vars[ "zombie_perk_juggernaut_health" ] ) )
		{
			base = level.zombie_vars[ "zombie_perk_juggernaut_health" ];
		}
		if ( isDefined( self.bo1sz_jugg2_max ) )
		{
			base += level.bo1sz_bal[ "perks.jugg2_health_bonus" ];
		}
		want = base + level.bo1sz_modifier_value;
		if ( self.maxhealth < want )
		{
			self.maxhealth = want;
		}
	}
}

// Lucky Streak: chained actor-killed wrapper (stock first).
mods_install_hooks()
{
	if ( level.bo1sz_modifier != "lucky" )
	{
		return;
	}
	t = 0;
	while ( !isDefined( level.overrideActorKilled ) && t < 300 )
	{
		wait 0.1;
		t++;
	}
	for ( i = 0; i < 10; i++ )
	{
		waittillframeend;
	}
	level.bo1sz_mods_orig_killed = level.overrideActorKilled;
	level.overrideActorKilled = ::mods_actor_killed;
}

mods_actor_killed( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime )
{
	if ( isDefined( level.bo1sz_mods_orig_killed ) )
	{
		self [[ level.bo1sz_mods_orig_killed ]]( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime );
	}
	if ( !isDefined( attacker ) || !isPlayer( attacker ) || RandomInt( 100 ) >= level.bo1sz_modifier_value )
	{
		return;
	}
	w = attacker GetCurrentWeapon();
	if ( !isDefined( w ) || w == "none" )
	{
		return;
	}
	size = WeaponClipSize( w );
	if ( size <= 0 )
	{
		return;
	}
	clip = attacker GetWeaponAmmoClip( w );
	add = int( size * level.bo1sz_bal[ "perks.lucky_refill_frac" ] );
	if ( add < 1 )
	{
		add = 1;
	}
	if ( clip + add > size )
	{
		add = size - clip;
	}
	if ( add > 0 )
	{
		attacker SetWeaponAmmoClip( w, clip + add );
	}
}
