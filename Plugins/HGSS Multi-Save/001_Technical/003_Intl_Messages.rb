#===============================================================================
#
#===============================================================================
class Translation
  def self.month_day_date_format?
    return System.user_language[3..4] == "US"   # If the user is in the United States
  end
end
