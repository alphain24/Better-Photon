#if !defined INCLUDE_SKY_AURORA_COLORS
#define INCLUDE_SKY_AURORA_COLORS

#include "/include/utility/random.glsl"

// [0] - bottom color (base of the curtains)
// [1] - top color (upper rays)
// All palettes stay close to the colors of real auroras: the green oxygen
// emission at the base of the curtains, fading to cyan and blue higher up
mat2x3 get_aurora_colors() {
    const mat2x3[] aurora_colors = mat2x3[](
        mat2x3(
            vec3(0.05, 1.00, 0.40), // emerald green
            vec3(0.15, 0.55, 1.00) // blue
        ),
        mat2x3(
            vec3(0.10, 1.00, 0.30), // green
            vec3(0.00, 0.85, 1.00) // cyan
        ),
        mat2x3(
            vec3(0.00, 1.00, 0.60), // teal
            vec3(0.10, 0.35, 1.00) // deep blue
        ),
        mat2x3(
            vec3(0.00, 0.95, 0.75), // cyan-green
            vec3(0.25, 0.45, 1.00) // blue
        )
    );

    uint day_index = uint(worldDay);
    day_index = lowbias32(day_index) % aurora_colors.length();

    return aurora_colors[day_index];
}

// 0.0 - no aurora
// 1.0 - full aurora
float get_aurora_amount() {
    float night = smoothstep(0.0, 0.2, -sun_dir.y);

#if AURORA_NORMAL == AURORA_NEVER
    float aurora_normal = 0.0;
#elif AURORA_NORMAL == AURORA_RARELY
    float aurora_normal = float(lowbias32(uint(worldDay)) % 5 == 1);
#elif AURORA_NORMAL == AURORA_ALWAYS
    float aurora_normal = 1.0;
#endif

#if AURORA_SNOW == AURORA_NEVER
    float aurora_snow = 0.0;
#elif AURORA_SNOW == AURORA_RARELY
    float aurora_snow = float(lowbias32(uint(worldDay)) % 5 == 1);
#elif AURORA_SNOW == AURORA_ALWAYS
    float aurora_snow = 1.0;
#endif

    return night * mix(aurora_normal, aurora_snow, biome_may_snow);
}

#endif // INCLUDE_SKY_AURORA_COLORS
