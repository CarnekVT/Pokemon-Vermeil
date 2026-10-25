# frozen_string_literal: true
# This isolated RGBA test protects against the cyan stripe visible at sunset.
# It does not replace a visual test in mkxp.
require_relative '../LA BASE DE SKY/Plugins/[CARNEK] Battle Scene Studio Runtime/99_Hotfix/045_Sunset_Sky_and_Clouds'

stripe = [66, 132, 156, 255]    # Blue band from the supplied screenshot
cloud  = [214, 239, 247, 255]  # Pale blue cloud/sky color
tree   = [32, 59, 44, 255]
orange = [227, 134, 86, 255]
empty  = [0, 0, 0, 0]
source = [stripe, cloud, tree, orange, empty].flatten.pack('C*').b
original = source.dup
BSSSunsetAtmosphere.regrade(source, 5, 1, 0)
result = source.unpack('C*').each_slice(4).to_a
raise 'Cyan stripe unchanged' unless result[0][0] > result[0][2] && result[0][1] > result[0][2]
raise 'Pale clouds still blue' unless result[1][0] > result[1][2] && result[1][1] > result[1][2]
raise 'Tree incorrectly recolored' unless result[2] == tree
raise 'Sunset horizon incorrectly recolored' unless result[3] == orange
raise 'Transparency incorrectly changed' unless result[4] == empty
raise 'Original color source changed' unless original.unpack('C*')[0, 4] == stripe
puts 'BSS sunset atmosphere: 6 isolated RGBA assertions passed'
