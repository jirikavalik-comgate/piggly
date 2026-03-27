require 'spec_helper'

module Piggly

=begin
  describe Util::Cacheable do
    before do
      @compiler = Class.new { include Piggly::Util::Cacheable }
      allow(@compiler).to receive(:name).and_return('TestCompiler')
    end

    describe "stale?" do
      it "compares cache_path with source path and cache_sources" do
        allow(@compiler).to receive(:cache_sources).
          and_return(%w(parser.rb grammar.tt nodes.rb))

        expect(@compiler).to receive(:cache_path).
          with('source.sql').
          and_return('source.cache')

        expect(Util::File).to receive(:stale?).
          with('source.cache', 'source.sql', 'parser.rb', 'grammar.tt', 'nodes.rb')

        @compiler.stale?('source.sql')
      end
    end

    describe "cache" do
      before do
        @procedure = double('procedure')
        allow(@procedure).to receive(:source_path).and_return('source path')
        allow(@procedure).to receive(:source).and_return('SOURCE CODE')
        allow(@procedure).to receive(:name).and_return('f')
      end

      context "when cache is stale" do
        before do
          expect(@compiler).to receive(:stale?).
            and_return(true)

          expect(File).to receive(:read).
            with(@procedure.source_path).
            and_return(@procedure.source)
        end

        it "parses the procedure source" do
          allow(@compiler).to receive(:compile).
            and_return(double('result').as_null_object)
          allow(Compiler::Cacheable::CacheDirectory).to receive(:lookup).
            and_return(double('cache').as_null_object)

          expect(Parser).to receive(:parse).
            with(@procedure.source)

          @compiler.cache(@procedure)
        end

        it "passes the parse tree and transient arguments to the compiler" do
          tree  = double('parse tree').as_null_object
          args  = %w(a b c)
          block = lambda{|a,b| b }

          allow(Parser).to receive(:parse).and_return(tree)
          allow(Compiler::Cacheable::CacheDirectory).to receive(:lookup).
            and_return(double('cache').as_null_object)

          # calling cache method below should pass the parse tree plus any
          # arguments given to cache along to the abstract 'compile' method
          expect(@compiler).to receive(:compile).
            with(tree, *args.push(block)).
            and_return(double('result').as_null_object)

          @compiler.cache(@procedure, *args, &block)
        end

        it "updates the cache with the results from the compiler" do
          cache  = double('cache')
          result = double('result')

          allow(Parser).to receive(:parse).
            and_return(double('parse tree').as_null_object)
          expect(@compiler).to receive(:compile).
            # with parse tree
            and_return(result)

          expect(Compiler::Cacheable::CacheDirectory).to receive(:lookup).
            and_return(cache)
          expect(cache).to receive(:replace).
            with(result)

          @compiler.cache(@procedure)
        end

        it "returns the cache object" do
          allow(Parser).to receive(:parse).
            and_return(double('parse tree').as_null_object)
          expect(@compiler).to receive(:compile).
            and_return(double('result'))

          cache = double('cache')
          allow(cache).to receive(:replace)

          expect(Compiler::Cacheable::CacheDirectory).to receive(:lookup).
            and_return(cache)
          
          expect(@compiler.cache(@procedure)).to eq(cache)
        end
      end

      context "when cache is fresh" do
        before do
          expect(@compiler).to receive(:stale?).
            and_return(false)
        end

        it "returns the cached results from disk" do
          cache = double('cache')
          
          expect(Compiler::Cacheable::CacheDirectory).to receive(:lookup).
            and_return(cache)
          
          expect(@compiler.cache(@procedure)).to eq(cache)
        end
      end
    end
  end

  describe Compiler::Cacheable::CacheDirectory do
    before do
      @cache = Compiler::Cacheable::CacheDirectory.new('directory-path')
    end

    describe "[]=" do
      it "stores the new entry" do
        allow(@cache).to receive(:write)
        @cache[:foo] = 'data'
        expect(@cache[:foo]).to eq('data')
        expect(@cache['foo']).to eq('data')
      end

      it "writes through to disk" do
        expect(@cache).to receive(:write).
          with('foo' => 'data')
        @cache['foo'] = 'data'
      end
    end

    describe "update" do
      it "stores new entries" do
        allow(@cache).to receive(:write)
        @cache.update(:abc => 'abacus', :xyz => 'xylophone')
        expect(@cache[:abc]).to eq('abacus')
        expect(@cache[:xyz]).to eq('xylophone')
        expect(@cache['abc']).to eq('abacus')
        expect(@cache['xyz']).to eq('xylophone')
      end

      it "stores updated entries"
      it "writes through to disk"
    end

    describe "replace" do
      it "stores new entries"
      it "stores updated entries"
      it "removes previous entries"
      it "writes through to disk"
    end

    describe "clear" do
      it "removes all entries"
      it "writes through to disk"
    end

    describe "[]" do
      context "when entry is not already in memory" do
        it "reads the entry from disk"
        it "stores the entry in memory"
        it "returns the associated value"
      end

      context "when entry is already in memory" do
        it "does not read the entry from disk"
        it "returns the associated value"
      end
    end

  end
=end

end
