#include <amxmodx>
#include <fakemeta_util>
#include <fakemeta_const>
#include <fakemeta>
#include <hamsandwich>
#include <engine>

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

    RegisterHam(Ham_TakeDamage, "player", "OnTakeDamage");
    register_forward(FM_CmdStart, "CmdStart");
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

public CmdStart(id, cmd, random_seed) {
    if (!is_user_connected(id) || !is_user_alive(id)) {
        return FMRES_IGNORED;
    }

    ShowVelocityHUD(id);

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

    return FMRES_IGNORED;
}
