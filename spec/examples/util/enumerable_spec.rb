require 'spec_helper'

module Piggly::Util

  describe Enumerable do
    before do
      @hash  = {:a => '%', :b => '#'}
      @array = %w(a b c d)
      @range = 'w'..'z'
      @empty = []
    end

    describe "count" do
      it "should default to `size' when no block is given" do
        expect(Enumerable.count(@hash)).to eq(2)
      end

      it "should count items that satisfied block" do
        expect(Enumerable.count(@hash){ true }).to eq(@hash.size)
        expect(Enumerable.count(@array){ false }).to eq(0)
        expect(Enumerable.count(@empty){ true }).to eq(@empty.size)
        expect(Enumerable.count(@range){|c| c < 'z' }).to eq(3)
      end
    end

    describe "sum" do
      it "should append when no block is given" do
        expect(Enumerable.sum(@range)).to eq('wxyz')
        expect(Enumerable.sum(@array)).to eq('abcd')
        expect(Enumerable.sum(@empty)).to eq(0)
      end

      it "should use block return value" do
        expect(Enumerable.sum(@range){ 100 }).to eq(400)
        expect(Enumerable.sum(@empty){ 100 }).to eq(0)
      end
    end

    describe "group_by" do
      it "should return a Hash" do
        expect(Enumerable.group_by(@array){ nil }).to be_a(Hash)
      end

      it "should collect elements into subcollections" do
        expect(Enumerable.group_by(@array){ :a }).to eq({ :a => @array })
        expect(Enumerable.group_by(@array){|x| x <= 'b'}).to eq({ true => %w(a b), false => %w(c d) })
        expect(Enumerable.group_by(@range){|x| x.to_i }).to eq({ 0 => %w(w x y z) })
        expect(Enumerable.group_by(@empty){ false }).to eq({})
      end
    end

    describe "index_by" do
      it "should return a Hash" do
        expect(Enumerable.index_by(@array){ nil }).to be_a(Hash)
      end

      it "should collect only one element per group" do
        expect(Enumerable.index_by(@array){ nil }).to eq({ nil => 'd' })
        expect(Enumerable.index_by(@range){|x| x }).to eq({ 'w' => 'w', 'x' => 'x', 'y' => 'y', 'z' => 'z' })
      end
    end
  end

end
