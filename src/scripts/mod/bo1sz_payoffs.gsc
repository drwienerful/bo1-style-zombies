// bo1-style-zombies: weapon payoffs and style-based points (Milestone 3).
// Every effect ADDS power or reward; nothing is ever reduced (CLAUDE.md rule 7).
//
//   Pistols   headshot-kill streak ramps damage (cap x3.5), +points per step, bullet refund
//   Snipers   each extra zombie one shot passes through takes more damage, +points
//   Shotguns  +points per extra kill from one blast, shell refund on 3+ kills
//   Launchers +points for every zombie caught in the blast
//   Any       real bonus points for headshot / multi-kill / long-range / melee kills,
//             plus a per-kill bonus and an ammo-on-kill chance from the style rank
// Wonder weapons (payoffs.excluded_weapons) get none of the class payoffs.
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
		dmg = self pay_on_damage( attacker, dmg, meansofdeath, weapon );
	}
	return dmg;
}

pay_on_damage( attacker, dmg, mod, weapon )
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
			if ( mult > pay_bal( "pistol_max_mult" ) )
			{
				mult = pay_bal( "pistol_max_mult" );
			}
		}
	}

	// Snipers: the Nth zombie one shot passes through takes extra damage and pays points.
	if ( cls == "sniper" && pay_is_bullet( mod ) )
	{
		if ( isDefined( attacker.bo1sz_pierce_ms ) && attacker.bo1sz_pierce_ms == now )
		{
			attacker.bo1sz_pierce_n++;
			mult = 1.0 + ( attacker.bo1sz_pierce_n - 1 ) * pay_bal( "sniper_pierce_mult" );
			pay_points( attacker, pay_bal( "sniper_pierce_points" ), "sniper pierce x" + attacker.bo1sz_pierce_n );
		}
		else
		{
			attacker.bo1sz_pierce_ms = now;
			attacker.bo1sz_pierce_n = 1;
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

	if ( mult > 1.0 )
	{
		return int( dmg * mult );
	}
	return dmg;
}

// Current streak, cleared once the timeout has passed since the last pistol headshot kill.
pay_pistol_streak( player )
{
	if ( !isDefined( player.bo1sz_pistol_streak ) )
	{
		player.bo1sz_pistol_streak = 0;
		player.bo1sz_pistol_ms = 0;
	}
	if ( player.bo1sz_pistol_streak > 0 && getTime() - player.bo1sz_pistol_ms > pay_bal( "pistol_streak_timeout_ms" ) )
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
		cap = int( ( pay_bal( "pistol_max_mult" ) - 1.0 ) / pay_bal( "pistol_step_mult" ) );
		if ( steps > cap )
		{
			steps = cap;
		}
		pts += steps * pay_bal( "pistol_step_points" );
		why = why + " pistol_streak" + attacker.bo1sz_pistol_streak;
		pay_refund( attacker, weapon, pay_bal( "pistol_refund" ), "pistol headshot" );
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
	if ( pay_is_bullet( mod ) && Distance( attacker.origin, self.origin ) > level.bo1sz_bal[ "style.long_range_units" ] )
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

	pay_points( attacker, pts, "kill:" + why );
}
