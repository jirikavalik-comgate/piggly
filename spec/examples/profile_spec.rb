require 'spec_helper'

module Piggly

describe Profile do

  before do
    @profile = Profile.new
  end

  describe "notice_processor" do
    before do
      @config = double('config', :trace_prefix => 'PIGGLY')
      @stderr = double('stderr').as_null_object
      @callback = @profile.notice_processor(@config, @stderr)
    end

    it "returns a function" do
      expect(@callback).to be_a(Proc)
    end

    context "when message matches PATTERN" do
      context "with no optional value" do
        it "pings the corresponding tag" do
          message = "WARNING:  #{@config.trace_prefix} 0123456789abcdef"
          expect(@profile).to receive(:ping).
            with('0123456789abcdef', nil)

          @callback.call(message)
        end
      end

      context "with an optional value" do
        it "pings the corresponding tag" do
          message = "WARNING:  #{@config.trace_prefix} 0123456789abcdef X"
          expect(@profile).to receive(:ping).
            with('0123456789abcdef', 'X')

          @callback.call(message)
        end
      end
    end

    context "when message doesn't contain trace prefix" do
      it "silently skips the message" do
        message = "WARNING:  Parameter was NULL and I don't like it!"
        expect(@stderr).not_to receive(:puts)
        @callback.call(message)
      end
    end

    context "when message contains trace prefix but doesn't match PATTERN" do
      it "prints the message to stderr" do
        message = "WARNING:  #{@config.trace_prefix} not-a-valid-tag"
        expect(@stderr).to receive(:puts).with("unknown trace: #{message}")
        @callback.call(message)
      end
    end
  end

  describe "add" do
    before do
      @first  = double('first tag',  :id => 'first')
      @second = double('second tag', :id => 'second')
      @third  = double('third tag',  :id => 'third')
      @cache  = double('Compiler::Cacheable::CacheDirectory')

      @procedure = Dumper::SkeletonProcedure.allocate
      allow(@procedure).to receive(:oid).and_return('oid')
    end

    context "without cache parameter" do
      it "indexes each tag by id" do
        @profile.add(@procedure, [@first, @second, @third])
        expect(@profile[@first.id]).to eq(@first)
        expect(@profile[@second.id]).to eq(@second)
        expect(@profile[@third.id]).to eq(@third)
      end

      it "indexes each tag by procedure" do
        @profile.add(@procedure, [@first, @second, @third])
        expect(@profile[@procedure]).to eq([@first, @second, @third])
      end
    end

    context "with cache parameter" do
      it "indexes each tag by id" do
        @profile.add(@procedure, [@first, @second, @third], @cache)
        expect(@profile[@first.id]).to eq(@first)
        expect(@profile[@second.id]).to eq(@second)
        expect(@profile[@third.id]).to eq(@third)
      end

      it "indexes each tag by procedure" do
        @profile.add(@procedure, [@first, @second, @third])
        expect(@profile[@procedure]).to eq([@first, @second, @third])
      end
    end
  end

  describe "ping" do
    context "when tag isn't in the profile" do
      it "raises an exception" do
        expect {
          @profile.ping('0123456789abcdef')
        }.to raise_error('No tag with id 0123456789abcdef')
      end
    end

    context "when tag is in the profile" do
      before do
        @tag = double('tag', :id => '0123456789abcdef')
        procedure = double('procedure', :oid => nil)
        @profile.add(procedure, [@tag])
      end

      it "calls ping on the corresponding tag" do
        expect(@tag).to receive(:ping).with('X')
        @profile.ping(@tag.id, 'X')
      end
    end
  end

  describe "summary" do
    def make_tag(type, pct)
      tag = double("tag-#{type}-#{pct}", :type => type, :to_f => pct.to_f)
      allow(tag).to receive(:id).and_return("id#{tag.object_id}")
      tag
    end

    context "when not given a procedure" do
      it "returns an empty hash when no tags have been added" do
        expect(@profile.summary).to be_empty
      end

      it "groups tags by type and averages percentages" do
        b1 = make_tag(:branch, 100)
        b2 = make_tag(:branch,   0)
        k1 = make_tag(:block,   50)
        procedure = double('procedure', :oid => '1')
        @profile.add(procedure, [b1, b2, k1])

        result = @profile.summary
        expect(result[:branch][:count]).to eq(2)
        expect(result[:branch][:percent]).to eq(50.0)
        expect(result[:block][:count]).to eq(1)
        expect(result[:block][:percent]).to eq(50.0)
      end
    end

    context "when given a procedure" do
      it "returns only that procedure's tags" do
        b1 = make_tag(:branch, 100)
        b2 = make_tag(:block,   50)
        k1 = make_tag(:branch,   0)

        p1 = double('procedure1', :oid => 'p1')
        p2 = double('procedure2', :oid => 'p2')
        @profile.add(p1, [b1])
        @profile.add(p2, [b2, k1])

        result = @profile.summary(p2)
        expect(result[:branch][:count]).to eq(1)
        expect(result[:block][:count]).to  eq(1)
        expect(result.key?(:branch) && result[:branch][:percent]).to eq(0.0)
      end

      it "returns empty hash for a procedure with no tags in profile" do
        p1 = double('procedure', :oid => 'unknown')
        expect(@profile.summary(p1)).to be_empty
      end
    end
  end

  describe "clear" do
    before do
      @first  = double('first tag',  :id => 'first')
      @second = double('second tag', :id => 'second')
      @third  = double('third tag',  :id => 'third')
      procedure = double('procedure', :oid => nil)

      @profile.add(procedure, [@first, @second, @third])
    end

    it "calls clear on each tag" do
      expect(@first).to receive(:clear)
      expect(@second).to receive(:clear)
      expect(@third).to receive(:clear)
      @profile.clear
    end
  end

  describe "store" do
  end

  describe "empty?" do
    it "returns true when all tags have zero coverage" do
      t1 = double('tag1', :to_f => 0.0)
      t2 = double('tag2', :to_f => 0.0)
      expect(@profile.empty?([t1, t2])).to be true
    end

    it "returns false when at least one tag has coverage" do
      t1 = double('tag1', :to_f => 0.0)
      t2 = double('tag2', :to_f => 50.0)
      expect(@profile.empty?([t1, t2])).to be false
    end

    it "returns true for an empty list" do
      expect(@profile.empty?([])).to be true
    end
  end

  describe "difference" do
    def make_tag(type, pct, id_suffix)
      tag = double("tag-#{id_suffix}", :type => type, :to_f => pct.to_f)
      allow(tag).to receive(:id).and_return("tag#{id_suffix}")
      tag
    end

    it "reports zero delta when coverage did not change" do
      t1 = make_tag(:branch, 100, '1')
      t2 = make_tag(:branch, 100, '2')
      procedure = double('procedure', :oid => 'p1')
      @profile.add(procedure, [t1])

      result = @profile.difference(procedure, [t2])
      expect(result).to eq("+0.0% branch")
    end

    it "reports positive delta when coverage improved" do
      before_tag = make_tag(:branch,   0, 'b')
      after_tag  = make_tag(:branch, 100, 'a')
      procedure  = double('procedure', :oid => 'p1')
      @profile.add(procedure, [after_tag])

      result = @profile.difference(procedure, [before_tag])
      expect(result).to eq("+100.0% branch")
    end

    it "reports negative delta when coverage regressed" do
      before_tag = make_tag(:block, 100, 'b')
      after_tag  = make_tag(:block,   0, 'a')
      procedure  = double('procedure', :oid => 'p1')
      @profile.add(procedure, [after_tag])

      result = @profile.difference(procedure, [before_tag])
      expect(result).to eq("-100.0% block")
    end
  end

end

end
