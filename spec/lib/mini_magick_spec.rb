require "spec_helper"

RSpec.describe MiniMagick do
  describe ".imagemagick?" do
    it "returns true if CLI is minimagick" do
      allow(described_class).to receive(:cli).and_return(:imagemagick)
      expect(described_class.imagemagick?).to eq true
    end

    it "returns false if CLI isn't minimagick" do
      allow(described_class).to receive(:cli).and_return(:graphicsmagick)
      expect(described_class.imagemagick?).to eq false
    end
  end

  describe ".graphicsmagick?" do
    it "returns true if CLI is graphicsmagick" do
      allow(described_class).to receive(:cli).and_return(:graphicsmagick)
      expect(described_class.graphicsmagick?).to eq true
    end

    it "returns false if CLI isn't graphicsmagick" do
      allow(described_class).to receive(:cli).and_return(:imagemagick)
      expect(described_class.graphicsmagick?).to eq false
    end
  end

  describe ".cli_version" do
    it "returns ImageMagick's version" do
      allow(described_class).to receive(:cli).and_return(:imagemagick)
      expect(described_class.cli_version).to match(/^\d+\.\d+\.\d+-\d+$/)
    end

    it "returns GraphicsMagick's version" do
      allow(described_class).to receive(:cli).and_return(:graphicsmagick)
      expect(described_class.cli_version).to match(/^\d+\.\d+\.\d+$/)
    end
  end
end
