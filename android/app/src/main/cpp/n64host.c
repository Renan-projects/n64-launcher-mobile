#include <jni.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <EGL/egl.h>
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
#define RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY 9
#define RETRO_ENVIRONMENT_SET_PIXEL_FORMAT 10
#define RETRO_ENVIRONMENT_SET_HW_RENDER 14
#define RETRO_ENVIRONMENT_GET_VARIABLE 15
#define RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE 17
#define RETRO_ENVIRONMENT_GET_LOG_INTERFACE 27
#define RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY 31

struct retro_log_callback { void (*log)(int level, const char *fmt, ...); };

static void core_log(int level, const char *fmt, ...) {
    (void) level;
    va_list ap;
    va_start(ap, fmt);
    __android_log_vprint(ANDROID_LOG_INFO, "n64core", fmt, ap);
    va_end(ap);
}

#define RETRO_HW_FRAME_BUFFER_VALID ((void *) -1)

typedef void (*retro_proc_address_t)(void);
typedef retro_proc_address_t (*retro_hw_get_proc_address_t)(const char *sym);
typedef uintptr_t (*retro_hw_get_current_framebuffer_t)(void);
typedef void (*retro_hw_context_reset_t)(void);

struct retro_hw_render_callback {
    unsigned context_type;
    retro_hw_context_reset_t context_reset;
    retro_hw_get_current_framebuffer_t get_current_framebuffer;
    retro_hw_get_proc_address_t get_proc_address;
    bool depth;
    bool stencil;
    bool bottom_left_origin;
    unsigned version_major;
    unsigned version_minor;
    bool cache_context;
    retro_hw_context_reset_t context_destroy;
    bool debug_context;
};

struct retro_game_info {
    const char *path;
    const void *data;
    size_t size;
    const char *meta;
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
};

static struct core g_core;
static struct retro_hw_render_callback g_hw;
static bool g_have_hw = false;

static char g_core_path[1024];
static char g_rom_path[1024];
static char g_system_dir[1024];
static char g_save_dir[1024];

static volatile bool g_want_load = false;
static volatile bool g_loaded = false;
static volatile bool g_gl_ready = false;
static volatile bool g_paused = false;

static volatile int g_buttons = 0;
static volatile float g_stick_x = 0.0f;
static volatile float g_stick_y = 0.0f;

static char g_pending_save[1024];
static char g_pending_load[1024];
static volatile bool g_do_save = false;
static volatile bool g_do_load = false;

static void *g_gles_lib = NULL;

static retro_proc_address_t proc_address(const char *sym) {
    void *p = (void *) eglGetProcAddress(sym);
    if (!p) {
        if (!g_gles_lib) {
            g_gles_lib = dlopen("libGLESv3.so", RTLD_NOW | RTLD_GLOBAL);
            if (!g_gles_lib) g_gles_lib = dlopen("libGLESv2.so", RTLD_NOW | RTLD_GLOBAL);
        }
        if (g_gles_lib) p = dlsym(g_gles_lib, sym);
    }
    if (!p) LOGE("proc_address NULL for %s", sym);
    return (retro_proc_address_t) p;
}

static uintptr_t current_framebuffer(void) {
    return 0;
}

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
        case RETRO_ENVIRONMENT_SET_HW_RENDER: {
            struct retro_hw_render_callback *hw = data;
            hw->get_current_framebuffer = current_framebuffer;
            hw->get_proc_address = proc_address;
            g_hw = *hw;
            g_have_hw = true;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            *(bool *) data = false;
            return true;
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
            ((struct retro_log_callback *) data)->log = core_log;
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
    return g_core.retro_run && g_core.retro_load_game && g_core.retro_init;
}

static bool startup(void) {
    if (!load_core(g_core_path)) return false;

    g_core.retro_set_environment(env_cb);
    g_core.retro_set_video_refresh(video_cb);
    g_core.retro_set_audio_sample(audio_sample_cb);
    g_core.retro_set_audio_sample_batch(audio_batch_cb);
    g_core.retro_set_input_poll(input_poll_cb);
    g_core.retro_set_input_state(input_state_cb);
    g_core.retro_init();

    struct retro_game_info info;
    memset(&info, 0, sizeof(info));
    info.path = g_rom_path;
    if (!g_core.retro_load_game(&info)) {
        LOGE("retro_load_game failed");
        return false;
    }
    if (g_have_hw && g_hw.context_reset) g_hw.context_reset();
    return true;
}

static void teardown(void) {
    if (!g_core.handle) return;
    if (g_have_hw && g_hw.context_destroy) g_hw.context_destroy();
    if (g_loaded && g_core.retro_unload_game) g_core.retro_unload_game();
    if (g_core.retro_deinit) g_core.retro_deinit();
    dlclose(g_core.handle);
    memset(&g_core, 0, sizeof(g_core));
    g_have_hw = false;
    g_loaded = false;
}

static void write_file(const char *path, const void *data, size_t size) {
    FILE *f = fopen(path, "wb");
    if (!f) return;
    fwrite(data, 1, size, f);
    fclose(f);
}

static void do_save(const char *path) {
    if (!g_loaded || !g_core.retro_serialize_size) return;
    size_t size = g_core.retro_serialize_size();
    if (size == 0) return;
    void *buffer = malloc(size);
    if (!buffer) return;
    if (g_core.retro_serialize(buffer, size)) write_file(path, buffer, size);
    free(buffer);
}

static bool do_load(const char *path) {
    if (!g_loaded || !g_core.retro_unserialize) return false;
    FILE *f = fopen(path, "rb");
    if (!f) return false;
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
    return ok;
}

#define FN(name) Java_org_renanprojects_n64_1launcher_1mobile_NativeLib_##name

JNIEXPORT void JNICALL
FN(nativeSetPaths)(JNIEnv *env, jobject thiz, jstring corePath, jstring romPath,
                   jstring systemDir, jstring saveDir) {
    const char *core = (*env)->GetStringUTFChars(env, corePath, NULL);
    const char *rom = (*env)->GetStringUTFChars(env, romPath, NULL);
    const char *sys = (*env)->GetStringUTFChars(env, systemDir, NULL);
    const char *save = (*env)->GetStringUTFChars(env, saveDir, NULL);
    strncpy(g_core_path, core, sizeof(g_core_path) - 1);
    strncpy(g_rom_path, rom, sizeof(g_rom_path) - 1);
    strncpy(g_system_dir, sys, sizeof(g_system_dir) - 1);
    strncpy(g_save_dir, save, sizeof(g_save_dir) - 1);
    (*env)->ReleaseStringUTFChars(env, corePath, core);
    (*env)->ReleaseStringUTFChars(env, romPath, rom);
    (*env)->ReleaseStringUTFChars(env, systemDir, sys);
    (*env)->ReleaseStringUTFChars(env, saveDir, save);
    g_want_load = true;
    g_paused = false;
}

JNIEXPORT void JNICALL
FN(nativeOnSurfaceCreated)(JNIEnv *env, jobject thiz) {
    g_gl_ready = true;
}

JNIEXPORT void JNICALL
FN(nativeOnSurfaceChanged)(JNIEnv *env, jobject thiz, jint width, jint height) {
    (void) width;
    (void) height;
}

JNIEXPORT void JNICALL
FN(nativeRunFrame)(JNIEnv *env, jobject thiz) {
    if (g_want_load && g_gl_ready && !g_loaded) {
        g_loaded = startup();
        g_want_load = false;
        if (!g_loaded) teardown();
        return;
    }
    if (!g_loaded || g_paused) return;

    if (g_do_load) {
        do_load(g_pending_load);
        g_do_load = false;
    }
    if (g_do_save) {
        do_save(g_pending_save);
        g_do_save = false;
    }

    g_core.retro_run();
}

JNIEXPORT void JNICALL
FN(nativeOnSurfaceDestroyed)(JNIEnv *env, jobject thiz) {
    g_gl_ready = false;
    teardown();
}

JNIEXPORT void JNICALL
FN(nativeStop)(JNIEnv *env, jobject thiz) {
    g_want_load = false;
    g_paused = true;
}

JNIEXPORT void JNICALL
FN(nativePause)(JNIEnv *env, jobject thiz, jboolean paused) {
    g_paused = paused == JNI_TRUE;
}

JNIEXPORT void JNICALL
FN(nativeReset)(JNIEnv *env, jobject thiz) {
    if (g_loaded && g_core.retro_reset) g_core.retro_reset();
}

JNIEXPORT void JNICALL
FN(nativeSetInput)(JNIEnv *env, jobject thiz, jint buttons, jfloat stickX, jfloat stickY) {
    g_buttons = buttons;
    g_stick_x = stickX;
    g_stick_y = stickY;
}

JNIEXPORT void JNICALL
FN(nativeSaveState)(JNIEnv *env, jobject thiz, jstring path) {
    const char *file = (*env)->GetStringUTFChars(env, path, NULL);
    strncpy(g_pending_save, file, sizeof(g_pending_save) - 1);
    (*env)->ReleaseStringUTFChars(env, path, file);
    g_do_save = true;
}

JNIEXPORT jboolean JNICALL
FN(nativeLoadState)(JNIEnv *env, jobject thiz, jstring path) {
    const char *file = (*env)->GetStringUTFChars(env, path, NULL);
    strncpy(g_pending_load, file, sizeof(g_pending_load) - 1);
    (*env)->ReleaseStringUTFChars(env, path, file);
    g_do_load = true;
    return JNI_TRUE;
}
