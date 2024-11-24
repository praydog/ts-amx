#include <amxmodx>
#include <fakemeta_util>
#include <fakemeta_const>
#include <fakemeta>
#include <hamsandwich>
#include <engine>

#define MAX_PLAYERS 32
#define MAX_RECORDING_DURATION 2048

new const HUD_CHANNEL = 4;

enum {
    RECORD_BUTTONS,
    RECORD_OLD_BUTTONS,
    RECORD_ENT_FLAGS,
    RECORD_MOVEDIR_X,
    RECORD_MOVEDIR_Y,
    RECORD_MOVEDIR_Z,
    RECORD_ANGLES_X,
    RECORD_ANGLES_Y,
    RECORD_ANGLES_Z,
    RECORD_V_ANGLE_X,
    RECORD_V_ANGLE_Y,
    RECORD_V_ANGLE_Z,
    RECORD_POS_X,
    RECORD_POS_Y,
    RECORD_POS_Z,
    RECORD_VEL_X,
    RECORD_VEL_Y,
    RECORD_VEL_Z,

    RECORD_VEC_USER1_X,
    RECORD_VEC_USER1_Y,
    RECORD_VEC_USER1_Z,
    RECORD_VEC_USER2_X,
    RECORD_VEC_USER2_Y,
    RECORD_VEC_USER2_Z,
    RECORD_VEC_USER3_X,
    RECORD_VEC_USER3_Y,
    RECORD_VEC_USER3_Z,
    RECORD_VEC_USER4_X,
    RECORD_VEC_USER4_Y,
    RECORD_VEC_USER4_Z,

    RECORD_FL_USER1,
    RECORD_FL_USER2,
    RECORD_FL_USER3,
    RECORD_FL_USER4,

    RECORD_COUNT
}

#define USERCMD_ELEMENTS RECORD_COUNT

new g_usercmd_recordings[MAX_PLAYERS + 1][MAX_RECORDING_DURATION][USERCMD_ELEMENTS];
new Float:g_recording_start_positions[MAX_PLAYERS + 1][3]
new bool:g_is_recording[MAX_PLAYERS + 1];
new bool:g_is_replaying[MAX_PLAYERS + 1];
new g_record_start_ticks[MAX_PLAYERS + 1];
new g_replay_start_ticks[MAX_PLAYERS + 1];
new g_recording_durations[MAX_PLAYERS + 1];
new g_current_replay_indices[MAX_PLAYERS + 1];
new bool:g_replay_reverse[MAX_PLAYERS + 1];
new bool:g_replay_pause[MAX_PLAYERS + 1];
new Float:g_last_time_displayed_buttons[MAX_PLAYERS + 1];
new g_last_replay_buttons[MAX_PLAYERS + 1];

// This function is called when the plugin is loaded
public plugin_init() {
    register_plugin("praydogs cool plugin", "1.0", "praydog");
    
    register_clcmd("say /pos", "PrintPlayerPosition");
    register_clcmd("say /savepos", "SavePlayerPosition");
    register_clcmd("say /restorepos", "RestorePlayerPosition");
    register_clcmd("say /nocollide", "DisablePlayerCollision");
    register_clcmd("say /collide", "EnablePlayerCollision");
    register_clcmd("say /speedboost", "ToggleSpeedBoost");
    register_clcmd("say /god", "ToggleGodMode");
    register_clcmd("say /record", "InitializeRecording");
    register_clcmd("say /replay", "InitializeReplay");
    register_clcmd("say /replayreverse", "InitializeReplayReverse");
    register_clcmd("say /replaypause", "PauseReplay");
    //register_clcmd("say /copyreplay", "CopyReplay");
    register_clcmd("say", "OnSay");

    RegisterHam(Ham_TakeDamage, "player", "OnTakeDamage");
    register_forward(FM_CmdStart, "CmdStart");
    register_forward(FM_PlayerPreThink, "PlayerPreThink");
    register_forward(FM_PlayerPostThink, "PlayerPostThink");

    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn");
}

public OnSay(id) {
    new txt[128];
    if (read_argv(1, txt, charsmax(txt)) == 0) {
        return PLUGIN_CONTINUE;
    }

    if (equali(txt, "/copyreplay")) {
        if (read_argv(2, txt, charsmax(txt)) == 0) {
            client_print(id, print_chat, "Usage: /copyreplay <player_name>");
            return PLUGIN_CONTINUE;
        }

        CopyReplay(id, txt);
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

new const messages[][] = {
    "/savepos, /restorepos - Save and restore your position",
    "/record, /replay - Record and replay your movement",
    "/nocollide, /collide - Enable/disable player collisions",
    "/speedboost - Toggle max speed cap when jumping"
};

public WelcomeHud(params[]) {
    if (!is_user_connected(params[0])) {
        return;
    }

    new Float:x = 0.5;
    new Float:y = 0.6;

    for (new i = 0; i < sizeof messages; i++) {
        set_hudmessage(255, 255, 255, x, y, 0, 0.1, 0.1, 0.0, 0.0, -1);
        show_hudmessage(params[0], messages[i]);
        y += 0.01; // Move down for the next message
    }
}

public OnPlayerSpawn(id) {
    for (new i = 0; i < sizeof messages; i++) {
        client_print(id, print_chat, messages[i]);
    }

    new parameters[1];
    parameters[0] = id;
    set_task(0.1, "WelcomeHud", id, parameters, sizeof(parameters), "a", 100);

    return HAM_HANDLED;
}

new bool:g_god_mode_enabled[33]; // Array to store god mode status for each player

public ToggleGodMode(id) {
    if (!is_user_alive(id)) {
        client_print(id, print_chat, "You must be alive to toggle god mode.");
        return PLUGIN_HANDLED;
    }

    g_god_mode_enabled[id] = !g_god_mode_enabled[id];

    if (g_god_mode_enabled[id]) {
        client_print(id, print_chat, "God mode enabled!");
    } else {
        client_print(id, print_chat, "God mode disabled!");
    }

    return PLUGIN_HANDLED;
}

public PrintPlayerPosition(id) {
    if (!is_user_alive(id)) {
        client_print(id, print_chat, "You must be alive to use this command.");
        return PLUGIN_HANDLED;
    }

    // Get the player's position
    new Float:playerPos[3];
    entity_get_vector(id, EV_VEC_origin, playerPos);

    // Format the position into a string
    new msg[128];
    new user_name[64];
    get_user_name(id, user_name, 63);
    format(msg, 128, "Player %s is at position: X: %f, Y: %f, Z: %f",
             user_name, playerPos[0], playerPos[1], playerPos[2]);

    // Print the message to all players
    client_print(0, print_chat, msg);

    return PLUGIN_HANDLED;
}

new Float:g_player_positions[33][3]; // Stores positions for up to 32 players (id 1 to 32)

// Function to save off player position for later use
public SavePlayerPosition(id) {
    if (!is_user_connected(id) || !is_user_alive(id)) {
        client_print(id, print_chat, "You must be alive to save your position.");
        return PLUGIN_HANDLED;
    }

    // Get the player's position
    new Float:pos[3];
    entity_get_vector(id, EV_VEC_origin, pos);

    // Save the position in the global array
    g_player_positions[id][0] = pos[0];
    g_player_positions[id][1] = pos[1];
    g_player_positions[id][2] = pos[2];

    client_print(id, print_chat, "Position saved!");
    return PLUGIN_HANDLED;
}

public RestorePlayerPosition(id) {
    if (!is_user_connected(id) || !is_user_alive(id)) {
        client_print(id, print_chat, "You must be alive to restore your position.");
        return PLUGIN_HANDLED;
    }

    if (g_player_positions[id][0] == 0.0 && g_player_positions[id][1] == 0.0 && g_player_positions[id][2] == 0.0) {
        client_print(id, print_chat, "No saved position found.");
        return PLUGIN_HANDLED;
    }

    // Restore the player's position
    entity_set_vector(id, EV_VEC_origin, g_player_positions[id]);
    new Float:vel[3] = {0.0, 0.0, 0.0};
    fm_set_user_velocity(id, vel);

    client_print(id, print_chat, "Position restored!");
    return PLUGIN_HANDLED;
}

// Hook for FM_TakeDamage
public OnTakeDamage(victim, inflictor, attacker, Float:damage, damageType) {
    if (g_god_mode_enabled[victim]) {
        client_print(victim, print_chat, "God mode enabled! Damage blocked!");
        return HAM_SUPERCEDE;
    }

    if ((damageType & DMG_FALL) && damage < 100.0) {
        client_print(victim, print_chat, "Fall damage blocked!");
        return HAM_SUPERCEDE;
    }

    // Allow other types of damage to pass through
    return HAM_HANDLED;
}

public DisablePlayerCollision(id) {
    if (!is_user_alive(id)) {
        client_print(id, print_chat, "You must be alive to toggle collisions.");
        return PLUGIN_HANDLED;
    }

    // Set the player's solid state to SOLID_NOT
    entity_set_int(id, EV_INT_solid, SOLID_NOT);

    client_print(id, print_chat, "Collisions disabled!");
    return PLUGIN_HANDLED;
}

public EnablePlayerCollision(id) {
    if (!is_user_alive(id)) {
        client_print(id, print_chat, "You must be alive to toggle collisions.");
        return PLUGIN_HANDLED;
    }

    // Set the player's solid state back to SOLID_SLIDEBOX (default for players)
    entity_set_int(id, EV_INT_solid, SOLID_SLIDEBOX);

    client_print(id, print_chat, "Collisions enabled!");
    return PLUGIN_HANDLED;
}

public ShowVelocityHUD(id) {
    new Float:velocity[3];
    fm_get_user_velocity(id, velocity);
    velocity[2] = 0.0; // Ignore the Z component of the velocity

    // Calculate the velocity's length (magnitude)
    new Float:veclen = vector_length(velocity);

    // Format the velocity text
    new msg[64];
    format(msg, charsmax(msg), "Velocity: %.2f", veclen);

    // Display the HUD message
    set_hudmessage(255, 0, 0, 0.5, 0.5, 0, 0.1, 0.1, 0.0, 0.0, HUD_CHANNEL); // Adjust positioning/colors as needed
    show_hudmessage(id, msg);
}

new bool:g_speed_boost_enabled[33]; // Array to store speed boost status for each player
new bool:g_last_on_ground_state[33]; // Array to store the last on-ground state for each player

// Speed boost means boosting the player to speed cap when jumping
// for testing stuff if we're too lazy to boost correctly
public ToggleSpeedBoost(id) {
    if (!is_user_alive(id)) {
        client_print(id, print_chat, "You must be alive to toggle speed boost.");
        return PLUGIN_HANDLED;
    }

    g_speed_boost_enabled[id] = !g_speed_boost_enabled[id];

    if (g_speed_boost_enabled[id]) {
        client_print(id, print_chat, "Speed boost enabled!");
    } else {
        client_print(id, print_chat, "Speed boost disabled!");
    }

    return PLUGIN_HANDLED;
}


public StopRecording(id) {
    g_is_recording[id] = false;
    g_record_start_ticks[id] = 0;
}

public bool:IsRecording(id) {
    return g_is_recording[id];
}

public bool:IsReplaying(id) {
    return g_is_replaying[id];
}

public bool:IsReplayingReverse(id) {
    return g_replay_reverse[id];
}

public InitializeRecording(id) {
    if (!is_user_alive(id)) {
        client_print(id, print_chat, "You must be alive to record.");
        return PLUGIN_HANDLED;
    }

    if (IsReplaying(id)) {
        client_print(id, print_chat, "Cannot record while replaying!");
        return PLUGIN_HANDLED;
    }

    StopRecording(id);

    g_is_recording[id] = true;
    g_is_replaying[id] = false;
    g_record_start_ticks[id] = 0;
    g_replay_start_ticks[id] = 0;
    g_recording_durations[id] = 0;

    client_print(id, print_chat, "Recording initialized!");

    return PLUGIN_HANDLED;
}

public InitializeReplayImpl(id) {
    if (!is_user_alive(id)) {
        client_print(id, print_chat, "You must be alive to replay.");
        return false;
    }

    StopRecording(id);

    if (g_recording_durations[id] == 0) {
        client_print(id, print_chat, "No recording found!");
        return false;
    }

    new was_replaying_reverse = IsReplayingReverse(id);

    g_is_replaying[id] = true;
    g_is_recording[id] = false;
    g_replay_reverse[id] = false;
    g_record_start_ticks[id] = 0;
    g_replay_start_ticks[id] = 0;
    g_replay_pause[id] = false;

    if (was_replaying_reverse) {
        g_current_replay_indices[id] = g_recording_durations[id] - g_current_replay_indices[id];
    } else {
        g_current_replay_indices[id] = 0;
    }

    client_print(id, print_chat, "Replay initialized!");

    return true;
}

public InitializeReplay(id) {
    if (!InitializeReplayImpl(id)) {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_HANDLED;
}

public InitializeReplayReverse(id) {
    new previous_replay_index = g_current_replay_indices[id];
    if (!IsReplaying(id)) {
        previous_replay_index = 0;
    }
    if (!InitializeReplayImpl(id)) {
        return PLUGIN_HANDLED;
    }

    g_replay_reverse[id] = true;
    if (previous_replay_index > 0) {
        g_current_replay_indices[id] = g_recording_durations[id] - previous_replay_index;
    }
    return PLUGIN_HANDLED;
}

public PauseReplay(id) {
    if (!IsReplaying(id)) {
        return PLUGIN_HANDLED;
    }

    g_replay_pause[id] = !g_replay_pause[id];

    if (g_replay_pause[id]) {
        client_print(id, print_chat, "Replay paused!");
    } else {
        client_print(id, print_chat, "Replay resumed!");
    }

    return PLUGIN_HANDLED;
}

public CopyReplay(id, target_name[]) {
    if (!is_user_connected(id) || !is_user_alive(id)) {
        client_print(id, print_chat, "You must be alive to use this command.");
        return PLUGIN_HANDLED;
    }

    client_print(id, print_chat, "Attempting to copy replay from %s", target_name);

    // Find the target player by name
    new target = find_player("al", target_name);
    if (!target || !is_user_connected(target)) {
        client_print(id, print_chat, "Target player not found.");
        return PLUGIN_HANDLED;
    }

    if (g_recording_durations[target] == 0) {
        client_print(id, print_chat, "Target player has no recording.");
        return PLUGIN_HANDLED;
    }

    if (IsRecording(target)) {
        client_print(id, print_chat, "Target player is currently recording.");
        return PLUGIN_HANDLED;
    }

    for (new i = 0; i < g_recording_durations[target]; i++) {
        for (new j = 0; j < USERCMD_ELEMENTS; j++) {
            g_usercmd_recordings[id][i][j] = g_usercmd_recordings[target][i][j];
        }
    }

    g_recording_durations[id] = g_recording_durations[target];

    return PLUGIN_HANDLED;
}

public RecordEntity(id) {
    if (!IsRecording(id)) {
        return;
    }

    if (g_record_start_ticks[id] == 0) {
        // Wait until entity velocity length is 0 before starting recording
        new Float:vel[3] = {0.0, 0.0, 0.0};
        fm_get_user_velocity(id, vel);

        new Float:veclen = vector_length(vel);

        if (veclen > 0.0) {
            return;
        }

        g_record_start_ticks[id] = tickcount();

        entity_get_vector(id, EV_VEC_origin, g_recording_start_positions[id]);
        client_print(id, print_chat, "Recording started!");
    }

    new index = g_recording_durations[id];
    if (index >= MAX_RECORDING_DURATION) {
        client_print(id, print_chat, "Maximum recording duration reached!");
        StopRecording(id);
        g_recording_durations[id] = MAX_RECORDING_DURATION;
        return;
    }

    // Record usercmd data
    g_usercmd_recordings[id][index][RECORD_BUTTONS] = entity_get_int(id, EV_INT_button);
    g_usercmd_recordings[id][index][RECORD_OLD_BUTTONS] = entity_get_int(id, EV_INT_oldbuttons);
    g_usercmd_recordings[id][index][RECORD_ENT_FLAGS] = entity_get_int(id, EV_INT_flags);

    new Float:movedir[3];
    /*g_usercmd_recordings[id][index][1] = get_uc(uc_handle, UC_ForwardMove);
    g_usercmd_recordings[id][index][2] = get_uc(uc_handle, UC_SideMove);
    g_usercmd_recordings[id][index][3] = get_uc(uc_handle, UC_UpMove);*/
    entity_get_vector(id, EV_VEC_movedir, movedir);

    g_usercmd_recordings[id][index][RECORD_MOVEDIR_X] = _:movedir[0];
    g_usercmd_recordings[id][index][RECORD_MOVEDIR_Y] = _:movedir[1];
    g_usercmd_recordings[id][index][RECORD_MOVEDIR_Z] = _:movedir[2];
    
    new Float:angles[3];
    /*get_uc(uc_handle, UC_ViewAngles, angles); 
    g_usercmd_recordings[id][index][4] = angles[0];
    g_usercmd_recordings[id][index][5] = angles[1];
    g_usercmd_recordings[id][index][6] = angles[2];*/

    entity_get_vector(id, EV_VEC_angles, angles);

    g_usercmd_recordings[id][index][RECORD_ANGLES_X] = _:angles[0];
    g_usercmd_recordings[id][index][RECORD_ANGLES_Y] = _:angles[1];
    g_usercmd_recordings[id][index][RECORD_ANGLES_Z] = _:angles[2];

    entity_get_vector(id, EV_VEC_v_angle, angles);

    g_usercmd_recordings[id][index][RECORD_V_ANGLE_X] = _:angles[0];
    g_usercmd_recordings[id][index][RECORD_V_ANGLE_Y] = _:angles[1];
    g_usercmd_recordings[id][index][RECORD_V_ANGLE_Z] = _:angles[2];

    new Float:pos[3];
    entity_get_vector(id, EV_VEC_origin, pos);

    g_usercmd_recordings[id][index][RECORD_POS_X] = _:pos[0];
    g_usercmd_recordings[id][index][RECORD_POS_Y] = _:pos[1];
    g_usercmd_recordings[id][index][RECORD_POS_Z] = _:pos[2];

    new Float:vel[3];
    fm_get_user_velocity(id, vel);

    g_usercmd_recordings[id][index][RECORD_VEL_X] = _:vel[0];
    g_usercmd_recordings[id][index][RECORD_VEL_Y] = _:vel[1];
    g_usercmd_recordings[id][index][RECORD_VEL_Z] = _:vel[2];

    new Float:vec_temp[3];

    entity_get_vector(id, EV_VEC_vuser1, vec_temp);
    g_usercmd_recordings[id][index][RECORD_VEC_USER1_X] = _:vec_temp[0];
    g_usercmd_recordings[id][index][RECORD_VEC_USER1_Y] = _:vec_temp[1];
    g_usercmd_recordings[id][index][RECORD_VEC_USER1_Z] = _:vec_temp[2];

    entity_get_vector(id, EV_VEC_vuser2, vec_temp);
    g_usercmd_recordings[id][index][RECORD_VEC_USER2_X] = _:vec_temp[0];
    g_usercmd_recordings[id][index][RECORD_VEC_USER2_Y] = _:vec_temp[1];
    g_usercmd_recordings[id][index][RECORD_VEC_USER2_Z] = _:vec_temp[2];

    entity_get_vector(id, EV_VEC_vuser3, vec_temp);
    g_usercmd_recordings[id][index][RECORD_VEC_USER3_X] = _:vec_temp[0];
    g_usercmd_recordings[id][index][RECORD_VEC_USER3_Y] = _:vec_temp[1];
    g_usercmd_recordings[id][index][RECORD_VEC_USER3_Z] = _:vec_temp[2];

    entity_get_vector(id, EV_VEC_vuser4, vec_temp);
    g_usercmd_recordings[id][index][RECORD_VEC_USER4_X] = _:vec_temp[0];
    g_usercmd_recordings[id][index][RECORD_VEC_USER4_Y] = _:vec_temp[1];
    g_usercmd_recordings[id][index][RECORD_VEC_USER4_Z] = _:vec_temp[2];

    g_usercmd_recordings[id][index][RECORD_FL_USER1] = _:entity_get_float(id, EV_FL_fuser1);
    g_usercmd_recordings[id][index][RECORD_FL_USER2] = _:entity_get_float(id, EV_FL_fuser2);
    g_usercmd_recordings[id][index][RECORD_FL_USER3] = _:entity_get_float(id, EV_FL_fuser3);
    g_usercmd_recordings[id][index][RECORD_FL_USER4] = _:entity_get_float(id, EV_FL_fuser4);

    g_recording_durations[id] = index + 1;
}

public ReplayEntity(id, bool:in_post) {
    if (IsRecording(id) || !IsReplaying(id)) {
        return;
    }

    if (g_replay_start_ticks[id] == 0) {
        //g_replay_start_ticks[id] = random_seed; // Initialize start tick on the first frame
        g_replay_start_ticks[id] = tickcount();
        client_print(id, print_chat, "Replay started!");

        entity_set_vector(id, EV_VEC_origin, g_recording_start_positions[id]);
    }

    new original_index = g_current_replay_indices[id];
    if (original_index >= MAX_RECORDING_DURATION || original_index >= g_recording_durations[id]) {
        client_print(id, print_chat, "Replay finished!");
        g_is_replaying[id] = false;
        g_replay_start_ticks[id] = 0;
        return;
    }

    new index = original_index;

    if (IsReplayingReverse(id)) {
        index = g_recording_durations[id] - original_index - 1;

        if (index < 0) {
            client_print(id, print_chat, "Replay finished!");
            g_is_replaying[id] = false;
            g_replay_start_ticks[id] = 0;
            return;
        }
    }

    /*set_uc(uc_handle, UC_Buttons, g_usercmd_recordings[id][index][0]);
    set_uc(uc_handle, UC_ForwardMove, g_usercmd_recordings[id][index][1]);
    set_uc(uc_handle, UC_SideMove, g_usercmd_recordings[id][index][2]);
    set_uc(uc_handle, UC_UpMove, g_usercmd_recordings[id][index][3]);*/

    new buttons = g_usercmd_recordings[id][index][RECORD_BUTTONS];

    entity_set_int(id, EV_INT_button, buttons);
    entity_set_int(id, EV_INT_oldbuttons, g_usercmd_recordings[id][index][RECORD_OLD_BUTTONS]);
    entity_set_int(id, EV_INT_flags, g_usercmd_recordings[id][index][RECORD_ENT_FLAGS]);

    if (g_last_replay_buttons[id] != buttons) {
        new w_pressed = (buttons & IN_FORWARD) != 0;
        new a_pressed = (buttons & IN_MOVELEFT) != 0;
        new s_pressed = (buttons & IN_BACK) != 0;
        new d_pressed = (buttons & IN_MOVERIGHT) != 0;

        new keys[5];
        format(keys, sizeof(keys), "%s%s%s%s",
            a_pressed ? "A" : "_",
            w_pressed ? "W" : "_",
            s_pressed ? "S" : "_",
            d_pressed ? "D" : "_");

        set_hudmessage(255, 255, 255, 0.5, 0.6, 0, 0.1, 5.0, 0.0, 0.0, HUD_CHANNEL + 1);
        show_hudmessage(id, keys);
    }

    g_last_replay_buttons[id] = buttons;

    new Float:movedir[3];
    movedir[0] = Float:g_usercmd_recordings[id][index][RECORD_MOVEDIR_X];
    movedir[1] = Float:g_usercmd_recordings[id][index][RECORD_MOVEDIR_Y];
    movedir[2] = Float:g_usercmd_recordings[id][index][RECORD_MOVEDIR_Z];

    entity_set_vector(id, EV_VEC_movedir, movedir);

    new Float:angles[3];
    angles[0] = Float:g_usercmd_recordings[id][index][RECORD_ANGLES_X];
    angles[1] = Float:g_usercmd_recordings[id][index][RECORD_ANGLES_Y];
    angles[2] = Float:g_usercmd_recordings[id][index][RECORD_ANGLES_Z];


    //set_uc(uc_handle, UC_ViewAngles, angles);
    entity_set_vector(id, EV_VEC_angles, angles);

    angles[0] = Float:g_usercmd_recordings[id][index][RECORD_V_ANGLE_X];
    angles[1] = Float:g_usercmd_recordings[id][index][RECORD_V_ANGLE_Y];
    angles[2] = Float:g_usercmd_recordings[id][index][RECORD_V_ANGLE_Z];
    entity_set_vector(id, EV_VEC_v_angle, angles);

    // Send the SVC_SETANGLE message
    // We dont set EV_INT_fixangle because it causes bugs
    if (!in_post && !g_replay_pause[id]) {
        new Float:pitch = floatmul(angles[0] + 360.0, 65536.0 / 360.0);
        new Float:yaw = floatmul(angles[1] + 360.0, 65536.0 / 360.0);
        new short_pitch = floatround(pitch);
        new short_yaw = floatround(yaw);

        message_begin(MSG_ONE_UNRELIABLE, SVC_SETANGLE, _, id);
        write_short(short_pitch);
        write_short(short_yaw); // Yaw (left/right)
        write_short(0); // Roll (tilt)
        message_end();
    }

    new Float:pos[3];
    pos[0] = Float:g_usercmd_recordings[id][index][RECORD_POS_X];
    pos[1] = Float:g_usercmd_recordings[id][index][RECORD_POS_Y];
    pos[2] = Float:g_usercmd_recordings[id][index][RECORD_POS_Z];

    entity_set_vector(id, EV_VEC_origin, pos);

    new Float:vel[3];
    vel[0] = Float:g_usercmd_recordings[id][index][RECORD_VEL_X];
    vel[1] = Float:g_usercmd_recordings[id][index][RECORD_VEL_Y];
    vel[2] = Float:g_usercmd_recordings[id][index][RECORD_VEL_Z];

    fm_set_user_velocity(id, vel);

    new Float:vec_temp[3];

    vec_temp[0] = Float:g_usercmd_recordings[id][index][RECORD_VEC_USER1_X];
    vec_temp[1] = Float:g_usercmd_recordings[id][index][RECORD_VEC_USER1_Y];
    vec_temp[2] = Float:g_usercmd_recordings[id][index][RECORD_VEC_USER1_Z];
    entity_set_vector(id, EV_VEC_vuser1, vec_temp);

    vec_temp[0] = Float:g_usercmd_recordings[id][index][RECORD_VEC_USER2_X];
    vec_temp[1] = Float:g_usercmd_recordings[id][index][RECORD_VEC_USER2_Y];
    vec_temp[2] = Float:g_usercmd_recordings[id][index][RECORD_VEC_USER2_Z];
    entity_set_vector(id, EV_VEC_vuser2, vec_temp);

    vec_temp[0] = Float:g_usercmd_recordings[id][index][RECORD_VEC_USER3_X];
    vec_temp[1] = Float:g_usercmd_recordings[id][index][RECORD_VEC_USER3_Y];
    vec_temp[2] = Float:g_usercmd_recordings[id][index][RECORD_VEC_USER3_Z];
    entity_set_vector(id, EV_VEC_vuser3, vec_temp);

    vec_temp[0] = Float:g_usercmd_recordings[id][index][RECORD_VEC_USER4_X];
    vec_temp[1] = Float:g_usercmd_recordings[id][index][RECORD_VEC_USER4_Y];
    vec_temp[2] = Float:g_usercmd_recordings[id][index][RECORD_VEC_USER4_Z];
    entity_set_vector(id, EV_VEC_vuser4, vec_temp);

    entity_set_float(id, EV_FL_fuser1, Float:g_usercmd_recordings[id][index][RECORD_FL_USER1]);
    entity_set_float(id, EV_FL_fuser2, Float:g_usercmd_recordings[id][index][RECORD_FL_USER2]);
    entity_set_float(id, EV_FL_fuser3, Float:g_usercmd_recordings[id][index][RECORD_FL_USER3]);
    entity_set_float(id, EV_FL_fuser4, Float:g_usercmd_recordings[id][index][RECORD_FL_USER4]);

    if (!g_replay_pause[id]) {
        g_current_replay_indices[id] = original_index + 1;
    }
}

public CmdStart(id, cmd, random_seed) {
    if (!is_user_connected(id) || !is_user_alive(id)) {
        return FMRES_IGNORED;
    }

    ShowVelocityHUD(id);
    //ReplayUserCmd(id, cmd, random_seed);

    new buttons = get_uc(cmd, UC_Buttons)

    new flags = pev(id, pev_flags)
    new bool:on_ground = (flags & FL_ONGROUND) != 0;
    new bool:sliding = (flags & 0x4000) != 0;

    if (buttons & IN_JUMP && on_ground && !sliding) {
        new Float:vel[3] = {0.0, 0.0, 0.0};
        fm_get_user_velocity(id, vel);

        new Float:veclen = vector_length(vel);

        // Stops player from losing speed due to exceeding speed cap when jumping
        // We just set their speed to speed cap instead
        if (veclen >= 560) {
            new Float:vecdir[3];
            xs_vec_normalize(vel, vecdir);
            
            new Float:scaledvel[3] = {560.0, 560.0, 560.0};
            scaledvel[0] *= vecdir[0];
            scaledvel[1] *= vecdir[1];
            scaledvel[2] *= vecdir[2];
            fm_set_user_velocity(id, scaledvel);


            new velstr[64];
            format(velstr, charsmax(velstr), "Velocity: %.2f", veclen);
            client_print(id, print_chat, velstr);

            new flagstr[64];
            format(flagstr, charsmax(flagstr), "Flags: %x", flags);

            client_print(id, print_chat, flagstr);
        }
    } else if (buttons & IN_JUMP && !on_ground && g_last_on_ground_state[id]) {
        if (g_speed_boost_enabled[id]) {
            new Float:vel[3] = {0.0, 0.0, 0.0};
            fm_get_user_velocity(id, vel);

            new Float:vel2d[3] = {0.0, 0.0, 0.0};
            vel2d[0] = vel[0];
            vel2d[1] = vel[1];

            new Float:veclen = vector_length(vel2d);

            if (veclen >= 256.0) {
                new Float:vecdir[3];
                xs_vec_normalize(vel2d, vecdir);

                new Float:scaledvel[3] = {560.0, 560.0, 0.0};
                scaledvel[0] *= vecdir[0];
                scaledvel[1] *= vecdir[1];
                scaledvel[2] = vel[2];
                //scaledvel[2] *= vecdir[2];

                fm_set_user_velocity(id, scaledvel);
            }
        }
    }

    g_last_on_ground_state[id] = on_ground;

    //RecordUserCmd(id, cmd, random_seed); 

    if (IsReplaying(id)) {
        return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
}

public PlayerPreThink(id) {
    if (!is_user_alive(id)) {
        return FMRES_IGNORED;
    }

    if (IsRecording(id)) {
        RecordEntity(id);
    } else if (IsReplaying(id)) {
        ReplayEntity(id, false);
    }

    return FMRES_IGNORED;
}

public PlayerPostThink(id) {
    if (!is_user_alive(id)) {
        return FMRES_IGNORED;
    }

    if (IsReplaying(id)) {
        if (g_current_replay_indices[id] > 0) {
            if (!g_replay_pause[id]) {
                g_current_replay_indices[id]--;
            }

            ReplayEntity(id, true);
        }
    }

    return FMRES_IGNORED;
}