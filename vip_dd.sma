/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <amxmisc>
#include <cromchat>
#include <zombieplague>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN "VIP: Double Damage"
#define VERSION "1.0"
#define AUTHOR "def."

#define VIPFLAG ADMIN_LEVEL_A

// Task IDs
#define TASK_AURA 321

// Bitsums
#define HaveDD(%1) g_HaveDD & (1<<(%1 & 31))
#define SetHaveDD(%1) g_HaveDD |= (1<<(%1 & 31))
#define ClearHaveDD(%1) g_HaveDD &= ~(1<<(%1 & 31))

new cvar_duration;
new cvar_auracolor, cvar_aurasize;
new g_HudSync, g_SayText,g_HaveDD,g_maxplayers;
new Time[33];
new g_damage2[33]

new bool:cooldown = false

const CD  = 600;

public plugin_init()
{
    cvar_duration = register_cvar("zp_vip_dd_duration", "15")
    cvar_auracolor = register_cvar("zp_vip_dd_color", "2 110 252")
    cvar_aurasize = register_cvar("zp_vip_dd_aura_size", "20")
    
    CC_SetPrefix("&x04[ &x05VIP &x04]")
    register_plugin("Requiem: Double Damage", "1.0", "def.");
    RegisterHam(Ham_TakeDamage, "player", "FwdTakeDamage", 1);
    
    	// Hamsandwich forward
    RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
    
    register_event("HLTV", "event_round_start", "a", "1=0", "2=0");
    g_maxplayers = get_maxplayers();
    register_clcmd("say /dd", "requestDD");
    register_clcmd("say !dd", "requestDD");
    register_clcmd("say !doubledamage", "requestDD");
    
    // Language File
    register_dictionary("zp_vip_dd.txt")
    
    g_HudSync = CreateHudSyncObj()
    g_SayText = get_user_msgid("SayText")
}

public event_round_start()
{
    new id = 1;
    while (id <= g_maxplayers)
    {
        g_damage2[id] = false;
        id++;
    }

}

public requestDD(id)
{
    new name[100]
    get_user_name(id, name, 100)
		// Wait until the round start
		if (!zp_has_round_started())
		{
			CC_SendMessage(id, "&x04Round not started yet.");
			return PLUGIN_HANDLED;
		}
		// If the player already have dd
		if(HaveDD(id))
		{
			CC_SendMessage(id, "&x04You &x05already have double damage active.");
			return PLUGIN_HANDLED;
		}
		// If the player dont have dd
		else
		{
			// if user is not vip
			if(!(get_user_flags(id) & VIPFLAG)){
				CC_SendMessage(id, "&x04You &x05are not &x04VIP...");
				return PLUGIN_HANDLED;
			}
			// if he is vip...	
			if(cooldown == false && (get_user_flags(id) & VIPFLAG)) {
				set_task(0.1,"trigger_cd",id)
				// Give double damage
				g_damage2[id] = true;
			
				// Aura task
				set_task(0.1, "aura", id + TASK_AURA, _, _, "b")
				
				SetHaveDD(id)
				
				// Start the countdown !
				Time[id] = get_pcvar_num(cvar_duration)
				CountDown(id)
				
				client_cmd(0, "spk %s", "sound/rqsound/dd.wav");
				CC_SendMessage(0, "&x04%s &x06activated &x04double damage &x06!!", name);
			}
			if(cooldown == true) {
				CC_SendMessage(id, "&x04Double damage &x05is on cooldown (10 min cooldown).");
				return PLUGIN_HANDLED
			}
			
		}
 

}
public trigger_cd(id){
    cooldown = true
    new cooling = CD;
    // bad coding but idk...
    set_task(cooling * 1.0, "unlock_dd", id)
}

public unlock_dd(id){
    new name[100]
    get_user_name(id, name, 100)
    cooldown = false
    CC_SendMessage(id, "&x04%s, &x06double damage &x06is available again!!", name);
}

public FwdTakeDamage(victim, inflictor, attacker, Float:damage, damage_bits)
{
    if (g_damage2[attacker])
    {
        SetHamParamFloat(4, damage * 2.00);
        return HAM_HANDLED
    }
    return HAM_HANDLED
}

// Countdown code
public CountDown(id)
{
	new name[100]
         get_user_name(id, name, 100)
	// If time is 0 or -1
	if(Time[id] <= 0)
	{		
		// Remove aura task
		remove_task(id + TASK_AURA)
		
		// Client_Print
		CC_SendMessage(0, "&x04%s &x06double damage &x04expired &x06!!", name);

		// Remove dd
		ClearHaveDD(id)
		
		// Remove countdown
		return
	}
	
	// Time - 1
	Time[id]--
	
	// Show the dd seconds
	set_hudmessage(85, 127, 255, -1.0, 0.15, 1, 0.1, 3.0, 0.05, 0.05, -1)
	ShowSyncHudMsg(id, g_HudSync, "%L", id, "REMAINING", Time[id])
	
	// Repeat
	set_task(1.0, "CountDown", id)
}



// If user is infected (Infection nade)
public zp_user_infected_post(id)
{
	if(HaveDD(id))
	{
		// Remove countdown task
		Time[id] = 0
		
		// Remove aura task
		remove_task(id + TASK_AURA)
		
		// Remove dd
		ClearHaveDD(id)

	}
}


// At player spawn
public fw_PlayerSpawn_Post(id)
{
	if(HaveDD(id))
	{
		// Remove countdown task
		Time[id] = 0

		
		// Show message
		CC_SendMessage(id, "&x04Double damage &x06is now over!.");
		
		// Remove aura task
		remove_task(id + TASK_AURA)
		
		// Remove DD
		ClearHaveDD(id)
	}
}



/*============
Aura Code
============*/

public aura(id)
{
	id -= TASK_AURA
	
	
	// If user die 
	if (!is_user_alive(id))
		return
	
	// Color cvar ---> RGB!
	new szColors[16]
	get_pcvar_string(cvar_auracolor, szColors, 15)
	
	new gRed[4], gGreen[4], gBlue[4], iRed, iGreen, iBlue
	parse(szColors, gRed, 3, gGreen, 3, gBlue, 3)
	
	iRed = clamp(str_to_num(gRed), 0, 255)
	iGreen = clamp(str_to_num(gGreen), 0, 255)
	iBlue = clamp(str_to_num(gBlue), 0, 255)
	
	new Origin[3]
	get_user_origin(id, Origin)
	
	message_begin(MSG_ALL, SVC_TEMPENTITY)
	write_byte(TE_DLIGHT)
	write_coord(Origin[0])
	write_coord(Origin[1])
	write_coord(Origin[2])
	write_byte(get_pcvar_num(cvar_aurasize))
	write_byte(iRed) //   R
	write_byte(iGreen) // G
	write_byte(iBlue) //  B
	write_byte(2)
	write_byte(0)
	message_end()
}

