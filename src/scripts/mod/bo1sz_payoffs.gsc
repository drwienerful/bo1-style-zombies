// bo1-style-zombies: weapon payoffs and style-based points (Milestone 3).
// Every effect ADDS power or reward; nothing is ever reduced (CLAUDE.md rule 7).
//
//   Pistols   headshot-kill streak ramps damage (cap x3.5), +points per step, bullet refund
//   Snipers   x3.5 headshot damage; each extra zombie one shot passes through takes
//             more damage, +points (FN FAL counts as a sniper via class_overrides)
//   Shotguns  each blast sends a damaging shockwave through the crowd behind the target;
//             +points per extra kill, shell refund on 3+
//   Launchers +points for every zombie caught in the blast; round refund on 6+ kills
//   Any       real bonus points for headshot / multi-kill / long-range / melee kills,
//             plus a per-kill bonus and an ammo-on-kill chance from the style rank
// Wonder weapons (payoffs.excluded_weapons) get none of the class payoffs.
// Archetype traits (bo1sz_archetypes.gsc sets player.bo1sz_arch[id]) and augments
// (player.bo1sz_aug[augment id]) are applied here too. Awakened: Gunslinger cap/timeout,
// Marksman pierce, Brawler melee, Blaster range, Demolitions explosive damage.
// Ascended: Gunslinger 2-bullet refund, Blaster shockwave radius, Demolitions grenade
// refund. Augments (augments.csv): dmg / points / refund kinds plus the specials.
// Capstones: Gunslinger full-magazine refills, Marksman detonations, Blaster chain
// reactions, Demolitions second blasts, Tech mini shockwaves (Brawler's is in the
// archetypes module, which owns the player-damage hook).
//
// Dvars: bo1sz_payoffs 0 disables this module; bo1sz_payoff_debug 1 logs every award.
// Tunables: data/balance/payoffs.csv, style_ranks.csv (kill_bonus, ammo_chance).

init()
{
	if ( getDvar( "zombiemode" ) != "1" && !( isDefined( level.is_zombie_level ) && level.is_zombie_level ) )
	{
		return;
	}
	if ( getDvar( "bo1sz_enable" ) == "0" || getDvar( "bo1sz_payoffs" ) == "0" )
	{
		return;
	}
	level thread pay_start();
}

pay_start()
{
	t = 0;
	while ( !isDefined( level.bo1sz_bal ) && t < 100 )
	{
		wait 0.05;
		t++;
	}
	if ( !isDefined( level.bo1sz_bal ) )
	{
		pay_log( "balance data missing; payoffs off" );
		return;
	}
	level.bo1sz_pay_excluded = strTok( pay_bal( "excluded_weapons" ), " " );
	pay_build_overrides();
	level.bo1sz_pay_add_points = getFunction( "maps/_zombiemode_score", "add_to_player_score" );

	t = 0;
	while ( ( !isDefined( level.overrideActorKilled ) || !isDefined( level.overrideActorDamage ) ) && t < 300 )
	{
		wait 0.1;
		t++;
	}
	for ( i = 0; i < 10; i++ )
	{
		waittillframeend;
	}
	// Chains onto whatever is installed (stock, or another bo1sz module's wrapper).
	level.bo1sz_pay_orig_damage = level.overrideActorDamage;
	level.bo1sz_pay_orig_killed = level.overrideActorKilled;
	level.overrideActorDamage = ::pay_actor_damage;
	level.overrideActorKilled = ::pay_actor_killed;
	pay_log( "payoffs on (score fn=" + isDefined( level.bo1sz_pay_add_points ) + ")" );
}

pay_bal( key )
{
	return level.bo1sz_bal[ "payoffs." + key ];
}

pay_log( msg )
{
	line = "[BO1SZ] payoffs: " + msg;
	println( line );
	logprint( line + "\n" );
}

pay_debug( player, msg )
{
	if ( getDvar( "bo1sz_payoff_debug" ) == "1" )
	{
		pay_log( player.playername + " " + msg );
	}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

pay_is_excluded( weapon )
{
	for ( i = 0; i < level.bo1sz_pay_excluded.size; i++ )
	{
		if ( isSubStr( weapon, level.bo1sz_pay_excluded[ i ] ) )
		{
			return true;
		}
	}
	return false;
}

// "fnfal=sniper rk5=pistol" -> parallel arrays of name substrings and classes.
pay_build_overrides()
{
	level.bo1sz_pay_ovr_name = [];
	level.bo1sz_pay_ovr_class = [];
	pairs = strTok( pay_bal( "class_overrides" ), " " );
	for ( i = 0; i < pairs.size; i++ )
	{
		kv = strTok( pairs[ i ], "=" );
		if ( kv.size == 2 )
		{
			level.bo1sz_pay_ovr_name[ level.bo1sz_pay_ovr_name.size ] = kv[ 0 ];
			level.bo1sz_pay_ovr_class[ level.bo1sz_pay_ovr_class.size ] = kv[ 1 ];
		}
	}
}

pay_class( weapon )
{
	if ( !isDefined( weapon ) || weapon == "none" || weapon == "" )
	{
		return "none";
	}
	if ( pay_is_excluded( weapon ) )
	{
		return "wonder";
	}
	for ( i = 0; i < level.bo1sz_pay_ovr_name.size; i++ )
	{
		if ( isSubStr( weapon, level.bo1sz_pay_ovr_name[ i ] ) )
		{
			return level.bo1sz_pay_ovr_class[ i ];
		}
	}
	return WeaponClass( weapon );
}

pay_is_bullet( mod )
{
	return ( mod == "MOD_PISTOL_BULLET" || mod == "MOD_RIFLE_BULLET" || mod == "MOD_HEAD_SHOT" );
}

pay_is_projectile( mod )
{
	return ( mod == "MOD_PROJECTILE" || mod == "MOD_PROJECTILE_SPLASH" );
}

pay_is_head( hitloc, mod )
{
	return ( isDefined( hitloc ) && ( hitloc == "head" || hitloc == "helmet" || hitloc == "neck" ) && pay_is_bullet( mod ) );
}

// Archetype tier for a player (0 = none, 1 Awakened, 2 Ascended, 3 capstone).
pay_arch( player, id )
{
	if ( isDefined( player.bo1sz_arch ) && isDefined( player.bo1sz_arch[ id ] ) )
	{
		return player.bo1sz_arch[ id ];
	}
	return 0;
}

pay_rule( key )
{
	return level.bo1sz_bal[ "archetype_rules." + key ];
}

pay_pistol_max( player )
{
	if ( pay_arch( player, "gunslinger" ) >= 1 )
	{
		return pay_rule( "gunslinger_t1_max_mult" );
	}
	return pay_bal( "pistol_max_mult" );
}

pay_pistol_timeout( player )
{
	// Steady Hand augment: streaks never time out.
	if ( isDefined( player.bo1sz_aug ) && isDefined( player.bo1sz_aug[ "gun_steady" ] ) )
	{
		return 99999999;
	}
	if ( pay_arch( player, "gunslinger" ) >= 1 )
	{
		return pay_rule( "gunslinger_t1_timeout_ms" );
	}
	return pay_bal( "pistol_streak_timeout_ms" );
}

pay_rank( player )
{
	if ( isDefined( player.bo1sz_style_rank ) )
	{
		return player.bo1sz_style_rank;
	}
	return 0;
}

pay_points( player, pts, why )
{
	pts = int( pts );
	if ( pts <= 0 )
	{
		return;
	}
	if ( isDefined( level.bo1sz_pay_add_points ) )
	{
		player [[ level.bo1sz_pay_add_points ]]( pts );
	}
	else
	{
		player.score += pts;
	}
	pay_debug( player, "+" + pts + " " + why );
}

// Adds bullets to the clip of a weapon the player holds, never above clip size.
pay_refund( player, weapon, bullets, why )
{
	if ( !isDefined( weapon ) || weapon == "none" )
	{
		return;
	}
	has = player HasWeapon( weapon );
	if ( !has )
	{
		return;
	}
	clip = player GetWeaponAmmoClip( weapon );
	size = WeaponClipSize( weapon );
	if ( clip >= size )
	{
		return;
	}
	add = bullets;
	if ( clip + add > size )
	{
		add = size - clip;
	}
	player SetWeaponAmmoClip( weapon, clip + add );
	pay_debug( player, "refund " + add + " " + weapon + " " + why );
}

// ---------------------------------------------------------------------------
// Damage: pistol streak ramp, sniper pierce, launcher blast points
// ---------------------------------------------------------------------------

pay_actor_damage( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, modelIndex, psOffsetTime )
{
	dmg = damage;
	if ( isDefined( level.bo1sz_pay_orig_damage ) )
	{
		dmg = self [[ level.bo1sz_pay_orig_damage ]]( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, modelIndex, psOffsetTime );
	}
	if ( !isDefined( dmg ) )
	{
		dmg = damage;
	}
	if ( dmg > 0 && isDefined( attacker ) && isPlayer( attacker ) )
	{
		dmg = self pay_on_damage( attacker, dmg, meansofdeath, weapon, sHitLoc );
	}
	return dmg;
}

pay_on_damage( attacker, dmg, mod, weapon, hitloc )
{
	if ( !isDefined( mod ) )
	{
		mod = "";
	}
	cls = pay_class( weapon );
	now = getTime();
	mult = 1.0;

	// Pistols: damage ramps with the current headshot-kill streak.
	if ( cls == "pistol" && pay_is_bullet( mod ) )
	{
		streak = pay_pistol_streak( attacker );
		if ( streak > 0 )
		{
			mult = 1.0 + streak * pay_bal( "pistol_step_mult" );
			cap = pay_pistol_max( attacker );
			if ( mult > cap )
			{
				mult = cap;
			}
		}
	}

	// Snipers: the Nth zombie one shot passes through takes extra damage and pays points.
	if ( cls == "sniper" && pay_is_bullet( mod ) )
	{
		if ( isDefined( attacker.bo1sz_pierce_ms ) && attacker.bo1sz_pierce_ms == now )
		{
			attacker.bo1sz_pierce_n++;
			step = pay_bal( "sniper_pierce_mult" );
			if ( pay_arch( attacker, "marksman" ) >= 1 )
			{
				step = pay_rule( "marksman_t1_pierce_mult" );
			}
			mult = 1.0 + ( attacker.bo1sz_pierce_n - 1 ) * step;
			pay_points( attacker, pay_bal( "sniper_pierce_points" ), "sniper pierce x" + attacker.bo1sz_pierce_n );
		}
		else
		{
			attacker.bo1sz_pierce_ms = now;
			attacker.bo1sz_pierce_n = 1;
		}
	}

	// Brawler Awakened: melee damage.
	if ( mod == "MOD_MELEE" && pay_arch( attacker, "brawler" ) >= 1 )
	{
		mult = mult * pay_rule( "brawler_t1_melee_mult" );
	}

	// Blaster Awakened: shotgun damage holds up at range (offsets the weapon's falloff).
	if ( cls == "spread" && pay_arch( attacker, "blaster" ) >= 1 )
	{
		start = pay_rule( "blaster_t1_range_start" );
		d = Distance( attacker.origin, self.origin );
		if ( d > start )
		{
			f = ( d - start ) / ( pay_rule( "blaster_t1_range_full" ) - start );
			if ( f > 1 )
			{
				f = 1;
			}
			mult = mult * ( 1 + f * ( pay_rule( "blaster_t1_max_mult" ) - 1 ) );
		}
	}

	// Demolitions Awakened: explosive damage (not wonder weapons).
	if ( cls != "wonder" && ( pay_is_projectile( mod ) || mod == "MOD_GRENADE" || mod == "MOD_GRENADE_SPLASH" || mod == "MOD_EXPLOSIVE" ) && pay_arch( attacker, "demolitions" ) >= 1 )
	{
		mult = mult * pay_rule( "demolitions_t1_mult" );
	}

	// Rifleman: assault rifle headshots (the capstone value replaces the Awakened one).
	if ( cls == "rifle" && pay_is_head( hitloc, mod ) )
	{
		if ( pay_arch( attacker, "rifleman" ) >= 3 )
		{
			mult = mult * pay_rule( "rifleman_t3_hs_mult" );
		}
		else if ( pay_arch( attacker, "rifleman" ) >= 1 )
		{
			mult = mult * pay_rule( "rifleman_t1_hs_mult" );
		}
	}

	// Gunner Awakened: suppressive fire, consecutive LMG hits stack damage.
	if ( cls == "mg" && pay_is_bullet( mod ) && pay_arch( attacker, "gunner" ) >= 1 )
	{
		if ( isDefined( attacker.bo1sz_supp_ms ) && now - attacker.bo1sz_supp_ms <= pay_rule( "gunner_t1_window_ms" ) )
		{
			if ( now != attacker.bo1sz_supp_ms )
			{
				attacker.bo1sz_supp_n++;
			}
		}
		else
		{
			attacker.bo1sz_supp_n = 0;
		}
		attacker.bo1sz_supp_ms = now;
		supp = 1.0 + attacker.bo1sz_supp_n * pay_rule( "gunner_t1_step" );
		if ( supp > pay_rule( "gunner_t1_max_mult" ) )
		{
			supp = pay_rule( "gunner_t1_max_mult" );
		}
		mult = mult * supp;
	}

	// Snipers: big headshot multiplier on top of stock headshot damage.
	if ( cls == "sniper" && pay_is_head( hitloc, mod ) )
	{
		mult = mult * pay_bal( "sniper_headshot_mult" );
	}

	// Shotguns: crowd control on hit (payoffs.shotgun_cc_mode).
	if ( cls == "spread" )
	{
		mode = pay_bal( "shotgun_cc_mode" );
		if ( mode == "shockwave" )
		{
			self pay_shockwave( attacker );
		}
		else if ( mode == "knockdown" )
		{
			self thread pay_knockdown( attacker );
		}
		else if ( mode == "stagger" )
		{
			self thread pay_stagger();
		}
	}

	// Launchers: points for every zombie caught in the blast (once per zombie per blast).
	// Pistols are skipped: the upgraded M1911 fires explosive rounds and already has the streak.
	if ( cls != "wonder" && cls != "none" && cls != "pistol" && pay_is_projectile( mod ) )
	{
		if ( !( isDefined( self.bo1sz_blast_ms ) && self.bo1sz_blast_ms == now && isDefined( self.bo1sz_blast_by ) && self.bo1sz_blast_by == attacker ) )
		{
			self.bo1sz_blast_ms = now;
			self.bo1sz_blast_by = attacker;
			pay_points( attacker, pay_bal( "launcher_hit_points" ), "launcher blast" );
		}
	}

	// Augments: class damage.
	mult = mult * pay_aug_value( attacker, pay_kill_arch( cls, mod, weapon ), "dmg", 1.0 );

	if ( mult > 1.0 )
	{
		return int( dmg * mult );
	}
	return dmg;
}

// Shotgun shockwave (user asked for crowd control that doesn't change zombie movement,
// since slowing breaks trains and a real knockdown can't be triggered from script).
// Once per blast: damages every zombie near a point just beyond the hit zombie,
// pointing away from the shooter. Skipped if the shooter could be inside the radius.
pay_shockwave( player )
{
	now = getTime();
	if ( isDefined( player.bo1sz_wave_ms ) && player.bo1sz_wave_ms == now )
	{
		return;
	}
	player.bo1sz_wave_ms = now;
	if ( !isDefined( level.zombie_health ) )
	{
		return;
	}
	d = Distance( player.origin, self.origin );
	if ( d < 1 )
	{
		return;
	}
	// Unit vector from the shooter to the zombie, flattened to the ground plane.
	dx = self.origin[ 0 ] - player.origin[ 0 ];
	dy = self.origin[ 1 ] - player.origin[ 1 ];
	flat = Distance( ( dx, dy, 0 ), ( 0, 0, 0 ) );
	if ( flat < 1 )
	{
		return;
	}
	off = pay_bal( "shockwave_offset" );
	r = pay_bal( "shockwave_radius" );
	if ( pay_arch( player, "blaster" ) >= 2 )
	{
		r = r * pay_rule( "blaster_t2_radius_mult" );
	}
	centre = self.origin + ( dx / flat * off, dy / flat * off, 30 );
	if ( Distance( player.origin, centre ) < r + pay_bal( "shockwave_player_margin" ) )
	{
		return;
	}
	amount = int( level.zombie_health * pay_bal( "shockwave_health_frac" ) * pay_aug_value( player, "blaster", "special", 1.0 ) );
	if ( amount < 1 )
	{
		amount = 1;
	}
	// Fire after the current damage callback finishes: the hit zombie is inside the
	// radius, and damaging it again from within its own callback would re-enter it.
	level thread pay_shockwave_fire( centre, r, amount, player );
}

pay_shockwave_fire( centre, r, amount, player )
{
	waittillframeend;
	if ( !isDefined( player ) )
	{
		return;
	}
	RadiusDamage( centre, r, amount, amount, player, "MOD_UNKNOWN" );
	pay_debug( player, "shotgun shockwave " + amount );
}

// Knocks the zombie down with the stock knockdown every zombie is given at spawn
// (self.thundergun_knockdown_func). It needs the Thundergun's knockdown values, which
// only maps that include the Thundergun load; elsewhere this does nothing.
// The user preferred this over a slowdown, which breaks trains.
pay_knockdown( player )
{
	self endon( "death" );
	if ( !isDefined( self.thundergun_knockdown_func ) || !isDefined( level.zombie_vars[ "thundergun_knockdown_damage" ] ) )
	{
		if ( !isDefined( level.bo1sz_pay_kd_warned ) )
		{
			level.bo1sz_pay_kd_warned = true;
			pay_log( "shotgun knockdown unavailable on this map (func=" + isDefined( self.thundergun_knockdown_func ) + " vars=" + isDefined( level.zombie_vars[ "thundergun_knockdown_damage" ] ) + ")" );
		}
		return;
	}
	now = getTime();
	if ( isDefined( self.bo1sz_kd_ms ) && now - self.bo1sz_kd_ms < pay_bal( "shotgun_knockdown_cooldown_ms" ) )
	{
		return;
	}
	self.bo1sz_kd_ms = now;
	// Let the shotgun's own damage resolve first.
	waittillframeend;
	if ( !isAlive( self ) )
	{
		return;
	}
	self [[ self.thundergun_knockdown_func ]]( player, false );
	pay_debug( player, "shotgun knockdown" );
}

// Slows the zombie's movement for a moment; a new hit restarts the timer.
pay_stagger()
{
	self endon( "death" );
	self notify( "bo1sz_stagger" );
	self endon( "bo1sz_stagger" );
	if ( !isDefined( self.bo1sz_stagger_base ) )
	{
		base = 1.0;
		if ( isDefined( self.moveplaybackrate ) )
		{
			base = self.moveplaybackrate;
		}
		self.bo1sz_stagger_base = base;
	}
	self.moveplaybackrate = self.bo1sz_stagger_base * pay_bal( "shotgun_stagger_rate" );
	wait pay_bal( "shotgun_stagger_seconds" );
	self.moveplaybackrate = self.bo1sz_stagger_base;
	self.bo1sz_stagger_base = undefined;
}

// Current streak, cleared once the timeout has passed since the last pistol headshot kill.
pay_pistol_streak( player )
{
	if ( !isDefined( player.bo1sz_pistol_streak ) )
	{
		player.bo1sz_pistol_streak = 0;
		player.bo1sz_pistol_ms = 0;
	}
	if ( player.bo1sz_pistol_streak > 0 && getTime() - player.bo1sz_pistol_ms > pay_pistol_timeout( player ) )
	{
		player.bo1sz_pistol_streak = 0;
	}
	return player.bo1sz_pistol_streak;
}

// ---------------------------------------------------------------------------
// Kills: streaks, shotgun blasts, style points, rank bonuses
// ---------------------------------------------------------------------------

pay_actor_killed( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime )
{
	if ( isDefined( level.bo1sz_pay_orig_killed ) )
	{
		self [[ level.bo1sz_pay_orig_killed ]]( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime );
	}
	if ( isDefined( attacker ) && isPlayer( attacker ) )
	{
		self pay_on_kill( attacker, sMeansOfDeath, sWeapon, sHitLoc );
	}
}

pay_on_kill( attacker, mod, weapon, hitloc )
{
	if ( !isDefined( mod ) )
	{
		mod = "";
	}
	cls = pay_class( weapon );
	head = pay_is_head( hitloc, mod );
	now = getTime();
	pts = 0;
	why = "";

	// Same-frame kill counter (multi-kills, shotgun blasts).
	if ( isDefined( attacker.bo1sz_pay_kill_ms ) && attacker.bo1sz_pay_kill_ms == now )
	{
		attacker.bo1sz_pay_kill_n++;
	}
	else
	{
		attacker.bo1sz_pay_kill_ms = now;
		attacker.bo1sz_pay_kill_n = 1;
	}
	extra = ( attacker.bo1sz_pay_kill_n > 1 );

	// Pistol headshot streak: grows on pistol headshot kills, resets on any other kill.
	streak = pay_pistol_streak( attacker );
	if ( cls == "pistol" && head )
	{
		attacker.bo1sz_pistol_streak = streak + 1;
		attacker.bo1sz_pistol_ms = now;
		steps = attacker.bo1sz_pistol_streak;
		cap = int( ( pay_pistol_max( attacker ) - 1.0 ) / pay_bal( "pistol_step_mult" ) );
		if ( steps > cap )
		{
			steps = cap;
		}
		pts += steps * pay_bal( "pistol_step_points" );
		why = why + " pistol_streak" + attacker.bo1sz_pistol_streak;
		bullets = pay_bal( "pistol_refund" );
		if ( pay_arch( attacker, "gunslinger" ) >= 2 )
		{
			bullets = pay_rule( "gunslinger_t2_refund" );
		}
		if ( pay_arch( attacker, "gunslinger" ) >= 3 && attacker.bo1sz_pistol_streak >= pay_rule( "gunslinger_t3_streak" ) )
		{
			bullets = WeaponClipSize( weapon );
		}
		pay_refund( attacker, weapon, bullets, "pistol headshot" );
	}
	else
	{
		attacker.bo1sz_pistol_streak = 0;
	}

	// Shotgun blasts.
	if ( cls == "spread" && extra )
	{
		pts += pay_bal( "shotgun_extra_kill_points" );
		why = why + " shotgun_multi" + attacker.bo1sz_pay_kill_n;
		if ( attacker.bo1sz_pay_kill_n == pay_bal( "shotgun_refund_kills" ) )
		{
			pay_refund( attacker, weapon, pay_bal( "shotgun_refund" ), "shotgun " + attacker.bo1sz_pay_kill_n + " kills" );
		}
	}

	// Launcher blasts that kill more than 5 refund a round (Short Fuse augment: fewer).
	need = pay_bal( "launcher_refund_kills" );
	if ( isDefined( attacker.bo1sz_aug ) && isDefined( attacker.bo1sz_aug[ "demo_fuse" ] ) )
	{
		need = pay_aug_value( attacker, "demolitions", "special", need );
	}
	if ( cls != "wonder" && cls != "none" && cls != "pistol" && pay_is_projectile( mod ) && attacker.bo1sz_pay_kill_n == need )
	{
		pay_refund( attacker, weapon, pay_bal( "launcher_refund" ), "launcher " + attacker.bo1sz_pay_kill_n + " kills" );
	}

	// Style points (real points, any weapon).
	if ( head )
	{
		pts += pay_bal( "style_headshot_points" );
		why = why + " headshot";
	}
	if ( extra )
	{
		pts += pay_bal( "style_multi_points" );
		why = why + " multi";
	}
	if ( pay_is_bullet( mod ) && Distance( attacker.origin, self.origin ) > pay_long_range( attacker ) )
	{
		pts += pay_bal( "style_long_range_points" );
		why = why + " long_range";
	}
	if ( mod == "MOD_MELEE" )
	{
		pts += pay_bal( "style_melee_points" );
		why = why + " melee";
	}

	// Style-rank bonuses: flat points per kill and an ammo-on-kill chance.
	rank = pay_rank( attacker );
	if ( isDefined( level.bo1sz_style_ranks_kill_bonus ) )
	{
		bonus = level.bo1sz_style_ranks_kill_bonus[ rank ];
		// High Roller run modifier doubles rank bonuses.
		if ( isDefined( level.bo1sz_rank_bonus_mult ) )
		{
			bonus = int( bonus * level.bo1sz_rank_bonus_mult );
		}
		if ( bonus > 0 )
		{
			pts += bonus;
			why = why + " rank" + rank;
		}
		chance = level.bo1sz_style_ranks_ammo_chance[ rank ];
		if ( chance > 0 && RandomInt( 100 ) < chance && isDefined( weapon ) && weapon != "none" && attacker HasWeapon( weapon ) )
		{
			n = int( WeaponClipSize( weapon ) * pay_bal( "ammo_refill_frac" ) );
			if ( n < 1 )
			{
				n = 1;
			}
			pay_refund( attacker, weapon, n, "rank ammo" );
		}
	}

	// Skirmisher Ascended: SMG kills refund bullets.
	if ( cls == "smg" && pay_arch( attacker, "skirmisher" ) >= 2 )
	{
		pay_refund( attacker, weapon, pay_rule( "skirmisher_t2_refund" ), "skirmisher" );
	}
	// Rifleman Ascended: assault rifle headshot kills refund bullets.
	if ( cls == "rifle" && head && pay_arch( attacker, "rifleman" ) >= 2 )
	{
		pay_refund( attacker, weapon, pay_rule( "rifleman_t2_refund" ), "rifleman" );
	}
	// Gunner capstone: LMG kills refund bullets.
	if ( cls == "mg" && pay_arch( attacker, "gunner" ) >= 3 )
	{
		pay_refund( attacker, weapon, pay_rule( "gunner_t3_refund" ), "gunner" );
	}

	// Demolitions Ascended: an explosive blast that kills 3 refunds a grenade.
	if ( pay_arch( attacker, "demolitions" ) >= 2 && cls != "wonder" && ( pay_is_projectile( mod ) || mod == "MOD_GRENADE" || mod == "MOD_GRENADE_SPLASH" || mod == "MOD_EXPLOSIVE" ) && attacker.bo1sz_pay_kill_n == pay_rule( "demolitions_t2_kills" ) )
	{
		attacker pay_give_grenade();
	}

	// Augments: points and magazine refunds for the archetype this kill belongs to.
	karch = pay_kill_arch( cls, mod, weapon );
	aug_pts = pay_aug_value( attacker, karch, "points", 0 );
	if ( aug_pts > 0 )
	{
		pts += aug_pts;
		why = why + " aug";
	}
	frac = pay_aug_value( attacker, karch, "refund", 0 );
	if ( frac > 0 )
	{
		gun = weapon;
		if ( mod == "MOD_MELEE" )
		{
			gun = attacker GetCurrentWeapon();
		}
		if ( isDefined( gun ) && gun != "none" )
		{
			n = int( WeaponClipSize( gun ) * frac );
			if ( n < 1 )
			{
				n = 1;
			}
			pay_refund( attacker, gun, n, "augment" );
		}
	}
	// Gadgeteer: claymore and monkey kills.
	if ( isDefined( weapon ) && ( isSubStr( weapon, "claymore" ) || isSubStr( weapon, "cymbal_monkey" ) ) )
	{
		gadget = pay_aug_value( attacker, "tech", "special", 0 );
		if ( gadget > 0 && isDefined( attacker.bo1sz_aug[ "tech_gadget" ] ) )
		{
			pts += gadget;
			why = why + " gadget";
		}
	}
	// Shockfist: melee kills release a small shockwave.
	if ( mod == "MOD_MELEE" && isDefined( attacker.bo1sz_aug ) && isDefined( attacker.bo1sz_aug[ "brawler_wave" ] ) )
	{
		self pay_shockfist( attacker );
	}

	self pay_capstones_on_kill( attacker, cls, mod, head );

	if ( isDefined( attacker.bo1sz_generalist ) && attacker.bo1sz_generalist )
	{
		pts += pay_rule( "generalist_kill_points" );
		why = why + " generalist";
	}

	pay_points( attacker, pts, "kill:" + why );
}

// ---------------------------------------------------------------------------
// Archetype helpers: which archetype a hit or kill belongs to, augment values
// ---------------------------------------------------------------------------

pay_kill_arch( cls, mod, weapon )
{
	if ( mod == "MOD_MELEE" )
	{
		return "brawler";
	}
	if ( cls == "wonder" )
	{
		return "tech";
	}
	if ( isDefined( weapon ) && ( isSubStr( weapon, "claymore" ) || isSubStr( weapon, "cymbal_monkey" ) ) )
	{
		return "tech";
	}
	if ( pay_is_projectile( mod ) || mod == "MOD_GRENADE" || mod == "MOD_GRENADE_SPLASH" || mod == "MOD_EXPLOSIVE" || cls == "rocketlauncher" || cls == "grenade" )
	{
		return "demolitions";
	}
	if ( cls == "pistol" )
	{
		return "gunslinger";
	}
	if ( cls == "spread" )
	{
		return "blaster";
	}
	if ( cls == "sniper" )
	{
		return "marksman";
	}
	if ( cls == "smg" )
	{
		return "skirmisher";
	}
	if ( cls == "rifle" )
	{
		return "rifleman";
	}
	if ( cls == "mg" )
	{
		return "gunner";
	}
	return "none";
}

// Value of the player's augment of `kind` for `arch`; `fallback` if they don't have one.
// "dmg" and "style" values multiply; "points", "refund" and "special" are taken as-is.
pay_aug_value( player, arch, kind, fallback )
{
	if ( !isDefined( player.bo1sz_aug ) || !isDefined( level.bo1sz_augments_count ) )
	{
		return fallback;
	}
	for ( i = 0; i < level.bo1sz_augments_count; i++ )
	{
		if ( isDefined( player.bo1sz_aug[ level.bo1sz_augments_id[ i ] ] ) && level.bo1sz_augments_arch[ i ] == arch && level.bo1sz_augments_kind[ i ] == kind )
		{
			return level.bo1sz_augments_value[ i ];
		}
	}
	return fallback;
}

pay_long_range( player )
{
	units = level.bo1sz_bal[ "style.long_range_units" ];
	if ( isDefined( player.bo1sz_aug ) && isDefined( player.bo1sz_aug[ "mark_eye" ] ) )
	{
		units = units * 0.5;
	}
	return units;
}

// Demolitions Ascended: one lethal grenade back (never above grenade_cap).
pay_give_grenade()
{
	list = self GetWeaponsList();
	for ( i = 0; i < list.size; i++ )
	{
		w = list[ i ];
		if ( isSubStr( w, "claymore" ) || isSubStr( w, "cymbal_monkey" ) )
		{
			continue;
		}
		if ( WeaponClass( w ) == "grenade" )
		{
			n = self GetWeaponAmmoClip( w );
			if ( n < pay_rule( "grenade_cap" ) )
			{
				self SetWeaponAmmoClip( w, n + 1 );
				pay_debug( self, "grenade refund " + w + " " + n + "->" + ( n + 1 ) );
			}
			return;
		}
	}
}

// Shockfist augment: a small shockwave just beyond a zombie killed by melee.
pay_shockfist( player )
{
	if ( !isDefined( level.zombie_health ) )
	{
		return;
	}
	dx = self.origin[ 0 ] - player.origin[ 0 ];
	dy = self.origin[ 1 ] - player.origin[ 1 ];
	flat = Distance( ( dx, dy, 0 ), ( 0, 0, 0 ) );
	if ( flat < 1 )
	{
		return;
	}
	off = 70;
	r = 60;
	centre = self.origin + ( dx / flat * off, dy / flat * off, 30 );
	if ( Distance( player.origin, centre ) < r + pay_bal( "shockwave_player_margin" ) )
	{
		return;
	}
	amount = int( level.zombie_health * pay_aug_value( player, "brawler", "special", 0.25 ) );
	if ( amount < 1 )
	{
		amount = 1;
	}
	level thread pay_shockwave_fire( centre, r, amount, player );
}

// ---------------------------------------------------------------------------
// Capstones that react to kills
// ---------------------------------------------------------------------------

// Area damage at `centre` credited to `player`, deferred to frame end. Never fires if the
// player could be inside the radius. `tag` marks the zombies it kills for chain reactions.
pay_safe_blast( player, centre, r, frac, why )
{
	if ( !isDefined( level.zombie_health ) )
	{
		return false;
	}
	if ( Distance( player.origin, centre ) < r + pay_bal( "shockwave_player_margin" ) )
	{
		return false;
	}
	amount = int( level.zombie_health * frac );
	if ( amount < 1 )
	{
		amount = 1;
	}
	level thread pay_shockwave_fire( centre, r, amount, player );
	pay_debug( player, why + " " + amount );
	return true;
}

pay_capstones_on_kill( attacker, cls, mod, head )
{
	now = getTime();
	centre = self.origin + ( 0, 0, 30 );

	// Marksman: every Nth sniper headshot kill detonates.
	if ( pay_arch( attacker, "marksman" ) >= 3 && cls == "sniper" && head )
	{
		if ( !isDefined( attacker.bo1sz_mark_hs ) )
		{
			attacker.bo1sz_mark_hs = 0;
		}
		attacker.bo1sz_mark_hs++;
		if ( attacker.bo1sz_mark_hs >= pay_rule( "marksman_t3_every" ) )
		{
			attacker.bo1sz_mark_hs = 0;
			pay_safe_blast( attacker, centre, pay_rule( "marksman_t3_radius" ), pay_rule( "marksman_t3_frac" ), "marksman detonation" );
		}
	}

	// Demolitions: a launcher kill sets off a second blast (once per blast).
	if ( pay_arch( attacker, "demolitions" ) >= 3 && cls != "wonder" && cls != "pistol" && pay_is_projectile( mod ) )
	{
		if ( !( isDefined( attacker.bo1sz_demo3_ms ) && attacker.bo1sz_demo3_ms == now ) )
		{
			attacker.bo1sz_demo3_ms = now;
			pay_safe_blast( attacker, centre, pay_rule( "demolitions_t3_radius" ), pay_rule( "demolitions_t3_frac" ), "demolitions second blast" );
		}
	}

	// Tech: a wonder weapon kill releases a mini shockwave (once per shot).
	if ( pay_arch( attacker, "tech" ) >= 3 && cls == "wonder" )
	{
		if ( !( isDefined( attacker.bo1sz_tech3_ms ) && attacker.bo1sz_tech3_ms == now ) )
		{
			attacker.bo1sz_tech3_ms = now;
			pay_safe_blast( attacker, centre, pay_rule( "tech_t3_radius" ), pay_rule( "tech_t3_frac" ), "tech shockwave" );
		}
	}

	// Blaster: zombies killed by a shockwave or blast (MOD_UNKNOWN from our area damage)
	// release their own, chaining through the crowd. Capped per second.
	if ( pay_arch( attacker, "blaster" ) >= 3 && mod == "MOD_UNKNOWN" )
	{
		if ( !isDefined( attacker.bo1sz_chain_ms ) || now - attacker.bo1sz_chain_ms >= 1000 )
		{
			attacker.bo1sz_chain_ms = now;
			attacker.bo1sz_chain_n = 0;
		}
		if ( attacker.bo1sz_chain_n < pay_rule( "blaster_t3_chain_max" ) )
		{
			frac = pay_bal( "shockwave_health_frac" ) * pay_aug_value( attacker, "blaster", "special", 1.0 );
			fired = pay_safe_blast( attacker, centre, pay_rule( "blaster_t3_radius" ), frac, "blaster chain " + attacker.bo1sz_chain_n );
			if ( fired )
			{
				attacker.bo1sz_chain_n++;
			}
		}
	}
}
