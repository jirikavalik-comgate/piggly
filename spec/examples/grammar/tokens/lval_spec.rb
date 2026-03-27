require 'spec_helper'

module Piggly
  describe Parser, "tokens" do
    include GrammarHelper

    describe "l-values" do
      it "can be a simple identifier" do
        expect(parse(:lValue, 'id')).to be_a(Parser::Nodes::Assignable)
      end

      it "can be an attribute accessor" do
        expect(parse(:lValue, 'record.id')).to be_a(Parser::Nodes::Assignable)
        expect(parse(:lValue, 'public.dataset.id')).to be_a(Parser::Nodes::Assignable)
      end

      it "can use quoted attributes" do
        expect(parse(:lValue, 'record."ID"')).to be_a(Parser::Nodes::Assignable)
        expect(parse(:lValue, '"schema name"."table name"."column name"')).to be_a(Parser::Nodes::Assignable)
      end
      
      it "can be an array accessor" do
        expect(parse(:lValue, 'names[0]')).to be_a(Parser::Nodes::Assignable)
        expect(parse(:lValue, 'names[1000]')).to be_a(Parser::Nodes::Assignable)
      end

      it "can contain comments in array accessors" do
        node = parse(:lValue, 'names[3 /* comment */]')
        expect(node).to be_a(Parser::Nodes::Assignable)
        expect(node.count{|e| e.comment? }).to eq(1)
        
        node = parse(:lValue, "names[9 -- comment \n]")
        expect(node).to be_a(Parser::Nodes::Assignable)
        expect(node.count{|e| e.comment? }).to eq(1)
      end

      it "can be an array accessed by another l-value" do
        expect(parse(:lValue, 'names[face.id]')).to be_a(Parser::Nodes::Assignable)
      end

      it "can be a nested array access"
        # names[faces[0].id].id doesn't work because it requires context-sensitivity [faces[0]
      
      it "can be a multi-dimensional array access" do
        expect(parse(:lValue, 'data[10][2][0]')).to be_a(Parser::Nodes::Assignable)
      end
    end

  end
end
