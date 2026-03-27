require 'spec_helper'

module Piggly
  describe Parser, "tokens" do
    include GrammarHelper

    describe "comments" do
      it "can begin with -- and terminate at EOF" do
        GrammarHelper::COMMENTS.map{|s| "-- #{s}" }.test_each do |s|
          expect(parse(:tComment, s)).to be_comment
        end
      end

      it "can begin with -- and terminate at line ending" do
        GrammarHelper::COMMENTS.map{|s| "-- #{s}\n" }.test_each do |s|
          expect(parse(:tComment, s)).to be_comment
        end

        GrammarHelper::COMMENTS.map{|s| "-- #{s}\n\n" }.test_each do |s|
          node, rest = parse_some(:tComment, s)
          expect(node).to be_comment
          expect(rest).to eq("\n")
        end

        GrammarHelper::COMMENTS.map{|s| "-- #{s}\nremaining cruft\n" }.test_each do |s|
          node, rest = parse_some(:tComment, s)
          expect(node).to be_comment
          expect(rest).to eq("remaining cruft\n")
        end
      end

      it "can be /* c-style */" do
        GrammarHelper::COMMENTS.map{|s| "/* #{s} */" }.test_each do |s|
          expect(parse(:tComment, s)).to be_comment
        end
      end

      it "terminates after */ marker" do
        GrammarHelper::COMMENTS.map{|s| "/* #{s} */remaining cruft\n" }.test_each do |s|
          node, rest = parse_some(:tComment, s)
          expect(node).to be_comment
          expect(rest).to eq("remaining cruft\n")
        end
      end

      it "cannot be nested" do
        node, rest = parse_some(:tComment, "/* nested /*INLINE*/ comments */")
        expect(node).to be_comment
        expect(rest).to eq(" comments */")

        node, rest = parse_some(:tComment, "-- nested -- line comments")
        expect(node.count{|e| e.comment? }).to eq(1)
        expect(rest).to eq('')
      end
    end

  end
end
