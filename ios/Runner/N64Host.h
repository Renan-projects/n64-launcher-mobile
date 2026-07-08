#ifndef N64HOST_H
#define N64HOST_H

#include <stdbool.h>

void n64_set_paths(const char *corePath, const char *romPath,
                   const char *systemDir, const char *saveDir);
void n64_on_gl_ready(void);
void n64_run_frame(void);
void n64_teardown(void);
void n64_pause(bool paused);
void n64_reset(void);
void n64_set_input(int buttons, float stickX, float stickY);
void n64_save_state(const char *path);
bool n64_load_state(const char *path);
bool n64_is_loaded(void);

#endif
