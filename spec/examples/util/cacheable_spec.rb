require 'spec_helper'

module Piggly

=begin
  describe Util::Cacheable do

    class ExampleClass;           include Piggly::Util::Cacheable; end
    class ExampleCacheClass;      include Piggly::Util::Cacheable; end
    class PigglyExampleClassHTML; include Piggly::Util::Cacheable; end
    class PigglyExampleHTMLClass; include Piggly::Util::Cacheable; end
    class HTMLPiggly;             include Piggly::Util::Cacheable; end
    class ExampleRedefined
      include Piggly::Util::Cacheable
      def self.cache_path(file)
        'redefined'
      end
    end

    before do
      allow(Config).to receive(:cache_root).and_return('/')
    end

    it "installs class methods" do
      expect(ExampleClass).to respond_to(:cache_path)
    end
    
    it "uses class name as cache subdirectory" do
      expect(FileUtils).to receive(:makedirs).at_least(:once)

      expect(ExampleClass.cache_path('a.ext')).to match(%r(/Example/a.ext$))
      expect(ExampleCacheClass.cache_path('a.ext')).to match(%r(/ExampleCache/a.ext$))
      expect(PigglyExampleClassHTML.cache_path('a.ext')).to match(%r(/PigglyExampleClassHTML/a.ext$))
      expect(PigglyExampleHTMLClass.cache_path('a.ext')).to match(%r(/PigglyExampleHTML/a.ext$))
      expect(HTMLPiggly.cache_path('a.ext')).to match(%r(/HTML/a.ext$))
      expect(ExampleRedefined.cache_path('a.ext')).to eq('redefined')
    end
  end
=end

end
