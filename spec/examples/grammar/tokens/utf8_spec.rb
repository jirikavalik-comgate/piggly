# encoding: UTF-8
require 'spec_helper'

module Piggly
  describe Parser, "UTF-8 tokens" do
    include GrammarHelper

    describe "identifiers with non-ASCII characters" do
      it "can start with a high-byte letter" do
        %w[ošetření výjimka číslo účet řazení].test_each do |s|
          expect(parse(:tIdentifier, s)).to be_identifier
        end
      end

      it "can contain high-byte letters in the middle" do
        %w[has_výjimka cislo_účtu pohledávka_typ].test_each do |s|
          expect(parse(:tIdentifier, s)).to be_identifier
        end
      end

      it "can be a quoted identifier with non-ASCII characters" do
        expect(parse(:tIdentifier, '"Ošetření"')).to be_identifier
      end
    end

    describe "data types with non-ASCII schema/table names" do
      it "can reference a type in a non-ASCII schema" do
        expect(parse(:tType, 'veřejné.stav')).to be_datatype
      end
    end

    describe "full block with UTF-8 identifiers" do
      it "parses a DECLARE block containing non-ASCII variable names" do
        source = <<~PLPGSQL
          DECLARE
            -- Ošetření výjimky
            částka integer := 0;
          BEGIN
            částka := 1;
          END;
        PLPGSQL
        node = parse(:start, source)
        expect(node).not_to be_nil
      end

      it "parses a block with non-ASCII in a comment only" do
        source = <<~PLPGSQL
          DECLARE
            -- komentář s diakritikou: řeřicha
            x integer;
          BEGIN
            x := 1;
          END;
        PLPGSQL
        node = parse(:start, source)
        expect(node).not_to be_nil
      end
    end

    describe "Parser.parse with UTF-8 input" do
      it "parses and returns a tree without encoding errors" do
        source = <<~PLPGSQL
          DECLARE
            částka integer := 0;
          BEGIN
            částka := 1;
          END;
        PLPGSQL
        tree = Parser.parse(source)
        expect { tree.force! }.not_to raise_error
      end

      it "restores original text after parsing" do
        source = <<~PLPGSQL
          DECLARE
            částka integer := 0;
          BEGIN
            částka := 1;
          END;
        PLPGSQL
        original = source.dup
        tree = Parser.parse(source)
        tree.force!
        expect(source).to eq(original)
      end
    end
  end
end
