/*
 * steam-wifi-fix.c — 32-bit LD_PRELOAD shim for Steam Game Mode on Void Linux.
 *
 * Resolves a critical race condition and property bug in Valve's NetworkManager
 * client implementation inside 32-bit steamclient.so:
 *
 * 1. Property Bug: In UpdateOrCreateConnection (steamclient.so), Valve attempts
 *    to set "autoconnect" to 0 on an NMSimpleConnection instance. Because
 *    "autoconnect" is a property of NMSettingConnection (not NMSimpleConnection),
 *    GLib logs "object class 'NMSimpleConnection' has no property named 'autoconnect'"
 *    and the property remains TRUE by default.
 *
 * 2. Background Race: On fast Wi-Fi chips (e.g. MediaTek MT7922 / Wi-Fi 6E),
 *    NetworkManager auto-connects to the access point immediately upon profile
 *    creation (within 200 ms) before Steam initiates ActivateConnection.
 *
 * 3. Deadlock / Infinite Spinner: In OnConnectionActivated, Steam registers a
 *    GObject signal listener on "notify::state" and blocks in:
 *        while (!ctx.event.Check()) g_main_context_iteration(ctx, 1);
 *    while holding the internal network manager mutex. In GObject, "notify"
 *    signals only fire on value transitions. If the connection is already in
 *    NM_ACTIVE_CONNECTION_STATE_ACTIVATED (2), no state change occurs, the event
 *    is never set, and Steam hangs indefinitely on the Wi-Fi spinner.
 *
 * This shim intercepts:
 *   - g_object_set / g_object_get: Redirects "autoconnect" to the underlying
 *     NMSettingConnection so Valve's intended autoconnect=0 is respected.
 *   - nm_client_add_connection_async: Ensures autoconnect is set to FALSE before
 *     the new profile is registered with NetworkManager.
 *   - g_signal_connect_data: If "notify::state" is hooked on an NMActiveConnection
 *     that is already in a terminal state (state >= 2, i.e. ACTIVATED or
 *     DEACTIVATED), immediately invokes the callback to awaken Steam's event loop.
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stdbool.h>

typedef void *gpointer;
typedef const char gchar;
typedef unsigned long gulong;
typedef size_t gsize;
typedef gsize GType;
typedef struct _GTypeInstance GTypeInstance;
typedef void (*GCallback)(void);
typedef void (*GClosureNotify)(gpointer data, void *closure);
typedef int GConnectFlags;

/* Dynamic symbol pointers */
static void (*real_g_object_set)(gpointer object, const gchar *first_property_name, ...) = NULL;
static void (*real_g_object_set_valist)(gpointer object, const gchar *first_property_name, va_list var_args) = NULL;
static void (*real_g_object_get_valist)(gpointer object, const gchar *first_property_name, va_list var_args) = NULL;
static gulong (*real_g_signal_connect_data)(gpointer instance, const gchar *detailed_signal, GCallback c_handler, gpointer data, GClosureNotify destroy_data, GConnectFlags connect_flags) = NULL;
static void (*real_nm_client_add_connection_async)(void *client, void *connection, int save_to_disk, void *cancellable, void *callback, void *user_data) = NULL;

static GType (*sym_nm_active_connection_get_type)(void) = NULL;
static int (*sym_nm_active_connection_get_state)(gpointer active_connection) = NULL;
static gpointer (*sym_nm_connection_get_setting_connection)(gpointer connection) = NULL;
static gpointer (*sym_nm_setting_connection_new)(void) = NULL;
static void (*sym_nm_connection_add_setting)(gpointer connection, gpointer setting) = NULL;
static int (*sym_g_type_check_instance_is_a)(GTypeInstance *type_instance, GType iface_type) = NULL;

static void log_msg(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    fprintf(stderr, "[steam-wifi-fix] ");
    vfprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
    va_end(args);
}

/* Helper to locate or create NMSettingConnection for an NMConnection */
static gpointer get_or_create_setting_connection(gpointer connection)
{
    if (!sym_nm_connection_get_setting_connection)
        sym_nm_connection_get_setting_connection = dlsym(RTLD_DEFAULT, "nm_connection_get_setting_connection");

    if (!sym_nm_connection_get_setting_connection)
        return NULL;

    gpointer s_con = sym_nm_connection_get_setting_connection(connection);
    if (!s_con) {
        if (!sym_nm_setting_connection_new)
            sym_nm_setting_connection_new = dlsym(RTLD_DEFAULT, "nm_setting_connection_new");
        if (!sym_nm_connection_add_setting)
            sym_nm_connection_add_setting = dlsym(RTLD_DEFAULT, "nm_connection_add_setting");

        if (sym_nm_setting_connection_new && sym_nm_connection_add_setting) {
            s_con = sym_nm_setting_connection_new();
            sym_nm_connection_add_setting(connection, s_con);
        }
    }
    return s_con;
}

/* Intercept g_object_set to fix Valve's call on NMSimpleConnection */
void g_object_set(gpointer object, const gchar *first_property_name, ...)
{
    if (!real_g_object_set_valist)
        real_g_object_set_valist = dlsym(RTLD_DEFAULT, "g_object_set_valist");

    gpointer target = object;

    if (object && first_property_name && strcmp(first_property_name, "autoconnect") == 0) {
        gpointer s_con = get_or_create_setting_connection(object);
        if (s_con) {
            target = s_con;
            log_msg("Redirected g_object_set('autoconnect') to NMSettingConnection %p", s_con);
        }
    }

    va_list args;
    va_start(args, first_property_name);
    if (real_g_object_set_valist) {
        real_g_object_set_valist(target, first_property_name, args);
    }
    va_end(args);
}

/* Intercept g_object_get to fix Valve's call on NMSimpleConnection */
void g_object_get(gpointer object, const gchar *first_property_name, ...)
{
    if (!real_g_object_get_valist)
        real_g_object_get_valist = dlsym(RTLD_DEFAULT, "g_object_get_valist");

    gpointer target = object;

    if (object && first_property_name && strcmp(first_property_name, "autoconnect") == 0) {
        gpointer s_con = get_or_create_setting_connection(object);
        if (s_con) {
            target = s_con;
            log_msg("Redirected g_object_get('autoconnect') to NMSettingConnection %p", s_con);
        }
    }

    va_list args;
    va_start(args, first_property_name);
    if (real_g_object_get_valist) {
        real_g_object_get_valist(target, first_property_name, args);
    }
    va_end(args);
}

/* Intercept nm_client_add_connection_async to prevent auto-activation before explicit connect */
void nm_client_add_connection_async(void *client, void *connection, int save_to_disk, void *cancellable, void *callback, void *user_data)
{
    if (!real_nm_client_add_connection_async)
        real_nm_client_add_connection_async = dlsym(RTLD_NEXT, "nm_client_add_connection_async");

    if (connection) {
        if (!real_g_object_set)
            real_g_object_set = dlsym(RTLD_DEFAULT, "g_object_set");

        gpointer s_con = get_or_create_setting_connection(connection);
        if (s_con && real_g_object_set) {
            log_msg("Ensured autoconnect=FALSE on connection %p before add", connection);
            real_g_object_set(s_con, "autoconnect", 0, NULL);
        }
    }

    if (real_nm_client_add_connection_async) {
        real_nm_client_add_connection_async(client, connection, save_to_disk, cancellable, callback, user_data);
    }
}

/* Intercept g_signal_connect_data to break the notify::state deadlock */
gulong g_signal_connect_data(gpointer instance,
                             const gchar *detailed_signal,
                             GCallback c_handler,
                             gpointer data,
                             GClosureNotify destroy_data,
                             GConnectFlags connect_flags)
{
    if (!real_g_signal_connect_data)
        real_g_signal_connect_data = dlsym(RTLD_NEXT, "g_signal_connect_data");

    gulong ret = 0;
    if (real_g_signal_connect_data)
        ret = real_g_signal_connect_data(instance, detailed_signal, c_handler, data, destroy_data, connect_flags);

    if (instance && detailed_signal && strcmp(detailed_signal, "notify::state") == 0) {
        if (!sym_nm_active_connection_get_type)
            sym_nm_active_connection_get_type = dlsym(RTLD_DEFAULT, "nm_active_connection_get_type");
        if (!sym_g_type_check_instance_is_a)
            sym_g_type_check_instance_is_a = dlsym(RTLD_DEFAULT, "g_type_check_instance_is_a");
        if (!sym_nm_active_connection_get_state)
            sym_nm_active_connection_get_state = dlsym(RTLD_DEFAULT, "nm_active_connection_get_state");

        bool is_active_conn = false;
        if (sym_nm_active_connection_get_type && sym_g_type_check_instance_is_a) {
            GType act_type = sym_nm_active_connection_get_type();
            if (act_type && sym_g_type_check_instance_is_a((GTypeInstance *)instance, act_type)) {
                is_active_conn = true;
            }
        } else if (sym_nm_active_connection_get_state) {
            is_active_conn = true;
        }

        if (is_active_conn && sym_nm_active_connection_get_state && c_handler) {
            int state = sym_nm_active_connection_get_state(instance);
            /* NM_ACTIVE_CONNECTION_STATE_ACTIVATED = 2, DEACTIVATED = 4 */
            if (state >= 2) {
                log_msg("Active connection %p in state %d, triggering callback immediately", instance, state);
                ((void (*)(gpointer, gpointer, gpointer))c_handler)(instance, NULL, data);
            }
        }
    }

    return ret;
}
