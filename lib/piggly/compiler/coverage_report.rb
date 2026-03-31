module Piggly
  module Compiler

    #
    # Produces HTML output to report coverage of tagged nodes in the tree
    #
    class CoverageReport
      include Reporter::HtmlDsl

      def initialize(config)
        @config = config
      end

      def compile(procedure, profile)
        trace = Compiler::TraceCompiler.new(@config)

        # Get (copies of) the tagged nodes from the compiled tree
        data = trace.compile(procedure, recompile: false)

        return :html  => traverse(data[:tree], profile),
               :lines => 1 .. procedure.source(@config).count("\n") + 1
      end

    protected

      # @return [String]
      def traverse(node, profile, string = "")
        if node.tagged?
          tag   = profile[node.tag_id]
          inner = ""
          node_content(node, profile, inner)
          # Prevent coverage background from bleeding into the next line's
          # indent: strip trailing newline+whitespace and re-emit outside span.
          trailing = inner.slice!(/\n[ \t]*\z/) || ""
          string << coverage_span(tag) << inner << "</span>" << trailing
        else
          node_content(node, profile, string)
        end
        string
      end

    private

      def coverage_span(tag)
        if tag.complete?
          %[<span class="#{tag.style}" id="T#{tag.id}">]
        else
          %[<span class="#{tag.style}" id="T#{tag.id}" title="#{tag.description}">]
        end
      end

      # Emits node content (terminal text or non-terminal children).
      # Nodes that carry a named :cond (IF, ELSIF, WHILE, FOR, FOREACH, WHEN,
      # EXIT WHEN, CONTINUE WHEN, plain LOOP) get the condition's coverage
      # colour extended across the entire header:
      #   opening keyword(s) + condition expression + THEN/LOOP keyword when
      #   the closing keyword is on the same line as the end of the condition.
      def node_content(node, profile, string)
        if node.terminal?
          if style = node.style
            string << %[<span class="#{style}">#{e(node.text_value)}</span>]
          else
            string << e(node.text_value)
          end
        elsif node.respond_to?(:cond) && node.cond.tagged?
          emit_cond_header_node(node, profile, string)
        else
          emit_children(node.elements, profile, string)
        end
      end

      # For nodes with a tagged :cond child, wraps the opening keywords +
      # condition + optionally the closing THEN/LOOP keyword (when on the same
      # line) in a single coverage span, then emits the remaining elements
      # (body, END IF, …) normally.
      def emit_cond_header_node(node, profile, string)
        elements  = node.elements
        cond_node = node.cond
        cond_idx  = elements.index(cond_node)

        unless cond_idx
          return emit_children(elements, profile, string)
        end

        tag = profile[cond_node.tag_id]

        # Build header: everything before the cond + cond content itself
        header = ""
        elements[0...cond_idx].each { |child| traverse(child, profile, header) }
        node_content(cond_node, profile, header)

        # Absorb THEN/LOOP keyword into the header when it's on the same line
        # as the end of the condition expression.
        rest_idx  = cond_idx + 1
        cond_tail = cond_node.respond_to?(:tail) ? cond_node.tail.text_value : ""
        if cond_tail !~ /\n/
          kw = elements[rest_idx]
          if kw && kw.terminal? && kw.keyword?
            traverse(kw, profile, header)
            rest_idx += 1
          end
        end

        trailing = header.slice!(/\n[ \t]*\z/) || ""
        string << coverage_span(tag) << header << "</span>" << trailing

        emit_children(elements[rest_idx..], profile, string)
      end

      # Emits a list of child elements with two behaviours:
      #
      # 1. Leading-whitespace absorption: consecutive empty/whitespace-only
      #    terminals (including empty stubs between bodySpace and body) before
      #    a tagged sibling are pulled inside that sibling's coverage span so
      #    the indentation gets the same coverage colour as the block body.
      #
      # 2. Trailing-newline strip: before closing each tagged span, any
      #    trailing newline+indent is moved outside so the background does not
      #    bleed into the following line's indentation.
      def emit_children(elements, profile, string)
        # Content from leading empty/whitespace nodes, waiting to be deposited
        # inside the next tagged sibling's span.
        pending = ""

        elements.each do |child|
          if child.tagged?
            tag     = profile[child.tag_id]
            inner   = pending
            pending = ""
            node_content(child, profile, inner)
            trailing = inner.slice!(/\n[ \t]*\z/) || ""
            string << coverage_span(tag) << inner << "</span>" << trailing
          elsif child.terminal? && !child.style && child.text_value.gsub(/[ \t\n]/, "").empty?
            # Empty stub or pure whitespace: defer placement until next tagged node
            pending << e(child.text_value)
          else
            string << pending
            pending = ""
            traverse(child, profile, string)
          end
        end

        string << pending
      end

    end
  end
end
