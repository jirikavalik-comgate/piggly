module Piggly
  module DatabaseHelper
    FIXTURES_SQL = File.expand_path("../../fixtures/procedures.sql", __FILE__)

    def self.connect
      require "pg"
      require "tmpdir"
      PG::Connection.new(
        host:            ENV["PGHOST"],
        port:            ENV["PGPORT"],
        dbname:          ENV["PGDATABASE"] || "piggly",
        user:            ENV["PGUSER"],
        password:        ENV["PGPASSWORD"])
    end

    def self.load_fixtures(conn)
      conn.exec(File.read(FIXTURES_SQL))
    end

    def self.drop_fixtures(conn)
      conn.exec(<<-SQL)
        DROP FUNCTION IF EXISTS public.test_branches(integer);
        DROP FUNCTION IF EXISTS public.test_loop(integer);
        DROP FUNCTION IF EXISTS public.test_found_exception(integer);
        DROP FUNCTION IF EXISTS public.test_found_after_no_rows();
        DROP FUNCTION IF EXISTS public.test_found_after_rows();
        DROP FUNCTION IF EXISTS public.test_found_while_zero_iterations();
        DROP FUNCTION IF EXISTS public.test_found_for_loop();
        DROP FUNCTION IF EXISTS public.test_found_while_after_rows();
        DROP FUNCTION IF EXISTS piggly_test_ns.piggly_audit(integer);
        DROP SCHEMA  IF EXISTS piggly_test_ns;
      SQL
    end

    def self.drop_helpers(conn)
      # Mirror Installer#uninstall_support: silence "does not exist, skipping"
      # notices from the legacy DROP IF EXISTS cleanup.
      conn.exec("SET client_min_messages = warning")
      begin
        conn.exec("DROP FUNCTION IF EXISTS public.piggly_cond(varchar, boolean)")
        conn.exec("DROP FUNCTION IF EXISTS public.piggly_expr(varchar, varchar)")
        conn.exec("DROP FUNCTION IF EXISTS public.piggly_expr(varchar, anyelement)")
        conn.exec("DROP FUNCTION IF EXISTS public.piggly_branch(varchar)")
        conn.exec("DROP FUNCTION IF EXISTS public.piggly_signal(varchar, varchar)")
      ensure
        conn.exec("RESET client_min_messages")
      end
    end
  end
end

RSpec.shared_context "with database" do
  before(:all) do
    if ENV["PGHOST"]
      begin
        @conn = Piggly::DatabaseHelper.connect
        Piggly::DatabaseHelper.load_fixtures(@conn)
      rescue PG::ConnectionBad, PG::Error
        @conn = nil
      end
    end
  end

  before(:each) do
    skip "No database (PGHOST not set or unreachable)" unless @conn
  end

  after(:all) do
    if @conn
      Piggly::DatabaseHelper.drop_fixtures(@conn)
      Piggly::DatabaseHelper.drop_helpers(@conn)
      @conn.close rescue nil
    end
  end

  let(:conn) { @conn }

  let(:config) do
    require "tmpdir"
    cfg = Piggly::Config.new
    cfg.cache_root = Dir.mktmpdir("piggly-test-cache")
    cfg
  end

  after(:each) do
    FileUtils.rm_rf(config.cache_root) if File.exist?(config.cache_root)
  end

  # Collect all WARNING messages emitted during a block
  def capture_warnings(connection, &block)
    warnings = []
    connection.set_notice_processor {|msg| warnings << msg.strip }
    yield
    warnings
  ensure
    connection.set_notice_processor {|msg| }
  end
end
