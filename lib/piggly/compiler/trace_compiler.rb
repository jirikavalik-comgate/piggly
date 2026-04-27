module Piggly
  module Compiler

    #
    # Walks the parse tree, attaching Tag values and rewriting source code to ping them.
    #
    class TraceCompiler
      include Util::Cacheable

      def initialize(config)
        @config = config
      end

      # Is the cache_path is older than its source path or the other files?
      def stale?(procedure)
        Util::File.stale?(cache_path(procedure.source_path(@config)),
                          procedure.source_path(@config),
                          *self.class.cache_sources)
      end

      def compile(procedure, recompile: true)
        source = procedure.source_path(@config)
        cache  = CacheDir.new(cache_path(source))

        if recompile && stale?(procedure)
          begin
          $stdout.puts "Compiling #{procedure.name}"
          tree = Parser.parse(IO.read(procedure.source_path(@config)))
          tree = tree.force! if tree.respond_to?(:thunk?)

          tags = []
          code = traverse(tree, procedure.identifier, tags)

          cache.replace(:tree => tree, :code => code, :tags => tags)
          rescue RuntimeError => e
            $stdout.puts <<-EXMSG
            ****
            Error compiling procedure #{procedure.name}
            Source: #{procedure.source_path(@config)}
            Exception Message:
            #{e.message}
            ****
            EXMSG
          end

        end

        cache
      end

    protected

      def trace_prefix
        @config.trace_prefix
      end

      # Rewrites the parse tree to call instrumentation helpers, and destructively
      # updates `tags` by appending the tags of instrumented nodes
      #   @return [String]
      def traverse(node, oid, tags)
        if node.terminal? or node.expression?
          node.source_text
        else
          if node.respond_to?(:condStub) and node.respond_to?(:cond)
            # Preserve opening parenthesis and whitespace before injecting code. This way 
            # IF(test) becomes IF(piggly_cond(TAG, test)) instead of IFpiggly_cond(TAG, (test))
            pre, cond = node.cond.expr.text_value.match(/\A(\(?[\t\n\r ]*)(.+)\z/m).captures
            node.cond.source_text = ""

            tags << node.cond.tag(oid)

            node.condStub.source_text  = "#{pre}public.piggly_cond($PIGGLY$#{node.cond.tag_id}$PIGGLY$, (#{cond}))"
            node.condStub.source_text << traverse(node.cond.tail, oid, tags) # preserve trailing whitespace
          end

          if node.respond_to?(:bodyStub)
            if node.respond_to?(:exitStub) and node.respond_to?(:cond)
              tags << node.body.tag(oid)
              tags << node.cond.tag(oid)

              # Hack to simulate a loop conditional statement in stmtForLoop and stmtLoop.
              # Use inline RAISE WARNING instead of perform piggly_cond/piggly_branch
              # to avoid corrupting the FOUND variable.
              node.bodyStub.source_text  = "RAISE WARNING '#{trace_prefix} % t', $PIGGLY$#{node.cond.tag_id}$PIGGLY$;#{node.indent(:bodySpace)}"
              node.bodyStub.source_text << "RAISE WARNING '#{trace_prefix} %', $PIGGLY$#{node.body.tag_id}$PIGGLY$;#{node.indent(:bodySpace)}"

              if node.respond_to?(:doneStub)
                # Signal the end of an iteration was reached
                node.doneStub.source_text  = "#{node.indent(:bodySpace)}RAISE WARNING '#{trace_prefix} % %', $PIGGLY$#{node.cond.tag_id}$PIGGLY$, $PIGGLY$@$PIGGLY$;"
                node.doneStub.source_text << node.body.indent
              end

              # Signal the loop terminated
              node.exitStub.source_text  = "\n#{node.indent}RAISE WARNING '#{trace_prefix} % f', $PIGGLY$#{node.cond.tag_id}$PIGGLY$;"
            elsif node.respond_to?(:body)
              # Unconditional branches (or blocks)
              #   BEGIN ... END;
              #   ... ELSE ... END;
              #   CONTINUE label;
              #   EXIT label;
              tags << node.body.tag(oid)
              node.bodyStub.source_text = "RAISE WARNING '#{trace_prefix} %', $PIGGLY$#{node.body.tag_id}$PIGGLY$;#{node.indent(:bodySpace)}"
            end
          end

          # Traverse children (in which we just injected code)
          node.elements.map{|e| traverse(e, oid, tags) }.join
        end
      end
    end

    class << TraceCompiler

      # Each of these files' mtimes are used to determine when another
      # file is stale. Only the procedure source itself is checked;
      # gem-internal files (grammar, parser, nodes) are excluded because
      # their mtimes change on every gem install, causing false
      # invalidation of caches produced by a different installation.
      def cache_sources
        []
      end
    end

  end
end
