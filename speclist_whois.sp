/*

	Compile this with SM 1.8

*/

/* Dependencies */

#include <sourcemod>
#include <tf2_stocks>
#include <morecolors>
#include "include/smlib"

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1"
#define PREFIX "[WhoIs List]"

/* Globals */

char permNames[MAXPLAYERS][MAX_NAME_LENGTH];
bool listDrawn[MAXPLAYERS + 1];
bool warningSent = false;
Database g_Database;

/* Plugin Info */

public Plugin myinfo =  {
	name = "[TF2] WhoIs List", 
	author = "ampere", 
	description = "Speclist by Xpktro modified to add WhoIs aliases.", 
	version = PLUGIN_VERSION, 
	url = "https://legacyhub.xyz"
};

/* Plugin Start */

public void OnPluginStart() {
	RegConsoleCmd("sl", CMD_SL);
	Database.Connect(SQL_ConnectionCallback, "whois");
	CreateTimer(3.0, DrawTimer, _, TIMER_REPEAT);
}

/* Database Connection Callback */

public void SQL_ConnectionCallback(Database db, const char[] error, any data) {
	if (db == null) {
		LogError("%s %s", PREFIX, error);
		return;
	}
	g_Database = db;
}

/* Getting user's permaname when he connects and storing it locally */

public void OnClientAuthorized(int client, const char[] auth) {
	if (g_Database == null) {
		return;
	}
	char query[128];
	g_Database.Format(query, sizeof(query), "SELECT name FROM whois_permname WHERE steam_id = '%s';", auth);
	g_Database.Query(SQL_ClientConnectedNameFetch, query, GetClientUserId(client));
}

public void SQL_ClientConnectedNameFetch(Database db, DBResultSet results, const char[] error, int userid) {
	// If char[] error ain't empty, log it and return
	if (error[0] != '\0') {
		ThrowError("%s %s", PREFIX, error);
		delete results;
		return;
	}
	// Fetch client permname and store it in the global string array
	int nameCol;
	char name[32];
	if (results.FetchRow()) {
		results.FieldNameToNum("name", nameCol);
		results.FetchString(nameCol, name, sizeof(name));
		strcopy(permNames[GetClientOfUserId(userid)], MAX_NAME_LENGTH, name);
	}
}

/* Command Callback */

public Action CMD_SL(int client, int args) {
	if (g_Database == null && !warningSent) {
		MC_PrintToChatAll("{green}%s {default}Database connection failed. Aliases will NOT be shown.", PREFIX);
		warningSent = true;
	}
	int userid = GetClientUserId(client);
	listDrawn[client] = !listDrawn[client];
	DrawList(userid);
}

void DrawList(int userid) {
	int client = GetClientOfUserId(userid);
	char specList[2048], nameBuffer[128], buffer[64], specBuffer[32], idx[16];
	int index = 1;
	Format(specBuffer, sizeof(specBuffer), "Spectators: %i\n", GetSpecCount());
	StrCat(specList, sizeof(specList), specBuffer);
	for (int i = 1; i <= MaxClients; i++) {
		// If client is in spec
		if (IsClientInGame(i) && !IsClientSourceTV(i) && !IsFakeClient(i) && TF2_GetClientTeam(i) == TFTeam_Spectator) {
			IntToString(index, idx, sizeof(idx));
			// Fetch his name, add it to a line in the specList
			GetClientName(i, nameBuffer, sizeof(nameBuffer));
			StrCat(specList, sizeof(specList), idx);
			StrCat(specList, sizeof(specList), ". ");
			// And if the global string array contains his name, add it to the line
			if (permNames[i][0] == '\0') {
				Format(buffer, sizeof(buffer), "%s\n", nameBuffer);
			}
			else {
				Format(buffer, sizeof(buffer), "%s (%s)\n", nameBuffer, permNames[i]);
			}
			StrCat(specList, sizeof(specList), buffer);
			index++;
		}
	}
	// Print the list
	Client_PrintKeyHintText(client, listDrawn[client] ? specList : "");
}

/* Deleting client's name from the array on disconnect */

public void OnClientDisconnect(int client) {
	strcopy(permNames[client], MAX_NAME_LENGTH, "");
}

/* Repeating timer to keep the list alive on screen */

public Action DrawTimer(Handle timer) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && listDrawn[i]) {
			DrawList(GetClientUserId(i));
		}
	}
	return Plugin_Continue;
}

/* Get the number of human spectators */

int GetSpecCount() {
	int result;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsClientSourceTV(i) && !IsFakeClient(i) && TF2_GetClientTeam(i) == TFTeam_Spectator) {
			result++;
		}
	}
	return result;
}