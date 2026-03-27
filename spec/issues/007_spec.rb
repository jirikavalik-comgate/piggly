require "spec_helper"

module Piggly
  describe "github issue #7" do
    include GrammarHelper

    it "can loop over dynamic query results" do
      node = parse(:stmtForLoop, "FOR r IN EXECUTE 'SELECT * FROM pg_user;' LOOP END LOOP;")
      expect(node).to be_statement

      cond = node.find{|e| e.named?(:cond) }
      expect(cond.source_text).to eq("EXECUTE 'SELECT * FROM pg_user;' ")
      expect(cond).to be_sql
    end

    it "can loop over dynamic query results when query contains the word 'LOOP'" do
      node = parse(:stmtForLoop, "FOR r IN EXECUTE 'SELECT * FROM pg_user.LOOP;' LOOP END LOOP;")
      expect(node).to be_statement

      cond = node.find{|e| e.named?(:cond) }
      expect(cond.source_text).to eq("EXECUTE 'SELECT * FROM pg_user.LOOP;' ")
      expect(cond).to be_sql
    end
  end
end
