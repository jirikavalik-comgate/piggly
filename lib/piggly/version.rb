module Piggly
  module VERSION
    MAJOR = 3
    MINOR = 0
    TINY  = 8

    RELEASE_DATE = "2026-06-09"
  end

  class << VERSION
    def to_s
      [VERSION::MAJOR, VERSION::MINOR, VERSION::TINY].join(".")
    end
  end
end
