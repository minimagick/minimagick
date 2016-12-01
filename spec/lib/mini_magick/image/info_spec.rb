require "spec_helper"

["ImageMagick", "GraphicsMagick"].each do |cli|
  RSpec.context "With #{cli}", cli: cli.downcase.to_sym do
    describe MiniMagick::Image::Info do
      describe "#exif" do
        subject { described_class.new(image_path(:exif)) }

        context "with tag containing a newline" do
          let(:exif_output) do
            <<-EOS
exif:ImageUniqueID=A16LSIA00VM A16LSIL02SM

exif:ImageWidth=1200
            EOS
          end

          it "handles newlines" do
            allow(subject).to receive(:identify).and_return(exif_output)
            expect(subject.exif["ImageUniqueID"]).to eq("A16LSIA00VM A16LSIL02SM")
          end
        end
      end
    end
  end
end
