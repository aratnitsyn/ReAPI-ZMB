#include <amxmodx>
#include <zmb>

#pragma semicolon       1

#define PLUGIN_NAME     "[ZMB] Score Hud"
#define PLUGIN_VERS     "0.0.1"
#define PLUGIN_AUTH     "81x08"

enum (+= 35)	{
	TASK_ID_SCORE
};

/*================================================================================
 [PLUGIN]
=================================================================================*/
public plugin_init()	{
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	register_dictionary("zmb_score_hud.txt");
}

/*================================================================================
 [CLIENT]
=================================================================================*/
public client_putinserver(iIndex)	{
	if(is_user_bot(iIndex) || is_user_alive(iIndex))
	{
		return PLUGIN_HANDLED;
	}
	
	set_task(1.0, "taskScore", TASK_ID_SCORE + iIndex, .flags = "b");
	
	return PLUGIN_CONTINUE;
}

public client_dissconnect(iIndex)	{
	remove_task(TASK_ID_SCORE + iIndex);
}

/*================================================================================
 [TASK]
=================================================================================*/
public taskScore(iIndex)	{
	iIndex -= TASK_ID_SCORE;
	
	set_hudmessage(255, 25, 0, -1.0, 0.02, 0, 0.0, 0.9, 0.15, 0.15, -1);
	show_hudmessage(0, "[%L] VS [%L]^n[%d] -- [%d]", LANG_SERVER, "ZMB__ZOMBIES", LANG_SERVER, "ZMB__HUMANS", get_alive_zombies(), get_alive_humans());
}