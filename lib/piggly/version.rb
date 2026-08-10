module Piggly
  module VERSION
    MAJOR = 3
    MINOR = 1
    TINY  = 0

    RELEASE_DATE = "2026-08-10"
  end

  class << VERSION
    def to_s
      [VERSION::MAJOR, VERSION::MINOR, VERSION::TINY].join(".")
    end
  end
end
