#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#include "zmb.inc"

#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
#endif

#pragma semicolon                    1

#define PLUGIN_NAME                  "[ZMB] Core"
#define PLUGIN_VERS                  "0.0.8"
#define PLUGIN_AUTH                  "81x08"

#define MAX_PLAYERS                  32
#define MAX_CLASSES                  10

#define MAX_GRENADES                 4
#define MAX_PRIMARY_WEAPONS          3
#define MAX_SECONDARY_WEAPONS        3

#define CLASS_NONE                   0

#define HIDEHUD_FLASHLIGHT           (1 << 1)
#define HIDEHUD_HEALTH               (1 << 3)

enum (+= 35)	{
	TASK_ID_INFECT,

	TASK_ID_PLAYER_HUD,
	TASK_ID_RESTART_GAME,
	TASK_ID_ZOMBIE_HP_REGENERATION
};

enum Positon	{
	Float: POS_X,
	Float: POS_Y
};

enum infoClass	{
	CLASS_NAME[64],
	CLASS_KNIFE_MODEL[64],
	CLASS_PLAYER_MODEL[64],
	
	CLASS_ACCESS,
	Float: CLASS_SPEED,
	Float: CLASS_HEALTH,
	Float: CLASS_GRAVITY,
	
	bool: CLASS_FOOTSTEPS,
	
	Float: CLASS_KNOCKBACK,
	Float: CLASS_FACTOR_DAMAGE,
	Float: CLASS_HP_REGENERATION,
	Float: CLASS_HP_REGENERATION_MIN
};

enum listWeaponInfo	{
	WEAPON_NAME[12],
	WEAPON_CLASSNAME[20],
	WeaponIdType: WEAPON_ID,
	WEAPON_BPAMMO,
	Float: WEAPON_KNOCKBACK
};

enum playerEquipment	{
	PLAYER_EQUIPMENT_PRIMARY,
	PLAYER_EQUIPMENT_SECONDARY
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
	g_iSyncPlayerHud,
	g_iTimeRestartGame;

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
	g_iNumberSoundsZombieScream;

new g_infoZombieClass[MAX_CLASSES + 1][infoClass];

new g_iCvar_HudType,
	g_iCvar_HudColor[Color],
	g_iCvar_TimeRestartGame;

new bool: g_bCvar_SaveEquipment,
	bool: g_bCvar_BlockZombieFlashlight,
	bool: g_bCvar_StateKnockbackSitZombie;

new Float: g_fCvar_ZombieRatio,
	Float: g_fCvar_TimeInfections,
	Float: g_fCvar_HudPosition[Positon],
	Float: g_fCvar_MaxDistanceKnockback;

new bool: g_bZombieUseNvg,
	bool: g_bZombieStateNvg;

new bool: g_bFog,
	bool: g_bRoundEnd,
	bool: g_bRestartGame,
	bool: g_bInfectionBegan;

new g_szFogColor[12],
	g_szFogDensity[8];

new g_szCvar_MapLightStyle[2],
	g_szCvar_GameDescription[64];

new gp_iClass[MAX_PLAYERS + 1],
	gp_iSelectedClass[MAX_PLAYERS + 1];

new gp_iBit[bitsPlayer],
	gp_iFlags[MAX_PLAYERS + 1],
	gp_iEquipment[MAX_PLAYERS + 1][playerEquipment],
	gp_iMenuPosition[MAX_PLAYERS + 1];

new gp_szSteamId[MAX_PLAYERS + 1][35];

new Trie: g_tEquipment,
	Trie: g_tRemoveEntities,
	Trie: g_tSoundsZombieKnife;

new	Array: g_aSoundsSurvirvorWin,
	Array: g_aSoundsZombieDie,
	Array: g_aSoundsZombieWin,
	Array: g_aSoundsZombieScream;

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
	FakeMeta_Init();
	Hamsandwich_Init();

	ClCmd_Init();
	MenuCmd_Init();

	register_dictionary("zmb_core.txt");
	
	g_iMaxPlayers = get_maxplayers();
	
	g_iSyncPlayerHud = CreateHudSyncObj();
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
			UTIL_SetFileState("Core", "~ [ERROR] Конфигурационный файл ^"%s^" не найден.", szFileDir);
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
		new iStrLen, iKey, iBlock, iSize, iCount;
		
		new szBuffer[128], szBlock[32], szKey[32], szValue[64];
		new szWeaponName[16], szClassName[16], szBpammo[6], szKnockback[6];

		#define MAIN_BLOCK__NONE                          0
		#define MAIN_BLOCK__WEATHER                       1
		#define MAIN_BLOCK__NIGHT_VISION                  2
		#define MAIN_BLOCK__EQUIPMENT_PRIMARY             3
		#define MAIN_BLOCK__EQUIPMENT_SECONDARY           4
		#define MAIN_BLOCK__EQUIPMENT_GRENADES            5
		
		new Trie: tMainsBlocks = TrieCreate();
		
		new const szMainsBlock[][] = {
			"weather",
			"nightvision",
			"equipment-primary",
			"equipment-secondary",
			"equipment-grenades"
		};
		
		for(iCount = 0, iSize = sizeof(szMainsBlock); iCount < iSize; iCount++)
		{
			TrieSetCell(tMainsBlocks, szMainsBlock[iCount], iCount + 1);
		}
		
		#define MAIN_KEY__NONE                            0
		#define MAIN_KEY__WEATHER                         1
		#define MAIN_KEY__FOG                             2
		#define MAIN_KEY__FOG_COLOR                       3
		#define MAIN_KEY__FOG_DENSITY                     4
		#define MAIN_KEY__ZOMBIE_USE_NVG                  5
		#define MAIN_KEY__ZOMBIE_STATE_NVG                6
		#define MAIN_KEY__NVG_ALPHA                       7
		#define MAIN_KEY__NVG_COLOR                       8

		new Trie: tMainsKeys = TrieCreate();

		new const szMainsKeys[][] = {
			"weather",
			"fog",
			"fog_color",
			"fog_density",
			"zombie_use_nvg",
			"zombie_state_nvg",
			"nvg_alpha",
			"nvg_color"
		};

		for(iCount = 0, iSize = sizeof(szMainsKeys); iCount < iSize; iCount++)
		{
			TrieSetCell(tMainsKeys, szMainsKeys[iCount], iCount + 1);
		}
		
		while(!(feof(iFile)))
		{
			fgets(iFile, szBuffer, charsmax(szBuffer));
			trim(szBuffer);

			if(!(szBuffer[0]) || szBuffer[0] == ';' || szBuffer[0] == '#')
			{
				continue;
			}
			
			iKey = MAIN_KEY__NONE;
			iStrLen = strlen(szBuffer);
			
			if(szBuffer[0] == '[' && szBuffer[iStrLen - 1] == ']')
			{
				iBlock = MAIN_BLOCK__NONE;
				
				copyc(szBlock, charsmax(szBlock), szBuffer[1], szBuffer[iStrLen - 1]);

				if(!(TrieGetCell(tMainsBlocks, szBlock, iBlock)))
				{
					UTIL_SetFileState("Core", "~ [WARNING] Блок ^"%s^" в файле ^"%s^" не идентифицирован.", szBlock, szFileDir);
				}
				
				continue;
			}

			switch(iBlock)
			{
				case MAIN_BLOCK__WEATHER:
				{
					strtok(szBuffer, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');

					UTIL_ConversionWord(szValue);

					if(szValue[0])
					{
						UTIL_ConversionWord(szKey);
						
						TrieGetCell(tMainsKeys, szKey, iKey);

						switch(iKey)
						{
							case MAIN_KEY__WEATHER:
							{
								g_iWeather = read_flags(szValue);

								setWeather(g_iWeather);
							}
							case MAIN_KEY__FOG:
							{
								g_bFog = bool: str_to_num(szValue);
							}
							case MAIN_KEY__FOG_COLOR:
							{
								if(g_bFog)
								{
									formatex(g_szFogColor, charsmax(g_szFogColor), szValue);
								}
							}
							case MAIN_KEY__FOG_DENSITY:
							{
								if(g_bFog)
								{
									formatex(g_szFogDensity, charsmax(g_szFogDensity), szValue);
								}
							}
							default:
							{
								UTIL_SetFileState("Core", "~ [WARNING] Ключ ^"%s^" из блока ^"%s^" не идентифицирован.", szKey, szBlock);
							}
						}
					}
				}
				case MAIN_BLOCK__NIGHT_VISION:
				{
					strtok(szBuffer, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');

					UTIL_ConversionWord(szValue);

					if(szValue[0])
					{
						UTIL_ConversionWord(szKey);
						
						TrieGetCell(tMainsKeys, szKey, iKey);
						
						switch(iKey)
						{
							case MAIN_KEY__ZOMBIE_USE_NVG:
							{
								g_bZombieUseNvg = bool: str_to_num(szValue);
							}
							case MAIN_KEY__ZOMBIE_STATE_NVG:
							{
								if(g_bZombieUseNvg)
								{
									g_bZombieStateNvg = bool: str_to_num(szValue);
								}
							}
							case MAIN_KEY__NVG_ALPHA:
							{
								if(g_bZombieUseNvg)
								{
									g_iNvgAlpha = str_to_num(szValue);
								}
							}
							case MAIN_KEY__NVG_COLOR:
							{
								if(g_bZombieUseNvg)
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
							default:
							{
								UTIL_SetFileState("Core", "~ [WARNING] Ключ ^"%s^" из блока ^"%s^" не идентифицирован.", szKey, szBlock);
							}
						}
					}
				}
				case MAIN_BLOCK__EQUIPMENT_PRIMARY:
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
				case MAIN_BLOCK__EQUIPMENT_SECONDARY:
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
				case MAIN_BLOCK__EQUIPMENT_GRENADES:
				{
					UTIL_ConversionWord(szBuffer);

					formatex(
						g_listGrenades[g_iGrenades],
						charsmax(g_listGrenades[]),
						szBuffer
					);

					g_iGrenades++;
				}
			}
		}
		
		fclose(iFile);
		
		TrieDestroy(tMainsKeys);
		TrieDestroy(tMainsBlocks);
		
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
			UTIL_SetFileState("Core", "~ [ERROR] Конфигурационный файл ^"%s^" не найден.", szFileDir);
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
		new iStrLen, iKey, iBlock, iSize, iCount;

		new szBuffer[64], szBlock[32], szKey[8], szValue[64], szPrecache[64];

		#define SOUND_BLOCK__NONE                    0
		#define SOUND_BLOCK__SURVIRVOR_WIN           1
		#define SOUND_BLOCK__ZOMBIE_WIN              2
		#define SOUND_BLOCK__ZOMBIE_DEATH            3
		#define SOUND_BLOCK__ZOMBIE_SCREAM           4
		#define SOUND_BLOCK__ZOMBIE_KNIFE            5
		
		new Trie: tSoundsBlocks = TrieCreate();
		
		new const szSoundsBlock[][] = {
			"survirvor_win",
			"zombie_win",
			"zombie_death",
			"zombie_scream",
			"zombie_knife"
		};
		
		for(iCount = 0, iSize = sizeof(szSoundsBlock); iCount < iSize; iCount++)
		{
			TrieSetCell(tSoundsBlocks, szSoundsBlock[iCount], iCount + 1);
		}

		new Trie: tSoundsKeys = TrieCreate();

		new const szOldSounds[][] = {
			"weapons/knife_hit1.wav",
			"weapons/knife_hit2.wav",
			"weapons/knife_hit3.wav",
			"weapons/knife_hit4.wav", 
			"weapons/knife_stab.wav",
			"weapons/knife_slash1.wav",
			"weapons/knife_slash2.wav",
			"weapons/knife_deploy1.wav",
			"weapons/knife_hitwall1.wav"
		};
		
		new const szSoundsKeys[][] = {
			"hit1",
			"hit2",
			"hit3",
			"hit4",
			"stab",
			"slash1",
			"slash2",
			"deploy",
			"hitwall"
		};
		
		g_tSoundsZombieKnife = TrieCreate();
		
		for(iCount = 0, iSize = sizeof(szSoundsKeys); iCount < iSize; iCount++)
		{
			TrieSetCell(tSoundsKeys, szSoundsKeys[iCount], iCount);
		}

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
				iBlock = SOUND_BLOCK__NONE;
				
				copyc(szBlock, charsmax(szBlock), szBuffer[1], szBuffer[iStrLen - 1]);
				
				if(!(TrieGetCell(tSoundsBlocks, szBlock, iBlock)))
				{
					UTIL_SetFileState("Core", "~ [WARNING] Блок ^"%s^" в файле ^"%s^" не идентифицирован.", szBlock, szFileDir);
				}
				
				continue;
			}
	
			switch(iBlock)
			{
				case SOUND_BLOCK__SURVIRVOR_WIN:
				{
					if(g_aSoundsSurvirvorWin || (g_aSoundsSurvirvorWin = ArrayCreate(64)))
					{
						UTIL_ConversionWord(szBuffer);

						formatex(szPrecache, charsmax(szPrecache), "sound/%s", szBuffer);
						
						switch(file_exists(szPrecache))
						{
							case false:
							{
								UTIL_SetFileState("Core", "~ [WARNING] Звуковой файл ^"%s^" не найден.", szPrecache);
							}
							case true:
							{
								precache_sound(szBuffer);
						
								ArrayPushString(g_aSoundsSurvirvorWin, szBuffer);
							}
						}
					}
				}
				case SOUND_BLOCK__ZOMBIE_WIN:
				{
					if(g_aSoundsZombieWin || (g_aSoundsZombieWin = ArrayCreate(64)))
					{
						UTIL_ConversionWord(szBuffer);

						formatex(szPrecache, charsmax(szPrecache), "sound/%s", szBuffer);
						
						switch(file_exists(szPrecache))
						{
							case false:
							{
								UTIL_SetFileState("Core", "~ [WARNING] Звуковой файл ^"%s^" не найден.", szPrecache);
							}
							case true:
							{
								precache_sound(szBuffer);
								
								ArrayPushString(g_aSoundsZombieWin, szBuffer);
							}
						}
					}
				}
				case SOUND_BLOCK__ZOMBIE_DEATH:
				{
					if(g_aSoundsZombieDie || (g_aSoundsZombieDie = ArrayCreate(64)))
					{
						UTIL_ConversionWord(szBuffer);

						formatex(szPrecache, charsmax(szPrecache), "sound/%s", szBuffer);
						
						switch(file_exists(szPrecache))
						{
							case false:
							{
								UTIL_SetFileState("Core", "~ [WARNING] Звуковой файл ^"%s^" не найден.", szPrecache);
							}
							case true:
							{
								precache_sound(szBuffer);

								ArrayPushString(g_aSoundsZombieDie, szBuffer);
							}
						}
					}
				}
				case SOUND_BLOCK__ZOMBIE_SCREAM:
				{
					if(g_aSoundsZombieScream || (g_aSoundsZombieScream = ArrayCreate(64)))
					{
						UTIL_ConversionWord(szBuffer);

						formatex(szPrecache, charsmax(szPrecache), "sound/%s", szBuffer);
						
						switch(file_exists(szPrecache))
						{
							case false:
							{
								UTIL_SetFileState("Core", "~ [WARNING] Звуковой файл ^"%s^" не найден.", szPrecache);
							}
							case true:
							{
								precache_sound(szBuffer);

								ArrayPushString(g_aSoundsZombieScream, szBuffer);
							}
						}
					}
				}
				case SOUND_BLOCK__ZOMBIE_KNIFE:
				{
					strtok(szBuffer, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');

					UTIL_ConversionWord(szValue);

					if(szValue[0])
					{
						UTIL_ConversionWord(szKey);
						
						if(TrieGetCell(tSoundsKeys, szKey, iKey))
						{
							formatex(szPrecache, charsmax(szPrecache), "sound/%s", szValue);
							
							switch(file_exists(szPrecache))
							{
								case false:
								{
									UTIL_SetFileState("Core", "~ [WARNING] Звуковой файл ^"%s^" не найден.", szPrecache);
								}
								case true:
								{
									precache_sound(szValue);
									
									TrieSetString(g_tSoundsZombieKnife, szOldSounds[iKey], szValue);
								}
							}
						}
						else
						{
							UTIL_SetFileState("Core", "~ [WARNING] Ключ ^"%s^" из блока ^"%s^" не идентифицирован.", szKey, szBlock);
						}
					}
				}
			}
		}
		
		fclose(iFile);
		
		TrieDestroy(tSoundsKeys);
		TrieDestroy(tSoundsBlocks);
		
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
			pause("d");
			
			UTIL_SetFileState("Core", "~ [ERROR] Конфигурационный файл ^"%s^" не найден. Плагин остановил свою работу.", szFileDir);
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
		new infoZombieClass[infoClass];
		
		new iStrLen, iKey;
		new szBuffer[128], szBlock[64], szKey[32], szValue[64], szPrecache[64];

		#define CLASS_KEY__NONE                      0
		#define CLASS_KEY__KNIFE_MODEL               1
		#define CLASS_KEY__PLAYER_MODEL              2
		#define CLASS_KEY__ACCESS                    3
		#define CLASS_KEY__SPEED                     4
		#define CLASS_KEY__HEALTH                    5
		#define CLASS_KEY__GRAVITY                   6
		#define CLASS_KEY__FOOTSTEPS                 7
		#define CLASS_KEY__KNOCKBACK                 8
		#define CLASS_KEY__FACTOR_DAMAGE             9
		#define CLASS_KEY__HP_REGENERATION_          10
		#define CLASS_KEY__HP_REGENERATION_MIN       11

		new Trie: tClassesKeys = TrieCreate();
		
		new const szClassesKeys[][] = {
			"knife_model",
			"player_model",
			"access",
			"speed",
			"health",
			"gravity",
			"footsteps",
			"knockback",
			"factor_damage",
			"regeneration_hp",
			"regeneration_hp_min"
		};
		
		for(new iCount = 0, iSize = sizeof(szClassesKeys); iCount < iSize; iCount++)
		{
			TrieSetCell(tClassesKeys, szClassesKeys[iCount], iCount + 1);
		}
		
		while(!(feof(iFile)))
		{
			fgets(iFile, szBuffer, charsmax(szBuffer));
			trim(szBuffer);

			if(!(szBuffer[0]) || szBuffer[0] == ';' || szBuffer[0] == '#')
			{
				continue;
			}
			
			iKey = CLASS_KEY__NONE;
			iStrLen = strlen(szBuffer);

			if(szBuffer[0] == '[' && szBuffer[iStrLen - 1] == ']')
			{
				copyc(szBlock, charsmax(szBlock), szBuffer[1], szBuffer[iStrLen - 1]);

				if(equali(szBlock, "end", 3) || equali(szBlock, "конец", 5))
				{
					if(infoZombieClass[CLASS_NAME][0])
					{
						addZombieClass(
							infoZombieClass[CLASS_NAME],
							infoZombieClass[CLASS_KNIFE_MODEL],
							infoZombieClass[CLASS_PLAYER_MODEL],
							infoZombieClass[CLASS_ACCESS],
							infoZombieClass[CLASS_SPEED],
							infoZombieClass[CLASS_HEALTH],
							infoZombieClass[CLASS_GRAVITY],
							infoZombieClass[CLASS_FOOTSTEPS],
							infoZombieClass[CLASS_KNOCKBACK],
							infoZombieClass[CLASS_FACTOR_DAMAGE],
							infoZombieClass[CLASS_HP_REGENERATION],
							infoZombieClass[CLASS_HP_REGENERATION_MIN]
						);
					}
					
					arrayset(infoZombieClass, 0, sizeof(infoZombieClass));
				}
				else
				{
					trim(szBlock);
					
					infoZombieClass[CLASS_NAME] = szBlock;
				}
				
				continue;
			}

			if(infoZombieClass[CLASS_NAME][0])
			{
				strtok(szBuffer, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');

				UTIL_ConversionWord(szValue);
				
				if(szValue[0])
				{
					UTIL_ConversionWord(szKey);
					
					TrieGetCell(tClassesKeys, szKey, iKey);
					
					switch(iKey)
					{
						case CLASS_KEY__KNIFE_MODEL:
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
						}
						case CLASS_KEY__PLAYER_MODEL:
						{
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
						case CLASS_KEY__ACCESS:
						{
							infoZombieClass[CLASS_ACCESS] = read_flags(szValue);
						}
						case CLASS_KEY__SPEED:
						{
							infoZombieClass[CLASS_SPEED] = _: str_to_float(szValue);
						}
						case CLASS_KEY__HEALTH:
						{
							infoZombieClass[CLASS_HEALTH] = _: str_to_float(szValue);
						}
						case CLASS_KEY__GRAVITY:
						{
							infoZombieClass[CLASS_GRAVITY] = _: str_to_float(szValue);
						}
						case CLASS_KEY__FOOTSTEPS:
						{
							infoZombieClass[CLASS_FOOTSTEPS] = bool: str_to_num(szValue);
						}
						case CLASS_KEY__KNOCKBACK:
						{
							infoZombieClass[CLASS_KNOCKBACK] = _: str_to_float(szValue);
						}
						case CLASS_KEY__FACTOR_DAMAGE:
						{
							infoZombieClass[CLASS_FACTOR_DAMAGE] = _: str_to_float(szValue);
						}
						case CLASS_KEY__HP_REGENERATION_:
						{
							infoZombieClass[CLASS_HP_REGENERATION] = _: str_to_float(szValue);
						}
						case CLASS_KEY__HP_REGENERATION_MIN:
						{
							infoZombieClass[CLASS_HP_REGENERATION_MIN] = _: str_to_float(szValue);
						}
						default:
						{
							UTIL_SetFileState("Core", "~ [WARNING] Ключ ^"%s^" из блока ^"%s^" не идентифицирован.", szKey, szBlock);
						}
					}
				}
			}
		}

		fclose(iFile);
		
		TrieDestroy(tClassesKeys);
		
		if(g_iZombieClasses == 0)
		{
			pause("d");
			
			UTIL_SetFileState("Core", "~ [INFO] Файл классов ^"%s^" пуст. Плагин остановил свою работу.", szFileDir);
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
		iCvarId_TimeRestartGame,
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
	iCvarId_TimeRestartGame         = register_cvar("zmb_time_restart_game",            "15");
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

	g_iCvar_HudType                 = get_pcvar_num(iCvarId_HudType);
	g_iCvar_HudColor                = UTIL_ParseHEXColor(szColor);
	g_iCvar_TimeRestartGame         = get_pcvar_num(iCvarId_TimeRestartGame);
	
	g_bCvar_SaveEquipment           = bool: get_pcvar_num(iCvarId_SaveEquipment);
	g_bCvar_BlockZombieFlashlight   = bool: get_pcvar_num(iCvarId_BlockZombieFlashlight);
	g_bCvar_StateKnockbackSitZombie = bool: get_pcvar_num(iCvarId_StateKnockbackSitZombie);
	
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

	if(g_bCvar_SaveEquipment)
	{
		g_tEquipment = TrieCreate();
	}
	
	if(g_bCvar_BlockZombieFlashlight)
	{
		RegisterHookChain(RG_CBasePlayer_ImpulseCommands, "HC_Impulse_Flashlight", false);
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
	gp_iFlags[iIndex] = get_user_flags(iIndex);
	gp_iSelectedClass[iIndex] = CLASS_NONE;
	
	if(g_bCvar_SaveEquipment)
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
		remove_task(TASK_ID_ZOMBIE_HP_REGENERATION + iIndex);

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
	else if(IsSetBit(gp_iBit[BIT_HUMAN], iIndex))
	{
		g_iAliveHumans--;
	}

	for(new iCount = BIT_NONE; iCount < BIT_MAX; iCount++)
	{
		ClearBit(gp_iBit[iCount], iIndex);
	}

	switch(g_bCvar_SaveEquipment)
	{
		case false:
		{
			gp_iEquipment[iIndex][PLAYER_EQUIPMENT_PRIMARY] = 0;
			gp_iEquipment[iIndex][PLAYER_EQUIPMENT_SECONDARY] = 0;
		}
		case true:
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
	g_bRestartGame = true;
	
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
	
	if(g_bRestartGame)
	{
		if(task_exists(TASK_ID_RESTART_GAME))
		{
			return PLUGIN_HANDLED;
		}
		
		if(g_iCvar_TimeRestartGame <= 0)
		{
			g_bRestartGame = false;
		}
		else
		{
			set_task(1.0, "taskRestartGame", TASK_ID_RESTART_GAME, .flags = "a", .repeat = (g_iTimeRestartGame = g_iCvar_TimeRestartGame));
		}
	}

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
			remove_task(TASK_ID_ZOMBIE_HP_REGENERATION + iIndex);

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
	
	return PLUGIN_CONTINUE;
}

public LogEventHook_RoundStart()	{
	if(g_bRestartGame)
	{
		return PLUGIN_HANDLED;
	}
	
	if(!(g_bRoundEnd) && !(g_bInfectionBegan))
	{
		set_task(g_fCvar_TimeInfections, "taskInfect", TASK_ID_INFECT);
	}
	
	return PLUGIN_CONTINUE;
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
	new szArg[16], szMsg[64];
	get_msg_arg_string(2, szArg, charsmax(szArg));

	static Trie: tTextMsg;
	
	if(tTextMsg == Invalid_Trie)
	{
		#define MAX_TEXT_MSG    5
		
		enum eTextMsg
		{
			TEXT_MSG_KEY,
			TEXT_MSG_VALUE
		};
		
		new const szTextMsg[MAX_TEXT_MSG][eTextMsg][] =
		{
			{"#CTs_Win", "ZMB__TEXT_MSG_CT_WIN"},
			{"#Round_Draw", "ZMB__TEXT_MSG_ROUND_DRAW"},
			{"#Target_Saved", "ZMB__TEXT_MSG_ROUND_DRAW"},
			{"Round is Over!", "ZMB__TEXT_MSG_ROUND_DRAW"},
			{"#Terrorists_Win", "ZMB__TEXT_MSG_TERRORIST_WIN"}
		}; 
		
		tTextMsg = TrieCreate();

		for(new iCount = 0; iCount < MAX_TEXT_MSG; iCount++)
		{
			formatex(szMsg, charsmax(szMsg), "%L", LANG_SERVER, szTextMsg[iCount][TEXT_MSG_VALUE]);

			TrieSetString(tTextMsg, szTextMsg[iCount][TEXT_MSG_KEY], szMsg);
		}
	}
	
	if(TrieGetString(tTextMsg, szArg, szMsg, charsmax(szMsg)))
	{
		set_msg_arg_string(2, szMsg);
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
	RegisterHookChain(RG_CBasePlayer_TakeDamage,  "HC_CBasePlayer_TakeDamage_Post", true);
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
		remove_task(TASK_ID_ZOMBIE_HP_REGENERATION + iVictim);
		
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

public HC_CBasePlayer_TakeDamage_Post(const iVictim)	{
	if(IsSetBit(gp_iBit[BIT_INFECT], iVictim))
	{
		if(g_infoZombieClass[gp_iClass[iVictim]][CLASS_HP_REGENERATION] && g_infoZombieClass[gp_iClass[iVictim]][CLASS_HP_REGENERATION_MIN])
		{
			if(!(task_exists(TASK_ID_ZOMBIE_HP_REGENERATION + iVictim)))
			{
				static Float: fHealth; fHealth = get_entvar(iVictim, var_health);

				if(fHealth > 0.0 && fHealth < g_infoZombieClass[gp_iClass[iVictim]][CLASS_HP_REGENERATION_MIN])
				{
					set_task(1.0, "taskZombieHealthRegeneration", iVictim + TASK_ID_ZOMBIE_HP_REGENERATION, .flags = "b");
				}
			}
		}
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
			if(g_infoZombieClass[gp_iClass[iAttacker]][CLASS_FACTOR_DAMAGE])
			{
				fDamage *= g_infoZombieClass[gp_iClass[iAttacker]][CLASS_FACTOR_DAMAGE];
			}
			
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
		if(g_bCvar_StateKnockbackSitZombie)
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

		static Float: fFactorDirection = 0.0;

		fFactorDirection = getPlayerActiveWeaponKnockback(iAttacker);

		if(fFactorDirection)
		{
			UTIL_VecMulScalar(fDirection, fDamage, fDirection);
			UTIL_VecMulScalar(fDirection, fFactorDirection, fDirection);
			
			if(g_infoZombieClass[gp_iClass[iVictim]][CLASS_KNOCKBACK])
			{
				UTIL_VecMulScalar(fDirection, g_infoZombieClass[gp_iClass[iVictim]][CLASS_KNOCKBACK], fDirection);
			}

			UTIL_VecAdd(fDirection, fVelocity, fVelocity);

			fDirection[2] = fVelocityZ;
			
			set_entvar(iVictim, var_velocity, fVelocity);
		}
	}
	
	return HC_CONTINUE;
}

public HC_Impulse_Flashlight(const iIndex)	{
	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		if(get_entvar(iIndex, var_impulse) == 100)
		{
			set_entvar(iIndex, var_impulse, 0);
			
			return HC_SUPERCEDE;
		}
	}

	return HC_CONTINUE;
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
	
	static szBuyZoneClassName[20];
	get_entvar(iEntity, var_classname, szBuyZoneClassName, charsmax(szBuyZoneClassName));
	
	if(TrieKeyExists(g_tRemoveEntities, szBuyZoneClassName))
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

			if(szSample[8] == 'k' && szSample[9] == 'n' && szSample[10] == 'i')
			{
				if(TrieGetString(g_tSoundsZombieKnife, szSample, szSound, charsmax(szSound)) && szSound[0])
				{
					emit_sound(iIndex, iChannel, szSound, fVolume, fAttn, iFlag, iPitch);
					
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
			set_entvar(iIndex, var_viewmodel, g_infoZombieClass[gp_iClass[iIndex]][CLASS_KNIFE_MODEL]);
			set_entvar(iIndex, var_weaponmodel, "");
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
	return (IsPlayer(iIndex) && IsSetBit(gp_iBit[BIT_INFECT], iIndex)) ? HAM_SUPERCEDE : HAM_IGNORED;
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
	return (IsSetBit(gp_iBit[BIT_INFECT], iIndex) && WeaponIdType: get_user_weapon(iIndex) == WEAPON_KNIFE) ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
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
			
			/*
				TEMP:
					Временный фикс.
			*/
			HC_CBasePlayer_Killed_Post(iIndex, 0);
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
			if(gp_iSelectedClass[iIndex] == iCount)
			{
				iBitKeys |= (1 << iItem);
				
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \d%s \r[ \yON SPAWN \r]^n", ++iItem, g_infoZombieClass[iCount][CLASS_NAME]);
			}
			else
			{
				if(gp_iFlags[iIndex] & g_infoZombieClass[iCount][CLASS_ACCESS])
				{
					iBitKeys |= (1 << iItem);
					
					iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s^n", ++iItem, g_infoZombieClass[iCount][CLASS_NAME]);
				}
				else
				{
					iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \d%s \r[ \yNO ACCESS \r]^n", ++iItem, g_infoZombieClass[iCount][CLASS_NAME]);
				}
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
				gp_iSelectedClass[iIndex] = (gp_iSelectedClass[iIndex] == iClass) ? CLASS_NONE : iClass;

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
			
			if(IsSetBit(gp_iBit[BIT_HUMAN], iInfected))
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

public taskRestartGame()	{
	if(--g_iTimeRestartGame == 0)
	{
		server_cmd("sv_restart 1");
		
		g_bRestartGame = false;
	}
	else
	{
		switch(g_iCvar_HudType)
		{
			case 0:	/* [HUD] */
			{
				set_hudmessage(g_iCvar_HudColor[COLOR_RED], g_iCvar_HudColor[COLOR_GREEN], g_iCvar_HudColor[COLOR_BLUE], g_fCvar_HudPosition[POS_X], g_fCvar_HudPosition[POS_Y], 0, 0.0, 0.9, 0.15, 0.15, -1);
				ShowSyncHudMsg(0, g_iSyncPlayerHud, "Рестарт игры через [%d]", g_iTimeRestartGame);
			}
			case 1:	/* [DHUD] */
			{
				set_dhudmessage(g_iCvar_HudColor[COLOR_RED], g_iCvar_HudColor[COLOR_GREEN], g_iCvar_HudColor[COLOR_BLUE], g_fCvar_HudPosition[POS_X], g_fCvar_HudPosition[POS_Y], 0, 0.0, 0.9, 0.15, 0.15);
				show_dhudmessage(0, "Рестарт игры через [%d]", g_iTimeRestartGame);
			}
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

public taskZombieHealthRegeneration(iIndex)	{
	iIndex -= TASK_ID_ZOMBIE_HP_REGENERATION;
	
	static Float: fHealth; fHealth = get_entvar(iIndex, var_health);
	
	if(fHealth < g_infoZombieClass[gp_iClass[iIndex]][CLASS_HEALTH])
	{
		fHealth += g_infoZombieClass[gp_iClass[iIndex]][CLASS_HP_REGENERATION];

		set_entvar(iIndex, var_health, (fHealth > g_infoZombieClass[gp_iClass[iIndex]][CLASS_HEALTH]) ? g_infoZombieClass[gp_iClass[iIndex]][CLASS_HEALTH] : fHealth);
	}
}

/*================================================================================
 [ZMB]
=================================================================================*/
stock setWeather(const iWeather)	{
	if(iWeather)
	{
		g_iActiveWeather = (g_iWeather == 3) ? random_num(1, 2) : g_iWeather;
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
		.iHideHud = (g_bCvar_BlockZombieFlashlight ? HIDEHUD_FLASHLIGHT : (1 << 0)) | HIDEHUD_HEALTH
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
	
	if(g_infoZombieClass[iClass][CLASS_FOOTSTEPS])
	{
		rg_set_user_footsteps(iIndex, true);
	}

	rg_set_user_team(iIndex, TEAM_TERRORIST);

	ExecuteHamB(Ham_Item_PreFrame, iIndex);

 	rg_remove_items_by_slot(iIndex, PRIMARY_WEAPON_SLOT);
	rg_remove_items_by_slot(iIndex, PISTOL_SLOT);
	rg_remove_items_by_slot(iIndex, GRENADE_SLOT);

	new iItem = rg_find_weapon_bpack_by_name(iIndex, "weapon_knife");
	
	if(iItem)
	{
		iItem != get_member(iIndex, m_pActiveItem) ? rg_switch_weapon(iIndex, iItem) : ExecuteHamB(Ham_Item_Deploy, iItem);
	}

	if(g_bZombieUseNvg)
	{
		if(g_bZombieStateNvg)
		{
			setPlayerNightVision(iIndex, true);
		}
	}
	
	if(g_bCvar_BlockZombieFlashlight)
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

stock Float: getPlayerActiveWeaponKnockback(const iIndex)	{
 	static WeaponIdType: iWeaponId; new iCount;
	
	iWeaponId = WeaponIdType: get_user_weapon(iIndex); 
	
	for(iCount = 0; iCount < g_iPrimaryWeapons; iCount++)
	{
		if(iWeaponId == g_listPrimaryWeapons[iCount][WEAPON_ID])
		{
			return g_listPrimaryWeapons[iCount][WEAPON_KNOCKBACK];
		}
	}
	
	for(iCount = 0; iCount < g_iSecondaryWeapons; iCount++)
	{
		if(iWeaponId == g_listSecondaryWeapons[iCount][WEAPON_ID])
		{
			return g_listSecondaryWeapons[iCount][WEAPON_KNOCKBACK];
		}
	}
	
	return 0.0;
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

stock addZombieClass(const szName[], const szKnifeModel[], const szPlayerModel[], const iAccessFlags, const Float: fSpeed, const Float: fHealth, const Float: fGravity, const bool: bFootSteps, const Float: fKnockback, const Float: fFactorDamage, const Float: fHealthRegeneration, const Float: fHealthRegenerationMin)	{
	new iClass = g_iZombieClasses += 1;

	copy(g_infoZombieClass[iClass][CLASS_NAME], 64, szName);
	copy(g_infoZombieClass[iClass][CLASS_KNIFE_MODEL], 64, szKnifeModel);
	copy(g_infoZombieClass[iClass][CLASS_PLAYER_MODEL], 64, szPlayerModel);
	
	g_infoZombieClass[iClass][CLASS_ACCESS] = iAccessFlags;
	g_infoZombieClass[iClass][CLASS_SPEED] = _: fSpeed;
	g_infoZombieClass[iClass][CLASS_HEALTH] = _: fHealth;
	g_infoZombieClass[iClass][CLASS_GRAVITY] = _: fGravity;
	g_infoZombieClass[iClass][CLASS_FOOTSTEPS] = bool: bFootSteps;
	g_infoZombieClass[iClass][CLASS_KNOCKBACK] = _: fKnockback;
	g_infoZombieClass[iClass][CLASS_FACTOR_DAMAGE] = _: fFactorDamage;
	g_infoZombieClass[iClass][CLASS_HP_REGENERATION] = _: fHealthRegeneration;
	g_infoZombieClass[iClass][CLASS_HP_REGENERATION_MIN] = _: fHealthRegenerationMin;
}