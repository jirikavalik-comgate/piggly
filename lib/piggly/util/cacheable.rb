module Piggly
  module Util
    module Cacheable

      def cache_path(file)
        # Up to the last capitalized word of the class name
        classdir = self.class.name[/^(?:.+::)?(.+?)([A-Z][^A-Z]+)?$/, 1]

        # Hash the path relative to cache_root (not the absolute path) so
        # cache directories are portable across environments.
        full = ::File.expand_path(file)
        root = ::File.expand_path(@config.cache_root)
        relative_dir = full.start_with?(root) ?
          ::File.dirname(full[root.length..]) :
          ::File.dirname(full)
        hash = Digest::MD5.hexdigest(relative_dir)
        base = ::File.basename(file)

        path = @config.mkpath(::File.join(@config.cache_root, classdir), "#{hash}-#{base}")

        # Fall back to the legacy scheme (absolute-path hash) for caches
        # created before the portable hashing was introduced.
        unless ::File.exist?(path)
          legacy_hash = Digest::MD5.hexdigest(::File.dirname(full))
          legacy_path = ::File.join(@config.cache_root, classdir, "#{legacy_hash}-#{base}")
          path = legacy_path if ::File.exist?(legacy_path)
        end

        path
      end

    end
  end
end
