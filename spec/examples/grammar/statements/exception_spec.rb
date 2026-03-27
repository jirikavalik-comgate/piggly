require 'spec_helper'

module Piggly
  describe Parser, "control structures" do
    include GrammarHelper

    describe "exceptions" do
      describe "raise" do
        it "parses successfully" do
          node, rest = parse_some(:statement, "RAISE EXCEPTION 'message';")
          expect(node).to be_statement
          expect(rest).to eq('')
        end

        it "handles exception" do
          node = parse(:statement, "RAISE EXCEPTION 'message';")
          expect(node.count{|e| e.is_a?(Parser::Nodes::Throw) }).to eq(1)
          expect(node.count{|e| e.is_a?(Parser::Nodes::Raise) }).to eq(0)
        end

        it "handles events" do
          %w(WARNING LOG INFO NOTICE DEBUG).each do |event|
            node = parse(:statement, "RAISE #{event} 'message';")
            expect(node.count{|e| e.is_a?(Parser::Nodes::Throw) }).to eq(0)
            expect(node.count{|e| e.is_a?(Parser::Nodes::Raise) }).to eq(1)
          end
        end

        it "doesn't require a message" do
          node = parse(:statement, "RAISE EXCEPTION;")
          expect(node.count{|e| e.is_a?(Parser::Nodes::Throw) }).to eq(1)
          expect(node.count{|e| e.is_a?(Parser::Nodes::Raise) }).to eq(0)
        end

        it "doesn't require a message" do
          %w(WARNING LOG INFO NOTICE DEBUG).each do |event|
            node = parse(:statement, "RAISE #{event};")
            expect(node.count{|e| e.is_a?(Parser::Nodes::Throw) }).to eq(0)
            expect(node.count{|e| e.is_a?(Parser::Nodes::Raise) }).to eq(1)
          end
        end

        it "has default level of EXCEPTION" do
          node = parse(:statement, "RAISE 'message';")
          expect(node.count{|e| e.is_a?(Parser::Nodes::Throw) }).to eq(1)
          expect(node.count{|e| e.is_a?(Parser::Nodes::Raise) }).to eq(0)
        end

        it "doesn't require a level or message" do
          node = parse(:statement, "RAISE;")
          expect(node.count{|e| e.is_a?(Parser::Nodes::Throw) }).to eq(1)
          expect(node.count{|e| e.is_a?(Parser::Nodes::Raise) }).to eq(0)
        end
      end

      describe "catch" do
        before do
          @text = 'BEGIN a := 10; EXCEPTION WHEN cond THEN b := 10; WHEN cond THEN b := 20; END;'
        end

        it "parses successfully" do
          node, rest = parse_some(:statement, @text)
          expect(node).to be_statement
          expect(rest).to eq('')
        end

        it "has Catch node" do
          node = parse(:statement, @text)
          catches = node.select{|e| e.is_a?(Parser::Nodes::Catch) }
          expect(catches.size).to eq(2)

          expect(catches[0].count{|e| e.named?(:cond) and e.expression? }).to eq(1)
          expect(catches[1].count{|e| e.named?(:cond) and e.expression? }).to eq(1)
        end
      end
    end
  end
end
