#===============================================================================
# ZBOX Enhanced Battle UI Integration
# Fixes two integration issues in the "new MK" branch:
#
# 1. Z-order: BSS087's bss087_enhanced_base_z returns z=300 by default, which
#    is BELOW BSS064::BossHUD (BASE_Z=3000). Move info and battler info panels
#    draw under the BossHUD. This patch extends the base-z calculation to
#    include BossHUD sprites.
#
# 2. Eclipse Fog effects: Enhanced Battle UI's pbGetDisplayEffects does not
#    check Battle Additions' Executioner's Shadow state, so Eclipse fog
#    effects never appear in the battler info panel. This patch adds the
#    Eclipse effect to the display.
#===============================================================================
