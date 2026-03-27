require "spec_helper"

module Piggly
  describe "github issue #32" do
    include GrammarHelper

    it "can parse a GET DIAGNOSTICS statement" do
      node = parse(:statement, "GET DIAGNOSTICS v_cnt = ROw_COUNT;")
      expect(node).to be_statement
    end

	it "can parse a procedure with GET DIAGNOSTICS" do
      body = <<-SQL
      DECLARE
        v_cnt INTEGER;
      BEGIN
        INSERT INTO foo.foo_table(bar, barbar_fl, foofoo_fl, bazbaz_ts)
          SELECT
            a.zoorzoor_id,
            b.zap_fl,
            b.zip_fl,
            current_timestamp
          FROM unnest(p_baz) a
            INNER JOIN foo.zimzam b
              ON a.zoor_id = b.zoor_id
        ON CONFLICT (bar)
          DO UPDATE SET barbar_fl= excluded.barbar_fl, foofoo_fl= excluded.foofoo_fl, last_updt_ts=current_timestamp;
        GET DIAGNOSTICS v_cnt = ROW_COUNT;
        RAISE NOTICE Updated % bar stuffs', v_cnt;
        RETURN v_cnt;
      END;
      SQL

      node = parse(:start, body.strip.downcase)
      expect(node.count{|e| e.sql? }).to eq(1)
      expect(node.count{|e| Parser::Nodes::Raise === e }).to eq(1)
      expect(node.count{|e| Parser::Nodes::Return === e }).to eq(1)
    end

  end
end
