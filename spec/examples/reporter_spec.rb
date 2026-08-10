require 'spec_helper'

module Piggly

  describe Reporter::Procedure do
    def make_proc(overrides = {})
      Dumper::ReifiedProcedure.from_hash(Piggly.proc_hash(overrides))
    end

    let(:reporter) { Reporter::Procedure.new(Config.new, double('profile')) }

    describe "signature" do
      context "with a function" do
        it "renders CREATE FUNCTION with RETURNS and volatility" do
          html = reporter.send(:signature, make_proc("volatility" => "v"))
          expect(html).to include("CREATE FUNCTION")
          expect(html).to include("RETURNS")
          expect(html).to include("VOLATILE")
        end

        it "renders STRICT when the function is strict" do
          html = reporter.send(:signature, make_proc("strict" => "t"))
          expect(html).to include("STRICT")
        end
      end

      context "with a procedure (prokind = p)" do
        it "renders CREATE PROCEDURE without RETURNS, STRICT, or volatility" do
          html = reporter.send(:signature,
            make_proc("kind" => "p", "strict" => "t", "volatility" => "v"))
          expect(html).to include("CREATE PROCEDURE")
          expect(html).not_to include("CREATE FUNCTION")
          expect(html).not_to include("RETURNS")
          expect(html).not_to include("STRICT")
          expect(html).not_to include("VOLATILE")
        end

        it "keeps SECURITY DEFINER" do
          html = reporter.send(:signature, make_proc("kind" => "p", "secdef" => "t"))
          expect(html).to include("SECURITY DEFINER")
        end
      end
    end
  end

end
