require 'spec_helper'

module Piggly
  describe Parser, "tokens" do
    include GrammarHelper

    describe "white space" do
      it "includes spaces" do
        node, rest = parse_some(:tSpace, "    ")
        expect(rest).to eq('')
        expect(node.source_text).to eq("    ")
      end

      it "includes tabs" do
        node, rest = parse_some(:tSpace, "\t\t")
        expect(rest).to eq('')
        expect(node.source_text).to eq("\t\t")
      end

      it "includes line feeds" do
        node, rest = parse_some(:tSpace, "\f\f")
        expect(rest).to eq('')
        expect(node.source_text).to eq("\f\f")
      end

      it "includes line breaks" do
        node, rest = parse_some(:tSpace, "\n\n")
        expect(rest).to eq('')
        expect(node.source_text).to eq("\n\n")
      end

      it "includes carriage returns" do
        node, rest = parse_some(:tSpace, "\r\r")
        expect(rest).to eq('')
        expect(node.source_text).to eq("\r\r")
      end
    end

  end
end
