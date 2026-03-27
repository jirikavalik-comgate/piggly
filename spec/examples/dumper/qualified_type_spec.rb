require "spec_helper"

module Piggly
  module Dumper

    describe QualifiedType do

      describe ".unquote" do
        it "strips surrounding double quotes" do
          expect(QualifiedType.unquote('"foo"')).to eq("foo")
        end

        it "returns the string unchanged when not quoted" do
          expect(QualifiedType.unquote("foo")).to eq("foo")
        end

        it "returns nil unchanged" do
          expect(QualifiedType.unquote(nil)).to be_nil
        end
      end

      describe ".parse" do
        it "parses a plain name with no schema" do
          t = QualifiedType.parse("mytype")
          expect(t.schema).to be_nil
          expect(t.name).to eq("mytype")
        end

        it "parses schema.name dot notation" do
          t = QualifiedType.parse("public.mytype")
          expect(t.schema).to eq("public")
          expect(t.name).to eq("mytype")
        end

        it "uses explicit schema argument when provided" do
          t = QualifiedType.parse("pg_catalog", "int4")
          expect(t.schema).to eq("pg_catalog")
          expect(t.name).to eq("int4")
        end

        it "strips double quotes from name" do
          t = QualifiedType.parse('"mytype"')
          expect(t.name).to eq("mytype")
        end

        it "detects array suffix []" do
          t = QualifiedType.parse("int8[]")
          expect(t.name).to eq("int8")
          expect(t.to_s).to include("[]")
        end

        it "handles array type with schema" do
          t = QualifiedType.parse("public.mytype[]")
          expect(t.schema).to eq("public")
          expect(t.name).to eq("mytype")
          expect(t.to_s).to eq("public.mytype[]")
        end
      end

      describe "#table?" do
        it "returns false for a regular type" do
          expect(QualifiedType.new(nil, "int4", "").table?).to be false
        end
      end

      describe "#shorten" do
        it "returns a new type with schema set to nil" do
          t = QualifiedType.new("public", "mytype", "")
          short = t.shorten
          expect(short.schema).to be_nil
          expect(short.name).to eq("mytype")
        end

        it "preserves the array suffix" do
          t = QualifiedType.new("public", "mytype", "[]")
          expect(t.shorten.to_s).to include("[]")
        end
      end

      describe "#==" do
        it "is equal when to_s matches" do
          a = QualifiedType.new(nil, "int4", "")
          b = QualifiedType.new(nil, "int4", "")
          expect(a).to eq(b)
        end

        it "is not equal when names differ" do
          a = QualifiedType.new(nil, "int4", "")
          b = QualifiedType.new(nil, "int8", "")
          expect(a).not_to eq(b)
        end
      end

      describe "#to_s — readable name mapping" do
        def t(schema, name, array = "")
          QualifiedType.new(schema, name, array)
        end

        it "suppresses pg_catalog schema prefix" do
          expect(t("pg_catalog", "int4").to_s).to eq("int")
        end

        it "suppresses nil schema prefix" do
          expect(t(nil, "text").to_s).to eq("text")
        end

        it "includes custom schema prefix" do
          expect(t("myschema", "mytype").to_s).to eq("myschema.mytype")
        end

        it "converts int2 to smallint" do
          expect(t("pg_catalog", "int2").to_s).to eq("smallint")
        end

        it "converts int4 to int" do
          expect(t("pg_catalog", "int4").to_s).to eq("int")
        end

        it "converts int8 to bigint" do
          expect(t("pg_catalog", "int8").to_s).to eq("bigint")
        end

        it "converts float4 to real" do
          expect(t("pg_catalog", "float4").to_s).to eq("real")
        end

        it "converts bpchar to char" do
          expect(t("pg_catalog", "bpchar").to_s).to eq("char")
        end

        it "converts serial4 to serial" do
          expect(t("pg_catalog", "serial4").to_s).to eq("serial")
        end

        it "includes array suffix in to_s" do
          expect(t("pg_catalog", "int8", "[]").to_s).to eq("bigint[]")
        end

        it "converts _int4 (internal array notation) to int[]" do
          expect(t("pg_catalog", "_int4", "").to_s).to eq("int[]")
        end
      end

      describe "#quote — normalize() for SQL emission" do
        def t(schema, name, array = "")
          QualifiedType.new(schema, name, array)
        end

        it "normalizes 'bigint' to 'int8' in SQL" do
          expect(t(nil, "bigint").quote).to eq('"int8"')
        end

        it "normalizes 'boolean' to 'bool' in SQL" do
          expect(t(nil, "boolean").quote).to eq('"bool"')
        end

        it "normalizes 'character varying' to 'varchar' in SQL" do
          expect(t(nil, "character varying").quote).to eq('"varchar"')
        end

        it "normalizes 'character' to 'bpchar' in SQL" do
          expect(t(nil, "character").quote).to eq('"bpchar"')
        end

        it "normalizes 'smallint' to 'int2' in SQL" do
          expect(t(nil, "smallint").quote).to eq('"int2"')
        end

        it "normalizes 'integer' to 'int4' in SQL" do
          expect(t(nil, "integer").quote).to eq('"int4"')
        end

        it "normalizes 'double precision' to 'float8' in SQL" do
          expect(t(nil, "double precision").quote).to eq('"float8"')
        end

        it "normalizes 'real' to 'float4' in SQL" do
          expect(t(nil, "real").quote).to eq('"float4"')
        end

        it "normalizes 'timestamp without time zone' to 'timestamp' in SQL" do
          expect(t(nil, "timestamp without time zone").quote).to eq('"timestamp"')
        end

        it "normalizes 'timestamp with time zone' to 'timestamptz' in SQL" do
          expect(t(nil, "timestamp with time zone").quote).to eq('"timestamptz"')
        end

        it "bypasses normalization for non-pg_catalog schemas" do
          expect(t("public", "bigint").quote).to include('"bigint"')
        end

        it "includes schema in quoted output" do
          expect(t("public", "mytype").quote).to eq('"public"."mytype"')
        end

        it "includes array suffix in quoted output" do
          expect(t(nil, "boolean").quote).to eq('"bool"')
          # with array; pg_catalog schema still normalizes name
          expect(t("pg_catalog", "boolean", "[]").quote).to eq('"pg_catalog"."bool"[]')
        end
      end

    end

    describe RecordType do
      it "#table? returns true" do
        rt = RecordType.new([], [], [], [])
        expect(rt.table?).to be true
      end

      it "quotes column list with types" do
        col_type = QualifiedType.new(nil, "int4", "")
        col_name = QualifiedName.new(nil, "id")
        rt = RecordType.new([col_type], [col_name], ["in"], [nil])
        expect(rt.quote).to eq("table (\"id\" \"int4\")")
      end
    end

  end
end
