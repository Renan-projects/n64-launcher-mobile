#include <jni.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <malloc.h>
#include <link.h>
#include <elf.h>
#include <sys/mman.h>
#include <unistd.h>
#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <SLES/OpenSLES.h>
#include <SLES/OpenSLES_Android.h>
#include <pthread.h>
#include <android/log.h>

#ifndef M_BIONIC_SET_HEAP_TAGGING_LEVEL
#define M_BIONIC_SET_HEAP_TAGGING_LEVEL (-206)
#endif
#ifndef M_HEAP_TAGGING_LEVEL_NONE
#define M_HEAP_TAGGING_LEVEL_NONE 0
#endif
#ifndef M_HEAP_TAGGING_LEVEL_TBI
#define M_HEAP_TAGGING_LEVEL_TBI 1
#endif

#define LOG_TAG "n64host"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

#define RETRO_DEVICE_JOYPAD 1
#define RETRO_DEVICE_ANALOG 5
#define RETRO_DEVICE_INDEX_ANALOG_LEFT 0
#define RETRO_DEVICE_INDEX_ANALOG_RIGHT 1
#define RETRO_DEVICE_ID_ANALOG_X 0
#define RETRO_DEVICE_ID_ANALOG_Y 1

#define RETRO_DEVICE_ID_JOYPAD_B 0
#define RETRO_DEVICE_ID_JOYPAD_Y 1
#define RETRO_DEVICE_ID_JOYPAD_SELECT 2
#define RETRO_DEVICE_ID_JOYPAD_START 3
#define RETRO_DEVICE_ID_JOYPAD_UP 4
#define RETRO_DEVICE_ID_JOYPAD_DOWN 5
#define RETRO_DEVICE_ID_JOYPAD_LEFT 6
#define RETRO_DEVICE_ID_JOYPAD_RIGHT 7
#define RETRO_DEVICE_ID_JOYPAD_A 8
#define RETRO_DEVICE_ID_JOYPAD_X 9
#define RETRO_DEVICE_ID_JOYPAD_L 10
#define RETRO_DEVICE_ID_JOYPAD_R 11
#define RETRO_DEVICE_ID_JOYPAD_L2 12
#define RETRO_DEVICE_ID_JOYPAD_R2 13
#define RETRO_DEVICE_ID_JOYPAD_MASK 256

/* Bit layout of g_buttons, matching lib/models/pad_button.dart (PadButton). */
#define PAD_DUP    (1 << 0)
#define PAD_DDOWN  (1 << 1)
#define PAD_DLEFT  (1 << 2)
#define PAD_DRIGHT (1 << 3)
#define PAD_START  (1 << 4)
#define PAD_Z      (1 << 5)
#define PAD_B      (1 << 6)
#define PAD_A      (1 << 7)
#define PAD_CUP    (1 << 8)
#define PAD_CDOWN  (1 << 9)
#define PAD_CLEFT  (1 << 10)
#define PAD_CRIGHT (1 << 11)
#define PAD_L      (1 << 12)
#define PAD_R      (1 << 13)

#define RETRO_ENVIRONMENT_GET_CAN_DUPE 3
#define RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY 9
#define RETRO_ENVIRONMENT_SET_PIXEL_FORMAT 10
#define RETRO_ENVIRONMENT_SET_HW_RENDER 14
#define RETRO_ENVIRONMENT_GET_VARIABLE 15
#define RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE 17
#define RETRO_ENVIRONMENT_GET_LOG_INTERFACE 27
#define RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY 31

struct retro_log_callback { void (*log)(int level, const char *fmt, ...); };

struct retro_variable { const char *key; const char *value; };

static const char *core_var(const char *key) {
    if (!key) return NULL;
    if (!strcmp(key, "mupen64plus-rdp-plugin")) return "angrylion";
    if (!strcmp(key, "mupen64plus-rsp-plugin")) return "hle";
    if (!strcmp(key, "mupen64plus-ThreadedRenderer")) return "False";
    if (!strcmp(key, "mupen64plus-angrylion-multithread")) return "all threads";
    if (!strcmp(key, "mupen64plus-angrylion-sync")) return "Low";
    if (!strcmp(key, "mupen64plus-angrylion-vioverlay")) return "Filtered";
    return NULL;
}

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

struct retro_game_geometry {
    unsigned base_width;
    unsigned base_height;
    unsigned max_width;
    unsigned max_height;
    float aspect_ratio;
};

struct retro_system_timing {
    double fps;
    double sample_rate;
};

struct retro_system_av_info {
    struct retro_game_geometry geometry;
    struct retro_system_timing timing;
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
    void (*retro_set_controller_port_device)(unsigned, unsigned);
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

static void *g_rom_data = NULL;
static size_t g_rom_size = 0;

static void *g_gles_lib = NULL;

static GLuint g_fbo = 0;
static GLuint g_fbo_tex = 0;
static GLuint g_fbo_depth = 0;
static int g_fbo_w = 0;
static int g_fbo_h = 0;
static int g_view_w = 0;
static int g_view_h = 0;
static int g_frame_w = 0;
static int g_frame_h = 0;

static void ensure_fbo(int w, int h) {
    if (g_fbo && g_fbo_w == w && g_fbo_h == h) return;
    if (g_fbo) {
        glDeleteFramebuffers(1, &g_fbo);
        glDeleteTextures(1, &g_fbo_tex);
        glDeleteRenderbuffers(1, &g_fbo_depth);
        g_fbo = g_fbo_tex = g_fbo_depth = 0;
    }
    glGenTextures(1, &g_fbo_tex);
    glBindTexture(GL_TEXTURE_2D, g_fbo_tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glGenRenderbuffers(1, &g_fbo_depth);
    glBindRenderbuffer(GL_RENDERBUFFER, g_fbo_depth);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, w, h);
    glGenFramebuffers(1, &g_fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, g_fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, g_fbo_tex, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, g_fbo_depth);
    GLenum st = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (st != GL_FRAMEBUFFER_COMPLETE) LOGE("FBO incomplete 0x%x (%dx%d)", st, w, h);
    else LOGI("FBO ready %dx%d id=%u tex=%u", w, h, g_fbo, g_fbo_tex);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    g_fbo_w = w;
    g_fbo_h = h;
}

static void destroy_fbo(void) {
    if (!g_fbo) return;
    glDeleteFramebuffers(1, &g_fbo);
    glDeleteTextures(1, &g_fbo_tex);
    glDeleteRenderbuffers(1, &g_fbo_depth);
    g_fbo = g_fbo_tex = g_fbo_depth = 0;
    g_fbo_w = g_fbo_h = 0;
}

static int g_pixel_format = 1;

static GLuint g_sw_prog = 0;
static GLuint g_sw_tex = 0;
static GLint g_sw_utex = -1;
static int g_sw_w = 0;
static int g_sw_h = 0;
static bool g_have_sw = false;

static const char *SW_VS =
    "#version 300 es\n"
    "out vec2 v_uv;\n"
    "void main(){\n"
    "  vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));\n"
    "  v_uv = p;\n"
    "  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);\n"
    "}\n";

static const char *SW_FS =
    "#version 300 es\n"
    "precision mediump float;\n"
    "in vec2 v_uv;\n"
    "uniform sampler2D u_tex;\n"
    "out vec4 o;\n"
    "void main(){\n"
    "  vec4 c = texture(u_tex, vec2(v_uv.x, 1.0 - v_uv.y));\n"
    "  o = vec4(c.b, c.g, c.r, 1.0);\n"
    "}\n";

static GLuint compile_sh(GLenum type, const char *src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetShaderInfoLog(s, sizeof(log), NULL, log);
        LOGE("shader compile failed: %s", log);
    }
    return s;
}

static void init_sw_display(void) {
    if (g_sw_prog) return;
    GLuint vs = compile_sh(GL_VERTEX_SHADER, SW_VS);
    GLuint fs = compile_sh(GL_FRAGMENT_SHADER, SW_FS);
    g_sw_prog = glCreateProgram();
    glAttachShader(g_sw_prog, vs);
    glAttachShader(g_sw_prog, fs);
    glLinkProgram(g_sw_prog);
    GLint ok = 0;
    glGetProgramiv(g_sw_prog, GL_LINK_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetProgramInfoLog(g_sw_prog, sizeof(log), NULL, log);
        LOGE("program link failed: %s", log);
    }
    glDeleteShader(vs);
    glDeleteShader(fs);
    g_sw_utex = glGetUniformLocation(g_sw_prog, "u_tex");
    glGenTextures(1, &g_sw_tex);
    glBindTexture(GL_TEXTURE_2D, g_sw_tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    LOGI("sw display init prog=%u tex=%u", g_sw_prog, g_sw_tex);
}

static void upload_sw_frame(const void *data, unsigned w, unsigned h, size_t pitch) {
    if (!g_sw_prog) init_sw_display();
    glBindTexture(GL_TEXTURE_2D, g_sw_tex);
    glPixelStorei(GL_UNPACK_ALIGNMENT, (g_pixel_format == 2) ? 2 : 4);
    GLint fmt = (g_pixel_format == 2) ? GL_RGB : GL_RGBA;
    GLenum type = (g_pixel_format == 2) ? GL_UNSIGNED_SHORT_5_6_5 : GL_UNSIGNED_BYTE;
    int bpp = (g_pixel_format == 2) ? 2 : 4;
    glPixelStorei(GL_UNPACK_ROW_LENGTH, (GLint) (pitch / bpp));
    if ((int) w != g_sw_w || (int) h != g_sw_h) {
        glTexImage2D(GL_TEXTURE_2D, 0, fmt, w, h, 0, fmt, type, data);
        g_sw_w = (int) w;
        g_sw_h = (int) h;
    } else {
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, w, h, fmt, type, data);
    }
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    g_have_sw = true;
}

static void draw_sw_frame(void) {
    if (!g_have_sw || !g_sw_prog || g_view_w <= 0 || g_view_h <= 0) return;
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);
    glDisable(GL_CULL_FACE);
    glDisable(GL_SCISSOR_TEST);

    glViewport(0, 0, g_view_w, g_view_h);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    const float target_ar = 4.0f / 3.0f;
    int dw = g_view_w;
    int dh = (int) ((float) g_view_w / target_ar);
    if (dh > g_view_h) {
        dh = g_view_h;
        dw = (int) ((float) g_view_h * target_ar);
    }
    int dx = (g_view_w - dw) / 2;
    int dy = (g_view_h - dh) / 2;
    glViewport(dx, dy, dw, dh);

    glUseProgram(g_sw_prog);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, g_sw_tex);
    glUniform1i(g_sw_utex, 0);
    glDrawArrays(GL_TRIANGLES, 0, 3);
}

static retro_proc_address_t proc_address(const char *sym) {
    if (!g_gles_lib) {
        g_gles_lib = dlopen("libGLESv3.so", RTLD_NOW | RTLD_GLOBAL);
        if (!g_gles_lib) g_gles_lib = dlopen("libGLESv2.so", RTLD_NOW | RTLD_GLOBAL);
    }
    void *p = g_gles_lib ? dlsym(g_gles_lib, sym) : NULL;
    if (!p) p = (void *) eglGetProcAddress(sym);
    if (!p) LOGE("proc_address NULL for %s", sym);
    return (retro_proc_address_t) p;
}

static uintptr_t current_framebuffer(void) {
    return (uintptr_t) g_fbo;
}

static bool env_cb(unsigned cmd, void *data) {
    switch (cmd) {
        case RETRO_ENVIRONMENT_GET_CAN_DUPE:
            *(bool *) data = true;
            return true;
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
            g_pixel_format = *(const int *) data;
            LOGI("SET_PIXEL_FORMAT %d", g_pixel_format);
            return true;
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
            *(const char **) data = g_system_dir;
            return true;
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            *(const char **) data = g_save_dir;
            return true;
        case RETRO_ENVIRONMENT_SET_HW_RENDER: {
            struct retro_hw_render_callback *hw = data;
            LOGI("SET_HW_RENDER type=%u version=%u.%u depth=%d stencil=%d",
                 hw->context_type, hw->version_major, hw->version_minor,
                 hw->depth, hw->stencil);
            hw->get_current_framebuffer = current_framebuffer;
            hw->get_proc_address = proc_address;
            g_hw = *hw;
            g_have_hw = true;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE: {
            struct retro_variable *var = data;
            const char *v = core_var(var->key);
            LOGI("GET_VARIABLE %s -> %s", var->key ? var->key : "(null)", v ? v : "(default)");
            if (v) {
                var->value = v;
                return true;
            }
            var->value = NULL;
            return false;
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
    if (!data) return;
    if (data == RETRO_HW_FRAME_BUFFER_VALID) {
        g_frame_w = (int) w;
        g_frame_h = (int) h;
        return;
    }
    upload_sw_frame(data, w, h, pitch);
}

/* --- OpenSL ES audio output (16-bit stereo, core sample rate) --- */
#define SL_RING_FRAMES 32768
#define SL_CHUNK_FRAMES 1024
static SLObjectItf g_sl_engine_obj = NULL;
static SLEngineItf g_sl_engine = NULL;
static SLObjectItf g_sl_mix_obj = NULL;
static SLObjectItf g_sl_player_obj = NULL;
static SLPlayItf g_sl_play = NULL;
static SLAndroidSimpleBufferQueueItf g_sl_bq = NULL;
static int16_t g_ring[SL_RING_FRAMES * 2];
static volatile size_t g_ring_wr = 0;
static volatile size_t g_ring_rd = 0;
static int16_t g_sl_chunk[2][SL_CHUNK_FRAMES * 2];
static int g_sl_chunk_idx = 0;
static pthread_mutex_t g_ring_mtx = PTHREAD_MUTEX_INITIALIZER;
static int g_audio_rate = 44100;

static void ring_write(const int16_t *data, size_t frames) {
    pthread_mutex_lock(&g_ring_mtx);
    for (size_t i = 0; i < frames; i++) {
        size_t next = (g_ring_wr + 1) % SL_RING_FRAMES;
        if (next == g_ring_rd) break; /* full: drop */
        g_ring[g_ring_wr * 2] = data[i * 2];
        g_ring[g_ring_wr * 2 + 1] = data[i * 2 + 1];
        g_ring_wr = next;
    }
    pthread_mutex_unlock(&g_ring_mtx);
}

static void sl_feed(void) {
    int16_t *chunk = g_sl_chunk[g_sl_chunk_idx];
    g_sl_chunk_idx ^= 1;
    pthread_mutex_lock(&g_ring_mtx);
    for (size_t i = 0; i < SL_CHUNK_FRAMES; i++) {
        if (g_ring_rd == g_ring_wr) {
            chunk[i * 2] = 0;
            chunk[i * 2 + 1] = 0;
        } else {
            chunk[i * 2] = g_ring[g_ring_rd * 2];
            chunk[i * 2 + 1] = g_ring[g_ring_rd * 2 + 1];
            g_ring_rd = (g_ring_rd + 1) % SL_RING_FRAMES;
        }
    }
    pthread_mutex_unlock(&g_ring_mtx);
    (*g_sl_bq)->Enqueue(g_sl_bq, chunk, SL_CHUNK_FRAMES * 2 * sizeof(int16_t));
}

static void sl_bq_cb(SLAndroidSimpleBufferQueueItf bq, void *ctx) {
    (void) bq;
    (void) ctx;
    sl_feed();
}

static void teardown_audio(void) {
    if (g_sl_player_obj) { (*g_sl_player_obj)->Destroy(g_sl_player_obj); g_sl_player_obj = NULL; }
    if (g_sl_mix_obj) { (*g_sl_mix_obj)->Destroy(g_sl_mix_obj); g_sl_mix_obj = NULL; }
    if (g_sl_engine_obj) { (*g_sl_engine_obj)->Destroy(g_sl_engine_obj); g_sl_engine_obj = NULL; }
    g_sl_engine = NULL; g_sl_play = NULL; g_sl_bq = NULL;
    g_ring_rd = g_ring_wr = 0;
}

static void init_audio(int sample_rate) {
    if (g_sl_engine_obj) return;
    g_audio_rate = sample_rate > 0 ? sample_rate : 44100;

    if (slCreateEngine(&g_sl_engine_obj, 0, NULL, 0, NULL, NULL) != SL_RESULT_SUCCESS) { LOGE("slCreateEngine failed"); return; }
    (*g_sl_engine_obj)->Realize(g_sl_engine_obj, SL_BOOLEAN_FALSE);
    (*g_sl_engine_obj)->GetInterface(g_sl_engine_obj, SL_IID_ENGINE, &g_sl_engine);
    (*g_sl_engine)->CreateOutputMix(g_sl_engine, &g_sl_mix_obj, 0, NULL, NULL);
    (*g_sl_mix_obj)->Realize(g_sl_mix_obj, SL_BOOLEAN_FALSE);

    SLDataLocator_AndroidSimpleBufferQueue loc_bq = { SL_DATALOCATOR_ANDROIDSIMPLEBUFFERQUEUE, 2 };
    SLDataFormat_PCM fmt = {
        SL_DATAFORMAT_PCM, 2, (SLuint32) (g_audio_rate * 1000),
        SL_PCMSAMPLEFORMAT_FIXED_16, SL_PCMSAMPLEFORMAT_FIXED_16,
        SL_SPEAKER_FRONT_LEFT | SL_SPEAKER_FRONT_RIGHT, SL_BYTEORDER_LITTLEENDIAN
    };
    SLDataSource src = { &loc_bq, &fmt };
    SLDataLocator_OutputMix loc_mix = { SL_DATALOCATOR_OUTPUTMIX, g_sl_mix_obj };
    SLDataSink sink = { &loc_mix, NULL };
    const SLInterfaceID ids[1] = { SL_IID_BUFFERQUEUE };
    const SLboolean req[1] = { SL_BOOLEAN_TRUE };
    if ((*g_sl_engine)->CreateAudioPlayer(g_sl_engine, &g_sl_player_obj, &src, &sink, 1, ids, req) != SL_RESULT_SUCCESS) {
        LOGE("CreateAudioPlayer failed");
        return;
    }
    (*g_sl_player_obj)->Realize(g_sl_player_obj, SL_BOOLEAN_FALSE);
    (*g_sl_player_obj)->GetInterface(g_sl_player_obj, SL_IID_PLAY, &g_sl_play);
    (*g_sl_player_obj)->GetInterface(g_sl_player_obj, SL_IID_BUFFERQUEUE, &g_sl_bq);
    (*g_sl_bq)->RegisterCallback(g_sl_bq, sl_bq_cb, NULL);
    (*g_sl_play)->SetPlayState(g_sl_play, SL_PLAYSTATE_PLAYING);
    LOGI("audio init rate=%d", g_audio_rate);
    sl_feed();
    sl_feed();
}

static void audio_sample_cb(int16_t l, int16_t r) {
    int16_t frame[2] = { l, r };
    ring_write(frame, 1);
}

static size_t audio_batch_cb(const int16_t *data, size_t frames) {
    ring_write(data, frames);
    return frames;
}

static void input_poll_cb(void) {}

/* RetroPad -> N64 mapping used by mupen64plus-next
 * (custom/mupen64plus-core/plugin/emulate_game_controller_via_libretro.c):
 *   N64 A       <- JOYPAD_B        N64 B      <- JOYPAD_Y
 *   N64 C-Down  <- JOYPAD_A        N64 C-Up   <- JOYPAD_X
 *   N64 C-Left  <- JOYPAD_L        N64 C-Right<- JOYPAD_R
 *   N64 Z       <- JOYPAD_L2       N64 Start  <- JOYPAD_START
 *   N64 L       <- JOYPAD_SELECT   N64 R      <- JOYPAD_R2
 *   N64 D-pad   <- JOYPAD d-pad    N64 stick  <- ANALOG LEFT
 */
static int16_t retropad_mask(int b) {
    int16_t m = 0;
    if (b & PAD_A)      m |= (1 << RETRO_DEVICE_ID_JOYPAD_B);
    if (b & PAD_B)      m |= (1 << RETRO_DEVICE_ID_JOYPAD_Y);
    if (b & PAD_CDOWN)  m |= (1 << RETRO_DEVICE_ID_JOYPAD_A);
    if (b & PAD_CUP)    m |= (1 << RETRO_DEVICE_ID_JOYPAD_X);
    if (b & PAD_CLEFT)  m |= (1 << RETRO_DEVICE_ID_JOYPAD_L);
    if (b & PAD_CRIGHT) m |= (1 << RETRO_DEVICE_ID_JOYPAD_R);
    if (b & PAD_Z)      m |= (1 << RETRO_DEVICE_ID_JOYPAD_L2);
    if (b & PAD_L)      m |= (1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
    if (b & PAD_R)      m |= (1 << RETRO_DEVICE_ID_JOYPAD_R2);
    if (b & PAD_START)  m |= (1 << RETRO_DEVICE_ID_JOYPAD_START);
    if (b & PAD_DUP)    m |= (1 << RETRO_DEVICE_ID_JOYPAD_UP);
    if (b & PAD_DDOWN)  m |= (1 << RETRO_DEVICE_ID_JOYPAD_DOWN);
    if (b & PAD_DLEFT)  m |= (1 << RETRO_DEVICE_ID_JOYPAD_LEFT);
    if (b & PAD_DRIGHT) m |= (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT);
    return m;
}

static int16_t input_state_cb(unsigned port, unsigned device, unsigned index, unsigned id) {
    if (port != 0) return 0;
    int b = g_buttons;
    if (device == RETRO_DEVICE_JOYPAD) {
        int16_t m = retropad_mask(b);
        if (id == RETRO_DEVICE_ID_JOYPAD_MASK) return m;
        if (id > 15) return 0;
        return (m >> id) & 1;
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

static inline void *untag_ptr(void *p) {
    return (void *) ((uintptr_t) p & 0x00FFFFFFFFFFFFFFULL);
}

static int g_free_calls = 0;

static void wrap_free(void *p) {
    if (g_free_calls < 3) {
        LOGI("wrap_free #%d p=%p untag=%p", g_free_calls, p, untag_ptr(p));
        g_free_calls++;
    }
    free(untag_ptr(p));
}

static void *wrap_realloc(void *p, size_t n) {
    return realloc(untag_ptr(p), n);
}

static void patch_relocs(uintptr_t base, const Elf64_Rela *r, size_t n,
                         const Elf64_Sym *symtab, const char *strtab) {
    long ps = sysconf(_SC_PAGESIZE);
    for (size_t i = 0; i < n; i++) {
        uint32_t s = (uint32_t) ELF64_R_SYM(r[i].r_info);
        const char *nm = strtab + symtab[s].st_name;
        void *repl = NULL;
        if (!strcmp(nm, "free")) repl = (void *) wrap_free;
        else if (!strcmp(nm, "realloc")) repl = (void *) wrap_realloc;
        if (!repl) continue;
        void **slot = (void **) (base + r[i].r_offset);
        void *page = (void *) ((uintptr_t) slot & ~((uintptr_t) ps - 1));
        int mp = mprotect(page, ps, PROT_READ | PROT_WRITE);
        void *before = *slot;
        *slot = repl;
        void *after = *slot;
        LOGI("GOT %s @ %p mprotect=%d before=%p wrote=%p readback=%p",
             nm, (void *) slot, mp, before, repl, after);
    }
}

static void patch_core_allocator(void *any_core_sym) {
    Dl_info di;
    if (!dladdr(any_core_sym, &di) || !di.dli_fbase) {
        LOGE("patch: dladdr failed");
        return;
    }
    uintptr_t base = (uintptr_t) di.dli_fbase;
    const Elf64_Ehdr *eh = (const Elf64_Ehdr *) base;
    const Elf64_Phdr *ph = (const Elf64_Phdr *) (base + eh->e_phoff);
    const Elf64_Dyn *dyn = NULL;
    for (int i = 0; i < eh->e_phnum; i++) {
        if (ph[i].p_type == PT_DYNAMIC) {
            dyn = (const Elf64_Dyn *) (base + ph[i].p_vaddr);
            break;
        }
    }
    if (!dyn) {
        LOGE("patch: no PT_DYNAMIC");
        return;
    }
    const Elf64_Sym *symtab = NULL;
    const char *strtab = NULL;
    const Elf64_Rela *jmprel = NULL, *rela = NULL;
    size_t pltsz = 0, relasz = 0, relaent = sizeof(Elf64_Rela);
    for (const Elf64_Dyn *d = dyn; d->d_tag != DT_NULL; d++) {
        uintptr_t v = (uintptr_t) d->d_un.d_ptr;
        switch (d->d_tag) {
            case DT_SYMTAB: symtab = (const Elf64_Sym *) (v < base ? base + v : v); break;
            case DT_STRTAB: strtab = (const char *) (v < base ? base + v : v); break;
            case DT_JMPREL: jmprel = (const Elf64_Rela *) (v < base ? base + v : v); break;
            case DT_PLTRELSZ: pltsz = v; break;
            case DT_RELA: rela = (const Elf64_Rela *) (v < base ? base + v : v); break;
            case DT_RELASZ: relasz = v; break;
            case DT_RELAENT: relaent = v ? v : sizeof(Elf64_Rela); break;
            default: break;
        }
    }
    if (!symtab || !strtab) {
        LOGE("patch: no symtab/strtab");
        return;
    }
    if (jmprel && pltsz) patch_relocs(base, jmprel, pltsz / relaent, symtab, strtab);
    if (rela && relasz) patch_relocs(base, rela, relasz / relaent, symtab, strtab);
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
    g_core.retro_set_controller_port_device = resolve(g_core.handle, "retro_set_controller_port_device");
    if (g_core.retro_run) patch_core_allocator((void *) g_core.retro_run);
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

    FILE *rf = fopen(g_rom_path, "rb");
    if (!rf) {
        LOGE("cannot open ROM %s", g_rom_path);
        return false;
    }
    fseek(rf, 0, SEEK_END);
    long rsize = ftell(rf);
    fseek(rf, 0, SEEK_SET);
    g_rom_data = malloc(rsize);
    if (!g_rom_data || fread(g_rom_data, 1, rsize, rf) != (size_t) rsize) {
        LOGE("cannot read ROM %s", g_rom_path);
        fclose(rf);
        return false;
    }
    fclose(rf);
    g_rom_size = (size_t) rsize;

    struct retro_game_info info;
    memset(&info, 0, sizeof(info));
    info.path = g_rom_path;
    info.data = g_rom_data;
    info.size = g_rom_size;
    if (!g_core.retro_load_game(&info)) {
        LOGE("retro_load_game failed");
        return false;
    }
    int fb_w = 640, fb_h = 480;
    if (g_core.retro_get_system_av_info) {
        struct retro_system_av_info av;
        memset(&av, 0, sizeof(av));
        g_core.retro_get_system_av_info(&av);
        LOGI("av_info base=%ux%u max=%ux%u fps=%.2f rate=%.0f",
             av.geometry.base_width, av.geometry.base_height,
             av.geometry.max_width, av.geometry.max_height,
             av.timing.fps, av.timing.sample_rate);
        if (av.geometry.max_width > 0) fb_w = (int) av.geometry.max_width;
        if (av.geometry.max_height > 0) fb_h = (int) av.geometry.max_height;
        init_audio(av.timing.sample_rate > 0 ? (int) av.timing.sample_rate : 44100);
    } else {
        init_audio(44100);
    }
    if (g_core.retro_set_controller_port_device) {
        g_core.retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
    }
    ensure_fbo(fb_w, fb_h);
    if (g_have_hw && g_hw.context_reset) g_hw.context_reset();
    return true;
}

static void teardown(void) {
    if (!g_core.handle) return;
    teardown_audio();
    if (g_have_hw && g_hw.context_destroy) g_hw.context_destroy();
    destroy_fbo();
    if (g_loaded && g_core.retro_unload_game) g_core.retro_unload_game();
    if (g_core.retro_deinit) g_core.retro_deinit();
    dlclose(g_core.handle);
    memset(&g_core, 0, sizeof(g_core));
    g_have_hw = false;
    g_loaded = false;
    free(g_rom_data);
    g_rom_data = NULL;
    g_rom_size = 0;
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

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    (void) vm;
    (void) reserved;
    void *probe = malloc(64);
    LOGI("JNI_OnLoad probe=%p (top byte %02llx)", probe,
         (unsigned long long) ((uintptr_t) probe >> 56));
    free(probe);
    void *t = malloc(64);
    void *tagged = (void *) ((uintptr_t) t | 0x0200000000000000ULL);
    LOGI("tagged-free test: freeing %p ...", tagged);
    free(tagged);
    LOGI("tagged-free test: SURVIVED (free masks the top byte)");
    return JNI_VERSION_1_6;
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
    g_view_w = width;
    g_view_h = height;
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

    if (g_have_sw) {
        draw_sw_frame();
    } else if (g_fbo && g_frame_w > 0 && g_frame_h > 0 && g_view_w > 0 && g_view_h > 0) {
        glBindFramebuffer(GL_READ_FRAMEBUFFER, g_fbo);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
        glBlitFramebuffer(0, 0, g_frame_w, g_frame_h,
                          0, 0, g_view_w, g_view_h,
                          GL_COLOR_BUFFER_BIT, GL_LINEAR);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
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
