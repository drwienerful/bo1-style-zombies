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
//   Perk tier II (step 2): hold USE at an owned perk's machine to buy tier II
//   (perk_tiers.csv): Jugg II health, Speed Cola II reload, Double Tap II fire rate,
//   Quick Revive II = Scavenger (kills may refill every gun's magazine), Mule Kick II
//   extra ammo reserve, Deadshot II headshot damage. Name + description shown in game.
//
// Dvars: bo1sz_perks 0 disables this module; bo1sz_perks_debug 1 logs perk machines at
// load and, while USE is held, the nearest machines. Tunables: data/balance/perks.csv.

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

	perks_build_tiers();
	perks_record_homes();
	level thread perks_install_hooks();
	level thread perks_global_dvars();
	perks_log( "perks on (minus fn=" + isDefined( level.bo1sz_perk_minus ) + " machines=" + GetEntArray( "zombie_vending", "targetname" ).size + ")" );
	if ( getDvar( "bo1sz_perks_debug" ) == "1" )
	{
		level thread perks_debug_machines();
	}

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
		d = Distance( player.origin, perks_machine_home( trigs[ i ] ) );
		if ( d < best_d )
		{
			best_d = d;
			best = trigs[ i ];
		}
	}
	return best;
}

// Where a machine's trigger started. In solo, stock moves the Quick Revive trigger
// about 10000 units below the map once it is bought (seen at z=-9894 on Kino,
// 2026-10-05), so distances must use the original position.
perks_machine_home( trig )
{
	if ( !isDefined( trig.bo1sz_home ) )
	{
		if ( trig.origin[ 2 ] < -5000 )
		{
			return trig.origin;
		}
		trig.bo1sz_home = trig.origin;
	}
	return trig.bo1sz_home;
}

// Record every machine's position at load, before any purchase can move it.
perks_record_homes()
{
	trigs = GetEntArray( "zombie_vending", "targetname" );
	for ( i = 0; i < trigs.size; i++ )
	{
		perks_machine_home( trigs[ i ] );
	}
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
	self perks_tiers_init();

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
		cost = 0;
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
			// Only prompt at a machine selling a perk the player doesn't own yet: stock never
			// sells an owned perk, and showing a surcharge there looked like a broken machine.
			if ( !isDefined( machine ) || ( isDefined( machine.script_noteworthy ) && self HasPerk( machine.script_noteworthy ) ) )
			{
				surcharge = 0;
			}
		}
		self perks_show_hint( surcharge, cost );
		self perks_dt2_steady();
		self perks_tiers_tick();
	}
}

perks_show_hint( surcharge, cost )
{
	key = surcharge * 100000 + cost;
	if ( key == self.bo1sz_perk_hint_shown )
	{
		return;
	}
	self.bo1sz_perk_hint_shown = key;
	if ( surcharge <= 0 )
	{
		self.bo1sz_perk_hint.alpha = 0;
		return;
	}
	self.bo1sz_perk_hint SetText( "Extra perk: " + cost + " + " + surcharge + " surcharge" );
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
	while ( ( !isDefined( level.overrideActorDamage ) || !isDefined( level.overrideActorKilled ) ) && t < 300 )
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
	level.bo1sz_perks_orig_killed = level.overrideActorKilled;
	level.overrideActorKilled = ::perks_actor_killed;
}

perks_actor_killed( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime )
{
	if ( isDefined( level.bo1sz_perks_orig_killed ) )
	{
		self [[ level.bo1sz_perks_orig_killed ]]( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime );
	}
	if ( isDefined( attacker ) && isPlayer( attacker ) && perks_has_tier( attacker, "specialty_quickrevive" ) && RandomInt( 100 ) < perks_bal( "scavenger_chance" ) )
	{
		attacker perks_scavenge();
	}
}

// Quick Revive II (Scavenger): refill part of every carried gun's magazine.
perks_scavenge()
{
	list = self GetWeaponsList();
	n = 0;
	for ( i = 0; i < list.size; i++ )
	{
		w = list[ i ];
		if ( w == "none" || WeaponClass( w ) == "grenade" )
		{
			continue;
		}
		size = WeaponClipSize( w );
		if ( size <= 0 )
		{
			continue;
		}
		clip = self GetWeaponAmmoClip( w );
		add = int( size * perks_bal( "scavenger_clip_frac" ) );
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
			self SetWeaponAmmoClip( w, clip + add );
			n++;
		}
	}
	if ( n > 0 )
	{
		self iPrintLn( "Scavenger: magazines refilled" );
	}
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
	if ( dmg > 0 && isDefined( attacker ) && isPlayer( attacker ) && perks_has_tier( attacker, "specialty_deadshot" ) && isDefined( sHitLoc ) && ( sHitLoc == "head" || sHitLoc == "helmet" || sHitLoc == "neck" ) )
	{
		dmg = int( dmg * perks_bal( "deadshot2_hs_mult" ) );
	}
	return dmg;
}

// ---------------------------------------------------------------------------
// Perk tier II (Milestone 4 step 2, user choice): hold USE at the machine of an owned
// perk to buy its tier II. Tiers are lost with the perk (e.g. when going down).
// Table: data/balance/perk_tiers.csv; effect tunables: perks.csv.
// ---------------------------------------------------------------------------

perks_build_tiers()
{
	level.bo1sz_tier_name = [];
	level.bo1sz_tier_price = [];
	level.bo1sz_tier_desc = [];
	for ( i = 0; i < level.bo1sz_perk_tiers_count; i++ )
	{
		perk = level.bo1sz_perk_tiers_perk[ i ];
		level.bo1sz_tier_name[ perk ] = level.bo1sz_perk_tiers_name[ i ];
		level.bo1sz_tier_price[ perk ] = level.bo1sz_perk_tiers_price[ i ];
		level.bo1sz_tier_desc[ perk ] = level.bo1sz_perk_tiers_desc[ i ];
	}
}

perks_has_tier( player, perk )
{
	return ( isDefined( player.bo1sz_tier ) && isDefined( player.bo1sz_tier[ perk ] ) );
}

perks_tiers_init()
{
	self.bo1sz_tier = [];
	self.bo1sz_tier_hint = NewClientHudElem( self );
	self.bo1sz_tier_hint.horzAlign = "user_center";
	self.bo1sz_tier_hint.vertAlign = "middle";
	self.bo1sz_tier_hint.alignX = "center";
	self.bo1sz_tier_hint.alignY = "middle";
	self.bo1sz_tier_hint.y = 110;
	self.bo1sz_tier_hint.fontScale = 1.3;
	self.bo1sz_tier_hint.alpha = 0;
	self.bo1sz_tier_hint_desc = perks_center_elem( self, 128, 1.1 );
	self.bo1sz_tier_pop_name = perks_center_elem( self, -110, 1.8 );
	self.bo1sz_tier_pop_desc = perks_center_elem( self, -86, 1.2 );
	self.bo1sz_tier_hint_perk = "";
	self.bo1sz_use_ms = 0;
}

perks_center_elem( player, y, scale )
{
	e = NewClientHudElem( player );
	e.horzAlign = "user_center";
	e.vertAlign = "middle";
	e.alignX = "center";
	e.alignY = "middle";
	e.y = y;
	e.fontScale = scale;
	e.foreground = true;
	e.alpha = 0;
	return e;
}

// Name in large text with its description underneath, then fade out.
perks_tier_popup( perk )
{
	self endon( "disconnect" );
	self notify( "bo1sz_tier_popup" );
	self endon( "bo1sz_tier_popup" );
	self.bo1sz_tier_pop_name SetText( level.bo1sz_tier_name[ perk ] );
	self.bo1sz_tier_pop_desc SetText( level.bo1sz_tier_desc[ perk ] );
	self.bo1sz_tier_pop_name FadeOverTime( 0.2 );
	self.bo1sz_tier_pop_desc FadeOverTime( 0.2 );
	self.bo1sz_tier_pop_name.alpha = 1;
	self.bo1sz_tier_pop_desc.alpha = 1;
	wait perks_bal( "tier_popup_seconds" );
	self.bo1sz_tier_pop_name FadeOverTime( 0.5 );
	self.bo1sz_tier_pop_desc FadeOverTime( 0.5 );
	self.bo1sz_tier_pop_name.alpha = 0;
	self.bo1sz_tier_pop_desc.alpha = 0;
}

perks_tiers_tick()
{
	now = getTime();

	// Drop tiers whose perk was lost, and undo their effects.
	keys = getArrayKeys( self.bo1sz_tier );
	for ( i = 0; i < keys.size; i++ )
	{
		still = self HasPerk( keys[ i ] );
		if ( !still )
		{
			self.bo1sz_tier[ keys[ i ] ] = undefined;
			if ( keys[ i ] == "specialty_armorvest" )
			{
				self.bo1sz_jugg2_max = undefined;
			}
			if ( keys[ i ] == "specialty_additionalprimaryweapon" )
			{
				self.bo1sz_extra_reserve_bonus = 0;
			}
		}
	}

	// Juggernog II: keep the raised max health even if something resets it.
	if ( isDefined( self.bo1sz_jugg2_max ) && self.maxhealth < self.bo1sz_jugg2_max )
	{
		self.maxhealth = self.bo1sz_jugg2_max;
	}

	// Prompt and purchase at the machine of an owned perk that has a tier II.
	perk = "";
	machine = perks_near_machine( self );
	if ( isDefined( machine ) && isDefined( machine.script_noteworthy ) )
	{
		p = machine.script_noteworthy;
		if ( isDefined( level.bo1sz_tier_name[ p ] ) && self HasPerk( p ) && !perks_has_tier( self, p ) )
		{
			perk = p;
		}
	}
	if ( perk != self.bo1sz_tier_hint_perk )
	{
		self.bo1sz_tier_hint_perk = perk;
		if ( perk == "" )
		{
			self.bo1sz_tier_hint.alpha = 0;
			self.bo1sz_tier_hint_desc.alpha = 0;
		}
		else
		{
			self.bo1sz_tier_hint SetText( "Hold USE: " + level.bo1sz_tier_name[ perk ] + " (" + level.bo1sz_tier_price[ perk ] + ")" );
			self.bo1sz_tier_hint_desc SetText( level.bo1sz_tier_desc[ perk ] );
			self.bo1sz_tier_hint.alpha = 1;
			self.bo1sz_tier_hint_desc.alpha = 1;
		}
	}
	if ( perk == "" )
	{
		self.bo1sz_use_ms = 0;
		if ( getDvar( "bo1sz_perks_debug" ) == "1" )
		{
			held = self UseButtonPressed();
			if ( held )
			{
				self perks_debug_use();
			}
		}
		return;
	}
	pressed = self UseButtonPressed();
	if ( pressed && getDvar( "bo1sz_perks_debug" ) == "1" )
	{
		self perks_debug_use();
	}
	if ( !pressed )
	{
		self.bo1sz_use_ms = 0;
		return;
	}
	if ( self.bo1sz_use_ms == 0 )
	{
		self.bo1sz_use_ms = now;
		return;
	}
	if ( now - self.bo1sz_use_ms < perks_bal( "tier_hold_seconds" ) * 1000 )
	{
		return;
	}
	self.bo1sz_use_ms = 0;
	self perks_buy_tier( perk );
}

perks_buy_tier( perk )
{
	price = level.bo1sz_tier_price[ perk ];
	if ( self.score < price )
	{
		self PlayLocalSound( "evt_perk_deny" );
		self iPrintLn( "Not enough points for " + level.bo1sz_tier_name[ perk ] );
		return;
	}
	if ( isDefined( level.bo1sz_perk_minus ) )
	{
		self [[ level.bo1sz_perk_minus ]]( price );
	}
	else
	{
		self.score -= price;
	}
	self.bo1sz_tier[ perk ] = 2;
	if ( perk == "specialty_armorvest" )
	{
		self.maxhealth += perks_bal( "jugg2_health_bonus" );
		self.health = self.maxhealth;
		self.bo1sz_jugg2_max = self.maxhealth;
	}
	if ( perk == "specialty_additionalprimaryweapon" )
	{
		self.bo1sz_extra_reserve_bonus = perks_bal( "mule2_extra_reserves" );
	}
	self PlayLocalSound( "zmb_cha_ching" );
	self thread perks_tier_popup( perk );
	perks_log( self.playername + " bought " + level.bo1sz_tier_name[ perk ] + " for " + price );
	self.bo1sz_tier_hint_perk = "-";
}

// Fire-rate and reload multipliers are game-wide dvars: use the best tier any player holds.
perks_global_dvars()
{
	level.bo1sz_stock_reload = getDvar( "perk_weapReloadMultiplier" );
	for ( ;; )
	{
		wait 0.5;
		rate = "" + perks_bal( "dt2_rate_mult" );
		reload = level.bo1sz_stock_reload;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			if ( perks_has_tier( players[ i ], "specialty_rof" ) )
			{
				rate = "" + perks_bal( "dt2b_rate_mult" );
			}
			if ( perks_has_tier( players[ i ], "specialty_fastreload" ) )
			{
				reload = "" + perks_bal( "speed2_reload_mult" );
			}
		}
		if ( getDvar( "perk_weapRateMultiplier" ) != rate )
		{
			setDvar( "perk_weapRateMultiplier", rate );
			for ( i = 0; i < players.size; i++ )
			{
				players[ i ] SetClientDvar( "perk_weapRateMultiplier", rate );
			}
		}
		if ( getDvar( "perk_weapReloadMultiplier" ) != reload )
		{
			setDvar( "perk_weapReloadMultiplier", reload );
			for ( i = 0; i < players.size; i++ )
			{
				players[ i ] SetClientDvar( "perk_weapReloadMultiplier", reload );
			}
		}
	}
}

// Debug: every perk machine trigger once, after power has had time to come on.
perks_debug_machines()
{
	wait 30;
	trigs = GetEntArray( "zombie_vending", "targetname" );
	for ( i = 0; i < trigs.size; i++ )
	{
		perks_log( "machine " + i + " " + perks_dbg_str( trigs[ i ].script_noteworthy ) + " at " + trigs[ i ].origin + " cost=" + perks_dbg_str( trigs[ i ].cost ) );
	}
}

// Debug: while USE is held (at most once a second), the three nearest machines.
perks_debug_use()
{
	now = getTime();
	if ( isDefined( self.bo1sz_dbg_ms ) && now - self.bo1sz_dbg_ms < 1000 )
	{
		return;
	}
	self.bo1sz_dbg_ms = now;
	trigs = GetEntArray( "zombie_vending", "targetname" );
	line = "use at " + self.origin + ":";
	for ( k = 0; k < 3 && k < trigs.size; k++ )
	{
		best = -1;
		best_d = 999999;
		for ( i = 0; i < trigs.size; i++ )
		{
			if ( isDefined( trigs[ i ].bo1sz_dbg_used ) )
			{
				continue;
			}
			d = Distance( self.origin, perks_machine_home( trigs[ i ] ) );
			if ( d < best_d )
			{
				best_d = d;
				best = i;
			}
		}
		if ( best < 0 )
		{
			break;
		}
		trigs[ best ].bo1sz_dbg_used = true;
		p = trigs[ best ].script_noteworthy;
		has = false;
		tier = false;
		if ( isDefined( p ) )
		{
			has = self HasPerk( p );
			tier = perks_has_tier( self, p );
		}
		line = line + " [" + perks_dbg_str( p ) + " d=" + int( best_d ) + " has=" + has + " tier=" + tier + "]";
	}
	for ( i = 0; i < trigs.size; i++ )
	{
		trigs[ i ].bo1sz_dbg_used = undefined;
	}
	perks_log( self.playername + " " + line );
}

perks_dbg_str( v )
{
	if ( !isDefined( v ) )
	{
		return "undef";
	}
	return "" + v;
}
