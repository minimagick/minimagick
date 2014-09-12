require "spec_helper"

RSpec.describe MiniMagick do
  describe ".mogrify?" do
    it "returns true if minimagick is using mogrify" do
      described_class.processor = :mogrify
      expect(described_class.mogrify?).to eq true
    end

    it "returns false if minimagick is not using mogrify" do
      described_class.processor = :gm
      expect(described_class.mogrify?).to eq false
    end

    it "sets the processor if not set" do
      described_class.processor = nil
      described_class.mogrify?
      expect(described_class.processor).to eq :mogrify
    end
  end

  describe ".gm?" do
    it "returns true if minimagick is using gm" do
      described_class.processor = :gm
      expect(described_class).to be_gm
    end

    it "returns false if minimagick is not using gm" do
      described_class.processor = :mogrify
      expect(described_class).not_to be_gm
    end

    it "sets the processor if not set" do
      described_class.processor = nil
      described_class.gm?
      expect(described_class.processor).to eq :mogrify
    end
  end

  it "validates on create and write by default" do
    expect(MiniMagick.validate_on_create).to eq(true)
    expect(MiniMagick.validate_on_write).to eq(true)
  end
end
