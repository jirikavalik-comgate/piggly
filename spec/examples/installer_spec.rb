require 'spec_helper'

module Piggly

describe Installer do

  before do
    @config     = Config.new
    @connection = double('connection')
    @installer  = Installer.new(@config, @connection)
  end

  describe "trace" do
    it "compiles, executes, and profiles the procedure" do
      untraced  = 'create or replace function x(char)'
      traced    = 'create or replace function f(int)'

      result   = {:tags => double('tags'), :code => traced}
      profile  = double('profile')

      compiler = double('compiler', :compile => result)
      expect(Compiler::TraceCompiler).to receive(:new).
        and_return(compiler)

      procedure = double('procedure', :oid => 'oid', :source => untraced)
      expect(procedure).to receive(:definition).
        with(traced).and_return(traced)

      expect(@connection).to receive(:exec).
        with(traced)

      expect(profile).to receive(:add).
        with(procedure, result[:tags], result)

      @installer.trace(procedure, profile)
    end
  end

  describe "untrace" do
    it "executes the original definition" do
      untraced  = 'create or replace function x(char)'
      procedure = double('procedure', :oid => 'oid', :source => untraced)

      expect(procedure).to receive(:definition).
        and_return(untraced)

      expect(@connection).to receive(:exec).
        with(untraced)

      @installer.untrace(procedure)
    end
  end

  describe "install_trace_support"
  describe "uninstall_trace_support"

end

end
