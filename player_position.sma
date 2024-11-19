#include <amxmodx>
#include <fakemeta_util>
#include <fakemeta_const>
#include <fakemeta>
#include <hamsandwich>
#include <engine>

#define MAX_PLAYERS 32
#define MAX_RECORDING_DURATION 2048

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

    RegisterHam(Ham_TakeDamage, "player", "OnTakeDamage");
    register_forward(FM_CmdStart, "CmdStart");
    register_forward(FM_PlayerPreThink, "PlayerPreThink");
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
    new len = format(msg, 128, "Player %s is at position: X: %f, Y: %f, Z: %f",
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

new const HUD_CHANNEL = 4; // Use a specific HUD channel for messages

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

public IsRecording(id) {
    return g_is_recording[id];
}

public IsReplaying(id) {
    return g_is_replaying[id];
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

public InitializeReplay(id) {
    if (!is_user_alive(id)) {
        client_print(id, print_chat, "You must be alive to replay.");
        return PLUGIN_HANDLED;
    }

    StopRecording(id);

    if (IsReplaying(id)) {
        client_print(id, print_chat, "Already replaying!");
        return PLUGIN_HANDLED;
    }

    if (g_recording_durations[id] == 0) {
        client_print(id, print_chat, "No recording found!");
        return PLUGIN_HANDLED;
    }

    g_is_replaying[id] = true;
    g_is_recording[id] = false;
    g_record_start_ticks[id] = 0;
    g_replay_start_ticks[id] = 0;
    g_current_replay_indices[id] = 0;

    client_print(id, print_chat, "Replay initialized!");

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

    new movedir[3];
    /*g_usercmd_recordings[id][index][1] = get_uc(uc_handle, UC_ForwardMove);
    g_usercmd_recordings[id][index][2] = get_uc(uc_handle, UC_SideMove);
    g_usercmd_recordings[id][index][3] = get_uc(uc_handle, UC_UpMove);*/
    entity_get_vector(id, EV_VEC_movedir, movedir);

    g_usercmd_recordings[id][index][RECORD_MOVEDIR_X] = movedir[0];
    g_usercmd_recordings[id][index][RECORD_MOVEDIR_Y] = movedir[1];
    g_usercmd_recordings[id][index][RECORD_MOVEDIR_Z] = movedir[2];
    
    new angles[3];
    /*get_uc(uc_handle, UC_ViewAngles, angles); 
    g_usercmd_recordings[id][index][4] = angles[0];
    g_usercmd_recordings[id][index][5] = angles[1];
    g_usercmd_recordings[id][index][6] = angles[2];*/

    entity_get_vector(id, EV_VEC_angles, angles);

    g_usercmd_recordings[id][index][RECORD_ANGLES_X] = angles[0];
    g_usercmd_recordings[id][index][RECORD_ANGLES_Y] = angles[1];
    g_usercmd_recordings[id][index][RECORD_ANGLES_Z] = angles[2];

    entity_get_vector(id, EV_VEC_v_angle, angles);

    g_usercmd_recordings[id][index][RECORD_V_ANGLE_X] = angles[0];
    g_usercmd_recordings[id][index][RECORD_V_ANGLE_Y] = angles[1];
    g_usercmd_recordings[id][index][RECORD_V_ANGLE_Z] = angles[2];

    new pos[3];
    entity_get_vector(id, EV_VEC_origin, pos);

    g_usercmd_recordings[id][index][RECORD_POS_X] = pos[0];
    g_usercmd_recordings[id][index][RECORD_POS_Y] = pos[1];
    g_usercmd_recordings[id][index][RECORD_POS_Z] = pos[2];

    new vel[3];
    fm_get_user_velocity(id, vel);

    g_usercmd_recordings[id][index][RECORD_VEL_X] = vel[0];
    g_usercmd_recordings[id][index][RECORD_VEL_Y] = vel[1];
    g_usercmd_recordings[id][index][RECORD_VEL_Z] = vel[2];

    new vec_temp[3];

    entity_get_vector(id, EV_VEC_vuser1, vec_temp);
    g_usercmd_recordings[id][index][RECORD_VEC_USER1_X] = vec_temp[0];
    g_usercmd_recordings[id][index][RECORD_VEC_USER1_Y] = vec_temp[1];
    g_usercmd_recordings[id][index][RECORD_VEC_USER1_Z] = vec_temp[2];

    entity_get_vector(id, EV_VEC_vuser2, vec_temp);
    g_usercmd_recordings[id][index][RECORD_VEC_USER2_X] = vec_temp[0];
    g_usercmd_recordings[id][index][RECORD_VEC_USER2_Y] = vec_temp[1];
    g_usercmd_recordings[id][index][RECORD_VEC_USER2_Z] = vec_temp[2];

    entity_get_vector(id, EV_VEC_vuser3, vec_temp);
    g_usercmd_recordings[id][index][RECORD_VEC_USER3_X] = vec_temp[0];
    g_usercmd_recordings[id][index][RECORD_VEC_USER3_Y] = vec_temp[1];
    g_usercmd_recordings[id][index][RECORD_VEC_USER3_Z] = vec_temp[2];

    entity_get_vector(id, EV_VEC_vuser4, vec_temp);
    g_usercmd_recordings[id][index][RECORD_VEC_USER4_X] = vec_temp[0];
    g_usercmd_recordings[id][index][RECORD_VEC_USER4_Y] = vec_temp[1];
    g_usercmd_recordings[id][index][RECORD_VEC_USER4_Z] = vec_temp[2];



    g_recording_durations[id] = index + 1;
}

public ReplayEntity(id) {
    if (IsRecording(id) || !IsReplaying(id)) {
        return;
    }

    if (g_replay_start_ticks[id] == 0) {
        //g_replay_start_ticks[id] = random_seed; // Initialize start tick on the first frame
        g_replay_start_ticks[id] = tickcount();
        client_print(id, print_chat, "Replay started!");

        entity_set_vector(id, EV_VEC_origin, g_recording_start_positions[id]);
    }

    new index = g_current_replay_indices[id];
    if (index >= MAX_RECORDING_DURATION || index >= g_recording_durations[id]) {
        client_print(id, print_chat, "Replay finished!");
        g_is_replaying[id] = false;
        g_replay_start_ticks[id] = 0;
        return;
    }

    /*set_uc(uc_handle, UC_Buttons, g_usercmd_recordings[id][index][0]);
    set_uc(uc_handle, UC_ForwardMove, g_usercmd_recordings[id][index][1]);
    set_uc(uc_handle, UC_SideMove, g_usercmd_recordings[id][index][2]);
    set_uc(uc_handle, UC_UpMove, g_usercmd_recordings[id][index][3]);*/

    entity_set_int(id, EV_INT_button, g_usercmd_recordings[id][index][RECORD_BUTTONS]);
    entity_set_int(id, EV_INT_oldbuttons, g_usercmd_recordings[id][index][RECORD_OLD_BUTTONS]);
    entity_set_int(id, EV_INT_flags, g_usercmd_recordings[id][index][RECORD_ENT_FLAGS]);

    new movedir[3];
    movedir[0] = g_usercmd_recordings[id][index][RECORD_MOVEDIR_X];
    movedir[1] = g_usercmd_recordings[id][index][RECORD_MOVEDIR_Y];
    movedir[2] = g_usercmd_recordings[id][index][RECORD_MOVEDIR_Z];

    entity_set_vector(id, EV_VEC_movedir, movedir);

    new angles[3];
    angles[0] = g_usercmd_recordings[id][index][RECORD_ANGLES_X];
    angles[1] = g_usercmd_recordings[id][index][RECORD_ANGLES_Y];
    angles[2] = g_usercmd_recordings[id][index][RECORD_ANGLES_Z];

    //set_uc(uc_handle, UC_ViewAngles, angles);
    entity_set_vector(id, EV_VEC_angles, angles);

    angles[0] = g_usercmd_recordings[id][index][RECORD_V_ANGLE_X];
    angles[1] = g_usercmd_recordings[id][index][RECORD_V_ANGLE_Y];
    angles[2] = g_usercmd_recordings[id][index][RECORD_V_ANGLE_Z];

    entity_set_vector(id, EV_VEC_v_angle, angles);

    new pos[3];
    pos[0] = g_usercmd_recordings[id][index][RECORD_POS_X];
    pos[1] = g_usercmd_recordings[id][index][RECORD_POS_Y];
    pos[2] = g_usercmd_recordings[id][index][RECORD_POS_Z];

    entity_set_vector(id, EV_VEC_origin, pos);

    new vel[3];
    vel[0] = g_usercmd_recordings[id][index][RECORD_VEL_X];
    vel[1] = g_usercmd_recordings[id][index][RECORD_VEL_Y];
    vel[2] = g_usercmd_recordings[id][index][RECORD_VEL_Z];

    fm_set_user_velocity(id, vel);

    new vec_temp[3];

    vec_temp[0] = g_usercmd_recordings[id][index][RECORD_VEC_USER1_X];
    vec_temp[1] = g_usercmd_recordings[id][index][RECORD_VEC_USER1_Y];
    vec_temp[2] = g_usercmd_recordings[id][index][RECORD_VEC_USER1_Z];
    entity_set_vector(id, EV_VEC_vuser1, vec_temp);

    vec_temp[0] = g_usercmd_recordings[id][index][RECORD_VEC_USER2_X];
    vec_temp[1] = g_usercmd_recordings[id][index][RECORD_VEC_USER2_Y];
    vec_temp[2] = g_usercmd_recordings[id][index][RECORD_VEC_USER2_Z];
    entity_set_vector(id, EV_VEC_vuser2, vec_temp);

    vec_temp[0] = g_usercmd_recordings[id][index][RECORD_VEC_USER3_X];
    vec_temp[1] = g_usercmd_recordings[id][index][RECORD_VEC_USER3_Y];
    vec_temp[2] = g_usercmd_recordings[id][index][RECORD_VEC_USER3_Z];
    entity_set_vector(id, EV_VEC_vuser3, vec_temp);

    vec_temp[0] = g_usercmd_recordings[id][index][RECORD_VEC_USER4_X];
    vec_temp[1] = g_usercmd_recordings[id][index][RECORD_VEC_USER4_Y];
    vec_temp[2] = g_usercmd_recordings[id][index][RECORD_VEC_USER4_Z];
    entity_set_vector(id, EV_VEC_vuser4, vec_temp);

    g_current_replay_indices[id] = index + 1;
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

    if (buttons & IN_JUMP && on_ground) {
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

    if (g_is_replaying[id]) {
        return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
}

public PlayerPreThink(id) {
    if (!is_user_alive(id)) {
        return FMRES_IGNORED;
    }

    // Testing
    //entity_set_int(id, EV_INT_button, entity_get_int(id, EV_INT_button) & ~IN_JUMP);

    if (IsRecording(id)) {
        RecordEntity(id);
    } else if (IsReplaying(id)) {
        ReplayEntity(id);
    }

    return FMRES_IGNORED;
}