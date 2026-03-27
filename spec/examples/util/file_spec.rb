require 'spec_helper'

module Piggly::Util

  describe File, "cache invalidation" do
    before do
      mtime = Hash['a' => 1,  'b' => 2,  'c' => 3]
      allow(::File).to receive(:mtime) {|f| mtime.fetch(f) }
      allow(::File).to receive(:exist?) {|f| mtime.include?(f) }
    end

    it "invalidates non-existant cache file" do
      expect(File.stale?('d', 'a')).to eq(true)
      expect(File.stale?('d', 'a', 'b')).to eq(true)
    end

    it "performs validation using file mtimes" do
      expect(File.stale?('c', 'b')).not_to be true
      expect(File.stale?('c', 'a')).not_to be true
      expect(File.stale?('c', 'b', 'a')).not_to be true
      expect(File.stale?('c', 'a', 'b')).not_to be true

      expect(File.stale?('b', 'a')).not_to be true
      expect(File.stale?('b', 'c')).to be true
      expect(File.stale?('b', 'a', 'c')).to be true
      expect(File.stale?('b', 'c', 'a')).to be true

      expect(File.stale?('a', 'b')).to be true
      expect(File.stale?('a', 'c')).to be true
      expect(File.stale?('a', 'b', 'c')).to be true
      expect(File.stale?('a', 'c', 'b')).to be true
    end

    it "assumes sources exist" do
      expect{ File.stale?('a', 'd') }.to raise_error(StandardError)
      expect{ File.stale?('c', 'a', 'x') }.to raise_error(StandardError)
    end
  end  

end
