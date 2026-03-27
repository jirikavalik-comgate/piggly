require 'spec_helper'

module Piggly

  describe Parser, "control structures" do
    include GrammarHelper

    describe "if statements" do
      describe "if .. then .. end if" do
        it "must end with a semicolon" do
          expect{ parse(:statement, 'IF cond THEN a := 10; END IF') }.to raise_error
          expect{ parse_some(:stmtIf, 'IF cond THEN a := 10; END IF') }.to raise_error
        end

        it "parses successfully" do
          node, rest = parse_some(:statement, 'IF cond THEN a := 10; END IF;')
          expect(node).to be_statement
          expect(rest).to eq('')
        end

        it "does not have an Else node" do
          node = parse(:statement, 'IF cond THEN a := 10; END IF;')
          expect(node.count{|e| e.else? }).to eq(0)
          expect(node.count{|e| e.named?(:else) and not e.empty? }).to eq(0)
        end

        it "has a 'cond' Expression" do
          node = parse(:statement, 'IF cond THEN a := 10; END IF;')
          expect(node.count{|e| e.named?(:cond) }).to eq(1)
          expect(node.find{|e| e.named?(:cond) }).to be_expression
        end

        it "can have missing body" do
          node = parse(:statement, 'IF cond THEN END IF;')
          expect(node).to be_statement
          expect(node.count{|e| e.if? }).to eq(1)
          expect(node.count{|e| e.named?(:cond) }).to eq(1)
        end

        it "can have comment body" do
          node = parse(:statement, 'IF cond THEN /* removed */ END IF;')
          expect(node).to be_statement
          expect(node.count{|e| e.if? }).to eq(1)
          expect(node.count{|e| e.comment? }).to eq(1)
          expect(node.find{|e| e.comment? }.source_text).to eq('/* removed */')
        end

        it "can have single statement body" do
          node = parse(:statement, 'IF cond THEN a := 10; END IF;')
          expect(node.count{|e| e.if? }).to eq(1)
          expect(node.count{|e| e.assignment? }).to eq(1)
        end

        it "can have multiple statement body" do
          node = parse(:statement, 'IF cond THEN a := 10; b := 10; END IF;')
          expect(node.count{|e| e.if? }).to eq(1)
          expect(node.count{|e| e.assignment? }).to eq(2)
        end

        it "can contain comments" do
          node = parse(:statement, "IF cond /* comment */ THEN -- foo\n  NULL; /* foo */ END IF;")
          expect(node).to be_statement
          expect(node.count{|e| e.comment? }).to eq(3)
        end
      end

      describe "if .. then .. else .. end if" do
        it "parses successfully" do
          node, rest = parse_some(:statement, 'IF cond THEN a := 10; ELSE a := 20; END IF;')
          expect(node).to be_statement
          expect(rest).to eq('')
        end

        it "has an Else node named 'else'" do
          node = parse(:statement, 'IF cond THEN a := 10; ELSE a := 20; END IF;')
          expect(node.count{|e| e.named?(:else) and e.else? }).to eq(1)
          expect(node.find{|e| e.named?(:else) }.source_text).to eq('ELSE a := 20; ')
        end

        it "can have missing else body" do
          node = parse(:statement, 'IF cond THEN a := 10; ELSE END IF;')
          expect(node.count{|e| e.if? }).to eq(1)
          expect(node.count{|e| e.assignment? }).to eq(1)
        end

        it "can have comment body" do
          node = parse(:statement, 'IF cond THEN a := 10; ELSE /* removed */ END IF;')
          expect(node.count{|e| e.if? }).to eq(1)
          expect(node.count{|e| e.comment? }).to eq(1)
          expect(node.count{|e| e.assignment? }).to eq(1)
        end

        it "can have single statement body" do
          node = parse(:statement, 'IF cond THEN a := 10; ELSE a := 20; END IF;')
          expect(node.count{|e| e.if? }).to eq(1)
          expect(node.count{|e| e.assignment? }).to eq(2)
        end

        it "can have multiple statement body" do
          node = parse(:statement, 'IF cond THEN a := 10; ELSE a := 20; b := 30; END IF;')
          expect(node.count{|e| e.if? }).to eq(1)
          expect(node.count{|e| e.assignment? }).to eq(3)
        end
      end

      describe "if .. then .. elsif .. then .. end if" do
        it "parses successfully" do
          node, rest = parse_some(:statement, 'IF cond THEN a := 10; ELSIF cond THEN a := 20; END IF;')
          expect(node).to be_statement
          expect(rest).to eq('')
        end

        it "can have comment body" do
          node = parse(:statement, 'IF cond THEN a := 10; ELSIF cond THEN /* removed */ END IF;')
          expect(node.count{|e| e.if? }).to eq(2)
          expect(node.count{|e| e.comment? }).to eq(1)
          expect(node.count{|e| e.assignment? }).to eq(1)
        end

        it "can having missing body" do
          node = parse(:statement, 'IF cond THEN a := 10; ELSIF cond THEN END IF;')
          expect(node.count{|e| e.if? }).to eq(2)
          expect(node.count{|e| e.assignment? }).to eq(1)
        end

        it "can have single statement body" do
          node = parse(:statement, 'IF cond THEN a := 10; ELSIF cond THEN a := 20; END IF;')
          expect(node.count{|e| e.if? }).to eq(2)
          expect(node.count{|e| e.assignment? }).to eq(2)
        end

        it "can have multiple statement body" do
          node = parse(:statement, 'IF cond THEN a := 10; ELSIF cond THEN a := 20; b := 30; END IF;')
          expect(node.count{|e| e.if? }).to eq(2)
          expect(node.count{|e| e.assignment? }).to eq(3)
        end

        it "can have many elsif branches" do
          node = parse(:statement, <<-SQL.strip)
            IF cond THEN a := 10;
            ELSIF cond THEN a := 20;
            ELSIF cond THEN a := 30;
            ELSIF cond THEN a := 40;
            ELSIF cond THEN a := 50;
            ELSIF cond THEN a := 60;
            END IF;
          SQL

          expect(node.count{|e| e.named?(:cond) }).to eq(6)
          expect(node.count{|e| e.if? }).to eq(6)
          expect(node.count{|e| e.if? and e.named?(:else) }).to eq(5)
        end

        it "has no Else nodes" do
          node = parse(:statement, 'IF cond THEN a := 10; ELSIF cond THEN a := 20; END IF;')
          expect(node.count{|e| e.else? }).to eq(0)
        end
      end

      describe "if .. then .. elsif .. then .. else .. endif" do
        before do
          @text = 'IF cond THEN a := 10; ELSIF cond THEN a := 20; ELSE a := 30; END IF;'
        end

        it "parses successfully" do
          node, rest = parse_some(:statement, @text)
          expect(node).to be_statement
          expect(rest).to eq('')
        end

        it "has an If node named 'else'" do
          node = parse(:statement, @text)
          expect(node.count{|e| e.named?(:else) and e.if? }).to eq(1)
          expect(node.find{|e| e.named?(:else) and e.if? }.source_text).to eq('ELSIF cond THEN a := 20; ELSE a := 30; ')
        end

        it "has an Else node named 'else'" do
          node = parse(:statement, @text)
          expect(node.count{|e| e.named?(:else) and e.else? }).to eq(1)
          expect(node.find{|e| e.named?(:else) and e.else? }.source_text).to eq('ELSE a := 30; ')
        end

        it "has two If nodes" do
          node = parse(:statement, @text)
          expect(node.count{|e| e.if? }).to eq(2)
        end
      end
    end

  end
end
