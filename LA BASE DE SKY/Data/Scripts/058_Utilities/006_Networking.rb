def network_available?(retries: 3, delay: 0.5)
  retries.times do
    begin
      response = HTTPLite.get("http://httpbin.org/status/200")
      return true if response && response.fetch(:status) == 200
    rescue StandardError, MKXPError
      return false
    end
    pbWait(delay) if retries > 1
  end
  false
end