require 'spec_helper'
require 'tmpdir'
require 'fileutils'

module Piggly

  describe Compiler::TraceCompiler, "cache staleness during report" do
    let(:config) do
      c = Config.new
      c.cache_root = @tmpdir
      c
    end

    let(:source) { "DECLARE x int;\nBEGIN\n  IF x > 0 THEN\n    x := 1;\n  END IF;\nEND;" }

    let(:procedure) do
      p = Dumper::ReifiedProcedure.from_hash(Piggly.proc_hash(
        "oid"    => "9999",
        "source" => source
      ))
      p.store_source(config)
      p.skeleton
    end

    before(:each) do
      @tmpdir = Dir.mktmpdir("piggly-test")
    end

    after(:each) do
      FileUtils.rm_rf(@tmpdir)
    end

    it "uses cached tags when cache is fresh (report scenario)" do
      compiler = Compiler::TraceCompiler.new(config)

      # First compile — populates cache
      result1 = compiler.compile(procedure)
      tags1   = result1[:tags].map(&:id)
      expect(tags1).not_to be_empty

      # Simulate report-only run: create a new compiler instance,
      # cache should be fresh → returns same tags without recompiling
      compiler2 = Compiler::TraceCompiler.new(config)
      expect(compiler2.stale?(procedure)).to be false

      result2 = compiler2.compile(procedure)
      tags2   = result2[:tags].map(&:id)

      expect(tags2).to eq(tags1)
    end

    it "recompiles and generates different tags when source is newer" do
      compiler = Compiler::TraceCompiler.new(config)

      # First compile
      result1 = compiler.compile(procedure)
      tags1   = result1[:tags].map(&:id)

      # Touch the procedure source to make the cache stale
      sleep 0.05
      FileUtils.touch(procedure.source_path(config))

      compiler2 = Compiler::TraceCompiler.new(config)
      expect(compiler2.stale?(procedure)).to be true

      result2 = compiler2.compile(procedure)
      tags2   = result2[:tags].map(&:id)

      # New compilation generates DIFFERENT tag IDs
      expect(tags2).not_to eq(tags1)
    end

    it "stale recompilation causes tag mismatch in Profile" do
      compiler = Compiler::TraceCompiler.new(config)

      # Simulate trace job: compile and register tags
      result1 = compiler.compile(procedure)
      tags1   = result1[:tags]

      profile = Profile.new
      profile.add(procedure, tags1, result1)

      # Record some coverage using original tags
      tags1.each { |t| profile.ping(t.id) }

      # Touch the procedure source to make cache stale
      sleep 0.05
      FileUtils.touch(procedure.source_path(config))

      # Simulate report job: recompile with stale cache
      compiler2 = Compiler::TraceCompiler.new(config)
      result2 = compiler2.compile(procedure)
      tags2   = result2[:tags]

      # Create a fresh profile for the report (as report command does)
      report_profile = Profile.new
      report_profile.add(procedure, tags2, result2)

      # Try to ping using ORIGINAL tag IDs (from trace log) — fails
      expect {
        report_profile.ping(tags1.first.id)
      }.to raise_error(RuntimeError, /No tag with id/)
    end

    it "with recompile: false, returns cached tags even when stale" do
      compiler = Compiler::TraceCompiler.new(config)

      # First compile — populates cache
      result1 = compiler.compile(procedure)
      tags1   = result1[:tags].map(&:id)

      # Touch the procedure source to make cache stale
      sleep 0.05
      FileUtils.touch(procedure.source_path(config))

      compiler2 = Compiler::TraceCompiler.new(config)
      expect(compiler2.stale?(procedure)).to be true

      # recompile: false skips staleness, returns existing cache
      result2 = compiler2.compile(procedure, recompile: false)
      tags2   = result2[:tags].map(&:id)

      expect(tags2).to eq(tags1)
    end
  end

end
