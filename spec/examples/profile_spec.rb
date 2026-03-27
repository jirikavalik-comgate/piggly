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
    context "when given a procedure" do
    end

    context "when not given a procedure" do
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
  end

  describe "difference" do
  end

end

end
