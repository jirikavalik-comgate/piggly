module Piggly
  module Util
    module File

      # True if target file is older (by mtime) than any source file,
      # or if any source file does not exist.
      def self.stale?(target, *sources)
        if ::File.exist?(target)
          oldest = ::File.mtime(target)
          sources.any? do |x|
            !::File.exist?(x) || ::File.mtime(x) > oldest
          end
        else
          true
        end
      end

    end
  end
end
