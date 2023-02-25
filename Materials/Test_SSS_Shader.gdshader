shader_type spatial;
render_mode blend_mix,depth_draw_always,cull_back,diffuse_burley,specular_schlick_ggx,sss_mode_skin,alpha_to_coverage_and_one;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;

uniform float alpha_scissor_threshold = 0.992;
uniform float alpha_antialiasing_edge;

uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0,128);

uniform float roughness : hint_range(0,1) = 1.0;

uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;

uniform float specular = 0.0;
uniform float metallic = 0.0;

uniform sampler2D texture_normal : hint_roughness_normal,filter_linear_mipmap,repeat_enable;
uniform float normal_scale : hint_range(-16,16) = 1.0;

uniform sampler2D texture_ambient_occlusion : hint_default_white, filter_linear_mipmap,repeat_enable;
uniform vec4 ao_texture_channel;
uniform float ao_light_affect = 0.5;

uniform float subsurface_scattering_strength : hint_range(0,1) = 0.0;
uniform sampler2D texture_subsurface_scattering : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 transmittance_color : source_color;
uniform float transmittance_depth = 32.0;
uniform sampler2D texture_subsurface_transmittance : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform float transmittance_boost = 0.0;
uniform sampler2D sss_texture;

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

// sss settings
uniform vec2 sss_thickness;
uniform float sss_power = 1.0;
uniform float sss_distortion = 2.0;
uniform float sss_scale = 0.5;
uniform float sss_strength = 4.0;
uniform vec4 sss_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// wind settings
uniform float speed = 1.0;
uniform float min_strength : hint_range(0.0, 1.0);
uniform float max_strength : hint_range(0.0, 1.0) = 0.1;
uniform float interval = 3.5;
uniform float detail = 1.0;
uniform float distortion : hint_range(0.0, 1.0) = 0.8;
uniform vec2 direction = vec2(1.0, 1.0);
uniform float heightOffset = 0.15;

vec3 getWind(vec3 vertex, float timer) {
	vec4 pos = mix(vec4(1.0), vec4(vertex, 1.0), distortion);
	float time = timer * speed + pos.x + pos.z;
	float diff = pow(max_strength - min_strength, 2);
	float strength = clamp(min_strength + diff + sin(time / interval) * diff, min_strength, max_strength);
	float wind = (sin(time) + cos(time * detail)) * strength * max(0.0, vertex.y - heightOffset);
	vec2 dir = normalize(direction);
	
	return vec3(wind * dir.x, 0.0, wind * dir.y);
}

varying vec3 v_Normal;
varying vec3 f_Normal;

void vertex() {
	UV=UV*uv1_scale.xy+uv1_offset.xy;
	
	vec4 worldPos = vec4(VERTEX, 1.0);
	worldPos.xyz += getWind(VERTEX, TIME);
	VERTEX = (worldPos).xyz;
	
	v_Normal = NORMAL;
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	NORMAL_MAP = texture(texture_normal,base_uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	ALPHA *= albedo.a * albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ALPHA_ANTIALIASING_EDGE = alpha_antialiasing_edge;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(albedo_texture_size);
	AO = dot(texture(texture_ambient_occlusion,base_uv),ao_texture_channel);
	AO_LIGHT_AFFECT = ao_light_affect;
	//float sss_tex = texture(texture_subsurface_scattering,base_uv).r;
	//SSS_STRENGTH=subsurface_scattering_strength*sss_tex;
	//vec4 trans_color_tex = texture(texture_subsurface_transmittance,base_uv);
	//SSS_TRANSMITTANCE_COLOR=transmittance_color*trans_color_tex;
	//SSS_TRANSMITTANCE_DEPTH=transmittance_depth;
	//SSS_TRANSMITTANCE_BOOST=transmittance_boost;
	
	f_Normal = NORMAL;
}

void light() {
	vec3 viewDir = normalize(VIEW);
	vec3 lightDir = normalize(LIGHT);
	
	// Translucency.
	vec3 transLightDir = (lightDir + f_Normal) * sss_distortion;
	float transDot = pow ( max (0, dot ( viewDir, -transLightDir ) ), sss_power ) * sss_scale;
	vec3 transLight = ( transDot ) * ALPHA * sss_color.rgb * texture(sss_texture, UV).rgb * sss_strength; // use this
	//vec3 transLight = (ATTENUATION * 1.0) * ( transDot ) * ALPHA * _SubColor.rgb * texture(sss_texture, UV).rgb;  // not this
	
	vec3 regularLight = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ALBEDO;
	
	vec3 a = regularLight;
	vec3 b = transLight;
	
	vec3 combinedLight = regularLight + transLight; // using this blend mode
	vec3 combinedLight_softlight = (1.0 - a) * (a * b) + a * (1.0 - (1.0 - a) * (1.0 - b));
	vec3 combinedLight_hardlight = float(sqrt(a.x * a.x + a.y * a.y + a.z * a.z) > 0.5) * (1.0 - (1.0-b) * (1.0-2.0*(a-0.5))) + float(sqrt(a.x * a.x + a.y * a.y + a.z * a.z) <= 0.5) * (b * (2.0*a));
	vec3 combinedLight_overlay = float(sqrt(a.x * a.x + a.y * a.y + a.z * a.z) < 0.5) * (2.0*a*b) + float(sqrt(a.x * a.x + a.y * a.y + a.z * a.z) > 0.5) * (1.0 - 2.0 * (1.0 - a) + 2.0 * (1.0 - b));
	vec3 combinedLight_vivid = float(sqrt(a.x * a.x + a.y * a.y + a.z * a.z) > 0.5) * (b / (1.0-2.0*(a-0.5))) + float(sqrt(a.x * a.x + a.y * a.y + a.z * a.z) <= 0.5) * (1.0 - (1.0-b) / (2.0*a));
	
	// The key to subsurface scattering is to calculate ATTENUATION last
	// Otherwise, it will look noisy
	DIFFUSE_LIGHT = combinedLight * ATTENUATION * LIGHT_COLOR;
}
