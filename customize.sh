ui_print "- Installing ZeroJitter Ping Optimizer"
ui_print "- Target: POCO F6 (peridot) / Qualcomm SM8635"
ui_print "- Setting file permissions..."
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/system.prop" 0 0 0644
set_perm "$MODPATH/sepolicy.rule" 0 0 0644
ui_print "- SUSFS stealth hooks armed."
ui_print "- Installation complete. Reboot to activate."
