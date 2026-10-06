// bo1-style-zombies: in-game codex overlay (Milestone 5).
// Every player: hold ADS + USE for about a second to cycle pages 1 -> 2 -> 3 -> closed.
// Host console (or a key bind):  set bo1sz_codex 1 | 2 | 3 opens a page, 0 closes. In co-op the
// console dvar lives on the host's game, so it only drives the host's codex (co-op test).
//   1  style rank and archetype affinity
//   2  archetype traits earned
//   3  augments and perk tiers
// Example bind: bind F2 "set bo1sz_codex 1". Full details are in CODEX.md.
// The page is drawn when opened or switched (not every frame) to keep the number of
// distinct HUD strings low. Dvar: bo1sz_codex_off 1 disables this module.

init()
{
	if ( getDvar( "zombiemode" ) != "1" && !( isDefined( level.is_zombie_level ) && level.is_zombie_level ) )
	{
		return;
	}
	if ( getDvar( "bo1sz_enable" ) == "0" || getDvar( "bo1sz_codex_off" ) == "1" )
	{
		return;
	}
	// Precache must happen before the first wait of the level.
	PrecacheShader( "white" );
	level thread codex_start();
}

codex_start()
{
	t = 0;
	while ( !isDefined( level.bo1sz_bal ) && t < 100 )
	{
		wait 0.05;
		t++;
	}
	if ( !isDefined( level.bo1sz_bal ) )
	{
		return;
	}
	setDvar( "bo1sz_codex", "0" );
	level thread codex_on_connect();
	shown = "0";
	for ( ;; )
	{
		wait 0.25;
		v = getDvar( "bo1sz_codex" );
		if ( v == "" )
		{
			v = "0";
		}
		if ( v == shown )
		{
			continue;
		}
		shown = v;
		players = GetPlayers();
		if ( players.size > 0 )
		{
			players[ 0 ].bo1sz_codex_page = v;
			players[ 0 ] codex_show( v );
		}
	}
}

// Per-player toggle: hold ADS + USE ~0.8s to cycle 1 -> 2 -> 3 -> closed.
codex_player_toggle()
{
	self endon( "disconnect" );
	self.bo1sz_codex_page = "0";
	hold_ms = 0;
	for ( ;; )
	{
		wait 0.1;
		ads_held = self AdsButtonPressed();
		use_held = self UseButtonPressed();
		if ( !( ads_held && use_held ) )
		{
			hold_ms = 0;
			continue;
		}
		if ( hold_ms == 0 )
		{
			hold_ms = getTime();
			continue;
		}
		if ( getTime() - hold_ms < 800 )
		{
			continue;
		}
		nxt = "1";
		if ( self.bo1sz_codex_page == "1" )
		{
			nxt = "2";
		}
		else if ( self.bo1sz_codex_page == "2" )
		{
			nxt = "3";
		}
		else if ( self.bo1sz_codex_page == "3" )
		{
			nxt = "0";
		}
		self.bo1sz_codex_page = nxt;
		self codex_show( nxt );
		// Wait for release before the next step.
		while ( ads_held && use_held )
		{
			wait 0.05;
			ads_held = self AdsButtonPressed();
			use_held = self UseButtonPressed();
		}
		hold_ms = 0;
	}
}

codex_on_connect()
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		players[ i ] thread codex_player_toggle();
	}
	for ( ;; )
	{
		level waittill( "connected", player );
		player thread codex_player_toggle();
	}
}

codex_elems()
{
	if ( isDefined( self.bo1sz_codex_lines ) )
	{
		return;
	}
	bg = NewClientHudElem( self );
	bg.horzAlign = "user_center";
	bg.vertAlign = "middle";
	bg.alignX = "center";
	bg.alignY = "middle";
	bg.y = 0;
	bg.color = ( 0, 0, 0 );
	bg.alpha = 0;
	bg SetShader( "white", 460, 330 );
	self.bo1sz_codex_bg = bg;
	self.bo1sz_codex_lines = [];
	for ( i = 0; i < 14; i++ )
	{
		e = NewClientHudElem( self );
		e.horzAlign = "user_center";
		e.vertAlign = "middle";
		e.alignX = "left";
		e.alignY = "middle";
		e.x = -215;
		e.y = -140 + i * 21;
		e.fontScale = 1.15;
		e.foreground = true;
		e.alpha = 0;
		self.bo1sz_codex_lines[ i ] = e;
	}
}

codex_show( page )
{
	lines = [];
	if ( page == "1" )
	{
		lines = self codex_page_style();
	}
	else if ( page == "2" )
	{
		lines = self codex_page_traits();
	}
	else if ( page == "3" )
	{
		lines = self codex_page_augments();
	}
	if ( lines.size == 0 )
	{
		// Closed: destroy the panel (HUD draw limit) rather than hide it.
		if ( isDefined( self.bo1sz_codex_lines ) )
		{
			self.bo1sz_codex_bg Destroy();
			for ( i = 0; i < self.bo1sz_codex_lines.size; i++ )
			{
				self.bo1sz_codex_lines[ i ] Destroy();
			}
			self.bo1sz_codex_bg = undefined;
			self.bo1sz_codex_lines = undefined;
		}
		return;
	}
	self codex_elems();
	lines[ lines.size ] = "bo1sz_codex 1 / 2 / 3: pages   0: close";
	self.bo1sz_codex_bg.alpha = 0.7;
	for ( i = 0; i < self.bo1sz_codex_lines.size; i++ )
	{
		e = self.bo1sz_codex_lines[ i ];
		if ( i < lines.size )
		{
			e SetText( lines[ i ] );
			e.color = ( 0.9, 0.9, 0.9 );
			if ( i == 0 )
			{
				e.color = ( 1, 0.85, 0.2 );
			}
			e.alpha = 1;
		}
		else
		{
			e.alpha = 0;
		}
	}
}

codex_tier_name( tier )
{
	if ( tier >= 3 )
	{
		return "Capstone";
	}
	if ( tier == 2 )
	{
		return "Ascended";
	}
	if ( tier == 1 )
	{
		return "Awakened";
	}
	return "-";
}

codex_page_style()
{
	lines = [];
	lines[ 0 ] = "CODEX 1/3: Style and affinity";
	if ( isDefined( self.bo1sz_style_rank ) )
	{
		r = self.bo1sz_style_rank;
		lines[ lines.size ] = "Style rank: " + level.bo1sz_style_ranks_letter[ r ] + "  " + level.bo1sz_style_ranks_word[ r ];
	}
	for ( i = 0; i < level.bo1sz_archetypes_count; i++ )
	{
		id = level.bo1sz_archetypes_id[ i ];
		a = 0;
		if ( isDefined( self.bo1sz_aff ) && isDefined( self.bo1sz_aff[ id ] ) )
		{
			a = int( self.bo1sz_aff[ id ] );
		}
		tier = 0;
		if ( isDefined( self.bo1sz_arch ) && isDefined( self.bo1sz_arch[ id ] ) )
		{
			tier = self.bo1sz_arch[ id ];
		}
		lines[ lines.size ] = level.bo1sz_archetypes_name[ i ] + ":  " + a + "  (" + codex_tier_name( tier ) + ")";
	}
	if ( isDefined( self.bo1sz_generalist ) && self.bo1sz_generalist )
	{
		lines[ lines.size ] = "Generalist bonus active";
	}
	return lines;
}

codex_page_traits()
{
	lines = [];
	lines[ 0 ] = "CODEX 2/3: Archetype traits";
	for ( i = 0; i < level.bo1sz_archetypes_count; i++ )
	{
		id = level.bo1sz_archetypes_id[ i ];
		tier = 0;
		if ( isDefined( self.bo1sz_arch ) && isDefined( self.bo1sz_arch[ id ] ) )
		{
			tier = self.bo1sz_arch[ id ];
		}
		name = level.bo1sz_archetypes_name[ i ];
		if ( tier >= 1 )
		{
			lines[ lines.size ] = name + " I: " + level.bo1sz_archetypes_awakened[ i ];
		}
		if ( tier >= 2 )
		{
			lines[ lines.size ] = name + " II: " + level.bo1sz_archetypes_ascended[ i ];
		}
		if ( tier >= 3 )
		{
			lines[ lines.size ] = name + " III: " + level.bo1sz_archetypes_capstone[ i ];
		}
	}
	if ( lines.size == 1 )
	{
		lines[ lines.size ] = "No archetype awakened yet (from round 5).";
	}
	return codex_clip( lines );
}

codex_page_augments()
{
	lines = [];
	lines[ 0 ] = "CODEX 3/3: Augments and perk tiers";
	if ( isDefined( self.bo1sz_aug ) )
	{
		for ( i = 0; i < level.bo1sz_augments_count; i++ )
		{
			if ( isDefined( self.bo1sz_aug[ level.bo1sz_augments_id[ i ] ] ) )
			{
				lines[ lines.size ] = level.bo1sz_augments_name[ i ] + ": " + level.bo1sz_augments_desc[ i ];
			}
		}
	}
	if ( isDefined( self.bo1sz_tier ) && isDefined( level.bo1sz_tier_name ) )
	{
		keys = getArrayKeys( self.bo1sz_tier );
		for ( k = 0; k < keys.size; k++ )
		{
			lines[ lines.size ] = level.bo1sz_tier_name[ keys[ k ] ] + ": " + level.bo1sz_tier_desc[ keys[ k ] ];
		}
	}
	if ( lines.size == 1 )
	{
		lines[ lines.size ] = "No augments or perk tiers yet.";
	}
	return codex_clip( lines );
}

// Keep room for the footer line.
codex_clip( lines )
{
	if ( lines.size <= 13 )
	{
		return lines;
	}
	out = [];
	for ( i = 0; i < 12; i++ )
	{
		out[ i ] = lines[ i ];
	}
	out[ 12 ] = "... (" + ( lines.size - 12 ) + " more)";
	return out;
}
