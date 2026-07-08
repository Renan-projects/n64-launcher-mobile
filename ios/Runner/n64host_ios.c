#include "N64Host.h"

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <OpenGLES/ES3/gl.h>

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
#define RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY 31

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

static retro_proc_address_t proc_address(const char *sym) {
    return (retro_proc_address_t) dlsym(RTLD_DEFAULT, sym);
}

static uintptr_t current_framebuffer(void) {
    GLint fbo = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &fbo);
    return (uintptr_t) fbo;
}

static int g_pixel_format = 1;
static int g_view_w = 0;
static int g_view_h = 0;
static GLuint g_def_fbo = 0;

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
    glDeleteShader(vs);
    glDeleteShader(fs);
    g_sw_utex = glGetUniformLocation(g_sw_prog, "u_tex");
    glGenTextures(1, &g_sw_tex);
    glBindTexture(GL_TEXTURE_2D, g_sw_tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
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
    glBindFramebuffer(GL_FRAMEBUFFER, g_def_fbo);
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

static bool env_cb(unsigned cmd, void *data) {
    switch (cmd) {
        case RETRO_ENVIRONMENT_GET_CAN_DUPE:
            *(bool *) data = true;
            return true;
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
            g_pixel_format = *(const int *) data;
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
        case RETRO_ENVIRONMENT_GET_VARIABLE: {
            struct retro_variable *var = data;
            const char *v = core_var(var->key);
            printf("[n64host] GET_VARIABLE %s -> %s\n", var->key ? var->key : "(null)", v ? v : "(default)");
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
        default:
            return false;
    }
}

static void video_cb(const void *data, unsigned w, unsigned h, size_t pitch) {
    if (!data) return;
    if (data == RETRO_HW_FRAME_BUFFER_VALID) return;
    upload_sw_frame(data, w, h, pitch);
}

static void audio_sample_cb(int16_t l, int16_t r) { (void) l; (void) r; }

static size_t audio_batch_cb(const int16_t *data, size_t frames) {
    (void) data;
    return frames;
}

static void input_poll_cb(void) {}

static int16_t input_state_cb(unsigned port, unsigned device, unsigned index, unsigned id) {
    if (port != 0) return 0;
    int b = g_buttons;
    if (device == RETRO_DEVICE_JOYPAD) {
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
    return dlsym(handle, name);
}

static bool load_core(const char *path) {
    g_core.handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!g_core.handle) return false;
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
    if (!rf) return false;
    fseek(rf, 0, SEEK_END);
    long rsize = ftell(rf);
    fseek(rf, 0, SEEK_SET);
    g_rom_data = malloc(rsize);
    if (!g_rom_data || fread(g_rom_data, 1, rsize, rf) != (size_t) rsize) {
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
    if (!g_core.retro_load_game(&info)) return false;
    if (g_core.retro_get_system_av_info) {
        struct retro_system_av_info av;
        memset(&av, 0, sizeof(av));
        g_core.retro_get_system_av_info(&av);
        printf("[n64host] av_info base=%ux%u max=%ux%u fps=%.2f rate=%.0f\n",
               av.geometry.base_width, av.geometry.base_height,
               av.geometry.max_width, av.geometry.max_height,
               av.timing.fps, av.timing.sample_rate);
    }
    if (g_core.retro_set_controller_port_device) {
        g_core.retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
    }
    if (g_have_hw && g_hw.context_reset) g_hw.context_reset();
    return true;
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

void n64_set_paths(const char *corePath, const char *romPath,
                   const char *systemDir, const char *saveDir) {
    strncpy(g_core_path, corePath, sizeof(g_core_path) - 1);
    strncpy(g_rom_path, romPath, sizeof(g_rom_path) - 1);
    strncpy(g_system_dir, systemDir, sizeof(g_system_dir) - 1);
    strncpy(g_save_dir, saveDir, sizeof(g_save_dir) - 1);
    g_want_load = true;
    g_paused = false;
}

void n64_on_gl_ready(void) {
    g_gl_ready = true;
}

void n64_run_frame(void) {
    if (g_want_load && g_gl_ready && !g_loaded) {
        g_loaded = startup();
        g_want_load = false;
        if (!g_loaded) n64_teardown();
        return;
    }
    if (!g_loaded || g_paused) return;
    if (g_do_load) { do_load(g_pending_load); g_do_load = false; }
    if (g_do_save) { do_save(g_pending_save); g_do_save = false; }
    GLint bound = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &bound);
    g_def_fbo = (GLuint) bound;
    g_core.retro_run();
    if (g_have_sw) draw_sw_frame();
}

void n64_set_view_size(int width, int height) {
    g_view_w = width;
    g_view_h = height;
}

void n64_teardown(void) {
    if (!g_core.handle) return;
    if (g_have_hw && g_hw.context_destroy) g_hw.context_destroy();
    if (g_loaded && g_core.retro_unload_game) g_core.retro_unload_game();
    if (g_core.retro_deinit) g_core.retro_deinit();
    dlclose(g_core.handle);
    memset(&g_core, 0, sizeof(g_core));
    g_have_hw = false;
    g_loaded = false;
    g_want_load = false;
    free(g_rom_data);
    g_rom_data = NULL;
    g_rom_size = 0;
}

void n64_pause(bool paused) { g_paused = paused; }

void n64_reset(void) {
    if (g_loaded && g_core.retro_reset) g_core.retro_reset();
}

void n64_set_input(int buttons, float stickX, float stickY) {
    g_buttons = buttons;
    g_stick_x = stickX;
    g_stick_y = stickY;
}

void n64_save_state(const char *path) {
    strncpy(g_pending_save, path, sizeof(g_pending_save) - 1);
    g_do_save = true;
}

bool n64_load_state(const char *path) {
    strncpy(g_pending_load, path, sizeof(g_pending_load) - 1);
    g_do_load = true;
    return true;
}

bool n64_is_loaded(void) { return g_loaded; }
