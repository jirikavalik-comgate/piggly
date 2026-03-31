require 'spec_helper'

module Piggly

  describe Util::Cacheable do

    let(:host_class) do
      Class.new do
        include Piggly::Util::Cacheable
        def self.name; "Piggly::Compiler::TraceCompiler"; end
        def initialize(config); @config = config; end
      end
    end

    let(:config) do
      double('config',
        :cache_root => '/cache',
        :mkpath     => nil)
    end

    subject { host_class.new(config) }

    describe "#cache_path" do
      it "calls config.mkpath with a path under cache_root" do
        allow(config).to receive(:mkpath) {|dir, base| File.join(dir, base) }
        result = subject.cache_path("/some/path/procedure.sql")
        expect(result).to start_with("/cache/")
      end

      it "extracts the class name prefix for the subdirectory" do
        allow(config).to receive(:mkpath) {|dir, base| File.join(dir, base) }
        result = subject.cache_path("/path/to/procedure.sql")
        # "TraceCompiler" -> classdir regex extracts "Trace"
        expect(result).to include("Trace")
      end

      it "uses the basename of the file" do
        allow(config).to receive(:mkpath) {|dir, base| File.join(dir, base) }
        result = subject.cache_path("/some/dir/my_proc.sql")
        expect(result).to include("my_proc.sql")
      end

      it "produces different paths for files with the same name in different directories" do
        allow(config).to receive(:mkpath) {|dir, base| File.join(dir, base) }
        path_a = subject.cache_path("/dir_a/proc.sql")
        path_b = subject.cache_path("/dir_b/proc.sql")
        expect(path_a).not_to eq(path_b)
      end

      it "produces the same hash when cache_root differs but relative path is the same" do
        config_a = double('config_a',
          cache_root: '/builds/project/piggly/cache',
          mkpath: nil)
        config_b = double('config_b',
          cache_root: '/app/piggly/cache',
          mkpath: nil)
        allow(config_a).to receive(:mkpath) {|dir, base| File.join(dir, base) }
        allow(config_b).to receive(:mkpath) {|dir, base| File.join(dir, base) }

        obj_a = host_class.new(config_a)
        obj_b = host_class.new(config_b)

        path_a = obj_a.cache_path("/builds/project/piggly/cache/Dumper/proc.sql")
        path_b = obj_b.cache_path("/app/piggly/cache/Dumper/proc.sql")

        expect(File.basename(path_a)).to eq(File.basename(path_b))
      end
    end

  end

end
