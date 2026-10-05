// bo1-style-zombies: perks (Milestone 4, step 1).
//
//   No perk limit: the first perks.stock_limit perks cost stock prices; each extra perk
//   adds a surcharge (step x extra index). The stock machine checks
//   "player.num_perks >= 4" (Phase 0, C6), so this module sets num_perks each tick:
//   below the limit it mirrors the real count; at or above it, it allows a purchase
//   only if the player can afford machine price + surcharge, and the surcharge is
//   deducted after "perk_bought". No stock function is replaced.
//
//   Double Tap 2.0 (docs/design/double_tap_2.md): x2 bullet damage while the attacker
//   has specialty_rof, fire-rate dvar 0.8333 (+20%), steady-aim perk while held.
//
// Dvar: bo1sz_perks 0 disables this module. Tunables: data/balance/perks.csv.

init()
{
	if ( getDvar( "zombiemode" ) != "1" && !( isDefined( level.is_zombie_level ) && level.is_zombie_level ) )
	{
		return;
	}
	if ( getDvar( "bo1sz_enable" ) == "0" || getDvar( "bo1sz_perks" ) == "0" )
	{
		return;
	}
	level thread perks_start();
}

perks_start()
{
	t = 0;
	while ( !isDefined( level.bo1sz_bal ) && t < 100 )
	{
		wait 0.05;
		t++;
	}
	if ( !isDefined( level.bo1sz_bal ) )
	{
		perks_log( "balance data missing; perks module off" );
		return;
	}
	level.bo1sz_perk_list = strTok( perks_bal( "perk_list" ), " " );
	level.bo1sz_perk_minus = getFunction( "maps/_zombiemode_score", "minus_to_player_score" );
	setDvar( "perk_weapRateMultiplier", "" + perks_bal( "dt2_rate_mult" ) );

	level thread perks_install_hooks();
	perks_log( "perks on (minus fn=" + isDefined( level.bo1sz_perk_minus ) + " machines=" + GetEntArray( "zombie_vending", "targetname" ).size + ")" );

	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		players[ i ] thread perks_player();
	}
	for ( ;; )
	{
		level waittill( "connected", player );
		player thread perks_player();
	}
}

perks_bal( key )
{
	return level.bo1sz_bal[ "perks." + key ];
}

perks_log( msg )
{
	line = "[BO1SZ] perks: " + msg;
	println( line );
	logprint( line + "\n" );
}

perks_owned( player )
{
	n = 0;
	for ( i = 0; i < level.bo1sz_perk_list.size; i++ )
	{
		if ( player HasPerk( level.bo1sz_perk_list[ i ] ) )
		{
			n++;
		}
	}
	return n;
}

// Surcharge for the next perk when the player already owns `owned` perks.
perks_surcharge( owned )
{
	limit = perks_bal( "stock_limit" );
	if ( owned < limit )
	{
		return 0;
	}
	return perks_bal( "surcharge_step" ) * ( owned - limit + 1 );
}

// Nearest perk machine trigger within machine_radius, or undefined.
perks_near_machine( player )
{
	trigs = GetEntArray( "zombie_vending", "targetname" );
	best = undefined;
	best_d = perks_bal( "machine_radius" );
	for ( i = 0; i < trigs.size; i++ )
	{
		d = Distance( player.origin, trigs[ i ].origin );
		if ( d < best_d )
		{
			best_d = d;
			best = trigs[ i ];
		}
	}
	return best;
}

// ---------------------------------------------------------------------------
// Per player: perk limit gate, surcharge prompt, Double Tap 2.0 steady aim
// ---------------------------------------------------------------------------

perks_player()
{
	self endon( "disconnect" );
	if ( isDefined( self.bo1sz_perks_started ) )
	{
		return;
	}
	self.bo1sz_perks_started = true;
	self waittill( "spawned_player" );

	self.bo1sz_perk_hint = NewClientHudElem( self );
	self.bo1sz_perk_hint.horzAlign = "user_center";
	self.bo1sz_perk_hint.vertAlign = "middle";
	self.bo1sz_perk_hint.alignX = "center";
	self.bo1sz_perk_hint.alignY = "middle";
	self.bo1sz_perk_hint.y = 90;
	self.bo1sz_perk_hint.fontScale = 1.3;
	self.bo1sz_perk_hint.alpha = 0;
	self.bo1sz_perk_hint_shown = -1;
	self.bo1sz_steady_given = false;

	self thread perks_on_bought();
	for ( ;; )
	{
		wait 0.2;
		if ( !isDefined( self.num_perks ) )
		{
			continue;
		}
		owned = perks_owned( self );
		limit = perks_bal( "stock_limit" );
		surcharge = 0;
		if ( owned < limit )
		{
			// Below the limit: behave exactly like stock.
			self.num_perks = owned;
		}
		else
		{
			surcharge = perks_surcharge( owned );
			cost = perks_bal( "default_cost" );
			machine = perks_near_machine( self );
			if ( isDefined( machine ) && isDefined( machine.cost ) )
			{
				cost = machine.cost;
			}
			if ( self.score >= cost + surcharge )
			{
				self.num_perks = 0;
			}
			else
			{
				self.num_perks = limit;
			}
			if ( !isDefined( machine ) )
			{
				surcharge = 0;
			}
		}
		self perks_show_hint( surcharge );
		self perks_dt2_steady();
	}
}

perks_show_hint( surcharge )
{
	if ( surcharge == self.bo1sz_perk_hint_shown )
	{
		return;
	}
	self.bo1sz_perk_hint_shown = surcharge;
	if ( surcharge <= 0 )
	{
		self.bo1sz_perk_hint.alpha = 0;
		return;
	}
	self.bo1sz_perk_hint SetText( "Extra perk surcharge: " + surcharge );
	self.bo1sz_perk_hint.alpha = 1;
}

perks_on_bought()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "perk_bought", perk );
		// The new perk is already owned here, so the count before it was owned - 1.
		surcharge = perks_surcharge( perks_owned( self ) - 1 );
		if ( surcharge <= 0 )
		{
			continue;
		}
		if ( surcharge > self.score )
		{
			surcharge = self.score;
		}
		if ( isDefined( level.bo1sz_perk_minus ) )
		{
			self [[ level.bo1sz_perk_minus ]]( surcharge );
		}
		else
		{
			self.score -= surcharge;
		}
		perks_log( self.playername + " bought " + perk + " surcharge " + surcharge );
	}
}

// Steady aim while the player has Double Tap; removed again if Double Tap is lost.
perks_dt2_steady()
{
	has_dt = self HasPerk( "specialty_rof" );
	if ( has_dt && !self.bo1sz_steady_given )
	{
		self SetPerk( perks_bal( "dt2_steady_perk" ) );
		self SetClientDvar( "perk_weapRateMultiplier", "" + perks_bal( "dt2_rate_mult" ) );
		self.bo1sz_steady_given = true;
	}
	else if ( !has_dt && self.bo1sz_steady_given )
	{
		self UnsetPerk( perks_bal( "dt2_steady_perk" ) );
		self.bo1sz_steady_given = false;
	}
}

// ---------------------------------------------------------------------------
// Double Tap 2.0 damage: chained actor damage wrapper (stock first)
// ---------------------------------------------------------------------------

perks_install_hooks()
{
	t = 0;
	while ( !isDefined( level.overrideActorDamage ) && t < 300 )
	{
		wait 0.1;
		t++;
	}
	for ( i = 0; i < 10; i++ )
	{
		waittillframeend;
	}
	level.bo1sz_perks_orig_damage = level.overrideActorDamage;
	level.overrideActorDamage = ::perks_actor_damage;
}

perks_actor_damage( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, modelIndex, psOffsetTime )
{
	dmg = damage;
	if ( isDefined( level.bo1sz_perks_orig_damage ) )
	{
		dmg = self [[ level.bo1sz_perks_orig_damage ]]( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, modelIndex, psOffsetTime );
	}
	if ( !isDefined( dmg ) )
	{
		dmg = damage;
	}
	if ( dmg > 0 && isDefined( attacker ) && isPlayer( attacker ) && isDefined( meansofdeath ) && ( meansofdeath == "MOD_PISTOL_BULLET" || meansofdeath == "MOD_RIFLE_BULLET" ) && attacker HasPerk( "specialty_rof" ) )
	{
		dmg = int( dmg * perks_bal( "dt2_damage_mult" ) );
	}
	return dmg;
}
