require "spec_helper"

RSpec.describe MiniMagick::Utilities do
  describe ".which" do
    it "identifies when mogrify exists" do
      expect(MiniMagick::Utilities.which('mogrify')).not_to be_nil
    end

    it "identifies when gm exists" do
      expect(MiniMagick::Utilities.which('gm')).not_to be_nil
    end

    it "returns nil on nonexistent executables" do
      expect(MiniMagick::Utilities.which('yogrify')).to be_nil
    end
  end
end
