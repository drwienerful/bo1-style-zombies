// bo1-style-zombies: archetypes (Milestone 5).
// Reads the hidden per-run affinity the style meter builds (player.bo1sz_aff[id]) and at
// every round break grants archetype tiers into player.bo1sz_arch[id]:
//   1 Awakened   round >= awaken_round and affinity >= awaken_aff
//   2 Ascended   round >= ascend_round, affinity >= ascend_aff, at most max_ascended
//   3 Capstone   round >= cap_round, affinity >= cap_aff, share >= cap_focus, only one
// Tiers are never taken away. Effects live in the modules that own the mechanic
// (payoffs, style, perks) and check player.bo1sz_arch.
// Generalist: from generalist_round, no archetype Awakened and none with a share
// >= generalist_focus gives a flat bonus per kill (payoffs module).
//
// Ascended also offers a pick-1-of-3 augment (augments.csv) during the round break:
// USE cycles the highlight, holding USE chooses. The menu stays up until the player chooses.
//
// Dvars: bo1sz_archetypes 0 disables; bo1sz_arch_test 1 (before load) scales gates
// down for testing; bo1sz_arch_eval 1 (in game) evaluates immediately.
// Tunables: data/balance/archetypes.csv, archetype_rules.csv.

init()
{
	if ( getDvar( "zombiemode" ) != "1" && !( isDefined( level.is_zombie_level ) && level.is_zombie_level ) )
	{
		return;
	}
	if ( getDvar( "bo1sz_enable" ) == "0" || getDvar( "bo1sz_archetypes" ) == "0" )
	{
		return;
	}
	level thread arch_start();
}

arch_start()
{
	t = 0;
	while ( !isDefined( level.bo1sz_bal ) && t < 100 )
	{
		wait 0.05;
		t++;
	}
	if ( !isDefined( level.bo1sz_bal ) )
	{
		arch_log( "balance data missing; archetypes off" );
		return;
	}
	level.bo1sz_arch_test = ( getDvar( "bo1sz_arch_test" ) == "1" && getDvar( "bo1sz_dev" ) == "1" );
	setDvar( "bo1sz_arch_eval", "0" );
	arch_log( "archetypes on (count=" + level.bo1sz_archetypes_count + " test=" + level.bo1sz_arch_test + " max tier=" + arch_rule( "enabled_tier" ) + ")" );

	level.bo1sz_round_start_count = 0;
	level thread arch_round_start_watch();
	level thread arch_install_hooks();
	level thread arch_round_watch();
	level thread arch_eval_command();
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		players[ i ] thread arch_player();
	}
	for ( ;; )
	{
		level waittill( "connected", player );
		player thread arch_player();
	}
}

arch_rule( key )
{
	return level.bo1sz_bal[ "archetype_rules." + key ];
}

arch_log( msg )
{
	line = "[BO1SZ] archetypes: " + msg;
	println( line );
	logprint( line + "\n" );
}

// Round and affinity gates, scaled down in test mode.
arch_round_gate( key )
{
	g = arch_rule( key );
	if ( level.bo1sz_arch_test )
	{
		g = g * arch_rule( "test_round_scale" );
	}
	return g;
}

arch_aff_gate( key )
{
	g = arch_rule( key );
	if ( level.bo1sz_arch_test )
	{
		g = g * arch_rule( "test_aff_scale" );
	}
	return g;
}

// ---------------------------------------------------------------------------
// Per player
// ---------------------------------------------------------------------------

arch_player()
{
	self endon( "disconnect" );
	if ( isDefined( self.bo1sz_arch_started ) )
	{
		return;
	}
	self.bo1sz_arch_started = true;
	self waittill( "spawned_player" );

	self.bo1sz_arch = [];
	for ( i = 0; i < level.bo1sz_archetypes_count; i++ )
	{
		self.bo1sz_arch[ level.bo1sz_archetypes_id[ i ] ] = 0;
	}
	if ( !isDefined( self.bo1sz_aff ) )
	{
		self.bo1sz_aff = [];
	}
	self.bo1sz_generalist = false;
	self.bo1sz_arch_shown = "";
	self.bo1sz_pop_title = [];
	self.bo1sz_pop_desc = [];
	self.bo1sz_aug = [];
	self.bo1sz_aug_pending = [];
	// Pop-ups and the augment menu are created only while shown (HUD draw limit).
	self.bo1sz_pop_showing = false;
	self thread arch_popup_loop();
	self thread arch_augment_loop();
}

arch_center_elem( player, y, scale )
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

arch_aff( player, id )
{
	if ( isDefined( player.bo1sz_aff[ id ] ) )
	{
		return player.bo1sz_aff[ id ];
	}
	return 0;
}

arch_round_watch()
{
	for ( ;; )
	{
		level waittill( "end_of_round" );
		arch_eval_all();
	}
}

arch_eval_command()
{
	for ( ;; )
	{
		wait 0.5;
		v = getDvar( "bo1sz_arch_eval" );
		if ( v != "" && v != "0" && getDvar( "bo1sz_dev" ) == "1" )
		{
			setDvar( "bo1sz_arch_eval", "0" );
			arch_eval_all();
		}
	}
}

arch_eval_all()
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isDefined( players[ i ].bo1sz_arch ) )
		{
			players[ i ] arch_evaluate();
		}
	}
}

arch_evaluate()
{
	rnd = level.round_number;
	max_tier = arch_rule( "enabled_tier" );
	ids = level.bo1sz_archetypes_id;

	total = 0;
	for ( i = 0; i < ids.size; i++ )
	{
		total += arch_aff( self, ids[ i ] );
	}

	// Count existing Ascended / capstone holders before granting more.
	ascended = 0;
	capstone = false;
	for ( i = 0; i < ids.size; i++ )
	{
		if ( self.bo1sz_arch[ ids[ i ] ] >= 2 )
		{
			ascended++;
		}
		if ( self.bo1sz_arch[ ids[ i ] ] >= 3 )
		{
			capstone = true;
		}
	}

	// Highest affinity first, so the strongest archetypes take the limited slots.
	order = arch_sorted_ids();
	for ( k = 0; k < order.size; k++ )
	{
		id = order[ k ];
		a = arch_aff( self, id );
		tier = self.bo1sz_arch[ id ];

		if ( tier < 1 && max_tier >= 1 && rnd >= arch_round_gate( "awaken_round" ) && a >= arch_aff_gate( "awaken_aff" ) )
		{
			tier = 1;
			self arch_grant( id, 1 );
		}
		if ( tier == 1 && max_tier >= 2 && ascended < arch_rule( "max_ascended" ) && rnd >= arch_round_gate( "ascend_round" ) && a >= arch_aff_gate( "ascend_aff" ) )
		{
			tier = 2;
			ascended++;
			self arch_grant( id, 2 );
		}
		if ( tier == 2 && max_tier >= 3 && !capstone && rnd >= arch_round_gate( "cap_round" ) && a >= arch_aff_gate( "cap_aff" ) && total > 0 && a >= total * arch_rule( "cap_focus" ) )
		{
			capstone = true;
			self arch_grant( id, 3 );
		}
	}

	// Generalist: no Awakened archetype and no dominant share.
	any_awake = false;
	top_share = 0;
	for ( i = 0; i < ids.size; i++ )
	{
		if ( self.bo1sz_arch[ ids[ i ] ] >= 1 )
		{
			any_awake = true;
		}
		if ( total > 0 && arch_aff( self, ids[ i ] ) / total > top_share )
		{
			top_share = arch_aff( self, ids[ i ] ) / total;
		}
	}
	was = self.bo1sz_generalist;
	self.bo1sz_generalist = ( !any_awake && total > 0 && rnd >= arch_round_gate( "generalist_round" ) && top_share < arch_rule( "generalist_focus" ) );
	if ( self.bo1sz_generalist && !was )
	{
		self arch_queue_popup( "Generalist", "+" + arch_rule( "generalist_kill_points" ) + " points per kill" );
	}

	self arch_update_hud_name();
	arch_log( "eval " + self.playername + " round=" + rnd + " total=" + int( total ) + " " + arch_summary( self ) + " generalist=" + self.bo1sz_generalist );
}

arch_grant( id, tier )
{
	self.bo1sz_arch[ id ] = tier;
	i = arch_index( id );
	name = level.bo1sz_archetypes_name[ i ];
	if ( tier == 1 )
	{
		self arch_queue_popup( "Awakened: " + name, level.bo1sz_archetypes_awakened[ i ] );
	}
	else if ( tier == 2 )
	{
		self arch_queue_popup( "Ascended: " + name, level.bo1sz_archetypes_ascended[ i ] );
		self.bo1sz_aug_pending[ self.bo1sz_aug_pending.size ] = id;
	}
	else
	{
		self arch_queue_popup( "Capstone: " + name, level.bo1sz_archetypes_capstone[ i ] );
	}
	arch_log( self.playername + " " + id + " -> tier " + tier );
}

arch_index( id )
{
	for ( i = 0; i < level.bo1sz_archetypes_count; i++ )
	{
		if ( level.bo1sz_archetypes_id[ i ] == id )
		{
			return i;
		}
	}
	return 0;
}

// Archetype ids sorted by this player's affinity, highest first (simple selection sort).
arch_sorted_ids()
{
	ids = [];
	for ( i = 0; i < level.bo1sz_archetypes_count; i++ )
	{
		ids[ i ] = level.bo1sz_archetypes_id[ i ];
	}
	for ( i = 0; i < ids.size; i++ )
	{
		best = i;
		for ( j = i + 1; j < ids.size; j++ )
		{
			if ( arch_aff( self, ids[ j ] ) > arch_aff( self, ids[ best ] ) )
			{
				best = j;
			}
		}
		tmp = ids[ i ];
		ids[ i ] = ids[ best ];
		ids[ best ] = tmp;
	}
	return ids;
}

arch_summary( player )
{
	s = "";
	ids = level.bo1sz_archetypes_id;
	for ( i = 0; i < ids.size; i++ )
	{
		s = s + ids[ i ] + "=" + int( arch_aff( player, ids[ i ] ) ) + "/t" + player.bo1sz_arch[ ids[ i ] ] + " ";
	}
	return s;
}

// Show the leading earned archetype beside the style meter (style module's HUD slot).
arch_update_hud_name()
{
	if ( !isDefined( self.bo1sz_hud_arch ) )
	{
		return;
	}
	best = "";
	best_tier = 0;
	best_aff = -1;
	ids = level.bo1sz_archetypes_id;
	for ( i = 0; i < ids.size; i++ )
	{
		tier = self.bo1sz_arch[ ids[ i ] ];
		a = arch_aff( self, ids[ i ] );
		if ( tier > best_tier || ( tier == best_tier && tier > 0 && a > best_aff ) )
		{
			best = level.bo1sz_archetypes_name[ i ];
			best_tier = tier;
			best_aff = a;
		}
	}
	if ( best == "" && self.bo1sz_generalist )
	{
		best = "Generalist";
	}
	if ( best != self.bo1sz_arch_shown )
	{
		self.bo1sz_arch_shown = best;
		self.bo1sz_hud_arch SetText( best );
	}
}

// ---------------------------------------------------------------------------
// Round-break pop-ups: one line plus a short description, one at a time
// ---------------------------------------------------------------------------

arch_queue_popup( title, desc )
{
	self.bo1sz_pop_title[ self.bo1sz_pop_title.size ] = title;
	self.bo1sz_pop_desc[ self.bo1sz_pop_desc.size ] = desc;
}

arch_popup_loop()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		wait 0.25;
		if ( self.bo1sz_pop_title.size == 0 )
		{
			continue;
		}
		title = self.bo1sz_pop_title[ 0 ];
		desc = self.bo1sz_pop_desc[ 0 ];
		rest_t = [];
		rest_d = [];
		for ( i = 1; i < self.bo1sz_pop_title.size; i++ )
		{
			rest_t[ rest_t.size ] = self.bo1sz_pop_title[ i ];
			rest_d[ rest_d.size ] = self.bo1sz_pop_desc[ i ];
		}
		self.bo1sz_pop_title = rest_t;
		self.bo1sz_pop_desc = rest_d;

		self.bo1sz_pop_showing = true;
		self.bo1sz_arch_pop1 = arch_center_elem( self, -170, 1.7 );
		self.bo1sz_arch_pop2 = arch_center_elem( self, -148, 1.2 );
		self.bo1sz_arch_pop1 SetText( title );
		self.bo1sz_arch_pop2 SetText( desc );
		self.bo1sz_arch_pop1 FadeOverTime( 0.2 );
		self.bo1sz_arch_pop2 FadeOverTime( 0.2 );
		self.bo1sz_arch_pop1.alpha = 1;
		self.bo1sz_arch_pop2.alpha = 1;
		self PlayLocalSound( "zmb_perks_power_on" );
		wait arch_rule( "popup_seconds" );
		self.bo1sz_arch_pop1 FadeOverTime( 0.4 );
		self.bo1sz_arch_pop2 FadeOverTime( 0.4 );
		self.bo1sz_arch_pop1.alpha = 0;
		self.bo1sz_arch_pop2.alpha = 0;
		wait 0.5;
		self.bo1sz_arch_pop1 Destroy();
		self.bo1sz_arch_pop2 Destroy();
		self.bo1sz_arch_pop1 = undefined;
		self.bo1sz_arch_pop2 = undefined;
		self.bo1sz_pop_showing = false;
	}
}

// ---------------------------------------------------------------------------
// Augments: pick 1 of 3 at Ascended (augments.csv)
// ---------------------------------------------------------------------------

arch_round_start_watch()
{
	for ( ;; )
	{
		level waittill( "start_of_round" );
		level.bo1sz_round_start_count++;
	}
}

// Three distinct random augment indexes from one archetype's pool.
arch_offer( arch )
{
	pool = [];
	for ( i = 0; i < level.bo1sz_augments_count; i++ )
	{
		if ( level.bo1sz_augments_arch[ i ] == arch && !isDefined( self.bo1sz_aug[ level.bo1sz_augments_id[ i ] ] ) )
		{
			pool[ pool.size ] = i;
		}
	}
	offer = [];
	while ( offer.size < 3 && pool.size > 0 )
	{
		k = RandomInt( pool.size );
		offer[ offer.size ] = pool[ k ];
		rest = [];
		for ( j = 0; j < pool.size; j++ )
		{
			if ( j != k )
			{
				rest[ rest.size ] = pool[ j ];
			}
		}
		pool = rest;
	}
	return offer;
}

arch_augment_loop()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		wait 0.25;
		// Wait until there is a pending choice and the pop-ups have finished.
		if ( self.bo1sz_aug_pending.size == 0 || self.bo1sz_pop_title.size > 0 || self.bo1sz_pop_showing )
		{
			continue;
		}
		arch = self.bo1sz_aug_pending[ 0 ];
		rest = [];
		for ( i = 1; i < self.bo1sz_aug_pending.size; i++ )
		{
			rest[ rest.size ] = self.bo1sz_aug_pending[ i ];
		}
		self.bo1sz_aug_pending = rest;

		offer = self arch_offer( arch );
		if ( offer.size == 0 )
		{
			continue;
		}
		pick = self arch_choose( arch, offer );
		self.bo1sz_aug[ level.bo1sz_augments_id[ pick ] ] = true;
		self arch_queue_popup( "Augment: " + level.bo1sz_augments_name[ pick ], level.bo1sz_augments_desc[ pick ] );
		arch_log( self.playername + " augment " + level.bo1sz_augments_id[ pick ] );
	}
}

// Shows the offer until the player picks: USE cycles, holding USE picks.
// (Auto-picking at round start closed the menu before it could be read.)
arch_choose( arch, offer )
{
	self endon( "disconnect" );
	sel = 0;
	hold_ms = 0;
	was_down = self UseButtonPressed();
	self.bo1sz_aug_lines = [];
	for ( i = 0; i < 4; i++ )
	{
		self.bo1sz_aug_lines[ i ] = arch_center_elem( self, -40 + i * 22, 1.25 );
	}
	self.bo1sz_aug_lines[ 0 ] SetText( "Choose an augment: " + level.bo1sz_archetypes_name[ arch_index( arch ) ] + "  (USE: next, hold USE: pick)" );
	self.bo1sz_aug_lines[ 0 ].alpha = 1;
	self arch_draw_offer( offer, sel );
	self PlayLocalSound( "zmb_perks_power_on" );
	choice = -1;
	while ( choice < 0 )
	{
		wait 0.05;
		down = self UseButtonPressed();
		if ( down && !was_down )
		{
			hold_ms = getTime();
		}
		if ( down && hold_ms > 0 && getTime() - hold_ms >= level.bo1sz_bal[ "archetype_rules.aug_hold_seconds" ] * 1000 )
		{
			choice = sel;
			break;
		}
		if ( !down && was_down && hold_ms > 0 )
		{
			// Short press: next option.
			sel = ( sel + 1 ) % offer.size;
			self arch_draw_offer( offer, sel );
			hold_ms = 0;
		}
		was_down = down;
	}
	for ( i = 0; i < self.bo1sz_aug_lines.size; i++ )
	{
		self.bo1sz_aug_lines[ i ] Destroy();
	}
	self.bo1sz_aug_lines = undefined;
	self PlayLocalSound( "zmb_cha_ching" );
	return offer[ choice ];
}

arch_draw_offer( offer, sel )
{
	for ( i = 0; i < 3; i++ )
	{
		line = self.bo1sz_aug_lines[ i + 1 ];
		if ( i >= offer.size )
		{
			line.alpha = 0;
			continue;
		}
		idx = offer[ i ];
		if ( i == sel )
		{
			line SetText( "> " + level.bo1sz_augments_name[ idx ] + ": " + level.bo1sz_augments_desc[ idx ] );
			line.color = ( 1, 0.85, 0.2 );
		}
		else
		{
			line SetText( level.bo1sz_augments_name[ idx ] + ": " + level.bo1sz_augments_desc[ idx ] );
			line.color = ( 0.8, 0.8, 0.8 );
		}
		line.alpha = 1;
	}
}

// ---------------------------------------------------------------------------
// Brawler capstone: all damage taken x0.5 (chained player-damage wrapper, stock first).
// The first hits are verified against the real health drop and logged, which also
// settles Phase 0's open item B8 (modifying player damage).
// ---------------------------------------------------------------------------

arch_install_hooks()
{
	t = 0;
	while ( !isDefined( level.overridePlayerDamage ) && t < 300 )
	{
		wait 0.1;
		t++;
	}
	for ( i = 0; i < 10; i++ )
	{
		waittillframeend;
	}
	level.bo1sz_arch_orig_pdamage = level.overridePlayerDamage;
	level.overridePlayerDamage = ::arch_player_damage;
}

arch_player_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime )
{
	dmg = iDamage;
	if ( isDefined( level.bo1sz_arch_orig_pdamage ) )
	{
		dmg = self [[ level.bo1sz_arch_orig_pdamage ]]( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime );
	}
	if ( !isDefined( dmg ) )
	{
		dmg = iDamage;
	}
	if ( dmg > 0 && isDefined( self.bo1sz_arch ) && isDefined( self.bo1sz_arch[ "brawler" ] ) && self.bo1sz_arch[ "brawler" ] >= 3 )
	{
		reduced = int( dmg * arch_rule( "brawler_t3_damage_taken" ) );
		if ( reduced < 1 )
		{
			reduced = 1;
		}
		if ( !isDefined( self.bo1sz_brawler_checks ) )
		{
			self.bo1sz_brawler_checks = 0;
		}
		if ( self.bo1sz_brawler_checks < 3 )
		{
			self.bo1sz_brawler_checks++;
			self thread arch_verify_drop( self.health, dmg, reduced );
		}
		return reduced;
	}
	return dmg;
}

arch_verify_drop( before, full, reduced )
{
	waittillframeend;
	arch_log( self.playername + " brawler capstone hit: stock=" + full + " reduced=" + reduced + " health drop=" + ( before - self.health ) );
}
