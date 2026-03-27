require 'spec_helper'

module Piggly

  describe Parser, "statements" do
    include GrammarHelper

      describe "SQL keywords" do
        it "parse successfully" do
          GrammarHelper::SQLWORDS.test_each do |k|
            expect(parse(:sqlKeyword, k).source_text).to eq(k)
          end
        end

        it "cannot have trailing characters" do
          GrammarHelper::SQLWORDS.each do |k|
            expect(lambda{ parse(:sqlKeyword, "#{k}abc") }).to raise_error
          end
        end

        it "cannot have preceeding characters" do
          GrammarHelper::SQLWORDS.each do |k|
            expect(lambda{ parse(:sqlKeyword, "abc#{k}") }).to raise_error
          end
        end

        it "are terminated by symbols" do
          GrammarHelper::SQLWORDS.test_each do |k|
            node, rest = parse_some(:sqlKeyword, "#{k}+")
            expect(node.source_text).to eq(k)
            expect(rest).to eq('+')
          end
        end

        it "are terminated by spaces" do
          GrammarHelper::SQLWORDS.test_each do |k|
            node, rest = parse_some(:sqlKeyword, "#{k} ")
            expect(node.source_text).to eq(k)
            expect(rest).to eq(' ')
          end
        end
      end

  end
end
