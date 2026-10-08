#===============================================================================
# Parche de búsqueda para bases sin actualizar (mismos cambios que 007_Debug List Search
# y 011_BaseSearcher). Si el motor ya define pbFindListIndexBySearch, no hace nada.
#===============================================================================
if !defined?(pbFindListIndexBySearch)

  def pbFuzzyPrefixCompatible?(word, term_clean)
    return true if term_clean.length < 3
    prefix_len = [3, term_clean.length, word.length].min
    prefix = term_clean[0, prefix_len]
    word_prefix = word[0, prefix_len]
    return true if word.start_with?(prefix) || term_clean.start_with?(word_prefix)
    false
  end

  def pbFindListIndexBySearch(names, search_term, current_index = -1)
    return nil if nil_or_empty?(search_term) || names.nil? || names.empty?
    term = pbRemoveAccents(search_term.to_s).downcase
    ranges = [[current_index + 1, names.length]]
    ranges.push([0, current_index]) if current_index >= 0
    ranges.each do |from, to|
      names[from...to].each_with_index do |name, offset|
        name_clean = pbRemoveAccents(name.to_s).downcase
        return from + offset if name_clean.include?(term)
      end
    end
    ranges.each do |from, to|
      names[from...to].each_with_index do |name, offset|
        return from + offset if pbSmartMatch?(name, search_term)
      end
    end
    nil
  end

  alias pbSmartMatch_pre_search_workaround? pbSmartMatch?
  def pbSmartMatch?(text, search_term)
    text_clean = pbRemoveAccents(text.to_s).downcase
    term_clean = pbRemoveAccents(search_term.to_s).downcase
    return true if text_clean.include?(term_clean)
    return false if term_clean.length <= 2
    tolerance = (term_clean.length >= 6) ? 2 : 1
    text_clean.split(" ").each do |word|
      next if !pbFuzzyPrefixCompatible?(word, term_clean)
      if (word.length - term_clean.length).abs <= tolerance
        dist = pbLevenshtein(word, term_clean)
        return true if dist <= tolerance
      end
    end
    if (text_clean.length - term_clean.length).abs <= tolerance + 2 &&
       pbFuzzyPrefixCompatible?(text_clean, term_clean)
      dist_full = pbLevenshtein(text_clean, term_clean)
      return true if dist_full <= tolerance
    end
    false
  end

  module DBK_BaseSearcherSearchWorkaround
    def search_by_name(text, _char = '')
      current_index = get_current_index
      search_list = get_search_list
      return false if search_list.nil? || search_list.empty?
      index = search(text, current_index + 1, search_list.length)
      return on_search_complete(index) if index
      if current_index >= 0
        index = search(text, 0, current_index)
        return on_search_complete(index) if index
      end
      false
    end
  end

  BaseSearcher.prepend(DBK_BaseSearcherSearchWorkaround) if defined?(BaseSearcher)
end
