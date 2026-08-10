require 'spec_helper'

module Piggly

  describe Dumper::ReifiedProcedure do
    def h(overrides = {}); Piggly.proc_hash(overrides); end

    describe "all" do
      before do
        # stub connection
      end
    end

    describe "from_hash" do
      it "abbreviates known return types" do
        # "integer" from pg_catalog is stored normalized as int4 when quoted
        proc = Dumper::ReifiedProcedure.from_hash(
          h("tschema" => "pg_catalog", "type" => "integer"))
        expect(proc.type.quote).to include("int4")
      end

      it "leaves alone unknown return types" do
        proc = Dumper::ReifiedProcedure.from_hash(
          h("tschema" => "myschema", "type" => "mytype"))
        expect(proc.type.to_s).to eq("myschema.mytype")
      end

      it "abbreviates known argument types" do
        proc = Dumper::ReifiedProcedure.from_hash(
          h("arg_count" => "1", "arg_modes" => "i",
            "arg_names" => "x", "arg_types" => "boolean"))
        expect(proc.arg_types.first.quote).to include('"bool"')
      end

      it "leaves alone unknown argument types" do
        proc = Dumper::ReifiedProcedure.from_hash(
          h("arg_count" => "1", "arg_modes" => "i",
            "arg_names" => "x", "arg_types" => "myschema.mytype"))
        expect(proc.arg_types.first.to_s).to eq("myschema.mytype")
      end

      it "maps known volatilities" do
        { "i" => "immutable", "v" => "volatile", "s" => "stable" }.each do |code, name|
          proc = Dumper::ReifiedProcedure.from_hash(h("volatility" => code))
          expect(proc.volatility).to eq(name)
        end
      end

      it "leaves alone unknown volatilities" do
        proc = Dumper::ReifiedProcedure.from_hash(h("volatility" => "x"))
        expect(proc.volatility).to eq("x")
      end

      it "maps prokind" do
        proc = Dumper::ReifiedProcedure.from_hash(h("kind" => "p"))
        expect(proc.kind).to eq("p")
        expect(proc.procedure?).to be true
      end

      it "defaults kind to function when absent" do
        proc = Dumper::ReifiedProcedure.from_hash(h)
        expect(proc.kind).to eq("f")
        expect(proc.procedure?).to be false
      end

      it "maps known argument modes" do
        { "i" => "in", "o" => "out", "b" => "inout", "v" => "variadic" }.each do |code, name|
          proc = Dumper::ReifiedProcedure.from_hash(
            h("arg_count" => "1", "arg_modes" => code,
              "arg_names" => "x", "arg_types" => "integer"))
          expect(proc.arg_modes.first).to eq(name)
        end
      end

      it "leaves alone unknown argument modes" do
        proc = Dumper::ReifiedProcedure.from_hash(
          h("arg_count" => "1", "arg_modes" => "z",
            "arg_names" => "x", "arg_types" => "integer"))
        expect(proc.arg_modes.first).to eq("z")
      end
    end

    describe "store_source" do
      before do
        allow(Config).to receive(:mkpath) {|root, file| file ? File.join(root, file) : root }
      end

      let(:config) { Config.new }

      context "when source is already instrumented" do
        it "raises an error" do
          proc = Dumper::ReifiedProcedure.from_hash(
            h("source" => "BEGIN $PIGGLY$ END;"))
          expect { proc.store_source(config) }.to \
            raise_error(RuntimeError, /already instrumented/)
        end
      end

      context "when the procedure was identified using the current configuration setting" do
        let(:proc) { Dumper::ReifiedProcedure.from_hash(h) }

        it "does not attempt to remove any files" do
          allow(File).to receive(:open).and_yield(double("io", write: nil))
          expect(FileUtils).not_to receive(:rm_r)
          proc.store_source(config)
        end

        it "writes to the current location" do
          io = double("io", write: nil)
          expect(File).to receive(:open).with(proc.source_path(config), "wb").and_yield(io)
          expect(io).to receive(:write).with(proc.source(config))
          proc.store_source(config)
        end

        it "has the current identified_using property" do
          # identifier is derived from the procedure signature (MD5 of name+args)
          allow(File).to receive(:open).and_yield(double("io", write: nil))
          proc.store_source(config)
          expect(proc.identifier).to eq(Digest::MD5.hexdigest(proc.signature))
        end
      end

      context "when the procedure was identified using some other configuration setting" do
        # The current codebase does not implement identifier-migration; store_source
        # always writes to the current identifier location regardless of prior state.
        let(:proc) { Dumper::ReifiedProcedure.from_hash(h) }

        it "removes any old report files" do
          skip "identifier migration not yet implemented"
        end

        it "removes any old trace cache files" do
          skip "identifier migration not yet implemented"
        end

        it "removes the old source cache files" do
          skip "identifier migration not yet implemented"
        end

        it "writes to the current location" do
          io = double("io", write: nil)
          expect(File).to receive(:open).with(proc.source_path(config), "wb").and_yield(io)
          proc.store_source(config)
        end

        it "updates the identified_using property" do
          skip "identifier migration not yet implemented"
        end
      end
    end
  end

  describe Dumper::SkeletonProcedure do
    def make_proc(overrides = {}); Dumper::ReifiedProcedure.from_hash(Piggly.proc_hash(overrides)); end

    before do
      allow(Config).to receive(:mkpath) {|root, file| file ? File.join(root, file) : root }
    end

    let(:config) { Config.new }

    describe "definition" do
      it "specifies namespace and function name" do
        proc = make_proc("nschema" => "myschema", "name" => "my_func")
        expect(proc.definition("BODY")).to include('"myschema"."my_func"')
      end

      it "specifies source code between dollar-quoted string tags" do
        proc = make_proc
        expect(proc.definition("BODY")).to include("$__PIGGLY__$BODY\n$__PIGGLY__$")
      end

      context "with argument modes" do
        it "specifies argument modes" do
          proc = make_proc(
            "arg_count" => "2", "arg_modes" => "i,o",
            "arg_names" => "a,b", "arg_types" => "integer,integer")
          defn = proc.definition("BODY")
          expect(defn).to include("in ")
          expect(defn).to include("out ")
        end
      end

      context "without argument modes" do
        it "doesn't specify out or inout argument modes" do
          # When no arg_modes are given, all args default to "in" — no out/inout modes
          proc = make_proc(
            "arg_count" => "1", "arg_names" => "x", "arg_types" => "integer")
          defn = proc.definition("BODY")
          expect(defn).not_to include("out ")
          expect(defn).not_to include("inout ")
        end
      end

      context "with strict modifier" do
        it "specifies STRICT token" do
          proc = make_proc("strict" => "t")
          expect(proc.definition("BODY")).to include("strict")
        end
      end

      context "without strict modifier" do
        it "doesn't specify STRICT token" do
          proc = make_proc("strict" => "f")
          expect(proc.definition("BODY")).not_to include("strict")
        end
      end

      context "with security definer modifier" do
        it "specifies SECURITY DEFINER token" do
          proc = make_proc("secdef" => "t")
          expect(proc.definition("BODY")).to include("security definer")
        end
      end

      context "without security definer modifier" do
        it "doesn't specify SECURITY DEFINER token" do
          proc = make_proc("secdef" => "f")
          expect(proc.definition("BODY")).not_to include("security definer")
        end
      end

      context "with set-returning type" do
        it "specifies SETOF token" do
          proc = make_proc("setof" => "t")
          expect(proc.definition("BODY")).to include("setof ")
        end
      end

      context "without non set-returning type" do
        it "doesn't specify SETOF token" do
          proc = make_proc("setof" => "f")
          expect(proc.definition("BODY")).not_to include("setof")
        end
      end

      context "with stable volatility" do
        it "specifies STABLE token" do
          proc = make_proc("volatility" => "s")
          expect(proc.definition("BODY")).to include("stable")
        end
      end

      context "with proconfig SET clauses" do
        it "emits SET clauses after the language declaration" do
          proc = make_proc("proconfig" => "search_path=protected,statement_timeout=5000")
          defn = proc.definition("BODY")
          expect(defn).to include("SET search_path = protected")
          expect(defn).to include("SET statement_timeout = 5000")
        end
      end

      context "without proconfig SET clauses" do
        it "doesn't emit any SET clause" do
          proc = make_proc
          expect(proc.definition("BODY")).not_to include("SET ")
        end
      end

      context "with a skeleton from a legacy index.yml (no @kind ivar)" do
        it "degrades to function behavior" do
          # index.yml files written by piggly < 3.1 serialize SkeletonProcedure
          # without @kind; loading them must behave like a function
          yaml = YAML.dump(make_proc.skeleton).lines.reject{|l| l =~ /^kind:/ }.join
          legacy = YAML.load(yaml, permitted_classes: [
            Piggly::Dumper::SkeletonProcedure,
            Piggly::Dumper::QualifiedType,
            Piggly::Dumper::QualifiedName
          ])

          expect(legacy.kind).to be_nil
          expect(legacy.procedure?).to be false
          expect(legacy.definition("BODY")).to include("create or replace function")
        end
      end

      context "with a procedure (prokind = p)" do
        it "emits CREATE OR REPLACE PROCEDURE" do
          proc = make_proc("kind" => "p", "nschema" => "myschema", "name" => "my_proc")
          expect(proc.definition("BODY")).to include('create or replace procedure "myschema"."my_proc"')
        end

        it "specifies source code between dollar-quoted string tags" do
          proc = make_proc("kind" => "p")
          expect(proc.definition("BODY")).to include("$__PIGGLY__$BODY\n$__PIGGLY__$")
        end

        it "doesn't emit RETURNS, strictness, or volatility" do
          # strict/volatile are invalid attributes in a procedure definition
          proc = make_proc("kind" => "p", "strict" => "t", "volatility" => "v")
          defn = proc.definition("BODY")
          expect(defn).not_to include("returns")
          expect(defn).not_to include("strict")
          expect(defn).not_to include("volatile")
        end

        it "keeps SECURITY DEFINER and proconfig SET clauses" do
          proc = make_proc(
            "kind" => "p", "secdef" => "t", "proconfig" => "search_path=protected")
          defn = proc.definition("BODY")
          expect(defn).to include("security definer")
          expect(defn).to include("SET search_path = protected")
        end
      end
    end

    describe "source_path" do
      let(:proc) { make_proc }

      it "has a .plpgsql extension" do
        expect(proc.source_path(config)).to end_with(".plpgsql")
      end

      it "is within the Dumper directory" do
        expect(proc.source_path(config)).to include("/Dumper/")
      end
    end

    describe "purge_source" do
      let(:proc) { make_proc }
      let(:source_path) { proc.source_path(config) }
      let(:trace_path)  { Compiler::TraceCompiler.new(config).cache_path(source_path) }
      let(:report_path) { Reporter::Base.new(config).report_path(source_path, ".html") }

      before do
        allow(File).to receive(:exist?).and_return(false)
        allow(FileUtils).to receive(:rm_r)
      end

      context "when the procedure was identified using the current configuration setting" do
        before do
          allow(File).to receive(:exist?).with(source_path).and_return(true)
          allow(File).to receive(:exist?).with(trace_path).and_return(true)
          allow(File).to receive(:exist?).with(report_path).and_return(true)
        end

        it "removes the current report files" do
          expect(FileUtils).to receive(:rm_r).with(report_path)
          proc.purge_source(config)
        end

        it "removes the current trace cache files" do
          expect(FileUtils).to receive(:rm_r).with(trace_path)
          proc.purge_source(config)
        end

        it "removes the current source cache files" do
          expect(FileUtils).to receive(:rm_r).with(source_path)
          proc.purge_source(config)
        end

        it "doesn't attempt to remove any other files" do
          expect(FileUtils).to receive(:rm_r).exactly(3).times
          proc.purge_source(config)
        end
      end

      context "when the procedure was identified using some other configuration setting" do
        # Without identifier migration, behaviour is identical to the "current" context above.
        # Once migration is implemented these tests should additionally verify that
        # old-identifier files (report, trace cache, source) are also removed.

        it "removes any old report files" do
          skip "identifier migration not yet implemented"
        end

        it "removes any old trace cache files" do
          skip "identifier migration not yet implemented"
        end

        it "removes any old source cache files" do
          skip "identifier migration not yet implemented"
        end
      end
    end

    describe "equality operator" do
      it "considers two procedures with the same signature equal" do
        a = make_proc
        b = make_proc
        expect(a).to eq(b)
      end

      it "considers two procedures with different signatures not equal" do
        a = make_proc("name" => "func_a")
        b = make_proc("name" => "func_b")
        expect(a).not_to eq(b)
      end
    end
  end

end
