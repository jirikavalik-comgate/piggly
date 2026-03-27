require 'spec_helper'

module Piggly

describe Tags::AbstractTag do
end

describe Tags::EvaluationTag do
  before { @tag = Tags::EvaluationTag.new('eval') }

  it "starts with zero coverage" do
    expect(@tag.to_f).to eq(0.0)
    expect(@tag.style).to eq("c0")
    expect(@tag.complete?).to be false
    expect(@tag.description).to eq("never evaluated")
  end

  it "reports full coverage after ping" do
    @tag.ping(nil)
    expect(@tag.to_f).to eq(100.0)
    expect(@tag.style).to eq("c1")
    expect(@tag.complete?).to be true
    expect(@tag.description).to eq("full coverage")
  end

  it "ping is idempotent" do
    @tag.ping(nil)
    @tag.ping(nil)
    expect(@tag.to_f).to eq(100.0)
  end

  it "clears coverage" do
    @tag.ping(nil)
    @tag.clear
    expect(@tag.to_f).to eq(0.0)
    expect(@tag.complete?).to be false
  end

  it "is equal to another tag with the same id and ran state" do
    other = Tags::EvaluationTag.new
    other.instance_variable_set(:@id, @tag.id)
    expect(@tag).to eq(other)
  end

  it "is not equal when ran state differs" do
    other = Tags::EvaluationTag.new
    other.instance_variable_set(:@id, @tag.id)
    @tag.ping(nil)
    expect(@tag).not_to eq(other)
  end

  it "type is :block" do
    expect(@tag.type).to eq(:block)
  end
end

describe Tags::BlockTag do
  it "type is :block" do
    expect(Tags::BlockTag.new('blk').type).to eq(:block)
  end

  it "behaves like EvaluationTag" do
    tag = Tags::BlockTag.new('blk')
    expect(tag.to_f).to eq(0.0)
    tag.ping(nil)
    expect(tag.to_f).to eq(100.0)
  end
end

describe Tags::UnconditionalBranchTag do
  it "type is :branch" do
    expect(Tags::UnconditionalBranchTag.new('br').type).to eq(:branch)
  end

  it "otherwise behaves like EvaluationTag" do
    tag = Tags::UnconditionalBranchTag.new('br')
    expect(tag.to_f).to eq(0.0)
    tag.ping(nil)
    expect(tag.to_f).to eq(100.0)
  end
end

describe Tags::ConditionalBranchTag do
  before { @tag = Tags::ConditionalBranchTag.new('cond') }

  it "starts with zero coverage" do
    expect(@tag.to_f).to eq(0.0)
    expect(@tag.style).to eq("b00")
    expect(@tag.complete?).to be false
    expect(@tag.description).to eq("never evaluated")
  end

  it "records true path" do
    @tag.ping("t")
    expect(@tag.true).to be true
    expect(@tag.false).to be false
    expect(@tag.style).to eq("b10")
    expect(@tag.to_f).to eq(50.0)
    expect(@tag.complete?).to be false
    expect(@tag.description).to eq("never evaluates false")
  end

  it "records false path" do
    @tag.ping("f")
    expect(@tag.true).to be false
    expect(@tag.false).to be true
    expect(@tag.style).to eq("b01")
    expect(@tag.to_f).to eq(50.0)
    expect(@tag.complete?).to be false
    expect(@tag.description).to eq("never evaluates true")
  end

  it "records both paths" do
    @tag.ping("t")
    @tag.ping("f")
    expect(@tag.style).to eq("b11")
    expect(@tag.to_f).to eq(100.0)
    expect(@tag.complete?).to be true
    expect(@tag.description).to eq("full coverage")
  end

  it "ignores unknown ping values" do
    @tag.ping("@")
    @tag.ping("x")
    expect(@tag.true).to be false
    expect(@tag.false).to be false
    expect(@tag.to_f).to eq(0.0)
  end

  it "clears both flags to false (not nil)" do
    @tag.ping("t")
    @tag.ping("f")
    @tag.clear
    expect(@tag.true).to be false
    expect(@tag.false).to be false
    expect(@tag.to_f).to eq(0.0)
  end

  it "type is :branch" do
    expect(@tag.type).to eq(:branch)
  end

  it "== compares id, true, and false flags" do
    other = Tags::ConditionalBranchTag.new
    other.instance_variable_set(:@id, @tag.id)
    expect(@tag).to eq(other)
    @tag.ping("t")
    expect(@tag).not_to eq(other)
  end
end

describe Tags::ConditionalLoopTag do
  before { @tag = Tags::ConditionalLoopTag.new('while-loop') }

  it "starts with state 0b0000 (never evaluated)" do
    expect(@tag.state).to eq(0b0000)
    expect(@tag.description).to eq("never evaluated")
    expect(@tag.to_f).to eq(0.0)
    expect(@tag.complete?).to be false
  end

  it "detects pass-through (0b1100) — zero iterations, terminated normally" do
    @tag.ping("f")
    expect(@tag.state).to eq(0b1100)
    expect(@tag.pass).to be true
    expect(@tag.ends).to be true
    expect(@tag.once).to be false
    expect(@tag.twice).to be false
  end

  it "detects iterate-once (0b1010)" do
    @tag.ping("t")
    @tag.ping("f")
    expect(@tag.state).to eq(0b1010)
    expect(@tag.once).to be true
    expect(@tag.ends).to be true
    expect(@tag.pass).to be false
    expect(@tag.twice).to be false
  end

  it "detects iterate-more-than-once (0b1001)" do
    @tag.ping("t")
    @tag.ping("t")
    @tag.ping("f")
    expect(@tag.state).to eq(0b1001)
    expect(@tag.twice).to be true
    expect(@tag.ends).to be true
    expect(@tag.pass).to be false
    expect(@tag.once).to be false
  end

  it "accumulates pass + once (0b1110)" do
    @tag.ping("f")
    @tag.ping("t")
    @tag.ping("f")
    expect(@tag.state).to eq(0b1110)
  end

  it "accumulates pass + twice (0b1101)" do
    @tag.ping("f")
    @tag.ping("t")
    @tag.ping("t")
    @tag.ping("f")
    expect(@tag.state).to eq(0b1101)
  end

  it "accumulates once + twice (0b1011)" do
    @tag.ping("t")
    @tag.ping("f")
    @tag.ping("t")
    @tag.ping("t")
    @tag.ping("f")
    expect(@tag.state).to eq(0b1011)
  end

  it "detects full coverage (0b1111)" do
    @tag.ping("f")       # pass
    @tag.ping("t")
    @tag.ping("f")       # once
    @tag.ping("t")
    @tag.ping("t")
    @tag.ping("f")       # twice
    expect(@tag.state).to eq(0b1111)
    expect(@tag.complete?).to be true
    expect(@tag.to_f).to eq(100.0)
    expect(@tag.description).to eq("full coverage")
  end

  it "to_f scales with number of dimensions covered" do
    expect(@tag.to_f).to eq(0.0)
    @tag.ping("f")                # pass + ends => 2/4 = 50%
    expect(@tag.to_f).to eq(50.0)
  end

  it "clears state back to zero" do
    @tag.ping("f")
    @tag.ping("t")
    @tag.ping("f")
    @tag.clear
    expect(@tag.state).to eq(0b0000)
    expect(@tag.to_f).to eq(0.0)
  end

  it "type is :loop" do
    expect(@tag.type).to eq(:loop)
  end
end

describe Tags::UnconditionalLoopTag do
  before do
    @tag = Tags::UnconditionalLoopTag.new('for-loop')
  end

  it "starts with state 00 (0b0000)" do
    # - terminates normally
    # - pass through
    # - iterate only once
    # - iterate more than once
    expect(@tag.state).to eq(0b0000)
  end

  it "detects state 01 (0b0001)" do
    # - terminates normally
    # - pass through
    # - iterate only once
    # + iterate more than once

    # two iterations
    @tag.ping('t')
    @tag.ping('t')
    @tag.ping('f')

    expect(@tag.state).to eq(0b0001)
  end

  it "detects state 02 (0b0010)" do
    # - terminates normally
    # - pass through
    # + iterate only once
    # - iterate more than once

    # one iteration
    @tag.ping('t')
    @tag.ping('f')

    expect(@tag.state).to eq(0b0010)
  end

  it "detects state 03 (0b0011)" do
    # - terminates normally
    # - pass through
    # + iterate only once
    # + iterate more than once

    # one iteration
    @tag.ping('t')
    @tag.ping('f')

    # two iterations
    @tag.ping('t')
    @tag.ping('t')
    @tag.ping('f')

    expect(@tag.state).to eq(0b0011)
  end

  it "detects state 04 (0b0100)" do
    # - terminates normally
    # + pass through
    # - iterate only once
    # - iterate more than once

    # zero iterations
    @tag.ping('f')

    expect(@tag.state).to eq(0b0100)
  end

  it "detects state 05 (0b0101)" do
    # - terminates normally
    # + pass through
    # - iterate only once
    # + iterate more than once

    # zero iterations
    @tag.ping('f')

    # two iterations
    @tag.ping('t')
    @tag.ping('t')
    @tag.ping('f')

    expect(@tag.state).to eq(0b0101)
  end

  it "detects state 06 (0b0110)" do
    # - terminates normally
    # + pass through
    # + iterate only once
    # - iterate more than once

    # zero iterations
    @tag.ping('f')

    # one iteration
    @tag.ping('t')
    @tag.ping('f')

    expect(@tag.state).to eq(0b0110)
  end

  it "detects state 07 (0b0111)" do
    # - terminates normally
    # + pass through
    # + iterate only once
    # + iterate more than once
    
    # zero iterations
    @tag.ping('f')

    # one iteration
    @tag.ping('t')
    @tag.ping('f')

    # two iterations
    @tag.ping('t')
    @tag.ping('t')
    @tag.ping('f')

    expect(@tag.state).to eq(0b0111)
  end

  it "detects state 08 (0b1000)" do
    # + terminates normally
    # - pass through
    # - iterate only once
    # - iterate more than once

    # TODO invalid
    @tag.ping('@')

    expect(@tag.state).to eq(0b1000)
  end

  it "detects state 09 (0b1001)" do
    # + terminates normally
    # - pass through
    # - iterate only once
    # + iterate more than once

    # iterate twice
    @tag.ping('t')
    @tag.ping('@')
    @tag.ping('t')
    @tag.ping('@')
    @tag.ping('f')

    expect(@tag.state).to eq(0b1001)
  end

  it "detects state 10 (0b1010)" do
    # + terminates normally
    # - pass through
    # + iterate only once
    # - iterate more than once

    # iterate once
    @tag.ping('t')
    @tag.ping('@')
    @tag.ping('f')

    expect(@tag.state).to eq(0b1010)
  end

  it "detects state 11 (0b1011)" do
    # + terminates normally
    # - pass through
    # + iterate only once
    # + iterate more than once

    # iterate once
    @tag.ping('t')
    @tag.ping('@')
    @tag.ping('f')

    # iterate twice
    @tag.ping('t')
    @tag.ping('@')
    @tag.ping('t')
    @tag.ping('@')
    @tag.ping('f')

    expect(@tag.state).to eq(0b1011)
  end

  it "detects state 12 (0b1100)" do
    # + terminates normally
    # + pass through
    # - iterate only once
    # - iterate more than once

    # TODO invalid
    @tag.ping('@')
    @tag.ping('f')

    expect(@tag.state).to eq(0b1100)
  end

  it "detects state 13 (0b1101)" do
    # + terminates normally
    # + pass through
    # - iterate only once
    # + iterate more than once

    # iterate twice
    @tag.ping('t')
    @tag.ping('@')
    @tag.ping('t')
    @tag.ping('@')
    @tag.ping('f')

    # pass through
    @tag.ping('f')

    expect(@tag.state).to eq(0b1101)
  end

  it "detects state 14 (0b1110)" do
    # + terminates normally
    # + pass through
    # + iterate only once
    # - iterate more than once
    
    # pass through
    @tag.ping('f')

    # iterate once
    @tag.ping('t')
    @tag.ping('@')
    @tag.ping('f')

    expect(@tag.state).to eq(0b1110)
  end

  it "detects state 15 (0b1111)" do
    # + terminates normally
    # + pass through
    # + iterate only once
    # + iterate more than once

    # pass through
    @tag.ping('f')

    # iterate once
    @tag.ping('t')
    @tag.ping('@')
    @tag.ping('f')

    # iterate twice
    @tag.ping('t')
    @tag.ping('@')
    @tag.ping('t')
    @tag.ping('@')
    @tag.ping('f')

    expect(@tag.state).to eq(0b1111)
  end

end

describe Tags::ConditionalBranchTag do
end

end
