require "spec_helper"

module Piggly
  module Reporter

    describe HtmlDsl do

      # Minimal host class that includes the mixin
      let(:host) do
        Class.new { include HtmlDsl }.new
      end

      # Capture HTML output via the html() context
      def render(&block)
        out = ""
        host.send(:html, out, &block)
        out
      end

      describe "#e (HTML escaping)" do
        it "escapes &" do
          expect(host.e("a & b")).to eq("a &amp; b")
        end

        it "escapes <" do
          expect(host.e("<tag>")).to eq("&lt;tag&gt;")
        end

        it "escapes >" do
          expect(host.e("1 > 0")).to eq("1 &gt; 0")
        end

        it 'escapes "' do
          expect(host.e('say "hi"')).to eq("say &quot;hi&quot;")
        end

        it "leaves safe characters unchanged" do
          safe = "hello world 123 !@#"
          expect(host.e(safe)).to eq(safe)
        end

        it "escapes multiple special characters in one string" do
          expect(host.e('<a href="/">link & more</a>')).to \
            eq('&lt;a href=&quot;/&quot;&gt;link &amp; more&lt;/a&gt;')
        end
      end

      describe "#tag" do
        it "emits a self-closing tag when no content and no block" do
          out = render { host.send(:tag, "br") }
          expect(out).to eq("<br/>")
        end

        it "emits an open/close tag with inline content" do
          out = render { host.send(:tag, "span", "hello") }
          expect(out).to eq("<span>hello</span>")
        end

        it "emits an open/close tag with a block" do
          out = render do
            host.send(:tag, "div") { host.send(:tag, "span", "x") }
          end
          expect(out).to eq("<div><span>x</span></div>")
        end

        it "emits attributes on a self-closing tag" do
          out = render { host.send(:tag, "input", :type => "text") }
          expect(out).to eq('<input type="text"/>')
        end

        it "emits attributes on a tag with content" do
          out = render { host.send(:tag, "a", "link", :href => "/") }
          expect(out).to eq('<a href="/">link</a>')
        end

        it "accepts attributes on a tag with a block" do
          out = render do
            host.send(:tag, "div", :class => "box") { host.send(:tag, "p", "hi") }
          end
          expect(out).to eq('<div class="box"><p>hi</p></div>')
        end

        it "swaps content/attributes arguments when content is a Hash" do
          # tag("a", href: "/")  should emit <a href="/"/> not  <a "href"="/"/>
          out = render { host.send(:tag, "a", :href => "/") }
          expect(out).to eq('<a href="/"/>')
        end
      end

      describe "#html context management" do
        it "accumulates output in the provided string" do
          out = "prefix:"
          host.send(:html, out) { host.send(:tag, "br") }
          expect(out).to eq("prefix:<br/>")
        end

        it "restores outer context after nested html() call" do
          outer = ""
          host.send(:html, outer) do
            host.send(:tag, "p", "outer")
            inner = ""
            host.send(:html, inner) do
              host.send(:tag, "span", "inner")
            end
            # inner output should be in 'inner', not leaked to outer
            expect(inner).to eq("<span>inner</span>")
            host.send(:tag, "p", "outer2")
          end
          expect(outer).to eq("<p>outer</p><p>outer2</p>")
        end
      end

    end

  end
end
