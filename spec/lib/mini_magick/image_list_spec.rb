require "spec_helper"

RSpec.describe MiniMagick::ImageList do
  subject { described_class.new(image_path) }

  describe "#initialize" do
    it "accepts a list of images" do
      images = described_class.new(image_path(:jpg), image_path(:gif))
      expect(images.count).to eq 2
    end
  end

  describe "#each" do
    it "yields a list of images" do
      expect { |b| subject.each(&b) }
        .to yield_with_args(an_instance_of(MiniMagick::Image))
    end
  end

  it "is able to modify its image list" do
    expect { subject << image_path }.to change { subject.count }.by 1
    expect(subject.last).to be_a(MiniMagick::Image)
  end

  it "returns self on some array methods that usually return an Array" do
    expect(subject + subject).to be_a(MiniMagick::ImageList)
  end

  describe "#montage" do
    it "yields the `montage` tool" do
      expect { |b| subject.montage(&b) }
        .to yield_with_args(instance_of(MiniMagick::Tool::Montage))
    end

    it "returns an image" do
      expect(subject.montage).to be_a(MiniMagick::Image)
    end

    it "accepts an output extension" do
      expect(subject.montage("png").path).to end_with(".png")
    end

    it "defaults the extension to JPEG" do
      expect(subject.montage.path).to end_with(".jpg")
    end
  end
end
