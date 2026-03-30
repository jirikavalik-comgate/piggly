require 'spec_helper'

module Piggly

describe Installer do

  before do
    @config     = Config.new
    @connection = double('connection')
    @installer  = Installer.new(@config, @connection)
  end

  describe "trace" do
    it "compiles, executes, and profiles the procedure" do
      untraced  = 'create or replace function x(char)'
      traced    = 'create or replace function f(int)'

      result   = {:tags => double('tags'), :code => traced}
      profile  = double('profile')

      compiler = double('compiler', :compile => result)
      expect(Compiler::TraceCompiler).to receive(:new).
        and_return(compiler)

      procedure = double('procedure', :oid => 'oid', :source => untraced)
      expect(procedure).to receive(:definition).
        with(traced).and_return(traced)

      expect(@connection).to receive(:exec).
        with(traced)

      expect(profile).to receive(:add).
        with(procedure, result[:tags], result)

      @installer.trace(procedure, profile)
    end
  end

  describe "untrace" do
    it "executes the original definition" do
      untraced  = 'create or replace function x(char)'
      procedure = double('procedure', :oid => 'oid', :source => untraced)

      expect(procedure).to receive(:definition).
        and_return(untraced)

      expect(@connection).to receive(:exec).
        with(untraced)

      @installer.untrace(procedure)
    end
  end

  describe "install_trace_support"
  describe "uninstall_trace_support"

end

# -------------------------------------------------------------------------
# Database integration tests — require a live PostgreSQL (PGHOST must be set)
# -------------------------------------------------------------------------
describe "Installer (integration)" do
  include_context "with database"

  let(:installer) { Installer.new(config, conn) }
  let(:profile)   { Profile.new }

  let(:branches_proc) do
    Dumper::ReifiedProcedure.all(conn).find do |p|
      p.name.to_s == "public.test_branches"
    end
  end

  let(:loop_proc) do
    Dumper::ReifiedProcedure.all(conn).find do |p|
      p.name.to_s == "public.test_loop"
    end
  end

  # -----------------------------------------------------------------------
  describe "install_support + uninstall_support" do

    around(:each) do |ex|
      next ex.run unless @conn
      installer.send(:install_support, profile)
      ex.run
      installer.send(:uninstall_support)
    end

    it "creates piggly_cond in the public schema" do
      result = conn.exec(<<-SQL).to_a
        SELECT nspname FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE p.proname = 'piggly_cond'
      SQL
      expect(result.map{|r| r["nspname"] }).to include("public")
    end

    it "creates piggly_branch in the public schema" do
      result = conn.exec(<<-SQL).to_a
        SELECT nspname FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE p.proname = 'piggly_branch'
      SQL
      expect(result.map{|r| r["nspname"] }).to include("public")
    end

    it "creates piggly_signal in the public schema" do
      result = conn.exec(<<-SQL).to_a
        SELECT nspname FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE p.proname = 'piggly_signal'
      SQL
      expect(result.map{|r| r["nspname"] }).to include("public")
    end

    it "creates both piggly_expr overloads in the public schema" do
      result = conn.exec(<<-SQL).to_a
        SELECT nspname FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE p.proname = 'piggly_expr'
      SQL
      expect(result.length).to eq(2)
      expect(result.map{|r| r["nspname"] }).to all(eq("public"))
    end

    it "piggly_cond emits WARNING ending in ' t' for true" do
      warnings = capture_warnings(conn) do
        conn.exec("SELECT public.piggly_cond('PIGGLY testid1234', true)")
      end
      expect(warnings.any?{|w| w.end_with?("PIGGLY testid1234 t") }).to be true
    end

    it "piggly_cond emits WARNING ending in ' f' for false" do
      warnings = capture_warnings(conn) do
        conn.exec("SELECT public.piggly_cond('PIGGLY testid1234', false)")
      end
      expect(warnings.any?{|w| w.end_with?("PIGGLY testid1234 f") }).to be true
    end

    it "piggly_cond returns the boolean value unchanged" do
      r_true  = conn.exec("SELECT public.piggly_cond('PIGGLY x', true)  AS v").first["v"]
      r_false = conn.exec("SELECT public.piggly_cond('PIGGLY x', false) AS v").first["v"]
      expect(r_true).to eq("t")
      expect(r_false).to eq("f")
    end

    it "piggly_branch emits WARNING containing the message" do
      warnings = capture_warnings(conn) do
        conn.exec("SELECT public.piggly_branch('PIGGLY branchid')")
      end
      expect(warnings.any?{|w| w.include?("PIGGLY branchid") }).to be true
    end

    it "piggly_signal emits WARNING containing message and signal" do
      warnings = capture_warnings(conn) do
        conn.exec("SELECT public.piggly_signal('PIGGLY sigid', '@')")
      end
      expect(warnings.any?{|w| w.include?("PIGGLY sigid") && w.include?("@") }).to be true
    end

    context "with non-standard search_path (Bug A regression)" do
      it "still creates functions in public regardless of search_path" do
        conn.exec("SET search_path = pg_temp, public")

        # Drop and recreate under altered search_path
        installer.send(:uninstall_support)
        installer.send(:install_support, profile)

        result = conn.exec(<<-SQL).to_a
          SELECT nspname FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
          WHERE p.proname = 'piggly_cond'
        SQL
        expect(result.map{|r| r["nspname"] }).to include("public")
      ensure
        conn.exec("RESET search_path")
      end
    end

    it "uninstall_support removes all five helper functions" do
      installer.send(:uninstall_support)
      result = conn.exec(<<-SQL).to_a
        SELECT proname FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN ('piggly_cond','piggly_branch','piggly_signal','piggly_expr')
      SQL
      expect(result).to be_empty
      # Restore so around(:each) cleanup succeeds
      installer.send(:install_support, profile)
    end

    it "uninstall_support is idempotent" do
      installer.send(:uninstall_support)
      expect { installer.send(:uninstall_support) }.not_to raise_error
      installer.send(:install_support, profile)
    end
  end

  # -----------------------------------------------------------------------
  describe "trace + untrace round-trip" do

    let(:original_source) { branches_proc.source(config) }

    before(:each) do
      branches_proc.store_source(config)
      @traced = false
    end

    after(:each) do
      if @traced
        conn.exec(branches_proc.definition(original_source)) rescue nil
      end
      Piggly::DatabaseHelper.drop_helpers(conn)
    end

    it "traced procedure source contains $PIGGLY$ markers" do
      installer.install([branches_proc], profile)
      @traced = true

      row = conn.exec(<<-SQL).first
        SELECT prosrc FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'test_branches'
      SQL
      expect(row["prosrc"]).to include("$PIGGLY$")
    end

    it "source is restored exactly after untrace" do
      installer.install([branches_proc], profile)
      @traced = true

      installer.uninstall([branches_proc])
      @traced = false

      row = conn.exec(<<-SQL).first
        SELECT prosrc FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'test_branches'
      SQL
      expect(row["prosrc"].strip).to eq(original_source)
    end

    it "raises when trying to store an already-instrumented source" do
      installer.install([branches_proc], profile)
      @traced = true

      traced = Dumper::ReifiedProcedure.all(conn).find do |p|
        p.name.to_s == "public.test_branches"
      end
      expect { traced.store_source(config) }.to raise_error(/already instrumented/)

      installer.uninstall([branches_proc])
      @traced = false
    end
  end

  # -----------------------------------------------------------------------
  describe "encoding" do

    it "connection client_encoding is UTF8" do
      expect(conn.exec("SHOW client_encoding").getvalue(0, 0)).to eq("UTF8")
    end

    it "procedure with UTF-8 source survives trace + untrace byte-for-byte" do
      expect(loop_proc).not_to be_nil
      original = loop_proc.source(config)
      expect(original.encode("UTF-8")).to include("Ošetření")

      loop_proc.store_source(config)
      installer.install([loop_proc], profile)
      installer.uninstall([loop_proc])

      row = conn.exec(<<-SQL).first
        SELECT prosrc FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'test_loop'
      SQL
      expect(row["prosrc"].strip.encode("UTF-8")).to eq(original)
    ensure
      Piggly::DatabaseHelper.drop_helpers(conn)
    end

    it "WARNING messages from notice processor are valid UTF-8" do
      installer.send(:install_support, profile)
      warnings = capture_warnings(conn) do
        conn.exec("SELECT public.piggly_branch('PIGGLY testbranch')")
      end
      warnings.each do |w|
        expect { w.encode("UTF-8") }.not_to raise_error
      end
    ensure
      installer.send(:uninstall_support)
    end
  end

end

end
