module Piggly
  module Compiler
    StaleCacheError = Class.new(RuntimeError)

    autoload :CacheDir,       "piggly/compiler/cache_dir"
    autoload :TraceCompiler,  "piggly/compiler/trace_compiler"
    autoload :CoverageReport, "piggly/compiler/coverage_report"
  end
end
