# Furfrou Hair Salon NPC
# Constants for better maintainability
POKEMON_VARIABLE_INDEX = 1
POKEMON_STORAGE_INDEX = 2
CANCEL_OPTION_INDEX = -1
DAYS_UNTIL_HAIRCUT_EXPIRES = 7

HAIRCUTS = [
	_INTL("Heart Cut (Normal/Fairy)"),
	_INTL("Star Cut (Normal/Flying)"),
	_INTL("Diamond Cut (Normal/Rock)"),
	_INTL("Lady Cut (Normal/Electric)"),
	_INTL("Dame Cut (Normal/Psychic)"),
	_INTL("Knight Cut (Normal/Grass)"),
	_INTL("Aristocrat Cut (Normal/Ice)"),
	_INTL("Kabuki Cut (Normal/Fire)"),
	_INTL("Pharaoh Cut (Normal/Water)"),
	_INTL("Cancel")
]

HAIRCUTS_TEXTS = [
	"{1} now has an adorable heart-shaped cut!",
	"{1} shines with its new star cut!",
	"{1} looks elegant with its diamond cut!",
	"{1} looks charming with its lady cut!",
	"{1} radiates elegance with its dame cut!",
	"{1} looks distinguished with its knight cut!",
	"{1} looks majestic with its aristocrat cut!",
	"{1} looks spectacular with its kabuki cut!",
	"{1} looks majestic with its pharaoh cut!"
]
# Helper methods for better code organization

def select_furfrou_from_party
	pbChoosePokemon(POKEMON_VARIABLE_INDEX, POKEMON_STORAGE_INDEX, proc { |pkmn|
		next pkmn.isSpecies?(:FURFROU) && pkmn.able?
	})

	return nil if $game_variables[POKEMON_VARIABLE_INDEX] < 0
	pbGetPokemon(POKEMON_VARIABLE_INDEX)
end

def get_haircut_choice(furfrou)
	pbMessage(_INTL("What haircut style would you like for {1}?", furfrou.name), HAIRCUTS, CANCEL_OPTION_INDEX, nil, furfrou.form)
end

def is_cancel_choice?(choice)
	choice == CANCEL_OPTION_INDEX || choice == HAIRCUTS.length - 1
end

def has_same_haircut?(furfrou, new_form)
	new_form + 1 == furfrou.form
end

def apply_haircut(furfrou, new_form)
	FollowingPkmn.toggle_off if defined?(FollowingPkmn)
	
	# old_form = furfrou.form
	furfrou.form = new_form + 1
	furfrou.time_form_set = pbGetTimeNow.to_i
	furfrou.calc_stats
	
	pbMessage(_INTL("Perfect! {1} has changed its haircut.", furfrou.name))
	
	# Validate array bounds before accessing
	if new_form < HAIRCUTS_TEXTS.length
		pbMessage(_INTL(HAIRCUTS_TEXTS[new_form], furfrou.name))
	end
	
	pbMessage(_INTL("I hope you like {1}'s new look!", furfrou.name))
	pbMessage(_INTL("Remember that after {1} days the haircut will wear off. Come see me again when that happens!", DAYS_UNTIL_HAIRCUT_EXPIRES))
	
	FollowingPkmn.toggle_on if defined?(FollowingPkmn)
end

# Place this code in an event on the map where you want the NPC
def furfrou_hair_salon
	# Code for the NPC event (use in "Script Command"):
	pbMessage(_INTL("Hello! I'm a Furfrou specialist hairstylist."))

	unless pbConfirmMessage(_INTL("Do you want to change your Furfrou's haircut?"))
		pbMessage(_INTL("Alright. Come back when you want a change of look!"))
		return
	end

	# Check if player has a Furfrou in party
	unless $player.has_species?(:FURFROU)
		pbMessage(_INTL("You don't have any Furfrou in your team."))
		pbMessage(_INTL("Bring one next time and I'll give it a spectacular cut."))
		return
	end

	# Open Pokémon selection screen
	pbMessage(_INTL("Perfect! Select the Furfrou you want to change the haircut of."))
	
	chosen_furfrou = select_furfrou_from_party
	unless chosen_furfrou
		pbMessage(_INTL("Come back when you want to change the haircut."))
		return
	end
	
	if chosen_furfrou.fainted?
		pbMessage(_INTL("I can't groom a fainted Pokémon."))
		pbMessage(_INTL("Heal it first and come back."))
		return
	end

	# Show haircut options
	new_form = get_haircut_choice(chosen_furfrou)

	if is_cancel_choice?(new_form)
			pbMessage(_INTL("Alright, maybe another time."))
	elsif has_same_haircut?(chosen_furfrou, new_form)
			pbMessage(_INTL("{1} already has that haircut.", chosen_furfrou.name))
	else
			apply_haircut(chosen_furfrou, new_form)
	end
end
