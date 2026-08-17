module PokeAPI
	module_function

	CACHE_DURATION = 60 * 24 * 60 * 60 # 60 days in seconds
	CACHE_FILE = File.join("Data", "data_pokeapi.json")

	# Overrides for species whose PokeAPI slug doesn't match the lowercased
	# species ID. A value starting with "-" is appended to the default slug
	# (used when this species' "no suffix" API entry doesn't exist and its
	# default form needs a suffix); any other value replaces the slug outright.
	SPECIES_API_NAME_OVERRIDES = {
		NIDORANfE:    "nidoran-f",
		NIDORANmA:    "nidoran-m",
		MRMIME:       "mr-mime",
		MRMIME_1:     "mr-mime",
		MIMEJR:       "mime-jr",
		WORMADAM:     "-plant",
		MEOWSTIC:     "-male",
		PUMPKABOO:    "-small",
		GOURGEIST:    "-small",
		LYCANROC:     "-midday",
		TYPENULL:     "type-null",
		MINIOR:       "-orange-meteor",
		MIMIKYU:      "-disguised",
		JANGMOO:      "jangmo-o",
		HAKAMOO:      "hakamo-o",
		KOMMOO:       "kommo-o",
		TAPUKOKO:     "tapu-koko",
		TAPUBULU:     "tapu-bulu",
		TAPULELE:     "tapu-lele",
		TAPUFINI:     "tapu-fini",
		TOXTRICITY:   "-amped",
		EISCUE:       "-ice",
		INDEEDEE:     "-male",
		BASCULEGION:  "-male",
		OINKOLOGNE:   "-male",
		MORPEKO:      "-full-belly",
		URSHIFU:      "-single-strike",
		MAUSHOLD:     "-family-of-four",
		SQUAWKABILLY: "-green-plumage",
		PALAFIN:      "-zero",
		TATSUGIRI:    "-curly",
		DUDUNSPARCE:  "-two-segment",
		GREATTUSK:    "great-tusk",
		SCREAMTAIL:   "scream-tail",
		BRUTEBONNET:  "brute-bonnet",
		FLUTTERMANE:  "flutter-mane",
		SLITHERWING:  "slither-wing",
		SANDYSHOCKS:  "sandy-shocks",
		IRONTHREADS:  "iron-threads",
		IRONBUNDLE:   "iron-bundle",
		IRONJUGULIS:  "iron-jugulis",
		IRONMOTH:     "iron-moth",
		IRONTHORNS:   "iron-thorns",
		IRONHANDS:    "iron-hands"
	}

	# Non-default forms: Spanish keyword found in the form name => API slug
	# suffix. Checked only when species.form > 0.
	FORM_NAME_APPEND_KEYWORDS = {
		TAUROS: { "combatiente" => "-combat-breed", "ardiente" => "-blaze-breed", "acuática" => "-aqua-breed" }
	}

	# Non-default forms where the keyword match replaces the form name outright
	# rather than appending to it.
	FORM_NAME_REPLACE_KEYWORDS = {
		CASTFORM:     { "sol" => "sunny", "lluvia" => "rainy", "nieve" => "snowy" },
		BURMY:        { "arena" => "sandy", "basura" => "trash" },
		WORMADAM:     { "arena" => "sandy", "basura" => "trash" },
		CHERRIM:      { "soleada" => "sunshine" },
		PUMPKABOO:    { "extragrande" => "super", "grande" => "large", "normal" => "average" },
		GOURGEIST:    { "extragrande" => "super", "grande" => "large", "normal" => "average" },
		LYCANROC:     { "nocturna" => "midnight", "crepuscular" => "dusk" },
		MINIOR:       { "rojo" => "red", "naranja" => "orange", "amarillo" => "yellow", "verde" => "green",
		                "azul" => "blue", "añil" => "indigo", "violeta" => "purple" },
		MIMIKYU:      { "descubierta" => "busted" },
		TOXTRICITY:   { "grave" => "low-key" },
		EISCUE:       { "deshielo" => "noice" },
		INDEEDEE:     { "hembra" => "female" },
		BASCULEGION:  { "hembra" => "female" },
		OINKOLOGNE:   { "hembra" => "female" },
		MORPEKO:      { "voraz" => "hangry" },
		URSHIFU:      { "fluido" => "rapid-strike" },
		MAUSHOLD:     { "tres" => "family-of-three" },
		SQUAWKABILLY: { "azul" => "blue-plumage", "amarillo" => "yellow-plumage", "blanco" => "white-plumage" },
		TATSUGIRI:    { "lánguida" => "droopy", "recta" => "stretchy" },
		DUDUNSPARCE:  { "trinodular" => "three-segment" }
	}

	# Non-default forms that always map to the same API slug regardless of
	# form name content.
	FORM_NAME_FIXED = {
		MEOWSTIC: "female",
		PALAFIN:  "hero"
	}

	# Whole cache lives in one file, { cache_key => { "data" => {...}, "cached_at" => epoch } }.
	# Loaded once and kept in memory; every write rewrites the file (fine at
	# this size, ~1500 species tops).
	def load_cache_file
		return {} unless File.file?(CACHE_FILE)
		return HTTPLite::JSON.parse(File.read(CACHE_FILE))
	rescue StandardError => e
		echoln "[PokeAPI] Failed to read #{CACHE_FILE}: #{e.message}"
		return {}
	end

	def cache
		@cache ||= load_cache_file
	end

	def save_cache_file
		Dir.create("Data") unless Dir.exist?("Data")
		File.write(CACHE_FILE, HTTPLite::JSON.stringify(cache))
	rescue StandardError => e
		# ponytail: a failed write just skips persisting this once, doesn't break get_data
		echoln "[PokeAPI] Failed to write #{CACHE_FILE}: #{e.message}"
	end

	# Read cached data if present. In :network mode, entries older than
	# CACHE_DURATION are treated as a miss so get_data refreshes them. In
	# :local mode the file is the source of truth and never expires (caller
	# is responsible for updating it).
	def get_cached_data(cache_key)
		entry = cache[cache_key]
		return nil unless entry

		if Settings::POKEAPI_DATA_SOURCE == :network && Time.now.to_i - entry["cached_at"].to_i > CACHE_DURATION
			return nil
		end

		return deserialize(entry["data"])
	end

	# Store data in the in-memory cache and persist the whole file.
	def cache_data(cache_key, data)
		cache[cache_key] = { "data" => serialize(data), "cached_at" => Time.now.to_i }
		save_cache_file
	end

	# parse_data's symbol/integer keys aren't valid JSON keys, so round-trip
	# through plain strings for storage and back to the shape callers expect.
	def serialize(data)
		return {
			"species"   => data["species"].to_s,
			"form"      => data["form"],
			"stats"     => data["stats"].transform_keys(&:to_s),
			"abilities" => data["abilities"].transform_keys(&:to_s),
			"types"     => data["types"].map(&:to_s)
		}
	end

	def deserialize(raw)
		return {
			"species"   => raw["species"].to_sym,
			"form"      => raw["form"],
			"stats"     => raw["stats"].to_h { |k, v| [k.to_sym, v] },
			"abilities" => raw["abilities"].to_h { |k, v| [k.to_sym, v] },
			"types"     => raw["types"].map(&:to_sym)
		}
	end

	# Generate cache key for a species. species.id already uniquely encodes
	# species+form in this engine (base symbol for form 0, BASE_N for form N)
	# so it doesn't need species.form appended too.
	def generate_cache_key(species)
		if species.is_a?(GameData::Species)
			return species.id.to_s
		else
			return species.to_s.downcase
		end
	end

	def get_data(species)
		# Generate cache key for this species
		cache_key = generate_cache_key(species)

		# Try to get cached data first
		cached_data = get_cached_data(cache_key)
		if cached_data
			echoln "[PokeAPI] Using cached data for #{cache_key}"
			return cached_data
		end

		# :local mode only ever reads Data/data_pokeapi.json — never hits the network
		return nil if Settings::POKEAPI_DATA_SOURCE == :local

		if species.is_a?(GameData::Species)
			species_name = get_species_name(species)

			if species.form > 0
				if species.mega_stone || species.mega_move
					species_name += get_mega_form_name(species)
				else
					species_name += get_form_name(species)
				end
			end
		else
			species_name = species.downcase
		end

		uri = "https://pokeapi.co/api/v2/pokemon/#{species_name}"
		begin
			response = pbDownloadToString(uri)
		rescue MKXPError, StandardError => e
			# ponytail: no dedicated "no internet" pre-check (it doubled every
			# request); a failed download just rescues here instead.
			PBDebug.log("[PokeAPI] Download failed for #{cache_key} (#{uri}): #{e.message}")
			return nil
		end
		return nil if response.nil? || response.empty?

		begin
			data = HTTPLite::JSON.parse(response)
		rescue StandardError => e
			PBDebug.log("[PokeAPI] Malformed JSON for #{cache_key} (#{uri}): #{e.message}")
			return nil
		end
		# A resolved-but-wrong slug (404, etc.) still returns valid JSON, just
		# without the fields a real pokemon entry has - treat that as a miss
		# instead of silently caching an empty stats/abilities/types blob.
		if !data.key?("stats")
			PBDebug.log("[PokeAPI] Unexpected response for #{cache_key} (#{uri}): #{data.inspect[0, 200]}")
			return nil
		end
		parsed_data = parse_data(data, species)

		# Cache the successful result
		if parsed_data
			cache_data(cache_key, parsed_data)
			echoln "[PokeAPI] Cached new data for #{cache_key}"
		end

		return parsed_data
	end

	# Fetches every species+form and writes it to Data/data_pokeapi.json, so
	# :local mode has a complete offline dataset afterward. Blocking, only
	# meant to be run once (from the debug menu) in :network mode.
	def download_all
		return [0, 0] if Settings::POKEAPI_DATA_SOURCE != :network
		count = 0
		total = 0
		GameData::Species.each do |species|
			total += 1
			count += 1 if get_data(species)
		end
		return [count, total]
	end

	def get_species_name(species)
		species_name = species.id.to_s.downcase
		species_name.gsub!(/_\d+$/, '')
		override = SPECIES_API_NAME_OVERRIDES[species.id]
		if override
			species_name = override.start_with?("-") ? species_name + override : override
		end
		return species_name
	end


	def parse_data(data, species)
		return nil if !data || data.empty?
		new_stats = {}
		data["species"] = species.is_a?(GameData::Species) ? species.id : species.to_sym
		data["form"] = species.is_a?(GameData::Species) ? species.form : 0
		stat_data = data.fetch("stats", [])
		stat_data.each do |stat|
			stat_name = stat.fetch("stat", {}).fetch("name", "").upcase.tr("-", "_").to_sym
			stat_value = stat.fetch("base_stat", 0)
			next if !stat_name || !stat_value || stat_value <= 0
			new_stats[stat_name] = stat_value
		end
		data["stats"] = new_stats
		abilities_data = data.fetch("abilities", [])
		new_abs = {}
		abilities_data.each do |ability|
			ability_key = ability.fetch("ability", {}).fetch("name", "").upcase.tr("-", "").to_sym
			ability_name = GameData::Ability.try_get(ability_key)&.name
			next if ability_name.nil?
			ability_hidden = ability["is_hidden"]
			ability_index = ability["slot"].to_i
			new_abs[ability_key] = [ability_name, ability_index, ability_hidden]
		end
		data["abilities"] = new_abs

		types = data.fetch("types", [])
		new_types = []
		types.each do |type|
			type_key = type.fetch("type", {}).fetch("name", "").upcase.tr("-", "_").to_sym
			next if !GameData::Type.exists?(type_key)
			new_types << type_key
		end
		data["types"] = new_types
		return data
	end

	def get_mega_form_name(species)
		case species.species
		when :CHARIZARD, :MEWTWO
			letter = (species.form_name || "").split(' ')[2]
			return letter ? "-mega-#{letter.downcase}" : "-mega"
		else
			return "-mega"
		end
	end

	def get_form_name(species)
		species_form_name = (species.form_name || "").downcase
		form_name = species.region && !species.region.empty? ? species.region.downcase : species_form_name.gsub(/forma\s+/, '').strip

		fixed = FORM_NAME_FIXED[species.species]
		if fixed
			form_name = fixed
		else
			keywords = FORM_NAME_REPLACE_KEYWORDS[species.species]
			match = keywords&.find { |keyword, _| species_form_name.include?(keyword) }
			if match
				form_name = match[1]
			else
				keywords = FORM_NAME_APPEND_KEYWORDS[species.species]
				match = keywords&.find { |keyword, _| species_form_name.include?(keyword) }
				form_name += match[1] if match
			end
		end
		return "-#{form_name}"
	end
end
