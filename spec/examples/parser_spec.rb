require 'spec_helper'

module Piggly

describe Parser do
  
  describe "parse" do
    it "returns a thunk" do
      tree = nil

      expect {
        tree = Parser.parse('input')
      }.not_to raise_error

      expect(tree.thunk?).to be true
    end

    context "when the thunk is evaluated" do
      before do
        @parser = double('PigglyParser')
        allow(Parser).to receive(:parser).and_return(@parser)
      end

      it "downcases input string before parsing" do
        input = 'SOURCE CODE'

        allow(@parser).to receive(:failure_reason)
        expect(@parser).to receive(:parse).
          with(input.downcase)

        begin
          Parser.parse(input).force!
        rescue Parser::Failure
          # don't care
        end
      end

      context "when parser fails" do
        it "raises Parser::Failure" do
          input  = 'SOURCE CODE'
          reason = 'expecting someone else'

          expect(@parser).to receive(:parse).
            and_return(nil)
          expect(@parser).to receive(:failure_reason).
            and_return(reason)

          expect {
            Parser.parse('SOURCE CODE').force!
          }.to raise_error(Parser::Failure, reason)
        end
      end

      context "when parser succeeds" do
        it "returns parser's result" do
          input = 'SOURCE CODE'
          tree  = double('NodeClass', :message => 'result')

          expect(@parser).to receive(:parse).
            and_return(tree)

          expect(Parser.parse('SOURCE CODE').message).to eq(tree.message)
        end
      end

    end
  end

  describe "parser" do

    context "when the grammar is older than the generated parser" do
      before do
        allow(Util::File).to receive(:stale?).and_return(false)
      end

      it "does not regenerate the parser" do
        expect(Treetop::Compiler::GrammarCompiler).not_to receive(:new)
      # expect(Parser).to receive(:require).
      #   with(Parser.parser_path)

        Parser.parser
      end

      it "returns an instance of PigglyParser" do
        expect(Parser.parser).to be_a(PigglyParser)
      end
    end

    context "when the generated parser is older than the grammar" do
      before do
        allow(Util::File).to receive(:stale?).and_return(true)
      end

      it "regenerates the parser and loads it" do
        compiler = double('GrammarCompiler')
        expect(compiler).to receive(:compile).
          with(Parser.grammar_path, Parser.parser_path)

        expect(Treetop::Compiler::GrammarCompiler).to receive(:new).
          and_return(compiler)

        expect(Parser).to receive(:load).
          with(Parser.parser_path)

        Parser.parser
      end

      it "returns an instance of PigglyParser" do
        expect(Parser.parser).to be_a(PigglyParser)
      end
    end
  end
end

end
