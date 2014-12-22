require "spec_helper"

RSpec.describe MiniMagick::Configuration do
  subject { Object.new.extend(MiniMagick::Configuration) }

  describe "#configure" do
    it "yields self" do
      expect { |b| subject.configure(&b) }
        .to yield_with_args(subject)
    end
  end

  describe "#cli" do
    it "can be assigned" do
      subject.cli = :imagemagick
      expect(subject.cli).to eq :imagemagick
    end

    it "returns :imagemagick if #processor is mogrify" do
      allow(subject).to receive(:processor).and_return("mogrify")
      expect(subject.cli).to eq :imagemagick
    end

    it "returns :graphicsmagick if #processor is gm" do
      allow(subject).to receive(:processor).and_return("gm")
      expect(subject.cli).to eq :graphicsmagick
    end

    it "returns nil of #processor is nil" do
      allow(subject).to receive(:processor).and_return(nil)
      expect(subject.cli).to be_nil
    end
  end

  describe "#cli=" do
    it "raises an error when set to an invalid value" do
      expect { subject.cli = :grapicsmagick }
        .to raise_error(ArgumentError)
    end
  end

  describe "#processor" do
    it "assigns :mogrify by default" do
      expect(subject.processor).to eq "mogrify"
    end

    it "assigns :gm if ImageMagick is not available" do
      allow(MiniMagick::Utilities).to receive(:which).with("mogrify").and_return(nil)
      allow(MiniMagick::Utilities).to receive(:which).with("gm").and_return(true)
      expect(subject.processor).to eq "gm"
    end

    it "returns nil if neither ImageMagick nor GraphicsMagick are available" do
      allow(MiniMagick::Utilities).to receive(:which).with("mogrify").and_return(nil)
      allow(MiniMagick::Utilities).to receive(:which).with("gm").and_return(nil)
      expect(subject.processor).to be_nil
    end
  end

  describe "#processor=" do
    it "raises an error when set to an invalid value" do
      expect { subject.processor = "mogrfy" }
        .to raise_error(ArgumentError)
    end
  end
end
