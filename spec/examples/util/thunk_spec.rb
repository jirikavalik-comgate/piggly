require 'spec_helper'

module Piggly

  describe Util::Thunk do

    context "not already evaluated" do
      before do
        @work  = double('computation')
        @thunk = Util::Thunk.new { @work.evaluate }
      end

      it "responds to thunk? without evaluating" do
        expect(@work).not_to receive(:evaluate)
        expect(@thunk.thunk?).to be true
      end

      it "evaluates when force! is explicitly called" do
        expect(@work).to receive(:evaluate).and_return(@work)
        expect(@thunk.force!).to eq(@work)
      end

      it "evaluates when some other method is called" do
        expect(@work).to receive(:evaluate).and_return(@work)
        expect(@work).to receive(:something).and_return(@work)
        expect(@thunk.something).to eq(@work)
      end
    end

    context "previously evaluated" do
      before do
        @work = double('computation')
        allow(@work).to receive(:evaluate).and_return(@work)

        @thunk = Util::Thunk.new { @work.evaluate }
        @thunk.force!
      end

      it "responds to thunk? without evaluating" do
        expect(@work).not_to receive(:evaluate)
        expect(@thunk.thunk?).to be true
      end

      it "should not re-evaluate when force! is called" do
        expect(@work).not_to receive(:evaluate)
        @thunk.force!
      end

      it "should not re-evaluate when some other method is called" do
        expect(@work).not_to receive(:evaluate)
        expect(@work).to receive(:something).and_return(@work)
        expect(@thunk.something).to eq(@work)
      end
    end

  end

end
