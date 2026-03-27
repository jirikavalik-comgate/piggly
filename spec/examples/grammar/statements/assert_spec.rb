require 'spec_helper'

module Piggly
  describe Parser, "control structures" do
    include GrammarHelper

    describe "assert" do
      it "parses minimal assert" do
        node, rest = parse_some(:statement, "ASSERT true;")
        expect(node).to be_statement
        expect(rest).to eq('')
      end

      it "creates Assert node" do
        node = parse(:statement, "ASSERT true;")
        expect(node.count{|e| e.is_a?(Parser::Nodes::Assert) }).to eq(1)
      end

      it "parses expression condition" do
        node = parse(:statement, "ASSERT x > 0;")
        expect(node.count{|e| e.is_a?(Parser::Nodes::Assert) }).to eq(1)
      end

      it "parses assert with message" do
        node = parse(:statement, "ASSERT x > 0, 'x must be positive';")
        expect(node.count{|e| e.is_a?(Parser::Nodes::Assert) }).to eq(1)
      end

      it "parses assert with complex message" do
        node = parse(:statement, "ASSERT (x > 0 AND y > 0), format('values: %s, %s', x, y);")
        expect(node.count{|e| e.is_a?(Parser::Nodes::Assert) }).to eq(1)
      end

      it "has a condition expression" do
        node = parse(:statement, "ASSERT x > 0;")
        assert_node = node.find{|e| e.is_a?(Parser::Nodes::Assert) }
        expect(assert_node).to respond_to(:cond)
        expect(assert_node.cond).to be_a(Parser::Nodes::Expression)
      end

      it "is a branch" do
        node = parse(:statement, "ASSERT true;")
        assert_node = node.find{|e| e.is_a?(Parser::Nodes::Assert) }
        expect(assert_node).to be_branch
      end

      it "has a condStub for instrumentation" do
        node = parse(:statement, "ASSERT x > 0;")
        assert_node = node.find{|e| e.is_a?(Parser::Nodes::Assert) }
        expect(assert_node).to respond_to(:condStub)
      end
    end
  end
end
