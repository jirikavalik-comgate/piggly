require "spec_helper"

module Piggly
  module Dumper

    describe QualifiedName do

      describe "#quote" do
        it "wraps name in double quotes when schema is nil" do
          expect(QualifiedName.new(nil, "my_func").quote).to eq('"my_func"')
        end

        it "wraps both schema and name in double quotes" do
          expect(QualifiedName.new("public", "my_func").quote).to eq('"public"."my_func"')
        end
      end

      describe "#to_s" do
        it "returns just the name when schema is nil" do
          expect(QualifiedName.new(nil, "my_func").to_s).to eq("my_func")
        end

        it "returns schema.name when schema is present" do
          expect(QualifiedName.new("public", "my_func").to_s).to eq("public.my_func")
        end
      end

      describe "#==" do
        it "is equal when to_s representations match" do
          a = QualifiedName.new("public", "my_func")
          b = QualifiedName.new("public", "my_func")
          expect(a).to eq(b)
        end

        it "is not equal when schemas differ" do
          a = QualifiedName.new("public", "my_func")
          b = QualifiedName.new("private", "my_func")
          expect(a).not_to eq(b)
        end

        it "is not equal when names differ" do
          a = QualifiedName.new("public", "func_a")
          b = QualifiedName.new("public", "func_b")
          expect(a).not_to eq(b)
        end

        it "is equal between nil-schema and no-schema when names match" do
          a = QualifiedName.new(nil, "my_func")
          b = QualifiedName.new(nil, "my_func")
          expect(a).to eq(b)
        end
      end

      describe "attribute readers" do
        it "exposes schema" do
          expect(QualifiedName.new("public", "fn").schema).to eq("public")
        end

        it "exposes name" do
          expect(QualifiedName.new("public", "fn").name).to eq("fn")
        end
      end

    end

  end
end
