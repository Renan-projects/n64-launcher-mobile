#include <jni.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <android/log.h>

#define LOG_TAG "n64host"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

#define RETRO_DEVICE_JOYPAD 1
#define RETRO_DEVICE_ANALOG 5
#define RETRO_DEVICE_INDEX_ANALOG_LEFT 0
#define RETRO_DEVICE_ID_ANALOG_X 0
#define RETRO_DEVICE_ID_ANALOG_Y 1

#define RETRO_ENVIRONMENT_GET_CAN_DUPE 3
#define RETRO_ENVIRONMENT_SET_PIXEL_FORMAT 10
#define RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY 9
#define RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY 31

struct retro_game_info {
    const char *path;
    const void *data;
    size_t size;
    const char *meta;
};

struct retro_system_av_info {
    struct {
        unsigned base_width;
        unsigned base_height;
        unsigned max_width;
        unsigned max_height;
        float aspect_ratio;
    } geometry;
    struct {
        double fps;
        double sample_rate;
    } timing;
};

typedef bool (*retro_environment_t)(unsigned, void *);
typedef void (*retro_video_refresh_t)(const void *, unsigned, unsigned, size_t);
typedef void (*retro_audio_sample_t)(int16_t, int16_t);
typedef size_t (*retro_audio_sample_batch_t)(const int16_t *, size_t);
typedef void (*retro_input_poll_t)(void);
typedef int16_t (*retro_input_state_t)(unsigned, unsigned, unsigned, unsigned);

struct core {
    void *handle;
    void (*retro_init)(void);
    void (*retro_deinit)(void);
    void (*retro_set_environment)(retro_environment_t);
    void (*retro_set_video_refresh)(retro_video_refresh_t);
    void (*retro_set_audio_sample)(retro_audio_sample_t);
    void (*retro_set_audio_sample_batch)(retro_audio_sample_batch_t);
    void (*retro_set_input_poll)(retro_input_poll_t);
    void (*retro_set_input_state)(retro_input_state_t);
    bool (*retro_load_game)(const struct retro_game_info *);
    void (*retro_unload_game)(void);
    void (*retro_run)(void);
    void (*retro_reset)(void);
    size_t (*retro_serialize_size)(void);
    bool (*retro_serialize)(void *, size_t);
    bool (*retro_unserialize)(const void *, size_t);
    void (*retro_get_system_av_info)(struct retro_system_av_info *);
};

static struct core g_core;
static pthread_t g_thread;
static volatile bool g_running = false;
static volatile bool g_paused = false;
static volatile int g_buttons = 0;
static volatile float g_stick_x = 0.0f;
static volatile float g_stick_y = 0.0f;
static char g_system_dir[1024];
static char g_save_dir[1024];

static bool env_cb(unsigned cmd, void *data) {
    switch (cmd) {
        case RETRO_ENVIRONMENT_GET_CAN_DUPE:
            *(bool *) data = true;
            return true;
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
            return true;
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
            *(const char **) data = g_system_dir;
            return true;
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            *(const char **) data = g_save_dir;
            return true;
        default:
            return false;
    }
}

static void video_cb(const void *data, unsigned w, unsigned h, size_t pitch) {
    (void) data;
    (void) w;
    (void) h;
    (void) pitch;
}

static void audio_sample_cb(int16_t l, int16_t r) {
    (void) l;
    (void) r;
}

static size_t audio_batch_cb(const int16_t *data, size_t frames) {
    (void) data;
    return frames;
}

static void input_poll_cb(void) {}

static int16_t input_state_cb(unsigned port, unsigned device, unsigned index, unsigned id) {
    if (port != 0) return 0;
    if (device == RETRO_DEVICE_JOYPAD) {
        return (g_buttons & (1 << id)) ? 1 : 0;
    }
    if (device == RETRO_DEVICE_ANALOG && index == RETRO_DEVICE_INDEX_ANALOG_LEFT) {
        if (id == RETRO_DEVICE_ID_ANALOG_X) return (int16_t) (g_stick_x * 32767.0f);
        if (id == RETRO_DEVICE_ID_ANALOG_Y) return (int16_t) (-g_stick_y * 32767.0f);
    }
    return 0;
}

static void *resolve(void *handle, const char *name) {
    void *sym = dlsym(handle, name);
    if (!sym) LOGE("missing symbol %s", name);
    return sym;
}

static bool load_core(const char *path) {
    g_core.handle = dlopen(path, RTLD_NOW);
    if (!g_core.handle) {
        LOGE("dlopen failed: %s", dlerror());
        return false;
    }
    g_core.retro_init = resolve(g_core.handle, "retro_init");
    g_core.retro_deinit = resolve(g_core.handle, "retro_deinit");
    g_core.retro_set_environment = resolve(g_core.handle, "retro_set_environment");
    g_core.retro_set_video_refresh = resolve(g_core.handle, "retro_set_video_refresh");
    g_core.retro_set_audio_sample = resolve(g_core.handle, "retro_set_audio_sample");
    g_core.retro_set_audio_sample_batch = resolve(g_core.handle, "retro_set_audio_sample_batch");
    g_core.retro_set_input_poll = resolve(g_core.handle, "retro_set_input_poll");
    g_core.retro_set_input_state = resolve(g_core.handle, "retro_set_input_state");
    g_core.retro_load_game = resolve(g_core.handle, "retro_load_game");
    g_core.retro_unload_game = resolve(g_core.handle, "retro_unload_game");
    g_core.retro_run = resolve(g_core.handle, "retro_run");
    g_core.retro_reset = resolve(g_core.handle, "retro_reset");
    g_core.retro_serialize_size = resolve(g_core.handle, "retro_serialize_size");
    g_core.retro_serialize = resolve(g_core.handle, "retro_serialize");
    g_core.retro_unserialize = resolve(g_core.handle, "retro_unserialize");
    g_core.retro_get_system_av_info = resolve(g_core.handle, "retro_get_system_av_info");
    return g_core.retro_run && g_core.retro_load_game && g_core.retro_init;
}

static void *run_loop(void *arg) {
    (void) arg;
    while (g_running) {
        if (!g_paused && g_core.retro_run) g_core.retro_run();
    }
    return NULL;
}

JNIEXPORT jboolean JNICALL
Java_org_renanprojects_n64_1launcher_1mobile_LibretroCore_nativeStart(
        JNIEnv *env, jobject thiz, jstring corePath, jstring romPath) {
    const char *core = (*env)->GetStringUTFChars(env, corePath, NULL);
    const char *rom = (*env)->GetStringUTFChars(env, romPath, NULL);

    bool ok = load_core(core);
    if (ok) {
        g_core.retro_set_environment(env_cb);
        g_core.retro_set_video_refresh(video_cb);
        g_core.retro_set_audio_sample(audio_sample_cb);
        g_core.retro_set_audio_sample_batch(audio_batch_cb);
        g_core.retro_set_input_poll(input_poll_cb);
        g_core.retro_set_input_state(input_state_cb);
        g_core.retro_init();

        struct retro_game_info info;
        memset(&info, 0, sizeof(info));
        info.path = rom;
        ok = g_core.retro_load_game(&info);
        if (ok) {
            g_running = true;
            g_paused = false;
            pthread_create(&g_thread, NULL, run_loop, NULL);
        }
    }

    (*env)->ReleaseStringUTFChars(env, corePath, core);
    (*env)->ReleaseStringUTFChars(env, romPath, rom);
    return ok ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_org_renanprojects_n64_1launcher_1mobile_LibretroCore_nativeStop(JNIEnv *env, jobject thiz) {
    if (!g_running) return;
    g_running = false;
    pthread_join(g_thread, NULL);
    if (g_core.retro_unload_game) g_core.retro_unload_game();
    if (g_core.retro_deinit) g_core.retro_deinit();
    if (g_core.handle) dlclose(g_core.handle);
    memset(&g_core, 0, sizeof(g_core));
}

JNIEXPORT void JNICALL
Java_org_renanprojects_n64_1launcher_1mobile_LibretroCore_nativePause(
        JNIEnv *env, jobject thiz, jboolean paused) {
    g_paused = paused == JNI_TRUE;
}

JNIEXPORT void JNICALL
Java_org_renanprojects_n64_1launcher_1mobile_LibretroCore_nativeReset(JNIEnv *env, jobject thiz) {
    if (g_running && g_core.retro_reset) g_core.retro_reset();
}

JNIEXPORT void JNICALL
Java_org_renanprojects_n64_1launcher_1mobile_LibretroCore_nativeSetInput(
        JNIEnv *env, jobject thiz, jint buttons, jfloat stickX, jfloat stickY) {
    g_buttons = buttons;
    g_stick_x = stickX;
    g_stick_y = stickY;
}

JNIEXPORT void JNICALL
Java_org_renanprojects_n64_1launcher_1mobile_LibretroCore_nativeSaveState(
        JNIEnv *env, jobject thiz, jstring path) {
    if (!g_running || !g_core.retro_serialize_size) return;
    size_t size = g_core.retro_serialize_size();
    if (size == 0) return;
    void *buffer = malloc(size);
    if (!buffer) return;
    if (g_core.retro_serialize(buffer, size)) {
        const char *file = (*env)->GetStringUTFChars(env, path, NULL);
        FILE *f = fopen(file, "wb");
        if (f) {
            fwrite(buffer, 1, size, f);
            fclose(f);
        }
        (*env)->ReleaseStringUTFChars(env, path, file);
    }
    free(buffer);
}

JNIEXPORT jboolean JNICALL
Java_org_renanprojects_n64_1launcher_1mobile_LibretroCore_nativeLoadState(
        JNIEnv *env, jobject thiz, jstring path) {
    if (!g_running || !g_core.retro_unserialize) return JNI_FALSE;
    const char *file = (*env)->GetStringUTFChars(env, path, NULL);
    FILE *f = fopen(file, "rb");
    (*env)->ReleaseStringUTFChars(env, path, file);
    if (!f) return JNI_FALSE;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    void *buffer = malloc(size);
    bool ok = false;
    if (buffer && fread(buffer, 1, size, f) == (size_t) size) {
        ok = g_core.retro_unserialize(buffer, size);
    }
    free(buffer);
    fclose(f);
    return ok ? JNI_TRUE : JNI_FALSE;
}
