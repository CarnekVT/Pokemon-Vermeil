#===============================================================================
# Battle Scene Studio v0.8.30
# v0.8.29 unified-world regression rollback.
#
# IMPORTANT: this filename is intentionally kept so installing v0.8.30 over
# v0.8.29 overwrites the invasive authority that used to live here.
# Camera, battler positions, send-out/recall, Ball and transitions are returned
# to the existing source-faithful/compatibility pipeline. No classes/modules are
# prepended from this file.
#===============================================================================
module BSS105
  VERSION = "0.8.30" unless const_defined?(:VERSION)
  ROLLED_BACK = true unless const_defined?(:ROLLED_BACK)
end
