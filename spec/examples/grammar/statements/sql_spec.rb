require 'spec_helper'

module Piggly
  describe Parser, "statements" do
    include GrammarHelper

    describe "SQL statements" do
      it "parse successfully" do
        node, rest = parse_some(:statement, 'SELECT id FROM users;')
        expect(node).to be_statement
        expect(node.count{|e| e.sql? }).to eq(1)
        expect(node.find{|e| e.sql? }.source_text).to eq('SELECT id FROM users;')
        expect(rest).to eq('')
      end

      it "must end with a semicolon" do
        expect{ parse(:statement, 'SELECT id FROM users') }.to raise_error
        expect{ parse_some(:statement, 'SELECT id FROM users') }.to raise_error
      end

      it "can contain comments" do
        node = parse(:statement, <<-SQL.strip)
          SELECT INTO user u.id, /* u.name */, p.fist_name, p.last_name
          FROM users u
          INNER JOIN people p ON p.id = u.person_id
          WHERE u.disabled -- can't login
            AND u.id = 100;
        SQL
        sql = node.find{|e| e.sql? }
        expect(sql.count{|e| e.comment? }).to eq(2)
      end

      it "can be followed by comments" do
        node, rest = parse_some(:statement, 'SELECT id FROM users; -- comment')
        node.find{|e| e.sql? }.source_text == 'SELECT id FROM users;'
        expect(node.tail.source_text).to eq(' -- comment')
        expect(rest).to eq('')
      end
      
      it "can be followed by whitespace" do
        node, rest = parse_some(:statement, "SELECT id FROM users;    \n")
        node.find{|e| e.sql? }.source_text == 'SELECT id FROM users;'
        expect(node.tail.source_text).to eq("    \n")
        expect(rest).to eq('')
      end

      it "can contain strings" do
        node, rest = parse_some(:statement, <<-SQL.strip)
          SELECT INTO user u.id, u.first_name, u.last_name
          FROM users u
          WHERE first_name ILIKE '%a%'
             OR last_name ILIKE '%b%';
        SQL
        sql = node.find{|e| e.sql? }
        expect(sql.count{|e| e.string? }).to eq(2)
      end

      it "can contain strings and comments" do
        node = parse(:statement, <<-SQL.strip)
          a := (SELECT fk, count(*), 'not a statement;'
                FROM dataset
                WHERE id > 100 /* filter out 'reserved' range */
                  AND id < 900 -- shouldn't be a string
                   OR source_text <> 'alpha /* no comment */;'
                GROUP BY /* pk ; 'abc' */ fk);
        SQL
      end

    end
  end
end
