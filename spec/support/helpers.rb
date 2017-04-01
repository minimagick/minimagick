require "tempfile"

module Helpers
  def image_path(type = :default)
    if type != :jpg_without_extension
      File.join("spec/fixtures",
        case type
        when :default, :jpg       then "default.jpg"
        when :png                 then "engine.png"  
        when :animation, :gif     then "animation.gif"
        when :exif                then "exif.jpg"
        when :empty_identify_line then "empty_identify_line.png"
        when :badly_encoded_line  then "badly_encoded_line.jpg"
        when :not                 then "not_an_image.rb"
        when :colon               then "with:colon.jpg"
        when :clipping_path       then "clipping_path.jpg"
        when :rgb                 then "rgb.png"
        when :rgb_tmp             then "rgb_tmp.png"
        else
          fail "image #{type.inspect} doesn't exist"
        end
      )
    else
      path = random_path
      FileUtils.cp image_path, path
      path
    end
  end

  def image_url
    "https://avatars2.githubusercontent.com/u/795488?v=2&s=40"
  end

  def random_path(basename = "")
    @tempfile = Tempfile.open(basename)
    @tempfile.path
  end

  def valid_bearer_token
    'valid_test_bearer_token'
  end

  def invalid_bearer_token
    'invalid_test_bearer_token'
  end

  def download_url_with_token
    "https://www.example.com/stubbed/valid/image/url"
  end

  def stub_tokenized_requests

    stub_request(:get, download_url_with_token).
      with(:headers => {'Authorization' => "Bearer " + valid_bearer_token }).
      to_return(:body => File.new(File.expand_path("../../fixtures/default.jpg", __FILE__)), :status => 200)

    stub_request(:get, download_url_with_token).
      with(:headers => {'Authorization' => "Bearer " + invalid_bearer_token }).
      to_return(:body => '401 Unauthorized', :status => [401, "Unauthorized"])
  end
end

RSpec.configure do |config|
  config.include Helpers
end

RSpec::Matchers.define :be_nonempty do
  match do |object|
    !object.empty?
  end
end
