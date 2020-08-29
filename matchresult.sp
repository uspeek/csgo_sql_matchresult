#include <sourcemod>
#include <cstrike>

public Plugin:myinfo = {
    name = "SQL Match Results",
    author = "uspeek",
    description = "Uploads match results to database",
    version = "0.1",
    url = "http://uspeek.one"
};

ConVar g_cvarDoUploadResults = null;

Database Connect(){
    char error[255];
    Database db;

    if(SQL_CheckConfig("matchresults")){
        db = SQL_Connect("matchresults", true, error, sizeof(error));
    }else{
        db = SQL_Connect("default", true, error, sizeof(error));
    }

    if(db == null) LogError("Could not connect to database: %s", error);

    return db;
}

void CreateTables(int client, Database db){
    bool errors;
    char queries[][] = {
        //Match results table containing date, map and team scores
        "CREATE TABLE `mr_results` (`matchid` INT UNSIGNED NOT NULL AUTO_INCREMENT,	`date` DATETIME NOT NULL,	`map` VARCHAR(64) NOT NULL DEFAULT '0',	`team1_score` TINYINT UNSIGNED NOT NULL DEFAULT 0,	`team1_half1` TINYINT UNSIGNED NULL DEFAULT 0,	`team1_half2` TINYINT UNSIGNED NULL DEFAULT 0,	`team2_score` TINYINT UNSIGNED NOT NULL DEFAULT 0,	`team2_half1` TINYINT UNSIGNED NULL DEFAULT 0,	`team2_half2` TINYINT UNSIGNED NULL DEFAULT 0,	PRIMARY KEY (`matchid`))",

        //Players table containing ids, K/A/D score and mvps
        "CREATE TABLE `mr_players` (`id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,`match_id` INT(11) NOT NULL,`player_name` VARCHAR(64) NOT NULL COLLATE 'utf8mb4_general_ci',`steamid` VARCHAR(20) NOT NULL COLLATE 'utf8mb4_general_ci',`team` TINYINT(3) UNSIGNED NOT NULL,`kills` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',`assists` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',`deaths` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',`mvps` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',`score` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',PRIMARY KEY (`id`) USING BTREE)"
    };

    for (int i = 0; i < sizeof(queries); i++){
        if (!SQL_FastQuery(db, queries[i])){
            char error[255];
            SQL_GetError(db, error, sizeof(error));
            PrintToServer("Failed to complete query %d (error: %s)", i, error);
            errors = true;
        }
    }
    if(!errors){
        ReplyToCommand(client, "Created Match Results tables");
    }
}

int GetLastMatchId(){
    int client = 0,matchid;
    Database db = Connect();
    if (db == null){
        ReplyToCommand(client, "[SM] Could not connect to database");
        return -1;
    }
    DBResultSet query = SQL_Query(db, "SELECT `matchid` FROM `mr_results` ORDER BY `matchid` DESC LIMIT 1");
    if (query == null){    
        char error[255];
        SQL_GetError(db, error, sizeof(error));
        PrintToServer("Failed to query match id (error: %s)", error);
        return -1;
    }else{
        while(SQL_FetchRow(query)){
            matchid = SQL_FetchInt(query, 0);
        }
        delete query;
        delete db;
        return matchid;
    }
}

public void OnPluginStart(){
    HookEvent("cs_win_panel_match", Event_MatchEnd);

    RegServerCmd("sm_create_matchresult_tables", Command_CreateTables);

    g_cvarDoUploadResults = CreateConVar("sm_upload_sql_results", "1", "Upload match results to SQL database");
}

public Action Event_MatchEnd(Event event, const char[] name, bool dontBroadcast){
    if(g_cvarDoUploadResults.IntValue != 0){
        if(GetClientCount(true)<10){
            PrintToChatAll("[Console] Less than 10 players on server, Match isn't uploaded");
            return;
        }
        PrintToChatAll("[Console] Match is over, uploading Match results...");

        char queries[15][1024];
        char i=1;
        char j=0;

        Database db = Connect();

        int scores[2];
        char CurMap[64];
        char player_name[64], escaped_name[64];
        char authid[32];
        int team=0;
        int errors=0;

        scores[0] = CS_GetTeamScore(CS_TEAM_T);
        scores[1] = CS_GetTeamScore(CS_TEAM_CT);

        GetCurrentMap(CurMap, sizeof(CurMap));

        Format(queries[0], 300, "INSERT INTO `mr_results` (map, team1_score, team2_score) VALUES ('%s', %d, %d);", CurMap, CS_GetTeamScore(CS_TEAM_T), CS_GetTeamScore(CS_TEAM_CT));

        PrintToServer("Match SQL: %s", queries[0]);
        LogMessage("Match SQL: %s", queries[0]);

        int matchid = GetLastMatchId() + 1;
        PrintToServer("Match id: %d", matchid);
        LogMessage("Match id: %d", matchid);

        for(j = 1; j <= MaxClients; j++){
            if(!IsClientConnected(j)){
                continue;
            }

            team = GetClientTeam(j);
            if(team==CS_TEAM_T) team = 1;
            else if(team==CS_TEAM_CT) team = 2;
            else continue;

            GetClientName(j, player_name, sizeof(player_name));

            if(IsFakeClient(j)){
                authid = "BOT";
            }else{
                GetClientAuthId(j, AuthId_SteamID64, authid, sizeof(authid));
            }

            db.Escape(player_name, escaped_name, 64);

            Format(queries[i], 300, "INSERT INTO `mr_players` (match_id, player_name, steamid, team, kills, assists, deaths, mvps, score) VALUES (%d, '%s', '%s', %d, %d, %d, %d, %d, %d);", matchid, escaped_name, authid, team, GetClientFrags(j), CS_GetClientAssists(j), GetEntProp(j, Prop_Data, "m_iDeaths"), CS_GetMVPCount(j), CS_GetClientContributionScore(j));
            i++;
        }

        PrintToServer("Total records to add: %d", i); 
        LogMessage("Total records to add: %d", i);

        for(j = 0; j < i; j++){
            /*
            PrintToServer("%d: %s", j, queries[j]);
            LogMessage("%d: %s", j, queries[j]); 
            */
            if (!SQL_FastQuery(db, queries[j])){
                char error[255];
                SQL_GetError(db, error, sizeof(error));
                if(j == 0){
                    PrintToServer("Failed to insert match result query (error: %s)", error);
                    LogMessage("Failed to insert match result query (error: %s)", error);
                    PrintToChatAll("[Console] Failed to upload Match results");
                    errors=100;
                    break;
                }else{
                    PrintToServer("Failed to insert player query (error: %s)", error);
                    LogMessage("Failed to insert player query (error: %s)", error);
                    LogMessage("Error at query: %s", queries[j]);
                    errors++;
                }
            }
        }

        delete db;

        if(errors == 0){
            PrintToServer("Uploaded match to SQL database");
            LogMessage("Uploaded match to SQL database");
            PrintToChatAll("[Console] Successfully uploaded Match results");
        }else{
            PrintToChatAll("[Console] There were %d errors while uploading Match results", errors);
            LogMessage("%d errors while uploading Match results", errors);
        }
    }
}

public Action Command_CreateTables(int args){
    int client = 0;
    Database db = Connect();
    if (db == null){
        ReplyToCommand(client, "Could not connect to database");
        return Plugin_Handled;
    }

    char ident[16];
    db.Driver.GetIdentifier(ident, sizeof(ident));

    if (strcmp(ident, "mysql") == 0){
        CreateTables(client, db);
    }else{
        ReplyToCommand(client, "MySQL is required for Match Results");
    }

    delete db;

    return Plugin_Handled;
}