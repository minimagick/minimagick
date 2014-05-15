require 'spec_helper'

describe MiniMagick do
  context 'which util' do
    it "identifies when mogrify exists" do
      expect(MiniMagick::Utilities.which("mogrify")).not_to be_nil
    end

    it "identifies when gm exists" do
      expect(MiniMagick::Utilities.which("gm")).not_to be_nil
    end

    it "returns nil on nonexistent executables" do
      expect(MiniMagick::Utilities.which("yogrify")).to eq(nil)
    end
  end

  context '.mogrify?' do
    it "checks if minimagick is using mogrify" do
      MiniMagick.processor = "mogrify"
      expect(MiniMagick.mogrify?).to eq(true)
    end

    it "checks if minimagick isn't using mogrify" do
      MiniMagick.processor = "gm"
      expect(MiniMagick.mogrify?).to eq(false)
    end

    it "sets the processor to mogrify (default) if it's not set" do
      MiniMagick.processor = nil
      MiniMagick.mogrify?
      expect(MiniMagick.processor).to eq("mogrify")
    end
  end

  context '.gm?' do
    it "checks if minimagick is using gm" do
      MiniMagick.processor = "gm"
      expect(MiniMagick.gm?).to eq(true)
    end

    it "checks if minimagick isn't using gm" do
      MiniMagick.processor = "mogrify"
      expect(MiniMagick.gm?).to eq(false)
    end

    it "sets the processor if it's not set" do
      MiniMagick.processor = nil
      MiniMagick.gm?
      MiniMagick.processor = "gm"
    end
  end

  describe '#validate_on_create' do
    subject { super().validate_on_create }
    it { should be_true }
  end

  describe '#validate_on_write' do
    subject { super().validate_on_write }
    it { should be_true }
  end
end
