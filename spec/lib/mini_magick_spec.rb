require "spec_helper"

RSpec.describe MiniMagick do
  describe ".cli_version" do
    it "returns ImageMagick's version" do
      expect(described_class.cli_version).to match(/^\d+\.\d+\.\d+-\d+$/)
    end
  end
end
