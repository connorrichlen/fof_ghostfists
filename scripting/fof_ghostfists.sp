#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>

#define PLUGIN_VERSION "1.0.12"
#define CHAT_PREFIX "{skyblue}[Ghost Fists] "
#define CONSOLE_PREFIX "[Fists] "


#define SOUND_SCARY       "npc/ghost/alert.wav"

#define HUD_X 0.14 //Fists
#define HUD_Y 0.99

new Handle: fof_ghostfists_price = INVALID_HANDLE;
new Handle: sm_fof_ghostfists_version = INVALID_HANDLE;
new Handle: fof_ghostfists = INVALID_HANDLE;
new Handle: hHUDSyncMsg = INVALID_HANDLE;
new bool: bAllowFistsFists = false;
new Float: flFistsPrice = 1.0;
new Float: flCashCurrent = 0.0;
new String: szClientName[MAX_NAME_LENGTH];
new String: szAttacker[MAX_NAME_LENGTH];

enum ClientData
{
	UserId,
	bool:hasFists
};

new g_Clients[MAXPLAYERS + 1][ClientData];

public Plugin: myinfo = {
    name = "[FOF] Buy Ghost Fists Addon",
    author = "Skooma",
    description = "[FOF] Buy Ghost Fists Addon",
    version = PLUGIN_VERSION,
    url = "https://connorrichlen.me"
};


public OnMapStart() {
    PrecacheModel("models/npc/ghost.mdl");
    PrecacheSound(SOUND_SCARY, true);
    CreateTimer(1.0, Timer_UpdateHUD, .flags = TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public OnPluginStart() {        
    sm_fof_ghostfists_version = CreateConVar("sm_fof_ghostfists_version", PLUGIN_VERSION, "[FOF] Buy Ghost Fists Addon Version", FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_SPONLY | FCVAR_DONTRECORD);
    SetConVarString(sm_fof_ghostfists_version, PLUGIN_VERSION);
    HookConVarChange(sm_fof_ghostfists_version, OnVerConVarChanged);
    HookConVarChange(fof_ghostfists_price = CreateConVar("fof_ghostfists_price", "20.0", "Sets the purchase price for the Ghost Fists.", FCVAR_NOTIFY), OnConVarChanged);
    HookConVarChange(fof_ghostfists = CreateConVar("fof_ghostfists", "1", "Allow (1) or disallow the Ghost Fists.", FCVAR_NOTIFY, true, 0.0, true, 1.0), OnConVarChanged);

    RegConsoleCmd("sm_fists", Command_GhostFists);
    hHUDSyncMsg = CreateHudSynchronizer();

    // Load the clients in g_Clients.
    for (new i = 1; i < MaxClients; ++i)
    {
        if (IsClientInGame(i)) {
            new userid = GetClientUserId(i);
            NewClient(userid, i);
        }
    }
    HookEvent("player_activate", Event_PlayerActivate);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_disconnect", Event_PlayerDisconnect);
    HookEvent("game_newmap", Event_NewMap);
	
}

public OnConfigsExecuted() {
    ScanAllConVars();
}
stock ScanAllConVars() {
    flFistsPrice = GetConVarFloat(fof_ghostfists_price);
    bAllowFistsFists = GetConVarBool(fof_ghostfists);
}

NewClient(userid, client = -1)
{
    if (client == -1)
        client = GetClientOfUserId(userid);
    
    if (g_Clients[client][(ClientData:UserId)] != userid)
    {
        g_Clients[client][(ClientData:UserId)] = userid;
        g_Clients[client][(ClientData:hasFists)] = false;
    }
}

public OnVerConVarChanged(Handle: hConVar, const String: szOldValue[], const String: szNewValue[]){
    if (strcmp(szNewValue, PLUGIN_VERSION, false))
        SetConVarString(hConVar, PLUGIN_VERSION, true, true);
}

public Action: Timer_UpdateHUD(Handle: hTimer, any: iUnused) {
    for (new i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i)) {
            ClearSyncHud(i, hHUDSyncMsg);
            SetHudTextParams(HUD_X, HUD_Y, 1.125, 255, 130, 0, 9, 0, 0.0, 0.0, 0.0);
            
            if ((GetUserFlagBits(i) & ADMFLAG_CUSTOM5) || (GetUserFlagBits(i) & ADMFLAG_ROOT))
            {
                _ShowFistsHudText(i, hHUDSyncMsg, "Type !fists to buy Ghost Fists for $%.0f!", (flFistsPrice * 0.5));
            }
            else {
                _ShowFistsHudText(i, hHUDSyncMsg, "Type !fists to buy Ghost Fists for $%.0f!", flFistsPrice);
            }
        }
}

public OnConVarChanged(Handle: hConVar, const String: szOldValue[], const String: szNewValue[]){
    ScanAllConVars();
}
public OnClientDisconnect_Post(client) {
    g_Clients[client][(ClientData:hasFists)] = false;
}

public Event_PlayerActivate(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    int userid = GetEventInt(hEvent, "userid");
    int client = GetClientOfUserId(userid);
    g_Clients[client][(ClientData:hasFists)] = false;
    NewClient(userid);
}

public Event_PlayerDisconnect(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	int userid = GetEventInt(hEvent, "userid");
	int client = GetClientOfUserId(userid);
	g_Clients[client][(ClientData:UserId)] = -1;
}

public Event_PlayerDeath(Handle: hEvent, const String: szEventName[], bool: bDontBroadcast) {	
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
    new String:fistswep[32];

    g_Clients[client][(ClientData:hasFists)] = false;

    GetEventString(hEvent, "weapon", fistswep, sizeof(fistswep));

    GetClientName(client, szClientName, sizeof(szClientName));
    GetClientName(attacker, szAttacker, sizeof(szAttacker));
    
    if (StrEqual(fistswep, "fists_ghost"))
    {
        EmitSoundToAll(SOUND_SCARY);
        PrintCenterTextAll("%s got killed by %s with the Ghost Fists!", szClientName, szAttacker);
    }
}

public Event_NewMap(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	for (new i = 0; i < MaxClients; ++i)
	{
		g_Clients[i][(ClientData:hasFists)] = false;
	}
}
stock _ShowFistsHudText(iClient, Handle: hHudSynchronizer = INVALID_HANDLE, const String: szFormat[], any: ...)
    if (0 < iClient <= MaxClients && IsClientInGame(iClient)) {

        new String: szBuffer[250];
        VFormat(szBuffer, sizeof(szBuffer), szFormat, 4);

        if (ShowHudText(iClient, -1, szBuffer) < 0 && hHudSynchronizer != INVALID_HANDLE) {
            ShowSyncHudText(iClient, hHudSynchronizer, szBuffer);
        }
}

public Action: Command_GhostFists(int client, int args) {
    if (bAllowFistsFists && flFistsPrice != 0.0 && 0 < client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client)){
        GetClientName(client, szClientName, sizeof(szClientName));
        flCashCurrent = GetEntPropFloat(client, Prop_Send, "m_flFoFCash");
        new cashCompare;
        if ((GetUserFlagBits(client) & ADMFLAG_CUSTOM5) || (GetUserFlagBits(client) & ADMFLAG_ROOT))
            {
                cashCompare = FloatCompare(flCashCurrent, (flFistsPrice * 0.5));
            }
            else {
                cashCompare = FloatCompare(flCashCurrent, flFistsPrice);
            }
        if (cashCompare == -1){
            CPrintToChat(client, "%s{red}You're broke! {gold}Get some kills to get some gold, partner!", CHAT_PREFIX );
            return Plugin_Handled;
        }
        else if (g_Clients[client][(ClientData:hasFists)] == true) {
            CPrintToChat(client, "%s{red}You already have Ghost Fists, you coward!", CHAT_PREFIX );
            return Plugin_Handled;
        }
        else {
            if ((GetUserFlagBits(client) & ADMFLAG_CUSTOM5) || (GetUserFlagBits(client) & ADMFLAG_ROOT))
            {
                SetEntPropFloat(client, Prop_Send, "m_flFoFCash", (GetEntPropFloat(client, Prop_Send, "m_flFoFCash") - (flFistsPrice * 0.5)));
            }
            else {
                SetEntPropFloat(client, Prop_Send, "m_flFoFCash", (GetEntPropFloat(client, Prop_Send, "m_flFoFCash") - flFistsPrice));
            }
            CPrintToChatAll("%s{green}Yee haw! {gold}%s{green} just purchased Ghost Fists. {gold}Boo!", CHAT_PREFIX, szClientName );
            new wepslot = GetPlayerWeaponSlot(client, 0);
            RemovePlayerItem(client, wepslot);
            GivePlayerItem(client, "weapon_fists_ghost");
            new client_weapon = GetPlayerWeaponSlot(client, 0);

            if (client_weapon != -1)
                EquipPlayerWeapon(client, client_weapon); 
            SetEntityModel(client, "models/npc/ghost.mdl");
            SetEntityRenderColor(client, 0, 0, 0, 255);
            g_Clients[client][(ClientData:hasFists)] = true;
            return Plugin_Handled;
        }
    }
    else if (!IsClientInGame(client))
    {
        CPrintToChat(client, "%s{red}Sorry, you gotta be playin' the game to get the Ghost Fists!", CHAT_PREFIX );
        return Plugin_Handled;
    } 
    else if (!IsPlayerAlive(client))
    {
        CPrintToChat(client, "%s{red}You can't fight when you're a bucket of bones!", CHAT_PREFIX );
        return Plugin_Handled;
    } 
    else
    {
        CPrintToChat(client, "%s{red}Sorry, but we can't have any ghosts here!", CHAT_PREFIX );
        return Plugin_Handled;
    }
}
