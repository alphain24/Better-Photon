#if !defined INCLUDE_LIGHTING_NIGHT
#define INCLUDE_LIGHTING_NIGHT

#if defined WORLD_OVERWORLD
// 0.0 - day (sunlight)
// 1.0 - night (moonlight)
float get_night_factor() { return linear_step(-0.02, -0.12, sun_dir.y); }
#endif

#endif // INCLUDE_LIGHTING_NIGHT
