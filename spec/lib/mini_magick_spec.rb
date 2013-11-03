require 'spec_helper'

describe MiniMagick do
  context '.choose_processor' do
    it "identifies when mogrify exists" do
      MiniMagick.class.any_instance.expects(:`).with('which mogrify').returns('/usr/bin/mogrify\n')
      MiniMagick.choose_processor.should == nil
    end

    it "identifies when gm exists" do
      MiniMagick.class.any_instance.expects(:`).with('which mogrify').returns('')
      MiniMagick.class.any_instance.expects(:`).with('which gm').returns('/usr/bin/gm\n')
      MiniMagick.choose_processor.should == 'gm'
    end
  end
end
