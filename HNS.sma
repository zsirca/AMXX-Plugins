#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <engine>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>

#define HUD_MONEY    ( 1 << 5 )
#define IsPlayer(%1) ( 1 <= %1 <= g_iMaxPlayers )

const m_pPlayer    = 41;
const m_fPainShock = 108;
const m_iHideHUD   = 361;

new const g_szGamename[ ] = "Escondidas EVG";

new g_iMaxPlayers, g_iMsgScreenFade, g_iMsgSendAudio, g_iMsgStatusText, g_iMsgStatusValue, g_iNubSlash, g_iTimer, g_iTimerEntity, g_iSendAudioMessage;

new Float:g_flRoundStartTime;
new Trie:g_tRoundStartSounds, bool:g_bStart, bool:g_bNewGrens, bool:g_bAlive[ 33 ], bool:g_bSolid[ 33 ], bool:g_bRestore[ 33 ], bool:g_bSawPlayer[ 33 ], Float:g_flLastAimDetail[ 33 ], CsTeams:g_iTeam[ 33 ], g_iSpawnCount[ 33 ], g_szCountry[ 33 ][ 46 ], g_iSprSmoke

new g_bScrim, g_iScores[ 2 ], g_szNames[ 2 ][ 32 ];



public plugin_init( ) {
	register_plugin( "HideNSeek", "1.0", "zsirca" );

	g_iMsgScreenFade  = get_user_msgid( "ScreenFade" );
	g_iMsgSendAudio   = get_user_msgid( "SendAudio" );

	g_iMsgStatusText  = get_user_msgid( "StatusText" );
	g_iMsgStatusValue = get_user_msgid( "StatusValue" );
	g_iMaxPlayers     = get_maxplayers( );
	
	g_iTimerEntity    = create_entity( "info_target" );
	set_pev( g_iTimerEntity, pev_classname, "hns_timer" );
	
	register_logevent( "EventRoundStart", 2, "0=World triggered", "1=Round_Start" );
	
	register_event( "HLTV",       "EventNewRound",   "a", "1=0", "2=0" );
	register_event( "TextMsg",    "EventRestart",    "a", "2&#Game_C", "2&#Game_w" );
	register_event( "SendAudio",  "EventWin_TS",     "a", "2=%!MRAD_terwin" );
	register_event( "SendAudio",  "EventWin_CT",     "a", "2=%!MRAD_ctwin" );
	register_event( "TeamInfo",   "EventTeamInfo",   "a" );
	register_event( "DeathMsg",   "EventDeathMsg",   "a" );
	register_event( "HideWeapon", "EventHideWeapon", "b" );
	register_event( "ResetHUD",   "EventResetHUD",   "b" );
	register_event( "Money",      "EventMoney",      "b" );
	
	register_message( get_user_msgid( "StatusIcon" ), "MsgStatusIcon" );
	register_message( get_user_msgid( "TextMsg" ),    "MsgTextMsg" );
	register_message( g_iMsgScreenFade,               "MsgScreenFade" );
	
	register_forward( FM_AddToFullPack,      "FwdAddToFullPack", 1 );
	register_forward( FM_PlayerPreThink,     "FwdPlayerPreThink" );
	register_forward( FM_PlayerPostThink,    "FwdPlayerPostThink" );
	register_forward( FM_GetGameDescription, "FwdGameDesc" );
	register_forward( FM_EmitSound,          "FwdEmitSound" );
	register_forward( FM_ClientKill,         "FwdClientKill" );
	register_forward(FM_CmdStart, "CmdStart" )
	register_think( "hns_timer",             "FwdThinkTimer" );
	
	RegisterHam( Ham_Weapon_PrimaryAttack,   "weapon_knife", "FwdHamKnifePrimaryAttack" );
	RegisterHam( Ham_Weapon_SecondaryAttack, "weapon_knife", "FwdHamKnifeSecondaryAttack" );
	
	RegisterHam( Ham_Spawn,  "grenade",   "FwdHamSpawn_Grenade",   1 );
	RegisterHam( Ham_Spawn,  "weaponbox", "FwdHamSpawn_Weaponbox", 1 );
	RegisterHam( Ham_Spawn,  "player",    "FwdHamSpawn_Player",    1 );
	RegisterHam( Ham_Killed, "player",    "FwdHamKilled_Player",   1 );
	RegisterHam( Ham_TakeDamage, "player", "FwdHamTakeDamage",     1 );
	
	
	set_msg_block( get_user_msgid( "WeapPickup" ), BLOCK_SET );
	set_msg_block( get_user_msgid( "AmmoPickup" ), BLOCK_SET );
	set_msg_block( get_user_msgid( "HostagePos" ), BLOCK_SET );
	
	new const szStartRadios[ ][ ] = { "%!MRAD_GO", "%!MRAD_LOCKNLOAD", "%!MRAD_LETSGO", "%!MRAD_MOVEOUT" };
	g_tRoundStartSounds = TrieCreate( );
	
	for( new i; i < sizeof szStartRadios; i++ )
		TrieSetCell( g_tRoundStartSounds, szStartRadios[ i ], 1 );
	
	new const szRemoveEntities[ ][ ] = {
		"func_hostage_rescue", "info_hostage_rescue", "game_player_equip",
		"func_bomb_target", "info_bomb_target", "hostage_entity",
		"info_vip_start", "func_vip_safetyzone", "func_escapezone",
		"info_map_parameters", "player_weaponstrip", "func_buyzone", "armoury_entity"
	};
	
	for( new i; i < sizeof szRemoveEntities; i++ )
		remove_entity_name( szRemoveEntities[ i ] );
	
	new iHostage = create_entity( "hostage_entity" );
	engfunc( EngFunc_SetOrigin, iHostage, { 0.0, 0.0, -55000.0 } );
	engfunc( EngFunc_SetSize, iHostage, { -1.0, -1.0, -1.0 }, { 1.0, 1.0, 1.0 } );
	dllfunc( DLLFunc_Spawn, iHostage );
	
}

public plugin_precache( ) {
	g_iSprSmoke = precache_model( "sprites/smoke.spr" );
	
	precache_sound( "items/smallmedkit1.wav" );
	precache_sound( "evg_sound/one.wav" );
	precache_sound( "evg_sound/two.wav" );
	precache_sound( "evg_sound/three.wav" );
	precache_sound( "evg_sound/four.wav" );
	precache_sound( "evg_sound/five.wav" );
	precache_sound( "evg_sound/six.wav" );
	precache_sound( "evg_sound/seven.wav" );
	precache_sound( "evg_sound/eight.wav" );
	precache_sound( "evg_sound/nine.wav" );
	precache_sound( "evg_sound/ten.wav" );
	
	
}
 
public CmdStart(const Client, const uc_handle, random_seed) {
    
    if(!is_user_alive(Client))
        return FMRES_IGNORED
    
    static clip, ammo;
    if(get_user_weapon(Client, clip, ammo) != CSW_KNIFE)
        return FMRES_IGNORED
    
    if(get_user_team(Client) == 1) {
        new button = get_uc(uc_handle, UC_Buttons);
        
        if(button&IN_ATTACK)
            button &= ~IN_ATTACK;
        if(button&IN_ATTACK2)
            button &= ~IN_ATTACK2;
        
        set_uc(uc_handle, UC_Buttons, button);
        
        return FMRES_SUPERCEDE;
    }
    else if(get_user_team(Client)== 2) {
        new button = get_uc(uc_handle, UC_Buttons);
        
        if(button&IN_ATTACK) {
            button &= ~IN_ATTACK;
            button |= IN_ATTACK2;
        }
        
        set_uc(uc_handle, UC_Buttons, button);
        
        return FMRES_SUPERCEDE;
    }
    
    return FMRES_IGNORED;
}
public CmdScrim( id, level, cid ) {
	if( !cmd_access( id, level, cid, 3 ) )
		return PLUGIN_HANDLED;
	
	read_argv( 1, g_szNames[ 0 ], 31 );
	read_argv( 2, g_szNames[ 1 ], 31 );
	
	g_bScrim       = true;

	g_iScores[ 0 ] = g_iScores[ 1 ] = 0;
	
	server_cmd( "mp_forcecamera 2" );
	server_cmd( "mp_forcechasecam 2" );
	server_cmd( "sv_restart 1" );
	
	return PLUGIN_HANDLED;
}
public EventWin_TS( ) {
	if( g_bStart ) {
		for( new id = 1; id <= g_iMaxPlayers; id++ ) {
			if( g_bAlive[ id ] && g_iTeam[ id ] == CS_TEAM_T ) {
				if( !g_bScrim )
					//GreenPrint( id, "You received^4 1^1 frag for surviving the round!" );
				
				set_user_frags( id, get_user_frags( id ) + 1 );
			}
		}
		g_iNubSlash++;
	}
}

public EventWin_CT( ) {
	if( g_bStart ) {
	
			set_task( 0.1, "Task_TeamSwap" );
			
			set_hudmessage( 255, 0, 0, -1.0, 0.13, 0, 0.0, 2.0, 0.2, 0.2, 1 );
			show_hudmessage( 0, "¡Cambio de lado!" );
			
			g_iNubSlash = 0;
		}
	}


public EventNewRound( ) {
	g_bNewGrens = false;
	
	if( CheckPlayers( 0 ) )
		g_bStart = true;
}

public EventRestart( ) {
	g_iNubSlash = 0;
	g_iTimer = 0;
}

public EventRoundStart( ) {
	set_task( 3.0, "BreakStuff" );
	
	if( g_bStart ) {
		if( g_iNubSlash == 3 )
			chatcolor( 0, "!g[HNS] !ySe desbloqueo !tClick primario!y para equipo !tCT!y tras racha de derrotas." );
		
		g_iTimer = 10;
		set_pev( g_iTimerEntity, pev_nextthink, get_gametime( ) );
		
		g_flRoundStartTime = get_gametime( );
		if( !g_iSendAudioMessage )
			g_iSendAudioMessage = register_message( g_iMsgSendAudio, "MsgSendAudio" );
	}
	
	return PLUGIN_CONTINUE;
}

public EventDeathMsg( ) {
	new iVictim = read_data( 2 );
	
	if( g_iTimer && g_iTeam[ iVictim ] == CS_TEAM_CT ) {
		MakeScreenFade( iVictim );
		set_pev( iVictim, pev_flags, pev( iVictim, pev_flags ) & ~FL_FROZEN );
	}
	
	return PLUGIN_CONTINUE;
}

public EventTeamInfo( ) {
	new szTeamInfo[ 2 ], id = read_data( 1 );
	read_data( 2, szTeamInfo, 1 );
	
	switch( szTeamInfo[ 0 ] ) {
		case 'T': g_iTeam[ id ] = CS_TEAM_T;
			case 'C': g_iTeam[ id ] = CS_TEAM_CT;
			case 'S': g_iTeam[ id ] = CS_TEAM_SPECTATOR;
			default : g_iTeam[ id ] = CS_TEAM_UNASSIGNED;
	}
}

public EventMoney( id ) {
	set_pdata_int( id, m_iHideHUD, HUD_MONEY );
	set_pdata_int( id, 115, 0 );
}

public EventResetHUD( id )
	set_pdata_int( id, m_iHideHUD, HUD_MONEY );

public EventHideWeapon( id )
	set_pdata_int( id, m_iHideHUD, read_data( 1 ) | HUD_MONEY );

public MsgTextMsg( msgid, dest, id ) {
	static const TerroristMsg[ ] = "#Terrorists_Win";
	static const HostageMsg  [ ] = "#Hostages_Not_Rescued";
	static const CTMsg       [ ] = "#CTs_Win";
	
	new szMsg[ 33 ];
	get_msg_arg_string( 2, szMsg, 32 );
	
	if( equal( szMsg, TerroristMsg ) || equal( szMsg, HostageMsg ) )
		set_msg_arg_string( 2, "" );
	else if( equal( szMsg, CTMsg ) )
		set_msg_arg_string( 2, "" );
}

public MsgStatusIcon( msgid, msgdest, id ) {
	static szMsg[ 8 ];
	get_msg_arg_string( 2, szMsg, 7 );
	
	if( equal( szMsg, "buyzone" ) && get_msg_arg_int( 1 ) ) {
		set_pdata_int( id, 235, get_pdata_int( id, 235 ) & ~( 1 << 0 ) );
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public MsgScreenFade( msgid, msgdest, id ) {
	if( get_msg_arg_int( 4 ) == 255 && get_msg_arg_int( 5 ) == 255 && get_msg_arg_int( 6 ) == 255 )
		if( ( g_iTeam[ id ] == CS_TEAM_CT && g_iTimer ) || g_iTeam[ id ] == CS_TEAM_T )
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public MsgSendAudio( iMsgId, iMsgDest, iMsgEnt ) {
	if( get_gametime( ) > g_flRoundStartTime ) {
		unregister_message( g_iMsgSendAudio, g_iSendAudioMessage );
		g_iSendAudioMessage = 0;
		return PLUGIN_CONTINUE;
	}
	
	if( iMsgEnt ) {
		new szAudioString[ 17 ];
		get_msg_arg_string( 2, szAudioString, 16 );
		
		if( TrieKeyExists( g_tRoundStartSounds, szAudioString ) )
			return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public FwdHamTakeDamage( id, iInflictor, iAttacker )
	if( IsPlayer( iAttacker ) )
	set_pdata_float( id, m_fPainShock, 1.0 );

public FwdHamKnifeSecondaryAttack( iKnife ) {
	if( !g_bStart )
		return HAM_IGNORED;
	
	if( g_iTeam[ get_pdata_cbase( iKnife, m_pPlayer, 4 ) ] == CS_TEAM_T )
		return HAM_SUPERCEDE;
	
	return HAM_IGNORED;
}

public FwdHamKnifePrimaryAttack( iKnife ) {
	if( !g_bStart )
		return HAM_IGNORED;
	
	if( g_iTeam[ get_pdata_cbase( iKnife, m_pPlayer, 4 ) ] == CS_TEAM_T )
		return HAM_SUPERCEDE;
	
	if( g_iNubSlash >= 3 )
		return HAM_IGNORED;
	
	ExecuteHam( Ham_Weapon_SecondaryAttack, iKnife );
	
	return HAM_SUPERCEDE;
}

public FwdAddToFullPack( es, e, ent, host, hostflags, player, pSet )
	if( player )
	if( g_iTeam[ host ] == g_iTeam[ ent ] )
	if( g_bSolid[ host ] && g_bSolid[ ent ] )
	set_es( es, ES_Solid, SOLID_NOT );

public FwdPlayerPreThink( id ) {
	if( g_bAlive[ id ] ) {
		static Float:flGametime; flGametime = get_gametime( );
		
		if( g_flLastAimDetail[ id ] < flGametime ) {
			static iTgt, iBody;
			get_user_aiming( id, iTgt, iBody, 3500 );
			
			if( is_user_alive( iTgt ) ) {
				static szMessage[ 256 ];
				
				if( g_iTeam[ iTgt ] == g_iTeam[ id ] )
					formatex( szMessage, 255, "amigo: %%p2 - %s - vida: %i%s", g_szCountry[ iTgt ], get_user_health( iTgt ), "%%" );
				else
					formatex( szMessage, 255, "enemigo: %%p2 - %s", g_szCountry[ iTgt ] );
				
				message_begin( MSG_ONE_UNRELIABLE, g_iMsgStatusValue, _, id );
				write_byte( 2 );
				write_short( iTgt );
				message_end( );
				
				message_begin( MSG_ONE_UNRELIABLE, g_iMsgStatusText, _, id );
				write_byte( 0 );
				write_string( szMessage );
				message_end( );
				
				g_bSawPlayer[ id ] = true;
				} else {
				if( g_bSawPlayer[ id ] ) {
					g_bSawPlayer[ id ] = false;
					
					message_begin( MSG_ONE_UNRELIABLE, g_iMsgStatusText, _, id );
					write_byte( 0 );
					write_string( " " );
					message_end( );
				}
			}
			
			g_flLastAimDetail[ id ] = flGametime + 0.2;
		}
	}
	
	static i, iLastThink;
	
	if( iLastThink > id ) {
		for( i = 1; i <= g_iMaxPlayers; i++ ) {
			if( !g_bAlive[ i ] ) {
				g_bSolid[ i ] = false;
				
				continue;
			}
			
			g_bSolid[ i ] = pev( i, pev_solid ) == SOLID_SLIDEBOX ? true : false;
		}
	}
	
	iLastThink = id;
	
	if( !g_bSolid[ id ] )
		return;
	
	for( i = 1; i <= g_iMaxPlayers; i++ ) {
		if( !g_bSolid[ i ] || id == i )
			continue;
		
		if( g_iTeam[ id ] == g_iTeam[ i ] ) {
			set_pev( i, pev_solid, SOLID_NOT );
			g_bRestore[ i ] = true;
		}
	}
}

public FwdPlayerPostThink( id ) {
	static i, Float:flGravity;
	
	for( i = 1; i <= g_iMaxPlayers; i++ ) {
		if( g_bRestore[ i ] ) {
			pev( i, pev_gravity, flGravity );
			set_pev( i, pev_solid, SOLID_SLIDEBOX );
			g_bRestore[ i ] = false;
			
			if( flGravity != 1.0 )
				set_pev( i, pev_gravity, flGravity );
		}
	}
}

public FwdClientKill( id ) {
	if( !g_bStart )
		return FMRES_IGNORED;
	
	return FMRES_SUPERCEDE;
}

public FwdGameDesc( ) {
	forward_return( FMV_STRING, g_szGamename );
	
	return FMRES_SUPERCEDE;
}

public FwdEmitSound( id, iChannel, const szSound[ ] ) {
	if( IsPlayer( id ) ) {
		if( g_iTeam[ id ] != CS_TEAM_T )
			return FMRES_IGNORED;
		
		static const KnifeDeploy[ ] = "weapons/knife_deploy1.wav";
		static const GunPickup[ ]   = "items/gunpickup2.wav";
		
		if( g_bNewGrens && equal( szSound, GunPickup ) )
			return FMRES_SUPERCEDE;
		else if( equal( szSound, KnifeDeploy ) )
			return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

public FwdHamSpawn_Player( id ) {
	g_bAlive[ id ] = bool:is_user_alive( id );
	
	if( g_bAlive[ id ] ) {
		g_iTeam[ id ] = cs_get_user_team( id );
		
		if( g_iSpawnCount[ id ] < 2 ) {
			g_iSpawnCount[ id ]++;
		}
		
		set_task( 0.1, "Task_GiveWeapons", id );
	}
}

public FwdHamKilled_Player( id, iAttacker, iShouldGib ) {
	g_bAlive[ id ]   = bool:is_user_alive( id );
	g_iTeam[ id ]    = cs_get_user_team( id );
	g_bRestore[ id ] = false;
	
	set_pev( id, pev_solid, SOLID_NOT );
	
	
}


public FwdHamSpawn_Grenade( iEntity )
	set_task( 0.01, "SetTrail", iEntity );

public SetTrail( iEntity ) {
	if( !pev_valid( iEntity ) )
		return PLUGIN_CONTINUE;
	
	new szModel[ 32 ], iColor[ 3 ];
	pev( iEntity, pev_model, szModel, charsmax( szModel ) );
	
	switch( szModel[ 9 ] ) {
		case 'h': iColor[ 0 ] = 255;
			case 'f': iColor[ 2 ] = 255;
			case 's': iColor[ 1 ] = 255;
		}
	
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
	write_byte( TE_BEAMFOLLOW );
	write_short( iEntity );
	write_short( g_iSprSmoke );
	write_byte( 10 );
	write_byte( 10 );
	write_byte( iColor[ 0 ] );
	write_byte( iColor[ 1 ] );
	write_byte( iColor[ 2 ] );
	write_byte( 100 );
	message_end( );
	
	return PLUGIN_CONTINUE;
}

public FwdHamSpawn_Weaponbox( iEntity ) {
	set_pev( iEntity, pev_flags, FL_KILLME );
	dllfunc( DLLFunc_Think, iEntity );
	
	return HAM_IGNORED;
}

public Task_TeamSwap( ) {
	new iPlayers[ 32 ], iNum, id;
	get_players( iPlayers, iNum );
	
	for( new i = 0; i < iNum; i++ ) {
		id = iPlayers[ i ];
		
		g_iTeam[ id ] = cs_get_user_team( id );
		
		switch( g_iTeam[ id ] ) {
			case CS_TEAM_T: cs_set_user_team( id, CS_TEAM_CT ); 
				case CS_TEAM_CT: cs_set_user_team( id, CS_TEAM_T ); 
			}
	}
}	

public Task_GiveWeapons( id ) {
	if( !g_bAlive[ id ] )
		return;
	
	strip_user_weapons( id );
	give_item( id, "weapon_knife" );
	
	g_iTeam[ id ] = cs_get_user_team( id );
	
	switch( g_iTeam[ id ] ) {
		case CS_TEAM_T: {
			set_user_footsteps( id, 1 );
			cs_set_user_armor( id, 100, CS_ARMOR_KEVLAR );
			
		}
		case CS_TEAM_CT: {
			if( g_bStart && g_iTimer > 0 ) {
				engfunc( EngFunc_SetClientMaxspeed, id, 0.0000001 );
				set_pev( id, pev_maxspeed, 0.0000001 );
			}
		}
	}
}

public client_putinserver( id ) {
	g_iSpawnCount[ id ] = 0;
	g_bSawPlayer[ id ] = false;
	

}

public client_disconnected( id )
	g_bAlive[ id ] = false;

public CmdJoinTeam( id ) {
	if( 0 < get_user_team( id ) < 3 )
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public FwdThinkTimer( ent ) {
	if( !CheckPlayers( 1 ) ) 
		g_iTimer = 0;
	
	if( g_iTimer ) {
		for( new id = 1; id <= g_iMaxPlayers; id++ ) {
			if( g_bAlive[ id ] && g_iTeam[ id ] == CS_TEAM_CT ) {
				engfunc( EngFunc_SetClientMaxspeed, id, 0.0000001 );
				set_pev( id, pev_maxspeed, 0.0000001 );
				
				MakeScreenFade( id, 1 ); 
			}
		}
		set_hudmessage( 0, 0,255, -1.0, 0.34, 0, 0.0, 1.1, 0.0, 0.0, 1 );
		show_hudmessage( 0, "%i segundos para esconderse...", g_iTimer );
		
		new szSeconds[ 10 ];
		num_to_word( g_iTimer, szSeconds, 9 );
		
		client_cmd( 0, "spk ^"evg_sound/%s^"", szSeconds );
		
		set_pev( ent, pev_nextthink, get_gametime( ) + 1.0 );
		
		g_iTimer--;
		} else {
		for( new id = 1; id <= g_iMaxPlayers; id++ ) {
			if( !g_bAlive[id] )
				continue;
			
			switch( g_iTeam[ id ] ) {
				case CS_TEAM_CT: {
					engfunc( EngFunc_SetClientMaxspeed, id, 250.0 );
					set_pev( id, pev_maxspeed, 250.0 );
					
					MakeScreenFade( id );
				}
			}
		}
		
		set_hudmessage( 0, 0, 255, -1.0, 0.34, 0, 0.0, 2.0, 0.0, 0.4, 1 );
		show_hudmessage( 0, "Listo o no, aqui vamos!" );
	}
}

MakeScreenFade( id, fade = 0 ) {
	message_begin( MSG_ONE, g_iMsgScreenFade, _, id );
	write_short( 8192 * fade );
	write_short( 8192 * fade );
	write_short( 0x0000 );
	write_byte( 0 );
	write_byte( 0 );
	write_byte( 0 );
	write_byte( g_bScrim ? 255 : 200 );
	message_end();
}

bool:CheckPlayers( iStatus ) {
	new iPlayers[ 32 ], iNum, id, iTerrs, iCTs;
	if( iStatus )
		get_players( iPlayers, iNum, "a" );
	else
		get_players( iPlayers, iNum );
	
	for( new i = 0; i < iNum; i++ ) {
		id = iPlayers[ i ];
		
		g_iTeam[ id ] = cs_get_user_team( id );
		
		switch( g_iTeam[ id ] ) {
			case CS_TEAM_T: iTerrs++;
				case CS_TEAM_CT: iCTs++;
			}
		
		if( iTerrs && iCTs )
			return true;
	}
	
	return false;
}

public BreakStuff( ) {
	new iEntity;
	while( ( iEntity = find_ent_by_class( iEntity, "func_breakable" ) ) > 0 )
		if( pev( iEntity, pev_spawnflags ) != SF_BREAK_TRIGGER_ONLY )
		ExecuteHamB( Ham_TakeDamage, iEntity, 0, 0, 9999.0, DMG_GENERIC );
}

stock chatcolor(id, const input[], any:...)
{
    static szMsg[191], msgSayText;
    
    if (!msgSayText)
        msgSayText = get_user_msgid("SayText");
    
    vformat(szMsg, 190, input, 3);

    replace_all(szMsg, 190, "!g", "^4");
    replace_all(szMsg, 190, "!y", "^1");
    replace_all(szMsg, 190, "!t", "^3");
    
    message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgSayText, .player = id);
    write_byte(id ? id : 33);
    write_string(szMsg);
    message_end();
} 

