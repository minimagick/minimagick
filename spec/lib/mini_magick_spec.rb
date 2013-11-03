require 'spec_helper'

describe MiniMagick do
  context '.choose_processor' do
    it "identifies when mogrify exists" do
      MiniMagick.class.any_instance.expects(:`).with('which mogrify').returns('/usr/bin/mogrify\n')
      MiniMagick.choose_processor.should == 'mogrify'
    end

    it "identifies when gm exists" do
      MiniMagick.class.any_instance.expects(:`).with('which mogrify').returns('')
      MiniMagick.class.any_instance.expects(:`).with('which gm').returns('/usr/bin/gm\n')
      MiniMagick.choose_processor.should == 'gm'
    end
  end

  context '.mogrify?' do
    it "checks if minimagick is using mogrify" do
      MiniMagick.processor = 'mogrify'
      MiniMagick.mogrify?.should == true
    end

    it "checks if minimagick isn't using mogrify" do
      MiniMagick.processor = 'gm'
      MiniMagick.mogrify?.should == false
    end

    it "sets the processor if it's not set" do
      MiniMagick.processor = nil
      MiniMagick.class.any_instance.expects(:`).with('which mogrify').returns('/usr/bin/mogrify\n')
      MiniMagick.mogrify?

      MiniMagick.processor = 'mogrify'
    end
  end

  context '.gm?' do
    it "checks if minimagick is using gm" do
      MiniMagick.processor = 'gm'
      MiniMagick.gm?.should == true
    end

    it "checks if minimagick isn't using gm" do
      MiniMagick.processor = 'mogrify'
      MiniMagick.gm?.should == false
    end

    it "sets the processor if it's not set" do
      MiniMagick.processor = nil
      MiniMagick.class.any_instance.expects(:`).with('which mogrify').returns('')
      MiniMagick.class.any_instance.expects(:`).with('which gm').returns('/usr/bin/gm\n')
      MiniMagick.gm?

      MiniMagick.processor = 'gm'
    end
  end
end
