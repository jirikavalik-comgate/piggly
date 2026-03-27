require 'spec_helper'

module Piggly
  describe Parser, "expressions" do
    include GrammarHelper

    describe "expressionUntilSemiColon" do
      it "does not consume semicolon" do
        # parser stops in front of THEN and dies
        expect{ parse(:expressionUntilSemiColon, 'abc;') }.to raise_error

        node, rest = parse_some(:expressionUntilSemiColon, 'abc; xyz')
        expect(rest).to eq('; xyz')
      end

      it "can be a blank expression" do
        node, rest = parse_some(:expressionUntilSemiColon, ';')
        expect(node).to be_expression
        expect(node.source_text).to eq('')
        expect(rest).to eq(';')
      end

      it "can be a comment" do
        node, rest = parse_some(:expressionUntilSemiColon, "/* comment */;")
        expect(node).to be_expression
        expect(node.count{|e| e.comment? }).to eq(1)

        node, rest = parse_some(:expressionUntilSemiColon, "-- comment\n;")
        expect(node).to be_expression
        expect(node.count{|e| e.comment? }).to eq(1)
      end

      it "can be a string" do
        node, rest = parse_some(:expressionUntilSemiColon, "'string';")
        expect(node).to be_expression
        expect(node.count{|e| e.string? }).to eq(1)

        node, rest = parse_some(:expressionUntilSemiColon, "$$ string $$;")
        expect(node).to be_expression
        expect(node.count{|e| e.string? }).to eq(1)
      end

      it "can be an arithmetic expression" do
        node, rest = parse_some(:expressionUntilSemiColon, "10 * (3 + x);")
        expect(node).to be_expression
      end

      it "can be an SQL statement" do
        node, rest = parse_some(:expressionUntilSemiColon, "SELECT id FROM dataset;")
        expect(node).to be_expression
      end

      it "can be an expression with comments embedded" do
        node, rest = parse_some(:expressionUntilSemiColon, <<-SQL)
          SELECT id                    -- primary key ;
          FROM "dataset" /* ; */       -- previous comments shouldn't terminate expression
          WHERE value IS /*NOT*/ NULL;
        SQL
        expect(node).to be_expression
        expect(node.count{|e| e.comment? }).to eq(4)
      end

      it "can be an expression with strings and comments embedded" do
        node, rest = parse_some(:expressionUntilSemiColon, <<-SQL)
          SELECT id    -- 1. upcoming single quote doesn't matter
          FROM dataset /* 2. this one's no problem either */
          WHERE value LIKE '/* comment within a string! shouldn''t parse a comment */'
            AND length(value) > 10 -- 3. this comment in tail doesn't contain any 'string's
            /* 4. farewell comment in tail */;
        SQL
        expect(node).to be_expression
        expect(node.count{|e| e.comment? }).to eq(4)
        expect(node.count{|e| e.string? }).to eq(1)
      end

      it "can be an expression with strings embedded" do
        node, rest = parse_some(:expressionUntilSemiColon, <<-SQL)
          SELECT id, created_at
          FROM "dataset"
          WHERE value IS NOT NULL
            AND value <> '; this should not terminate expression'
            AND created_at = '2001-01-01';
        SQL
        expect(node).to be_expression
        expect(node.count{|e| e.string? }).to eq(2)
      end

      it "combines trailing whitespace into 'tail' node" do
        node, rest = parse_some(:expressionUntilSemiColon, "a := x + y  \t;")
        expect(node).to be_expression
        expect(node.tail.source_text).to eq("  \t")
      end

      it "combines trailing comments into 'tail' node" do
        node, rest = parse_some(:expressionUntilSemiColon, "a := x + y /* note -- comment */;")
        expect(node).to be_expression
        expect(node.tail.source_text).to eq(' /* note -- comment */')

        node, rest = parse_some(:expressionUntilSemiColon, <<-SQL)
          SELECT id    -- 1. upcoming single quote doesn't matter
          FROM dataset /* 2. this one's no problem either */
          WHERE value LIKE '/* comment within a string! shouldn''t parse a comment */'
            AND length(value) > 10 -- 3. this comment in tail doesn't contain any 'string's
            /* 4. farewell comment in tail */;
        SQL
        expect(node.tail.count{|e| e.comment? }).to eq(2)
      end
    end

    describe "expressionUntilThen" do
      it "does not consume THEN token" do
        # parser stops in front of THEN and dies
        expect{ parse(:expressionUntilThen, 'abc THEN') }.to raise_error

        node, rest = parse_some(:expressionUntilThen, 'abc THEN xyz')
        expect(rest).to eq('THEN xyz')
      end

      it "cannot be a blank expression" do
        expect{ parse_some(:expressionUntilThen, ' THEN') }.to raise_error
      end

      it "cannot be a comment" do
        expect{ parse_some(:expressionUntilThen, "/* comment */ THEN") }.to raise_error
        expect{ parse_some(:expressionUntilThen, "-- comment\n THEN") }.to raise_error
      end

      it "can be a string" do
        node, rest = parse_some(:expressionUntilThen, "'string' THEN")
        expect(node).to be_expression
        expect(node.count{|e| e.string? }).to eq(1)

        node, rest = parse_some(:expressionUntilThen, "$$ string $$ THEN")
        expect(node).to be_expression
        expect(node.count{|e| e.string? }).to eq(1)
      end

      it "can be an arithmetic expression" do
        node, rest = parse_some(:expressionUntilThen, "10 * (3 + x) THEN")
        expect(node).to be_expression
      end

      it "can be an SQL statement" do
        node, rest = parse_some(:expressionUntilThen, "SELECT id FROM dataset THEN")
        expect(node).to be_expression
      end

      it "can be an expression with comments embedded" do
        node, rest = parse_some(:expressionUntilThen, <<-SQL)
          SELECT id                    -- primary key  THEN
          FROM "dataset" /*  THEN */       -- previous comments shouldn't terminate expression
          WHERE value IS /*NOT*/ NULL THEN
        SQL
        expect(node).to be_expression
        expect(node.count{|e| e.comment? }).to eq(4)
      end

      it "can be an expression with strings and comments embedded" do
        node, rest = parse_some(:expressionUntilThen, <<-SQL)
          SELECT id    -- 1. upcoming single quote doesn't matter
          FROM dataset /* 2. this one's no problem either */
          WHERE value LIKE '/* comment within a string! shouldn''t parse a comment */'
            AND length(value) > 10 -- 3. this comment in tail doesn't contain any 'string's
            /* 4. farewell comment in tail */ THEN
        SQL
        expect(node).to be_expression
        expect(node.count{|e| e.comment? }).to eq(4)
        expect(node.count{|e| e.string? }).to eq(1)
      end

      it "can be an expression with strings embedded" do
        node, rest = parse_some(:expressionUntilThen, <<-SQL)
          SELECT id, created_at
          FROM "dataset"
          WHERE value IS NOT NULL
            AND value <> ' THEN this should not terminate expression'
            AND created_at = '2001-01-01' THEN
        SQL
        expect(node).to be_expression
        expect(node.count{|e| e.string? }).to eq(2)
      end

      it "combines trailing whitespace into 'tail' node" do
        node, rest = parse_some(:expressionUntilThen, "a := x + y  \tTHEN")
        expect(node).to be_expression
        expect(node.tail.source_text).to eq("  \t")
      end

      it "combines trailing comments into 'tail' node" do
        node, rest = parse_some(:expressionUntilThen, "a := x + y /* note -- comment */THEN")
        expect(node).to be_expression
        expect(node.tail.source_text).to eq(' /* note -- comment */')

        node, rest = parse_some(:expressionUntilThen, <<-SQL)
          SELECT id    -- 1. upcoming single quote doesn't matter
          FROM dataset /* 2. this one's no problem either */
          WHERE value LIKE '/* comment within a string! shouldn''t parse a comment */'
            AND length(value) > 10 -- 3. this comment in tail doesn't contain any 'string's
            /* 4. farewell comment in tail */THEN
        SQL
        expect(node.tail.count{|e| e.comment? }).to eq(2)
      end
    end

    describe "expressionUntilLoop" do
      it "does not consume LOOP token" do
        # parser stops in front of LOOP and dies
        expect{ parse(:expressionUntilLoop, 'abc LOOP') }.to raise_error

        node, rest = parse_some(:expressionUntilLoop, 'abc LOOP xyz')
        expect(rest).to eq('LOOP xyz')
      end

      it "cannot be a blank expression" do
        expect{ parse_some(:expressionUntilLoop, ' LOOP') }.to raise_error
      end

      it "cannot be a comment" do
        expect{ parse_some(:expressionUntilLoop, "/* comment */ LOOP") }.to raise_error
        expect{ parse_some(:expressionUntilLoop, "-- comment\n LOOP") }.to raise_error
      end

      it "can be a string" do
        node, rest = parse_some(:expressionUntilLoop, "'string' LOOP")
        expect(node).to be_expression
        expect(node.count{|e| e.string? }).to eq(1)

        node, rest = parse_some(:expressionUntilLoop, "$$ string $$ LOOP")
        expect(node).to be_expression
        expect(node.count{|e| e.string? }).to eq(1)
      end

      it "can be an arithmetic expression" do
        node, rest = parse_some(:expressionUntilLoop, "10 * (3 + x) LOOP")
        expect(node).to be_expression
      end

      it "can be an SQL statement" do
        node, rest = parse_some(:expressionUntilLoop, "SELECT id FROM dataset LOOP")
        expect(node).to be_expression
      end

      it "can be an expression with comments embedded" do
        node, rest = parse_some(:expressionUntilLoop, <<-SQL)
          SELECT id                    -- primary key  LOOP
          FROM "dataset" /*  LOOP */       -- previous comments shouldn't terminate expression
          WHERE value IS /*NOT*/ NULL LOOP
        SQL
        expect(node).to be_expression
        expect(node.count{|e| e.comment? }).to eq(4)
      end

      it "can be an expression with strings and comments embedded" do
        node, rest = parse_some(:expressionUntilLoop, <<-SQL)
          SELECT id    -- 1. upcoming single quote doesn't matter
          FROM dataset /* 2. this one's no problem either */
          WHERE value LIKE '/* comment within a string! shouldn''t parse a comment */'
            AND length(value) > 10 -- 3. this comment in tail doesn't contain any 'string's
            /* 4. farewell comment in tail */ LOOP
        SQL
        expect(node).to be_expression
        expect(node.count{|e| e.comment? }).to eq(4)
        expect(node.count{|e| e.string? }).to eq(1)
      end

      it "can be an expression with strings embedded" do
        node, rest = parse_some(:expressionUntilLoop, <<-SQL)
          SELECT id, created_at
          FROM "dataset"
          WHERE value IS NOT NULL
            AND value <> ' LOOP this should not terminate expression'
            AND created_at = '2001-01-01' LOOP
        SQL
        expect(node).to be_expression
        expect(node.count{|e| e.string? }).to eq(2)
      end

      it "combines trailing whitespace into 'tail' node" do
        node, rest = parse_some(:expressionUntilLoop, "a := x + y  \tLOOP")
        expect(node).to be_expression
        expect(node.tail.source_text).to eq("  \t")
      end

      it "combines trailing comments into 'tail' node" do
        node, rest = parse_some(:expressionUntilLoop, "a := x + y /* note -- comment */LOOP")
        expect(node).to be_expression
        expect(node.tail.source_text).to eq(' /* note -- comment */')

        node, rest = parse_some(:expressionUntilLoop, <<-SQL)
          SELECT id    -- 1. upcoming single quote doesn't matter
          FROM dataset /* 2. this one's no problem either */
          WHERE value LIKE '/* comment within a string! shouldn''t parse a comment */'
            AND length(value) > 10 -- 3. this comment in tail doesn't contain any 'string's
            /* 4. farewell comment in tail */LOOP
        SQL
        expect(node.tail.count{|e| e.comment? }).to eq(2)
      end
    end

  end

end
