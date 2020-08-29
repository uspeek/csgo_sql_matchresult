# CS:GO SQL Match Result plugin

This is a very crude, possibly prone to bugs and other unwanted stuff plugin to save the result of a completed match (tracked by *cs_win_panel_match* event) into an SQL-database.

The plugin was made to be used on a private server, I didn't test much. The plugin has been used alongside the [splewis' pug setup plugin](https://github.com/splewis/csgo-pug-setup) with the only purpose of saving match results.

# Usage

Compile or get .smx file from the releases tab and put it into your `server folder/csgo/addons/sourcemod/plugins`. Add "matchresults" section to your database config if you need to. 

Use `sm_create_matchresult_tables` in **server console** to create database tables.

`sm_upload_sql_results` cvar is set to 1 by default, set it to 0 if you want to disable match results saving.

The match will be saved on `cs_win_panel_match` event when cvar is set to 1 and there are at least 10 players (bots included(?)) on the server. The plugin will skip spectators and it will also mark bots accordingly.

**NOTICE** I haven't tested it with empty database (huh). If it throws errors or anything, create one entry in the `mr_results` table and fill it however you like.

# Database strcture

The next info will be saved about the match:
* matchid
* date
* map
* team1_score
* team2_score

SQL for the `mr_results` table:

```CREATE TABLE `mr_results` (`matchid` INT UNSIGNED NOT NULL AUTO_INCREMENT,	`date` DATETIME NOT NULL,	`map` VARCHAR(64) NOT NULL DEFAULT '0',	`team1_score` TINYINT UNSIGNED NOT NULL DEFAULT 0,	`team1_half1` TINYINT UNSIGNED NULL DEFAULT 0,	`team1_half2` TINYINT UNSIGNED NULL DEFAULT 0,	`team2_score` TINYINT UNSIGNED NOT NULL DEFAULT 0,	`team2_half1` TINYINT UNSIGNED NULL DEFAULT 0,	`team2_half2` TINYINT UNSIGNED NULL DEFAULT 0,	PRIMARY KEY (`matchid`))```

Don't mind the teamX_halfY fields, that's what I've initally wanted to have, but was ditched in the end.

The next info will be saved about the players:
* id
* match_id
* player_name
* steamid - Steam ID of the player, or "BOT" will be written into this field
* team
* kills
* assists
* deaths
* mvps
* score

SQL for the `mr_players` table:

```CREATE TABLE `mr_players` (`id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,`match_id` INT(11) NOT NULL,`player_name` VARCHAR(64) NOT NULL COLLATE 'utf8mb4_general_ci',`steamid` VARCHAR(20) NOT NULL COLLATE 'utf8mb4_general_ci',`team` TINYINT(3) UNSIGNED NOT NULL,`kills` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',`assists` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',`deaths` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',`mvps` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',`score` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',PRIMARY KEY (`id`) USING BTREE)```