#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
#endif

#pragma semicolon               1

#define PLUGIN_NAME             "[ZMB] Core"
#define PLUGIN_VERS             "0.0.7"
#define PLUGIN_AUTH             "81x08"

#define SetBit(%0,%1)           ((%0) |= (1 << (%1 - 1)))
#define ClearBit(%0,%1)         ((%0) &= ~(1 << (%1 - 1)))
#define IsSetBit(%0,%1)         ((%0) & (1 << (%1 - 1)))
#define InvertBit(%0,%1)        ((%0) ^= (1 << (%1 - 1)))
#define IsNotSetBit(%0,%1)      (~(%0) & (1 << (%1 - 1)))

#define IsPlayer(%0)            (%0 && %0 <= g_iMaxPlayers)

#define MAX_PLAYERS             32
#define MAX_CLASSES             10

#define MAX_GRENADES            4
#define MAX_PRIMARY_WEAPONS     3
#define MAX_SECONDARY_WEAPONS   3

#define CLASS_NONE              0

#define HIDEHUD_FLASHLIGHT      (1 << 1)
#define HIDEHUD_HEALTH          (1 << 3)

const MsgId_TextMsg             = 77;
const MsgId_ReceiveW            = 129;
const MsgId_SendAudio           = 100;
const MsgId_ScreenFade          = 98;
const MsgId_HideWeapon          = 94;

enum (+= 35)	{
	TASK_ID_INFECT,

	TASK_ID_PLAYER_HUD
};

enum Color	{
	COLOR_RED,
	COLOR_GREEN,
	COLOR_BLUE
};

enum Positon	{
	Float: POS_X,
	Float: POS_Y
};

enum infoClass	{
	CLASS_NAME[64],
	CLASS_KNIFE_MODEL[64],
	CLASS_PLAYER_MODEL[64],
	
	Float: CLASS_SPEED,
	Float: CLASS_HEALTH,
	Float: CLASS_GRAVITY,
	Float: CLASS_KNOCKBACK,
	Float: CLASS_FACTOR_DMG
};

enum playerEquipment	{
	PLAYER_EQUIPMENT_PRIMARY,
	PLAYER_EQUIPMENT_SECONDARY
};

enum listWeaponInfo	{
	WEAPON_NAME[12],
	WEAPON_CLASSNAME[20],
	WeaponIdType: WEAPON_ID,
	WEAPON_BPAMMO,
	Float: WEAPON_KNOCKBACK
};

enum _: bitsPlayer	{
	BIT_NONE,
	
	BIT_ALIVE,
	BIT_HUMAN,
	BIT_INFECT,
	BIT_CONNECTED,
	BIT_NIGHT_VISION,
	BIT_MENU_EQUIPMENT,
	
	BIT_MAX
};

new g_listGrenades[MAX_GRENADES][20];
new g_listPrimaryWeapons[MAX_PRIMARY_WEAPONS + 1][listWeaponInfo];
new g_listSecondaryWeapons[MAX_SECONDARY_WEAPONS + 1][listWeaponInfo];

new g_iFakeMetaFwd_Spawn;

new HamHook: g_iHamFwd_Entity_Block[13];

new g_iMaxPlayers,
	g_iZombieClasses,
	g_iSyncPlayerHud;

new g_iWeather,
	g_iActiveWeather;

new g_iAliveHumans,
	g_iAliveZombies;

new g_iGrenades,
	g_iPrimaryWeapons,
	g_iSecondaryWeapons;

new g_iNvgAlpha,
	g_iNvgColor[Color];

new g_iNumberSoundsSurvirvorWin,
	g_iNumberSoundsZombieDie,
	g_iNumberSoundsZombieWin,
	g_iNumberSoundsZombieScream,
	g_iNumberSoundsZombieKnifeMiss,
	g_iNumberSoundsZombieKnifeHits;

new g_infoZombieClass[MAX_CLASSES + 1][infoClass];

new g_iCvar_HudType,
	g_iCvar_SaveEquipment,
	g_iCvar_HudColor[Color],
	g_iCvar_BlockZombieFlashlight,
	g_iCvar_StateKnockbackSitZombie;
	
new Float: g_fCvar_ZombieRatio,
	Float: g_fCvar_TimeInfections,
	Float: g_fCvar_HudPosition[Positon],
	Float: g_fCvar_MaxDistanceKnockback;

new bool: g_bFog,
	bool: g_bRoundEnd,
	bool: g_bZombieUseNvg,
	bool: g_bZombieStateNvg,
	bool: g_bInfectionBegan;

new g_szFogColor[12],
	g_szFogDensity[8];

new g_szCvar_MapLightStyle[2],
	g_szCvar_GameDescription[64];

new gp_iBit[bitsPlayer],
	gp_iClass[MAX_PLAYERS + 1],
	gp_iMenuPosition[MAX_PLAYERS + 1],
	gp_iSelectedClass[MAX_PLAYERS + 1],
	gp_iEquipment[MAX_PLAYERS + 1][playerEquipment];

new gp_szSteamId[MAX_PLAYERS + 1][35];

new	Trie: g_tEquipment,
	Trie: g_tRemoveEntities,
	Trie: g_tPrimaryWeapons,
	Trie: g_tSecondaryWeapons;

new Array: g_aSoundsSurvirvorWin,
	Array: g_aSoundsZombieDie,
	Array: g_aSoundsZombieWin,
	Array: g_aSoundsZombieScream,
	Array: g_aSoundsZombieKnifeMiss,
	Array: g_aSoundsZombieKnifeHits;

/*================================================================================
 [PLUGIN]
=================================================================================*/
public plugin_precache()	{
	LoadMain();
	LoadSounds();
	LoadClasses();

	FakeMeta_RemoveEntities();
}

public plugin_init()	{
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	Event_Init();
	Message_Init();
	
	ReAPI_Init();
	Engine_Init();
	FakeMeta_Init();
	Hamsandwich_Init();

	ClCmd_Init();
	MenuCmd_Init();

	g_iMaxPlayers = get_maxplayers();
	
	g_iSyncPlayerHud = CreateHudSyncObj();

	new iCount;
	
	g_tPrimaryWeapons = TrieCreate();
	
	for(iCount = 1; iCount <= g_iPrimaryWeapons; iCount++)
	{
		TrieSetCell(g_tPrimaryWeapons, g_listPrimaryWeapons[iCount][WEAPON_CLASSNAME], iCount);
	}
	
	g_tSecondaryWeapons = TrieCreate();
	
	for(iCount = 1; iCount <= g_iSecondaryWeapons; iCount++)
	{
		TrieSetCell(g_tSecondaryWeapons, g_listSecondaryWeapons[iCount][WEAPON_CLASSNAME], iCount);
	}
}

public plugin_cfg()	{
	Cvars_Cfg();
}

/*================================================================================
 [PRECACHE]
=================================================================================*/
LoadMain()	{
	new szFileDir[128];
	get_localinfo("amxx_configsdir", szFileDir, charsmax(szFileDir));
	
	formatex(szFileDir, charsmax(szFileDir), "%s/zmb/zmb_main.ini", szFileDir);

	switch(file_exists(szFileDir))
	{
		case 0:
		{
			UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" не найден.", szFileDir);
		}
		case 1:
		{
			ReadFile_Main(szFileDir);
		}
	}
}

ReadFile_Main(const szFileDir[])	{
	new iFile = fopen(szFileDir, "rt");
	
	if(iFile)
	{
		new iStrLen;
		new szBuffer[128], szBlock[32], szKey[32], szValue[64];
		new szWeaponName[16], szClassName[16], szBpammo[6], szKnockback[6];

		while(!(feof(iFile)))
		{
			fgets(iFile, szBuffer, charsmax(szBuffer));
			trim(szBuffer);

			if(!(szBuffer[0]) || szBuffer[0] == ';' || szBuffer[0] == '#')
			{
				continue;
			}
			
			iStrLen = strlen(szBuffer);
			
			if(szBuffer[0] == '[' && szBuffer[iStrLen - 1] == ']')
			{
				copyc(szBlock, charsmax(szBlock), szBuffer[1], szBuffer[iStrLen - 1]);

				continue;
			}
			
			if(szBlock[0])
			{
				if(szBlock[0] == 'e' && szBlock[1] == 'n' && szBlock[2] == 'd')
				{
					continue;
				}

				switch(szBlock[0])
				{
					case 'w':
					{
						if(equali(szBlock, "weather", 7))
						{
							strtok(szBuffer, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');
							
							trim(szKey);
							trim(szValue);
							
							remove_quotes(szKey);
							remove_quotes(szValue);
						
							switch(szKey[0])
							{
								case 'w':
								{
									if(equali(szKey, "weather", 7))
									{
										g_iWeather = read_flags(szValue);

										setWeather(g_iWeather);
									}
								}
								case 'f':
								{
									if(equali(szKey, "fog"))
									{
										g_bFog = bool: str_to_num(szValue);
										
										continue;
									}
									
									if(g_bFog)
									{
										if(equali(szKey, "fog_color", 9))
										{
											formatex(g_szFogColor, charsmax(g_szFogColor), szValue);
										
											continue;
										}
										
										if(equali(szKey, "fog_density", 11))
										{
											formatex(g_szFogDensity, charsmax(g_szFogDensity), szValue);
										}
									}
								}
							}
						}
					}
					case 'n':
					{
						if(equali(szBlock, "nightvision", 11))
						{
							strtok(szBuffer, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');
							
							trim(szKey);
							trim(szValue);
							
							remove_quotes(szKey);
							remove_quotes(szValue);
							
							switch(szKey[0])
							{
								case 'z':
								{
									if(equali(szKey, "zombie_use_nvg", 14))
									{
										g_bZombieUseNvg = bool: str_to_num(szValue);
										
										continue;
									}
									
									if(g_bZombieUseNvg)
									{
										if(equali(szKey, "zombie_state_nvg", 16))
										{
											g_bZombieStateNvg = bool: str_to_num(szValue);
										}
									}
								}
								case 'n':
								{
									if(g_bZombieUseNvg)
									{
										if(equali(szKey, "nvg_alpha", 9))
										{
											g_iNvgAlpha = str_to_num(szValue);
											
											continue;
										}

										if(equali(szKey, "nvg_color", 9))
										{
											new szColor[Color][4];
											
											parse(
												szValue,
												szColor[COLOR_RED], charsmax(szColor[]),
												szColor[COLOR_GREEN], charsmax(szColor[]),
												szColor[COLOR_BLUE], charsmax(szColor[])
											);
											
											g_iNvgColor[COLOR_RED] = str_to_num(szColor[COLOR_RED]);
											g_iNvgColor[COLOR_GREEN] = str_to_num(szColor[COLOR_GREEN]);
											g_iNvgColor[COLOR_BLUE] = str_to_num(szColor[COLOR_BLUE]);
										}
									}
								}
							}
						}
					}
					case 'p':
					{
						if(equali(szBlock, "primary", 7))
						{
							g_iPrimaryWeapons++;
							
							parse(
								szBuffer,
								szWeaponName, charsmax(szWeaponName),
								szClassName, charsmax(szClassName),
								szBpammo, charsmax(szBpammo),
								szKnockback, charsmax(szKnockback)
							);
							
							formatex(
								g_listPrimaryWeapons[g_iPrimaryWeapons][WEAPON_NAME],
								charsmax(g_listPrimaryWeapons[][WEAPON_NAME]),
								szWeaponName
							);
							
							formatex(
								g_listPrimaryWeapons[g_iPrimaryWeapons][WEAPON_CLASSNAME],
								charsmax(g_listPrimaryWeapons[][WEAPON_CLASSNAME]),
								szClassName
							);

							g_listPrimaryWeapons[g_iPrimaryWeapons][WEAPON_ID] = rg_get_weapon_info(g_listPrimaryWeapons[g_iPrimaryWeapons][WEAPON_CLASSNAME], WI_ID);
							g_listPrimaryWeapons[g_iPrimaryWeapons][WEAPON_BPAMMO] = str_to_num(szBpammo);
							g_listPrimaryWeapons[g_iPrimaryWeapons][WEAPON_KNOCKBACK] = _: str_to_float(szKnockback);
						}
					}
					case 's':
					{
						if(equali(szBlock, "secondary", 9))
						{
							g_iSecondaryWeapons++;
							
							parse(
								szBuffer,
								szWeaponName, charsmax(szWeaponName),
								szClassName, charsmax(szClassName),
								szBpammo, charsmax(szBpammo),
								szKnockback, charsmax(szKnockback)
							);

							formatex(
								g_listSecondaryWeapons[g_iSecondaryWeapons][WEAPON_NAME],
								charsmax(g_listSecondaryWeapons[][WEAPON_NAME]),
								szWeaponName
							);
							
							formatex(
								g_listSecondaryWeapons[g_iSecondaryWeapons][WEAPON_CLASSNAME],
								charsmax(g_listSecondaryWeapons[][WEAPON_CLASSNAME]),
								szClassName
							);

							g_listSecondaryWeapons[g_iSecondaryWeapons][WEAPON_ID] = rg_get_weapon_info(g_listSecondaryWeapons[g_iSecondaryWeapons][WEAPON_CLASSNAME], WI_ID);
							g_listSecondaryWeapons[g_iSecondaryWeapons][WEAPON_BPAMMO] = str_to_num(szBpammo);
							g_listSecondaryWeapons[g_iSecondaryWeapons][WEAPON_KNOCKBACK] = _: str_to_float(szKnockback);
						}
					}
					case 'g':
					{
						if(equali(szBlock, "grenades", 8))
						{
							remove_quotes(szBuffer);

							formatex(
								g_listGrenades[g_iGrenades],
								charsmax(g_listGrenades[]),
								szBuffer
							);

							g_iGrenades++;
						}
					}
				}
			}
		}
		
		fclose(iFile);
		
		if(g_bFog)
		{
			FakeMeta_EnvFog();
		}
	}
}

LoadSounds()	{
	new szFileDir[128];
	get_localinfo("amxx_configsdir", szFileDir, charsmax(szFileDir));
	
	formatex(szFileDir, charsmax(szFileDir), "%s/zmb/zmb_sounds.ini", szFileDir);

	switch(file_exists(szFileDir))
	{
		case 0:
		{
			UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" не найден.", szFileDir);
		}
		case 1:
		{
			ReadFile_Sounds(szFileDir);
		}
	}
}

ReadFile_Sounds(const szFileDir[])	{
	new iFile = fopen(szFileDir, "rt");
	
	if(iFile)
	{
		new iStrLen;
		new szBuffer[128], szBlock[32], szPrecache[64];

		while(!(feof(iFile)))
		{
			fgets(iFile, szBuffer, charsmax(szBuffer));
			trim(szBuffer);

			if(!(szBuffer[0]) || szBuffer[0] == ';' || szBuffer[0] == '#')
			{
				continue;
			}
			
			iStrLen = strlen(szBuffer);
			
			if(szBuffer[0] == '[' && szBuffer[iStrLen - 1] == ']')
			{
				copyc(szBlock, charsmax(szBlock), szBuffer[1], szBuffer[iStrLen - 1]);

				continue;
			}
			
			if(szBlock[0])
			{
				if(szBlock[0] == 'e' && szBlock[1] == 'n' && szBlock[2] == 'd')
				{
					continue;
				}
				
				remove_quotes(szBuffer);

				formatex(szPrecache, charsmax(szPrecache), "sound/%s", szBuffer);
				
				switch(file_exists(szPrecache))
				{
					case 0:
					{
						UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" не найден.", szPrecache);
					}
					case 1:
					{
						switch(szBlock[0])
						{
							case 's':
							{
								if(equali(szBlock, "survirvor_win", 13))
								{
									if(g_aSoundsSurvirvorWin || (g_aSoundsSurvirvorWin = ArrayCreate(64)))
									{
										precache_sound(szBuffer);
										
										ArrayPushString(g_aSoundsSurvirvorWin, szBuffer);
									}
								}
							}
							case 'z':
							{
								if(equali(szBlock, "zombie_win", 10))
								{
									if(g_aSoundsZombieWin || (g_aSoundsZombieWin = ArrayCreate(64)))
									{
										precache_sound(szBuffer);
										
										ArrayPushString(g_aSoundsZombieWin, szBuffer);
									}
									
									continue;
								}

								if(equali(szBlock, "zombie_death", 12))
								{
									if(g_aSoundsZombieDie || (g_aSoundsZombieDie = ArrayCreate(64)))
									{
										precache_sound(szBuffer);

										ArrayPushString(g_aSoundsZombieDie, szBuffer);
									}
									
									continue;
								}

								if(equali(szBlock, "zombie_scream", 13))
								{
									if(g_aSoundsZombieScream || (g_aSoundsZombieScream = ArrayCreate(64)))
									{
										precache_sound(szBuffer);

										ArrayPushString(g_aSoundsZombieScream, szBuffer);
									}
									
									continue;
								}

								if(equali(szBlock, "zombie_knife_miss", 17))
								{
									if(g_aSoundsZombieKnifeMiss || (g_aSoundsZombieKnifeMiss = ArrayCreate(64)))
									{
										precache_sound(szBuffer);

										ArrayPushString(g_aSoundsZombieKnifeMiss, szBuffer);
									}
									
									continue;
								}

								if(equali(szBlock, "zombie_knife_hits", 17))
								{
									if(g_aSoundsZombieKnifeHits || (g_aSoundsZombieKnifeHits = ArrayCreate(64)))
									{
										precache_sound(szBuffer);

										ArrayPushString(g_aSoundsZombieKnifeHits, szBuffer);
									}
								}
							}
						}
					}
				}
			}
		}
		
		fclose(iFile);
		
		if(g_aSoundsSurvirvorWin)
		{
			g_iNumberSoundsSurvirvorWin = ArraySize(g_aSoundsSurvirvorWin);
		}
		
		if(g_aSoundsZombieWin)
		{
			g_iNumberSoundsZombieWin = ArraySize(g_aSoundsZombieWin);
		}

		if(g_aSoundsZombieDie)
		{
			g_iNumberSoundsZombieDie = ArraySize(g_aSoundsZombieDie);
		}
		
		if(g_aSoundsZombieScream)
		{
			g_iNumberSoundsZombieScream = ArraySize(g_aSoundsZombieScream);
		}
		
		if(g_aSoundsZombieKnifeMiss)
		{
			g_iNumberSoundsZombieKnifeMiss = ArraySize(g_aSoundsZombieKnifeMiss);
		}
		
		if(g_aSoundsZombieKnifeHits)
		{
			g_iNumberSoundsZombieKnifeHits = ArraySize(g_aSoundsZombieKnifeHits);
		}
	}
}

LoadClasses()	{
	new szFileDir[128];
	get_localinfo("amxx_configsdir", szFileDir, charsmax(szFileDir));
	
	formatex(szFileDir, charsmax(szFileDir), "%s/zmb/zmb_classes.ini", szFileDir);

	switch(file_exists(szFileDir))
	{
		case 0:
		{
			writeDefaultClassFile(szFileDir);
			
			UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" был не найден и был создан.", szFileDir);
		}
		case 1:
		{
			ReadFile_Classes(szFileDir);
		}
	}
}

ReadFile_Classes(const szFileDir[])	{
	new iFile = fopen(szFileDir, "rt");
	
	if(iFile)
	{
		new iStrLen;
		new szBuffer[128], szKey[32], szValue[64], szName[64];
		
		new infoZombieClass[infoClass];
		
		while(!(feof(iFile)))
		{
			fgets(iFile, szBuffer, charsmax(szBuffer));
			trim(szBuffer);

			if(!(szBuffer[0]) || szBuffer[0] == ';' || szBuffer[0] == '#')
			{
				continue;
			}
			
			iStrLen = strlen(szBuffer);

			if(szBuffer[0] == '[' && szBuffer[iStrLen - 1] == ']')
			{
				copyc(szName, charsmax(szName), szBuffer[1], szBuffer[iStrLen - 1]);

				if(equali(szName, "end", 3) || equali(szName, "конец", 5))
				{
					if(infoZombieClass[CLASS_NAME][0])
					{
						addZombieClass(
							infoZombieClass[CLASS_NAME],
							infoZombieClass[CLASS_KNIFE_MODEL],
							infoZombieClass[CLASS_PLAYER_MODEL],
							infoZombieClass[CLASS_SPEED],
							infoZombieClass[CLASS_HEALTH],
							infoZombieClass[CLASS_GRAVITY],
							infoZombieClass[CLASS_KNOCKBACK],
							infoZombieClass[CLASS_FACTOR_DMG]
						);
					}
					
					arrayset(infoZombieClass, 0, sizeof(infoZombieClass));
				}
				else
				{
					trim(szName);
					
					infoZombieClass[CLASS_NAME] = szName;
				}
				
				continue;
			}

			if(infoZombieClass[CLASS_NAME][0])
			{
				strtok(szBuffer, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');

				trim(szKey);
				trim(szValue);
				
				remove_quotes(szKey);
				remove_quotes(szValue);
				
				switch(szKey[0])
				{
					case 'k':
					{
						if(equali(szKey, "knife_model", 11))
						{
							switch(file_exists(szValue))
							{
								case 0:
								{
									UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" не найден.", szValue);
								}
								case 1:
								{
									precache_model(szValue);
									
									infoZombieClass[CLASS_KNIFE_MODEL] = szValue;
								}
							}
							
							continue;
						}
						
						if(equali(szKey, "knockback", 9))
						{
							infoZombieClass[CLASS_KNOCKBACK] = _: str_to_float(szValue);
						}
					}
					case 'p':
					{
						if(equali(szKey, "player_model", 12))
						{
							new szPrecache[64];
							formatex(szPrecache, charsmax(szPrecache), "models/player/%s/%s.mdl", szValue, szValue);
							
							switch(file_exists(szPrecache))
							{
								case 0:
								{
									UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" не найден.", szPrecache);
								}
								case 1:
								{
									precache_model(szPrecache);
									
									infoZombieClass[CLASS_PLAYER_MODEL] = szValue;
								}
							}
						}
					}
					case 's':
					{
						if(equali(szKey, "speed", 5))
						{
							infoZombieClass[CLASS_SPEED] = _: str_to_float(szValue);
						}
					}
					case 'h':
					{
						if(equali(szKey, "health", 6))
						{
							infoZombieClass[CLASS_HEALTH] = _: str_to_float(szValue);
						}
					}
					case 'g':
					{
						if(equali(szKey, "gravity", 7))
						{
							infoZombieClass[CLASS_GRAVITY] = _: str_to_float(szValue);
						}
					}
					case 'f':
					{
						if(equali(szKey, "factor_damage", 13))
						{
							infoZombieClass[CLASS_FACTOR_DMG] = _: str_to_float(szValue);
						}
					}
				}
			}
		}

		fclose(iFile);
		
		if(g_iZombieClasses == 0)
		{
			precache_model("models/zmb/classes/v_knife.mdl");
			precache_model("models/player/slum/slum.mdl");

			addZombieClass(
				.szName = "Slum",
				.szKnifeModel = "models/zmb/classes/v_knife.mdl",
				.szPlayerModel = "slum",
				.fSpeed = 225.0,
				.fHealth = 2200.0,
				.fGravity = 0.7,
				.fKnockback = 0.4,
				.fFactorDmg = 1.2
			);
			
			writeDefaultClassFile(szFileDir);
			
			UTIL_SetFileState("Core", "~ [INFO] Файл классов ^"%s^" пуст. Поэтому был создан класс ^"Slum^".", szFileDir);
		}
	}
}

/*================================================================================
 [CVARS]
=================================================================================*/
Cvars_Cfg()	{
	new iCvarId_HudType,
		iCvarId_HudColor,
		iCvarId_HudPosition,
		iCvarId_ZombieRatio,
		iCvarId_MapLightStyle,
		iCvarId_SaveEquipment,
		iCvarId_TimeInfections,
		iCvarId_GameDescription,
		iCvarId_MaxDistanceKnockback,
		iCvarId_BlockZombieFlashlight,
		iCvarId_StateKnockbackSitZombie;

	iCvarId_HudType                 = register_cvar("zmb_hud_type",                     "0");
	iCvarId_HudColor                = register_cvar("zmb_hud_color",                    "#008000");
	iCvarId_HudPosition             = register_cvar("zmb_hud_position",                 "-1.0 0.85");
	iCvarId_ZombieRatio             = register_cvar("zmb_zombie_ratio",                 "0.2");
	iCvarId_MapLightStyle           = register_cvar("zmb_map_lightstyle",               "d");
	iCvarId_SaveEquipment           = register_cvar("zmb_save_equipment",               "0");
	iCvarId_TimeInfections          = register_cvar("zmb_time_infections",              "15");
	iCvarId_GameDescription         = register_cvar("zmb_game_description",             "[ZMB] by 81x08");
	iCvarId_MaxDistanceKnockback    = register_cvar("zmb_min_distance_knockback",       "500");
	iCvarId_BlockZombieFlashlight   = register_cvar("zmb_block_zombie_flashlight",      "1");
	iCvarId_StateKnockbackSitZombie = register_cvar("zmb_state_knockback_sit_zombie",   "1");

 	new szFileDir[128];
	get_localinfo("amxx_configsdir", szFileDir, charsmax(szFileDir));
	
	formatex(szFileDir, charsmax(szFileDir), "%s/zmb/zmb_core.cfg", szFileDir);
	
	switch(file_exists(szFileDir))
	{
		case 0:
		{
			UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" не найден.", szFileDir);
		}
		case 1:
		{
			server_cmd("exec %s", szFileDir);
			
			server_exec();
		}
	}

	new szColor[8];
	get_pcvar_string(iCvarId_HudColor, szColor, charsmax(szColor));

	g_iCvar_HudColor                = UTIL_ParseHEXColor(szColor);
	g_iCvar_HudType                 = get_pcvar_num(iCvarId_HudType);
	g_iCvar_SaveEquipment           = get_pcvar_num(iCvarId_SaveEquipment);
	g_iCvar_BlockZombieFlashlight   = get_pcvar_num(iCvarId_BlockZombieFlashlight);
	g_iCvar_StateKnockbackSitZombie = get_pcvar_num(iCvarId_StateKnockbackSitZombie);
	
	new szPosition[Positon][8], szCvarPosition[16];
	get_pcvar_string(iCvarId_HudPosition, szCvarPosition, charsmax(szCvarPosition));
	parse(szCvarPosition, szPosition[POS_X], charsmax(szPosition[]), szPosition[POS_Y], charsmax(szPosition[]));
	
	g_fCvar_HudPosition[POS_X]      = str_to_float(szPosition[POS_X]);
	g_fCvar_HudPosition[POS_Y]      = str_to_float(szPosition[POS_Y]);
	g_fCvar_ZombieRatio             = get_pcvar_float(iCvarId_ZombieRatio);
	g_fCvar_TimeInfections          = get_pcvar_float(iCvarId_TimeInfections);
	g_fCvar_MaxDistanceKnockback    = get_pcvar_float(iCvarId_MaxDistanceKnockback);

	get_pcvar_string(iCvarId_MapLightStyle, g_szCvar_MapLightStyle, charsmax(g_szCvar_MapLightStyle));
	get_pcvar_string(iCvarId_GameDescription, g_szCvar_GameDescription, charsmax(g_szCvar_GameDescription));

	if(g_iCvar_SaveEquipment)
	{
		g_tEquipment = TrieCreate();
	}
	
	if(g_iCvar_BlockZombieFlashlight)
	{
		register_impulse(100, "EngineHook_Impulse_Flashlight");
	}
	
	if(g_szCvar_GameDescription[0])
	{
		set_member_game(m_GameDesc, g_szCvar_GameDescription);
	}
}

/*================================================================================
 [CLIENT]
=================================================================================*/
public client_putinserver(iIndex)	{
	if(is_user_bot(iIndex) || is_user_hltv(iIndex))
	{
		return PLUGIN_HANDLED;
	}
	
	SetBit(gp_iBit[BIT_CONNECTED], iIndex);
	SetBit(gp_iBit[BIT_MENU_EQUIPMENT], iIndex);
	
	gp_iClass[iIndex] = random_num(1, g_iZombieClasses);
	gp_iSelectedClass[iIndex] = CLASS_NONE;
	
	if(g_iCvar_SaveEquipment)
	{
		get_user_authid(iIndex, gp_szSteamId[iIndex], charsmax(gp_szSteamId[]));
		
		if(TrieKeyExists(g_tEquipment, gp_szSteamId[iIndex]))
		{
			TrieGetArray(g_tEquipment, gp_szSteamId[iIndex], gp_iEquipment[iIndex], sizeof(gp_iEquipment[][]));

			TrieDeleteKey(g_tEquipment, gp_szSteamId[iIndex]);
		}
	}

	return PLUGIN_CONTINUE;
}

public client_disconnect(iIndex)	{
	if(IsNotSetBit(gp_iBit[BIT_CONNECTED], iIndex))
	{
		return PLUGIN_HANDLED;
	}
	
	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		g_iAliveZombies--;
		
		remove_task(TASK_ID_PLAYER_HUD + iIndex);

		if(g_bInfectionBegan)
		{
			if(g_iAliveZombies == 0)
			{
				if(g_iAliveHumans > 1)
				{
					setRandomPlayerZombie();
				}
			}
		}
	}
	else
	{
		if(IsSetBit(gp_iBit[BIT_HUMAN], iIndex))
		{
			g_iAliveHumans--;
		}
	}
	
	for(new iCount = BIT_NONE; iCount < BIT_MAX; iCount++)
	{
		ClearBit(gp_iBit[iCount], iIndex);
	}

	switch(g_iCvar_SaveEquipment)
	{
		case 0:
		{
			gp_iEquipment[iIndex][PLAYER_EQUIPMENT_PRIMARY] = 0;
			gp_iEquipment[iIndex][PLAYER_EQUIPMENT_SECONDARY] = 0;
		}
		case 1:
		{
			TrieSetArray(g_tEquipment, gp_szSteamId[iIndex], gp_iEquipment[iIndex], sizeof(gp_iEquipment[][]));
		}
	}
	
	return PLUGIN_CONTINUE;
}

/*================================================================================
 [EVENT]
=================================================================================*/
Event_Init()	{
	register_event("InitHUD", "EventHook_InitHUD", "b");
	register_event("HLTV", "EventHook_HLTV", "a", "1=0", "2=0");
	
	register_logevent("LogEventHook_RoundEnd",      2,  "1=Round_End");
	register_logevent("LogEventHook_RoundStart",    2,  "1=Round_Start");
	register_logevent("LogEventHook_RestartGame",   2,  "1=Game_Commencing", "1&Restart_Round_");
}

public EventHook_InitHUD(const iIndex)	{
	if(g_szCvar_MapLightStyle[0])
	{
		UTIL_SetPlayerMapLightStyle(iIndex, g_szCvar_MapLightStyle);
	}

 	if(g_iActiveWeather)
	{
		UTIL_SetPlayerWeather(iIndex, g_iActiveWeather);
	}
}

public EventHook_HLTV()	{
	g_bRoundEnd = false;

	for(new iCount = 0; iCount < 13; iCount++)
	{
		DisableHamForward(g_iHamFwd_Entity_Block[iCount]);
	}

	setWeather(g_iWeather);

	for(new iIndex = 1; iIndex <= g_iMaxPlayers; iIndex++)
	{
		if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
		{
			ClearBit(gp_iBit[BIT_INFECT], iIndex);
			
			remove_task(TASK_ID_PLAYER_HUD + iIndex);

			if(IsSetBit(gp_iBit[BIT_NIGHT_VISION], iIndex))
			{
				setPlayerNightVision(iIndex, false);
			}
			
			rg_reset_user_model(iIndex);
			
			new iItem = get_member(iIndex, m_pActiveItem);
			
			if(iItem > 0)
			{
				ExecuteHamB(Ham_Item_Deploy, iItem);
			}
		}
	}

	g_iAliveHumans = 0;
	g_iAliveZombies = 0;
}

public LogEventHook_RoundStart()	{
	if(!(g_bRoundEnd) && !(g_bInfectionBegan))
	{
		set_task(g_fCvar_TimeInfections, "taskInfect", TASK_ID_INFECT);
	}
}

public LogEventHook_RoundEnd()	{
	g_bRoundEnd = true;
	g_bInfectionBegan = false;
	
	remove_task(TASK_ID_INFECT);
}

public LogEventHook_RestartGame()	{
	LogEventHook_RoundEnd();
}

/*================================================================================
 [MESSAGE]
=================================================================================*/
Message_Init()	{
	register_message(MsgId_TextMsg,   "MessageHook_TextMsg");
	register_message(MsgId_SendAudio, "MessageHook_SendAudio");
}

public MessageHook_TextMsg()	{
	new szArg[16];
	get_msg_arg_string(2, szArg, charsmax(szArg));

	switch(szArg[1])
	{
		case 'C':
		{
			if(equal(szArg[1], "CTs_Win", 7))
			{
				set_msg_arg_string(2, "Люди победили заразу!");
			}
		}
		case 'R':
		{
			if(equal(szArg[1], "Round_Draw", 10))
			{
				set_msg_arg_string(2, "На этот раз ничья...");
			}
		}
		case 'T':
		{
			if(equal(szArg[1], "Target_Saved", 12))
			{
				set_msg_arg_string(2, "На этот раз ничья...");
			}
			else if(equal(szArg[1], "Terrorists_Win", 14))
			{
				set_msg_arg_string(2, "Зомби захватили весь мир!");
			}
		}
	}
}

public MessageHook_SendAudio()	{
	new szArg[14], szSoundWin[64];
	get_msg_arg_string(2, szArg, charsmax(szArg));

	switch(szArg[7])
	{
		case 't':
		{
			if(g_iNumberSoundsZombieWin)
			{
				if(equal(szArg[7], "terwin", 6))
				{
					ArrayGetString(g_aSoundsZombieWin, random(g_iNumberSoundsZombieWin), szSoundWin, charsmax(szSoundWin));
					
					set_msg_arg_string(2, szSoundWin);
				}
			}
		}
		case 'c':
		{
			if(g_iNumberSoundsSurvirvorWin)
			{
				if(equal(szArg[7], "ctwin", 5))
				{
					ArrayGetString(g_aSoundsSurvirvorWin, random(g_iNumberSoundsSurvirvorWin), szSoundWin, charsmax(szSoundWin));
					
					set_msg_arg_string(2, szSoundWin);
				}
			}
		}
	}
}

/*================================================================================
 [ReAPI]
=================================================================================*/
ReAPI_Init()	{
	RegisterHookChain(RG_ShowVGUIMenu,            "HC_ShowVGUIMenu_Pre",            false);
	RegisterHookChain(RG_CBasePlayer_Spawn,       "HC_CBasePlayer_Spawn_Post",      true);
	RegisterHookChain(RG_CBasePlayer_Killed,      "HC_CBasePlayer_Killed_Post",     true);
	RegisterHookChain(RG_CBasePlayer_PreThink,    "HC_CBasePlayer_PreThink_Pre",    false);
	RegisterHookChain(RG_CBasePlayer_TraceAttack, "HC_CBasePlayer_TraceAttack_Pre", false);
}

public HC_ShowVGUIMenu_Pre(const iIndex, const VGUIMenu: iMenuType)	{
	if(iMenuType == VGUI_Menu_Team)
	{
		ShowMenu_Main(iIndex);
	}
	
	SetHookChainReturn(ATYPE_INTEGER, 0);

	return HC_SUPERCEDE;
}

public HC_CBasePlayer_Spawn_Post(const iIndex)	{
	if(is_user_alive(iIndex))
	{
		if(IsNotSetBit(gp_iBit[BIT_ALIVE], iIndex))
		{
			SetBit(gp_iBit[BIT_ALIVE], iIndex);
		}

		g_iAliveHumans++;
		
		SetBit(gp_iBit[BIT_HUMAN], iIndex);

		if(IsSetBit(gp_iBit[BIT_MENU_EQUIPMENT], iIndex))
		{
			ShowMenu_Equipment(iIndex);
		}
		else
		{
			new iPrimaryWeaponId = gp_iEquipment[iIndex][PLAYER_EQUIPMENT_PRIMARY];
			new iSecondaryWeaponId = gp_iEquipment[iIndex][PLAYER_EQUIPMENT_SECONDARY];
			
			givePlayerPrimaryWeapon(iIndex, iPrimaryWeaponId);
			givePlayerSecondaryWeapon(iIndex, iSecondaryWeaponId);
			givePlayerGrenades(iIndex);
		}
		
		if(gp_iSelectedClass[iIndex] != CLASS_NONE)
		{
			gp_iClass[iIndex] = gp_iSelectedClass[iIndex];
			
			gp_iSelectedClass[iIndex] = CLASS_NONE;
		}
	}
}

public HC_CBasePlayer_Killed_Post(const iVictim, const iAttacker)	{
	if(IsNotSetBit(gp_iBit[BIT_ALIVE], iVictim))
	{
		return HC_CONTINUE;
	}
	
	ClearBit(gp_iBit[BIT_ALIVE], iVictim);
	
	if(IsSetBit(gp_iBit[BIT_INFECT], iVictim))
	{
		g_iAliveZombies--;
		
		remove_task(TASK_ID_PLAYER_HUD + iVictim);
		
		if(IsSetBit(gp_iBit[BIT_NIGHT_VISION], iVictim))
		{
			setPlayerNightVision(iVictim, false);
		}
	}
	else
	{
		g_iAliveHumans--;
		
		ClearBit(gp_iBit[BIT_HUMAN], iVictim);
	}
	
	return HC_CONTINUE;
}

public HC_CBasePlayer_PreThink_Pre(const iIndex)	{
	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		set_entvar(iIndex, var_flTimeStepSound, 999);
	}
}

public HC_CBasePlayer_TraceAttack_Pre(const iVictim, const iAttacker, Float: fDamage, Float: fDirection[3])	{
	if(!(g_bInfectionBegan))
	{
		SetHookChainReturn(ATYPE_INTEGER, 0);
		
		return HC_SUPERCEDE;
	}
	
	if(IsSetBit(gp_iBit[BIT_INFECT], iAttacker) && IsSetBit(gp_iBit[BIT_HUMAN], iVictim))
	{
		static Float: fArmor; fArmor = get_entvar(iVictim, var_armorvalue);
		
		if(fArmor > 0.0)
		{
			fDamage *= g_infoZombieClass[gp_iClass[iAttacker]][CLASS_FACTOR_DMG];
			
			fArmor -= fDamage;
			
			set_entvar(iVictim, var_armorvalue, fArmor);
		}
		else
		{
			if(g_iAliveHumans == 1)
			{
				SetHookChainArg(3, ATYPE_FLOAT, fDamage);
				
				return HC_CONTINUE;
			}
			else
			{
				setPlayerInfect(iVictim);
			
				set_entvar(iAttacker, var_frags, get_entvar(iAttacker, var_frags) + 1);
			}
		}
		
		SetHookChainArg(3, ATYPE_FLOAT, 0.0);
		
		return HC_CONTINUE;
	}
	
	if(IsSetBit(gp_iBit[BIT_HUMAN], iAttacker) && IsSetBit(gp_iBit[BIT_INFECT], iVictim))
	{
		if(g_iCvar_StateKnockbackSitZombie)
		{
			static iFlags; iFlags = get_entvar(iVictim, var_flags);
			
			if(iFlags & FL_ONGROUND && iFlags & FL_DUCKING)
			{
				return HC_CONTINUE;
			}
		}
		
		static Float: fOriginHuman[3], Float: fOriginZombie[3];
		
		get_entvar(iVictim, var_origin, fOriginZombie);
		get_entvar(iAttacker, var_origin, fOriginHuman);
		
		if(get_distance_f(fOriginHuman, fOriginZombie) > g_fCvar_MaxDistanceKnockback)
		{
			return HC_CONTINUE;
		}
		
		static Float: fVelocity[3], Float: fVelocityZ;
		get_entvar(iVictim, var_velocity, fVelocity);
		
		fVelocityZ = fVelocity[2];
		
		static iPrimaryWeaponListId, iSecondaryWeaponListId;
		getPlayerActiveWeaponListId(iAttacker, iPrimaryWeaponListId, iSecondaryWeaponListId);

		static Float: fFactorDirection = 0.0;

		if(iPrimaryWeaponListId && g_listPrimaryWeapons[iPrimaryWeaponListId][WEAPON_KNOCKBACK] > 0.0)
		{
			fFactorDirection = g_listPrimaryWeapons[iPrimaryWeaponListId][WEAPON_KNOCKBACK];
		}
		
		if(iSecondaryWeaponListId && g_listPrimaryWeapons[iSecondaryWeaponListId][WEAPON_KNOCKBACK] > 0.0)
		{
			fFactorDirection = g_listPrimaryWeapons[iSecondaryWeaponListId][WEAPON_KNOCKBACK];
		}

		if(fFactorDirection)
		{
			UTIL_VecMulScalar(fDirection, fDamage, fDirection);
			UTIL_VecMulScalar(fDirection, fFactorDirection, fDirection);
			UTIL_VecMulScalar(fDirection, g_infoZombieClass[gp_iClass[iVictim]][CLASS_KNOCKBACK], fDirection);
			
			UTIL_VecAdd(fDirection, fVelocity, fVelocity);

			fDirection[2] = fVelocityZ;
			
			set_entvar(iVictim, var_velocity, fVelocity);
		}
	}
	
	return HC_CONTINUE;
}

/*================================================================================
 [Engine]
=================================================================================*/
Engine_Init()	{
}

public EngineHook_Impulse_Flashlight(const iIndex)	{
	if(g_iCvar_BlockZombieFlashlight)
	{
		if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
		{
			return PLUGIN_HANDLED;
		}
	}
	
	return PLUGIN_CONTINUE;
}

/*================================================================================
 [FakeMeta]
=================================================================================*/
FakeMeta_Init()	{
	unregister_forward(FM_Spawn, g_iFakeMetaFwd_Spawn, true);
	
	register_forward(FM_EmitSound, "FakeMetaHook_EmitSound_Pre", false);
	
	TrieDestroy(g_tRemoveEntities);
}

FakeMeta_EnvFog()	{
	new iEntity = rg_create_entity("env_fog");
	
	if(iEntity)
	{
		UTIL_SetKvd(iEntity, "env_fog", "density", g_szFogDensity);
		UTIL_SetKvd(iEntity, "env_fog", "rendercolor", g_szFogColor);
	}
}

FakeMeta_RemoveEntities()	{
	new const szRemoveEntities[][] =
	{
		"func_hostage_rescue",
		"info_hostage_rescue",
		"func_bomb_target",
		"info_bomb_target",
		"func_vip_safetyzone",
		"info_vip_start",
		"func_escapezone",
		"hostage_entity",
		"monster_scientist",
		"func_buyzone"
	};

	g_tRemoveEntities = TrieCreate();

	for(new iCount = 0, iSize = sizeof(szRemoveEntities); iCount < iSize; iCount++)
	{
		TrieSetCell(g_tRemoveEntities, szRemoveEntities[iCount], iCount);
	}
	
	rg_create_entity("func_buyzone");

	g_iFakeMetaFwd_Spawn = register_forward(FM_Spawn, "FakeMetaHook_Spawn_Post", true);
}

public FakeMetaHook_Spawn_Post(const iEntity)	{
	if(!(is_entity(iEntity)))
	{
		return FMRES_IGNORED;
	}
	
	static szClassName[20];
	get_entvar(iEntity, var_classname, szClassName, charsmax(szClassName));
	
	if(TrieKeyExists(g_tRemoveEntities, szClassName))
	{
		set_entvar(iEntity, var_flags, FL_KILLME);
	}
	
	return FMRES_IGNORED;
}

public FakeMetaHook_EmitSound_Pre(const iIndex, const iChannel, const szSample[], const Float: fVolume, const Float: fAttn, const iFlag, const iPitch)	{
	if(IsPlayer(iIndex))
	{
		if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
		{
			new szSound[64];

			if(szSample[0] == 'i' && szSample[6] == 'n' && szSample[7] == 'v' && szSample[8] == 'g')
			{
				return FMRES_SUPERCEDE;
			}
			
			if(szSample[8] == 'k' && szSample[9] == 'n' && szSample[10] == 'i')
			{
				if(g_iNumberSoundsZombieKnifeMiss)
				{
					/* [Knife slash] */
					if(szSample[14] == 's' && szSample[15] == 'l' && szSample[16] == 'a')
					{
						ArrayGetString(g_aSoundsZombieKnifeMiss, random(g_iNumberSoundsZombieKnifeMiss), szSound, charsmax(szSound));
				
						emit_sound(iIndex, iChannel, szSound, fVolume, fAttn, iFlag, iPitch);
						
						return FMRES_SUPERCEDE;
					}
				}
				
				/* [Knife [hit|stab] */
				if((szSample[14] == 'h' && szSample[15] == 'i' && szSample[16] == 't') || (szSample[14] == 's' && szSample[15] == 't' && szSample[16] == 'a'))
				{
					/* [Wall] */
					if(szSample[17] == 'w' && szSample[18] == 'a' && szSample[19] == 'l')
					{
						if(g_iNumberSoundsZombieKnifeMiss)
						{
							ArrayGetString(g_aSoundsZombieKnifeMiss, random(g_iNumberSoundsZombieKnifeMiss), szSound, charsmax(szSound));
				
							emit_sound(iIndex, iChannel, szSound, fVolume, fAttn, iFlag, iPitch);
						}
					}
					else
					{
						if(g_iNumberSoundsZombieKnifeHits)
						{
							ArrayGetString(g_aSoundsZombieKnifeHits, random(g_iNumberSoundsZombieKnifeHits), szSound, charsmax(szSound));
				
							emit_sound(iIndex, iChannel, szSound, fVolume, fAttn, iFlag, iPitch);
						}
					}

					return FMRES_SUPERCEDE;
				}
			}
			
			if(g_iNumberSoundsZombieDie)
			{
				if(szSample[7] == 'd' && szSample[8] == 'i' && szSample[9] == 'e')
				{
					ArrayGetString(g_aSoundsZombieDie, random(g_iNumberSoundsZombieDie), szSound, charsmax(szSound));
				
					emit_sound(iIndex, iChannel, szSound, fVolume, fAttn, iFlag, iPitch);
					
					return FMRES_SUPERCEDE;
				}
			}
		}
	}
	
	return FMRES_IGNORED;
}

/*================================================================================
 [Hamsandwich]
=================================================================================*/
Hamsandwich_Init()	{
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "HamHook_Knife_Deploy_Post", true);
	RegisterHam(Ham_Item_PreFrame, "player", "HamHook_Item_PreFrame_Post", true);
	
	new const szEntityClass[][] =
	{
		"func_vehicle", 		// Управляемая машина
		"func_tracktrain", 		// Управляемый поезд
		"func_tank", 			// Управляемая пушка
		"game_player_hurt",	 	// При активации наносит игроку повреждения
		"func_recharge", 		// Увеличение запаса бронижелета
		"func_healthcharger", 	// Увеличение процентов здоровья
		"game_player_equip", 	// Выдаёт оружие
		"player_weaponstrip", 	// Забирает всё оружие
		"trigger_hurt", 		// Наносит игроку повреждения
		"trigger_gravity", 		// Устанавливает игроку силу гравитации
		"armoury_entity", 		// Объект лежащий на карте, оружия, броня или гранаты
		"weaponbox", 			// Оружие выброшенное игроком
		"weapon_shield" 		// Щит
	};
	
	new iCount;
	
	for(iCount = 0; iCount <= 7; iCount++)
	{
		DisableHamForward(
			g_iHamFwd_Entity_Block[iCount] = RegisterHam(
				Ham_Use, szEntityClass[iCount], "HamHook_EntityBlock_Pre", false
			)
		);
	}
	
	for(iCount = 8; iCount <= 12; iCount++)
	{
		DisableHamForward(
			g_iHamFwd_Entity_Block[iCount] = RegisterHam(
				Ham_Touch, szEntityClass[iCount], "HamHook_EntityBlock_Pre", false
			)
		);
	}
}

public HamHook_Knife_Deploy_Post(const iEntity)	{
	new iIndex = get_member(iEntity, m_pPlayer);

	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		if(g_infoZombieClass[gp_iClass[iIndex]][CLASS_KNIFE_MODEL])
		{
			entity_set_string(iIndex, EV_SZ_viewmodel, g_infoZombieClass[gp_iClass[iIndex]][CLASS_KNIFE_MODEL]);
			entity_set_string(iIndex, EV_SZ_weaponmodel, "");
		}
	}
	
	return HAM_IGNORED;
}

public HamHook_Item_PreFrame_Post(const iIndex)	{
	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		if(g_infoZombieClass[gp_iClass[iIndex]][CLASS_SPEED])
		{
			set_entvar(iIndex, var_maxspeed, g_infoZombieClass[gp_iClass[iIndex]][CLASS_SPEED]);
		}
	}
}

public HamHook_EntityBlock_Pre(const iEntity, const iIndex)	{
	if(IsPlayer(iIndex))
	{
		if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
		{
			return HAM_SUPERCEDE;
		}
	}

	return HAM_IGNORED;
}

/*================================================================================
 [ClCmd]
=================================================================================*/
ClCmd_Init()	{
	new const szCommand[][] =
	{
		"radio1",
		"radio2",
		"radio3",
		"jointeam",
		"joinclass"
	};
	
	for(new iCount = 0, iSize = sizeof(szCommand); iCount < iSize; iCount++)
	{
		register_clcmd(szCommand[iCount], "ClCmd_Block");
	}
	
	register_clcmd("drop",         "ClCmd_Drop");
	register_clcmd("nightvision",  "ClCmd_NightVision");
	
	register_clcmd("say /equip",   "ClCmd_Equipment");
}

public ClCmd_Block()	{
	return PLUGIN_HANDLED;
}

public ClCmd_Drop(const iIndex)	{
	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		if(WeaponIdType: get_user_weapon(iIndex) == WEAPON_KNIFE)
		{
			return PLUGIN_HANDLED;
		}
	}
	
	return PLUGIN_CONTINUE;
}

public ClCmd_NightVision(const iIndex)	{
	if(!(g_bZombieUseNvg) || IsNotSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		return PLUGIN_HANDLED;
	}

	setPlayerNightVision(iIndex, bool: IsNotSetBit(gp_iBit[BIT_NIGHT_VISION], iIndex));
	
	return PLUGIN_CONTINUE;
}

public ClCmd_Equipment(const iIndex)	{
	SetBit(gp_iBit[BIT_MENU_EQUIPMENT], iIndex);
	
	return PLUGIN_HANDLED;
}

/*================================================================================
 [MenuCmd]
=================================================================================*/
MenuCmd_Init()	{
	register_menucmd(register_menuid("ShowMenu_Main"), MENU_KEY_1|MENU_KEY_3|MENU_KEY_5|MENU_KEY_0, "Handler_Main");
	register_menucmd(register_menuid("ShowMenu_Equipment"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0, "Handler_Equipment");
	register_menucmd(register_menuid("ShowMenu_ChooseClass"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0, "Handler_ChooseClass");
	register_menucmd(register_menuid("ShowMenu_PrimaryWeapons"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0, "Handler_PrimaryWeapons");
	register_menucmd(register_menuid("ShowMenu_SecondaryWeapons"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0, "Handler_SecondaryWeapons");
}

ShowMenu_Main(const iIndex)	{
	static szMenu[512]; new iBitKeys = MENU_KEY_1|MENU_KEY_3|MENU_KEY_5|MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\r[ZMB] \wГлавное меню^n^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[1] \wВыбрать класс^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[2] \dМагазин^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[3] \wМеню обмундирования \r[ \y%s \r]^n^n", IsSetBit(gp_iBit[BIT_MENU_EQUIPMENT], iIndex) ? "ON" : "OFF");
	
	new TeamName: iTeam = get_member(iIndex, m_iTeam);

	if(iTeam == TEAM_SPECTATOR || iTeam == TEAM_UNASSIGNED)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[5] \wНачать играть^n^n^n^n^n^n");
	}
	else
	{
		if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
		{
			iBitKeys &= ~MENU_KEY_5;
			
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[5] \dЗайти за [ Спектаторов ]^n^n^n^n^n^n");
		}
		else
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[5] \wЗайти за \r[ \yСпектаторов \r]^n^n^n^n^n^n");
		}
	}

	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[0] \wВыход");
	
	return show_menu(iIndex, iBitKeys, szMenu, -1, "ShowMenu_Main");
}

public Handler_Main(const iIndex, const iKey)	{
	switch(iKey)
	{
		case 0:
		{
			return ShowMenu_ChooseClass(iIndex, gp_iMenuPosition[iIndex] = 0);
		}
		case 2:
		{
			InvertBit(gp_iBit[BIT_MENU_EQUIPMENT], iIndex);

			return ShowMenu_Main(iIndex);
		}
		case 4:
		{
			if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
			{
				return ShowMenu_Main(iIndex);
			}
			
			new TeamName: iTeam = get_member(iIndex, m_iTeam),
				TeamName: iRandomTeam = TEAM_SPECTATOR;

			if(iTeam == TEAM_SPECTATOR || iTeam == TEAM_UNASSIGNED)
			{
				iRandomTeam = TeamName: random_num(1, 2);
			}

			rg_join_team(iIndex, iRandomTeam);
		}
	}
	
	return PLUGIN_HANDLED;
}

ShowMenu_ChooseClass(const iIndex, const iPos)	{
	if(iPos < 0)
	{
		return PLUGIN_HANDLED;
	}
	
	static iStart; iStart = iPos * 8;
	
	if(iStart > g_iZombieClasses)
	{
		iStart = g_iZombieClasses;
	}

	iStart = iStart - (iStart % 8);
	
	gp_iMenuPosition[iIndex] = iStart / 8;

	static iEnd; iEnd = iStart + 8;
	
	if(iEnd > g_iZombieClasses)
	{
		iEnd = g_iZombieClasses;
	}
	
	static iPagesNum; iPagesNum = (g_iZombieClasses / 8 + ((g_iZombieClasses % 8) ? 1 : 0));
	
	static szMenu[512]; new iBitKeys = MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\r[ZMB] \wКлассы зомби \d[%d|%d]^n^n", iPos + 1, iPagesNum);

	new iItem = 0, iCount;
	for(iCount = iStart + 1; iCount < iEnd + 1; iCount++)
	{
		if(gp_iClass[iIndex] == iCount)
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \d%s^n", ++iItem, g_infoZombieClass[iCount][CLASS_NAME]);
		}
		else
		{
			iBitKeys |= (1 << iItem);
			
			if(gp_iSelectedClass[iIndex] == iCount)
			{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \d%s \r[ \yON SPAWN \r]^n", ++iItem, g_infoZombieClass[iCount][CLASS_NAME]);
			}
			else
			{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s^n", ++iItem, g_infoZombieClass[iCount][CLASS_NAME]);
			}
		}
	}
	
	for(iCount = iItem; iCount < 8; iCount++)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
	}
	
	if(iEnd < g_iZombieClasses)
	{
		iBitKeys |= MENU_KEY_9;
		
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r[9] \wДалее^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	}
	else
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	}
	
	return show_menu(iIndex, iBitKeys, szMenu, -1, "ShowMenu_ChooseClass");
}

public Handler_ChooseClass(const iIndex, const iKey)	{
	switch(iKey)
	{
		case 8:
		{
			return ShowMenu_ChooseClass(iIndex, ++gp_iMenuPosition[iIndex]);
		}
		case 9:
		{
			return ShowMenu_ChooseClass(iIndex, --gp_iMenuPosition[iIndex]);
		}
		default:
		{
			new iClass = gp_iMenuPosition[iIndex] * 8 + iKey + 1;
			
			if(IsSetBit(gp_iBit[BIT_ALIVE], iIndex) && IsNotSetBit(gp_iBit[BIT_INFECT], iIndex))
			{
				gp_iClass[iIndex] = iClass;
			}
			else
			{
				if(gp_iSelectedClass[iIndex] == iClass)
				{
					gp_iSelectedClass[iIndex] = CLASS_NONE;
				}
				else
				{
					gp_iSelectedClass[iIndex] = iClass;
				}
				
				/*
					TODO:
						Добавть сообщение, что класс будет доступен
						с нового раунда
				*/
			}
		}
	}
	
	return PLUGIN_HANDLED;
}

ShowMenu_Equipment(const iIndex)	{
	static szMenu[512]; new iBitKeys = MENU_KEY_1|MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\r[ZMB] \wОбмундирование^n^n");
	
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[1] \wНовое оружие^n");
	
	static iPrimaryWeaponId; iPrimaryWeaponId = gp_iEquipment[iIndex][PLAYER_EQUIPMENT_PRIMARY];
	static iSecondaryWeaponId; iSecondaryWeaponId = gp_iEquipment[iIndex][PLAYER_EQUIPMENT_SECONDARY];

	if(!(iPrimaryWeaponId) || !(iSecondaryWeaponId))
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[2] \dПредыдущие снаряжие^n^n");
	}
	else
	{
		iBitKeys |= MENU_KEY_2;
		
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[2] \wПредыдущие снаряжие \r[ \d%s | %s \r]^n^n", g_listPrimaryWeapons[iPrimaryWeaponId][WEAPON_NAME], g_listSecondaryWeapons[iSecondaryWeaponId][WEAPON_NAME]);
	}
	
	if(!(iPrimaryWeaponId) || !(iSecondaryWeaponId))
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[3] \dБольше не показывать меню^n^n^n^n^n^n^n");
	}
	else
	{
		iBitKeys |= MENU_KEY_3;
		
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[3] \wБольше не показывать меню^n^n^n^n^n^n^n");
	}
	
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[0] \wВыход");

	return show_menu(iIndex, iBitKeys, szMenu, -1, "ShowMenu_Equipment");
}

public Handler_Equipment(const iIndex, const iKey)	{
	if(IsNotSetBit(gp_iBit[BIT_ALIVE], iIndex) || IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		return PLUGIN_HANDLED;
	}
	
	switch(iKey)
	{
		case 0:
		{
			return ShowMenu_PrimaryWeapons(iIndex, gp_iMenuPosition[iIndex] = 0);
		}
		case 1, 2:
		{
			new iPrimaryWeaponId = gp_iEquipment[iIndex][PLAYER_EQUIPMENT_PRIMARY];
			new iSecondaryWeaponId = gp_iEquipment[iIndex][PLAYER_EQUIPMENT_SECONDARY];
			
			givePlayerPrimaryWeapon(iIndex, iPrimaryWeaponId);
			givePlayerSecondaryWeapon(iIndex, iSecondaryWeaponId);
			givePlayerGrenades(iIndex);

			if(iKey == 2)
			{
				ClearBit(gp_iBit[BIT_MENU_EQUIPMENT], iIndex);
			}
		}
	}
	
	return PLUGIN_HANDLED;
}

ShowMenu_PrimaryWeapons(const iIndex, const iPos)	{
	if(iPos < 0 || !(g_iPrimaryWeapons))
	{
		return PLUGIN_HANDLED;
	}
	
	static iStart; iStart = iPos * 8;
	
	if(iStart > g_iPrimaryWeapons)
	{
		iStart = g_iPrimaryWeapons;
	}
	
	iStart = iStart - (iStart % 8);
	
	gp_iMenuPosition[iIndex] = iStart / 8;

	static iEnd; iEnd = iStart + 8;
	
	if(iEnd > g_iPrimaryWeapons)
	{
		iEnd = g_iPrimaryWeapons;
	}
	
	static iPagesNum; iPagesNum = (g_iPrimaryWeapons / 8 + ((g_iPrimaryWeapons % 8) ? 1 : 0));
	
	static szMenu[512]; new iBitKeys = MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\r[ZMB] \wОсновное оружие \d[%d|%d]^n^n", iPos + 1, iPagesNum);

	new iItem = 0, iCount;

	for(iCount = iStart + 1; iCount <= iEnd; iCount++)
	{
		iBitKeys |= (1 << iItem);
		
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s^n", ++iItem, g_listPrimaryWeapons[iCount][WEAPON_NAME]);
	}

	for(iCount = iItem; iCount < 8; iCount++)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
	}
	
	if(iEnd < g_iPrimaryWeapons)
	{
		iBitKeys |= MENU_KEY_9;
		
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r[9] \wДалее^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	}
	else
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	}
	
	return show_menu(iIndex, iBitKeys, szMenu, -1, "ShowMenu_PrimaryWeapons");
}

public Handler_PrimaryWeapons(const iIndex, const iKey)	{
	if(IsNotSetBit(gp_iBit[BIT_ALIVE], iIndex) || IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		return PLUGIN_HANDLED;
	}
	
	switch(iKey)
	{
		case 8:
		{
			return ShowMenu_PrimaryWeapons(iIndex, ++gp_iMenuPosition[iIndex]);
		}
		case 9:
		{
			return ShowMenu_PrimaryWeapons(iIndex, --gp_iMenuPosition[iIndex]);
		}
		default:
		{
			new iWeaponId = gp_iMenuPosition[iIndex] * 8 + iKey + 1;
			
			givePlayerPrimaryWeapon(iIndex, iWeaponId);

			switch(g_iSecondaryWeapons)
			{
				case 0:
				{
					givePlayerGrenades(iIndex);
				}
				default:
				{
					return ShowMenu_SecondaryWeapons(iIndex, gp_iMenuPosition[iIndex] = 0);
				}
			}
		}
	}
	return PLUGIN_HANDLED;
}

ShowMenu_SecondaryWeapons(const iIndex, const iPos)	{
	if(iPos < 0 || !(g_iSecondaryWeapons))
	{
		return PLUGIN_HANDLED;
	}
	
	static iStart; iStart = iPos * 8;
	
	if(iStart > g_iSecondaryWeapons)
	{
		iStart = g_iSecondaryWeapons;
	}
	
	iStart = iStart - (iStart % 8);
	
	gp_iMenuPosition[iIndex] = iStart / 8;

	static iEnd; iEnd = iStart + 8;
	
	if(iEnd > g_iSecondaryWeapons)
	{
		iEnd = g_iSecondaryWeapons;
	}
	
	static iPagesNum; iPagesNum = (g_iSecondaryWeapons / 8 + ((g_iSecondaryWeapons % 8) ? 1 : 0));
	
	static szMenu[512]; new iBitKeys = MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\r[ZMB] \wЗапасное оружие \d[%d|%d]^n^n", iPos + 1, iPagesNum);

	new iItem = 0, iCount;
	for(iCount = iStart + 1; iCount <= iEnd; iCount++)
	{
		iBitKeys |= (1 << iItem);
		
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s^n", ++iItem, g_listSecondaryWeapons[iCount][WEAPON_NAME]);
	}
	
	for(iCount = iItem; iCount < 8; iCount++)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
	}
	
	if(iEnd < g_iSecondaryWeapons)
	{
		iBitKeys |= MENU_KEY_9;
		
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r[9] \wДалее^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	}
	else
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	}
	
	return show_menu(iIndex, iBitKeys, szMenu, -1, "ShowMenu_SecondaryWeapons");
}

public Handler_SecondaryWeapons(const iIndex, const iKey)	{
	if(IsNotSetBit(gp_iBit[BIT_ALIVE], iIndex) || IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		return PLUGIN_HANDLED;
	}
	
	switch(iKey)
	{
		case 8:
		{
			return ShowMenu_SecondaryWeapons(iIndex, ++gp_iMenuPosition[iIndex]);
		}
		case 9:
		{
			return ShowMenu_SecondaryWeapons(iIndex, --gp_iMenuPosition[iIndex]);
		}
		default:
		{
			new iWeaponId = gp_iMenuPosition[iIndex] * 8 + iKey + 1;
			
			givePlayerSecondaryWeapon(iIndex, iWeaponId);
			givePlayerGrenades(iIndex);
		}
	}
	
	return PLUGIN_HANDLED;
}

/*================================================================================
 [TASK]
=================================================================================*/
public taskInfect()	{
	g_bInfectionBegan = true;
	
	for(new iCount = 0; iCount < 13; iCount++)
	{
		EnableHamForward(g_iHamFwd_Entity_Block[iCount]);
	}
	
	new iIndex, iPlayersNum, iPlayers[MAX_PLAYERS + 1];
	
	for(iIndex = 1; iIndex <= g_iMaxPlayers; iIndex++)
	{
		if(IsSetBit(gp_iBit[BIT_ALIVE], iIndex))
		{
			iPlayers[iPlayersNum++] = iIndex;
		}
	}
	
	if(iPlayersNum)
	{
		new iTotalInfected = clamp(floatround(iPlayersNum * g_fCvar_ZombieRatio), 1, 31);

		while(iTotalInfected)
		{
			new iInfected = iPlayers[random(iPlayersNum)];
			
			if(IsNotSetBit(gp_iBit[BIT_INFECT], iInfected))
			{
				setPlayerInfect(iInfected);
				
				iTotalInfected--;
			}
		}
	}
	
	for(iIndex = 1; iIndex <= g_iMaxPlayers; iIndex++)
	{
		if(IsSetBit(gp_iBit[BIT_HUMAN], iIndex))
		{
			rg_set_user_team(iIndex, TEAM_CT);
		}
	}
}

public taskPlayerHud(iIndex)	{
	iIndex -= TASK_ID_PLAYER_HUD;

	static Float: fHealth; fHealth = get_entvar(iIndex, var_health);

	switch(g_iCvar_HudType)
	{
		case 0:	/* [HUD] */
		{
			set_hudmessage(g_iCvar_HudColor[COLOR_RED], g_iCvar_HudColor[COLOR_GREEN], g_iCvar_HudColor[COLOR_BLUE], g_fCvar_HudPosition[POS_X], g_fCvar_HudPosition[POS_Y], 0, 0.0, 0.9, 0.15, 0.15, -1);
			ShowSyncHudMsg(iIndex, g_iSyncPlayerHud, "Жизни [%.f] Класс ^"%s^"", fHealth, g_infoZombieClass[gp_iClass[iIndex]]);
		}
		case 1:	/* [DHUD] */
		{
			set_dhudmessage(g_iCvar_HudColor[COLOR_RED], g_iCvar_HudColor[COLOR_GREEN], g_iCvar_HudColor[COLOR_BLUE], g_fCvar_HudPosition[POS_X], g_fCvar_HudPosition[POS_Y], 0, 0.0, 0.9, 0.15, 0.15);
			show_dhudmessage(iIndex, "Жизни [%.f] Класс ^"%s^"", fHealth, g_infoZombieClass[gp_iClass[iIndex]]);
		}
	}
}

/*================================================================================
 [ZMB]
=================================================================================*/
stock setWeather(const iWeather)	{
	if(iWeather)
	{
		g_iActiveWeather = g_iWeather;

		if(g_iActiveWeather == 3)
		{
			g_iActiveWeather = random_num(1, 2);
		}
	}
}

stock setPlayerInfect(const iIndex)	{
	ClearBit(gp_iBit[BIT_HUMAN], iIndex);
	
	SetBit(gp_iBit[BIT_INFECT], iIndex);

	if(g_iNumberSoundsZombieScream)
	{
		static szSound[64];
		
		ArrayGetString(g_aSoundsZombieScream, random(g_iNumberSoundsZombieScream), szSound, charsmax(szSound));
	
		emit_sound(iIndex, CHAN_AUTO, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	}

	UTIL_SetPlayerHideHud(
		.iIndex = iIndex,
		.iHideHud = (g_iCvar_BlockZombieFlashlight ? HIDEHUD_FLASHLIGHT : (1 << 0)) | HIDEHUD_HEALTH
	);
	
	UTIL_SetPlayerScreenFade(
		.iIndex = iIndex,
		.iDuration = (1 << 12),
		.iHoldTime = (1 << 12),
		.iFlags = 0,
		.iRed = 0,
		.iGreen = 255,
		.iBlue = 0,
		.iAlpha = 110
	);

	new iClass = gp_iClass[iIndex];
	
	if(g_infoZombieClass[iClass][CLASS_PLAYER_MODEL])
	{
		rg_set_user_model(iIndex, g_infoZombieClass[iClass][CLASS_PLAYER_MODEL], true);
	}
	
	if(g_infoZombieClass[iClass][CLASS_HEALTH])
	{
		set_entvar(iIndex, var_health, g_infoZombieClass[iClass][CLASS_HEALTH]);
	}
	
	if(g_infoZombieClass[iClass][CLASS_GRAVITY])
	{
		set_entvar(iIndex, var_gravity, g_infoZombieClass[iClass][CLASS_GRAVITY]);
	}
	
	set_entvar(iIndex, var_flTimeStepSound, 999);
	
	rg_set_user_team(iIndex, TEAM_TERRORIST);

	ExecuteHamB(Ham_Item_PreFrame, iIndex);

 	UTIL_RemovePlayerSlotWeapon(iIndex, PRIMARY_WEAPON_SLOT);
	UTIL_RemovePlayerSlotWeapon(iIndex, PISTOL_SLOT);
	UTIL_RemovePlayerSlotWeapon(iIndex, GRENADE_SLOT);

 	new iItem = get_member(iIndex, m_pActiveItem);
	
	if(iItem > 0)
	{
		ExecuteHamB(Ham_Item_Deploy, iItem);
	}
	
	if(g_bZombieUseNvg)
	{
		if(g_bZombieStateNvg)
		{
			setPlayerNightVision(iIndex, true);
		}
	}
	
	if(g_iCvar_BlockZombieFlashlight)
	{
		new iEffects = get_entvar(iIndex, var_effects);
		
		if(iEffects & EF_DIMLIGHT)
		{
			set_entvar(iIndex, var_effects, iEffects & ~EF_DIMLIGHT);
		}
	}
	
	g_iAliveHumans--;
	g_iAliveZombies++;
	
	set_task(1.0, "taskPlayerHud", TASK_ID_PLAYER_HUD + iIndex, .flags = "b");
}

stock setRandomPlayerZombie()	{
	new iIndex, iPlayersNum, iPlayers[MAX_PLAYERS + 1];
	
	for(iIndex = 1; iIndex <= g_iMaxPlayers; iIndex++)
	{
		if(IsSetBit(gp_iBit[BIT_HUMAN], iIndex))
		{
			iPlayers[iPlayersNum++] = iIndex;
		}
	}
	
	if(iPlayersNum)
	{
		new iInfected = iPlayers[random(iPlayersNum)];

		setPlayerInfect(iInfected);
	}
}

stock setPlayerNightVision(const iIndex, const bool: bNightVision)	{
	UTIL_SetPlayerScreenFade(
		.iIndex = iIndex,
		.iDuration = 0,
		.iHoldTime = 0,
		.iFlags = 0x0004,
		.iRed = g_iNvgColor[COLOR_RED],
		.iGreen = g_iNvgColor[COLOR_GREEN],
		.iBlue = g_iNvgColor[COLOR_BLUE],
		.iAlpha = bNightVision ? g_iNvgAlpha : 0
	);

	UTIL_SetPlayerMapLightStyle(iIndex, bNightVision ? "z" : g_szCvar_MapLightStyle);

	InvertBit(gp_iBit[BIT_NIGHT_VISION], iIndex);
}

stock getPlayerActiveWeaponListId(const iIndex, &iPrimaryWeaponListId, &iSecondaryWeaponListId)	{
 	new iItem = get_member(iIndex, m_pActiveItem), szWeaponName[20];
	
 	if(iItem > 0)
 	{
        get_entvar(iItem, var_classname, szWeaponName, charsmax(szWeaponName));

        if(!(TrieGetCell(g_tPrimaryWeapons, szWeaponName, iPrimaryWeaponListId)))
		{
			iPrimaryWeaponListId = 0;
		}
		
        if(!(TrieGetCell(g_tSecondaryWeapons, szWeaponName, iSecondaryWeaponListId)))
		{
			iSecondaryWeaponListId = 0;
		}
 	}
}

stock givePlayerPrimaryWeapon(const iIndex, const iPrimaryWeaponId)	{
	if(iPrimaryWeaponId)
	{
		gp_iEquipment[iIndex][PLAYER_EQUIPMENT_PRIMARY] = iPrimaryWeaponId;

		rg_give_item(iIndex, g_listPrimaryWeapons[iPrimaryWeaponId][WEAPON_CLASSNAME], GT_REPLACE);
		rg_set_user_bpammo(iIndex, g_listPrimaryWeapons[iPrimaryWeaponId][WEAPON_ID], g_listPrimaryWeapons[iPrimaryWeaponId][WEAPON_BPAMMO]);
	}
}

stock givePlayerSecondaryWeapon(const iIndex, const iSecondaryWeaponId)	{
	if(iSecondaryWeaponId)
	{
		gp_iEquipment[iIndex][PLAYER_EQUIPMENT_SECONDARY] = iSecondaryWeaponId;

		rg_give_item(iIndex, g_listSecondaryWeapons[iSecondaryWeaponId][WEAPON_CLASSNAME], GT_REPLACE);
		rg_set_user_bpammo(iIndex, g_listSecondaryWeapons[iSecondaryWeaponId][WEAPON_ID], g_listSecondaryWeapons[iSecondaryWeaponId][WEAPON_BPAMMO]);
	}
}

stock givePlayerGrenades(const iIndex)	{
	for(new iCount = 0; iCount < g_iGrenades; iCount++)
	{
		rg_give_item(iIndex, g_listGrenades[iCount]);
	}
}

stock addZombieClass(const szName[], const szKnifeModel[], const szPlayerModel[], const Float: fSpeed, const Float: fHealth, const Float: fGravity, const Float: fKnockback, const Float: fFactorDmg)	{
	new iClass = g_iZombieClasses += 1;

	copy(g_infoZombieClass[iClass][CLASS_NAME], 64, szName);
	copy(g_infoZombieClass[iClass][CLASS_KNIFE_MODEL], 64, szKnifeModel);
	copy(g_infoZombieClass[iClass][CLASS_PLAYER_MODEL], 64, szPlayerModel);
	
	g_infoZombieClass[iClass][CLASS_SPEED] = _: fSpeed;
	g_infoZombieClass[iClass][CLASS_HEALTH] = _: fHealth;
	g_infoZombieClass[iClass][CLASS_GRAVITY] = _: fGravity;
	g_infoZombieClass[iClass][CLASS_KNOCKBACK] = _: fKnockback;
	g_infoZombieClass[iClass][CLASS_FACTOR_DMG] = _: fFactorDmg;
}

stock writeDefaultClassFile(const szFileDir[])	{
	write_file(
		szFileDir,
		"\
			[Slum]^n\
			^tknife_model = ^"models/zmb/classes/v_knife.mdl^"^n\
			^tplayer_model = ^"slum^"^n^n\
			^tspeed = ^"225^"^n\
			^thealth = ^"2200^"^n\
			^tgravity = ^"0.7^"^n\
			^tfactor_damage = ^"1.2^"^n\
			[end]\
		"
	);
}

/*================================================================================
 [UTIL]
=================================================================================*/
stock UTIL_SetPlayerMapLightStyle(const iIndex, const szMapLightStyle[])	{
	message_begin(MSG_ONE, SVC_LIGHTSTYLE, {0, 0, 0}, iIndex);
	{
		write_byte(0);
		write_string(szMapLightStyle);
	}
	message_end();
}

stock UTIL_SetPlayerWeather(const iIndex, const iWeather)	{
	switch(iIndex)
	{
		case 0:
		{
			message_begin(MSG_ALL, MsgId_ReceiveW);
			{
				write_byte(iWeather);
			}
			message_end();
		}
		default:
		{
 			message_begin(MSG_ONE, MsgId_ReceiveW, {0, 0, 0}, iIndex);
			{
				write_byte(iWeather);
			}
			message_end();
		}
	}
}

stock UTIL_RemovePlayerSlotWeapon(const iIndex, const InventorySlotType: iSlot)	{
    new iItem = get_member(iIndex, m_rgpPlayerItems, iSlot), szWeaponClassName[20];

    while(iItem > 0)
    {
        get_entvar(iItem, var_classname, szWeaponClassName, charsmax(szWeaponClassName));

        rg_remove_item(iIndex, szWeaponClassName);

        iItem = get_member(iItem, m_pNext);
    }
}

stock UTIL_SetPlayerHideHud(const iIndex, const iHideHud)	{
	message_begin(MSG_ONE, MsgId_HideWeapon, {0, 0, 0}, iIndex);
	{
		write_byte(iHideHud);
	}
	message_end();
}

stock UTIL_SetPlayerScreenFade(const iIndex, const iDuration, const iHoldTime, const iFlags, const iRed, const iGreen, const iBlue, const iAlpha)	{
	message_begin(MSG_ONE, MsgId_ScreenFade, {0, 0, 0}, iIndex);
	{
		write_short(iDuration);
		write_short(iHoldTime);
		write_short(iFlags);
		write_byte(iRed);
		write_byte(iGreen);
		write_byte(iBlue);
		write_byte(iAlpha);
	}
	message_end();
}

stock UTIL_SetKvd(const iEntity, const szClssName[], const szKeyName[], const szValue[])	{
	set_kvd(0, KV_ClassName, szClssName);
	set_kvd(0, KV_KeyName, szKeyName);
	set_kvd(0, KV_Value, szValue);
	set_kvd(0, KV_fHandled, 0);

	return dllfunc(DLLFunc_KeyValue, iEntity, 0);
}

stock UTIL_SetFileState(const szPlugin[], const szMessage[], any:...)	{
	new szLog[256];
	vformat(szLog, charsmax(szLog), szMessage, 3);
	
	new szDate[20];
	get_time("error_%Y%m%d.log", szDate, charsmax(szDate));
	
	log_to_file(szDate, "[%s] %s", szPlugin, szLog);
}

stock UTIL_ParseHEXColor(const szValue[])	{
	new iColor[Color];
	
	if(szValue[0] != '#' && strlen(szValue) != 7)
	{
		return iColor;
	}

	iColor[COLOR_RED] = UTIL_Parse16bit(szValue[1], szValue[2]);
	iColor[COLOR_GREEN] = UTIL_Parse16bit(szValue[3], szValue[4]);
	iColor[COLOR_BLUE] = UTIL_Parse16bit(szValue[5], szValue[6]);

	return iColor;
}

stock UTIL_Parse16bit(const cSymbolA, const cSymbolB)	{
	return UTIL_ParseHex(cSymbolA) * 16 + UTIL_ParseHex(cSymbolB);
}

stock UTIL_ParseHex(const cSymbol)	{
	if('0' <= cSymbol && cSymbol <= '9')
	{
		return cSymbol - '0';
	}
	
	if('a' <= cSymbol && cSymbol <= 'f')
	{
		return 10 + cSymbol - 'a';
	}
	
	if('A' <= cSymbol && cSymbol <= 'F')
	{
		return 10 + cSymbol - 'A';
	}

	return 0;
}

stock UTIL_VecAdd(const Float: fVectorA[3], const Float: fVectorB[3], Float: fOut[3])	{
	fOut[0] = fVectorA[0] + fVectorB[0];
	fOut[1] = fVectorA[1] + fVectorB[1];
	fOut[2] = fVectorA[2] + fVectorB[2];
}

stock UTIL_VecMulScalar(const Float: fVector[3], const Float: fScalar, Float: fOut[3])	{
	fOut[0] = fVector[0] * fScalar;
	fOut[1] = fVector[1] * fScalar;
	fOut[2] = fVector[2] * fScalar;
}