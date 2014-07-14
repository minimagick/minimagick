require 'spec_helper'

# All tests tagged as `ported` are ported from
# testunit tests and are there for backwards compatibility

MiniMagick.processor = 'mogrify'

describe MiniMagick::CommandBuilder do
  before do
    @processor = MiniMagick.processor
    @processor_path = MiniMagick.processor_path
  end

  after do
    MiniMagick.processor_path = @processor_path
    MiniMagick.processor = @processor
  end

  describe 'ported from testunit', :ported => true do
    let(:builder) { described_class.new('test') }

    it 'builds a basic command' do
      builder.resize '30x40'
      expect(builder.args.join(' ')).to eq '-resize 30x40'
    end

    it 'builds a full command' do
      builder.resize '30x40'
      expect(builder.command).to eq 'test -resize 30x40'
    end

    describe 'windows only', :if => MiniMagick::Utilities.windows? do
      it 'builds a complicated command' do
        builder.resize '30x40'
        builder.alpha '1 3 4'
        builder.resize 'mome fingo'
        expect(builder.args.join(' ')).to eq '-resize 30x40 -alpha 1 3 4 -resize mome fingo'
      end

      it 'builds a command with multiple options and plus modifier' do
        builder.distort.+ 'srt', '0.6 20'
        expect(builder.args.join(' ')).to eq '+distort srt 0.6 20'
      end

      it 'sets a colorspace correctly' do
        builder.set 'colorspace RGB'
        expect(builder.command).to eq 'test -set colorspace RGB'
      end
    end

    describe 'not windows', :if => !MiniMagick::Utilities.windows? do
      it 'builds a complicated command' do
        builder.resize '30x40'
        builder.alpha '1 3 4'
        builder.resize 'mome fingo'
        expect(builder.args.join(' ')).to eq '-resize 30x40 -alpha 1\ 3\ 4 -resize mome\ fingo'
      end

      it 'sets a colorspace correctly' do
        builder.set 'colorspace RGB'
        expect(builder.command).to eq 'test -set colorspace\ RGB'
      end

      it 'builds a command with multiple options and plus modifier' do
        builder.distort.+ 'srt', '0.6 20'
        expect(builder.args.join(' ')).to eq '\+distort srt 0.6\ 20'
      end
    end

    describe 'common verbs between morgify and image creation operators' do
      context 'mogrify' do
        let(:builder) { described_class.new('mogrify') }

        it 'builds the command' do
          builder.caption 'caption_text'
          expect(builder.command).to eq 'mogrify -caption caption_text'
        end
      end

      context 'other' do
        it 'builds the command' do
          builder.caption 'caption_text'
          expect(builder.command).to eq 'test caption:caption_text'
        end
      end
    end

    it 'raises error when command is invalid' do
      expect {
        command = described_class.new('test', 'path')
        command.input 2
      }.to raise_error
    end

    it 'builds a dashed command' do
      builder.auto_orient
      expect(builder.args.join(' ')).to eq '-auto-orient'
    end

    it 'builds a dashed command via send' do
      builder.send('auto-orient')
      expect(builder.args.join(' ')).to eq '-auto-orient'
    end

    it 'builds a canvas command' do
      builder.canvas 'black'
      expect(builder.args.join(' ')).to eq 'canvas:black'
    end

    it 'sets a processor path correctly' do
      MiniMagick.processor_path = '/a/strange/path'
      builder.auto_orient
      expect(builder.command).to eq '/a/strange/path/test -auto-orient'
    end

    it 'builds a processor path with processor' do
      MiniMagick.processor_path = '/a/strange/path'
      MiniMagick.processor = 'processor'
      builder.auto_orient
      expect(builder.command).to eq '/a/strange/path/processor test -auto-orient'
    end
  end

  describe 'deprecated' do
    let(:builder) { described_class.new('test') }
    before { MiniMagick.processor = nil }

    it 'builds a full command' do
      builder.resize '30x40'
      expect(builder.command).to eq 'test -resize 30x40'
    end

    context 'windows only', :if => MiniMagick::Utilities.windows? do
      it 'sets a colorspace correctly' do
        builder.set 'colorspace RGB'
        expect(builder.command).to eq 'test -set colorspace RGB'
      end
    end

    context 'not windows', :if => !MiniMagick::Utilities.windows? do
      it 'sets a colorspace correctly' do
        builder.set 'colorspace RGB'
        expect(builder.command).to eq 'test -set colorspace\ RGB'
      end
    end

    it 'sets a processor path correctly' do
      MiniMagick.processor_path = '/a/strange/path'
      builder.auto_orient
      expect(builder.command).to eq '/a/strange/path/test -auto-orient'
    end
  end
end
