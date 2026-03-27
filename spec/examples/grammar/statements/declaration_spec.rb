require 'spec_helper'

module Piggly

  describe Parser, "statements" do
    include GrammarHelper

    describe "single variable declarations" do
      it "parse successfully" do
        node = parse(:stmtDeclare, "declare t text;")
        expect(node.count{|e| e.identifier? }).to eq(1)
        expect(node.count{|e| e.datatype? }).to eq(1)
      end

      it "allows an initial assignment" do
        node = parse(:stmtDeclare, "declare a text := 10;")
      end
    end

  end
end
