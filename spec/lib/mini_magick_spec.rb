require 'spec_helper'

describe MiniMagick do
  context 'which util' do
    it 'identifies when mogrify exists' do
      expect(MiniMagick::Utilities.which('mogrify')).not_to be_nil
    end

    it 'identifies when gm exists' do
      expect(MiniMagick::Utilities.which('gm')).not_to be_nil
    end

    it 'returns nil on nonexistent executables' do
      expect(MiniMagick::Utilities.which('yogrify')).to be_nil
    end
  end

  context '.mogrify?' do
    it 'returns true if minimagick is using mogrify' do
      described_class.processor = :mogrify
      expect(described_class.mogrify?).to eq true
    end

    it 'returns false if minimagick is not using mogrify' do
      described_class.processor = :gm
      expect(described_class.mogrify?).to eq false
    end

    it 'sets the processor if not set' do
      described_class.processor = nil
      described_class.mogrify?
      expect(described_class.processor).to eq :mogrify
    end
  end

  context '.gm?' do
    it 'returns true if minimagick is using gm' do
      described_class.processor = :gm
      expect(described_class).to be_gm
    end

    it 'returns false if minimagick is not using gm' do
      described_class.processor = :mogrify
      expect(described_class).not_to be_gm
    end

    it 'sets the processor if not set' do
      described_class.processor = nil
      described_class.gm?
      expect(described_class.processor).to eq :mogrify
    end
  end

  context 'validation' do
    it 'validates on create' do
      expect(MiniMagick.validate_on_create).to eq(true)
    end

    it 'validates on write' do
      expect(MiniMagick.validate_on_write).to eq(true)
    end
  end
end
