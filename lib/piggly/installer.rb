module Piggly

  class Installer
    def initialize(config, connection)
      @config, @connection = config, connection
    end

    # @return [void]
    def install(procedures, profile)
      @connection.exec("begin")

      install_support(profile)

      procedures.each do |p|
        begin
          trace(p, profile)
        rescue Parser::Failure
          $stdout.puts $!
        end
      end

      @connection.exec("commit")
    rescue
      @connection.exec("rollback")
      raise
    end

    # @return [void]
    def uninstall(procedures)
      @connection.exec("begin")

      procedures.each{|p| untrace(p) }
      uninstall_support

      @connection.exec("commit")
    rescue
      @connection.exec("rollback")
      raise
    end

    # @return [void]
    def trace(procedure, profile)
      # recompile with instrumentation
      compiler = Compiler::TraceCompiler.new(@config)
      result   = compiler.compile(procedure)
        # result[:tree] - tagged and rewritten parse tree
        # result[:tags] - collection of Tag values in the tree
        # result[:code] - instrumented

      @connection.exec(procedure.definition(result[:code]))
      
      profile.add(procedure, result[:tags], result)
    rescue
      $!.message << "\nError installing traced procedure #{procedure.name} "
      $!.message << "from #{procedure.source_path(@config)}"
      raise
    end

    # @return [void]
    def untrace(procedure)
      @connection.exec(procedure.definition(procedure.source(@config)))
    end

    # Installs necessary instrumentation support
    def install_support(profile)
      @connection.set_notice_processor(&profile.notice_processor(@config))

    # def connection.set_notice_processor
    #   # do nothing: prevent the notice processor from being subverted
    # end

      # install tracing functions
      @connection.exec <<-SQL
        -- Signals that a conditional expression was executed
        CREATE OR REPLACE FUNCTION public.piggly_cond(message varchar, value boolean)
          RETURNS boolean AS $$
        BEGIN
          IF value THEN
            RAISE WARNING '#{@config.trace_prefix} % t', message;
          ELSE
            RAISE WARNING '#{@config.trace_prefix} % f', message;
          END IF;
          RETURN value;
        END $$ LANGUAGE 'plpgsql' VOLATILE;
      SQL
    end

    # Uninstalls instrumentation support
    def uninstall_support
      @connection.set_notice_processor{|x| $stderr.puts x }
      # Silence "function ... does not exist, skipping" notices from the
      # DROP IF EXISTS cleanup below. The legacy helpers are absent on any
      # database not traced by an older piggly, so those notices are pure
      # noise on every untrace. Suppressing via client_min_messages is
      # locale-independent and still lets genuine WARNINGs reach stderr.
      @connection.exec "SET client_min_messages = warning"
      begin
        @connection.exec "DROP FUNCTION IF EXISTS public.piggly_cond(varchar, boolean)"
        # Legacy helpers that may remain from older piggly versions
        @connection.exec "DROP FUNCTION IF EXISTS public.piggly_expr(varchar, varchar)"
        @connection.exec "DROP FUNCTION IF EXISTS public.piggly_expr(varchar, anyelement)"
        @connection.exec "DROP FUNCTION IF EXISTS public.piggly_branch(varchar)"
        @connection.exec "DROP FUNCTION IF EXISTS public.piggly_signal(varchar, varchar)"
      ensure
        @connection.exec "RESET client_min_messages"
      end
    end
  end

end
