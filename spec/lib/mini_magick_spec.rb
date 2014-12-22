require "spec_helper"

RSpec.describe MiniMagick do
  describe ".imagemagick?" do
    it "returns true if CLI is minimagick" do
      allow(described_class).to receive(:cli).and_return(:imagemagick)
      expect(described_class).to be_imagemagick
    end

    it "returns false if CLI isn't minimagick" do
      allow(described_class).to receive(:cli).and_return(:graphicsmagick)
      expect(described_class).not_to be_imagemagick
    end
  end

  describe ".graphicsmagick?" do
    it "returns true if CLI is graphicsmagick" do
      allow(described_class).to receive(:cli).and_return(:graphicsmagick)
      expect(described_class).to be_graphicsmagick
    end

    it "returns false if CLI isn't graphicsmagick" do
      allow(described_class).to receive(:cli).and_return(:imagemagick)
      expect(described_class).not_to be_graphicsmagick
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
