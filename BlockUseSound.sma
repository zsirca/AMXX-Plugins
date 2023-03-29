#include <amxmodx>
#include <fakemeta>

new cmd_click, bool:g_click

public plugin_init() {
	register_plugin("Block Use Sound", "1.0", "zsirca")
	register_forward(FM_EmitSound, "EmitirSonido")
	
	register_cvar("BlockUseSound", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	cmd_click = register_cvar("mf_nouseclick", "1")
}

public plugin_cfg()
	g_click = bool:get_pcvar_num(cmd_click)

public EmitirSonido(id, iChannel, szSound[])
	return equal(szSound, "common/wpn_denyselect.wav") || (g_click && equal(szSound, "common/wpn_select.wav")) ? FMRES_SUPERCEDE : FMRES_IGNORED
  
  
