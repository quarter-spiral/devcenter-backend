module Devcenter::Backend
  class Utils
     def self.camelize_string(str)
      str.gsub('-', '_').sub(/^[a-z\d]*/) { $&.capitalize }.gsub(/(?:_|(\/))([a-z\d]*)/i) {$2.capitalize}
    end
  end
end
