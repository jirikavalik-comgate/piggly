require "spec_helper"

module Piggly

  describe "github issue #8" do
    include GrammarHelper

    context "with declare" do
      it "doesn't require a space before the := symbol" do
        node, rest = parse_some(:stmtDeclare, "declare a text:= 10; begin")
      # expect(node.count{|e| e.assignment? }).to eq(1)
        expect(rest).to eq("begin")
      end

      it "doesn't require a space after the := symbol" do
        node, rest = parse_some(:stmtDeclare, "declare a text :=10;")
        expect(rest).to eq("")
      # expect(node.count{|e| e.assignment? }).to eq(1)
      end

      it "doesn't require a space after the := symbol" do
        node, rest = parse_some(:stmtDeclare, "declare a text :=10; begin")
      # expect(node.count{|e| e.assignment? }).to eq(1)
        expect(rest).to eq("begin")
      end

      it "allows escaped strings" do
        node, rest = parse_some(:stmtDeclare, "declare a text :=E'\\001abc'; begin")
      # expect(node.count{|e| e.assignment? }).to eq(1)
        expect(rest).to eq("begin")
      end

      it "allows escaped octal characters" do
        node, rest = parse_some(:stmtDeclare, "declare a text :=E'\\001abc'; begin")
      # expect(node.count{|e| e.assignment? }).to eq(1)
        expect(rest).to eq("begin")
      end
    end

    context "without declare" do
      it "doesn't require a space before the := symbol" do
        node, rest = parse_some(:statement, "a:= 10; begin")
        expect(node.count{|e| e.assignment? }).to eq(1)
        expect(rest).to eq("begin")
      end

      it "doesn't require a space after the := symbol" do
        node = parse(:statement, "a :=10;")
        expect(node).to be_statement
        expect(node.count{|e| e.assignment? }).to eq(1)
      end

      it "doesn't require a space after the := symbol" do
        node, rest = parse_some(:statement, "a :=10; begin")
        expect(node.count{|e| e.assignment? }).to eq(1)
        expect(rest).to eq("begin")
      end

      it "allows escaped strings" do
        node, rest = parse_some(:statement, "a :=E'\\001abc'; begin")
        expect(node.count{|e| e.assignment? }).to eq(1)
        expect(rest).to eq("begin")
      end

      it "allows escaped octal characters" do
        node, rest = parse_some(:statement, "a :=E'\\001abc'; begin")
        expect(node.count{|e| e.assignment? }).to eq(1)
        expect(rest).to eq("begin")
      end
    end

  end
end
