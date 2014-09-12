require "spec_helper"

RSpec.describe MiniMagick::CommandBuilder do
  subject { described_class.new('test') }

  after do
    MiniMagick.processor_path = nil
    MiniMagick.processor = nil
  end

  context "on windows", if: MiniMagick::Utilities.windows? do
    it "builds a complicated command" do
      subject.resize '30x40'
      subject.alpha '1 3 4'
      subject.distort.+ 'srt', '0.6 20'
      expect(subject.command).to eq 'test -resize 30x40 -alpha 1 3 4 +distort srt 0.6 20'
    end

    it "properly escapes special characters" do
      image = MiniMagick::Image.open(image_path)
      expect {
        image.combine_options do |c|
          c.sample '50%'
          c.rotate '-90>'
        end
      }.not_to raise_error
    end
  end

  context "on unix", unless: MiniMagick::Utilities.windows? do
    it "builds a complicated command" do
      subject.resize '30x40'
      subject.alpha '1 3 4'
      subject.distort.+ 'srt', '0.6 20'
      expect(subject.command).to eq 'test -resize 30x40 -alpha 1\ 3\ 4 \+distort srt 0.6\ 20'
    end

    it "properly escapes special characters" do
      image = MiniMagick::Image.open(image_path)
      expect {
        image.combine_options do |c|
          c.sample '50%'
          c.rotate '-90>'
        end
      }.not_to raise_error
    end
  end

  it "builds the commands with creation operators" do
    subject = described_class.new('mogrify')
    subject.caption 'caption_text'
    expect(subject.command).to eq 'mogrify -caption caption_text'

    subject = described_class.new('test')
    subject.caption 'caption_text'
    expect(subject.command).to eq 'test caption:caption_text'
  end

  it "raises error on option not found" do
    expect { subject.input }.to raise_error(NoMethodError)
  end

  it "builds a dashed command" do
    subject.auto_orient
    expect(subject.command).to eq 'test -auto-orient'
  end

  it "builds a dashed command via send" do
    subject.send('auto-orient')
    expect(subject.command).to eq 'test -auto-orient'
  end

  it "sets a processor path correctly" do
    MiniMagick.processor_path = '/a/strange/path'
    subject.auto_orient
    expect(subject.command).to eq '/a/strange/path/test -auto-orient'
  end

  it "builds a processor path with processor" do
    MiniMagick.processor_path = '/a/strange/path'
    MiniMagick.processor = 'processor'
    subject.auto_orient
    expect(subject.command).to eq '/a/strange/path/processor test -auto-orient'
  end

  # from https://github.com/minimagick/minimagick/issues/163
  it "annotates image with whitespace" do
    image = MiniMagick::Image.open(image_path)
    expect { image.annotate '0', 'a b' }
      .not_to raise_error
  end
end
