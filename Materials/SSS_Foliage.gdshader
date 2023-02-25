shader_type spatial;
render_mode blend_mix,depth_draw_always,cull_back,diffuse_burley,alpha_to_coverage_and_one;

// Material Propeties
group_uniforms Material;

group_uniforms Material.Albedo;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform ivec2 albedo_texture_size;

group_uniforms Material.Roughness;
uniform float roughness : hint_range(0,1) = 1.0;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;

group_uniforms Material.Specular;
uniform float specular = 0.0;
uniform float metallic = 0.0;
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel = vec4(0.0);

group_uniforms Material.Normals;
uniform sampler2D texture_normal : hint_roughness_normal,filter_linear_mipmap,repeat_enable;
uniform float normal_strength : hint_range(-16,16) = 0.5;

group_uniforms Material.AmbientOcclusion;
uniform sampler2D texture_ambient_occlusion : hint_default_white, filter_linear_mipmap,repeat_enable;
uniform vec4 ao_texture_channel;
uniform float ao_light_affect = 0.5;

group_uniforms Material.Transparency;
uniform float alpha_scissor_threshold = 0.992;
uniform float alpha_antialiasing_edge = 1.0;

group_uniforms Material.Uvs;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);

group_uniforms;

// sss settings
group_uniforms Subsurface_Scattering;
uniform vec2 sss_thickness = vec2(0.0);
uniform float sss_power = 1.0;
uniform float sss_distortion = 2.0;
uniform float sss_scale = 0.5;
uniform float sss_strength = 4.0;
uniform vec4 sss_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D texture_sss;
uniform sampler2D texture_sss_mask;
group_uniforms;

// wind settings
group_uniforms Wind;
uniform float wind_speed = 1.0;
uniform float wind_min_strength : hint_range(0.0, 1.0) = 0.0;
uniform float wind_max_strength : hint_range(0.0, 1.0) = 0.1;
uniform float wind_interval = 3.5;
uniform float wind_detail = 1.0;
uniform float wind_distortion : hint_range(0.0, 1.0) = 0.8;
uniform vec2 wind_direction = vec2(0.9, 0.1);
uniform float wind_height_offset = 0.15;
group_uniforms;

// collison settings
group_uniforms Collision;
uniform float collision_strength = 1.0;
uniform vec3 playerpos;
uniform float collision_distance = 4.0;
group_uniforms;

varying vec3 v_Normal;
varying vec3 f_Normal;

vec3 getWind(vec3 vertex, float timer) {
	vec4 pos = mix(vec4(1.0), vec4(vertex, 1.0), wind_distortion);
	float time = timer * wind_speed + pos.x + pos.z;
	float diff = pow(wind_max_strength - wind_min_strength, 2);
	float strength = clamp(wind_min_strength + diff + sin(time / wind_interval) * diff, wind_min_strength, wind_max_strength);
	float wind = (sin(time) + cos(time * wind_detail)) * strength * max(0.0, vertex.y - wind_height_offset);
	vec2 dir = normalize(wind_direction);
	
	return vec3(wind * dir.x, 0.0, wind * dir.y);
}

vec3 get_collision(mat4 world_mat, vec3 vertex)
{
	vec4 v = world_mat * vec4(vertex, 1.0);
	vec3 diff = normalize(playerpos - vertex.xyz); // vec3(0, 0, 5)
	float dist = distance(playerpos, v.xyz); // 5
	vec3 strength = vec3(collision_strength, 0, collision_strength); // vec3(1.0, 0, 1.0)

	float col_dist = 1.0 - clamp(dist * collision_distance, 0.0, 1.0); // 1.0 - 5.0 / 10.0 = 1.0 - 0.5
	vec3 collision = diff * strength; // vec3(0.0, 0.0, 5.0)

	return col_dist * collision; // vec3(0.0, 0.0, 2.5)
}

void vertex() {
	// Set UV Tiling
	UV= UV * uv1_scale.xy + uv1_offset.xy;
	
	// Move vertices based on wind
	vec4 worldPos = vec4(VERTEX, 1.0);
	worldPos.xyz += getWind(VERTEX, TIME);
	// Move vertices based on collison
	worldPos.xyz += get_collision(MODEL_MATRIX, VERTEX);

	VERTEX = worldPos.xyz;

	// Varyings
	v_Normal = NORMAL;
}

void fragment() {
	// UVs
	vec2 base_uv = UV;

	// Albedo
	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;

	// Specular
	float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;
	
	// Roughness
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	
	// Normals
	NORMAL_MAP = texture(texture_normal, base_uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength;

	// Ambient Occlusion
	AO = dot(texture(texture_ambient_occlusion, base_uv), ao_texture_channel);
	AO_LIGHT_AFFECT = ao_light_affect;

	// Transparency
	ALPHA *= albedo.a * albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ALPHA_ANTIALIASING_EDGE = alpha_antialiasing_edge;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(albedo_texture_size);

	// Varyings
	f_Normal = NORMAL;
}

void light() {
	vec3 viewDir = normalize(VIEW);
	vec3 lightDir = normalize(LIGHT);
	
	// Regular Lighting
	vec3 regularLight = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ALBEDO;

	// Translucent Lighting
	vec3 transLightDir = (lightDir + f_Normal) * sss_distortion;
	float transDot = pow ( max (0, dot ( viewDir, -transLightDir ) ), sss_power ) * sss_scale;
	//vec3 transLight = transDot * ALPHA * sss_color.rgb * texture(texture_sss, UV).rgb  * sss_strength;
	vec3 transLight = ( transDot ) * ALPHA * sss_color.rgb * texture(texture_sss, UV).rgb * texture(texture_sss_mask, UV).rgb * sss_strength;
	
	// Final Combined Lighting
	vec3 combinedLight = regularLight + transLight;
	
	// Don't know why, but the key to subsurface scattering is to calculate ATTENUATION last
	// Otherwise, it will look noisy
	DIFFUSE_LIGHT = combinedLight * ATTENUATION * LIGHT_COLOR;
}
