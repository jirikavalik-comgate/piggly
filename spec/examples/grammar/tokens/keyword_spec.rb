require 'spec_helper'

module Piggly
  describe Parser, "tokens" do
    include GrammarHelper
  
    describe "keywords" do
      it "parse successfully" do
        GrammarHelper::KEYWORDS.test_each do |k|
          expect(parse(:keyword, k)).to be_keyword
        end
      end

      it "cannot have trailing characters" do
        GrammarHelper::KEYWORDS.each do |k|
          expect(lambda{ parse(:keyword, "#{k}abc") }).to raise_error
        end
      end

      it "cannot have preceeding characters" do
        GrammarHelper::KEYWORDS.each do |k|
          expect(lambda{ parse(:keyword, "abc#{k}") }).to raise_error
        end
      end

      it "are terminated by symbols" do
        GrammarHelper::KEYWORDS.test_each do |k|
          node, rest = parse_some(:keyword, "#{k}+")
          expect(node).to be_keyword
          expect(rest).to eq('+')
        end
      end

      it "are terminated by spaces" do
        GrammarHelper::KEYWORDS.test_each do |k|
          node, rest = parse_some(:keyword, "#{k} ")
          expect(node).to be_keyword
          expect(rest).to eq(' ')
        end
      end
    end

  end
end
