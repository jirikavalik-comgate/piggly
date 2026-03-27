require 'spec_helper'

module Piggly

  describe Parser, "statements" do
    include GrammarHelper

    describe "assignment statements" do
      it "parse successfully" do
        node = parse(:statement, "a := 10;")
        expect(node).to be_statement
        expect(node.count{|e| e.assignment? }).to eq(1)

        expect(node.find{|e| e.named? :lval }).to be_a(Parser::Nodes::Assignable)
        expect(node.find{|e| e.named? :rval }).to be_expression
      end

      it "must end with a semicolon" do
        expect{ parse_some(:statement, 'a := 10') }.to raise_error
        expect{ parse(:statement, 'a := 10') }.to raise_error
      end

      it "can use := or =" do
        a = parse(:statement, "a := 10;")
        expect(a).to be_statement
        expect(a.count{|e| e.assignment? }).to eq(1)

        b = parse(:statement, "a = 10;")
        expect(b).to be_statement
        expect(b.count{|e| e.assignment? }).to eq(1)
      end

      it "can assign strings" do
        node = parse(:statement, "a := 'string';")
        rval = node.find{|e| e.named? :rval }
        expect(rval.count{|e| e.string? }).to eq(1)
      end

      it "can assign value expressions containing comments" do
        ['a := /* comment */ 100;',
         'a := 100 /* comment */;',
         'a := 10 /* comment */ + 10;'].test_each do |s|
          node = parse(:statement, s)
          rval = node.find{|e| e.named? :rval }
          expect(rval.count{|e| e.comment? }).to eq(1)
        end
      end

      it "can assign value expressions containing strings" do
        node = parse(:statement, "a := 'Hello,' || space || 'world';")
        rval = node.find{|e| e.named? :rval }
        expect(rval.count{|e| e.string? }).to eq(2)
      end

      it "can assign value expressions containing comments and strings" do
        node = parse(:statement, <<-SQL.strip)
          a := (SELECT fk, count(*), 'not a statement;'
                FROM dataset
                WHERE id > 100 /* filter out 'reserved' range */
                  AND id < 900 -- shouldn't be a string
                   OR value <> 'alpha /* no comment */;'
                GROUP BY /* pk ; 'abc' */ fk);
        SQL
        rval = node.find{|e| e.named? :rval }
        expect(rval.count{|e| e.string? }).to eq(2)
      end
    end

  end
end
