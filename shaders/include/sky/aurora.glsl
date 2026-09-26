#if !defined INCLUDE_SKY_AURORA
#define INCLUDE_SKY_AURORA

#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/geometry.glsl"
#include "/include/utility/phase_functions.glsl"

// Aurora curtains are modelled as thin vertical sheets: a 2D pattern of thin
// arcs (contour lines of a domain-warped noise field) is extruded vertically
// through a slab of the atmosphere. Seen from below, this gives the familiar
// look of folded curtains with vertical rays that converge overhead

const float aurora_volume_bottom = 2000.0;
const float aurora_volume_top = 6000.0;
const float aurora_volume_radius = 30000.0;

// Highest viewer altitude used for the aurora, so that the viewer can get
// closer to the curtains by climbing or flying but never enters them
const float aurora_max_viewer_altitude = 0.75 * aurora_volume_bottom;

// Target distance between raymarching steps and step count limits
const float aurora_step_length = 120.0;
const float aurora_min_steps = 16.0;
const float aurora_max_steps = 96.0;

// Returns the density of the aurora at the given position
float aurora_shape(vec3 pos, float altitude_fraction) {
    const float frequency = 0.000005 * AURORA_FREQUENCY;

    // Auroral arcs tend to align along lines of magnetic latitude, so stretch
    // the pattern along one axis to make the arcs run mostly east-west
    const vec2 stretch = vec2(0.6, 1.0);

    const vec2 wind_0 = vec2(0.0003, 0.0001);
    const vec2 wind_1 = vec2(0.0004, -0.0002);
    const vec2 wind_2 = vec2(-0.0006, -0.0006);
    const vec2 wind_3 = vec2(0.0040, 0.0012);

    // Attach the aurora to the world, using the same scale as the clouds, so
    // that it moves past the viewer like a real object instead of following
    // the camera
    vec2 coord
        = (pos.xz + cameraPosition.xz * CLOUDS_SCALE) * frequency * stretch;

    // Large-scale noise: domain warp (folds and swirls) and coverage (breaks
    // the aurora up into separate arcs)
    vec4 large_scale
        = texture(noisetex, coord * 0.4 + wind_0 * frameTimeCounter);
    coord += 0.12 * (large_scale.xw - vec2(0.5, 0.535));
    float coverage = smoothstep(0.40, 0.56, large_scale.w);

    if (coverage < eps) {
        return 0.0;
    }

    // Arcs: thin bands along the contour lines of a two-octave noise field
    vec2 arc_coord_0 = coord + wind_1 * frameTimeCounter;
    vec2 arc_coord_1 = coord * 2.7 + (0.13 + wind_2 * frameTimeCounter);
    float arc_noise = texture(noisetex, arc_coord_0).x
        + 0.3 * texture(noisetex, arc_coord_1).x - 0.15;
    float arc_dist = abs(arc_noise - 0.5);

    float arcs = sqr(max0(1.0 - 80.0 * arc_dist)) // Sharp curtain
        + 0.05 * sqr(max0(1.0 - 16.0 * arc_dist)); // Diffuse glow around it

    if (arcs * coverage < eps) {
        return 0.0;
    }

    // Vertical rays: fine brightness variation along the curtain
    float rays = texture(noisetex, coord * 40.0 + wind_3 * frameTimeCounter).w;
    rays = 0.25 + 0.75 * smoothstep(0.40, 0.70, rays);

    // Vertical profile: sharp, rippled lower edge and a long fade upwards
    float lower_edge = 0.02 + 0.12 * arc_noise;
    float vertical_profile
        = linear_step(lower_edge, lower_edge + 0.03, altitude_fraction)
        * exp2(-4.0 * max0(altitude_fraction - lower_edge))
        * sqr(1.0 - altitude_fraction);

    return arcs * coverage * rays * vertical_profile;
}

// Green at the base of the curtain, fading to cyan and blue towards the top
vec3 aurora_color(float altitude_fraction) {
    return mix(
        aurora_colors[0],
        aurora_colors[1],
        smoothstep(0.0, 0.8, altitude_fraction)
    );
}

vec3 draw_aurora(vec3 ray_dir, float dither) {
    if (aurora_amount < 0.01) {
        return vec3(0.0);
    }

    // Viewer altitude above sea level, in the same units as the clouds
    float viewer_altitude = clamp(
        CLOUDS_SCALE * (eyeAltitude - SEA_LEVEL),
        0.0,
        aurora_max_viewer_altitude
    );

    // Calculate distance to enter and exit the volume

    float rcp_dir_y = rcp(ray_dir.y);
    float distance_to_lower_plane
        = (aurora_volume_bottom - viewer_altitude) * rcp_dir_y;
    float distance_to_upper_plane
        = (aurora_volume_top - viewer_altitude) * rcp_dir_y;
    float distance_to_cylinder = aurora_volume_radius * rcp_length(ray_dir.xz);

    float distance_to_volume_start = distance_to_lower_plane;
    float distance_to_volume_end
        = min(distance_to_cylinder, distance_to_upper_plane);

    // Make sure that the volume is intersected
    if (distance_to_volume_start > distance_to_volume_end) {
        return vec3(0.0);
    }

    // Raymarching setup
    // The step count adapts to the ray length: short rays looking up need few
    // steps, while long rays towards the horizon get more to reduce noise

    float ray_length = max0(distance_to_volume_end - distance_to_volume_start);
    uint step_count = uint(clamp(
        ceil(ray_length * rcp(aurora_step_length)),
        aurora_min_steps,
        aurora_max_steps
    ));
    float step_length = ray_length * rcp(float(step_count));

    vec3 ray_pos = vec3(0.0, viewer_altitude, 0.0)
        + ray_dir * (distance_to_volume_start + step_length * dither);
    vec3 ray_step = ray_dir * step_length;

    vec3 emission = vec3(0.0);

    // Raymarching loop

    for (uint i = 0u; i < step_count; ++i, ray_pos += ray_step) {
        float altitude_fraction
            = linear_step(aurora_volume_bottom, aurora_volume_top, ray_pos.y);

        float shape = aurora_shape(ray_pos, altitude_fraction);
        if (shape < eps) {
            continue;
        }

        float d = length(ray_pos.xz);
        float distance_fade = (1.0 - cube(d * rcp(aurora_volume_radius)))
            * (1.0 - exp2(-0.001 * d));

        emission += aurora_color(altitude_fraction)
            * (shape * distance_fade * step_length);
    }

    return (0.009 * AURORA_BRIGHTNESS) * emission * aurora_amount;
}

#endif // INCLUDE_SKY_AURORA
