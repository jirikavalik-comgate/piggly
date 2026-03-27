require 'spec_helper'

module Piggly

describe Config do
  before do
    @config = Config.new
  end

  it "has class accessors and mutators" do
    expect(@config).to respond_to(:cache_root)
    expect(@config).to respond_to(:cache_root=)
    expect(@config).to respond_to(:report_root)
    expect(@config).to respond_to(:report_root=)
    expect(@config).to respond_to(:trace_prefix)
    expect(@config).to respond_to(:trace_prefix=)
  end

  it "has default values" do
  # @config.cache_root = nil
    expect(@config.cache_root).not_to be_nil
    expect(@config.cache_root).to match(/cache$/)

  # @config.report_root = nil
    expect(@config.report_root).not_to be_nil
    expect(@config.report_root).to match(/reports$/)

  # @config.trace_prefix = nil
    expect(@config.trace_prefix).not_to be_nil
    expect(@config.trace_prefix).to eq('PIGGLY')
  end
  
  describe "path" do
    it "doesn't reparent absolute paths" do
      expect(@config.path('/tmp', '/usr/bin/ps')).to eq('/usr/bin/ps')
      expect(@config.path('A:/data/tmp', 'C:/USER/tmp')).to eq('C:/USER/tmp')
      expect(@config.path('/tmp/data', '../data.txt')).to eq('../data.txt')
    end
    
    it "reparents relative paths" do
      expect(@config.path('/tmp', 'note.txt')).to eq('/tmp/note.txt')
    end
    
    it "doesn't require path parameter" do
      expect(@config.path('/tmp')).to eq('/tmp')
    end
  end
  
  describe "mkpath" do
    it "creates root if doesn't exist" do
      expect(FileUtils).to receive(:makedirs).with('x/y').once.and_return(true)
      @config.mkpath('x/y', 'z')
    end

    it "throws an error on path components that exist as files" do
      expect{ @config.mkpath('/etc/passwd/file') }.to raise_error(Errno::EEXIST)
    end
  end
end

end
