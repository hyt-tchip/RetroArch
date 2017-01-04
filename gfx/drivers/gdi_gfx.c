/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2010-2014 - Hans-Kristian Arntzen
 *  Copyright (C) 2011-2016 - Daniel De Matteis
 *  Copyright (C) 2016 - Brad Parker
 *
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

#include <retro_miscellaneous.h>

#include "../../driver.h"
#include "../../configuration.h"
#include "../../verbosity.h"
#include "../../menu/menu_driver.h"
#include "../common/gdi_common.h"

static unsigned char *gdi_menu_frame = NULL;
static unsigned gdi_menu_width = 0;
static unsigned gdi_menu_height = 0;
static unsigned gdi_menu_pitch = 0;
static unsigned gdi_video_width = 0;
static unsigned gdi_video_height = 0;
static unsigned gdi_video_pitch = 0;
static bool gdi_rgb32 = 0;

static void gdi_gfx_free(void *data);

static void gdi_gfx_create()
{
   if(!gdi_video_width || !gdi_video_height)
   {
      printf("***** GDI: no width or height!\n");
   }

   //video_driver_set_size(&gdi_video_width, &gdi_video_height);
}

static void *gdi_gfx_init(const video_info_t *video,
      const input_driver_t **input, void **input_data)
{
   settings_t *settings = config_get_ptr();
   gdi_t *gdi = (gdi_t*)calloc(1, sizeof(*gdi));

   *input = NULL;
   *input_data = NULL;

   gdi_video_width = video->width;
   gdi_video_height = video->height;
   gdi_rgb32 = video->rgb32;

   if (video->rgb32)
      gdi_video_pitch = video->width * 4;
   else
      gdi_video_pitch = video->width * 2;

   gdi_gfx_create();

   if (settings->video.font_enable)
      font_driver_init_osd(NULL, false, FONT_DRIVER_RENDER_GDI);

   return gdi;
}

static bool gdi_gfx_frame(void *data, const void *frame,
      unsigned frame_width, unsigned frame_height, uint64_t frame_count,
      unsigned pitch, const char *msg)
{
   const void *frame_to_copy = frame;
   unsigned width = 0;
   unsigned height = 0;
   bool draw = true;

   (void)data;
   (void)frame;
   (void)frame_width;
   (void)frame_height;
   (void)pitch;
   (void)msg;

   if (!frame || !frame_width || !frame_height)
      return true;

   if (gdi_video_width != frame_width || gdi_video_height != frame_height || gdi_video_pitch != pitch)
   {
      if (frame_width > 4 && frame_height > 4)
      {
         gdi_video_width = frame_width;
         gdi_video_height = frame_height;
         gdi_video_pitch = pitch;
         gdi_gfx_free(NULL);
         gdi_gfx_create();
      }
   }

   if (gdi_menu_frame)
      frame_to_copy = gdi_menu_frame;

   //width = gdi_get_canvas_width(gdi_cv);
   //height = gdi_get_canvas_height(gdi_cv);
   width = frame_width;
   height = frame_height;

   if (frame_to_copy == frame && frame_width == 4 && frame_height == 4 && (frame_width < width && frame_height < height))
      draw = false;

#ifdef HAVE_MENU
   menu_driver_ctl(RARCH_MENU_CTL_FRAME, NULL);
#endif

   if (msg)
      font_driver_render_msg(NULL, msg, NULL);

   if (draw)
   {
      /*gdi_dither_bitmap(gdi_cv, 0, 0,
                         width,
                         height,
                         gdi_dither, frame_to_copy);*/
   }

   return true;
}

static void gdi_gfx_set_nonblock_state(void *data, bool toggle)
{
   (void)data;
   (void)toggle;
}

static bool gdi_gfx_alive(void *data)
{
   (void)data;
   video_driver_set_size(&gdi_video_width, &gdi_video_height);
   return true;
}

static bool gdi_gfx_focus(void *data)
{
   (void)data;
   return true;
}

static bool gdi_gfx_suppress_screensaver(void *data, bool enable)
{
   (void)data;
   (void)enable;
   return false;
}

static bool gdi_gfx_has_windowed(void *data)
{
   (void)data;
   return true;
}

static void gdi_gfx_free(void *data)
{
   (void)data;

   if (gdi_menu_frame)
   {
      free(gdi_menu_frame);
      gdi_menu_frame = NULL;
   }
}

static bool gdi_gfx_set_shader(void *data,
      enum rarch_shader_type type, const char *path)
{
   (void)data;
   (void)type;
   (void)path;

   return false;
}

static void gdi_gfx_set_rotation(void *data,
      unsigned rotation)
{
   (void)data;
   (void)rotation;
}

static void gdi_gfx_viewport_info(void *data,
      struct video_viewport *vp)
{
   (void)data;
   (void)vp;
}

static bool gdi_gfx_read_viewport(void *data, uint8_t *buffer)
{
   (void)data;
   (void)buffer;

   return true;
}

static void gdi_set_texture_frame(void *data,
      const void *frame, bool rgb32, unsigned width, unsigned height,
      float alpha)
{
   unsigned pitch = width * 2;

   if (rgb32)
      pitch = width * 4;

   if (gdi_menu_frame)
   {
      free(gdi_menu_frame);
      gdi_menu_frame = NULL;
   }

   if (!gdi_menu_frame || gdi_menu_width != width || gdi_menu_height != height || gdi_menu_pitch != pitch)
      if (pitch && height)
         gdi_menu_frame = (unsigned char*)malloc(pitch * height);

   if (gdi_menu_frame && frame && pitch && height)
      memcpy(gdi_menu_frame, frame, pitch * height);
}

static void gdi_set_osd_msg(void *data, const char *msg,
      const struct font_params *params, void *font)
{
   font_driver_render_msg(font, msg, params);
}

static const video_poke_interface_t gdi_poke_interface = {
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
#ifdef HAVE_FBO
   NULL,
#else
   NULL,
#endif
   NULL,
   NULL,
   NULL,
#if defined(HAVE_MENU)
   gdi_set_texture_frame,
   NULL,
   gdi_set_osd_msg,
   NULL,
#else
   NULL,
   NULL,
   NULL,
   NULL,
#endif

   NULL,
#ifdef HAVE_MENU
   NULL,
#endif
};

static void gdi_gfx_get_poke_interface(void *data,
      const video_poke_interface_t **iface)
{
   (void)data;
   *iface = &gdi_poke_interface;
}

static void gdi_gfx_set_viewport(void *data, unsigned viewport_width,
      unsigned viewport_height, bool force_full, bool allow_rotate)
{
}

video_driver_t video_gdi = {
   gdi_gfx_init,
   gdi_gfx_frame,
   gdi_gfx_set_nonblock_state,
   gdi_gfx_alive,
   gdi_gfx_focus,
   gdi_gfx_suppress_screensaver,
   gdi_gfx_has_windowed,
   gdi_gfx_set_shader,
   gdi_gfx_free,
   "gdi",
   gdi_gfx_set_viewport,
   gdi_gfx_set_rotation,
   gdi_gfx_viewport_info,
   gdi_gfx_read_viewport,
   NULL, /* read_frame_raw */

#ifdef HAVE_OVERLAY
  NULL, /* overlay_interface */
#endif
  gdi_gfx_get_poke_interface,
};
